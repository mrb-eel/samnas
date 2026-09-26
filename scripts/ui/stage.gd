class_name Stage
extends Control
## The low-resolution 3D stage, full screen. It shows the room through
## whoever is lending Ari their eyes, and in rooms with a floor it lets the
## player ask that person to walk somewhere or deal with something: click
## the floor and they go; click a thing and they go to it, turn to it, and
## the story takes it from there.

signal spot_clicked(spot: String)  # a screen-space spot (close-ups)
signal walk_picked(spot: String)  # the lender has reached a room hotspot
signal clicked()
signal actor_settled()

const SETS_DIR := "res://scripts/sets/"
const VIEW_NAMES := {
	"jad": "JAD", "inez": "INEZ", "dima": "DIMA", "sal": "SAL", "teodor": "TEODOR", "kaye": "MRS. KAYE",
	"nell": "NELL", "tobi": "TOBI",
}

var container: SubViewportContainer
var vp: SubViewport
var current: SetBase
var set_name := ""
var set_variant := ""
var mat: ShaderMaterial
var frame: StageFrame
var spots_layer: Control
var marks: Marks
var view := "none"
var in_call := false
var shrink := 1
var _spot_buttons: Dictionary = {}
var _heard_tw: Tween

# walking
var nav := Nav.new()
var walking := false
var walk_who := ""
var walker: Walker
var walkers: Dictionary = {}
var walk_spots: Dictionary = {}  # spot -> {label, verb, index}
var interactive := false  # choices are waiting, so clicks do something
var hover_spot := ""
var pending_spot := ""
var cutaway := ""
var reveal := false
var _walk_cam: Camera3D
var _cam_target := Vector3.ZERO
var _was_moving := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = shrink
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	container.add_child(vp)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/stage_post.gdshader")
	container.material = mat
	marks = Marks.new()
	marks.stage = self
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marks)
	frame = StageFrame.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	spots_layer = Control.new()
	spots_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	spots_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spots_layer)
	Settings.changed.connect(_on_settings)
	_on_settings()

func _on_settings() -> void:
	mat.set_shader_parameter("motion", 0.0 if Settings.reduced_motion else 1.0)
	mat.set_shader_parameter("grain", 0.03 if Settings.reduced_motion else 0.05)
	var want := 2 if Settings.world_res == 0 else 1
	if want != shrink:
		shrink = want
		container.stretch_shrink = shrink

# ---------------------------------------------------------------- sets

func load_set(name: String, variant: String) -> void:
	if name == set_name and variant == set_variant and current != null:
		return
	walk_end()
	walkers.clear()
	if current:
		vp.remove_child(current)
		current.queue_free()
		current = null
	set_name = name
	set_variant = variant
	if name == "" or name == "none":
		return
	var path := SETS_DIR + "set_" + name + ".gd"
	var s: SetBase
	if ResourceLoader.exists(path):
		s = load(path).new()
	else:
		s = load(SETS_DIR + "set_placeholder.gd").new()
	s.variant = variant
	vp.add_child(s)
	s.build(variant)
	current = s
	frame.plan_name = s.title
	nav.build(s)
	_walk_cam = null
	set_cam("main")

func set_cam(name: String) -> void:
	if current == null:
		return
	if walking:
		cutaway = name
	var c := current.cam(name)
	if c:
		c.current = true
		current.on_cam(name if current.cams.has(name) else "main")

func apply_state(key: String, value: String) -> void:
	if current:
		current.apply_state(key, value)

func set_view(who: String, calling: bool) -> void:
	view = who
	in_call = calling
	var heard := 1.0 if (calling and (who == "none" or who == "")) else 0.0
	if _heard_tw:
		_heard_tw.kill()
	if Settings.reduced_motion:
		mat.set_shader_parameter("heard", heard)
	else:
		var from: float = mat.get_shader_parameter("heard") if mat.get_shader_parameter("heard") != null else 0.0
		_heard_tw = create_tween()
		_heard_tw.tween_method(func(v: float): mat.set_shader_parameter("heard", v), from, heard, 0.6)
	frame.view = who
	frame.calling = calling
	frame.queue_redraw()

func set_fade(v: float) -> void:
	mat.set_shader_parameter("fade", v)

func texture() -> ViewportTexture:
	return vp.get_texture()

# ---------------------------------------------------------------- screen spots (close-ups)

