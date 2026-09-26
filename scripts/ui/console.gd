class_name Console
extends Control
## The talk console along the bottom of the screen: a steel panel, a small
## green screen for whoever is speaking, a wide one for the words, a row of
## red buttons for what Ari could say. Inez's old line-test set, as far as
## anyone knows, wired into 247 and left there.
##
## Modes:
##   "panel"   a bar across the bottom; one line at a time
##   "center"  no room to look at; a terminal in the middle, scrolling
##   "walk"    exploring; only a slim strip, plus any choices that aren't
##             somewhere in the room
##   "hidden"

signal advance_requested()
signal chosen(index: int)

const SPEAKERS := {
	"ARI": "ARI", "JAD": "JAD", "INEZ": "INEZ", "DIMA": "DIMA", "SAL": "SAL", "TEODOR": "TEODOR",
	"KAYE": "MRS. KAYE", "NELL": "NELL", "TOBI": "TOBI", "LINE": "RECORDING", "OPERATOR": "RECORDING",
	"RADIO": "RADIO", "MAN": "MAN OPPOSITE", "WOMAN": "WOMAN OPPOSITE", "JUNE": "JUNE PIKE", "ADEYEMI": "MR. ADEYEMI",
}
const PORTRAITS := ["jad", "inez", "dima", "sal", "teodor", "kaye", "nell"]

var mode := "panel"
var entry: Dictionary = {}
var history: Array = []  # entries shown in centre mode
var lines := PackedStringArray()  # wrapped current entry
var page := 0
var per_page := 4
var typed := 0.0
var typing := false
var options: Array = []  # [{text, tags, speech, index}]
var hot := -1
var taking := -1
var _armed_at := 0.0
var _opt_rects: Array = []
var t := 0.0
var portrait: TextureRect
var _portrait_key := ""
var _last_speaker := ""
var _blink := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/phosphor.gdshader")
	portrait.material = m
	portrait.visible = false
	add_child(portrait)
	Settings.changed.connect(restyle)
	restyle()

func restyle() -> void:
	(portrait.material as ShaderMaterial).set_shader_parameter("motion", 0.0 if Settings.reduced_motion else 1.0)
	_rewrap()
	_layout()

# ---------------------------------------------------------------- geometry

func body_kind() -> String:
	return "body"

func body_px() -> int:
	return Grim.body_size()

func lh() -> float:
	return floorf(Grim.line_h("body", body_px()) * 0.92)

func _text_rect() -> Rect2:
	match mode:
		"center":
			return Rect2(96, 60, 448, 240)
		"cutscene":
			return Rect2(48, size.y - 36, size.x - 96, 34)
		_:
			return Rect2(100, size.y - _panel_h() + 10, size.x - 110, _panel_h() - 20)

func _panel_h() -> float:
	var base := 12.0 + 16.0 + lh() * per_page + 8.0
	if mode == "walk":
		if options.is_empty():
			return 0.0
		return 16.0 + _options_h()
	if not options.is_empty():
		return clampf(28.0 + _prompt_h() + _options_h(), base, size.y * 0.62)
	return base

func _prompt_h() -> float:
	if entry.is_empty() or mode == "walk":
		return 0.0
	return lh() * mini(lines.size(), 2) + 6.0

func _options_h() -> float:
	var h := 0.0
	var w := size.x - 150.0
	for o in options:
		h += lh() * Grim.wrap_text(_opt_text(o), "body", body_px(), w).size() + 4.0
	return h

func _layout() -> void:
	var pr := _portrait_rect()
	portrait.position = pr.position
	portrait.size = pr.size
	queue_redraw()

func _portrait_rect() -> Rect2:
	var ph := _panel_h()
	return Rect2(10, size.y - ph + 10, 80, minf(80, ph - 20))

# ---------------------------------------------------------------- lines

func clear() -> void:
	entry = {}
	lines = PackedStringArray()
	history.clear()
	typing = false
	portrait.visible = false
	_portrait_key = ""
	queue_redraw()

func set_mode(m: String) -> void:
	mode = m
	visible = m != "hidden"
	_rewrap()
	_layout()

func add_line(e: Dictionary, instant: bool = false) -> void:
	finish_typing()
	entry = e
	history.append(e)
	while history.size() > 24:
		history.pop_front()
	page = 0
	_rewrap()
	typed = 0.0
	typing = not (instant or Settings.instant_text or e.get("kind", "") == "echo")
	_set_portrait(e)
	if typing and e.get("kind", "") != "sound":
		Audio.sfx("type_tick", -26.0)
	_layout()

