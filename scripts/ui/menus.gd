class_name Menus
extends RefCounted
## Title, pause, save/load, settings and the text history.

static func panel(parent: Control, rect: Rect2, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.flat(Color(0.055, 0.05, 0.06, 0.98), Color(Kit.IVORY_DIM, 0.45), 1, 0, 24))
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	if title != "":
		vb.add_child(Kit.label(title, 30, Kit.IVORY, "display"))
	return vb

class Title extends Control:
	signal action(what: String)
	var t := 0.0
	var paper: Texture2D
	var art: Texture2D
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		if ResourceLoader.exists("res://assets/ui/title_art.png"):
			art = load("res://assets/ui/title_art.png")
		var vb := VBoxContainer.new()
		vb.position = Vector2(96, 330)
		vb.size = Vector2(300, 300)
		vb.add_theme_constant_override("separation", 10)
		add_child(vb)
		var items := [["New night", "new"]]
		if Game.has_any_save():
			items.insert(0, ["Continue", "continue"])
			items.append(["Load", "load"])
		items.append(["Settings", "settings"])
		items.append(["Quit", "quit"])
		var first: Button = null
		for it in items:
			var b := Kit.button(it[0], 22)
			b.custom_minimum_size = Vector2(260, 46)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var what: String = it[1]
			b.pressed.connect(func(): action.emit(what))
			vb.add_child(b)
			if first == null:
				first = b
		first.call_deferred("grab_focus")
		if not Game.story_ok:
			var err := Kit.label("Story failed to load:\n" + "\n".join(Game.load_errors.slice(0, 6)), 14, Kit.RED)
			err.position = Vector2(96, 620)
			err.size = Vector2(1100, 90)
			err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(err)
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0d0c10"))
		if art:
			var h := size.y
			var w := h * art.get_width() / art.get_height()
			draw_texture_rect(art, Rect2(size.x - w, 0, w, h), false)
			# fade the art into the dark on the left
			for i in 60:
				var x := size.x - w + i * 6
				draw_rect(Rect2(x, 0, 6, h), Color(0.05, 0.047, 0.063, 1.0 - i / 60.0))
		var f := Kit.font("display")
		draw_string(f, Vector2(92, 190), "Hold My Place", HORIZONTAL_ALIGNMENT_LEFT, -1, 76, Kit.IVORY)
		draw_string(Kit.font("italic"), Vector2(98, 240), "One night at Ferrier Court. The overnight service closes at six.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Kit.IVORY_DIM)
		draw_rect(Rect2(96, 262, 180, 3), Kit.RED)

class Pause extends Control:
	signal action(what: String)
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Overlays.dim_bg(self, 0.75)
		var vb := Menus.panel(self, Rect2(460, 150, 360, 430), "Paused")
		var first: Button = null
		for it in [["Back to the night", "resume"], ["Save", "save"], ["Load", "load"], ["Text history", "log"], ["Settings", "settings"], ["Title screen", "title"], ["Quit", "quit"]]:
			var b := Kit.button(it[0], 19)
			var what: String = it[1]
			b.pressed.connect(func(): action.emit(what))
			vb.add_child(b)
			if first == null:
				first = b
		first.call_deferred("grab_focus")
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			action.emit("resume")
			get_viewport().set_input_as_handled()

class SaveLoad extends Control:
	signal closed()
	signal picked(slot: int)
	var saving := true
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Overlays.dim_bg(self, 0.85)
		var vb := Menus.panel(self, Rect2(240, 50, 800, 620), "Save the night" if saving else "Load")
		var note := Kit.label("Slot 0 is the autosave, written at each chapter and when you leave." if not saving else "Saving keeps everything exactly where it is: messages, promises, what people know.", 15, Kit.IVORY_DIM, "italic")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(note)
		var first: Button = null
		for slot in range(0 if not saving else 1, 7):
			var d := Game.read_save(slot)
			var label := "Slot %d   —   empty" % slot
			if not d.is_empty():
				var p: Dictionary = d.get("pres", {})
				var ch := int(p.get("chapter", 0))
				var last := ""
				var bl: Array = d.get("backlog", [])
				if bl.size() > 0:
					last = str(bl[-1].get("text", ""))
					if last.length() > 60:
						last = last.substr(0, 57) + "..."
				label = "Slot %d   %s   ch.%d %s   %s\n      “%s”" % [slot, "AUTO" if slot == 0 else "", ch, p.get("chapter_title", ""), p.get("clock", ""), last]
			var b := Kit.button(label, 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 62)
			b.disabled = (not saving) and d.is_empty()
			var s: int = slot
			b.pressed.connect(func(): picked.emit(s))
			vb.add_child(b)
			if first == null and not b.disabled:
				first = b
		var back := Kit.button("Back", 18)
		back.pressed.connect(func(): closed.emit())
		vb.add_child(back)
		if first:
			first.call_deferred("grab_focus")
		else:
			back.call_deferred("grab_focus")
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			closed.emit()
			get_viewport().set_input_as_handled()

class SettingsMenu extends Control:
	signal closed()
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Overlays.dim_bg(self, 0.85)
		var vb := Menus.panel(self, Rect2(290, 30, 700, 660), "Settings")
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vb.add_child(sc)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 24)
		g.add_theme_constant_override("v_separation", 10)
		sc.add_child(g)
		var ts := OptionButton.new()
		for i in Settings.TEXT_SIZE_NAMES.size():
			ts.add_item(Settings.TEXT_SIZE_NAMES[i], i)
		ts.selected = Settings.text_size
		ts.item_selected.connect(func(i): Settings.set_and_save("text_size", i))
		_row(g, "Text size", ts)
		_row(g, "Text speed", _slider(Settings.text_speed, func(v): Settings.set_and_save("text_speed", v)))
		_row(g, "Instant text", _check(Settings.instant_text, func(v): Settings.set_and_save("instant_text", v)))
		_row(g, "Clean text (plain panels, no texture behind words)", _check(Settings.clean_text, func(v): Settings.set_and_save("clean_text", v)))
		_row(g, "Reduced motion", _check(Settings.reduced_motion, func(v): Settings.set_and_save("reduced_motion", v)))
		_row(g, "Captions for background sound", _check(Settings.ambient_captions, func(v): Settings.set_and_save("ambient_captions", v)))
		_row(g, "Master volume", _slider(Settings.master_vol, func(v): Settings.set_and_save("master_vol", v)))
		_row(g, "Music", _slider(Settings.music_vol, func(v): Settings.set_and_save("music_vol", v)))
		_row(g, "Effects", _slider(Settings.sfx_vol, func(v): Settings.set_and_save("sfx_vol", v)))
		_row(g, "Rooms and lines", _slider(Settings.amb_vol, func(v): Settings.set_and_save("amb_vol", v)))
		_row(g, "Fullscreen", _check(Settings.fullscreen, func(v): Settings.set_and_save("fullscreen", v)))
		var keys := Kit.label("Keys: Space/Enter continue · 1–9 choose · P or Tab phone · L history · F5 quicksave · F9 quickload · Esc menu", 14, Kit.IVORY_DIM, "italic")
		keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(keys)
		var back := Kit.button("Done", 18)
		back.pressed.connect(func(): closed.emit())
		vb.add_child(back)
		ts.call_deferred("grab_focus")
	func _row(g: GridContainer, name: String, ctl: Control) -> void:
		var l := Kit.label(name, 17, Kit.IVORY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(330, 0)
		g.add_child(l)
		ctl.custom_minimum_size = Vector2(260, 30)
		g.add_child(ctl)
	func _slider(v: float, cb: Callable) -> HSlider:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = v
		s.value_changed.connect(cb)
		return s
	func _check(v: bool, cb: Callable) -> CheckButton:
		var c := CheckButton.new()
		c.button_pressed = v
		c.toggled.connect(cb)
		return c
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			closed.emit()
			get_viewport().set_input_as_handled()

class Backlog extends Control:
	signal closed()
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Overlays.dim_bg(self, 0.92)
		var vb := Menus.panel(self, Rect2(170, 30, 940, 660), "What was said")
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vb.add_child(sc)
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_theme_font_override("normal_font", Kit.font("text"))
		r.add_theme_font_override("bold_font", Kit.font("display"))
		r.add_theme_font_override("italics_font", Kit.font("italic"))
		for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
			r.add_theme_font_size_override(k, Settings.font_size() - 1)
		var parts: PackedStringArray = []
		var last_clock := ""
		for e in Game.backlog:
			if e.get("clock", "") != last_clock:
				last_clock = e.get("clock", "")
				parts.append("[color=#6f6a60]— %s —[/color]" % last_clock)
			parts.append(Feed.format(e))
		r.text = "\n\n".join(parts)
		sc.add_child(r)
		var back := Kit.button("Close (L)", 18)
		back.pressed.connect(func(): closed.emit())
		vb.add_child(back)
		back.call_deferred("grab_focus")
		sc.call_deferred("set", "scroll_vertical", 1000000)
		await get_tree().process_frame
		await get_tree().process_frame
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu") or e.is_action_pressed("log"):
			closed.emit()
			get_viewport().set_input_as_handled()
