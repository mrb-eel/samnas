class_name GW
extends RefCounted
## Widgets for the menus and cards, made of the same stuff as the rest:
## bakelite keys with a red button set in, toggle switches, a fader, a
## rotary selector. All drawn on the 640x360 grid.

## A key: red button, name on it, shortcut in small type.
class Key extends Control:
	signal pressed()
	var text := ""
	var hint := ""
	var disabled := false:
		set(v):
			disabled = v
			queue_redraw()
	var lamp_col := Grim.RED
	var hover := false
	var down := false
	var wide := false
	func _init(label: String = "", shortcut: String = "") -> void:
		text = label
		hint = shortcut
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		if size.y < 16:
			size.y = 20
		custom_minimum_size = Vector2(maxf(custom_minimum_size.x, Grim.text_w(text, "head", 16) + 34 + (Grim.text_w(hint, "tiny", 8) + 6 if hint != "" else 0)), 20)
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; down = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _process(_d: float) -> void:
		if hover and not disabled:
			ScreenFx.want("use")
	func _gui_input(e: InputEvent) -> void:
		if disabled:
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				down = true
			elif down and hover:
				down = false
				_fire()
			queue_redraw()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			_fire()
			accept_event()
	func _fire() -> void:
		Audio.sfx("key_throw", -8.0)
		pressed.emit()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-1)
		var hot := (hover or has_focus()) and not disabled
		Grim.inset(self, r.grow(1), Grim.INK)
		var face := Color("2e2420") if not hot else Color("46362c")
		if down:
			face = Color("1e1714")
		draw_rect(r, face)
		var bt := Grim.surf("bakelite")
		if bt:
			draw_texture_rect_region(bt, r, Rect2(Vector2(size.x * 0.37, 20), r.size), Color(1, 1, 1, 0.35))
		if not down:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.12))
		var cy := r.position.y + r.size.y * 0.5
		Grim.red_button(self, Vector2(r.position.x + 9, cy), hot, down, 4, lamp_col if not disabled else Color("4a3a36"))
		var lc := Grim.IVORY if hot else Grim.IVORY_DIM
		if disabled:
			lc = Color(Grim.IVORY_DIM, 0.35)
		var dy := 1.0 if down else 0.0
		Grim.text(self, Vector2(r.position.x + 19, cy + 5 + dy), text, "head", 16, lc)
		if hint != "":
			var hw := Grim.text_w(hint, "tiny", 8)
			Grim.text(self, Vector2(r.end.x - hw - 4, cy + 3 + dy), hint, "tiny", 8, Color(Grim.AMBER_DIM, 0.9 if not disabled else 0.3))
		if has_focus() and not disabled:
			draw_rect(r.grow(1), Color(Grim.AMBER, 0.7), false, 1.0)

## A toggle: a steel bat that flips up for on, a lamp that says so.
class Toggle extends Control:
	signal changed(v: bool)
	var text := ""
	var value := false
	var hover := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(maxf(custom_minimum_size.x, 180), 18)
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _process(_d: float) -> void:
		if hover:
			ScreenFx.want("use")
	func set_value(v: bool) -> void:
		value = v
		queue_redraw()
	func _flip() -> void:
		value = not value
		Audio.sfx("key_throw", -8.0)
		changed.emit(value)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_flip()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			_flip()
			accept_event()
	func _draw() -> void:
		var hot := hover or has_focus()
		var base := Rect2(2, 3, 22, 12)
		Grim.inset(self, base, Color("111"))
		draw_rect(base.grow(-1), Grim.STEEL_DK)
		var bat := Rect2(9, 1 if value else 8, 8, 9)
		draw_rect(bat, Grim.HILITE if hot else Grim.STEEL_LT)
		draw_rect(Rect2(bat.position, Vector2(bat.size.x, 1)), Color(1, 1, 1, 0.4))
		Grim.lamp(self, Vector2(32, 9), Grim.PHOS if value else Grim.RED, true, 2)
		Grim.text(self, Vector2(42, 14), text, "head", 16, Grim.IVORY if hot else Grim.IVORY_DIM)
		Grim.text(self, Vector2(size.x - 18, 13), "ON" if value else "OFF", "tiny", 8, Grim.PHOS_MID if value else Grim.IVORY_DIM)
		if has_focus():
			draw_rect(Rect2(Vector2.ZERO, size), Color(Grim.AMBER, 0.5), false, 1.0)