func _entry_text(e: Dictionary) -> String:
	var s: String = e.get("text", "")
	match e.get("kind", ""):
		"sound":
			return "[" + s + "]"
		"sms":
			return "\"" + s + "\""
	return s

func _rewrap() -> void:
	if entry.is_empty():
		lines = PackedStringArray()
		return
	var w := _text_rect().size.x - 10.0
	lines = Grim.wrap_text(_entry_text(entry), "body", body_px(), w)
	if mode == "center":
		per_page = 99
	elif mode == "cutscene":
		per_page = 2
	else:
		per_page = 4

func _page_lines() -> PackedStringArray:
	if mode == "center":
		return lines
	return lines.slice(page * per_page, (page + 1) * per_page)

func _page_chars() -> int:
	var n := 0
	for l in _page_lines():
		n += l.length()
	return n

func pages() -> int:
	return maxi(1, ceili(float(lines.size()) / float(per_page)))

func is_typing() -> bool:
	return typing

func finish_typing() -> void:
	typing = false
	queue_redraw()

## Returns true if the click was used up turning a page or finishing type.
func consume_advance() -> bool:
	if typing:
		finish_typing()
		return true
	if mode != "center" and page < pages() - 1:
		page += 1
		typed = 0.0
		typing = not Settings.instant_text
		queue_redraw()
		return true
	return false

func _set_portrait(e: Dictionary) -> void:
	var sp: String = str(e.get("speaker", "")).to_lower()
	var kind: String = e.get("kind", "")
	if kind == "echo":
		return  # Ari's own words: keep whoever Ari's talking to
	var key := ""
	if kind == "say" and sp in PORTRAITS:
		var expr: String = Game.pres.get("portraits", {}).get(sp, {}).get("expr", "neutral")
		key = "%s_%s" % [sp, expr]
		if not ResourceLoader.exists("res://assets/portraits/%s.png" % key):
			key = "%s_neutral" % sp
	elif kind == "say":
		key = ""
	else:
		return
	_last_speaker = sp
	if key != _portrait_key:
		_portrait_key = key
		if key != "":
			portrait.texture = load("res://assets/portraits/%s.png" % key)
	portrait.visible = key != "" and mode in ["panel"]

# ---------------------------------------------------------------- choices

func show_choices(opts: Array) -> void:
	options = opts
	hot = -1
	taking = -1
	_armed_at = Time.get_ticks_msec() / 1000.0 + 0.25
	finish_typing()
	if mode != "walk" and mode != "center":
		page = maxi(0, pages() - 1)
	_layout()

func clear_choices() -> void:
	options = []
	hot = -1
	taking = -1
	_opt_rects.clear()
	_layout()

func _opt_text(o: Dictionary) -> String:
	var s: String = o["text"]
	if o.get("speech", false):
		s = "\"" + s + "\""
	if o.get("board", false):
		s = "[ON THE BOARD] " + s
	return s

func pick(i: int) -> void:
	if taking >= 0 or i < 0 or i >= options.size():
		return
	if Time.get_ticks_msec() / 1000.0 < _armed_at:
		return
	taking = i
	Audio.sfx("key_throw", -8.0)
	var idx: int = options[i].get("index", i)
	var d := 0.02 if Settings.reduced_motion else 0.18
	get_tree().create_timer(d).timeout.connect(func():
		if taking == i:
			clear_choices()
			chosen.emit(idx))

# ---------------------------------------------------------------- input

func _process(d: float) -> void:
	t += d
	_blink += d
	if typing:
		typed += d * Settings.chars_per_second()
		if typed >= _page_chars():
			typing = false
		queue_redraw()
	elif int(_blink * 2.0) % 2 == 0 or not options.is_empty():
		queue_redraw()
	else:
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := -1
		for k in _opt_rects.size():
			if _opt_rects[k].has_point(e.position):
				h = k
		if h != hot:
			hot = h
			if h >= 0:
				Audio.sfx("tick", -22.0)
			queue_redraw()
		ScreenFx.want("use" if h >= 0 else "point")
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if hot >= 0:
			pick(hot)
		elif options.is_empty() or mode == "center":
			advance_requested.emit()
		accept_event()

