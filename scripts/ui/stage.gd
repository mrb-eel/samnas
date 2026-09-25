class_name Stage
extends Control
## The low-resolution 3D stage, its viewpoint frame and its hotspots.

signal spot_clicked(spot: String)
signal clicked()

const SETS_DIR := "res://scripts/sets/"
const VIEW_COLORS := {
	"jad": Color("8fbf73"), "inez": Color("c98a4e"), "dima": Color("b39ad0"), "sal": Color("d3e8e0"),
	"teodor": Color("b58d63"), "kaye": Color("8fa3cf"), "nell": Color("e392aa"), "ari": Color("f2ebdd"),
	"tobi": Color("e3c96a"),
}
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
var view := "none"
var in_call := false
var shrink := 2
var _spot_buttons: Dictionary = {}
var _heard_tw: Tween

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

func load_set(name: String, variant: String) -> void:
	if name == set_name and variant == set_variant and current != null:
		return
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
	set_cam("main")

func set_cam(name: String) -> void:
	if current == null:
		return
	var c := current.cam(name)
	if c:
		c.current = true

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
		_heard_tw = create_tween()
		_heard_tw.tween_property(mat, "shader_parameter/heard", heard, 0.6)
	frame.view = who
	frame.calling = calling
	frame.queue_redraw()

func set_fade(v: float) -> void:
	mat.set_shader_parameter("fade", v)

func texture() -> ViewportTexture:
	return vp.get_texture()

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
		b.position = Vector2(r[0], r[1]) * size
		b.size = Vector2(r[2], r[3]) * size
		b.pressed_spot.connect(func(s): spot_clicked.emit(s))
		spots_layer.add_child(b)
		_spot_buttons[sid] = b

func set_spot_labels(labels: Dictionary) -> void:
	for sid in _spot_buttons:
		_spot_buttons[sid].tip = labels.get(sid, "")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()

class StageFrame extends Control:
	var view := "none"
	var calling := false
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if view != "none" and view != "":
			var col: Color = Stage.VIEW_COLORS.get(view, Kit.IVORY)
			draw_rect(r.grow(-3), col, false, 6.0)
			draw_rect(r.grow(-9), Color(col, 0.35), false, 1.0)
			var f := Kit.font("display")
			var label := "VIA " + str(Stage.VIEW_NAMES.get(view, view.to_upper()))
			if view == "ari":
				label = "YOUR OWN EYES"
			var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_rect(Rect2(14, 12, w + 22, 28), col)
			draw_string(f, Vector2(25, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Kit.INK)
		elif calling:
			draw_rect(r.grow(-3), Color(Kit.IVORY_DIM, 0.25), false, 2.0)
			var f2 := Kit.font("display")
			var label2 := "HEARD, NOT SEEN"
			var w2 := f2.get_string_size(label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_rect(Rect2(14, 12, w2 + 20, 26), Color(0, 0, 0, 0.7))
			draw_string(f2, Vector2(24, 31), label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.IVORY_DIM)

class SpotButton extends Control:
	signal pressed_spot(s: String)
	var spot := ""
	var tip := ""
	var hover := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Kit.RED if hover else Color(Kit.IVORY, 0.5)
		# corner ticks rather than a box, so the art stays visible
		var l := minf(14.0, minf(size.x, size.y) * 0.3)
		for c in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			var dx := l if c.x == 0 else -l
			var dy := l if c.y == 0 else -l
			draw_line(c, c + Vector2(dx, 0), col, 2.0)
			draw_line(c, c + Vector2(0, dy), col, 2.0)
		if hover and tip != "":
			var f := Kit.font("text")
			var w := f.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var p := Vector2(clampf(size.x * 0.5 - w * 0.5 - 6, -position.x, 9999), size.y + 4)
			draw_rect(Rect2(p, Vector2(w + 12, 24)), Color(0, 0, 0, 0.85))
			draw_string(f, p + Vector2(6, 18), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.IVORY)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed_spot.emit(spot)
			accept_event()
