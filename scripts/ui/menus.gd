class_name Menus
extends RefCounted
## The title, the pause panel, the register of saves, the fuse board of
## settings, and the transcript. Same materials as everything else: steel,
## bakelite, a green screen, red buttons.

## Behind a menu: whatever was on screen, darkened and dithered.
class Backdrop extends Control:
	var a := 0.72
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		size = get_parent().size if get_parent() is Control else Vector2(640, 360)
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.01, a))
		Grim.dither(self, Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5), 2)

static func column(parent: Control, pos: Vector2, width: float, keys: Array) -> Array:
	var out: Array = []
	var y := pos.y
	for k in keys:
		var key := GW.Key.new(k[0], k[1] if k.size() > 1 else "")
		key.position = Vector2(pos.x, y)
		key.size = Vector2(width, 20)
		parent.add_child(key)
		out.append(key)
		y += 24
	for i in out.size():
		out[i].focus_neighbor_top = out[i].get_path_to(out[(i - 1 + out.size()) % out.size()])
		out[i].focus_neighbor_bottom = out[i].get_path_to(out[(i + 1) % out.size()])
	return out

# ------------------------------------------------------------------ title

## The dry pool at the bottom of the building, the chair in the deep end,
## the phone on the chair. The name of the thing, stencilled. A column of
## keys.
class Title extends Control:
	signal action(what: String)
	var t := 0.0
	var vp: SubViewport
	var view: SubViewportContainer
	var keys: Array = []
	var going := ""
	var go_t := 0.0
	var _ink: Control
	var _shutter: Control
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		view = SubViewportContainer.new()
		view.stretch = true
		view.stretch_shrink = 2
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/stage_post.gdshader")
		m.set_shader_parameter("levels", 8.0)
		m.set_shader_parameter("grain", 0.07)
		view.material = m
		add_child(view)
		m.set_shader_parameter("lift", Vector3(0.02, 0.025, 0.03))
		var ink := Control.new()
		ink.set_anchors_preset(Control.PRESET_FULL_RECT)
		ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink.draw.connect(func(): _paint(ink))
		add_child(ink)
		_ink = ink
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_DISABLED
		view.add_child(vp)
		var s: SetBase = load("res://scripts/sets/set_pool.gd").new()
		vp.add_child(s)
		s.build("")
		var c := s.cam("title")
		if c:
			c.current = true
			s.on_cam("title")
		var has_save := Game.has_any_save()
		var items := [["NEW NIGHT", ""], ["CARRY ON", ""], ["THE REGISTER", ""], ["FUSE BOARD", ""], ["HANG UP", ""]]
		keys = Menus.column(self, Vector2(40, 214), 150, items)
		var acts := ["new", "continue", "load", "settings", "quit"]
		for i in keys.size():
			var what: String = acts[i]
			keys[i].pressed.connect(func(): _go(what))
		keys[1].disabled = not has_save
		keys[2].disabled = not has_save
		var shutter := Control.new()
		shutter.set_anchors_preset(Control.PRESET_FULL_RECT)
		shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shutter.draw.connect(func():
			if going != "":
				shutter.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(go_t * 3.0, 0.0, 1.0))))
		add_child(shutter)
		_shutter = shutter
		var first: Control = keys[1] if has_save else keys[0]
		first.call_deferred("grab_focus")
		Audio.sfx("relay_burst", -12.0)
	func _go(what: String) -> void:
		if going != "":
			return
		going = what
		go_t = 0.0
		Audio.sfx("plug_in", -2.0)
	func _process(d: float) -> void:
		t += d
		if going != "":
			go_t += d
			if go_t > (0.05 if Settings.reduced_motion else 0.35):
				var g := going
				going = ""
				action.emit(g)
		if _ink:
			_ink.queue_redraw()
		if _shutter:
			_shutter.queue_redraw()
	func _paint(c: Control) -> void:
		# the title over the pool, a band of dark for it to sit on
		Grim.dither(c, Rect2(0, 0, size.x, 118), Color(0, 0, 0, 0.6), 2)
		var title := "HOLD MY PLACE"
		var x := 36.0
		var y := 86.0
		Grim.text(c, Vector2(x + 2, y + 3), title, "stencil", 52, Color(0, 0, 0, 0.75))
		Grim.text(c, Vector2(x, y), title, "stencil", 52, Grim.IVORY)
		var tw := Grim.text_w(title, "stencil", 52)
		c.draw_rect(Rect2(x, y + 7, tw, 3), Grim.RED)
		Grim.text(c, Vector2(x + 1, y + 24), "ONE NIGHT AT FERRIER COURT, ABOVE THE OLD BATHS", "tiny", 8, Grim.IVORY_DIM)
		# the keys sit on a strip of steel
		Grim.plate(c, Rect2(30, 204, 170, 128), "steel", 2.0)
		Grim.band(c, Rect2(30, 338, 380, 12), 0.7)
		Grim.text(c, Vector2(36, 347), "CLICK TO WALK.  H SHOWS WHAT YOU CAN TOUCH.  TAB: THE BOARD.", "tiny", 8, Color(Grim.IVORY_DIM, 0.9))
		if not Game.story_ok:
			var err := "STORY FAILED TO LOAD: " + " / ".join(Game.load_errors.slice(0, 3))
			Grim.para(c, Vector2(230, 220), err, "body", 16, Grim.RED, 390)
		Grim.glitch(c, Rect2(Vector2.ZERO, size), t, 0.15 if fmod(t, 7.0) < 0.3 else 0.0)
	func _draw() -> void:
		pass
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ pause