func _unhandled_key_input(e: InputEvent) -> void:
	if options.is_empty() or not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < options.size():
			pick(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_UP or k == KEY_W:
			hot = (hot - 1 + options.size()) % options.size() if hot >= 0 else options.size() - 1
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif k == KEY_DOWN or k == KEY_S:
			hot = (hot + 1) % options.size()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE) and hot >= 0:
			pick(hot)
			get_viewport().set_input_as_handled()

func has_point(p: Vector2) -> bool:
	if not visible:
		return false
	if mode == "center" or mode == "cutscene":
		return true
	return p.y >= size.y - _panel_h()

func _has_point(p: Vector2) -> bool:
	return has_point(p)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_opt_rects.clear()
	match mode:
		"hidden":
			return
		"center":
			_draw_center()
		"cutscene":
			_draw_cutscene()
		_:
			_draw_panel()

func _draw_panel() -> void:
	var ph := _panel_h()
	if ph <= 0.0:
		return
	var r := Rect2(0, size.y - ph, size.x, ph)
	Grim.plate(self, r, "steel", 7.0)
	# rust bleeding up from the bottom edge
	var rt := Grim.surf("rust")
	if rt and not Grim.plain():
		draw_texture_rect_region(rt, Rect2(r.position.x + 1, r.end.y - 7, r.size.x - 2, 6), Rect2(40, 60, r.size.x - 2, 6), Color(1, 1, 1, 0.8))
	var tr := Rect2(100, r.position.y + 8, size.x - 110, ph - 16)
	var pr := Rect2(10, r.position.y + 8, 82, minf(82, ph - 16))
	if mode == "walk":
		tr = Rect2(10, r.position.y + 8, size.x - 20, ph - 16)
	else:
		Grim.crt(self, pr, t)
		if not portrait.visible:
			_draw_idle_face(pr)
	Grim.crt(self, tr, t + 3.0)
	var x := tr.position.x + 8
	var y := tr.position.y + 4
	var sz := body_px()
	var lhh := lh()
	if not entry.is_empty() and mode != "walk":
		var kind: String = entry.get("kind", "")
		var name := _name_of(entry)
		var col := _col_of(entry)
		if options.is_empty():
			# the speaker plate
			if name != "":
				var nw := Grim.text_w(name, "head", 16) + 8
				draw_rect(Rect2(x - 3, y + 1, nw, 13), Color(col, 0.9))
				Grim.text(self, Vector2(x + 1, y + 12), name, "head", 16, Grim.PHOS_BG)
				var who := str(entry.get("speaker", "")).to_lower()
				if Grim.WHO.has(who):
					Grim.lamp(self, Vector2(x + nw + 5, y + 7), Grim.WHO[who], true, 2)
				y += 16
			elif kind == "think":
				Grim.text(self, Vector2(x, y + 12), "ARI, UNBIDDEN", "tiny", 8, Grim.AMBER_DIM)
				y += 12
			elif kind == "sound":
				Grim.text(self, Vector2(x, y + 12), "HEARD", "tiny", 8, Grim.PHOS_DIM)
				y += 12
			var shown := int(typed) if typing else 1 << 30
			var pl := _page_lines()
			for i in pl.size():
				var s: String = pl[i]
				if shown <= 0:
					break
				var vis := s.substr(0, shown)
				shown -= s.length()
				Grim.glow_text(self, Vector2(x, y + lhh - 3), vis, "body", sz, col)
				y += lhh
			if not typing:
				var more := page < pages() - 1
				if int(t * 2.0) % 2 == 0 or Settings.reduced_motion:
					var p := Vector2(tr.end.x - 14, tr.end.y - 9)
					if more:
						draw_rect(Rect2(p, Vector2(7, 3)), Grim.PHOS_MID)
						draw_rect(Rect2(p + Vector2(2, 3), Vector2(3, 2)), Grim.PHOS_MID)
					else:
						draw_rect(Rect2(p, Vector2(7, 5)), Grim.PHOS_MID)
		else:
			# the question still showing, dimmed, above the answers
			var pl2 := lines.slice(maxi(0, lines.size() - 2))
			for s in pl2:
				Grim.text(self, Vector2(x, y + lhh - 3), s, "body", sz, Color(col, 0.45))
				y += lhh
			y += 4
			draw_rect(Rect2(x, y - 3, tr.size.x - 16, 1), Color(Grim.PHOS_DIM, 0.5))
	if not options.is_empty():
		if mode == "walk":
			Grim.text(self, Vector2(x, y + 9), "OR ELSE", "tiny", 8, Grim.PHOS_DIM)
			y += 10
		var w := tr.size.x - 40
		for i in options.size():
			var o: Dictionary = options[i]
			var ls := Grim.wrap_text(_opt_text(o), "body", sz, w)
			var h := lhh * ls.size() + 2
			var orow := Rect2(tr.position.x + 2, y - 1, tr.size.x - 4, h + 2)
			_opt_rects.append(orow)
			var is_hot := i == hot and taking < 0
			var taken := i == taking
			if is_hot:
				draw_rect(orow, Color(Grim.PHOS_DIM, 0.35))
			Grim.red_button(self, Vector2(x + 5, y + lhh * 0.5), is_hot, taken, 4)
			var num := str(i + 1)
			Grim.text(self, Vector2(x + 14, y + lhh - 3), num, "head", 16, Grim.AMBER if is_hot else Grim.AMBER_DIM)
			var c := Grim.PHOS if is_hot else Grim.PHOS_MID
			if taking >= 0 and not taken:
				c = Grim.PHOS_DIM
			for k in ls.size():
				Grim.glow_text(self, Vector2(x + 26, y + lhh - 3 + k * lhh), ls[k], "body", sz, c)
			y += h + 2
	Grim.crt_glass(self, tr)
	if mode != "walk":
		Grim.crt_glass(self, pr)

