class_name Feed
extends Control
## The dialogue: slips of paper stacking up the side of the board. Each line
## arrives as its own slip and types out; older slips darken as they go back.
## People's names are rubber-stamped in their own ink. Ari's thoughts aren't
## on paper at all: Ari hasn't got any. Sounds are on caption tape. Texts come
## off the printer. In clean-text mode it's all plain type on black.

signal clicked()

const MAX_ENTRIES := 40

var scroll: ScrollContainer
var list: VBoxContainer
var choices: ChoiceList
var _typing: RichTextLabel = null
var _typed := 0.0
var _last_scroll_max := 0.0
var style_mode := "column"  # column | band | center
var _waiting_slip: Slip = null
var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.add_theme_stylebox_override("panel", Kit.empty_box())
	add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 14)
	scroll.add_child(inner)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	inner.add_child(list)
	choices = ChoiceList.new()
	choices.visible = false
	inner.add_child(choices)
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 10)
	inner.add_child(tail)
	scroll.get_v_scroll_bar().changed.connect(_on_scroll_changed)
	resized.connect(_fit_scroll)
	restyle()
	Settings.changed.connect(restyle)

func _fit_scroll() -> void:
	var pad := Vector4(16, 14, 12, 8)
	match style_mode:
		"band":
			pad = Vector4(24, 18, 24, 8)
		"center":
			pad = Vector4(0, 0, 0, 0)
	scroll.position = Vector2(pad.x, pad.y)
	scroll.size = size - Vector2(pad.x + pad.z, pad.y + pad.w)

func restyle() -> void:
	_fit_scroll()
	for c in list.get_children():
		if c is Slip:
			c.restyle()
	queue_redraw()

func set_mode(mode: String) -> void:
	style_mode = mode
	restyle()

func _process(d: float) -> void:
	t += d
	if _typing:
		_typed += d * Settings.chars_per_second()
		var total := _typing.get_total_character_count()
		_typing.visible_characters = int(_typed)
		if _typed >= total:
			_typing.visible_characters = -1
			_typing = null
			_set_waiting(true)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if Settings.clean_text:
		if style_mode != "center":
			draw_rect(r, Color(0, 0, 0, 1.0 if style_mode == "column" else 0.9))
		return
	match style_mode:
		"column":
			# the side of the board: bakelite, a brass edge, a shadow where it meets the wall
			Kit.shadow(self, r, 0.35)
			draw_rect(r, Color("1c1411"))
			var bk := Kit.tex("res://assets/ui/bakelite.png")
			if bk:
				draw_texture_rect(bk, r, true, Color(1, 1, 1, 0.5))
			for k in 10:
				draw_rect(Rect2(r.position + Vector2(k, k), r.size - Vector2(k, k) * 2.0), Color(0, 0, 0, 0.06), false, 1.0)
			draw_rect(Rect2(0, 0, 4, size.y), Kit.BRASS_DK)
			draw_rect(Rect2(1, 0, 1.5, size.y), Kit.BRASS)
			for y in [22.0, size.y - 22.0]:
				draw_circle(Vector2(size.x - 14, y), 4.0, Kit.BRASS_DK)
				draw_circle(Vector2(size.x - 14, y), 2.5, Kit.BRASS)
		"band":
			for k in 24:
				var a := 0.9 * pow(float(k) / 23.0, 1.4)
				draw_rect(Rect2(0, size.y * k / 24.0, size.x, size.y / 24.0 + 1), Color(0.03, 0.025, 0.03, a))

func clear() -> void:
	for c in list.get_children():
		c.queue_free()
	_typing = null
	_waiting_slip = null

func add_line(entry: Dictionary, instant: bool = false) -> void:
	finish_typing()
	_set_waiting(false)
	for c in list.get_children():
		if c is Slip:
			c.age += 1
			c.update_age()
	var s := Slip.new()
	s.entry = entry
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(s)
	s.build(style_mode)
	var cap := MAX_ENTRIES if style_mode == "column" else 5
	while list.get_child_count() > cap:
		var old := list.get_child(0)
		list.remove_child(old)
		old.queue_free()
	var r := s.body
	if instant or Settings.instant_text or entry["kind"] == "echo":
		r.visible_characters = -1
		_typing = null
		if not instant:
			_waiting_slip = s
	else:
		r.visible_characters = 0
		_typing = r
		_typed = 0.0
		_waiting_slip = s
	if not instant:
		s.arrive_anim()

