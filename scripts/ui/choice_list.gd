class_name ChoiceList
extends VBoxContainer
## Choices are tickets from a take-a-number machine, the sort the council
## lobby had: a stub with the number, a body with what you'd do. Pick one and
## the stub tears off and the body is stamped TAKEN. Speech is in quotes. A
## choice never moves once it's shown.

signal chosen(index: int)

const VERB_NAMES := {
	"look": "LOOK", "listen": "LISTEN", "ask": "ASK", "hold": "PHONE DOWN", "end": "END CALL",
	"callback": "CALL BACK", "text": "PRINT", "defer": "LATER", "leave": "LEAVE", "dial": "DIAL",
	"answer": "ANSWER", "decline": "LET IT RING", "wait": "WAIT", "go": "GO", "sign": "SIGN",
	"read": "READ", "stay": "STAY", "call": "CALL", "respect": "LOOK AWAY",
}

var items: Array = []
var options: Array = []
var _armed_at := 0.0
var surface := "feed"
var taking := -1

func _ready() -> void:
	add_theme_constant_override("separation", 6)

func show_options(opts: Array) -> void:
	clear()
	options = opts
	taking = -1
	_armed_at = Time.get_ticks_msec() / 1000.0 + 0.3
	for i in opts.size():
		var it := Ticket.new()
		it.setup(i, opts[i], self)
		add_child(it)
		items.append(it)
	visible = true
	if items.size() > 0:
		items[0].call_deferred("grab_focus")

func clear() -> void:
	for it in items:
		it.queue_free()
	items.clear()
	options.clear()
	taking = -1
	visible = false

func pick(i: int) -> void:
	if taking >= 0 or Time.get_ticks_msec() / 1000.0 < _armed_at:
		return
	if i < 0 or i >= items.size():
		return
	taking = i
	Audio.sfx("paper", -3.0)
	for k in items.size():
		items[k].take(k == i)
	var idx := i
	var delay := 0.02 if Settings.reduced_motion else 0.42
	get_tree().create_timer(delay).timeout.connect(func():
		if taking == idx:
			clear()
			chosen.emit(idx))

func spot_index(spot: String) -> int:
	for i in options.size():
		for t in options[i]["tags"]:
			if t == "spot:" + spot:
				return i
	return -1

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or items.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var n := k - KEY_1
			if n < items.size():
				pick(n)
				get_viewport().set_input_as_handled()