## ON HOLD: the night stops while this is up.
class Pause extends Control:
	signal action(what: String)
	var t := 0.0
	var keys: Array = []
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var bd := Backdrop.new()
		add_child(bd)
		var items := [["BACK TO IT", "ESC"], ["SAVE", ""], ["LOAD", ""], ["TRANSCRIPT", "L"], ["FUSE BOARD", ""], ["TO THE TITLE", ""], ["HANG UP", ""]]
		keys = Menus.column(self, Vector2(236, 118), 168, items)
		var acts := ["resume", "save", "load", "log", "settings", "title", "quit"]
		for i in keys.size():
			var what: String = acts[i]
			keys[i].pressed.connect(func(): _pick(what))
		keys[0].call_deferred("grab_focus")
		Audio.sfx("hold_on", -10.0)
	func _pick(what: String) -> void:
		if what == "resume":
			action.emit("resume")
		else:
			action.emit(what)
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(220, 64, 200, 234)
		Grim.plate(self, r, "steel", 4.0)
		Grim.text(self, Vector2(r.position.x, r.position.y + 30), "ON HOLD", "stencil", 26, Grim.IVORY, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Grim.lamp(self, Vector2(r.position.x + 18, r.position.y + 20), Grim.AMBER, int(t * 1.5) % 2 == 0 or Settings.reduced_motion, 2)
		Grim.lamp(self, Vector2(r.end.x - 18, r.position.y + 20), Grim.AMBER, int(t * 1.5) % 2 == 1 or Settings.reduced_motion, 2)
		var info := "%s   %s" % [Game.pres.get("clock", ""), str(Game.pres.get("chapter_title", "")).to_upper()]
		Grim.text(self, Vector2(r.position.x, r.position.y + 44), info, "tiny", 8, Grim.IVORY_DIM, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			action.emit("resume")
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ saves

## The Receiving Register: each save is a line in the ledger, with a small
## picture of the night as it was.
class SaveLoad extends Control:
	signal closed()
	signal picked(slot: int)
	var saving := true
	var rows: Array = []
	var hover := -1
	var sel := 1
	var t := 0.0
	var writing := -1
	var write_t := 0.0
	var back: GW.Key
	const SLOT_NAMES := {0: "AUTO", 6: "QUICK"}
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		for slot in range(0, 7):
			var d := Game.read_save(slot)
			var thumb: Texture2D = null
			var tp := Game.thumb_path(slot)
			if FileAccess.file_exists(tp):
				var img := Image.load_from_file(tp)
				if img:
					thumb = ImageTexture.create_from_image(img)
			var col := slot % 2
			var row := slot / 2
			var r := Rect2(24 + col * 302, 52 + row * 70, 290, 62)
			rows.append({"slot": slot, "data": d, "thumb": thumb, "rect": r})
		back = GW.Key.new("BACK", "ESC")
		back.position = Vector2(326, 262)
		back.size = Vector2(290, 20)
		back.pressed.connect(func(): closed.emit())
		add_child(back)
		sel = 1 if saving else _first_filled()
		Audio.sfx("paper", -6.0)
	func _first_filled() -> int:
		for i in rows.size():
			if not rows[i]["data"].is_empty():
				return i
		return 0
	func _usable(i: int) -> bool:
		if saving:
			return i != 0
		return not rows[i]["data"].is_empty()
	func _process(d: float) -> void:
		t += d
		if writing >= 0:
			write_t += d
			if write_t > (0.1 if Settings.reduced_motion else 0.6):
				var s := writing
				writing = -1
				picked.emit(s)
		queue_redraw()
	func _activate(i: int) -> void:
		if writing >= 0 or not _usable(i):
			return
		sel = i
		writing = rows[i]["slot"]
		write_t = 0.0
		Audio.sfx("stamp" if saving else "paper", -4.0)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("070706"))
		Grim.dither(self, Rect2(Vector2.ZERO, size), Color(0.1, 0.09, 0.08, 0.5), 3)
		Grim.text(self, Vector2(24, 38), "THE RECEIVING REGISTER", "stencil", 24, Grim.IVORY)
		Grim.text(self, Vector2(24 + Grim.text_w("THE RECEIVING REGISTER", "stencil", 24) + 10, 38), "SAVE THE NIGHT" if saving else "PICK UP WHERE YOU LEFT IT", "tiny", 8, Grim.AMBER)
		for i in rows.size():
			var row: Dictionary = rows[i]
			var r: Rect2 = row["rect"]
			var d: Dictionary = row["data"]
			var usable := _usable(i)
			var hot := (i == hover or i == sel) and usable
			Grim.plate(self, r, "steel", float(i) * 3.0, false, Color(1, 1, 1) if usable else Color(0.55, 0.55, 0.55))
			var tr := Rect2(r.position + Vector2(6, 6), Vector2(89, 50))
			Grim.crt(self, tr, t + i)
			if row["thumb"] and not d.is_empty():
				draw_texture_rect(row["thumb"], tr, false, Color(0.85, 1.0, 0.85))
				Grim.crt_glass(self, tr)
			var label: String = SLOT_NAMES.get(row["slot"], "No. %d" % row["slot"])
			Grim.text(self, Vector2(r.position.x + 102, r.position.y + 17), label, "head", 16, Grim.AMBER if hot else Grim.AMBER_DIM)
			if d.is_empty():
				Grim.text(self, Vector2(r.position.x + 102, r.position.y + 36), "EMPTY LINE", "body", 16, Grim.IVORY_DIM)
			else:
				var p: Dictionary = d.get("pres", {})
				var ch := "%s  %s" % [p.get("clock", ""), str(p.get("chapter_title", "")).to_upper()]
				Grim.text(self, Vector2(r.position.x + 102, r.position.y + 34), ch, "body", 16, Grim.IVORY)
				var at := str(d.get("saved_at", "")).replace("T", " ")
				Grim.text(self, Vector2(r.position.x + 102, r.position.y + 50), "WRITTEN " + at.substr(0, 16), "tiny", 8, Grim.IVORY_DIM)
			if hot:
				draw_rect(r.grow(1), Color(Grim.AMBER, 0.8), false, 1.0)
			if writing == row["slot"]:
				var sc := clampf(write_t * 4.0, 0.0, 1.0)
				var stamp := "REGISTERED" if saving else "RECEIVED"
				Grim.text(self, Vector2(r.position.x + 150, r.end.y - 14), stamp, "stencil", 20, Color(Grim.RED, sc))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = -1
			for i in rows.size():
				if rows[i]["rect"].has_point(e.position):
					hover = i
			if hover >= 0 and _usable(hover):
				ScreenFx.want("use")
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for i in rows.size():
				if rows[i]["rect"].has_point(e.position):
					_activate(i)
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			closed.emit()
			get_viewport().set_input_as_handled()
		elif e is InputEventKey and e.pressed and not e.echo:
			match e.keycode:
				KEY_UP:
					sel = (sel - 2 + rows.size()) % rows.size()
				KEY_DOWN:
					sel = (sel + 2) % rows.size()
				KEY_LEFT, KEY_RIGHT:
					sel = sel ^ 1 if (sel ^ 1) < rows.size() else sel
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_activate(sel)
				_:
					return
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ settings

## The fuse board: switches, faders, a rotary for the size of words.
class SettingsMenu extends Control:
	signal closed()
	var t := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var col1 := 36.0
		var col2 := 336.0
		var y := 70.0
		var sel := GW.Selector.new()
		sel.text = "SIZE OF WORDS"
		sel.options = Settings.TEXT_SIZE_NAMES
		sel.position = Vector2(col1, y)
		sel.size = Vector2(270, 18)
		sel.set_index(Settings.text_size)
		sel.changed.connect(func(i): Settings.set_and_save("text_size", i))
		add_child(sel)
		var sp := GW.Fader.new()
		sp.text = "TYPING SPEED"
		sp.position = Vector2(col1, y + 24)
		sp.size = Vector2(270, 18)
		sp.set_value(Settings.text_speed)
		sp.changed.connect(func(v): Settings.set_and_save("text_speed", v))
		add_child(sp)
		var toggles := [
			["ALL AT ONCE", "instant_text", col1, y + 48],
			["PLAIN, SHARP TEXT", "plain_text", col1, y + 70],
			["SAY WHAT YOU HEAR", "ambient_captions", col1, y + 92],
			["KEEP STILL", "reduced_motion", col1, y + 146],
			["MARK EVERYTHING", "show_hotspots", col1, y + 168],
			["ORDINARY ARROW", "plain_cursor", col1, y + 190],
			["FULL SCREEN", "fullscreen", col1, y + 212],
		]
		for tg in toggles:
			var w := GW.Toggle.new()
			w.text = tg[0]
			w.position = Vector2(tg[2], tg[3])
			w.size = Vector2(270, 18)
			w.set_value(bool(Settings.get(tg[1])))
			var key: String = tg[1]
			w.changed.connect(func(v): Settings.set_and_save(key, v))
			add_child(w)
		var wr := GW.Selector.new()
		wr.text = "THE WORLD AT"
		wr.options = ["320 x 180", "640 x 360"]
		wr.position = Vector2(col2, y)
		wr.size = Vector2(270, 18)
		wr.set_index(Settings.world_res)
		wr.changed.connect(func(i): Settings.set_and_save("world_res", i))
		add_child(wr)
		var vols := [["ALL SOUND", "master_vol"], ["MUSIC", "music_vol"], ["NOISES", "sfx_vol"], ["THE ROOM", "amb_vol"]]
		for i in vols.size():
			var f := GW.Fader.new()
			f.text = vols[i][0]
			f.position = Vector2(col2, y + 48 + i * 24)
			f.size = Vector2(270, 18)
			f.set_value(float(Settings.get(vols[i][1])))
			var key: String = vols[i][1]
			f.changed.connect(func(v): Settings.set_and_save(key, v))
			add_child(f)
		var back := GW.Key.new("CLOSE THE BOARD", "ESC")
		back.position = Vector2(col2, 290)
		back.size = Vector2(270, 20)
		back.pressed.connect(func(): closed.emit())
		add_child(back)
		back.call_deferred("grab_focus")
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("060606"))
		Grim.plate(self, Rect2(16, 24, 608, 312), "paint_green", 12.0)
		Grim.text(self, Vector2(30, 52), "THE FUSE BOARD", "stencil", 24, Grim.IVORY)
		Grim.tape(self, Vector2(200, 34), "DO NOT TOUCH - I.C.", 13)
		for lab in [["WORDS", Vector2(36, 67)], ["PLAYING", Vector2(36, 213)], ["PICTURE", Vector2(336, 67)], ["SOUND", Vector2(336, 115)]]:
			var w := Grim.text_w(lab[0], "tiny", 8)
			Grim.band(self, Rect2(lab[1] + Vector2(-2, -8), Vector2(w + 4, 10)), 0.8)
			Grim.text(self, lab[1], lab[0], "tiny", 8, Grim.AMBER)
		# a sample of the words at the chosen size
		var sr := Rect2(336, 222, 270, 56)
		Grim.crt(self, sr, t)
		Grim.para(self, sr.position + Vector2(6, 16), "JAD: Can you hear me?", "body", Grim.body_size(), Grim.PHOS, sr.size.x - 12, 16)
		Grim.crt_glass(self, sr)
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			closed.emit()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ transcript

