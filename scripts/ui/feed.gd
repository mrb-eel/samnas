class_name Feed
extends PanelContainer
## The dialogue column. New lines arrive at the bottom and type out; older
## lines stay, dimmed, so a conversation can refer back three minutes.

signal clicked()

const MAX_ENTRIES := 40

var scroll: ScrollContainer
var list: VBoxContainer
var choices: ChoiceList
var more: Label
var _typing: RichTextLabel = null
var _typed := 0.0
var _last_scroll_max := 0.0
var style_mode := "column"  # column | band | center

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	scroll.add_child(inner)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	inner.add_child(list)
	more = Kit.label("▾", 18, Kit.RED, "bold")
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	more.visible = false
	inner.add_child(more)
	choices = ChoiceList.new()
	choices.visible = false
	inner.add_child(choices)
	scroll.get_v_scroll_bar().changed.connect(_on_scroll_changed)
	restyle()
	Settings.changed.connect(restyle)

func restyle() -> void:
	var clean := Settings.clean_text
	var sb: StyleBox
	match style_mode:
		"band":
			sb = Kit.flat(Color(0.03, 0.03, 0.04, 0.82 if not clean else 1.0), Color(0, 0, 0, 0), 0, 0, 18)
		"center":
			sb = Kit.flat(Color(0, 0, 0, 0.0 if not clean else 1.0), Color(0, 0, 0, 0), 0, 0, 18)
		_:
			if clean:
				sb = Kit.flat(Color(0, 0, 0, 1), Color(0.4, 0.4, 0.4), 1, 0, 18)
			else:
				sb = Kit.tex_box("res://assets/ui/panel_column.png", 24, 20,
					Kit.flat(Color(0.075, 0.07, 0.085, 0.96), Color(Kit.IVORY_DIM, 0.3), 1, 0, 18))
	add_theme_stylebox_override("panel", sb)
	for c in list.get_children():
		if c is RichTextLabel:
			c.add_theme_font_size_override("normal_font_size", Settings.font_size())
			c.add_theme_font_size_override("bold_font_size", Settings.font_size())
			c.add_theme_font_size_override("italics_font_size", Settings.font_size())

func set_mode(mode: String) -> void:
	style_mode = mode
	restyle()

func clear() -> void:
	for c in list.get_children():
		c.queue_free()
	_typing = null
	more.visible = false

func add_line(entry: Dictionary, instant: bool = false) -> void:
	finish_typing()
	for c in list.get_children():
		if c is RichTextLabel:
			c.modulate = Color(1, 1, 1, 0.5)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", Kit.font("text"))
	r.add_theme_font_override("bold_font", Kit.font("display"))
	r.add_theme_font_override("italics_font", Kit.font("italic"))
	r.add_theme_font_size_override("normal_font_size", Settings.font_size())
	r.add_theme_font_size_override("bold_font_size", Settings.font_size())
	r.add_theme_font_size_override("italics_font_size", Settings.font_size())
	r.add_theme_color_override("default_color", Kit.IVORY)
	r.text = format(entry)
	list.add_child(r)
	while list.get_child_count() > MAX_ENTRIES:
		var old := list.get_child(0)
		list.remove_child(old)
		old.queue_free()
	if instant or Settings.instant_text or entry["kind"] == "echo":
		r.visible_characters = -1
		_typing = null
	else:
		r.visible_characters = 0
		_typing = r
		_typed = 0.0
	more.visible = false

static func format(entry: Dictionary) -> String:
	var t := Kit.esc_bb(entry["text"])
	var sp: String = entry.get("speaker", "")
	match entry["kind"]:
		"say", "echo":
			var col := Kit.speaker_color(sp).to_html(false)
			return "[b][color=#%s]%s[/color][/b]   %s" % [col, Kit.speaker_name(sp).to_upper(), t]
		"sms":
			var col2 := Kit.speaker_color(sp).to_html(false)
			return "[b][color=#%s]%s[/color][/b] [color=#8a8f86](text)[/color]   %s" % [col2, Kit.speaker_name(sp).to_upper(), t]
		"sound":
			return "[color=#79a88c][i]≈ %s[/i][/color]" % t
		"think":
			return "[indent][color=#d9a0b0][i]%s[/i][/color][/indent]" % t
		"doc":
			return "[color=#c9bfa8]%s[/color]" % t
		_:
			return "[color=#d8d0bd]%s[/color]" % t

func is_typing() -> bool:
	return _typing != null

func finish_typing() -> void:
	if _typing:
		_typing.visible_characters = -1
		_typing = null
		more.visible = true

func show_more(v: bool) -> void:
	more.visible = v and _typing == null

func _process(delta: float) -> void:
	if _typing:
		_typed += delta * Settings.chars_per_second()
		var total := _typing.get_total_character_count()
		_typing.visible_characters = int(_typed)
		if _typed >= total:
			_typing.visible_characters = -1
			_typing = null
			more.visible = true

func _on_scroll_changed() -> void:
	var sb := scroll.get_v_scroll_bar()
	if sb.max_value != _last_scroll_max:
		_last_scroll_max = sb.max_value
		scroll.scroll_vertical = int(sb.max_value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()
