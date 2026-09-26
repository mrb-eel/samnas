class_name Hud
extends RefCounted
## The strip across the top of the night: a split-flap clock, the chapter on
## a length of label tape, and a row of bakelite keys.

## Split-flap digits, like a departures board: each flap folds over when the
## minute changes.
class FlapClock extends Control:
	var text := "":
		set(v):
			if v == text:
				return
			_old = text if text != "" else v
			text = v
			for i in v.length():
				if i >= _old.length() or _old[i] != v[i]:
					_flips[i] = 0.0 if not Settings.reduced_motion else 1.0
			if Game.playing and _flips.size() > 0:
				Audio.sfx("flap", -14.0)
			queue_redraw()
	var _old := ""
	var _flips: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(150, 40)
		size = custom_minimum_size

	func _process(d: float) -> void:
		if _flips.is_empty():
			return
		for k in _flips.keys():
			_flips[k] += d * 4.5
			if _flips[k] >= 1.0:
				_flips.erase(k)
		queue_redraw()

	func _draw() -> void:
		var x := 0.0
		var fw := 27.0
		var fh := 38.0
		var f := Kit.font("dymo")
		for i in text.length():
			var ch := text[i]
			if ch == ":":
				draw_circle(Vector2(x + 6, fh * 0.34), 2.6, Kit.AMBER)
				draw_circle(Vector2(x + 6, fh * 0.68), 2.6, Kit.AMBER)
				x += 13.0
				continue
			var r := Rect2(x, 0, fw, fh)
			draw_rect(Rect2(r.position + Vector2(1.5, 2.5), r.size), Color(0, 0, 0, 0.5))
			draw_rect(r, Color("161313"))
			var p: float = _flips.get(i, 1.0)
			var show := ch if p >= 0.5 else (_old[i] if i < _old.length() else ch)
			var sy := absf(p - 0.5) * 2.0 if i in _flips else 1.0
			draw_set_transform(Vector2(x + fw * 0.5, fh * 0.5), 0.0, Vector2(1.0, maxf(sy, 0.02)))
			draw_rect(Rect2(-fw * 0.5 + 1, -fh * 0.5 + 1, fw - 2, fh - 2), Color("211d1c"))
			draw_string(f, Vector2(-fw * 0.5, 12), show, HORIZONTAL_ALIGNMENT_CENTER, fw, 32, Color("f1ece0"))
			draw_set_transform(Vector2.ZERO)
			draw_line(Vector2(x, fh * 0.5), Vector2(x + fw, fh * 0.5), Color(0, 0, 0, 0.85), 2.0)
			draw_rect(Rect2(x - 1.5, fh * 0.5 - 2.5, 3, 5), Color("5a5250"))
			draw_rect(Rect2(x + fw - 1.5, fh * 0.5 - 2.5, 3, 5), Color("5a5250"))
			x += fw + 3.0

## A length of label-maker tape that says where in the night you are.
class TapeLabel extends Control:
	var text := "":
		set(v):
			text = v
			queue_redraw()
	var tape_col := Color("1f3f78")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if text != "":
			Kit.dymo(self, Vector2(0, 4), text, 15, tape_col, -0.01)

## A bakelite key on the rail. Engraved name on the cap, shortcut under it.
class HudKey extends Control:
	signal pressed()
	var cap := ""
	var hint := ""
	var badge := 0:
		set(v):
			badge = v
			queue_redraw()
	var disabled := false:
		set(v):
			disabled = v
			queue_redraw()
	var hover := false
	var down := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta("plug", true)
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; down = false; queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			down = e.pressed and not disabled
			if not e.pressed and hover and not disabled:
				Audio.sfx("key_throw", -10.0)
				pressed.emit()
			queue_redraw()
			accept_event()

	func _draw() -> void:
		var press := 2.0 if down else 0.0
		var cr := Rect2(Vector2(0, press), Vector2(size.x, 28))
		draw_rect(Rect2(Vector2(1.5, 4), Vector2(size.x, 28)), Color(0, 0, 0, 0.55))
		var capc := Kit.BAKELITE.lightened(0.18 if hover and not disabled else 0.05)
		draw_rect(cr, capc)
		draw_rect(Rect2(cr.position, Vector2(cr.size.x, 5)), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(cr.position + Vector2(0, cr.size.y - 3), Vector2(cr.size.x, 3)), Color(0, 0, 0, 0.35))
		var ink := Color("0e0a08")
		var lit := Kit.AMBER if hover and not disabled else Color("d9c9a4")
		if disabled:
			lit = Color(0.5, 0.45, 0.4, 0.5)
		Kit.text(self, Vector2(0, press + 20), cap, "stamp_b", 15, Color(ink, 0.7), size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.text(self, Vector2(0, press + 19), cap, "stamp_b", 15, lit, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.text(self, Vector2(0, 44), hint, "dotline", 11, Color(Kit.IVORY_DIM, 0.6 if not disabled else 0.25), size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if badge > 0:
			var c := Vector2(size.x - 4, 2)
			Kit.lamp(self, c, 9.0, Kit.RED, true)
			Kit.text(self, c + Vector2(-10, 5), str(badge), "clean_b", 12, Color.WHITE, 20, HORIZONTAL_ALIGNMENT_CENTER)

## A caption for the room's own sound, on tape, fading.
class CaptionTape extends Control:
	var text := ""
	var life := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func show_text(s: String) -> void:
		text = s
		life = 7.0
		queue_redraw()
	func _process(d: float) -> void:
		if life > 0.0:
			life -= d
			queue_redraw()
	func _draw() -> void:
		if life <= 0.0 or text == "":
			return
		var a := clampf(life / 1.2, 0.0, 1.0)
		var f := Kit.font("prose_i")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var r := Rect2(0, 0, w + 44, 26)
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.4 * a))
		draw_rect(r, Color("1b2621", a))
		Kit.text(self, Vector2(10, 18), "≈", "prose_b", 16, Color("7fb89a", a))
		draw_string(f, Vector2(30, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c4e2cf", a))
