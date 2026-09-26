class_name Overlays
extends RefCounted
## Full-screen cards and viewers. Each is a Control that emits `done`.

static func dim(ci: CanvasItem, size: Vector2, a: float = 0.88) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.01, a))
	Grim.dither(ci, Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), 2)

static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]

## A chapter title, stencilled, coming in on a bad signal.
class ChapterCard extends Control:
	signal done()
	var num := 1
	var title := ""
	var t := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("050505"))
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var ready_ := Settings.reduced_motion or t > 0.5
		# a strip of steel across the dark, the title stencilled on it
		var strip := Rect2(0, cy - 34, size.x, 68)
		if ready_:
			Grim.plate(self, strip, "rust", float(num) * 11.0, false, Color(0.75, 0.72, 0.7))
			draw_rect(Rect2(0, strip.position.y, size.x, 2), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(0, strip.end.y - 2, size.x, 2), Color(0, 0, 0, 0.8))
		var label := ("CHAPTER " + Overlays.roman(num)) if num > 0 else ""
		if label != "":
			Grim.glow_text(self, Vector2(0, strip.position.y - 12), label, "scan", 16, Grim.PHOS_MID, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var tsz := 44
		while Grim.text_w(title.to_upper(), "stencil", tsz) > size.x - 60 and tsz > 20:
			tsz -= 4
		var ty := cy + tsz * 0.36
		if ready_:
			Grim.text(self, Vector2(2, ty + 2), title.to_upper(), "stencil", tsz, Color(0, 0, 0, 0.7), size.x, HORIZONTAL_ALIGNMENT_CENTER)
			Grim.text(self, Vector2(0, ty), title.to_upper(), "stencil", tsz, Grim.IVORY, size.x, HORIZONTAL_ALIGNMENT_CENTER)
			var tw := Grim.text_w(title.to_upper(), "stencil", tsz)
			draw_rect(Rect2(round(cx - tw * 0.5), ty + 6, round(tw), 2), Grim.RED)
		Grim.glitch(self, Rect2(Vector2.ZERO, size), t, clampf(1.0 - t * 1.2, 0.0, 1.0))
		var clock: String = Game.pres.get("clock", "")
		if clock != "" and ready_:
			Grim.text(self, Vector2(0, strip.end.y + 22), "FERRIER COURT  /  " + clock, "tiny", 8, Grim.IVORY_DIM, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if (t > 1.2 or Settings.reduced_motion) and int(t * 2.0) % 2 == 0:
			Grim.text(self, Vector2(0, size.y - 20), "CLICK TO GO ON", "tiny", 8, Grim.PHOS_DIM, size.x, HORIZONTAL_ALIGNMENT_CENTER)
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
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.01, 0.97))
		var show_to := t > 1.1 or Settings.reduced_motion
		var s := to if show_to else from
		# a big cheap LCD
		var lr := Rect2(size.x * 0.5 - 110, size.y * 0.5 - 44, 220, 80)
		Grim.plate(self, lr.grow(8), "steel", 3.0)
		Grim.inset(self, lr, Color("2e3a20"))
		draw_rect(lr.grow(-2), Color("3d4a2a"))
		Grim.text(self, Vector2(lr.position.x, lr.end.y - 12), "88:88", "lcd", 80, Color(0, 0, 0, 0.1), lr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if not show_to and int(t * 8.0) % 2 == 1 and not Settings.reduced_motion:
			pass
		else:
			Grim.text(self, Vector2(lr.position.x, lr.end.y - 12), s, "lcd", 80, Color("0c1006"), lr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Grim.glitch(self, Rect2(Vector2.ZERO, size), t, 0.6 if not show_to else 0.1)
		if show_to:
			var cap := "[the line closes; nothing holds you; minutes go missing]"
			Grim.text(self, Vector2(0, lr.end.y + 34), cap, "body", 16, Grim.PHOS_MID, size.x, HORIZONTAL_ALIGNMENT_CENTER)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (t > 1.2 or Settings.reduced_motion):
			done.emit()
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("advance") and (t > 1.2 or Settings.reduced_motion):
			done.emit()
			get_viewport().set_input_as_handled()

## A paper or a picture under a desk lamp, with its words typed out on a
## green screen beside it, because at this resolution handwriting can't be
## trusted to be read.
class DocViewer extends Control:
	signal done()
	var doc_id := ""
	var tex: Texture2D
	var title := ""
	var body := PackedStringArray()
	var zoomed := false
	var uv := Vector2(0.5, 0.35)
	var scroll := 0
	var t := 0.0
	var close_key: GW.Key
	var desk := Rect2(8, 24, 330, 326)
	var screen := Rect2(348, 30, 284, 290)
	const ZOOM := 3.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var d: Dictionary = Game.docs_def.get(doc_id, {})
		var path: String = d.get("image", "")
		if path != "" and ResourceLoader.exists(path):
			tex = load(path)
		title = d.get("title", doc_id)
		body = Grim.wrap_text(d.get("text", ""), "body", Grim.body_size() - 4 if not Grim.plain() else Grim.body_size(), screen.size.x - 16)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		close_key = GW.Key.new("PUT IT DOWN", "ESC")
		close_key.position = Vector2(screen.position.x, screen.end.y + 10)
		close_key.size = Vector2(screen.size.x, 20)
		close_key.pressed.connect(func(): done.emit())
		add_child(close_key)
		close_key.call_deferred("grab_focus")
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _fit() -> Rect2:
		if tex == null:
			return desk.grow(-20)
		var ts := tex.get_size()
		var avail := desk.size - Vector2(28, 28)
		var k := minf(avail.x / ts.x, avail.y / ts.y)
		if zoomed:
			k *= ZOOM
		var sz := ts * k
		var pos := desk.position + (desk.size - sz) * 0.5
		if zoomed:
			pos = desk.position + Vector2(
				lerpf(8.0, desk.size.x - sz.x - 8.0, uv.x) if sz.x > desk.size.x else (desk.size.x - sz.x) * 0.5,
				lerpf(8.0, desk.size.y - sz.y - 8.0, uv.y) if sz.y > desk.size.y else (desk.size.y - sz.y) * 0.5)
		return Rect2(pos.round(), sz.round())
	func _draw() -> void:
		Overlays.dim(self, size, 0.92)
		# the desk: formica under a lamp
		draw_rect(desk, Color("1a1714"))
		var st := Grim.surf("steel")
		if st:
			draw_texture_rect_region(st, desk, Rect2(0, 0, desk.size.x, desk.size.y), Color(0.45, 0.4, 0.34))
		var r := _fit()
		var clip_on := r.size.x > desk.size.x or r.size.y > desk.size.y
		if tex:
			if clip_on:
				# draw only what lands on the desk
				var vis := r.intersection(desk)
				var src := Rect2((vis.position - r.position) / r.size * tex.get_size(), vis.size / r.size * tex.get_size())
				draw_texture_rect_region(tex, vis, src)
			else:
				draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.55))
				draw_texture_rect(tex, r, false)
		# lamp falloff
		for k in 6:
			draw_rect(desk.grow(-k * 6), Color(0, 0, 0, 0.06), false, 6.0)
		Grim.text(self, Vector2(desk.position.x + 4, desk.end.y - 4), "CLICK TO LOOK CLOSER" if not zoomed else "MOVE TO READ ACROSS IT", "tiny", 8, Color(Grim.IVORY_DIM, 0.8))
		# the transcript
		Grim.plate(self, screen.grow(6), "steel", 9.0)
		Grim.crt(self, screen, t)
		var tr := Grim.wrap_text(title.to_upper(), "head", 16, screen.size.x - 16)
		var y := screen.position.y + 14
		for l in tr:
			Grim.glow_text(self, Vector2(screen.position.x + 8, y), l, "head", 16, Grim.PHOS)
			y += 14
		draw_rect(Rect2(screen.position.x + 8, y - 6, screen.size.x - 16, 1), Grim.PHOS_DIM)
		y += 6
		var sz := Grim.body_size() - 4 if not Grim.plain() else Grim.body_size()
		var lh := floorf(Grim.line_h("body", sz) * 0.9)
		var rows := int((screen.end.y - y - 6) / lh)
		scroll = clampi(scroll, 0, maxi(0, body.size() - rows))
		for i in range(scroll, mini(body.size(), scroll + rows)):
			Grim.text(self, Vector2(screen.position.x + 8, y + lh - 4), body[i], "body", sz, Grim.PHOS_MID)
			y += lh
		if body.size() > rows:
			var bar_h := screen.size.y * rows / body.size()
			var by := screen.position.y + (screen.size.y - bar_h) * scroll / maxf(1, body.size() - rows)
			draw_rect(Rect2(screen.end.x - 3, by, 2, bar_h), Grim.PHOS_DIM)
		Grim.crt_glass(self, screen)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT and desk.has_point(e.position):
				zoomed = not zoomed
				uv = ((e.position - desk.position) / desk.size).clamp(Vector2.ZERO, Vector2.ONE)
				Audio.sfx("paper", -10.0)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll += 2
			elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll -= 2
			accept_event()
		elif e is InputEventMouseMotion:
			if zoomed and desk.has_point(e.position):
				uv = ((e.position - desk.position) / desk.size).clamp(Vector2.ZERO, Vector2.ONE)
			if desk.has_point(e.position):
				ScreenFx.want("look")
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			done.emit()
			get_viewport().set_input_as_handled()
		elif e is InputEventKey and e.pressed:
			match e.keycode:
				KEY_Z:
					zoomed = not zoomed
				KEY_DOWN:
					scroll += 1
				KEY_UP:
					scroll -= 1
				KEY_PAGEDOWN:
					scroll += 8
				KEY_PAGEUP:
					scroll -= 8
				KEY_LEFT:
					uv.x = clampf(uv.x - 0.12, 0, 1)
				KEY_RIGHT:
					uv.x = clampf(uv.x + 0.12, 0, 1)
				_:
					return
			get_viewport().set_input_as_handled()

