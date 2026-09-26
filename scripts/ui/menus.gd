class_name Menus
extends RefCounted
## The menus are things in the exchange, not panels. The title is the
## attendant's switchboard: you plug into what you want. Holding the night is
## a Rolodex. Saving is writing a line in the Receiving Register. Settings are
## Inez's fuse box. What was said comes back off the booking printer's roll.

static func blur_backdrop(parent: Control, dim: float = 0.5) -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/blur.gdshader")
	m.set_shader_parameter("dim", dim)
	bg.material = m
	parent.add_child(bg)
	return bg

# ------------------------------------------------------------------ jacks

## A jack on the switchboard with its lamp and a strip of masking tape that
## says what it's for, in Inez's marker.
class Jack extends Control:
	signal pressed()
	var label := ""
	var enabled := true
	var plugged := false
	var hover := false
	var tape_angle := 0.0
	var key_hint := ""

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
		set_meta("plug", enabled)
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func jack_center() -> Vector2:
		return Vector2(size.x * 0.5, 78)

	func _draw() -> void:
		var c := jack_center()
		var on := enabled and (hover or has_focus() or plugged)
		Kit.lamp(self, Vector2(c.x, 22), 9.0, Kit.LAMP_GREEN if plugged else Kit.AMBER, on)
		Kit.jack(self, c, 18.0, plugged)
		if has_focus() and not hover:
			draw_arc(c, 27.0, 0, TAU, 32, Color(Kit.AMBER, 0.7), 2.0)
		var tc := Vector2(c.x, 142)
		var f := Kit.font("marker")
		var fs := 21
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if label != "" else 70.0
		Kit.tape(self, tc, tape_angle, maxf(w + 34.0, 90.0), 38.0)
		if label != "":
			draw_set_transform(tc, tape_angle)
			var ink := Color("201a18") if enabled else Color(0.2, 0.18, 0.16, 0.35)
			draw_string(f, Vector2(-w * 0.5, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			draw_set_transform(Vector2.ZERO)
		if key_hint != "":
			Kit.text(self, Vector2(c.x - 30, 188), key_hint, "dotline", 12, Color(Kit.IVORY_DIM, 0.55), 60, HORIZONTAL_ALIGNMENT_CENTER)

	func _gui_input(e: InputEvent) -> void:
		if not enabled:
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			pressed.emit()
			accept_event()

# ------------------------------------------------------------------ title

class Title extends Control:
	signal action(what: String)
	var t := 0.0
	var jacks: Array = []
	var jack_home: Array = []
	var going := ""
	var go_t := 0.0
	var art: Texture2D
	var ari_jack := Vector2(1128, 610)
	const BOARD_Y := 452.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		art = Kit.tex("res://assets/ui/title_art.png")
		var has_save := Game.has_any_save()
		var items := [["NEW NIGHT", "new", true], ["CARRY ON", "continue", has_save], ["THE REGISTER", "load", has_save],
			["FUSE BOX", "settings", true], ["HANG UP", "quit", true]]
		var x0 := 150.0
		var step := 196.0
		for i in items.size():
			var j := Jack.new()
			j.label = items[i][0] if items[i][2] else ""
			j.enabled = items[i][2]
			j.tape_angle = [-0.035, 0.025, -0.015, 0.04, -0.03][i]
			j.size = Vector2(170, 200)
			var home := Vector2(x0 + i * step - 85, 532)
			j.position = home
			var what: String = items[i][1]
			var idx: int = i
			j.pressed.connect(func(): _plug(idx, what))
			add_child(j)
			jacks.append(j)
			jack_home.append(home)
		var live: Array = jacks.filter(func(jj): return jj.enabled)
		for i in live.size():
			var jj: Control = live[i]
			jj.focus_neighbor_left = jj.get_path_to(live[(i - 1 + live.size()) % live.size()])
			jj.focus_neighbor_right = jj.get_path_to(live[(i + 1) % live.size()])
		if not Game.story_ok:
			var err := Kit.label("Story failed to load:\n" + "\n".join(Game.load_errors.slice(0, 6)), 14, Kit.RED, "clean")
			err.position = Vector2(60, 10)
			err.size = Vector2(1100, 90)
			err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(err)
		var first: Control = live[1] if has_save and live.size() > 1 else live[0]
		first.call_deferred("grab_focus")

	func _exit_tree() -> void:
		Atmos.anchor_override = Vector2(-1, -1)
		Atmos.magnet = Vector2(-1, -1)

	func _plug(idx: int, what: String) -> void:
		if going != "":
			return
		going = what
		go_t = 0.0
		jacks[idx].plugged = true
		jacks[idx].queue_redraw()
		Audio.sfx("plug_in", -2.0)

	func _process(d: float) -> void:
		t += d
		var bo := Atmos.off(0.85)
		for i in jacks.size():
			jacks[i].position = jack_home[i] + bo
		Atmos.anchor_override = get_global_transform() * (ari_jack + bo)
		var hot := Vector2(-1, -1)
		for j in jacks:
			if j.plugged or (j.enabled and (j.hover or (j.has_focus() and going != ""))):
				hot = j.get_global_transform() * j.jack_center()
		Atmos.magnet = hot
		if going != "":
			go_t += d
			if go_t > (0.05 if Settings.reduced_motion else 0.42):
				var w := going
				going = ""
				for j in jacks:
					j.plugged = false
				action.emit(w)
		queue_redraw()

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo:
			var k: int = e.physical_keycode
			if k >= KEY_1 and k <= KEY_5:
				var j: Jack = jacks[k - KEY_1]
				if j.enabled:
					j.pressed.emit()
					get_viewport().set_input_as_handled()

	func _draw() -> void:
		var W := 1280.0
		# the wall: relays in the dark, the lamp's side of the room warmer
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, 720)), Kit.NIGHT)
		var wo := Atmos.off(0.12)
		var relays := Kit.tex("res://assets/tex/relays.png")
		if relays:
			draw_texture_rect(relays, Rect2(wo - Vector2(40, 40), Vector2(W + 80, 520)), true, Color(0.2, 0.19, 0.2))
		draw_rect(Rect2(wo + Vector2(-40, 382), Vector2(W + 80, 80)), Color("27443a"))
		draw_rect(Rect2(wo + Vector2(-40, 382), Vector2(W + 80, 3)), Color(0, 0, 0, 0.4))
		# the mosaic, lifted from the baths' entrance and screwed to the wall
		var mo := Atmos.off(0.3)
		var tile := 10.0
		var mpos := Vector2(62, 62) + mo
		var msz := Vector2(Kit.mosaic_cols("HOLD MY PLACE") + 6, 13) * tile
		Kit.shadow(self, Rect2(mpos, msz), 0.35)
		var reveal := 1.0 if Settings.reduced_motion else clampf(t * 0.8 - 0.05, 0.0, 1.0)
		Kit.mosaic(self, mpos, "HOLD MY PLACE", tile, reveal)
		for sc in [Vector2(10, 10), Vector2(msz.x - 10, 10), Vector2(10, msz.y - 10), Vector2(msz.x - 10, msz.y - 10)]:
			draw_circle(mpos + sc, 4.0, Kit.BRASS_DK)
			draw_circle(mpos + sc, 2.6, Kit.BRASS)
		Kit.dymo(self, mpos + Vector2(8, msz.y + 22), "One night at Ferrier Court · the overnight service closes at six", 15, Color("1a1a1c"), -0.012)
		# the porthole into the deep end
		var po := Atmos.off(0.5)
		var pc := Vector2(1086, 226) + po
		var pr := 138.0
		draw_circle(pc + Vector2(10, 16), pr + 26, Color(0, 0, 0, 0.45))
		if art:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var inner := Atmos.off(0.8) - po
			for i in 48:
				var a := TAU * i / 48.0
				var p := pc + Vector2(cos(a), sin(a)) * pr
				pts.append(p)
				var q := (p - pc - inner * 0.6) / (pr * 2.2) + Vector2(0.58, 0.5)
				uvs.append(q)
			draw_colored_polygon(pts, Color.WHITE, uvs, art)
		# light moving on the water, a long way down
		if not Settings.reduced_motion:
			for k in 5:
				var yy := pc.y - pr * 0.5 + k * pr * 0.25 + sin(t * 0.7 + k) * 6.0
				var half := sqrt(maxf(pr * pr - pow(yy - pc.y, 2.0), 0.0)) * 0.8
				draw_line(Vector2(pc.x - half, yy), Vector2(pc.x + half, yy + sin(t + k) * 4.0), Color(0.7, 0.85, 1.0, 0.05), 3.0)
		draw_arc(pc, pr - 3, PI * 1.1, PI * 1.55, 24, Color(1, 1, 1, 0.22), 8.0)
		draw_arc(pc, pr + 12, 0, TAU, 64, Kit.BRASS_DK, 28.0)
		draw_arc(pc, pr + 10, 0, TAU, 64, Kit.BRASS, 20.0)
		draw_arc(pc, pr + 12, PI * 1.05, PI * 1.6, 24, Kit.BRASS_LT, 5.0)
		for i in 12:
			var a2 := TAU * i / 12.0
			var rp := pc + Vector2(cos(a2), sin(a2)) * (pr + 11)
			draw_circle(rp, 4.0, Kit.BRASS_DK)
			draw_circle(rp - Vector2(1, 1), 2.4, Kit.BRASS_LT)
		# an enamel plate under it
		var plate := Rect2(pc + Vector2(-78, pr + 34), Vector2(156, 34))
		Kit.shadow(self, plate, 0.2)
		draw_rect(plate, Color("1d3a64"))
		draw_rect(plate.grow(-3), Color("e8e2d0"), false, 1.5)
		Kit.text(self, plate.position + Vector2(0, 24), "DEEP END · 3.2 M", "stamp_b", 20, Color("e8e2d0"), plate.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		# the board, tilted toward you
		var bo := Atmos.off(0.85)
		var top := BOARD_Y + bo.y
		var face := PackedVector2Array([Vector2(52, top) + Vector2(bo.x, 0), Vector2(W - 52, top) + Vector2(bo.x, 0), Vector2(W + 30, 760), Vector2(-30, 760)])
		draw_colored_polygon(PackedVector2Array([face[0] + Vector2(0, -8), face[1] + Vector2(0, -8), face[1] + Vector2(40, 30), face[0] + Vector2(-40, 30)]), Color(0, 0, 0, 0.45))
		var bk := Kit.tex("res://assets/ui/bakelite.png")
		var uvs2 := PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5.2, 1.3), Vector2(-0.2, 1.3)])
		draw_colored_polygon(face, Color("3a281c"), uvs2 if bk else PackedVector2Array(), bk)
		# brass rail and the plaque
		draw_rect(Rect2(Vector2(52 + bo.x, top - 6), Vector2(W - 104, 12)), Kit.BRASS_DK)
		draw_rect(Rect2(Vector2(52 + bo.x, top - 6), Vector2(W - 104, 5)), Kit.BRASS)
		draw_rect(Rect2(Vector2(52 + bo.x, top - 6), Vector2(W - 104, 1.5)), Kit.BRASS_LT)
		var pl := Rect2(Vector2(W * 0.5 - 250 + bo.x, top + 16), Vector2(500, 30))
		draw_rect(pl, Kit.BRASS_DK)
		draw_rect(pl.grow(-2), Kit.BRASS)
		Kit.text(self, pl.position + Vector2(0, 22), "FERRIER ST. EXCHANGE  ·  ATTENDANT'S POSITION No. 1", "stamp", 17, Color("3a2a10"), pl.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		# a row of the building's own jacks, for company
		for i in 26:
			var jx := 110.0 + i * 41.0 + bo.x
			var jy := top + 66
			Kit.jack(self, Vector2(jx, jy), 6.0)
			Kit.text(self, Vector2(jx - 14, jy + 20), str(201 + i), "dotline", 10, Color(Kit.IVORY_DIM, 0.5), 28, HORIZONTAL_ALIGNMENT_CENTER)
		# 247, where Ari is, and where the cord comes up from
		var aj := ari_jack + bo
		Kit.lamp(self, aj + Vector2(0, -56), 9.0, Kit.AMBER, fmod(t, 1.6) < 0.8 and going == "")
		Kit.jack(self, aj, 18.0, true)
		Kit.dymo(self, aj + Vector2(-52, 40), "247 · Ari", 15, Color("b8262a"), 0.02)
		Kit.text(self, Vector2(60 + bo.x, 706), "PLUG IN TO CHOOSE   ·   ← →   ·   ENTER   ·   1–5", "dotline", 13, Color(Kit.IVORY_DIM, 0.5))

# ------------------------------------------------------------------ hold (pause)

## Holding the night: the scene goes out of focus behind a Rolodex of what
## you can do with it.
class Pause extends Control:
	signal action(what: String)
	const CARDS := [
		["BACK TO THE NIGHT", "resume", "The line's still warm."],
		["WRITE IT IN", "save", "Put tonight in the Receiving Register."],
		["READ IT BACK", "load", "Open the Register at another line."],
		["THE PRINTOUT", "log", "Everything that's been said, off the roll."],
		["THE FUSE BOX", "settings", "Inez's switches. Text, sound, stillness."],
		["HANG UP", "title", "Back to the board. Your place is kept."],
		["PULL THE PLUG", "quit", "Leave. The building keeps your place."],
	]
	var cur := 0.0
	var sel := 0
	var t := 0.0
	var rects: Dictionary = {}

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Menus.blur_backdrop(self, 0.52)
		var hit := Control.new()
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(hit)
		hit.gui_input.connect(_on_hit)
		hit.draw.connect(func(): _paint(hit))
		hit.set_meta("plug", true)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_process(true)
		Audio.sfx("tape_click", -8.0)

	func _process(d: float) -> void:
		t += d
		cur = lerpf(cur, float(sel), 1.0 if Settings.reduced_motion else clampf(d * 11.0, 0.0, 1.0))
		get_child(1).queue_redraw()

	func _spin(n: int) -> void:
		sel = clampi(sel + n, 0, CARDS.size() - 1)
		Audio.sfx("paper", -14.0)

	func _pick() -> void:
		Audio.sfx("click", -6.0)
		action.emit(CARDS[sel][1])

	func _on_hit(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP:
				_spin(-1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_spin(1)
			elif e.button_index == MOUSE_BUTTON_LEFT:
				var best := -1
				var best_a := 99.0
				for i in rects:
					var r: Rect2 = rects[i]
					if r.has_point(e.position) and absf(float(i) - cur) < best_a:
						best = i
						best_a = absf(float(i) - cur)
				if best == sel:
					_pick()
				elif best >= 0:
					sel = best
					Audio.sfx("paper", -14.0)

	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			action.emit("resume")
		elif e.is_action_pressed("ui_up") or e.is_action_pressed("ui_left"):
			_spin(-1)
		elif e.is_action_pressed("ui_down") or e.is_action_pressed("ui_right"):
			_spin(1)
		elif e.is_action_pressed("ui_accept") or e.is_action_pressed("advance"):
			_pick()
		else:
			return
		get_viewport().set_input_as_handled()

	func _paint(ci: Control) -> void:
		# the HOLD lamp and a strip of LCD
		var lcd := Rect2(490, 28, 300, 46)
		ci.draw_rect(lcd.grow(5), Color("1a1612"))
		ci.draw_rect(lcd, Color("1c2a18"))
		ci.draw_rect(lcd.grow(-3), Color("27402a"), false, 1.0)
		var blink := fmod(t, 1.2) < 0.85
		Kit.lamp(ci, Vector2(lcd.position.x - 30, lcd.get_center().y), 9.0, Kit.AMBER, blink)
		Kit.text(ci, lcd.position + Vector2(0, 33), "ON HOLD  " + str(Game.pres.get("clock", "")), "dot", 26, Color("9fe0a0"), lcd.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.text(ci, Vector2(0, 104), "the night keeps while you're gone", "prose_i", 17, Color(Kit.IVORY_DIM, 0.8), 1280, HORIZONTAL_ALIGNMENT_CENTER)
		# the drum and its rails
		var c := Vector2(640, 402) + Atmos.off(0.4)
		var rail := Rect2(c.x - 300, c.y + 150, 600, 26)
		Kit.shadow(ci, rail, 0.3)
		ci.draw_rect(rail, Color("2a2622"))
		ci.draw_rect(Rect2(rail.position, Vector2(rail.size.x, 6)), Color(1, 1, 1, 0.12))
		for sx in [-1, 1]:
			var kc := Vector2(c.x + sx * 318, c.y + 163)
			ci.draw_circle(kc + Vector2(3, 5), 30, Color(0, 0, 0, 0.4))
			ci.draw_circle(kc, 28, Kit.BRASS_DK)
			ci.draw_circle(kc, 24, Kit.BRASS)
			for k in 10:
				var a := TAU * k / 10.0 + cur * 0.9
				ci.draw_line(kc + Vector2(cos(a), sin(a)) * 12, kc + Vector2(cos(a), sin(a)) * 23, Kit.BRASS_DK, 2.0)
		# the cards, furthest first
		var order: Array = range(CARDS.size())
		order.sort_custom(func(a, b): return absf(float(a) - cur) > absf(float(b) - cur))
		rects.clear()
		for i in order:
			var a := (float(i) - cur) * 0.48
			if absf(a) > 1.4:
				continue
			var W := 560.0 * (1.0 - absf(a) * 0.1)
			var H := 290.0
			var sy := cos(a)
			var cy := c.y - sin(a) * 175.0
			var bright := clampf(1.0 - absf(a) * 0.5, 0.25, 1.0)
			var r := Rect2(c.x - W * 0.5, cy - H * 0.5 * sy, W, H * sy)
			rects[i] = r
			ci.draw_set_transform(Vector2(c.x, cy), 0.0, Vector2(1.0 - absf(a) * 0.1, sy))
			var card := Rect2(-280, -145, 560, 290)
			Kit.shadow(ci, card, 0.25 + (0.3 if i == sel else 0.0), bright)
			# a coloured celluloid tab, staggered like real ones
			var tab := Rect2(-250 + (i % 3) * 170, -178, 110, 38)
			var tabc: Color = [Color("c83a32"), Color("2f6a9e"), Color("3d7a58"), Color("c89a32"), Color("7a4a8a"), Color("3a3a40"), Color("8a2a22")][i]
			ci.draw_rect(tab, tabc.darkened(1.0 - bright))
			ci.draw_rect(Rect2(tab.position + Vector2(8, 8), tab.size - Vector2(16, 12)), Color(1, 1, 1, 0.8 * bright))
			Kit.text(ci, tab.position + Vector2(8, 29), "%02d" % (i + 1), "dot", 20, tabc.darkened(0.3), tab.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
			var pcol := Color("efe8d4").darkened(1.0 - bright)
			ci.draw_rect(card, pcol)
			var ptex := Kit.tex("res://assets/ui/paper.png")
			if ptex:
				ci.draw_texture_rect(ptex, card, true, Color(1, 1, 1, 0.35 * bright))
			ci.draw_line(Vector2(-280, -86), Vector2(280, -86), Color(0.75, 0.3, 0.3, 0.7 * bright), 1.5)
			for ln in 5:
				ci.draw_line(Vector2(-280, -46 + ln * 38), Vector2(280, -46 + ln * 38), Color(0.55, 0.65, 0.85, 0.45 * bright), 1.0)
			ci.draw_line(Vector2(-232, -145), Vector2(-232, 145), Color(0.8, 0.4, 0.4, 0.4 * bright), 1.0)
			var ink := Color("1d1814").darkened(1.0 - bright)
			Kit.text(ci, Vector2(-212, -100), CARDS[i][0], "display", 38, ink)
			Kit.text(ci, Vector2(-212, -20), CARDS[i][2], "hand", 30, Color("23386a").darkened(1.0 - bright), 470)
			ci.draw_circle(Vector2(-150, 118), 9, Color(0.15, 0.13, 0.12, bright))
			ci.draw_circle(Vector2(150, 118), 9, Color(0.15, 0.13, 0.12, bright))
			if i == sel:
				Kit.text(ci, Vector2(-212, 108), "ENTER  ·  CLICK", "dotline", 14, Color(ink, 0.5))
			ci.draw_set_transform(Vector2.ZERO)
		Kit.text(ci, Vector2(0, 706), "↑ ↓ turn the cards   ·   ENTER take one   ·   ESC back to the night", "dotline", 13, Color(Kit.IVORY_DIM, 0.6), 1280, HORIZONTAL_ALIGNMENT_CENTER)

# ------------------------------------------------------------------ the register (save/load)

## Saving is writing a line in the Receiving Register, with a photograph of
## where you were pasted in the margin. Loading is reading a line back.
class SaveLoad extends Control:
	signal closed()
	signal picked(slot: int)
	var saving := true
	var rows: Array = []
	var sel := 0
	var hover := -1
	var confirm := -1
	var writing := -1
	var write_t := 0.0
	var t := 0.0
	var paper: Control

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Menus.blur_backdrop(self, 0.6)
		paper = Control.new()
		paper.set_anchors_preset(Control.PRESET_FULL_RECT)
		paper.mouse_filter = Control.MOUSE_FILTER_PASS
		paper.set_meta("plug", true)
		paper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(paper)
		paper.draw.connect(func(): _paint(paper))
		paper.gui_input.connect(_on_input)
		for slot in range(0, 7):
			var d := Game.read_save(slot)
			var thumb: Texture2D = null
			var tp := Game.thumb_path(slot)
			if FileAccess.file_exists(tp):
				var img := Image.load_from_file(tp)
				if img:
					thumb = ImageTexture.create_from_image(img)
			var left := slot <= 3
			var r := Rect2(118 if left else 668, 146 + (slot if left else slot - 4) * 128, 500, 116)
			rows.append({"slot": slot, "data": d, "thumb": thumb, "rect": r})
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
		paper.position = Atmos.off(0.25)
		if writing >= 0:
			write_t += d
			if write_t > (0.1 if Settings.reduced_motion else 0.95):
				var s := writing
				writing = -1
				picked.emit(s)
		paper.queue_redraw()

	func _activate(i: int) -> void:
		if writing >= 0 or not _usable(i):
			return
		sel = i
		if saving:
			if not rows[i]["data"].is_empty() and confirm != i:
				confirm = i
				Audio.sfx("paper", -10.0)
				return
			writing = i
			write_t = 0.0
			Audio.sfx("paper", -4.0)
		else:
			Audio.sfx("click", -6.0)
			picked.emit(rows[i]["slot"])

	func _on_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = -1
			for i in rows.size():
				if rows[i]["rect"].has_point(e.position):
					hover = i
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if Rect2(1072, 648, 140, 40).has_point(e.position):
				closed.emit()
				return
			for i in rows.size():
				if rows[i]["rect"].has_point(e.position):
					_activate(i)

	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			closed.emit()
		elif e.is_action_pressed("ui_down"):
			sel = (sel + 1) % rows.size()
			confirm = -1
		elif e.is_action_pressed("ui_up"):
			sel = (sel - 1 + rows.size()) % rows.size()
			confirm = -1
		elif e.is_action_pressed("ui_right") and sel <= 3:
			sel = mini(sel + 4, rows.size() - 1)
		elif e.is_action_pressed("ui_left") and sel >= 4:
			sel = sel - 4
		elif e.is_action_pressed("ui_accept"):
			_activate(sel)
		else:
			return
		get_viewport().set_input_as_handled()

	func _entry_text(i: int) -> Array:
		# what the line says: the time and chapter, and the last thing said
		var d: Dictionary = rows[i]["data"]
		var p: Dictionary
		var bl: Array
		if writing == i or (saving and hover == i and d.is_empty()):
			p = Game.pres
			bl = Game.backlog
		else:
			if d.is_empty():
				return []
			p = d.get("pres", {})
			bl = d.get("backlog", [])
		var ch := int(p.get("chapter", 0))
		var roman: String = ["", "I", "II", "III", "IV", "V"][clampi(ch, 0, 5)]
		var head := "%s   ·   %s %s" % [p.get("clock", ""), roman, str(p.get("chapter_title", ""))]
		var last := ""
		for k in range(bl.size() - 1, -1, -1):
			var e: Dictionary = bl[k]
			if str(e.get("text", "")) != "" and e.get("kind", "") in ["say", "narration", "think", "echo"]:
				last = str(e["text"])
				break
		if last.length() > 70:
			last = last.substr(0, 67) + "…"
		return [head, last]

	func _paint(ci: Control) -> void:
		# the book: green cloth, a red spine, two pages
		var cover := Rect2(64, 30, 1152, 666)
		Kit.shadow(ci, cover, 0.5)
		ci.draw_rect(cover, Color("294a3a"))
		var cl := Kit.tex("res://assets/ui/paper.png")
		if cl:
			ci.draw_texture_rect(cl, cover, true, Color(0.2, 0.35, 0.28, 0.35))
		ci.draw_rect(Rect2(622, 30, 36, 666), Color("7a2420"))
		ci.draw_rect(Rect2(622, 30, 36, 666).grow(-4), Color("8a2c26"))
		for pg in [Rect2(94, 48, 532, 630), Rect2(654, 48, 532, 630)]:
			ci.draw_rect(pg, Color("e9dfc4"))
			if cl:
				ci.draw_texture_rect(cl, pg, true, Color(1, 1, 1, 0.5))
			var gut_left: bool = pg.position.x > 600
			for k in 18:
				var gx: float = pg.position.x + (k * 2.0 if gut_left else pg.size.x - k * 2.0 - 2.0)
				ci.draw_rect(Rect2(gx, pg.position.y, 2, pg.size.y), Color(0.25, 0.18, 0.1, 0.16 * (1.0 - k / 18.0)))
			for ln in 16:
				ci.draw_line(Vector2(pg.position.x + 12, pg.position.y + 96 + ln * 32), Vector2(pg.end.x - 12, pg.position.y + 96 + ln * 32), Color(0.55, 0.62, 0.78, 0.35), 1.0)
		var brown := Color("5a3a26")
		Kit.text(ci, Vector2(94, 88), "RECEIVING REGISTER", "display", 30, brown, 532, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.text(ci, Vector2(654, 88), "FERRIER ST. BATHS", "display", 30, brown, 532, HORIZONTAL_ALIGNMENT_CENTER)
		for x0 in [118, 668]:
			Kit.text(ci, Vector2(x0, 128), "No.", "prose_i", 15, Color("8a3a2a"))
			Kit.text(ci, Vector2(x0 + 50, 128), "Photograph", "prose_i", 15, Color("8a3a2a"))
			Kit.text(ci, Vector2(x0 + 220, 128), "Time  ·  Chapter  ·  Remarks", "prose_i", 15, Color("8a3a2a"))
		Kit.dymo(ci, Vector2(100, 648), "Write it in" if saving else "Read it back", 16, Color("1f3f78") if saving else Color("2f6a52"), -0.01)
		for i in rows.size():
			var row: Dictionary = rows[i]
			var r: Rect2 = row["rect"]
			var slot: int = row["slot"]
			var usable := _usable(i)
			var ink := Color("2a2436") if usable else Color("2a2436", 0.35)
			Kit.text(ci, Vector2(r.position.x, r.position.y + 34), str(slot), "hand", 30, ink)
			if slot == 0:
				Kit.text(ci, Vector2(r.position.x + 220, r.position.y + 108), "kept by the building as you go (autosave)", "prose_i", 12, Color(ink, 0.6))
			var ph := Rect2(r.position.x + 48, r.position.y + 12, 152, 86)
			var tx: Array = _entry_text(i)
			var thumb: Texture2D = row["thumb"]
			var show_photo := thumb != null and writing != i
			if writing == i and Game.thumb:
				thumb = ImageTexture.create_from_image(Game.thumb)
				show_photo = write_t > 0.45 or Settings.reduced_motion
			if show_photo and thumb:
				Kit.shadow(ci, ph, 0.12)
				ci.draw_rect(ph.grow(4), Color("f4efe2"))
				ci.draw_texture_rect(thumb, ph, false)
				for cc in [ph.position, Vector2(ph.end.x, ph.position.y), Vector2(ph.position.x, ph.end.y), ph.end]:
					var dx := 1.0 if cc.x == ph.position.x else -1.0
					var dy := 1.0 if cc.y == ph.position.y else -1.0
					ci.draw_colored_polygon(PackedVector2Array([cc, cc + Vector2(16 * dx, 0), cc + Vector2(0, 16 * dy)]), Color("1a1614"))
			else:
				ci.draw_rect(ph, Color(0.6, 0.55, 0.45, 0.12))
				ci.draw_rect(ph, Color(0.4, 0.35, 0.3, 0.25), false, 1.0)
			var tx0 := r.position.x + 220
			if tx.size() > 0:
				var head: String = tx[0]
				var reveal := 1.0
				if writing == i:
					reveal = clampf(write_t / 0.8, 0.0, 1.0)
				var hw := Kit.text_w(head, "hand", 27) * reveal
				var clip_head := head.substr(0, int(head.length() * reveal))
				Kit.text(ci, Vector2(tx0, r.position.y + 38), clip_head, "hand", 27, Color("23386a"))
				if writing == i and reveal < 1.0:
					var nib := Vector2(tx0 + hw, r.position.y + 30)
					ci.draw_line(nib, nib + Vector2(26, -34), Color("1a1a1a"), 5.0)
					ci.draw_colored_polygon(PackedVector2Array([nib, nib + Vector2(5, -8), nib + Vector2(-2, -9)]), Kit.BRASS)
				if reveal >= 1.0 and str(tx[1]) != "":
					Kit.para(ci, Vector2(tx0, r.position.y + 62), "“" + str(tx[1]) + "”", "prose_i", 15, Color("3a3040"), 280, 3)
			elif saving and usable:
				Kit.text(ci, Vector2(tx0, r.position.y + 50), "(a blank line)", "prose_i", 15, Color(0.4, 0.36, 0.3, 0.5))
			if confirm == i:
				Kit.text(ci, Vector2(tx0 - 10, r.position.y + 104), "write over it?  click again", "hand", 24, Color("b8261f"))
				ci.draw_line(Vector2(tx0, r.position.y + 32), Vector2(tx0 + 250, r.position.y + 26), Color("b8261f", 0.8), 2.0)
			var lit := (i == hover or i == sel) and usable
			if lit and writing < 0:
				# a wooden ruler laid along the line you're about to use
				var rr := Rect2(r.position.x - 14, r.end.y - 6, r.size.x + 28, 16)
				Kit.shadow(ci, rr, 0.15)
				ci.draw_rect(rr, Color("c8a466", 0.92))
				for k in 50:
					var mx := rr.position.x + 8 + k * 10.0
					ci.draw_line(Vector2(mx, rr.position.y), Vector2(mx, rr.position.y + (7 if k % 5 == 0 else 4)), Color("5a3a1a"), 1.0)
		# shut the book
		var btn := Rect2(1072, 648, 140, 40)
		Kit.dymo(ci, btn.position, "Shut the book", 15, Color("1a1a1c"), 0.0)
		Kit.text(ci, Vector2(0, 712), "↑ ↓ ← → a line   ·   ENTER write / read   ·   ESC shut the book", "dotline", 12, Color(Kit.IVORY_DIM, 0.6), 1280, HORIZONTAL_ALIGNMENT_CENTER)

# ------------------------------------------------------------------ the fuse box (settings)

## One of Inez's switches: a bat-handle toggle with a lamp, labelled in marker.
class Toggle extends Control:
	signal changed(v: bool)
	var value := false
	var label := ""
	var note := ""
	var flip := 0.0
	var hover := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta("plug", true)
		custom_minimum_size = Vector2(200, 170)
		size = custom_minimum_size
		flip = 1.0 if value else 0.0
		mouse_entered.connect(func(): hover = true)
		mouse_exited.connect(func(): hover = false)
	func _process(d: float) -> void:
		flip = move_toward(flip, 1.0 if value else 0.0, d * (100.0 if Settings.reduced_motion else 7.0))
		queue_redraw()
	func toggle() -> void:
		value = not value
		Audio.sfx("key_throw", -4.0)
		changed.emit(value)
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			toggle()
			accept_event()
	func _draw() -> void:
		Menus.tape_label(self, Vector2(size.x * 0.5, 16), label, -0.02)
		var c := Vector2(size.x * 0.5, 92)
		draw_circle(c + Vector2(2, 4), 30, Color(0, 0, 0, 0.4))
		draw_circle(c, 29, Color("9a9c9e"))
		draw_circle(c, 25, Color("7a7c80"))
		draw_arc(c, 27, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.4), 2.0)
		var ang := lerpf(2.6, -0.22, flip)
		var tip := c + Vector2(sin(ang), -cos(ang)) * 42
		draw_line(c + Vector2(3, 5), tip + Vector2(3, 5), Color(0, 0, 0, 0.35), 11)
		draw_line(c, tip, Color("d8d8d4"), 10)
		draw_line(c + Vector2(-2, 0), tip + Vector2(-2, 0), Color(1, 1, 1, 0.6), 2)
		draw_circle(tip, 7, Color("e4e4e0"))
		Kit.lamp(self, Vector2(size.x * 0.5 + 58, 92), 7.0, Kit.LAMP_GREEN if value else Kit.RED, true if value else false)
		Kit.text(self, Vector2(size.x * 0.5 + 44, 122), "ON" if value else "OFF", "stamp_b", 14, Color(Kit.IVORY_DIM, 0.8), 30, HORIZONTAL_ALIGNMENT_CENTER)
		if has_focus() or hover:
			draw_arc(c, 40, 0, TAU, 32, Color(Kit.AMBER, 0.6), 2.0)
		Kit.text(self, Vector2(0, 152), note, "dotline", 12, Color(Kit.IVORY_DIM, 0.75), size.x, HORIZONTAL_ALIGNMENT_CENTER)

## A bakelite knob with a brass pointer: drag up and down, scroll, or arrows.
class Knob extends Control:
	signal changed(v: float)
	var value := 0.5
	var label := ""
	var note := ""
	var hover := false
	var _drag := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta("plug", true)
		custom_minimum_size = Vector2(190, 180)
		size = custom_minimum_size
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func set_value(v: float) -> void:
		var nv := clampf(snappedf(v, 0.01), 0.0, 1.0)
		if nv != value:
			value = nv
			changed.emit(value)
			queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_drag = e.pressed
				accept_event()
			elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
				set_value(value + 0.05)
				accept_event()
			elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				set_value(value - 0.05)
				accept_event()
		elif e is InputEventMouseMotion and _drag:
			set_value(value - e.relative.y * 0.006 + e.relative.x * 0.004)
			accept_event()
		elif e.is_action_pressed("ui_right") or e.is_action_pressed("ui_up"):
			set_value(value + 0.05)
			accept_event()
		elif e.is_action_pressed("ui_left") or e.is_action_pressed("ui_down"):
			set_value(value - 0.05)
			accept_event()
	func _draw() -> void:
		Menus.tape_label(self, Vector2(size.x * 0.5, 16), label, 0.02)
		var c := Vector2(size.x * 0.5, 96)
		for k in 11:
			var a := lerpf(-2.35, 2.35, k / 10.0) - PI * 0.5
			var l := 8.0 if k % 5 == 0 else 5.0
			draw_line(c + Vector2(cos(a), sin(a)) * 46, c + Vector2(cos(a), sin(a)) * (46 + l), Color(Kit.IVORY_DIM, 0.7), 1.5)
		draw_circle(c + Vector2(3, 5), 36, Color(0, 0, 0, 0.45))
		draw_circle(c, 35, Color("140e0a"))
		draw_circle(c, 31, Kit.BAKELITE_LT)
		for k in 18:
			var a2 := TAU * k / 18.0
			draw_line(c + Vector2(cos(a2), sin(a2)) * 31, c + Vector2(cos(a2), sin(a2)) * 35, Color("140e0a"), 2.0)
		draw_arc(c, 24, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.14), 4.0)
		var av := lerpf(-2.35, 2.35, value) - PI * 0.5
		draw_line(c, c + Vector2(cos(av), sin(av)) * 28, Kit.BRASS, 4.0)
		draw_circle(c, 6, Kit.BRASS_DK)
		if has_focus() or hover:
			draw_arc(c, 42, 0, TAU, 40, Color(Kit.AMBER, 0.6), 2.0)
		Kit.text(self, Vector2(0, 160), "%s  %d%%" % [note, int(round(value * 100))], "dotline", 12, Color(Kit.IVORY_DIM, 0.75), size.x, HORIZONTAL_ALIGNMENT_CENTER)

## A rotary switch with named positions round it.
class Selector extends Control:
	signal changed(i: int)
	var value := 0
	var names: Array = []
	var label := ""
	var note := ""
	var hover := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta("plug", true)
		custom_minimum_size = Vector2(210, 180)
		size = custom_minimum_size
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func step(n: int) -> void:
		value = (value + n + names.size()) % names.size()
		Audio.sfx("key_throw", -8.0)
		changed.emit(value)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_WHEEL_UP:
				step(1)
				accept_event()
			elif e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				step(-1)
				accept_event()
		elif e.is_action_pressed("ui_right") or e.is_action_pressed("ui_accept"):
			step(1)
			accept_event()
		elif e.is_action_pressed("ui_left"):
			step(-1)
			accept_event()
	func _draw() -> void:
		Menus.tape_label(self, Vector2(size.x * 0.5, 16), label, -0.03)
		var c := Vector2(size.x * 0.5, 100)
		var n := names.size()
		for i in n:
			var a := lerpf(-1.9, 1.9, float(i) / maxf(n - 1, 1)) - PI * 0.5
			var p := c + Vector2(cos(a), sin(a)) * 58
			Kit.text(self, p + Vector2(-20, 6), str(names[i]), "stamp_b", 16, Kit.AMBER if i == value else Color(Kit.IVORY_DIM, 0.6), 40, HORIZONTAL_ALIGNMENT_CENTER)
		draw_circle(c + Vector2(3, 5), 34, Color(0, 0, 0, 0.45))
		draw_circle(c, 33, Color("1a1410"))
		var av := lerpf(-1.9, 1.9, float(value) / maxf(n - 1, 1)) - PI * 0.5
		var dir := Vector2(cos(av), sin(av))
		var nor := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([c - dir * 26 + nor * 11, c + dir * 30 + nor * 6, c + dir * 30 - nor * 6, c - dir * 26 - nor * 11]), Kit.BAKELITE_LT)
		draw_line(c, c + dir * 28, Color("e8e0cc"), 3.0)
		if has_focus() or hover:
			draw_arc(c, 42, 0, TAU, 40, Color(Kit.AMBER, 0.6), 2.0)
		Kit.text(self, Vector2(0, 168), note, "dotline", 12, Color(Kit.IVORY_DIM, 0.75), size.x, HORIZONTAL_ALIGNMENT_CENTER)

## A knife switch: the whole wall or a window.
class Knife extends Toggle:
	func _draw() -> void:
		Menus.tape_label(self, Vector2(size.x * 0.5, 16), label, 0.03)
		var base := Rect2(size.x * 0.5 - 40, 58, 80, 84)
		Kit.shadow(self, base, 0.15)
		draw_rect(base, Color("3a2e26"))
		draw_rect(base.grow(-4), Color("2a211b"))
		for x in [-18, 18]:
			draw_rect(Rect2(size.x * 0.5 + x - 5, 64, 10, 16), Kit.BRASS)
			draw_rect(Rect2(size.x * 0.5 + x - 5, 122, 10, 14), Kit.BRASS)
		var hinge := Vector2(size.x * 0.5, 130)
		var ang := lerpf(1.25, 0.0, flip)
		var up := Vector2(0, -1).rotated(ang)
		var tip := hinge + up * 68
		var side := Vector2(1, 0)
		for x in [-18, 18]:
			draw_line(hinge + side * x, tip + side * x, Color("c8c8c0"), 5)
		draw_line(tip + side * -26 + up * 6, tip + side * 26 + up * 6, Color("1a1a1a"), 12)
		draw_line(tip + side * -26 + up * 6, tip + side * 26 + up * 6, Color(1, 1, 1, 0.15), 3)
		Kit.lamp(self, Vector2(size.x * 0.5 + 64, 70), 7.0, Kit.LAMP_GREEN if value else Kit.RED, value)
		if has_focus() or hover:
			draw_rect(base.grow(8), Color(Kit.AMBER, 0.6), false, 2.0)
		Kit.text(self, Vector2(0, 162), note, "dotline", 12, Color(Kit.IVORY_DIM, 0.75), size.x, HORIZONTAL_ALIGNMENT_CENTER)

## Masking tape with Inez's marker on it.
static func tape_label(ci: CanvasItem, c: Vector2, text: String, angle: float) -> void:
	var f := Kit.font("marker")
	var fs := 18
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	Kit.tape(ci, c, angle, w + 28, 30)
	ci.draw_set_transform(c, angle)
	ci.draw_string(f, Vector2(-w * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("201a18"))
	ci.draw_set_transform(Vector2.ZERO)

class SettingsMenu extends Control:
	signal closed()
	var box: Control
	var door_t := 0.0
	var close_btn: Jack

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Menus.blur_backdrop(self, 0.6)
		box = Control.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		box.draw.connect(func(): _paint(box))
		var ctl: Array = []
		var ts := Selector.new()
		ts.names = ["S", "M", "L", "XL"]
		ts.value = Settings.text_size
		ts.label = "HOW BIG"
		ts.note = "text size"
		ts.changed.connect(func(i): Settings.set_and_save("text_size", i))
		ctl.append([ts, Vector2(250, 104)])
		var sp := Knob.new()
		sp.value = Settings.text_speed
		sp.label = "HOW FAST"
		sp.note = "text speed"
		sp.changed.connect(func(v): Settings.set_and_save("text_speed", v))
		ctl.append([sp, Vector2(470, 104)])
		ctl.append([_tog("ALL AT ONCE", "instant text", Settings.instant_text, "instant_text"), Vector2(680, 104)])
		ctl.append([_tog("PLAIN PAPER", "clean text", Settings.clean_text, "clean_text"), Vector2(890, 104)])
		ctl.append([_tog("KEEP STILL", "reduced motion", Settings.reduced_motion, "reduced_motion"), Vector2(250, 300)])
		ctl.append([_tog("SAY WHAT YOU HEAR", "sound captions", Settings.ambient_captions, "ambient_captions"), Vector2(470, 300)])
		ctl.append([_tog("ORDINARY ARROW", "plain pointer", Settings.plain_cursor, "plain_cursor"), Vector2(680, 300)])
		var kn := Knife.new()
		kn.value = Settings.fullscreen
		kn.label = "WHOLE WALL"
		kn.note = "fullscreen"
		kn.changed.connect(func(v): Settings.set_and_save("fullscreen", v))
		ctl.append([kn, Vector2(890, 300)])
		var vols := [["EVERYTHING", "master", "master_vol"], ["THE TAPE", "music", "music_vol"], ["CLICKS & BELLS", "effects", "sfx_vol"], ["ROOMS & LINES", "ambience", "amb_vol"]]
		for i in vols.size():
			var k := Knob.new()
			k.value = float(Settings.get(vols[i][2]))
			k.label = vols[i][0]
			k.note = vols[i][1]
			var key: String = vols[i][2]
			k.changed.connect(func(v): Settings.set_and_save(key, v))
			ctl.append([k, Vector2(250 + i * 210, 490)])
		for c in ctl:
			add_child(c[0])
			c[0].position = c[1]
		close_btn = Jack.new()
		close_btn.label = "SHUT THE BOX"
		close_btn.size = Vector2(190, 200)
		close_btn.position = Vector2(1066, 470)
		close_btn.pressed.connect(func(): closed.emit())
		add_child(close_btn)
		# keyboard order: along each row, then down
		var order: Array = ctl.map(func(c): return c[0])
		order.append(close_btn)
		for i in order.size():
			var cc: Control = order[i]
			cc.focus_next = cc.get_path_to(order[(i + 1) % order.size()])
			cc.focus_previous = cc.get_path_to(order[(i - 1 + order.size()) % order.size()])
		ts.call_deferred("grab_focus")
		Audio.sfx("key_throw", -6.0)

	func _tog(label: String, note: String, v: bool, key: String) -> Toggle:
		var tg := Toggle.new()
		tg.value = v
		tg.label = label
		tg.note = note
		tg.changed.connect(func(nv): Settings.set_and_save(key, nv))
		return tg

	func _process(d: float) -> void:
		door_t = minf(1.0, door_t + d * (10.0 if Settings.reduced_motion else 2.2))
		box.queue_redraw()

	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu"):
			closed.emit()
			get_viewport().set_input_as_handled()

	func _paint(ci: Control) -> void:
		# the steel box, open, and its door swung out on the left
		var inner := Rect2(214, 60, 1052, 640)
		Kit.shadow(ci, inner.grow(10), 0.45)
		ci.draw_rect(inner.grow(10), Color("5e6266"))
		ci.draw_rect(inner, Color("2c2f33"))
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 3)), Color(1, 1, 1, 0.08))
		for y in [270, 460]:
			ci.draw_rect(Rect2(inner.position.x + 20, y, inner.size.x - 40, 3), Color(0, 0, 0, 0.35))
		# the rows' printed rails
		Kit.text(ci, Vector2(inner.position.x + 24, 92), "READING", "stamp", 16, Color(Kit.IVORY_DIM, 0.45))
		Kit.text(ci, Vector2(inner.position.x + 24, 290), "THE ROOM", "stamp", 16, Color(Kit.IVORY_DIM, 0.45))
		Kit.text(ci, Vector2(inner.position.x + 24, 480), "HOW LOUD", "stamp", 16, Color(Kit.IVORY_DIM, 0.45))
		var open := door_t
		var hinge_x := inner.position.x - 10
		var dw := lerpf(1052.0, 190.0, open)
		var skew := lerpf(0.0, 40.0, open)
		var door := PackedVector2Array([Vector2(hinge_x, 50), Vector2(hinge_x - dw, 50 + skew), Vector2(hinge_x - dw, 710 - skew), Vector2(hinge_x, 710)])
		ci.draw_colored_polygon(door, Color("6a6e72"))
		ci.draw_polyline(PackedVector2Array([door[0], door[1], door[2], door[3]]), Color("3a3d40"), 3.0)
		if open > 0.9:
			# Inez's card on the inside of the door
			var card := Rect2(hinge_x - 176, 150, 160, 400)
			ci.draw_rect(card, Color("efe8d4"))
			var lines := ["KEYS", "", "SPACE / ENTER", "go on", "", "1 – 9", "choose", "", "TAB  or  B", "the board", "", "L", "the printout", "", "F5  /  F9", "quick save / load", "", "ESC", "hold"]
			var y := card.position.y + 30
			for ln in lines:
				if ln == "":
					y += 8
					continue
				var big: bool = ln == ln.to_upper() and ln != "go on"
				Kit.text(ci, Vector2(card.position.x + 12, y), ln, "marker" if big else "hand", 15 if big else 21, Color("201a18") if big else Color("23386a"))
				y += 18 if big else 20
			Kit.tape(ci, Vector2(card.get_center().x, card.position.y), 0.05, 90, 22)
			Kit.tape(ci, Vector2(card.get_center().x, card.end.y), -0.04, 90, 22)
		Kit.text(ci, Vector2(0, 712), "TAB / ← → between switches   ·   ENTER or click to flip   ·   drag or scroll the knobs   ·   ESC shut the box", "dotline", 12, Color(Kit.IVORY_DIM, 0.6), 1280, HORIZONTAL_ALIGNMENT_CENTER)

# ------------------------------------------------------------------ the printout (history)

## What was said, printed on the booking printer's roll.
class Backlog extends Control:
	signal closed()
	var sc: ScrollContainer
	var strip: VBoxContainer
	var t := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		Menus.blur_backdrop(self, 0.62)
		var machine := Control.new()
		machine.set_anchors_preset(Control.PRESET_FULL_RECT)
		machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(machine)
		machine.draw.connect(func(): _paint_machine(machine))
		sc = ScrollContainer.new()
		sc.position = Vector2(270, 0)
		sc.size = Vector2(740, 604)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.add_theme_stylebox_override("panel", Kit.empty_box())
		add_child(sc)
		var roll := _Roll.new()
		roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(roll)
		strip = VBoxContainer.new()
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.add_theme_constant_override("separation", 14)
		roll.add_child(strip)
		var top_pad := Control.new()
		top_pad.custom_minimum_size = Vector2(0, 40)
		strip.add_child(top_pad)
		var last_clock := ""
		for e in Game.backlog:
			if e.get("clock", "") != last_clock:
				last_clock = e.get("clock", "")
				var tl := Kit.label("─────  %s  ─────" % last_clock, 14, Color("6a6254"), "dotline")
				tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				strip.add_child(tl)
			strip.add_child(_entry(e))
		var bottom_pad := Control.new()
		bottom_pad.custom_minimum_size = Vector2(0, 30)
		strip.add_child(bottom_pad)
		var cut := Jack.new()
		cut.label = "TEAR OFF"
		cut.size = Vector2(170, 200)
		cut.position = Vector2(1040, 470)
		cut.pressed.connect(func(): closed.emit())
		add_child(cut)
		cut.call_deferred("grab_focus")
		Audio.sfx("printer", -8.0)
		await get_tree().process_frame
		await get_tree().process_frame
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

	func _entry(e: Dictionary) -> Control:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_theme_font_override("normal_font", Kit.font("prose"))
		r.add_theme_font_override("italics_font", Kit.font("prose_i"))
		r.add_theme_font_override("bold_font", Kit.font("stamp"))
		r.add_theme_font_override("mono_font", Kit.font("dotline"))
		for k in ["normal_font_size", "italics_font_size", "bold_font_size", "mono_font_size"]:
			r.add_theme_font_size_override(k, Settings.font_size() - 2)
		r.add_theme_color_override("default_color", Color("2a2420"))
		var t := Kit.esc_bb(str(e.get("text", "")))
		var sp: String = e.get("speaker", "")
		match e.get("kind", ""):
			"say", "echo":
				r.text = "[b][color=#%s]%s[/color][/b]   %s" % [Kit.speaker_ink(sp).to_html(false), Kit.speaker_name(sp).to_upper(), t]
			"sms":
				r.text = "[b][color=#%s]%s[/color][/b]  [code]%s[/code]" % [Kit.speaker_ink(sp).to_html(false), Kit.speaker_name(sp).to_upper(), t]
			"sound":
				r.text = "[color=#3d6a52][i]≈ %s[/i][/color]" % t
			"think":
				r.text = "[color=#a23a30][i]%s[/i][/color]" % t
			_:
				r.text = t
		return r

	func _process(d: float) -> void:
		t += d

	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("menu") or e.is_action_pressed("log"):
			closed.emit()
			get_viewport().set_input_as_handled()

	func _paint_machine(ci: Control) -> void:
		# the paper curls over the top edge; the printer takes the bottom of the screen
		var body := Rect2(220, 600, 840, 140)
		Kit.shadow(ci, body, 0.4)
		ci.draw_rect(body, Color("b8b0a0"))
		ci.draw_rect(Rect2(body.position, Vector2(body.size.x, 4)), Color(1, 1, 1, 0.3))
		ci.draw_rect(Rect2(250, 604, 780, 14), Color("2a2622"))
		ci.draw_rect(Rect2(250, 604, 780, 3), Color(0, 0, 0, 0.5))
		Kit.text(ci, Vector2(270, 660), "BOOKING PRINTER  ·  FERRIER ST. EXCHANGE", "stamp", 18, Color("4a4238"))
		Kit.lamp(ci, Vector2(960, 652), 7.0, Kit.LAMP_GREEN, true)
		Kit.text(ci, Vector2(0, 712), "scroll to pull the paper   ·   L or ESC tear it off", "dotline", 12, Color("3a342c"), 1280, HORIZONTAL_ALIGNMENT_CENTER)

## The roll itself, drawn behind whatever is printed on it: sprocket holes
## down both edges, a perforation every sheet.
class _Roll extends MarginContainer:
	func _ready() -> void:
		for side in ["margin_left", "margin_right"]:
			add_theme_constant_override(side, 50)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("ece5d2"))
		var p := Kit.tex("res://assets/ui/paper.png")
		if p:
			draw_texture_rect(p, r, true, Color(1, 1, 1, 0.45))
		var y := 10.0
		while y < size.y:
			draw_circle(Vector2(18, y), 5.5, Color("1a1612"))
			draw_circle(Vector2(size.x - 18, y), 5.5, Color("1a1612"))
			y += 22.0
		for x in [36.0, size.x - 36.0]:
			var yy := 0.0
			while yy < size.y:
				draw_line(Vector2(x, yy), Vector2(x, yy + 3), Color(0.55, 0.5, 0.45, 0.5), 1.0)
				yy += 7.0
		var perf := 600.0
		while perf < size.y:
			for xx in range(0, int(size.x), 8):
				draw_line(Vector2(xx, perf), Vector2(xx + 4, perf), Color(0.5, 0.45, 0.4, 0.45), 1.0)
			perf += 600.0
