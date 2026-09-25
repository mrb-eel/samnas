class_name Layers
extends RefCounted
## Exchange view, portraits, collage.

## The exchange: windows onto live connections, arranged around the place
## where Ari would be if Ari were anywhere.
class ExchangeLayer extends Control:
	var stage: Stage
	var wins: Dictionary = {}  # slot -> [kind, arg, label]
	var t := 0.0
	var frame_tex: Texture2D
	var bg_tex: Texture2D
	const SLOTS := {
		"1": Rect2(34, 44, 420, 250),
		"2": Rect2(34, 318, 204, 140),
		"3": Rect2(250, 318, 204, 140),
		"4": Rect2(484, 318, 150, 140),
	}
	const CENTER := Rect2(530, 36, 300, 400)
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://assets/ui/oval_frame.png"):
			frame_tex = load("res://assets/ui/oval_frame.png")
		if ResourceLoader.exists("res://assets/ui/exchange_bg.png"):
			bg_tex = load("res://assets/ui/exchange_bg.png")
	func _process(d: float) -> void:
		t += d * (0.0 if Settings.reduced_motion else 1.0)
		queue_redraw()
	func _draw() -> void:
		if bg_tex:
			draw_texture_rect(bg_tex, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color("0b0b0e"))
		# wires from each live window to the centre
		var c := CENTER.get_center()
		for slot in wins:
			var w: Array = wins[slot]
			if w[0] == "off":
				continue
			var r: Rect2 = SLOTS.get(slot, Rect2())
			var a := r.get_center()
			var col := Color(Kit.GREEN, 0.5)
			var pts := PackedVector2Array()
			for i in 17:
				var k := i / 16.0
				var p := a.lerp(c, k)
				p.y += sin(k * PI) * 40.0
				pts.append(p)
			draw_polyline(pts, col, 2.0)
			var pulse := fmod(t * 0.4 + float(slot.hash() % 7) * 0.13, 1.0)
			draw_circle(a.lerp(c, pulse) + Vector2(0, sin(pulse * PI) * 40.0), 3.0, Kit.RED)
		# the absence
		var inner := CENTER.grow(-34)
		_oval(inner, Color(0.015, 0.015, 0.02, 1.0))
		var breathe := 0.05 + 0.03 * sin(t * 0.9)
		_oval(inner.grow(-20), Color(Kit.BLUE, breathe))
		if frame_tex:
			draw_texture_rect(frame_tex, CENTER, false)
		else:
			_oval_line(CENTER.grow(-24), Color("6d7a63"), 10.0)
			_oval_line(CENTER.grow(-36), Color("3b4a3d"), 3.0)
		for slot in wins:
			_win(slot, wins[slot])
	func _oval(r: Rect2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(r.get_center() + Vector2(cos(a) * r.size.x / 2, sin(a) * r.size.y / 2))
		draw_colored_polygon(pts, col)
	func _oval_line(r: Rect2, col: Color, w: float) -> void:
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(r.get_center() + Vector2(cos(a) * r.size.x / 2, sin(a) * r.size.y / 2))
		draw_polyline(pts, col, w)
	func _win(slot: String, w: Array) -> void:
		if not SLOTS.has(slot) or w[0] == "off":
			return
		var r: Rect2 = SLOTS[slot]
		var kind: String = w[0]
		var arg: String = w[1] if w.size() > 1 else ""
		var label: String = w[2] if w.size() > 2 else ""
		draw_rect(r.grow(4), Color("262229"))
		draw_rect(r, Color("050506"))
		var col := Kit.IVORY_DIM
		match kind:
			"view":
				if stage:
					draw_texture_rect(stage.texture(), r, false)
				col = Stage.VIEW_COLORS.get(arg, Kit.IVORY)
				if label == "":
					label = "VIA " + str(Stage.VIEW_NAMES.get(arg, arg.to_upper()))
			"wave":
				var pts := PackedVector2Array()
				for i in 64:
					var x := r.position.x + 8 + (r.size.x - 16) * i / 63.0
					var amp := (sin(i * 0.7 + t * 6.0) * 0.5 + sin(i * 0.23 - t * 3.1) * 0.5) * r.size.y * 0.22
					pts.append(Vector2(x, r.get_center().y + amp))
				draw_polyline(pts, Color("79a88c"), 2.0)
			"lamp":
				var on := arg == "on"
				draw_circle(r.get_center() - Vector2(0, 8), 18.0, Color("f0b24a") if on else Color("3a3228"))
				if on:
					draw_circle(r.get_center() - Vector2(0, 8), 30.0, Color(1, 0.7, 0.3, 0.15))
			"doc":
				var dd: Dictionary = Game.docs_def.get(arg, {})
				var p: String = dd.get("image", "")
				if p != "" and ResourceLoader.exists(p):
					draw_texture_rect(load(p), r.grow(-6), false)
			"text":
				pass
		draw_rect(r, col, false, 3.0)
		if label != "":
			var f := Kit.font("display")
			var sz := 15
			var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 24), Vector2(tw + 16, 24)), Color(col, 0.92))
			draw_string(f, r.position + Vector2(8, r.size.y - 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Kit.INK)

## Portraits sit at the edges of a composition, not in a row of sprites.
class PortraitLayer extends Control:
	var stage_rect := Rect2()
	var items: Dictionary = {}
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false
	func show_all(p: Dictionary, rect: Rect2) -> void:
		stage_rect = rect
		for k in items:
			items[k].queue_free()
		items.clear()
		for who in p:
			var info: Dictionary = p[who]
			var tex := _tex(who, info.get("expr", "neutral"))
			if tex == null:
				continue
			var holder := PortraitItem.new()
			holder.tex = tex
			holder.slot = info.get("slot", "edge")
			holder.rect = _slot_rect(holder.slot, tex)
			holder.who = who
			add_child(holder)
			items[who] = holder
	func _tex(who: String, expr: String) -> Texture2D:
		for p in ["res://assets/portraits/%s_%s.png" % [who, expr], "res://assets/portraits/%s_neutral.png" % who]:
			if ResourceLoader.exists(p):
				return load(p)
		return null
	func _slot_rect(slot: String, tex: Texture2D) -> Rect2:
		var r := stage_rect
		var aspect := float(tex.get_width()) / tex.get_height()
		match slot:
			"oval":
				var h := r.size.y * 0.36
				return Rect2(r.end.x - h * 0.82 - 18, r.position.y + 18, h * 0.82, h)
			"strip":
				var h2 := r.size.y
				var w2 := minf(h2 * aspect, r.size.x * 0.26)
				return Rect2(r.end.x - w2, r.position.y, w2, h2)
			"low_right":
				var h4 := r.size.y * 0.62
				return Rect2(r.end.x - h4 * aspect * 0.95, r.end.y - h4 * 0.88, h4 * aspect, h4)
			_:
				var h3 := r.size.y * 0.72
				return Rect2(r.position.x - h3 * aspect * 0.06, r.end.y - h3 * 0.9, h3 * aspect, h3)

class PortraitItem extends Control:
	var tex: Texture2D
	var slot := "edge"
	var rect := Rect2()
	var who := ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO
		size = Vector2(1280, 720)
	func _draw() -> void:
		if slot == "oval":
			var c := rect.get_center()
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var p := c + Vector2(cos(a) * rect.size.x / 2, sin(a) * rect.size.y / 2)
				pts.append(p)
				uvs.append((p - rect.position) / rect.size * Vector2(1.0, 0.75) + Vector2(0.0, 0.02))
			draw_colored_polygon(pts, Color.WHITE, uvs, tex)
			var ring := pts.duplicate()
			ring.append(pts[0])
			draw_polyline(ring, Color("8a7f5c"), 6.0)
			draw_polyline(ring, Color("3e3a2c"), 2.0)
		elif slot == "strip":
			var src_w := tex.get_width() * (rect.size.x / (rect.size.y * tex.get_width() / tex.get_height()))
			var src := Rect2((tex.get_width() - src_w) / 2, 0, src_w, tex.get_height())
			draw_texture_rect_region(tex, rect, src)
			draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color("8a7f5c"), 3.0)
		else:
			draw_texture_rect(tex, rect, false)

## Several people's expectations of Ari at once.
class CollageLayer extends Control:
	var items: Array = []
	var t := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_items(list: Array) -> void:
		items = list
		queue_redraw()
	func _process(d: float) -> void:
		if not visible:
			return
		t += d * (0.0 if Settings.reduced_motion else 1.0)
		queue_redraw()
	func _draw() -> void:
		for i in items.size():
			var a: Array = items[i]
			var p := "res://assets/collage/%s.png" % a[0]
			if not ResourceLoader.exists(p):
				continue
			var tex: Texture2D = load(p)
			var pos := Vector2(float(a[1]) * 1280.0, float(a[2]) * 720.0)
			var sc := float(a[3]) if a.size() > 3 else 1.0
			var rot := deg_to_rad(float(a[4])) if a.size() > 4 else 0.0
			var drift := Vector2(sin(t * 0.3 + i), cos(t * 0.23 + i * 1.7)) * 3.0
			draw_set_transform(pos + drift, rot, Vector2(sc, sc))
			draw_texture(tex, -tex.get_size() / 2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