func set_spots(spots: Dictionary, active: Array) -> void:
	for k in _spot_buttons:
		_spot_buttons[k].queue_free()
	_spot_buttons.clear()
	for sid in spots:
		if not active.has(sid):
			continue
		var r: Array = spots[sid]
		var b := SpotButton.new()
		b.spot = sid
		b.position = (Vector2(r[0], r[1]) * size).round()
		b.size = (Vector2(r[2], r[3]) * size).round()
		b.pressed_spot.connect(func(s): spot_clicked.emit(s))
		spots_layer.add_child(b)
		_spot_buttons[sid] = b

func set_spot_labels(labels: Dictionary, verbs: Dictionary = {}) -> void:
	for sid in _spot_buttons:
		_spot_buttons[sid].tip = labels.get(sid, "")
		_spot_buttons[sid].verb = verbs.get(sid, "look")

# ---------------------------------------------------------------- walking

func can_walk() -> bool:
	return current != null and current.can_walk()

## Hand the lender over to the player. `entry` names a door in the set;
## empty keeps them where they are.
func walk_begin(who: String, entry: String = "", pose: String = "phone") -> void:
	if current == null or not current.can_walk():
		return
	var w := _walker_for(who, pose)
	if w == null:
		return
	walking = true
	walk_who = who
	walker = w
	cutaway = ""
	if entry != "" and current.entries.has(entry):
		var e: Array = current.entries[entry]
		w.place(e[0], e[1])
	_ensure_walk_cam(true)

func walk_end() -> void:
	walking = false
	walk_who = ""
	walker = null
	walk_spots.clear()
	hover_spot = ""
	pending_spot = ""
	cutaway = ""
	interactive = false

func _walker_for(who: String, pose: String = "phone") -> Walker:
	if walkers.has(who) and is_instance_valid(walkers[who].fig):
		return walkers[who]
	var fig: Node3D = current.actors.get(who)
	if fig == null or not is_instance_valid(fig):
		var at: Array = current.entries.values()[0] if not current.entries.is_empty() else [Vector3.ZERO, 0.0]
		fig = Figure.build(current, at[0], at[1], Figure.cast(who, {"arms": pose}))
		current.set_actor(who, fig)
	fig.visible = true
	var w := Walker.new()
	w.name = "walker_" + who
	add_child(w)
	w.setup(fig)
	walkers[who] = w
	return w

func _ensure_walk_cam(snap: bool) -> void:
	if current == null or walker == null:
		return
	if _walk_cam == null or not is_instance_valid(_walk_cam):
		var wc: Dictionary = current.walk_cam
		_walk_cam = current.add_cam("walk", Vector3(0, 3, 4), Vector3.ZERO, float(wc.get("fov", 50.0)))
		var off: Vector3 = wc["offset"]
		var look: Vector3 = wc["look"]
		_walk_cam.look_at_from_position(off, look, Vector3.UP)
		if current.cam_hide.has("main") and not current.cam_hide.has("walk"):
			current.cam_hide["walk"] = current.cam_hide["main"]
	_cam_target = _clamped(walker.fig.position)
	if snap:
		_walk_cam.position = _cam_target + current.walk_cam["offset"]
	if cutaway == "":
		_walk_cam.current = true
		current.on_cam("walk")

func _clamped(p: Vector3) -> Vector3:
	var lo: Vector3 = current.walk_cam["min"]
	var hi: Vector3 = current.walk_cam["max"]
	return Vector3(clampf(p.x, lo.x, hi.x), 0.0, clampf(p.z, lo.z, hi.z))

## The script has put choices up that live in the room.
func set_walk_spots(spots: Dictionary) -> void:
	walk_spots = spots
	interactive = true
	if walking and cutaway != "":
		cutaway = ""
		_ensure_walk_cam(false)
	marks.queue_redraw()

func clear_walk_spots() -> void:
	walk_spots.clear()
	interactive = false
	hover_spot = ""
	marks.queue_redraw()

