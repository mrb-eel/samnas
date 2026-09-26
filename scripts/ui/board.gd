class_name Board
extends Control
## The attendant's board: the Baths' old cord switchboard in the frame room.
## Ari doesn't carry a phone. Ari is on this.
##
##   jack field  forty-two flats, floor by floor, lamps for who's awake;
##               the people Ari knows have tags cut from food packets
##   cord        Ari's own cord, home in 247; plug it into a jack to ring
##               or answer, pull it (CLEAR) to end, park it in HOLD
##   keys        LOOK, LISTEN, HOLD, CLEAR, RELEASE (door)
##   printer     the Baths' booking printer: messages to 247 come out on a
##               paper strip, black for them, red for Ari
##   spike       tickets waiting for a reply
##   tape        the answering machine: counter, index card, transcripts
##   pinboard    pictures, which arrive as coarse dot printouts
##
## Modes: "full" (Tab: the whole board), "strip" (a call: a vertical slice of
## the board beside the scene), "printer" (the script is exchanging messages).

signal call_requested(who: String)
signal reply_requested(who: String)
signal doc_requested(id: String)
signal advance_requested()
signal close_requested()
signal control_picked(tag: String)

const FLOORS := 6
const FLATS := ["A", "B", "C", "D", "E", "F", "G"]
# Flats with a name on them. Contacts first; the rest are neighbours Ari never meets.
const TAGGED := {
	"4B": ["jad", "JAD"], "3D": ["dima", "DIMA"], "3B": ["nell", "NELL + TOBI"], "2C": ["kaye", "MRS KAYE"],
	"5A": ["teodor", "TEODOR"], "1A": ["", "INEZ (HOME)"], "1D": ["", "ADEYEMI"], "1B": ["", "J. PIKE"],
	"2A": ["", "ROSTAMI"], "6A": ["", "RUSU"], "6C": ["", "HOLLIS"],
}
# Food-packet stripes for the name tags.
const PACKETS := ["SEMI-SKIMMED", "BEST BEFORE", "SERVES 4", "WHOLEMEAL", "LOW FAT", "FAMILY PACK", "NEW RECIPE", "SLICED", "PRODUCE OF", "KEEP COOL", "EXTRA MATURE"]
const PACKET_COLS := [Color("3a6fb0"), Color("c43a2e"), Color("3d8a4f"), Color("d49a2a"), Color("7a4a9a"), Color("2a8a8a"), Color("b0503a"), Color("5a5a5a"), Color("9a7a2a"), Color("4a6a9a"), Color("8a3a5a")]
const SPECIALS := [
	["sal", "209", "DESK"], ["inez", "299", "TEST SET"], ["door", "200", "DOOR"], ["receiving", "201", "RECEIVING"],
	["hold", "HOLD", "HOLD"], ["line1", "LINE 1", "OUTSIDE"], ["home", "247", "ARI"],
]
const KEYS := [["look", "LOOK"], ["listen", "LISTEN"], ["hold", "HOLD"], ["clear", "CLEAR"], ["release", "RELEASE 9"]]
const VERB_KEY := {"look": "key:look", "listen": "key:listen", "hold": "key:hold", "end": "key:clear"}

const BAKELITE := Color("2a211d")
const BAKELITE_HI := Color("3b2f28")
const BRASS := Color("b08d4a")
const BRASS_DK := Color("6e5528")
const LAMP_AMBER := Color("f0b24a")
const LAMP_WARM := Color("e8d6a8")
const CORD_RED := Color("8e2a22")
const PAPER := Color("ece5d2")
const INK_BLACK := Color("1c1a1a")
const INK_RED := Color("a8261d")

var mode := "full"
var sub := "strip"  # right panel in full mode: strip | tape | pins | spike | calls
var sel_contact := ""
var sel_vm := ""
var script_thread := ""
var call_who := ""
var ring_who := ""
var view_who := "none"
var active_tags: Dictionary = {}
var choices: ChoiceList
var t := 0.0
var hover := ""
var focus_jack := 0
var cord_to := "home"
var cord_anim := 1.0
var _cord_from := "home"
var _rects: Dictionary = {}  # id -> Rect2 in local coords
var _panel: Control
var _panel_scroll: ScrollContainer
var _panel_box: VBoxContainer
var _status := ""
var _flat_warm: Dictionary = {}
var _tex_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_panel = Control.new()
	_panel.clip_contents = true
	add_child(_panel)
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_panel_scroll)
	_panel_box = VBoxContainer.new()
	_panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_box.add_theme_constant_override("separation", 6)
	_panel_scroll.add_child(_panel_box)
	choices = ChoiceList.new()
	choices.surface = "board"
	choices.visible = false
	add_child(choices)
	Game.phone_changed.connect(refresh)
	Settings.changed.connect(refresh)
	_seed_warm()
	set_mode("full")

func _seed_warm() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for f in range(1, FLOORS + 1):
		for l in FLATS:
			_flat_warm["%d%s" % [f, l]] = r.randf() < 0.18

# ------------------------------------------------------------------ layout

func set_mode(m: String) -> void:
	mode = m
	match m:
		"full":
			position = Vector2.ZERO
			size = Vector2(1280, 720)
		"strip":
			position = Vector2(918, 50)
			size = Vector2(344, 652)
		"printer":
			position = Vector2(452, 52)
			size = Vector2(390, 648)
	_layout_children()
	if choices.items.size() > 0:
		choices.visible = m != "full"
	refresh()