static func format(entry: Dictionary) -> String:
	var t := Kit.esc_bb(entry["text"])
	var sp: String = entry.get("speaker", "")
	match entry["kind"]:
		"say", "echo":
			return "[b][color=#%s]%s[/color][/b]   %s" % [Kit.speaker_color(sp).to_html(false), Kit.speaker_name(sp).to_upper(), t]
		"sms":
			return "[b][color=#%s]%s[/color][/b] [color=#8a8f86](text)[/color]   %s" % [Kit.speaker_color(sp).to_html(false), Kit.speaker_name(sp).to_upper(), t]
		"sound":
			return "[color=#79a88c][i]≈ %s[/i][/color]" % t
		"think":
			return "[indent][color=#d9a0b0][i]%s[/i][/color][/indent]" % t
		_:
			return "[color=#d8d0bd]%s[/color]" % t

func is_typing() -> bool:
	return _typing != null

func finish_typing() -> void:
	if _typing:
		_typing.visible_characters = -1
		_typing = null
		_set_waiting(true)

func show_more(v: bool) -> void:
	_set_waiting(v and _typing == null)

func _set_waiting(v: bool) -> void:
	if is_instance_valid(_waiting_slip):
		_waiting_slip.waiting = v and not choices.visible
		_waiting_slip.queue_redraw()