## Somebody walks to a hotspot or a door, for the script. Calls `done`
## when they get there.
func walk_to(who: String, target: String, done: Callable) -> void:
	if current == null:
		done.call()
		return
	var w := _walker_for(who)
	if w == null:
		done.call()
		return
	var dest := Vector3.INF
	var face := Vector3.INF
	if current.hotspots.has(target):
		dest = current.hotspots[target]["stand"]
		face = current.hotspots[target]["face"]
	elif current.entries.has(target):
		dest = current.entries[target][0]
	if dest == Vector3.INF:
		done.call()
		return
	var p := nav.path(w.fig.position, dest)
	if p.is_empty():
		p = PackedVector3Array([dest])
	for c in w.arrived.get_connections():
		w.arrived.disconnect(c["callable"])
	w.arrived.connect(func(): done.call(), CONNECT_ONE_SHOT)
	w.go(p, face)

func place(who: String, target: String) -> void:
	if current == null:
		return
	var w := _walker_for(who)
	if w == null:
		return
	if current.hotspots.has(target):
		var hs: Dictionary = current.hotspots[target]
		var dir: Vector3 = hs["face"] - hs["stand"]
		w.place(hs["stand"], atan2(dir.x, dir.z))
	elif current.entries.has(target):
		w.place(current.entries[target][0], current.entries[target][1])
	if walking and w == walker:
		_ensure_walk_cam(true)

func actor_state() -> Dictionary:
	if walker == null or not is_instance_valid(walker.fig):
		return {}
	var p := walker.fig.position
	return {"who": walk_who, "x": p.x, "z": p.z, "r": walker.fig.rotation.y}

func actor_restore(st: Dictionary) -> void:
	if st.is_empty() or not walking or st.get("who", "") != walk_who:
		return
	walker.place(Vector3(float(st["x"]), current.floor_y, float(st["z"])), float(st["r"]))
	_ensure_walk_cam(true)

func _process(d: float) -> void:
	if not walking or walker == null or not is_instance_valid(walker.fig):
		return
	if _walk_cam and is_instance_valid(_walk_cam):
		_cam_target = _clamped(walker.fig.position)
		var want: Vector3 = _cam_target + current.walk_cam["offset"]
		var k := 1.0 - exp(-d * 2.6)
		_walk_cam.position = _walk_cam.position.lerp(want, k)
	if walker.moving != _was_moving:
		_was_moving = walker.moving
		if not walker.moving:
			actor_settled.emit()
	if interactive:
		marks.queue_redraw()

# ---------------------------------------------------------------- picking

func _ray(p: Vector2) -> Array:
	var cam := vp.get_camera_3d()
	if cam == null:
		return []
	var vpp := p / float(shrink)
	return [cam.project_ray_origin(vpp), cam.project_ray_normal(vpp)]

func _pick_spot(p: Vector2) -> String:
	var r := _ray(p)
	if r.is_empty():
		return ""
	var best := ""
	var bt := INF
	for sid in walk_spots:
		if not current.hotspots.has(sid):
			continue
		var box: AABB = current.hotspots[sid]["box"]
		var hit = box.intersects_ray(r[0], r[1])
		if hit != null:
			var t: float = (hit - r[0]).length()
			if t < bt:
				bt = t
				best = sid
	return best

func _pick_floor(p: Vector2) -> Vector3:
	var r := _ray(p)
	if r.is_empty():
		return Vector3.INF
	var o: Vector3 = r[0]
	var n: Vector3 = r[1]
	if absf(n.y) < 0.0001:
		return Vector3.INF
	var t := (current.floor_y - o.y) / n.y
	if t <= 0.0:
		return Vector3.INF
	return o + n * t

## Screen rect of a room hotspot, for brackets.
func spot_rect(sid: String) -> Rect2:
	var cam := vp.get_camera_3d()
	if cam == null or not current.hotspots.has(sid):
		return Rect2()
	var box: AABB = current.hotspots[sid]["box"]
	var pts: Array = []
	for i in 8:
		var c := box.get_endpoint(i)
		if cam.is_position_behind(c):
			continue
		pts.append(cam.unproject_position(c) * float(shrink))
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r