func _layout_children() -> void:
	match mode:
		"full":
			_panel.position = Vector2(760, 206)
			_panel.size = Vector2(492, 476)
			choices.position = Vector2(760, 206)
			choices.size = Vector2(492, 10)
		"strip":
			_panel.position = Vector2(16, 250)
			_panel.size = Vector2(0, 0)
			choices.position = Vector2(14, 356)
			choices.size = Vector2(316, 10)
		"printer":
			_panel.position = Vector2(34, 60)
			_panel.size = Vector2(322, 330)
			choices.position = Vector2(14, 470)
			choices.size = Vector2(362, 10)

# ------------------------------------------------------------------ state from Game

func sync(ring: String, call: String, view: String, thread: String) -> void:
	ring_who = ring
	call_who = call
	view_who = view
	script_thread = thread
	var target := "home"
	if call != "":
		target = call
	if Game.pres.get("cord_hold", false):
		target = "hold"
	if target != cord_to:
		_cord_from = cord_to
		cord_to = target
		cord_anim = 1.0 if Settings.reduced_motion else 0.0
		Audio.sfx("plug_in" if target != "home" else "plug_out", -6.0)
	if thread != "":
		sel_contact = thread
		Game.mark_thread_read(thread)
	refresh()

func set_active_tags(options: Array) -> void:
	active_tags.clear()
	for i in options.size():
		var tags: Array = options[i].get("tags", [])
		for tg in tags:
			if tg.begins_with("jack:") or tg.begins_with("key:"):
				active_tags[tg] = i
			elif VERB_KEY.has(tg):
				active_tags[VERB_KEY[tg]] = i
			elif tg == "answer" and ring_who != "":
				active_tags["jack:" + ring_who] = i
	queue_redraw()

func clear_active() -> void:
	active_tags.clear()
	queue_redraw()

# ------------------------------------------------------------------ refresh panels

func refresh() -> void:
	if _panel_box == null:
		return
	for c in _panel_box.get_children():
		_panel_box.remove_child(c)
		c.queue_free()
	match mode:
		"full":
			_panel.visible = true
			match sub:
				"strip":
					_fill_strip(sel_contact, false)
				"tape":
					_fill_tape()
				"pins":
					_fill_pins()
				"spike":
					_fill_spike()
				"calls":
					_fill_calls()
		"printer":
			_panel.visible = true
			_fill_strip(script_thread, true)
		_:
			_panel.visible = false
	queue_redraw()

