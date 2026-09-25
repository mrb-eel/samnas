class_name Overlays
extends RefCounted
## Full-screen cards and viewers. Each is a Control that emits `done`.

static func dim_bg(parent: Control, alpha: float = 0.86) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.04, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(bg)
	return bg

## Chapter card: number, title, a line of paper. Click or key to continue.
class ChapterCard extends Control:
	signal done()
	var num := 1
	var title := ""
	var t := 0.0
	var paper: Texture2D
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		if ResourceLoader.exists("res://assets/ui/paper.png"):
			paper = load("res://assets/ui/paper.png")
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var a := 1.0 if Settings.reduced_motion else clampf(t * 1.5, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.03, 0.04, 1.0))
		var card := Rect2(size.x / 2 - 300, size.y / 2 - 150, 600, 300)
		if paper:
			draw_texture_rect(paper, card, false, Color(1, 1, 1, a))
		else:
			draw_rect(card, Color(Kit.IVORY, a))
		draw_rect(card.grow(-12), Color(Kit.INK, 0.55 * a), false, 1.0)
		draw_rect(card.grow(-16), Color(Kit.INK, 0.35 * a), false, 1.0)
		var f := Kit.font("display")
		var roman: String = ["", "I", "II", "III", "IV", "V", "VI"][clampi(num, 0, 6)]
		var s1 := "Chapter " + roman if num > 0 else ""
		var w1 := f.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f, Vector2(size.x / 2 - w1 / 2, card.position.y + 105), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(Kit.RED.darkened(0.2), a))
		var w2 := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		draw_string(f, Vector2(size.x / 2 - w2 / 2, card.position.y + 175), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(Kit.INK, a))
		if t > 1.2 or Settings.reduced_motion:
			var hint := "click to continue"
			var fh := Kit.font("italic")
			var w3 := fh.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(fh, Vector2(size.x / 2 - w3 / 2, card.end.y - 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Kit.INK, 0.6 * a))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and t > 0.4:
			done.emit()
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("advance") and t > 0.4:
			done.emit()
			get_viewport().set_input_as_handled()

## Drift: the clock jumps. Nothing hurts. Minutes are just gone.
class DriftCard extends Control:
	signal done()
	var from := ""
	var to := ""
	var t := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		Audio.sfx("relay_burst")
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.97))
		var f := Kit.font("display")
		var show_to := t > 1.1 or Settings.reduced_motion
		var s := to if show_to else from
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
		var col := Kit.IVORY if show_to else Color(Kit.IVORY_DIM, 0.6)
		draw_string(f, Vector2(size.x / 2 - w / 2, size.y / 2 + 20), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, col)
		if show_to:
			var cap := "[the line closes; nothing holds you; minutes go missing]"
			var fi := Kit.font("italic")
			var w2 := fi.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(fi, Vector2(size.x / 2 - w2 / 2, size.y / 2 + 70), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("79a88c"))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (t > 1.2 or Settings.reduced_motion):
			done.emit()
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("advance") and (t > 1.2 or Settings.reduced_motion):
			done.emit()
			get_viewport().set_input_as_handled()