## A name, typed into the register on a green screen.
class NameInput extends Control:
	signal done(value: String)
	var prompt := ""
	var default_value := "Ari"
	var edit: LineEdit
	var t := 0.0
	var screen := Rect2(110, 96, 420, 150)
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		edit = LineEdit.new()
		edit.text = default_value
		edit.max_length = 24
		edit.position = screen.position + Vector2(16, 84)
		edit.size = Vector2(screen.size.x - 32, 24)
		edit.add_theme_font_override("font", Grim.font("body"))
		edit.add_theme_font_size_override("font_size", 24 if not Grim.plain() else 16)
		edit.add_theme_color_override("font_color", Grim.PHOS)
		edit.add_theme_color_override("caret_color", Grim.PHOS)
		edit.add_theme_color_override("selection_color", Color(Grim.PHOS_DIM, 0.6))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("020803")
		sb.border_color = Grim.PHOS_DIM
		sb.set_border_width_all(1)
		sb.content_margin_left = 4
		edit.add_theme_stylebox_override("normal", sb)
		edit.add_theme_stylebox_override("focus", sb)
		edit.select_all_on_focus = true
		edit.caret_blink = true
		add_child(edit)
		var k := GW.Key.new("WRITE IT IN", "ENTER")
		k.position = Vector2(screen.end.x - 150, screen.end.y + 14)
		k.size = Vector2(150, 20)
		k.pressed.connect(_ok)
		add_child(k)
		edit.text_submitted.connect(func(_t): _ok())
		edit.call_deferred("grab_focus")
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		Overlays.dim(self, size, 0.9)
		Grim.plate(self, screen.grow(10), "steel", 21.0)
		Grim.crt(self, screen, t)
		Grim.text(self, screen.position + Vector2(12, 16), "R-1  REGISTRATION OF ARRIVAL", "tiny", 8, Grim.PHOS_DIM)
		var lines := Grim.wrap_text(prompt, "body", Grim.body_size(), screen.size.x - 24)
		var y := screen.position.y + 36
		for l in lines:
			Grim.glow_text(self, Vector2(screen.position.x + 12, y), l, "body", Grim.body_size(), Grim.PHOS)
			y += 16
		Grim.crt_glass(self, screen)
	func _ok() -> void:
		var v := edit.text.strip_edges()
		if v == "":
			v = default_value
		done.emit(v)