func _paper_label(txt: String, col: Color = INK_BLACK, size: int = 15, kind: String = "text") -> Label:
	var l := Kit.label(txt, size, col if not Settings.clean_text else Color.WHITE, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	return l

func _cdef(who: String) -> Dictionary:
	return Game.contacts_def.get(who, {"name": who.capitalize(), "place": ""})

func _fill_strip(who: String, scripted: bool) -> void:
	if who == "" or not Game.phone["contacts"].has(who):
		var any := false
		for id in Game.contacts_order:
			if Game.phone["contacts"][id]["thread"].size() > 0:
				any = true
				who = id
				break
		if not any:
			_panel_box.add_child(_paper_label("Nothing has come through the printer yet.", Color("6a6458"), 15, "italic"))
			return
	sel_contact = who
	var c: Dictionary = Game.phone["contacts"][who]
	var d := _cdef(who)
	var head := _paper_label("%s · %s" % [d.get("name", who).to_upper(), d.get("place", "")], INK_BLACK, 14, "bold")
	_panel_box.add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(INK_BLACK, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	_panel_box.add_child(rule)
	for m in c["thread"]:
		_strip_entry(m, who)
	if not scripted and c["reply_label"] != "":
		var b := Kit.button("→ answer on the printer: " + c["reply_prompt"], 15)
		b.add_theme_stylebox_override("normal", Kit.flat(Color(INK_RED, 0.18), INK_RED, 1, 2, 8))
		b.add_theme_color_override("font_color", INK_RED.darkened(0.3) if not Settings.clean_text else Color.WHITE)
		b.disabled = not Game.can_interrupt()
		b.pressed.connect(func(): reply_requested.emit(who))
		_panel_box.add_child(b)
		if b.disabled:
			_panel_box.add_child(_paper_label("You can answer once this moment lets you.", Color("6a6458"), 13, "italic"))
	Game.mark_thread_read(who)
	call_deferred("_scroll_bottom")

func _strip_entry(m: Dictionary, who: String) -> void:
	var from: String = m["from"]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var stamp := ""
	match from:
		"ari":
			stamp = "%s   247 → %s" % [m.get("clock", ""), _cdef(who).get("place", who)]
		"them":
			stamp = "%s   %s → 247" % [m.get("clock", ""), _cdef(who).get("place", who)]
		_:
			stamp = m.get("clock", "")
	vb.add_child(_paper_label(stamp, Color("7a7264"), 11, "bold"))
	if m.get("doc", "") != "":
		var doc_id: String = m["doc"]
		var dd: Dictionary = Game.docs_def.get(doc_id, {})
		var tb := Button.new()
		tb.flat = true
		tb.focus_mode = Control.FOCUS_ALL
		tb.custom_minimum_size = Vector2(200, 120)
		var tr := TextureRect.new()
		var tex := _doc_tex(doc_id, true)
		if tex:
			tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(tr)
		tb.pressed.connect(func(): doc_requested.emit(doc_id))
		vb.add_child(tb)
		vb.add_child(_paper_label("[printed picture: %s — click to look]" % dd.get("title", doc_id), Color("6a6458"), 12, "italic"))
	if m["text"] != "":
		var col := INK_RED if from == "ari" else INK_BLACK
		if from == "sys":
			col = Color("6a6458")
		vb.add_child(_paper_label(m["text"], col, 16 if from != "sys" else 13, "text" if from != "sys" else "italic"))
	_panel_box.add_child(vb)

func _doc_tex(id: String, printed: bool) -> Texture2D:
	var dd: Dictionary = Game.docs_def.get(id, {})
	var paths: Array = []
	if printed and dd.has("print"):
		paths.append(dd["print"])
	paths.append(dd.get("image", ""))
	for p in paths:
		if p != "" and ResourceLoader.exists(p):
			return load(p)
	return null

func _scroll_bottom() -> void:
	await get_tree().process_frame
	_panel_scroll.scroll_vertical = int(_panel_scroll.get_v_scroll_bar().max_value)

func _fill_tape() -> void:
	var vms: Array = Game.phone["voicemails"].duplicate()
	vms.sort_custom(func(a, b): return str(Game.voicemail_def.get(a["id"], {}).get("sort", "")) < str(Game.voicemail_def.get(b["id"], {}).get("sort", "")))
	_panel_box.add_child(_paper_label("ANSWERING MACHINE · INDEX CARD", INK_BLACK, 14, "bold"))
	if vms.is_empty():
		_panel_box.add_child(_paper_label("Nothing on the tape.", Color("6a6458"), 14, "italic"))
	var n := 1
	for v in vms:
		var d: Dictionary = Game.voicemail_def.get(v["id"], {})
		var id: String = v["id"]
		var mark := "● " if not v["heard"] else "   "
		var b := Button.new()
		b.text = "%s%02d  %s  ·  %s" % [mark, n, d.get("when", ""), d.get("from_name", "")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_override("font", Kit.font("text"))
		b.add_theme_font_size_override("font_size", 14)
		var col := INK_RED if not v["heard"] else INK_BLACK
		if Settings.clean_text:
			col = Color.WHITE
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", INK_RED)
		b.add_theme_color_override("font_focus_color", INK_RED)
		b.pressed.connect(func(): sel_vm = id; Game.mark_vm_heard(id); Audio.sfx("tape_play", -6.0); refresh())
		_panel_box.add_child(b)
		if sel_vm == id:
			var box := PanelContainer.new()
			box.add_theme_stylebox_override("panel", Kit.flat(Color(1, 1, 1, 0.35) if not Settings.clean_text else Color(0.15, 0.15, 0.15), Color(INK_BLACK, 0.3), 1, 2, 10))
			var inner := VBoxContainer.new()
			box.add_child(inner)
			inner.add_child(_paper_label("%s · %s" % [d.get("from_name", ""), d.get("length", "")], Color("5a5448"), 12, "bold"))
			inner.add_child(_paper_label(d.get("text", ""), INK_BLACK, 15))
			if d.has("audio"):
				var pb := Kit.button("▶ play it again", 13)
				pb.pressed.connect(func(): Audio.sfx(d["audio"]))
				inner.add_child(pb)
			_panel_box.add_child(box)
		n += 1
	if not Game.phone.get("archive_open", false):
		_panel_box.add_child(_paper_label("Reel two, older messages: not threaded. (Someone who knows the machine could put it on.)", Color("6a6458"), 13, "italic"))

func _fill_pins() -> void:
	_panel_box.add_child(_paper_label("PINNED UP", INK_BLACK, 14, "bold"))
	if Game.phone["gallery"].is_empty():
		_panel_box.add_child(_paper_label("Nothing pinned up yet.", Color("6a6458"), 14, "italic"))
		return
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	_panel_box.add_child(g)
	for item in Game.phone["gallery"]:
		var id: String = item["id"]
		var dd: Dictionary = Game.docs_def.get(id, {})
		var vb := VBoxContainer.new()
		var tb := Button.new()
		tb.flat = true
		tb.custom_minimum_size = Vector2(146, 104)
		tb.focus_mode = Control.FOCUS_ALL
		var tr := TextureRect.new()
		var tex := _doc_tex(id, item.get("from", "") != "")
		if tex:
			tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(tr)
		tb.pressed.connect(func(): doc_requested.emit(id))
		vb.add_child(tb)
		var l := _paper_label(dd.get("title", id), INK_BLACK, 12)
		l.custom_minimum_size = Vector2(146, 0)
		vb.add_child(l)
		g.add_child(vb)

func _fill_spike() -> void:
	_panel_box.add_child(_paper_label("ON THE SPIKE · waiting for an answer", INK_BLACK, 14, "bold"))
	var any := false
	for id in Game.contacts_order:
		var c: Dictionary = Game.phone["contacts"][id]
		if c["reply_label"] == "":
			continue
		any = true
		var who: String = id
		var b := Kit.button("%s · %s" % [_cdef(id).get("name", id), c["reply_prompt"]], 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not Game.can_interrupt()
		b.pressed.connect(func(): reply_requested.emit(who))
		_panel_box.add_child(b)
	if not any:
		_panel_box.add_child(_paper_label("Nothing on the spike.", Color("6a6458"), 14, "italic"))
	elif not Game.can_interrupt():
		_panel_box.add_child(_paper_label("You can answer once this moment lets you.", Color("6a6458"), 13, "italic"))

func _fill_calls() -> void:
	_panel_box.add_child(_paper_label("CALL TICKETS", INK_BLACK, 14, "bold"))
	var log: Array = Game.phone["log"]
	for i in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[i]
		var dir: String = {"in": "came in", "out": "went out", "missed": "UNANSWERED"}.get(e["dir"], e["dir"])
		var col := INK_RED if e["dir"] == "missed" else INK_BLACK
		_panel_box.add_child(_paper_label("%s   %s   %s" % [e.get("when", ""), _cdef(e["who"]).get("name", e["who"]).to_upper(), dir], col, 14))

# ------------------------------------------------------------------ drawing

func _process(delta: float) -> void:
	t += delta
	if cord_anim < 1.0:
		cord_anim = minf(1.0, cord_anim + delta * 2.5)
	if visible:
		queue_redraw()

func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tx: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = tx
	return tx

func _draw() -> void:
	_rects.clear()
	match mode:
		"full":
			_draw_full()
		"strip":
			_draw_strip()
		"printer":
			_draw_printer()

func _panel_bg(r: Rect2, col: Color = BAKELITE) -> void:
	draw_rect(r, col)
	var tx := _tex("res://assets/ui/bakelite.png")
	if tx:
		draw_texture_rect(tx, r, true, Color(1, 1, 1, 0.55))
	draw_rect(r, Color("120e0c"), false, 3.0)
	draw_rect(r.grow(-5), Color(BRASS_DK, 0.6), false, 1.0)

func _draw_full() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.035, 0.97))
	var wall := _tex("res://assets/tex/relays.png")
	if wall:
		draw_texture_rect(wall, Rect2(0, 0, 1280, 720), true, Color(0.25, 0.25, 0.27, 1.0))
	# console
	var console := Rect2(24, 52, 716, 646)
	_panel_bg(console)
	_plaque(Rect2(44, 64, 420, 30), "FERRIER ST. BATHS · ATTENDANT'S POSITION")
	_caller_box(Rect2(484, 62, 238, 38))
	_draw_jack_field(Rect2(44, 110, 676, 356))
	_draw_specials(Rect2(44, 472, 676, 78))
	_draw_keys(Rect2(44, 560, 676, 64))
	_draw_cord()
	# status line
	var st := _status_text()
	if hover == "" and not active_tags.is_empty():
		st = "Something is waiting on you: the jack or key framed in red."
	draw_rect(Rect2(44, 634, 676, 52), Color(0, 0, 0, 0.55))
	draw_string(Kit.font("text"), Vector2(56, 658), st, HORIZONTAL_ALIGNMENT_LEFT, 660, 15, Kit.IVORY)
	draw_string(Kit.font("italic"), Vector2(56, 679), "Click a lit jack to ring someone. Tab or Esc puts the board away.", HORIZONTAL_ALIGNMENT_LEFT, 660, 13, Kit.IVORY_DIM)
	# right-hand desk: printer, spike, tape, pins, tickets
	var desk := Rect2(752, 52, 508, 646)
	draw_rect(desk, Color("1b1714"))
	draw_rect(desk, Color("0d0b0a"), false, 2.0)
	_desk_objects(Rect2(760, 60, 492, 136))
	# reading surface
	var read_r := Rect2(756, 202, 500, 484)
	if Settings.clean_text:
		draw_rect(read_r, Color.BLACK)
	else:
		draw_rect(read_r, PAPER)
		var ptx := _tex("res://assets/ui/paper.png")
		if ptx:
			draw_texture_rect(ptx, read_r, true, Color(1, 1, 1, 0.6))
		# torn top edge
		for i in 50:
			var x := read_r.position.x + i * 10
			draw_colored_polygon(PackedVector2Array([Vector2(x, read_r.position.y), Vector2(x + 5, read_r.position.y + 4 + (i % 3)), Vector2(x + 10, read_r.position.y)]), Color("1b1714"))
	draw_rect(read_r, Color(0, 0, 0, 0.5), false, 1.0)

func _plaque(r: Rect2, txt: String) -> void:
	draw_rect(r, BRASS)
	draw_rect(r, BRASS_DK, false, 2.0)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 5), Vector2(r.size.x, 5)), Color(BRASS_DK, 0.5))
	var f := Kit.font("display")
	draw_string(f, r.position + Vector2(12, r.size.y - 9), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 17, Color("2c2210"))
	for c in [r.position + Vector2(5, 5), Vector2(r.end.x - 5, r.position.y + 5), Vector2(r.position.x + 5, r.end.y - 5), r.end - Vector2(5, 5)]:
		draw_circle(c, 2.2, BRASS_DK)