func _draw_idle_face(pr: Rect2) -> void:
	# nobody's face: what the little screen shows instead
	var kind: String = entry.get("kind", "") if not entry.is_empty() else ""
	var c := pr.get_center()
	if kind == "sound":
		# a trace on the scope
		var pts := PackedVector2Array()
		for i in int(pr.size.x - 12):
			var xx := pr.position.x + 6 + i
			var a := sin(i * 0.45 + t * 9.0) * sin(i * 0.07 + t * 2.0) * (pr.size.y * 0.28)
			pts.append(Vector2(xx, round(c.y + a)))
		draw_polyline(pts, Grim.PHOS_MID, 1.0)
	elif kind == "think":
		# static, and something nearly in it
		for i in 90:
			var s: float = floorf(t * 12.0) * 31.0 + i
			var p := pr.position + Vector2(3 + Grim.rnd(s) * (pr.size.x - 6), 3 + Grim.rnd(s + 0.5) * (pr.size.y - 6))
			draw_rect(Rect2(p.floor(), Vector2.ONE), Color(Grim.PHOS, 0.25 + Grim.rnd(s + 2.0) * 0.4))
	else:
		var who := str(entry.get("speaker", "")) if not entry.is_empty() else ""
		var initial := who.substr(0, 1) if who != "" and entry.get("kind", "") in ["say", "sms"] else "247"
		var fsz := 40 if initial.length() == 1 else 24
		Grim.text(self, Vector2(pr.position.x, c.y + fsz * 0.35), initial, "head", fsz, Grim.PHOS_DIM, pr.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_center() -> void:
	var r := _text_rect()
	var frame := r.grow(10)
	Grim.plate(self, frame, "steel", 11.0)
	Grim.crt(self, r, t)
	var sz := body_px()
	var lhh := lh()
	var w := r.size.x - 20
	# the whole recent history, bottom-aligned like a terminal
	var blocks: Array = []
	var total := 0.0
	for i in range(history.size() - 1, -1, -1):
		var e: Dictionary = history[i]
		var ls := Grim.wrap_text(_entry_text(e), "body", sz, w)
		total += ls.size() * lhh + 6
		blocks.push_front([e, ls])
		if total > r.size.y - 20 - _options_h():
			break
	var y := r.end.y - 10 - _options_h() - total + 2
	for bi in blocks.size():
		var e: Dictionary = blocks[bi][0]
		var ls: PackedStringArray = blocks[bi][1]
		var latest := bi == blocks.size() - 1
		var col := _col_of(e)
		if not latest:
			col = Color(col, 0.45)
		var shown := int(typed) if (latest and typing) else 1 << 30
		for l in ls:
			if y > r.position.y + 2 and shown > 0:
				Grim.glow_text(self, Vector2(r.position.x + 10, y + lhh - 3), l.substr(0, shown), "body", sz, col)
			shown -= l.length()
			y += lhh
		y += 6
	if not options.is_empty():
		y = r.end.y - 6 - _options_h()
		for i in options.size():
			var o: Dictionary = options[i]
			var ls2 := Grim.wrap_text(_opt_text(o), "body", sz, w - 30)
			var h := lhh * ls2.size() + 2
			var orow := Rect2(r.position.x + 2, y - 1, r.size.x - 4, h + 2)
			_opt_rects.append(orow)
			var is_hot := i == hot and taking < 0
			if is_hot:
				draw_rect(orow, Color(Grim.PHOS_DIM, 0.35))
			Grim.red_button(self, Vector2(r.position.x + 15, y + lhh * 0.5), is_hot, i == taking, 4)
			Grim.text(self, Vector2(r.position.x + 24, y + lhh - 3), str(i + 1), "head", 16, Grim.AMBER if is_hot else Grim.AMBER_DIM)
			for k in ls2.size():
				Grim.glow_text(self, Vector2(r.position.x + 36, y + lhh - 3 + k * lhh), ls2[k], "body", sz, Grim.PHOS if is_hot else Grim.PHOS_MID)
			y += h + 2
	elif not typing and int(t * 2.0) % 2 == 0:
		draw_rect(Rect2(r.position.x + 10, y - 4, 8, 3), Grim.PHOS_MID)
	Grim.crt_glass(self, r)

## Subtitles in the bottom bar; choices, if any, float just above it.
func _draw_cutscene() -> void:
	var r := _text_rect()
	var sz := 16 if not Grim.plain() else 12
	var lhh := 15.0
	if not entry.is_empty() and options.is_empty():
		var col := _col_of(entry)
		var name := _name_of(entry)
		var pl := _page_lines()
		var y := r.position.y + (8 if pl.size() > 1 else 16)
		var shown := int(typed) if typing else 1 << 30
		for i in pl.size():
			var s: String = pl[i]
			if i == 0 and name != "":
				s = name + ": " + s
			var vis := s.substr(0, maxi(0, shown + (name.length() + 2 if i == 0 and name != "" else 0)))
			shown -= pl[i].length()
			Grim.glow_text(self, Vector2(r.position.x, y + 4), vis, "body", sz, col, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			y += lhh
	if not options.is_empty():
		var w := r.size.x - 60
		var total := 0.0
		for o in options:
			total += lhh * Grim.wrap_text(_opt_text(o), "body", sz, w).size() + 4
		var y2 := size.y - 44 - total
		Grim.band(self, Rect2(r.position.x - 8, y2 - 6, r.size.x + 16, total + 10), 0.8)
		for i in options.size():
			var o: Dictionary = options[i]
			var ls := Grim.wrap_text(_opt_text(o), "body", sz, w)
			var h := lhh * ls.size() + 2
			var orow := Rect2(r.position.x, y2 - 2, r.size.x, h + 2)
			_opt_rects.append(orow)
			var is_hot := i == hot and taking < 0
			if is_hot:
				draw_rect(orow, Color(Grim.RED_DK, 0.5))
			Grim.red_button(self, Vector2(r.position.x + 8, y2 + lhh * 0.5 - 1), is_hot, i == taking, 3)
			for k in ls.size():
				Grim.glow_text(self, Vector2(r.position.x + 20, y2 + lhh - 3 + k * lhh), ls[k], "body", sz, Grim.IVORY if is_hot else Grim.IVORY_DIM)
			y2 += h + 2

func _name_of(e: Dictionary) -> String:
	match e.get("kind", ""):
		"say", "echo", "sms":
			var sp: String = e.get("speaker", "")
			var n: String = SPEAKERS.get(sp, sp)
			if e["kind"] == "sms":
				n += "  (PRINTED)"
			return n
	return ""

func _col_of(e: Dictionary) -> Color:
	if Grim.plain():
		match e.get("kind", ""):
			"think":
				return Color("e8c8a0")
			"sound":
				return Color("a0c0b0")
		return Color("f0f0f0")
	match e.get("kind", ""):
		"say":
			return Grim.PHOS
		"echo":
			return Grim.IVORY
		"think":
			return Grim.AMBER
		"sound":
			return Color("6fbf9a")
		"sms":
			return Color("b8ffc2")
	return Grim.PHOS_MID