class Ticket extends MarginContainer:
	var index := 0
	var owner_list: ChoiceList
	var hovered := false
	var body: Label
	var verb := ""
	var lift := 0.0
	var taken := 0.0
	var dropped := 0.0
	var chosen_one := false
	var seed := 0.0

	func setup(i: int, opt: Dictionary, list: ChoiceList) -> void:
		index = i
		owner_list = list
		seed = float(i) * 7.3 + float(hash(str(opt.get("text", ""))) % 100)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta("plug", true)
		for tg in opt.get("tags", []):
			if VERB_NAMES.has(tg):
				verb = VERB_NAMES[tg]
		var txt: String = opt["text"]
		if opt.get("speech", false):
			txt = "“" + txt + "”"
		body = Label.new()
		body.text = txt
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.custom_minimum_size = Vector2(60, 0)
		add_child(body)
		mouse_entered.connect(func(): hovered = true)
		mouse_exited.connect(func(): hovered = false)
		resized.connect(func(): pivot_offset = size * 0.5)
		_restyle()

	func _restyle() -> void:
		var clean := Settings.clean_text
		add_theme_constant_override("margin_left", 12 if clean else 78)
		add_theme_constant_override("margin_top", 26 if (verb != "" and not clean) else 12)
		add_theme_constant_override("margin_right", 14)
		add_theme_constant_override("margin_bottom", 12)
		body.add_theme_font_override("font", Kit.font("prose"))
		body.add_theme_font_size_override("font_size", Settings.font_size())
		body.add_theme_color_override("font_color", Kit.IVORY if clean else Color("251d18"))

	func take(me: bool) -> void:
		chosen_one = me
		if Settings.reduced_motion:
			taken = 1.0 if me else 0.0
			dropped = 0.0 if me else 1.0
			modulate.a = 1.0 if me else 0.2

	func _process(d: float) -> void:
		var hot := (hovered or has_focus()) and owner_list.taking < 0
		lift = move_toward(lift, 1.0 if hot else 0.0, d * 7.0)
		if owner_list.taking >= 0 and not Settings.reduced_motion:
			if chosen_one:
				taken = move_toward(taken, 1.0, d * 4.0)
			else:
				dropped = move_toward(dropped, 1.0, d * 3.5)
				modulate.a = 1.0 - dropped * 0.85
		rotation = 0.0 if Settings.clean_text else lerpf((Kit.rnd(seed) - 0.5) * 0.02, 0.0, lift) + dropped * 0.04
		scale = Vector2.ONE * (1.0 + lift * 0.015)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			owner_list.pick(index)
			accept_event()
		elif event.is_action_pressed("ui_accept"):
			owner_list.pick(index)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hot := lift > 0.01
		if Settings.clean_text:
			draw_rect(r, Color(0.12, 0.12, 0.13) if hot else Color(0.06, 0.06, 0.07))
			draw_rect(r, Kit.IVORY if hot else Color(0.4, 0.4, 0.4), false, 1.0)
			Kit.text(self, Vector2(r.size.x - 34, 20), str(index + 1), "clean_b", 16, Kit.AMBER)
			return
		var buff := Color("e9d6a2").lerp(Color("f4e4b4"), lift)
		var stub_w := 64.0
		var body_r := Rect2(Vector2(stub_w, 0) + Vector2(-2, -lift * 3.0), Vector2(size.x - stub_w, size.y))
		# the body
		Kit.shadow(self, body_r, 0.1 + lift * 0.35)
		draw_rect(body_r, buff)
		var pt := Kit.tex("res://assets/ui/paper.png")
		if pt:
			draw_texture_rect(pt, body_r, true, Color(1, 1, 1, 0.35))
		if verb == "":
			draw_rect(Rect2(body_r.position + Vector2(8, 5), Vector2(body_r.size.x - 16, 2)), Color("b8261f", 0.5))
		draw_rect(Rect2(body_r.position + Vector2(8, body_r.size.y - 7), Vector2(body_r.size.x - 16, 2)), Color("b8261f", 0.5))
		if verb != "":
			Kit.stamp(self, body_r.position + Vector2(10, 3), verb, Color("b8261f"), 14, -0.03, false, buff)
		# the stub, which tears off along the dots when you take it
		var fall := taken
		var stub := Rect2(Vector2(0, -lift * 3.0 + fall * fall * 140.0), Vector2(stub_w, size.y))
		if fall < 1.0:
			draw_set_transform(stub.get_center(), fall * 0.9)
			var sr := Rect2(-stub.size * 0.5, stub.size)
			Kit.shadow(self, sr, 0.1 + lift * 0.35, 1.0 - fall)
			draw_rect(sr, Color(buff.darkened(0.06), 1.0 - fall))
			Kit.text(self, sr.position + Vector2(0, 20), "No.", "dotline", 11, Color("b8261f", 0.8 * (1.0 - fall)), stub_w, HORIZONTAL_ALIGNMENT_CENTER)
			Kit.text(self, sr.position + Vector2(0, 20 + 36), str(index + 1), "display", 34, Color("b8261f", 1.0 - fall), stub_w, HORIZONTAL_ALIGNMENT_CENTER)
			draw_set_transform(Vector2.ZERO)
		# the perforation, torn or not
		var px := stub_w - 2.0
		for y in range(4, int(size.y) - 2, 7):
			draw_circle(Vector2(px, y - lift * 3.0), 1.6, Color("1a1410") if fall < 0.05 else Color(buff.darkened(0.3), 1.0))
		if taken > 0.0:
			var sc := clampf(taken * 1.6, 0.0, 1.0)
			var a := clampf(taken * 3.0, 0.0, 1.0)
			var sp := body_r.position + Vector2(body_r.size.x - 128, body_r.size.y * 0.5 - 18)
			draw_set_transform(sp + Vector2(56, 18), -0.18, Vector2.ONE * lerpf(1.6, 1.0, sc))
			Kit.stamp(self, Vector2(-56, -18), "TAKEN", Color("b8261f", a), 26, 0.0, true, buff)
			draw_set_transform(Vector2.ZERO)
