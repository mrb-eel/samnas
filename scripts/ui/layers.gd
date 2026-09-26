class_name Layers
extends RefCounted
## The exchange view, and the collage.

## Ari at home: the frame room, where nothing sits in the chair. Live
## connections come up on a bank of old monitors, like a caretaker's CCTV
## desk. When Ari is borrowing someone's eyes, that picture fills the
## screen and the other monitors shrink to a column at the side.
class ExchangeLayer extends Control:
	var stage: Stage
	var stage_full := false
	var wins: Dictionary = {}  # slot -> [kind, arg, label]
	var t := 0.0
	const BANK := {
		"1": Rect2(60, 48, 300, 190),
		"2": Rect2(384, 48, 196, 120),
		"3": Rect2(384, 184, 94, 70),
		"4": Rect2(486, 184, 94, 70),
	}
	const SIDE := {
		"2": Rect2(566, 40, 68, 46),
		"3": Rect2(566, 92, 68, 46),
		"4": Rect2(566, 144, 68, 46),
	}
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		t += d * (0.0 if Settings.reduced_motion else 1.0)
		queue_redraw()
	func _draw() -> void:
		if not stage_full:
			_draw_room()
		var slots: Dictionary = SIDE if stage_full else BANK
		for slot in wins:
			if stage_full and slot == "1":
				continue
			if slots.has(slot):
				_monitor(slots[slot], wins[slot], slot)
	func _draw_room() -> void:
		# a wall of dirty tiles, a desk of steel, the dark
		draw_rect(Rect2(Vector2.ZERO, size), Color("070807"))
		var st := Grim.surf("paint_green")
		if st:
			draw_texture_rect_region(st, Rect2(0, 0, size.x, 250), Rect2(0, 0, size.x, 250), Color(0.35, 0.38, 0.36))
		for x in range(0, int(size.x), 16):
			draw_rect(Rect2(x, 0, 1, 250), Color(0, 0, 0, 0.25))
		for y in range(0, 250, 16):
			draw_rect(Rect2(0, y, size.x, 1), Color(0, 0, 0, 0.25))
		Grim.plate(self, Rect2(20, 262, 600, 60), "steel", 5.0)
		Grim.dither(self, Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.35), 2)
		# the empty chair in front of the bank
		var c := Vector2(320, 300)
		draw_rect(Rect2(c + Vector2(-26, -10), Vector2(52, 8)), Color("1c1a18"))
		draw_rect(Rect2(c + Vector2(-24, -58), Vector2(48, 46)), Color("141312"))
		draw_rect(Rect2(c + Vector2(-24, -58), Vector2(48, 2)), Color("2c2a26"))
		# the cord, home in 247
		Grim.lamp(self, Vector2(40, 280), Grim.AMBER, true, 2)
		Grim.text(self, Vector2(48, 285), "247", "tiny", 8, Grim.IVORY_DIM)
	func _monitor(r: Rect2, w: Array, slot: String) -> void:
		var kind: String = w[0]
		if kind == "off":
			return
		var arg: String = w[1] if w.size() > 1 else ""
		var label: String = w[2] if w.size() > 2 else ""
		Grim.plate(self, r.grow(5), "bakelite", float(slot.hash() % 17), r.size.x > 80)
		Grim.crt(self, r, t + float(slot.hash() % 5))
		var col := Grim.PHOS_MID
		match kind:
			"view":
				if stage:
					draw_texture_rect(stage.texture(), r, false)
				col = Grim.WHO.get(arg, Grim.IVORY)
				if label == "":
					label = "VIA " + str(Stage.VIEW_NAMES.get(arg, arg.to_upper()))
			"wave":
				var pts := PackedVector2Array()
				var n := int(r.size.x - 8)
				for i in n:
					var x := r.position.x + 4 + i
					var a := (sin(i * 0.5 + t * 6.0) * 0.5 + sin(i * 0.17 - t * 3.1) * 0.5) * r.size.y * 0.22
					pts.append(Vector2(x, round(r.get_center().y + a)))
				draw_polyline(pts, Grim.PHOS_MID, 1.0)
			"lamp":
				Grim.lamp(self, r.get_center() - Vector2(0, 4), Grim.AMBER, arg == "on", 4)
			"doc":
				var dd: Dictionary = Game.docs_def.get(arg, {})
				var p: String = dd.get("image", "")
				if p != "" and ResourceLoader.exists(p):
					draw_texture_rect(load(p), r.grow(-3), false, Color(0.7, 1.0, 0.75))
			"text":
				Grim.text(self, r.position + Vector2(4, r.size.y * 0.5 + 4), arg if arg != "x" else "", "body", 16, Grim.PHOS_MID, r.size.x - 8, HORIZONTAL_ALIGNMENT_CENTER)
		Grim.crt_glass(self, r)
		if label != "":
			var sz := 8
			var tw := Grim.text_w(label, "tiny", sz)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 10), Vector2(tw + 6, 10)), Color(0, 0, 0, 0.8))
			Grim.text(self, r.position + Vector2(3, r.size.y - 2), label, "tiny", sz, col)

## Several people's expectations of Ari at once: cut-outs pinned up over
## the room.
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
			var pos := Vector2(float(a[1]) * size.x, float(a[2]) * size.y)
			var sc := (float(a[3]) if a.size() > 3 else 1.0) * (size.x / 1280.0)
			var rot := deg_to_rad(float(a[4])) if a.size() > 4 else 0.0
			var drift := Vector2(sin(t * 0.3 + i), cos(t * 0.23 + i * 1.7)).round()
			draw_set_transform((pos + drift).round(), rot, Vector2(sc, sc))
			draw_texture(tex, -tex.get_size() / 2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