func _on_scroll_changed() -> void:
	var sb := scroll.get_v_scroll_bar()
	if sb.max_value != _last_scroll_max:
		_last_scroll_max = sb.max_value
		scroll.scroll_vertical = int(sb.max_value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()

# ------------------------------------------------------------------ a slip

class Slip extends MarginContainer:
	var entry: Dictionary = {}
	var body: RichTextLabel
	var kind := "narration"
	var speaker := ""
	var mode := "column"
	var age := 0
	var waiting := false
	var seed := 0.0
	var t := 0.0

	func build(m: String) -> void:
		mode = m
		kind = entry.get("kind", "narration")
		speaker = entry.get("speaker", "")
		seed = float(hash(str(entry.get("text", "")) + kind) % 1000)
		mouse_filter = Control.MOUSE_FILTER_PASS
		body = RichTextLabel.new()
		body.bbcode_enabled = true
		body.fit_content = true
		body.scroll_active = false
		body.selection_enabled = false
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(body)
		restyle()
		resized.connect(func(): pivot_offset = Vector2(0, size.y))

	func _process(d: float) -> void:
		if waiting:
			t += d
			queue_redraw()

	func arrive_anim() -> void:
		if Settings.reduced_motion:
			return
		modulate.a = 0.0
		scale = Vector2(0.97, 0.97)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
		tw.tween_property(self, "scale", Vector2.ONE, 0.32)

	func update_age() -> void:
		var k := clampf(1.0 - minf(age, 6) * 0.085, 0.45, 1.0)
		if kind in ["think", "sound"] or Settings.clean_text:
			self_modulate = Color(1, 1, 1, 1)
			modulate = Color(1, 1, 1, clampf(1.0 - minf(age, 6) * 0.1, 0.4, 1.0))
		else:
			modulate = Color(k, k, k * 0.98, 1.0)

	func restyle() -> void:
		if body == null:
			return
		var clean := Settings.clean_text
		var fs := Settings.font_size()
		var t_text := Kit.esc_bb(str(entry.get("text", "")))
		var m := Vector4(18, 14, 18, 14)  # left, top, right, bottom
		var col := Color("2b241f")
		var kind_font := "prose"
		body.remove_theme_constant_override("outline_size")
		rotation = 0.0 if clean else (Kit.rnd(seed) - 0.5) * 0.01
		if clean:
			body.text = Feed.format(entry)
			col = Kit.IVORY
			m = Vector4(4, 4, 4, 4)
		else:
			match kind:
				"say", "echo":
					m.y = 46
					body.text = t_text if kind == "say" else "“" + t_text + "”"
				"think":
					col = Color("f0a698")
					kind_font = "prose_i"
					m = Vector4(22, 4, 6, 6)
					body.add_theme_constant_override("outline_size", 7)
					body.add_theme_color_override("font_outline_color", Color(0.9, 0.2, 0.15, 0.16))
					body.text = t_text
				"sound":
					col = Color("c4e2cf")
					kind_font = "prose_i"
					m = Vector4(34, 9, 16, 10)
					body.text = t_text
				"sms":
					col = Color("27273a")
					kind_font = "dotline"
					m = Vector4(34, 42, 30, 14)
					body.text = t_text
				"doc":
					col = Color("3a3226")
					kind_font = "prose_i"
					body.text = t_text
				_:
					body.text = t_text
		add_theme_constant_override("margin_left", int(m.x))
		add_theme_constant_override("margin_top", int(m.y))
		add_theme_constant_override("margin_right", int(m.z))
		add_theme_constant_override("margin_bottom", int(m.w))
		for k in ["normal_font", "bold_font", "italics_font"]:
			body.add_theme_font_override(k, Kit.font(kind_font if not clean else ("prose_i" if kind in ["think", "sound"] else "prose")))
		if clean:
			body.add_theme_font_override("bold_font", Kit.font("prose_b"))
			body.add_theme_font_override("italics_font", Kit.font("prose_i"))
		for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
			body.add_theme_font_size_override(k, fs if kind != "sms" else fs - 3)
		body.add_theme_color_override("default_color", col)
		update_age()
		queue_redraw()

	func _draw() -> void:
		if Settings.clean_text:
			return
		var r := Rect2(Vector2.ZERO, size)
		match kind:
			"think":
				# Ari's own voice: no paper, a thread of the red cord beside it
				draw_line(Vector2(7, 4), Vector2(7, size.y - 4), Color(Kit.CORD_DK, 0.9), 4.0)
				draw_line(Vector2(7, 4), Vector2(7, size.y - 4), Color(Kit.CORD, 0.9), 2.4)
				draw_line(Vector2(6, 4), Vector2(6, size.y - 4), Color(1, 0.6, 0.5, 0.35), 0.8)
			"sound":
				var tape := Rect2(4, 2, size.x - 8, size.y - 4)
				draw_rect(Rect2(tape.position + Vector2(2, 3), tape.size), Color(0, 0, 0, 0.35))
				draw_rect(tape, Color("1b2621"))
				draw_rect(Rect2(tape.position, Vector2(tape.size.x, tape.size.y * 0.4)), Color(1, 1, 1, 0.05))
				Kit.text(self, Vector2(14, 12 + Settings.font_size() * 0.8), "≈", "prose_b", Settings.font_size(), Color("7fb89a"))
			"sms":
				Kit.paper(self, r.grow(-2), Color("eee8d6"), 0.12, seed)
				for y in range(10, int(size.y) - 4, 18):
					draw_circle(Vector2(12, y), 4.0, Color("171412"))
					draw_circle(Vector2(size.x - 12, y), 4.0, Color("171412"))
				Kit.stamp(self, Vector2(30, 8), Kit.speaker_name(speaker) + "  ·  printed", Kit.speaker_ink(speaker), 15, -0.02, false, Color("eee8d6"))
			_:
				var pc := Kit.PAPER
				if kind == "echo":
					pc = Color("ead8a8")
				elif kind == "doc":
					pc = Color("e2d9c0")
				Kit.paper(self, r.grow(-2), pc, 0.14 if age == 0 else 0.05, seed)
				if kind == "echo":
					for y in range(8, int(size.y) - 4, 12):
						draw_circle(Vector2(2, y), 3.0, Color("1c1411"))
				if kind == "say" or kind == "echo":
					var who := speaker if kind == "say" else "ARI"
					Kit.stamp(self, Vector2(14, 8), Kit.speaker_name(who), Kit.speaker_ink(who), 20, (Kit.rnd(seed, 2.0) - 0.5) * 0.08, true, pc)
				if kind == "doc":
					var cx := size.x - 38
					draw_arc(Vector2(cx, 6), 7, PI, TAU, 10, Color("8a8a8e"), 2.0)
					draw_line(Vector2(cx - 7, 6), Vector2(cx - 7, 28), Color("8a8a8e"), 2.0)
					draw_line(Vector2(cx + 7, 6), Vector2(cx + 7, 22), Color("8a8a8e"), 2.0)
		if waiting and not Settings.reduced_motion:
			var on := fmod(t, 1.0) < 0.6
			Kit.lamp(self, Vector2(size.x - 16, size.y - 14), 5.0, Kit.RED, on)
		elif waiting:
			Kit.lamp(self, Vector2(size.x - 16, size.y - 14), 5.0, Kit.RED, true)