func _gui_input(event: InputEvent) -> void:
	var live := walking and interactive and walker != null and cutaway == ""
	if event is InputEventMouseMotion:
		if live:
			var sid := _pick_spot(event.position)
			if sid != hover_spot:
				hover_spot = sid
				marks.queue_redraw()
				if sid != "":
					Audio.sfx("tick", -24.0)
			if sid != "":
				var ws: Dictionary = walk_spots[sid]
				ScreenFx.want(ws.get("verb", "look"), ws.get("label", ""))
			else:
				var fp := _pick_floor(event.position)
				ScreenFx.want("walk" if fp != Vector3.INF and nav.walkable(nav.nearest(fp)) and fp.distance_to(nav.nearest(fp)) < 0.8 else "point")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not live:
			clicked.emit()
			return
		var sid2 := _pick_spot(event.position)
		if sid2 != "":
			_go_spot(sid2)
			return
		var fp2 := _pick_floor(event.position)
		if fp2 != Vector3.INF:
			var dest := nav.nearest(fp2)
			if dest.distance_to(fp2) < 0.8:
				pending_spot = ""
				var path := nav.path(walker.fig.position, dest)
				if not path.is_empty():
					marks.flag(dest)
					walker.go(path)

func _go_spot(sid: String) -> void:
	var hs: Dictionary = current.hotspots[sid]
	pending_spot = sid
	var path := nav.path(walker.fig.position, hs["stand"])
	for c in walker.arrived.get_connections():
		walker.arrived.disconnect(c["callable"])
	walker.arrived.connect(func():
		if pending_spot == sid and walking:
			pending_spot = ""
			walk_picked.emit(sid), CONNECT_ONE_SHOT)
	if path.is_empty():
		path = PackedVector3Array([walker.fig.position])
	walker.go(path, hs["face"])

## Keyboard: step through the live hotspots and pick one.
func cycle_spot(dir: int) -> void:
	if not (walking and interactive) or walk_spots.is_empty():
		return
	var keys := walk_spots.keys()
	var i := keys.find(hover_spot)
	i = (i + dir + keys.size()) % keys.size() if i >= 0 else 0
	hover_spot = keys[i]
	marks.queue_redraw()

func pick_hovered() -> void:
	if walking and interactive and hover_spot != "":
		_go_spot(hover_spot)

# ---------------------------------------------------------------- overlays

## Brackets on what the pointer is over; small marks on every live thing
## while the reveal key is held.
class Marks extends Control:
	var stage: Stage
	var _flag := Vector3.INF
	var _flag_t := 0.0
	func flag(p: Vector3) -> void:
		_flag = p
		_flag_t = 0.6
	func _process(d: float) -> void:
		if _flag_t > 0.0:
			_flag_t -= d
			queue_redraw()
	func _draw() -> void:
		if stage == null or not stage.walking or not stage.interactive or stage.cutaway != "":
			return
		var show_all: bool = stage.reveal or Settings.show_hotspots
		var placed: Array = []
		var marks_list: Array = []
		for sid in stage.walk_spots:
			var r := stage.spot_rect(sid)
			if r.size == Vector2.ZERO:
				continue
			if sid == stage.hover_spot:
				_brackets(r.grow(2), Grim.IVORY)
			elif show_all:
				marks_list.append([r.get_center().round(), stage.walk_spots[sid].get("label", "")])
		# labels pushed down until they stop overlapping each other
		marks_list.sort_custom(func(a, b): return a[0].y < b[0].y)
		for m in marks_list:
			var c: Vector2 = m[0]
			draw_rect(Rect2(c - Vector2(3, 3), Vector2(7, 7)), Grim.INK)
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), Grim.AMBER)
			var lab: String = m[1]
			if lab == "":
				continue
			var w := Grim.text_w(lab, "tiny", 8)
			var lr := Rect2(c + Vector2(-w * 0.5 - 2, 5), Vector2(w + 4, 10))
			lr.position.x = clampf(lr.position.x, 2, size.x - lr.size.x - 2)
			var tries := 0
			while tries < 12 and placed.any(func(q): return q.intersects(lr)):
				lr.position.y += 11
				tries += 1
			placed.append(lr)
			if lr.position.y > c.y + 6:
				draw_rect(Rect2(c.x, c.y + 3, 1, lr.position.y - c.y - 3), Color(Grim.AMBER, 0.6))
			Grim.band(self, lr, 0.8)
			Grim.text(self, lr.position + Vector2(2, 8), lab, "tiny", 8, Grim.IVORY)
		if _flag_t > 0.0 and _flag != Vector3.INF:
			var cam := stage.vp.get_camera_3d()
			if cam and not cam.is_position_behind(_flag):
				var p := (cam.unproject_position(_flag) * float(stage.shrink)).round()
				var k := int(_flag_t * 10.0) % 2
				draw_rect(Rect2(p - Vector2(3, 0), Vector2(7, 1)), Color(Grim.IVORY, 0.8 if k == 0 else 0.4))
				draw_rect(Rect2(p - Vector2(0, 2), Vector2(1, 5)), Color(Grim.IVORY, 0.8 if k == 0 else 0.4))
	func _brackets(r: Rect2, col: Color) -> void:
		r = Grim.snap(r)
		var l := clampf(minf(r.size.x, r.size.y) * 0.3, 3.0, 10.0)
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var dx := l if c.x == r.position.x else -l
			var dy := l if c.y == r.position.y else -l
			draw_rect(Rect2(c + Vector2(minf(dx, 0), 0), Vector2(absf(dx), 1)), Grim.INK)
			draw_rect(Rect2(c + Vector2(0, minf(dy, 0)), Vector2(1, absf(dy))), Grim.INK)
			draw_rect(Rect2(c + Vector2(minf(dx, 0), -1), Vector2(absf(dx), 1)), col)
			draw_rect(Rect2(c + Vector2(-1, minf(dy, 0)), Vector2(1, absf(dy))), col)