## A fader in a slot.
class Fader extends Control:
	signal changed(v: float)
	var text := ""
	var value := 0.5
	var hover := false
	var dragging := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(maxf(custom_minimum_size.x, 220), 18)
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _process(_d: float) -> void:
		if hover:
			ScreenFx.want("use")
	func _slot() -> Rect2:
		return Rect2(size.x * 0.46, 7, size.x * 0.5, 4)
	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
	func _set_from(x: float) -> void:
		var s := _slot()
		value = clampf((x - s.position.x) / s.size.x, 0.0, 1.0)
		changed.emit(value)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			dragging = e.pressed
			if e.pressed:
				_set_from(e.position.x)
			accept_event()
		elif e is InputEventMouseMotion and dragging:
			_set_from(e.position.x)
		elif e.is_action_pressed("ui_left"):
			value = clampf(value - 0.1, 0.0, 1.0)
			changed.emit(value)
			queue_redraw()
			accept_event()
		elif e.is_action_pressed("ui_right"):
			value = clampf(value + 0.1, 0.0, 1.0)
			changed.emit(value)
			queue_redraw()
			accept_event()
	func _draw() -> void:
		var hot := hover or has_focus()
		Grim.text(self, Vector2(2, 14), text, "head", 16, Grim.IVORY if hot else Grim.IVORY_DIM)
		var s := _slot()
		Grim.inset(self, s, Color("050505"))
		for i in 11:
			draw_rect(Rect2(s.position.x + s.size.x * i / 10.0, s.end.y + 2, 1, 2 if i % 5 else 3), Color(Grim.IVORY_DIM, 0.5))
		var kx := round(s.position.x + s.size.x * value)
		var knob := Rect2(kx - 3, 2, 7, 14)
		draw_rect(knob, Grim.INK)
		draw_rect(knob.grow(-1), Grim.HILITE if hot else Grim.STEEL_LT)
		draw_rect(Rect2(kx - 2, 8, 5, 1), Grim.RED)
		if has_focus():
			draw_rect(Rect2(Vector2.ZERO, size), Color(Grim.AMBER, 0.5), false, 1.0)

## A rotary switch through a few named positions.
class Selector extends Control:
	signal changed(i: int)
	var text := ""
	var options: Array = []
	var index := 0
	var hover := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(maxf(custom_minimum_size.x, 220), 18)
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _process(_d: float) -> void:
		if hover:
			ScreenFx.want("use")
	func set_index(i: int) -> void:
		index = clampi(i, 0, options.size() - 1)
		queue_redraw()
	func _step(dir: int) -> void:
		index = (index + dir + options.size()) % options.size()
		Audio.sfx("tick", -10.0)
		changed.emit(index)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_step(1)
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				_step(-1)
			accept_event()
		elif e.is_action_pressed("ui_right") or e.is_action_pressed("ui_accept"):
			_step(1)
			accept_event()
		elif e.is_action_pressed("ui_left"):
			_step(-1)
			accept_event()
	func _draw() -> void:
		var hot := hover or has_focus()
		Grim.text(self, Vector2(2, 14), text, "head", 16, Grim.IVORY if hot else Grim.IVORY_DIM)
		var c := Vector2(size.x * 0.46 + 7, 9)
		Grim._disc(self, c, 7, Grim.INK)
		Grim._disc(self, c, 6, Grim.STEEL_LT if hot else Grim.STEEL)
		var a := -PI * 0.75 + (PI * 1.5) * (float(index) / maxf(1.0, options.size() - 1))
		var tip := c + Vector2(cos(a - PI / 2), sin(a - PI / 2)) * 5.0
		draw_line(c, tip.round(), Grim.RED, 1.0)
		var label: String = str(options[index]).to_upper() if options.size() > 0 else ""
		Grim.text(self, Vector2(c.x + 12, 14), label, "head", 16, Grim.AMBER if hot else Grim.AMBER_DIM)
		if has_focus():
			draw_rect(Rect2(Vector2.ZERO, size), Color(Grim.AMBER, 0.5), false, 1.0)