## Everything said tonight, on the test set's green screen, newest at the
## bottom.
class Backlog extends Control:
	signal closed()
	var lines: Array = []  # [text, colour, indent]
	var scroll := 0
	var rows := 0
	var t := 0.0
	var screen := Rect2(24, 44, 592, 270)
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sz := _sz()
		var w := screen.size.x - 20
		var last_clock := ""
		for e in Game.backlog:
			var clock: String = e.get("clock", "")
			if clock != last_clock and clock != "":
				lines.append(["-- " + clock + " --", Grim.PHOS_DIM, 0])
				last_clock = clock
			var kind: String = e.get("kind", "")
			var prefix := ""
			var col := Grim.PHOS_MID
			match kind:
				"say", "echo":
					prefix = str(Console.SPEAKERS.get(e.get("speaker", ""), e.get("speaker", ""))) + ": "
					col = Grim.IVORY if kind == "echo" else Grim.PHOS
				"sms":
					prefix = str(Console.SPEAKERS.get(e.get("speaker", ""), e.get("speaker", ""))) + " (PRINTED): "
					col = Color("b8ffc2")
				"think":
					col = Grim.AMBER
				"sound":
					col = Color("6fbf9a")
			var text: String = e.get("text", "")
			if kind == "sound":
				text = "[" + text + "]"
			for l in Grim.wrap_text(prefix + text, "body", sz, w):
				lines.append([l, col, 0])
		rows = int((screen.size.y - 12) / _lh())
		scroll = maxi(0, lines.size() - rows)
		var back := GW.Key.new("PUT IT AWAY", "ESC")
		back.position = Vector2(466, 326)
		back.size = Vector2(150, 20)
		back.pressed.connect(func(): closed.emit())
		add_child(back)
		back.call_deferred("grab_focus")
	func _sz() -> int:
		return Grim.body_size() - 4 if not Grim.plain() else Grim.body_size()
	func _lh() -> float:
		return floorf(Grim.line_h("body", _sz()) * 0.9)
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("050505"))
		Grim.plate(self, screen.grow(10), "steel", 6.0)
		Grim.text(self, Vector2(24, 26), "TRANSCRIPT", "stencil", 20, Grim.IVORY)
		Grim.text(self, Vector2(24 + Grim.text_w("TRANSCRIPT", "stencil", 20) + 8, 26), "LINE 247, TONIGHT", "tiny", 8, Grim.AMBER_DIM)
		Grim.crt(self, screen, t)
		var lh := _lh()
		var y := screen.position.y + 8
		for i in range(scroll, mini(lines.size(), scroll + rows)):
			var l: Array = lines[i]
			Grim.text(self, Vector2(screen.position.x + 10, y + lh - 4), l[0], "body", _sz(), l[1])
			y += lh
		if lines.size() > rows:
			var bar_h := maxf(8.0, screen.size.y * rows / lines.size())
			var by := screen.position.y + (screen.size.y - bar_h) * scroll / maxf(1, lines.size() - rows)
			draw_rect(Rect2(screen.end.x - 4, by, 2, bar_h), Grim.PHOS_DIM)
		if lines.is_empty():
			Grim.text(self, screen.position + Vector2(10, 20), "NOTHING YET.", "body", 16, Grim.PHOS_DIM)
		Grim.crt_glass(self, screen)
		Grim.text(self, Vector2(24, 340), "WHEEL OR ARROWS TO SCROLL", "tiny", 8, Grim.IVORY_DIM)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll = mini(scroll + 3, maxi(0, lines.size() - rows))
			elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll = maxi(scroll - 3, 0)
			accept_event()
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu") or e.is_action_pressed("log"):
			closed.emit()
			get_viewport().set_input_as_handled()
		elif e is InputEventKey and e.pressed:
			var mx := maxi(0, lines.size() - rows)
			match e.keycode:
				KEY_UP:
					scroll = maxi(scroll - 1, 0)
				KEY_DOWN:
					scroll = mini(scroll + 1, mx)
				KEY_PAGEUP:
					scroll = maxi(scroll - rows, 0)
				KEY_PAGEDOWN:
					scroll = mini(scroll + rows, mx)
				KEY_HOME:
					scroll = 0
				KEY_END:
					scroll = mx
				_:
					return
			get_viewport().set_input_as_handled()