## A paper or picture, with a clean transcript beside it.
class DocViewer extends Control:
	signal done()
	var doc_id := ""
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Overlays.dim_bg(self, 0.9)
		var d: Dictionary = Game.docs_def.get(doc_id, {})
		var img := TextureRect.new()
		var path: String = d.get("image", "")
		if path != "" and ResourceLoader.exists(path):
			img.texture = load(path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.position = Vector2(40, 50)
		img.size = Vector2(700, 620)
		add_child(img)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Kit.flat(Color(0.05, 0.05, 0.06, 1), Color(Kit.IVORY_DIM, 0.4), 1, 0, 18))
		panel.position = Vector2(770, 50)
		panel.size = Vector2(470, 620)
		add_child(panel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		panel.add_child(vb)
		var title := Kit.label(d.get("title", doc_id), 24, Kit.IVORY, "display")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(title)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vb.add_child(sc)
		var tr := Kit.label(d.get("text", ""), Settings.font_size() - 2, Kit.IVORY)
		tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tr.custom_minimum_size = Vector2(420, 0)
		sc.add_child(tr)
		var b := Kit.button("Put it down", 18)
		b.pressed.connect(func(): done.emit())
		vb.add_child(b)
		b.call_deferred("grab_focus")
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			done.emit()
			get_viewport().set_input_as_handled()

## Name entry for registration.
class NameInput extends Control:
	signal done(value: String)
	var prompt := ""
	var default_value := "Ari"
	var edit: LineEdit
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Overlays.dim_bg(self, 0.9)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Kit.flat(Color(0.06, 0.06, 0.07), Kit.IVORY_DIM, 1, 0, 26))
		p.position = Vector2(340, 220)
		p.size = Vector2(600, 260)
		add_child(p)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 14)
		p.add_child(vb)
		var l := Kit.label(prompt, 20, Kit.IVORY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
		edit = LineEdit.new()
		edit.text = default_value
		edit.max_length = 24
		edit.add_theme_font_override("font", Kit.font("text"))
		edit.add_theme_font_size_override("font_size", 26)
		edit.select_all_on_focus = true
		vb.add_child(edit)
		var b := Kit.button("Write it in", 18)
		b.pressed.connect(_ok)
		edit.text_submitted.connect(func(_t): _ok())
		vb.add_child(b)
		edit.call_deferred("grab_focus")
	func _ok() -> void:
		var v := edit.text.strip_edges()
		if v == "":
			v = default_value
		done.emit(v)

## The Casio. Nobody needs Ari to play it.
class Casio extends Control:
	signal done(resolved: bool, played: int)
	const NOTES := ["A4", "B4", "C#5", "D5", "E5", "F#5", "G#5", "A5"]
	const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	var history: Array = []
	var played := 0
	var resolved := false
	var lit := -1
	var lit_t := 0.0
	var leave: Button
	var t := 0.0
	var note_label := ""
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		leave = Kit.button("Put it down", 18)
		leave.position = Vector2(560, 610)
		leave.size = Vector2(160, 44)
		leave.visible = false
		leave.pressed.connect(func(): done.emit(resolved, played))
		add_child(leave)
	func _process(d: float) -> void:
		t += d
		lit_t -= d
		if t > 6.0 and not leave.visible:
			leave.visible = true
		queue_redraw()
	func _key_rect(i: int) -> Rect2:
		return Rect2(size.x / 2 - 360 + i * 90, size.y / 2 - 40, 84, 230)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.72))
		var body := Rect2(size.x / 2 - 400, size.y / 2 - 140, 800, 360)
		draw_rect(body, Color("2b2a2e"))
		draw_rect(body.grow(-6), Color("37353b"))
		draw_rect(Rect2(body.position + Vector2(24, 22), Vector2(220, 46)), Color("7f9a78"))
		draw_string(Kit.font("bold"), body.position + Vector2(34, 54), note_label if note_label != "" else "CASIO  SA-21", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("22301f"))
		draw_string(Kit.font("italic"), body.position + Vector2(270, 50), "Inez's label: TEST TONES. DON'T.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c8c0b0"))
		for i in NOTES.size():
			var r := _key_rect(i)
			var col := Color("ece6d6")
			if i == lit and lit_t > 0.0:
				col = Color("f7c9b8")
			draw_rect(r, col)
			draw_rect(r, Color("1a1a1a"), false, 2.0)
			draw_string(Kit.font("text"), r.position + Vector2(34, r.size.y - 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("555"))
		var hint := "Keys 1 to 8, or click. There is nothing you have to play."
		var fh := Kit.font("italic")
		var w := fh.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(fh, Vector2(size.x / 2 - w / 2, body.end.y + 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.IVORY_DIM)
	func press(i: int) -> void:
		lit = i
		lit_t = 0.25
		played += 1
		note_label = NOTES[i].replace("#", "♯")
		Audio.sfx("casio_" + NOTES[i].replace("#", "s"))
		history.append(NOTES[i])
		if history.size() > 5:
			history = history.slice(history.size() - 5)
		if history == ["E5", "C#5", "D5", "B4", "A4"] or (history.size() >= 2 and history[-2] == "B4" and history[-1] == "A4"):
			resolved = true
		if played >= 1 and not leave.visible:
			leave.visible = true
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for i in NOTES.size():
				if _key_rect(i).has_point(e.position):
					press(i)
			accept_event()
	func _unhandled_key_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo:
			var idx := KEYS.find(e.physical_keycode)
			if idx != -1:
				press(idx)
				get_viewport().set_input_as_handled()

## End of the night.
class EndingCard extends Control:
	signal done()
	var title := ""
	var t := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var a := 1.0 if Settings.reduced_motion else clampf(t * 0.6, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.04, a))
		var f := Kit.font("display")
		var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(f, Vector2(size.x / 2 - w / 2, size.y / 2 - 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Kit.IVORY, a))
		var s2 := "HOLD MY PLACE"
		var w2 := f.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f, Vector2(size.x / 2 - w2 / 2, size.y / 2 + 40), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Kit.RED, a * 0.9))
		if t > 2.5:
			var fi := Kit.font("italic")
			var h := "click to return to the building"
			var w3 := fi.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(fi, Vector2(size.x / 2 - w3 / 2, size.y - 60), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Kit.IVORY_DIM, a))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and t > 2.5:
			done.emit()
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("advance") and t > 2.5:
			done.emit()
			get_viewport().set_input_as_handled()

## Brief notification for a text or voicemail that arrives while the phone is away.
class Toast extends PanelContainer:
	var life := 4.0
	func setup(title: String, body: String) -> void:
		add_theme_stylebox_override("panel", Kit.flat(Color(0.07, 0.07, 0.08, 0.96), Kit.RED, 1, 3, 10))
		var vb := VBoxContainer.new()
		add_child(vb)
		vb.add_child(Kit.label(title, 14, Kit.RED.lightened(0.3), "bold"))
		var l := Kit.label(body, 15, Kit.IVORY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		vb.add_child(l)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		life -= d
		if life < 0.6:
			modulate.a = maxf(life / 0.6, 0.0)
		if life <= 0.0:
			queue_free()