func _caller_box(r: Rect2) -> void:
	# A cheap plastic caller-display, screwed to the board with a picture hook.
	draw_rect(r.grow(3), Color("d8d4c8"))
	draw_rect(r.grow(3), Color("8a867c"), false, 1.0)
	draw_rect(r, Color("8fa77f"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0, 0, 0, 0.2))
	var who := ring_who if ring_who != "" else call_who
	var line1 := "NO CALL"
	if who != "" and who != "home":
		var d := _cdef(who)
		line1 = ("RINGING  " if ring_who != "" else "CONNECTED  ") + str(d.get("place", "")).to_upper()
		draw_string(Kit.font("bold"), r.position + Vector2(8, 34), str(d.get("name", who)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 14, Color("1f2a1a"))
	draw_string(Kit.font("bold"), r.position + Vector2(8, 16), line1, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 12, Color("1f2a1a"))
	draw_string(Kit.font("text"), Vector2(r.end.x - 44, r.position.y + 16), Game.pres.get("clock", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1f2a1a"))

func _flat_owner(flat: String) -> String:
	return TAGGED.get(flat, ["", ""])[0]

func _jack_state(who: String) -> Dictionary:
	# lamp: off | warm | ring | on ; tag: reason text when unavailable
	var st := {"lamp": "off", "msg": false, "reply": false, "reason": "", "callable": false}
	if who == "" or not Game.phone["contacts"].has(who):
		return st
	var c: Dictionary = Game.phone["contacts"][who]
	if ring_who == who:
		st["lamp"] = "ring"
	elif call_who == who:
		st["lamp"] = "on"
	elif c["call_label"] != "" and c["avail"]:
		st["lamp"] = "warm"
		st["callable"] = true
	st["msg"] = int(c["unread"]) > 0
	st["reply"] = c["reply_label"] != ""
	if not st["callable"] and st["lamp"] == "off":
		st["reason"] = c["reason"]
	return st

func _draw_jack_field(area: Rect2) -> void:
	draw_rect(area, Color(0, 0, 0, 0.25))
	var cw := area.size.x / 7.0
	var ch := area.size.y / 6.0
	var packet_i := 0
	for floor_i in FLOORS:
		var fl := FLOORS - floor_i
		draw_string(Kit.font("display"), Vector2(area.position.x - 14, area.position.y + floor_i * ch + ch * 0.55), str(fl), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(BRASS, 0.9))
		for li in FLATS.size():
			var flat := "%d%s" % [fl, FLATS[li]]
			var cell := Rect2(area.position.x + li * cw, area.position.y + floor_i * ch, cw, ch).grow(-3)
			var who := _flat_owner(flat)
			var known: bool = who != "" and Game.phone["contacts"].has(who) and Game.phone["contacts"][who]["known"]
			var tagged := TAGGED.has(flat)
			var id := "jack:" + (who if who != "" else flat)
			_rects[id] = cell
			var hot := hover == id or active_tags.has(id)
			# tag
			if tagged:
				var tag_r := Rect2(cell.position + Vector2(4, 2), Vector2(cell.size.x - 8, 17))
				var pc: Color = PACKET_COLS[packet_i % PACKET_COLS.size()]
				draw_rect(tag_r, Color("efe9da") if known or who == "" else Color("cfc8b6"))
				draw_rect(Rect2(tag_r.position, Vector2(tag_r.size.x, 4)), pc)
				draw_string(Kit.font("text"), tag_r.position + Vector2(2, 3), PACKETS[packet_i % PACKETS.size()], HORIZONTAL_ALIGNMENT_LEFT, tag_r.size.x - 2, 5, Color(1, 1, 1, 0.8))
				var name_txt: String = TAGGED[flat][1] if (known or who == "") else "?"
				draw_string(Kit.font("display"), tag_r.position + Vector2(3, 15), name_txt, HORIZONTAL_ALIGNMENT_LEFT, tag_r.size.x - 4, 11, Color("1e1a14"))
				packet_i += 1
			else:
				draw_string(Kit.font("display"), cell.position + Vector2(6, 14), flat, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Kit.IVORY_DIM, 0.55))
			# lamp
			var st := _jack_state(who)
			var lamp_c := Vector2(cell.position.x + 14, cell.end.y - 14)
			var lamp_col := Color("2b2622")
			if who == "" and _flat_warm.get(flat, false):
				lamp_col = Color(LAMP_WARM, 0.55)
			match st["lamp"]:
				"warm":
					lamp_col = LAMP_WARM
				"on":
					lamp_col = Color("f4f1e6")
				"ring":
					var blink := Settings.reduced_motion or fmod(t, 1.0) < 0.55
					lamp_col = LAMP_AMBER if blink else Color("5a4020")
			draw_circle(lamp_c, 6.0, Color("0e0c0a"))
			draw_circle(lamp_c, 4.6, lamp_col)
			if st["lamp"] in ["warm", "on", "ring"]:
				draw_circle(lamp_c, 10.0, Color(lamp_col, 0.18))
			# jack
			var jc := Vector2(cell.position.x + cell.size.x * 0.62, cell.end.y - 14)
			draw_circle(jc, 8.5, BRASS if hot else BRASS_DK)
			draw_circle(jc, 6.0, Color("0b0908"))
			draw_arc(jc, 8.5, -2.4, -0.7, 8, Color(1, 1, 1, 0.25), 1.5)
			# message pips
			if st["msg"]:
				draw_circle(Vector2(cell.end.x - 7, cell.position.y + 26), 3.5, Color("7fd07f"))
			if st["reply"]:
				var pulse := 1.0 if Settings.reduced_motion else (0.6 + 0.4 * sin(t * 4.0))
				draw_circle(Vector2(cell.end.x - 7, cell.position.y + 36), 3.5, Color(Kit.RED, pulse))
			if st["reason"] != "" and known:
				draw_line(cell.position + Vector2(cell.size.x - 16, cell.size.y - 22), cell.position + Vector2(cell.size.x - 6, cell.size.y - 8), Color(Kit.RED, 0.8), 2.0)
			if hot:
				draw_rect(cell, Kit.RED if active_tags.has(id) else Color(Kit.IVORY, 0.5), false, 2.0)

func _draw_specials(area: Rect2) -> void:
	draw_rect(area, Color(0, 0, 0, 0.25))
	var cw := area.size.x / SPECIALS.size()
	for i in SPECIALS.size():
		var s: Array = SPECIALS[i]
		var cell := Rect2(area.position.x + i * cw, area.position.y, cw, area.size.y).grow(-3)
		var id := "jack:" + str(s[0])
		_rects[id] = cell
		var hot := hover == id or active_tags.has(id)
		draw_string(Kit.font("display"), cell.position + Vector2(6, 16), str(s[1]), HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 8, 14, Kit.IVORY)
		draw_string(Kit.font("text"), cell.position + Vector2(6, 30), str(s[2]), HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 8, 10, Kit.IVORY_DIM)
		var st := _jack_state(str(s[0]))
		var lamp_col := Color("2b2622")
		if s[0] == "hold" and Game.vars.get("hold_fixed", false):
			lamp_col = LAMP_AMBER
		elif s[0] == "home":
			lamp_col = Color("f4f1e6") if cord_to == "home" else Color("2b2622")
		match st["lamp"]:
			"warm":
				lamp_col = LAMP_WARM
			"on":
				lamp_col = Color("f4f1e6")
			"ring":
				lamp_col = LAMP_AMBER if (Settings.reduced_motion or fmod(t, 1.0) < 0.55) else Color("5a4020")
		var lamp_c := Vector2(cell.position.x + 14, cell.end.y - 14)
		draw_circle(lamp_c, 6.0, Color("0e0c0a"))
		draw_circle(lamp_c, 4.6, lamp_col)
		var jc := Vector2(cell.position.x + cell.size.x * 0.62, cell.end.y - 16)
		draw_circle(jc, 9.5, BRASS if hot else BRASS_DK)
		draw_circle(jc, 6.5, Color("0b0908"))
		if hot:
			draw_rect(cell, Kit.RED if active_tags.has(id) else Color(Kit.IVORY, 0.5), false, 2.0)

func _draw_keys(area: Rect2) -> void:
	# a sloped key shelf
	var shelf := PackedVector2Array([area.position + Vector2(-8, 0), Vector2(area.end.x + 8, area.position.y), area.end + Vector2(20, 0), Vector2(area.position.x - 20, area.end.y)])
	draw_colored_polygon(shelf, BAKELITE_HI)
	var kw := area.size.x / KEYS.size()
	for i in KEYS.size():
		var k: Array = KEYS[i]
		var id := "key:" + str(k[0])
		var cell := Rect2(area.position.x + i * kw, area.position.y + 4, kw, area.size.y - 8).grow(-6)
		_rects[id] = cell
		_lever(cell, str(k[1]), active_tags.has(id), hover == id)

func _lever(cell: Rect2, label: String, active: bool, hot: bool, size_px: int = 12) -> void:
	var plate := Rect2(cell.position.x, cell.end.y - 20, cell.size.x, 18)
	var base_r := Rect2(cell.get_center().x - 16, cell.position.y + 4, 32, 26)
	draw_rect(base_r, Color("171210"))
	draw_rect(base_r, Color(BRASS_DK, 0.8), false, 1.0)
	var pivot := Vector2(base_r.get_center().x, base_r.end.y - 6)
	var ang := -0.35 if not (active and hot) else 0.55
	var tip := pivot + Vector2(sin(ang), -cos(ang)) * 22.0
	draw_line(pivot, tip, Color("0c0a09"), 7.0)
	draw_line(pivot, tip, Color("3a302a"), 4.0)
	draw_circle(tip, 8.0, Color("0c0a09"))
	draw_circle(tip, 6.5, Kit.RED if active else Color("2a221e"))
	draw_circle(tip + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.25))
	draw_circle(pivot, 4.0, BRASS)
	draw_rect(plate, LAMP_AMBER if active else Color("d8cfb8"))
	draw_rect(plate, BRASS_DK, false, 1.0)
	var f := Kit.font("bold")
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(f, Vector2(plate.get_center().x - tw / 2, plate.end.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("1e1a14"))
	if hot:
		draw_rect(cell, Kit.RED if active else Color(Kit.IVORY, 0.4), false, 2.0)

func _jack_point(id: String) -> Vector2:
	var key := "jack:" + id
	if _rects.has(key):
		var r: Rect2 = _rects[key]
		return Vector2(r.position.x + r.size.x * 0.62, r.end.y - 14)
	return Vector2(-100, -100)

func _draw_cord() -> void:
	var home := _jack_point("home")
	var to := _jack_point(cord_to) if cord_to != "home" else home
	var from := _jack_point(_cord_from) if _cord_from != "home" else home
	var tip := from.lerp(to, ease(cord_anim, -2.0))
	if cord_to == "home" and cord_anim >= 1.0:
		_plug(home, true)
		return
	var sag := 90.0 + home.distance_to(tip) * 0.25
	var pts := PackedVector2Array()
	for i in 25:
		var k := i / 24.0
		var p := home.lerp(tip, k)
		p.y += sin(k * PI) * sag
		pts.append(p)
	draw_polyline(pts, Color("3a0f0b"), 7.0)
	draw_polyline(pts, CORD_RED, 5.0)
	draw_polyline(pts, Color(1, 1, 1, 0.12), 1.5)
	_plug(tip, false)

func _plug(p: Vector2, home: bool) -> void:
	draw_circle(p, 7.5, Color("d9b86a"))
	draw_circle(p, 4.0, Color("8a6a2a"))
	draw_rect(Rect2(p + Vector2(-4, 6), Vector2(8, 16)), Color("2a1d18"))
	if home and mode == "full":
		draw_string(Kit.font("italic"), p + Vector2(14, 5), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.IVORY_DIM)

func _desk_objects(r: Rect2) -> void:
	var objs := [["strip", "PRINTER"], ["spike", "SPIKE"], ["tape", "TAPE"], ["pins", "PINBOARD"], ["calls", "TICKETS"]]
	var w := r.size.x / objs.size()
	for i in objs.size():
		var o: Array = objs[i]
		var id := "obj:" + str(o[0])
		var cell := Rect2(r.position.x + i * w, r.position.y, w, r.size.y).grow(-4)
		_rects[id] = cell
		var selected: bool = sub == str(o[0])
		draw_rect(cell, Color("2a2420") if not selected else Color("3a3028"))
		draw_rect(cell, Kit.RED if selected else (Color(Kit.IVORY, 0.5) if hover == id else Color("0d0b0a")), false, 2.0)
		var c := cell.get_center() - Vector2(0, 14)
		match str(o[0]):
			"strip":
				draw_rect(Rect2(c + Vector2(-30, 6), Vector2(60, 26)), Color("8a8478"))
				draw_rect(Rect2(c + Vector2(-18, -30), Vector2(36, 38)), PAPER)
				for j in 4:
					draw_line(c + Vector2(-14, -24 + j * 8), c + Vector2(10 - j * 3, -24 + j * 8), Color(INK_BLACK, 0.6), 1.0)
				var unread := 0
				for id2 in Game.phone["contacts"]:
					unread += int(Game.phone["contacts"][id2]["unread"])
				if unread > 0:
					_badge(cell.position + Vector2(cell.size.x - 14, 12), str(unread), Color("3f8f3f"))
			"spike":
				draw_rect(Rect2(c + Vector2(-22, 26), Vector2(44, 6)), Color("555"))
				draw_line(c + Vector2(0, 26), c + Vector2(0, -34), Color("c8c8c0"), 2.0)
				var pend := 0
				for id3 in Game.phone["contacts"]:
					if Game.phone["contacts"][id3]["reply_label"] != "":
						pend += 1
				for j in mini(pend, 5):
					draw_rect(Rect2(c + Vector2(-14 + (j % 2) * 4, -10 + j * 7), Vector2(26, 9)), PAPER)
				if pend > 0:
					_badge(cell.position + Vector2(cell.size.x - 14, 12), str(pend), Kit.RED)
			"tape":
				draw_rect(Rect2(c + Vector2(-34, -22), Vector2(68, 50)), Color("3a3a3e"))
				draw_circle(c + Vector2(-16, -2), 11.0, Color("15151a"))
				draw_circle(c + Vector2(16, -2), 11.0, Color("15151a"))
				draw_circle(c + Vector2(-16, -2), 4.0, Color("888"))
				draw_circle(c + Vector2(16, -2), 4.0, Color("888"))
				var nv := 0
				for v in Game.phone["voicemails"]:
					if not v["heard"]:
						nv += 1
				var led := Rect2(c + Vector2(-10, 14), Vector2(20, 12))
				draw_rect(led, Color("200a08"))
				var on := nv > 0 and (Settings.reduced_motion or fmod(t, 1.2) < 0.8)
				draw_string(Kit.font("bold"), led.position + Vector2(5, 11), str(nv), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ff4a3a") if on else Color("5a1a14"))
			"pins":
				draw_rect(Rect2(c + Vector2(-34, -28), Vector2(68, 56)), Color("9a7048"))
				var np: int = Game.phone["gallery"].size()
				for j in mini(np, 6):
					var pr := Rect2(c + Vector2(-30 + (j % 3) * 21, -24 + (j / 3) * 26), Vector2(18, 22))
					draw_rect(pr, PAPER)
					draw_circle(pr.position + Vector2(9, 2), 2.0, Kit.RED)
			"calls":
				for j in 4:
					draw_rect(Rect2(c + Vector2(-24 + j * 3, -26 + j * 10), Vector2(44, 14)), Color("d8d0bc"))
				var missed := 0
				for e in Game.phone["log"]:
					if e["dir"] == "missed":
						missed += 1
		draw_string(Kit.font("display"), Vector2(cell.position.x + 6, cell.end.y - 8), str(o[1]), HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 10, 13, Kit.IVORY_DIM if not selected else Kit.IVORY)

func _badge(p: Vector2, txt: String, col: Color) -> void:
	draw_circle(p, 10.0, col)
	var f := Kit.font("bold")
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f, p + Vector2(-w / 2, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _status_text() -> String:
	if hover.begins_with("jack:"):
		var id := hover.substr(5)
		if Game.phone["contacts"].has(id):
			var c: Dictionary = Game.phone["contacts"][id]
			var d := _cdef(id)
			if not c["known"]:
				return "%s · a flat you don't know yet" % d.get("place", id)
			var s := "%s · %s" % [d.get("name", id), d.get("place", "")]
			if active_tags.has(hover):
				return s + " · plug in"
			if c["call_label"] != "" and c["avail"]:
				return s + " · lit: you can ring"
			if c["reason"] != "":
				return s + " · " + c["reason"]
			return s + " · not now"
		for s2 in SPECIALS:
			if s2[0] == id:
				return "%s · %s" % [s2[1], s2[2]]
		return "Flat %s" % id
	if hover.begins_with("key:"):
		return hover.substr(4).to_upper() + (" · throw it" if active_tags.has(hover) else " · nothing to do with it just now")
	if hover.begins_with("obj:"):
		return {"obj:strip": "The printer. Messages to 247 come out here.", "obj:spike": "The spike. Tickets waiting for an answer.",
			"obj:tape": "The answering machine.", "obj:pins": "Pictures that came through, pinned up.",
			"obj:calls": "Call tickets: who rang, who you rang, who nobody answered."}.get(hover, "")
	if call_who != "":
		return "Your cord is in %s." % _cdef(call_who).get("name", call_who)
	return "Your cord is home, in 247."

func _draw_strip() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_panel_bg(r)
	_caller_box(Rect2(14, 14, size.x - 28, 38))
	# two big jacks and the cord between them
	var who := ring_who if ring_who != "" else call_who
	var home := Vector2(64, 190)
	var other := Vector2(size.x - 70, 110)
	_rects.clear()
	var id := "jack:" + who
	_rects[id] = Rect2(other - Vector2(34, 34), Vector2(68, 68))
	var hot := hover == id or active_tags.has(id)
	draw_string(Kit.font("display"), home + Vector2(-44, -30), "247 · ARI", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Kit.IVORY)
	draw_circle(home, 16.0, BRASS)
	draw_circle(home, 11.0, Color("0b0908"))
	if who != "":
		var d := _cdef(who)
		draw_string(Kit.font("display"), other + Vector2(-150, 34), str(d.get("place", who)), HORIZONTAL_ALIGNMENT_LEFT, 170, 15, Kit.IVORY)
		draw_string(Kit.font("text"), other + Vector2(-150, 50), str(d.get("name", who)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 170, 11, Kit.IVORY_DIM)
		var lamp_col := Color("f4f1e6")
		if ring_who != "":
			lamp_col = LAMP_AMBER if (Settings.reduced_motion or fmod(t, 1.0) < 0.55) else Color("5a4020")
		draw_circle(other + Vector2(-44, 0), 8.0, Color("0e0c0a"))
		draw_circle(other + Vector2(-44, 0), 6.0, lamp_col)
		draw_circle(other + Vector2(-44, 0), 14.0, Color(lamp_col, 0.18))
		draw_circle(other, 16.0, BRASS if hot else BRASS_DK)
		draw_circle(other, 11.0, Color("0b0908"))
		if hot:
			draw_arc(other, 24.0, 0, TAU, 32, Kit.RED, 2.0)
	# the cord
	var tip := home
	if call_who != "":
		tip = other
	if tip != home:
		var pts := PackedVector2Array()
		for i in 25:
			var k := i / 24.0
			var p := home.lerp(tip, k)
			p.y += sin(k * PI) * 70.0
			pts.append(p)
		draw_polyline(pts, Color("3a0f0b"), 8.0)
		draw_polyline(pts, CORD_RED, 6.0)
		draw_polyline(pts, Color(1, 1, 1, 0.12), 1.5)
	_plug(tip, tip == home)
	if ring_who != "" and call_who == "":
		draw_string(Kit.font("italic"), Vector2(20, 238), "It's ringing. Plug in to answer.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 14, Kit.IVORY)
	# view status
	var v := "LINE ONLY: you can hear, not see"
	var vcol := Kit.IVORY_DIM
	if view_who != "none" and view_who != "" and view_who != "plan" and view_who != "ari":
		v = "SEEING THROUGH " + str(Stage.VIEW_NAMES.get(view_who, view_who.to_upper()))
		vcol = Grim.WHO.get(view_who, Kit.IVORY)
	if call_who != "":
		draw_string(Kit.font("bold"), Vector2(18, 262), v, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 12, vcol)
	# keys
	var keys_r := Rect2(12, 276, size.x - 24, 70)
	var kw := keys_r.size.x / 4.0
	for i in 4:
		var k: Array = KEYS[i]
		var kid := "key:" + str(k[0])
		var cell := Rect2(keys_r.position.x + i * kw, keys_r.position.y, kw, keys_r.size.y).grow(-4)
		_rects[kid] = cell
		_lever(cell, str(k[1]), active_tags.has(kid), hover == kid, 11)

func _draw_printer() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.05, 0.045, 0.05, 0.94))
	draw_rect(r, Color("0d0b0a"), false, 2.0)
	var strip := Rect2(24, 44, size.x - 48, 360)
	if Settings.clean_text:
		draw_rect(strip, Color.BLACK)
	else:
		draw_rect(strip, PAPER)
		var ptx := _tex("res://assets/ui/paper.png")
		if ptx:
			draw_texture_rect(ptx, strip, true, Color(1, 1, 1, 0.6))
		for i in int(strip.size.y / 14):
			draw_circle(Vector2(strip.position.x + 6, strip.position.y + 7 + i * 14), 2.4, Color(0.05, 0.045, 0.05, 1.0))
			draw_circle(Vector2(strip.end.x - 6, strip.position.y + 7 + i * 14), 2.4, Color(0.05, 0.045, 0.05, 1.0))
	draw_string(Kit.font("display"), Vector2(24, 30), "THE PRINTER · messages to 247", HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 15, Kit.IVORY_DIM)
	# printer body
	var body := Rect2(12, 404, size.x - 24, 54)
	draw_rect(body, Color("8a8478"))
	draw_rect(Rect2(body.position + Vector2(10, -4), Vector2(body.size.x - 20, 8)), Color("2a2420"))
	draw_rect(body, Color("4a463e"), false, 2.0)
	draw_string(Kit.font("bold"), body.position + Vector2(14, 34), "BOOKINGS · F.S.B.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2a2420"))
	draw_circle(body.end - Vector2(22, 27), 5.0, Color("7fd07f"))

# ------------------------------------------------------------------ input

func _hit(p: Vector2) -> String:
	for id in _rects:
		if (_rects[id] as Rect2).has_point(p):
			return id
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit(event.position)
		if h != hover:
			hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(event.position)
		if id != "":
			_activate(id)
		elif mode != "full":
			advance_requested.emit()
		accept_event()

func _activate(id: String) -> void:
	if active_tags.has(id):
		Audio.sfx("key_throw" if id.begins_with("key:") else "plug_in", -6.0)
		control_picked.emit(id)
		return
	if id.begins_with("obj:"):
		sub = id.substr(4)
		Audio.sfx("paper", -10.0)
		refresh()
		return
	if id.begins_with("jack:"):
		var who := id.substr(5)
		if Game.phone["contacts"].has(who):
			var c: Dictionary = Game.phone["contacts"][who]
			if mode == "full" and c["thread"].size() > 0:
				sel_contact = who
				sub = "strip"
			if c["call_label"] != "" and c["avail"] and mode == "full":
				if Game.can_interrupt():
					call_requested.emit(who)
				else:
					Audio.sfx("key_dead", -8.0)
			else:
				Audio.sfx("key_dead", -8.0)
			refresh()
			return
		Audio.sfx("key_dead", -8.0)
		return
	if id.begins_with("key:"):
		Audio.sfx("key_dead", -8.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or mode != "full":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ids: Array = []
		for cid in Game.contacts_order:
			if Game.phone["contacts"][cid]["known"]:
				ids.append("jack:" + cid)
		if ids.is_empty():
			return
		match event.physical_keycode:
			KEY_RIGHT, KEY_DOWN:
				focus_jack = (focus_jack + 1) % ids.size()
				hover = ids[focus_jack]
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_UP:
				focus_jack = (focus_jack - 1 + ids.size()) % ids.size()
				hover = ids[focus_jack]
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if hover != "":
					_activate(hover)
					get_viewport().set_input_as_handled()