## The Casio at the frame. Nobody needs Ari to play it.
class Casio extends Control:
	signal done(resolved: bool, played: int)
	const NOTES := ["A4", "B4", "C#5", "D5", "E5", "F#5", "G#5", "A5"]
	const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	var history: Array = []
	var played := 0
	var resolved := false
	var lit := -1
	var lit_t := 0.0
	var leave: GW.Key
	var t := 0.0
	var note_label := ""
	var hover := -1
	var body := Rect2(70, 80, 500, 200)
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		leave = GW.Key.new("PUT IT DOWN", "ESC")
		leave.position = Vector2(245, 306)
		leave.size = Vector2(150, 20)
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
		return Rect2(body.position.x + 30 + i * 56, body.position.y + 70, 52, 116)
	func _draw() -> void:
		Overlays.dim(self, size, 0.75)
		draw_rect(Rect2(body.position + Vector2(4, 6), body.size), Color(0, 0, 0, 0.6))
		draw_rect(body, Color("1e1d21"))
		draw_rect(body.grow(-3), Color("2b2a2f"))
		draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(body.size.x - 6, 1)), Color(1, 1, 1, 0.1))
		# speaker grille
		for gx in range(0, 120, 4):
			for gy in range(0, 30, 4):
				draw_rect(Rect2(body.end.x - 150 + gx, body.position.y + 18 + gy, 2, 2), Color("121114"))
		# LCD
		var lcd := Rect2(body.position + Vector2(24, 18), Vector2(140, 34))
		Grim.inset(self, lcd, Color("2e3a20"))
		draw_rect(lcd.grow(-2), Color("6f8a60"))
		Grim.text(self, Vector2(lcd.position.x, lcd.end.y - 7), note_label if note_label != "" else "SA-21", "lcd", 28, Color("16200f"), lcd.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Grim.text(self, Vector2(body.position.x + 176, body.position.y + 34), "CASIO", "head", 16, Color("c8c4bc"))
		Grim.tape(self, Vector2(body.position.x + 176, body.position.y + 40), "TEST TONES. DON'T.", 13)
		for i in NOTES.size():
			var r := _key_rect(i)
			var col := Color("e6e0d0")
			if i == hover:
				col = Color("f4efe2")
			if i == lit and lit_t > 0.0:
				col = Color("f7c9b8")
			draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color("0c0c0e"))
			draw_rect(Rect2(r.position + (Vector2(0, 2) if i == lit and lit_t > 0.0 else Vector2.ZERO), r.size), col)
			draw_rect(Rect2(r.position, Vector2(1, r.size.y)), Color(0, 0, 0, 0.3))
			Grim.text(self, Vector2(r.position.x, r.end.y - 8), str(i + 1), "head", 16, Color("5a5650"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Grim.text(self, Vector2(0, body.end.y + 16), "KEYS 1 TO 8, OR CLICK. THERE IS NOTHING YOU HAVE TO PLAY.", "tiny", 8, Grim.IVORY_DIM, size.x, HORIZONTAL_ALIGNMENT_CENTER)
	func press(i: int) -> void:
		lit = i
		lit_t = 0.25
		played += 1
		note_label = NOTES[i]
		Audio.sfx("casio_" + NOTES[i].replace("#", "s"))
		history.append(NOTES[i])
		if history.size() > 5:
			history = history.slice(history.size() - 5)
		if history == ["E5", "C#5", "D5", "B4", "A4"] or (history.size() >= 2 and history[-2] == "B4" and history[-1] == "A4"):
			resolved = true
		if played >= 1 and not leave.visible:
			leave.visible = true
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = -1
			for i in NOTES.size():
				if _key_rect(i).has_point(e.position):
					hover = i
			if hover >= 0:
				ScreenFx.want("use")
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
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
			elif e.physical_keycode == KEY_ESCAPE and leave.visible:
				done.emit(resolved, played)
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
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.015, 0.015, a))
		var tsz := 32
		while Grim.text_w(title.to_upper(), "stencil", tsz) > size.x - 60 and tsz > 16:
			tsz -= 2
		Grim.text(self, Vector2(0, size.y * 0.5 - 6), title.to_upper(), "stencil", tsz, Color(Grim.IVORY, a), size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Grim.text(self, Vector2(0, size.y * 0.5 + 22), "HOLD MY PLACE", "head", 16, Color(Grim.RED, a * 0.9), size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if t > 2.5 and int(t * 2.0) % 2 == 0:
			Grim.text(self, Vector2(0, size.y - 24), "CLICK TO GO BACK TO THE BUILDING", "tiny", 8, Color(Grim.IVORY_DIM, a), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and t > 2.5:
			done.emit()
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("advance") and t > 2.5:
			done.emit()
			get_viewport().set_input_as_handled()