class StageFrame extends Control:
	var plan_name := ""
	var view := "none"
	var calling := false
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		if view != "none" and view != "":
			queue_redraw()
	func _draw() -> void:
		var top := 22.0
		if view == "plan":
			var lp := "THE PLAN" + ((" / " + plan_name) if plan_name != "" else "")
			var w := Grim.text_w(lp, "head", 16)
			Grim.band(self, Rect2(6, top, w + 12, 15))
			Grim.text(self, Vector2(12, top + 12), lp, "head", 16, Grim.IVORY)
		elif view != "none" and view != "":
			var col: Color = Grim.WHO.get(view, Grim.IVORY)
			# the frame of somebody else's eyes: four hard corners
			var r := Rect2(Vector2(4, top - 2), size - Vector2(8, top + 2))
			for c in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
				var dx := 14.0 if c.x < size.x * 0.5 else -14.0
				var dy := 10.0 if c.y < size.y * 0.5 else -10.0
				draw_rect(Rect2(c + Vector2(minf(dx, 0), 0), Vector2(absf(dx), 1)), Color(col, 0.8))
				draw_rect(Rect2(c + Vector2(0, minf(dy, 0)), Vector2(1, absf(dy))), Color(col, 0.8))
			var label := "VIA " + str(Stage.VIEW_NAMES.get(view, view.to_upper()))
			if view == "ari":
				label = "YOUR OWN EYES"
			var w2 := Grim.text_w(label, "head", 16)
			Grim.band(self, Rect2(10, top + 3, w2 + 20, 15))
			var on := int(t * 1.5) % 2 == 0 or Settings.reduced_motion
			Grim.lamp(self, Vector2(17, top + 10), col, on, 1)
			Grim.text(self, Vector2(24, top + 15), label, "head", 16, col)
		elif calling:
			var l2 := "HEARD, NOT SEEN"
			var w3 := Grim.text_w(l2, "head", 16)
			Grim.band(self, Rect2(10, top + 3, w3 + 12, 15))
			Grim.text(self, Vector2(16, top + 15), l2, "head", 16, Grim.PHOS_DIM)

class SpotButton extends Control:
	signal pressed_spot(s: String)
	var spot := ""
	var tip := ""
	var verb := "look"
	var hover := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
	func _process(_d: float) -> void:
		if hover:
			ScreenFx.want(verb, tip)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Grim.IVORY if hover else Color(Grim.IVORY, 0.35)
		var l := minf(8.0, minf(size.x, size.y) * 0.3)
		for c in [Vector2(0, 0), Vector2(size.x - 1, 0), Vector2(0, size.y - 1), Vector2(size.x - 1, size.y - 1)]:
			var dx := l if c.x == 0 else -l
			var dy := l if c.y == 0 else -l
			draw_rect(Rect2(c + Vector2(minf(dx, 0), 0), Vector2(absf(dx), 1)), col)
			draw_rect(Rect2(c + Vector2(0, minf(dy, 0)), Vector2(1, absf(dy))), col)
		if not hover and Settings.show_hotspots:
			var cc := r.get_center().round()
			draw_rect(Rect2(cc - Vector2(2, 2), Vector2(5, 5)), Grim.AMBER)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed_spot.emit(spot)
			accept_event()
