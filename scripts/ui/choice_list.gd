class_name ChoiceList
extends VBoxContainer
## Choices look the same wherever they appear (feed, phone, doorway strip):
## a hot-red numbered tab, then the text. Speech is in quotes. Once shown,
## a choice never moves; hover and focus change colour only.

signal chosen(index: int)

const VERB_NAMES := {
	"look": "LOOK", "listen": "LISTEN", "ask": "ASK", "hold": "PHONE DOWN", "end": "END CALL",
	"callback": "CALL BACK", "text": "TEXT", "defer": "LATER", "leave": "LEAVE", "dial": "DIAL",
	"answer": "ANSWER", "decline": "LET IT RING", "wait": "WAIT", "go": "GO", "sign": "SIGN",
	"read": "READ", "stay": "STAY", "call": "CALL", "respect": "LOOK AWAY",
}

var items: Array = []
var options: Array = []
var _armed_at := 0.0
var surface := "feed"  # feed | phone | strip

func _ready() -> void:
	add_theme_constant_override("separation", 6)

func show_options(opts: Array) -> void:
	clear()
	options = opts
	_armed_at = Time.get_ticks_msec() / 1000.0 + 0.3
	for i in opts.size():
		var it := ChoiceItem.new()
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
	visible = false

func pick(i: int) -> void:
	if Time.get_ticks_msec() / 1000.0 < _armed_at:
		return
	if i < 0 or i >= items.size():
		return
	var idx := i
	clear()
	chosen.emit(idx)

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

class ChoiceItem extends PanelContainer:
	var index := 0
	var owner_list: ChoiceList
	var hovered := false
	var tab: Label
	var body: Label
	var verb: Label

	func setup(i: int, opt: Dictionary, list: ChoiceList) -> void:
		index = i
		owner_list = list
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		add_child(hb)
		var tabbox := PanelContainer.new()
		tabbox.add_theme_stylebox_override("panel", Kit.flat(Kit.RED, Color(0, 0, 0, 0), 0, 1, 0))
		tabbox.custom_minimum_size = Vector2(30, 0)
		tabbox.size_flags_vertical = Control.SIZE_FILL
		hb.add_child(tabbox)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		tabbox.add_child(vb)
		tab = Kit.label(str(i + 1), Settings.font_size() - 2, Kit.IVORY, "bold")
		tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tab)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 0)
		hb.add_child(right)
		var tags: Array = opt.get("tags", [])
		var verb_text := ""
		for t in tags:
			if VERB_NAMES.has(t):
				verb_text = VERB_NAMES[t]
		if verb_text != "":
			verb = Kit.label(verb_text, max(12, Settings.font_size() - 7), Kit.RED.lightened(0.25), "bold")
			right.add_child(verb)
		var txt: String = opt["text"]
		if opt.get("speech", false):
			txt = "“" + txt + "”"
		body = Kit.label(txt, Settings.font_size(), Kit.IVORY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.custom_minimum_size = Vector2(80, 0)
		right.add_child(body)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(4, 0)
		hb.add_child(pad)
		mouse_entered.connect(func(): hovered = true; _restyle())
		mouse_exited.connect(func(): hovered = false; _restyle())
		focus_entered.connect(_restyle)
		focus_exited.connect(_restyle)
		_restyle()

	func _restyle() -> void:
		var clean := Settings.clean_text
		var bg := Color(0.09, 0.085, 0.1, 0.94) if not clean else Color(0, 0, 0, 1)
		var border := Color(Kit.IVORY_DIM, 0.35)
		if hovered or has_focus():
			bg = Color(0.2, 0.17, 0.2, 0.97) if not clean else Color(0.15, 0.15, 0.15, 1)
			border = Kit.IVORY
		var sb := Kit.flat(bg, border, 1, 2, 0)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		add_theme_stylebox_override("panel", sb)
		if body:
			body.add_theme_color_override("font_color", Color.WHITE if (hovered or has_focus()) else Kit.IVORY)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			owner_list.pick(index)
			accept_event()
		elif event.is_action_pressed("ui_accept"):
			owner_list.pick(index)
			accept_event()
