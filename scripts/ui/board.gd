class_name Board
extends Control
## The attendant's board: the Baths' old cord switchboard in the frame room.
## Ari doesn't carry a phone. Ari is on this. Tab brings it up over the
## room; Tab or Esc puts it away.
##
##   jack field  forty-two flats, floor by floor, lamps for who's awake;
##               the people Ari knows have tags cut from food packets
##   cord        Ari's own cord, home in 247
##   keys        LOOK, LISTEN, HOLD, CLEAR, RELEASE 9
##   printer     messages to 247 come out on a paper strip
##   spike       messages waiting for a reply
##   tape        the answering machine
##   pinboard    pictures, which arrive as coarse dot printouts
##   tickets     who rang and who didn't

signal call_requested(who: String)
signal reply_requested(who: String)
signal doc_requested(id: String)
signal advance_requested()
signal close_requested()
signal control_picked(tag: String)

const FLOORS := 6
const FLATS := ["A", "B", "C", "D", "E", "F", "G"]
const TAGGED := {
	"4B": ["jad", "JAD"], "3D": ["dima", "DIMA"], "3B": ["nell", "NELL+TOBI"], "2C": ["kaye", "MRS KAYE"],
	"5A": ["teodor", "TEODOR"], "1A": ["", "INEZ"], "1D": ["", "ADEYEMI"], "1B": ["", "J.PIKE"],
	"2A": ["", "ROSTAMI"], "6A": ["", "RUSU"], "6C": ["", "HOLLIS"],
}
const PACKET_COLS := [Color("3a6fb0"), Color("c43a2e"), Color("3d8a4f"), Color("d49a2a"), Color("7a4a9a"), Color("2a8a8a"), Color("b0503a"), Color("5a5a5a"), Color("9a7a2a"), Color("4a6a9a"), Color("8a3a5a")]
const SPECIALS := [
	["sal", "209", "DESK"], ["inez", "299", "TEST"], ["door", "200", "DOOR"], ["receiving", "201", "RECV"],
	["hold", "HOLD", "HOLD"], ["line1", "L1", "OUT"], ["home", "247", "ARI"],
]
const KEYS := [["look", "LOOK"], ["listen", "LISTEN"], ["hold", "HOLD"], ["clear", "CLEAR"], ["release", "REL 9"]]
const VERB_KEY := {"look": "key:look", "listen": "key:listen", "hold": "key:hold", "end": "key:clear"}
const TABS := [["strip", "PRINTER"], ["spike", "SPIKE"], ["tape", "TAPE"], ["pins", "PINS"], ["calls", "TICKETS"]]

const FIELD := Rect2(24, 50, 336, 168)
const SPEC := Rect2(24, 226, 336, 30)
const KEYROW := Rect2(24, 262, 336, 36)
const DESK := Rect2(378, 24, 254, 328)
const READ := Rect2(384, 70, 242, 250)

var mode := "full"
var sub := "strip"
var sel_contact := ""
var sel_vm := ""
var script_thread := ""
var call_who := ""
var ring_who := ""
var view_who := "none"
var active_tags: Dictionary = {}
var t := 0.0
var hover := ""
var focus_jack := 0
var cord_to := "home"
var cord_anim := 1.0
var _cord_from := "home"
var _rects: Dictionary = {}
var _flat_warm: Dictionary = {}
var _rows: Array = []  # reading panel content
var _scroll := 0.0
var _content_h := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	position = Vector2.ZERO
	size = Vector2(640, 360)
	Game.phone_changed.connect(refresh)
	Settings.changed.connect(refresh)
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for f in range(1, FLOORS + 1):
		for l in FLATS:
			_flat_warm["%d%s" % [f, l]] = r.randf() < 0.18

func set_mode(m: String) -> void:
	mode = m
	refresh()

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
	if thread != "":
		sel_contact = thread
		sub = "strip"
		Game.mark_thread_read(thread)
	refresh()

func set_active_tags(options: Array) -> void:
	active_tags.clear()
	for i in options.size():
		var tags: Array = options[i].get("tags", [])
		var in_room := tags.any(func(x): return str(x).begins_with("spot:"))
		for tg in tags:
			if in_room and VERB_KEY.has(tg):
				continue
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

func _cdef(who: String) -> Dictionary:
	return Game.contacts_def.get(who, {"name": who.capitalize(), "place": ""})

# ------------------------------------------------------------------ the reading panel

## Rebuilds what's on the desk's reading surface as a list of rows:
## [kind, text, colour, action, texture]
func refresh() -> void:
	_rows.clear()
	match sub:
		"strip":
			_fill_strip(sel_contact)
		"tape":
			_fill_tape()
		"pins":
			_fill_pins()
		"spike":
			_fill_spike()
		"calls":
			_fill_calls()
	_measure()
	queue_redraw()

func _row(kind: String, text: String, col: Color = Grim.PHOS_MID, action: String = "", tex: Texture2D = null) -> void:
	_rows.append([kind, text, col, action, tex])

func _fill_strip(who: String) -> void:
	if who == "" or not Game.phone["contacts"].has(who):
		who = ""
		for id in Game.contacts_order:
			if Game.phone["contacts"][id]["thread"].size() > 0:
				who = id
				break
		if who == "":
			_row("note", "Nothing has come through the printer yet.", Grim.PHOS_DIM)
			return
	sel_contact = who
	var c: Dictionary = Game.phone["contacts"][who]
	var d := _cdef(who)
	# every thread, as tabs along the top
	var names := ""
	for id in Game.contacts_order:
		if Game.phone["contacts"][id]["thread"].size() > 0:
			_row("thread", str(_cdef(id).get("name", id)).to_upper(), Grim.AMBER if id == who else Grim.AMBER_DIM, "thread:" + id)
	_row("head", "%s  %s" % [str(d.get("name", who)).to_upper(), str(d.get("place", ""))], Grim.PHOS)
	for m in c["thread"]:
		var from: String = m["from"]
		var stamp: String = m.get("clock", "")
		stamp += "  247 > " + str(d.get("place", who)) if from == "ari" else ("  " + str(d.get("place", who)) + " > 247" if from == "them" else "")
		_row("stamp", stamp, Grim.PHOS_DIM)
		if m.get("doc", "") != "":
			var doc_id: String = m["doc"]
			_row("pic", Game.docs_def.get(doc_id, {}).get("title", doc_id), Grim.PHOS_MID, "doc:" + doc_id, _doc_tex(doc_id, true))
		if m["text"] != "":
			var col := Grim.IVORY if from == "ari" else Grim.PHOS
			if from == "sys":
				col = Grim.PHOS_DIM
			_row("text", m["text"], col)
	if c["reply_label"] != "":
		_row("button", "ANSWER: " + str(c["reply_prompt"]).to_upper(), Grim.RED, "reply:" + who if Game.can_interrupt() else "")
		if not Game.can_interrupt():
			_row("note", "You can answer once this moment lets you.", Grim.PHOS_DIM)
	Game.mark_thread_read(who)
	names = names
	_scroll = 1e9

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

func _fill_tape() -> void:
	var vms: Array = Game.phone["voicemails"].duplicate()
	vms.sort_custom(func(a, b): return str(Game.voicemail_def.get(a["id"], {}).get("sort", "")) < str(Game.voicemail_def.get(b["id"], {}).get("sort", "")))
	_row("head", "ANSWERING MACHINE", Grim.PHOS)
	if vms.is_empty():
		_row("note", "Nothing on the tape.", Grim.PHOS_DIM)
	var n := 1
	for v in vms:
		var d: Dictionary = Game.voicemail_def.get(v["id"], {})
		var id: String = v["id"]
		var mark := "* " if not v["heard"] else "  "
		_row("item", "%s%02d %s %s" % [mark, n, d.get("when", ""), str(d.get("from_name", "")).to_upper()], Grim.RED if not v["heard"] else Grim.PHOS_MID, "vm:" + id)
		if sel_vm == id:
			_row("stamp", "%s  %s" % [d.get("from_name", ""), d.get("length", "")], Grim.PHOS_DIM)
			_row("text", d.get("text", ""), Grim.PHOS)
			if d.has("audio"):
				_row("button", "PLAY IT AGAIN", Grim.AMBER, "play:" + id)
		n += 1
	if not Game.phone.get("archive_open", false):
		_row("note", "Reel two, older messages: not threaded. Someone who knows the machine could put it on.", Grim.PHOS_DIM)

func _fill_pins() -> void:
	_row("head", "PINNED UP", Grim.PHOS)
	if Game.phone["gallery"].is_empty():
		_row("note", "Nothing pinned up yet.", Grim.PHOS_DIM)
		return
	for item in Game.phone["gallery"]:
		var id: String = item["id"]
		_row("pic", Game.docs_def.get(id, {}).get("title", id), Grim.PHOS_MID, "doc:" + id, _doc_tex(id, item.get("from", "") != ""))

func _fill_spike() -> void:
	_row("head", "ON THE SPIKE", Grim.PHOS)
	var any := false
	for id in Game.contacts_order:
		var c: Dictionary = Game.phone["contacts"][id]
		if c["reply_label"] == "":
			continue
		any = true
		_row("button", "%s: %s" % [str(_cdef(id).get("name", id)).to_upper(), str(c["reply_prompt"]).to_upper()], Grim.RED, "reply:" + id if Game.can_interrupt() else "")
	if not any:
		_row("note", "Nothing on the spike.", Grim.PHOS_DIM)
	elif not Game.can_interrupt():
		_row("note", "You can answer once this moment lets you.", Grim.PHOS_DIM)

func _fill_calls() -> void:
	_row("head", "CALL TICKETS", Grim.PHOS)
	var log: Array = Game.phone["log"]
	for i in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[i]
		var dir: String = {"in": "CAME IN", "out": "WENT OUT", "missed": "UNANSWERED"}.get(e["dir"], e["dir"])
		_row("item", "%s %s %s" % [e.get("when", ""), str(_cdef(e["who"]).get("name", e["who"])).to_upper(), dir], Grim.RED if e["dir"] == "missed" else Grim.PHOS_MID)

func _body_px() -> int:
	return 16 if not Grim.plain() else 11

func _row_h(r: Array) -> float:
	var w := READ.size.x - 14
	match r[0]:
		"thread":
			return 0.0  # laid out on one line at the top
		"head":
			return 16.0
		"stamp":
			return 10.0
		"pic":
			return 76.0
		"button", "item":
			return 12.0 * Grim.wrap_text(r[1], "body", _body_px(), w - 10).size() + 4.0
		_:
			return 12.0 * Grim.wrap_text(r[1], "body", _body_px(), w).size() + 3.0

func _measure() -> void:
	_content_h = 0.0
	for r in _rows:
		_content_h += _row_h(r)

# ------------------------------------------------------------------ drawing

func _process(delta: float) -> void:
	t += delta
	if cord_anim < 1.0:
		cord_anim = minf(1.0, cord_anim + delta * 2.5)
	if visible:
		queue_redraw()

func _draw() -> void:
	_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color("060605"))
	# the console: bakelite in a steel frame
	var console := Rect2(10, 20, 362, 332)
	Grim.plate(self, console, "steel", 1.0)
	var inner := Rect2(16, 42, 350, 262)
	draw_rect(inner, Color("1a1311"))
	var bt := Grim.surf("bakelite")
	if bt:
		draw_texture_rect_region(bt, inner, Rect2(Vector2.ZERO, inner.size))
	Grim.text(self, Vector2(18, 36), "F.S.B. ATTENDANT'S POSITION", "head", 16, Grim.IVORY)
	_caller_box(Rect2(236, 25, 128, 14))
	_draw_jack_field()
	_draw_specials()
	_draw_keys()
	_draw_cord()
	# status line
	var st := _status_text()
	if hover == "" and not active_tags.is_empty():
		st = "Something is waiting on you: the jack or key framed in red."
	var sr := Rect2(18, 308, 346, 38)
	Grim.crt(self, sr, t)
	Grim.para(self, sr.position + Vector2(4, 12), st, "body", _body_px(), Grim.PHOS, sr.size.x - 8, 12)
	Grim.text(self, Vector2(sr.position.x + 4, sr.end.y - 3), "CLICK A LIT JACK TO RING SOMEONE.  TAB OR ESC TO PUT IT AWAY.", "tiny", 8, Grim.PHOS_DIM)
	Grim.crt_glass(self, sr)
	_draw_desk()

func _caller_box(r: Rect2) -> void:
	Grim.inset(self, r, Color("2e3a20"))
	draw_rect(r.grow(-1), Color("7f9870"))
	var who := ring_who if ring_who != "" else call_who
	var s := "NO CALL  " + str(Game.pres.get("clock", ""))
	if who != "" and who != "home":
		s = ("RING " if ring_who != "" else "CONN ") + str(_cdef(who).get("place", "")).to_upper()
	Grim.text(self, r.position + Vector2(3, 11), s, "tiny", 8, Color("16200f"))

func _flat_owner(flat: String) -> String:
	return TAGGED.get(flat, ["", ""])[0]

func _jack_state(who: String) -> Dictionary:
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

func _lamp_col(state: String, fallback: Color) -> Color:
	match state:
		"warm":
			return Color("e8d6a8")
		"on":
			return Color("f4f1e6")
		"ring":
			return Grim.AMBER if (Settings.reduced_motion or fmod(t, 1.0) < 0.55) else Color("5a4020")
	return fallback

func _draw_jack_field() -> void:
	var cw := FIELD.size.x / 7.0
	var ch := FIELD.size.y / 6.0
	var packet_i := 0
	for floor_i in FLOORS:
		var fl := FLOORS - floor_i
		Grim.text(self, Vector2(FIELD.position.x - 7, FIELD.position.y + floor_i * ch + ch * 0.6), str(fl), "tiny", 8, Grim.AMBER_DIM)
		for li in FLATS.size():
			var flat := "%d%s" % [fl, FLATS[li]]
			var cell := Rect2(FIELD.position.x + li * cw, FIELD.position.y + floor_i * ch, cw, ch).grow(-1)
			cell = Grim.snap(cell)
			var who := _flat_owner(flat)
			var known: bool = who != "" and Game.phone["contacts"].has(who) and Game.phone["contacts"][who]["known"]
			var id := "jack:" + (who if who != "" else flat)
			_rects[id] = cell
			var active := active_tags.has(id)
			var hot := hover == id
			if TAGGED.has(flat):
				var tag := Rect2(cell.position + Vector2(2, 1), Vector2(cell.size.x - 4, 10))
				var pc: Color = PACKET_COLS[packet_i % PACKET_COLS.size()]
				draw_rect(tag, Color("e3dccb") if (known or who == "") else Color("a8a292"))
				draw_rect(Rect2(tag.position, Vector2(tag.size.x, 2)), pc)
				var name_txt: String = TAGGED[flat][1] if (known or who == "") else "?"
				Grim.text(self, tag.position + Vector2(2, 9), name_txt, "tiny", 8, Color("1e1a14"))
				packet_i += 1
			else:
				Grim.text(self, cell.position + Vector2(3, 9), flat, "tiny", 8, Color(Grim.IVORY_DIM, 0.45))
			var st := _jack_state(who)
			var fallback := Color("2b2622")
			if who == "" and _flat_warm.get(flat, false):
				fallback = Color("6a5e44")
			Grim.lamp(self, Vector2(cell.position.x + 8, cell.end.y - 7), _lamp_col(st["lamp"], fallback), st["lamp"] != "off" or fallback != Color("2b2622"), 1)
			var jc := Vector2(cell.position.x + cell.size.x * 0.64, cell.end.y - 7).round()
			Grim._disc(self, jc, 4, Color("b08d4a") if (hot or active) else Color("6e5528"))
			Grim._disc(self, jc, 2, Color("0b0908"))
			if st["msg"]:
				draw_rect(Rect2(cell.end.x - 5, cell.position.y + 13, 3, 3), Color("7fd07f"))
			if st["reply"]:
				var on := Settings.reduced_motion or fmod(t, 0.8) < 0.5
				draw_rect(Rect2(cell.end.x - 5, cell.position.y + 18, 3, 3), Grim.RED if on else Grim.RED_DK)
			if active:
				draw_rect(cell, Grim.RED, false, 1.0)
			elif hot:
				draw_rect(cell, Color(Grim.IVORY, 0.6), false, 1.0)

func _draw_specials() -> void:
	var cw := SPEC.size.x / SPECIALS.size()
	for i in SPECIALS.size():
		var s: Array = SPECIALS[i]
		var cell := Grim.snap(Rect2(SPEC.position.x + i * cw, SPEC.position.y, cw, SPEC.size.y).grow(-1))
		var id := "jack:" + str(s[0])
		_rects[id] = cell
		var active := active_tags.has(id)
		var hot := hover == id
		draw_rect(cell, Color(0, 0, 0, 0.3))
		Grim.text(self, cell.position + Vector2(3, 9), str(s[1]), "tiny", 8, Grim.IVORY)
		Grim.text(self, cell.position + Vector2(3, 17), str(s[2]), "tiny", 8, Grim.IVORY_DIM)
		var st := _jack_state(str(s[0]))
		var fallback := Color("2b2622")
		if s[0] == "hold" and Game.vars.get("hold_fixed", false):
			fallback = Grim.AMBER
		elif s[0] == "home" and cord_to == "home":
			fallback = Color("f4f1e6")
		var lc := _lamp_col(st["lamp"], fallback)
		Grim.lamp(self, Vector2(cell.position.x + 6, cell.end.y - 5), lc, lc != Color("2b2622"), 1)
		var jc := Vector2(cell.position.x + cell.size.x * 0.66, cell.end.y - 8).round()
		Grim._disc(self, jc, 5, Color("b08d4a") if (hot or active) else Color("6e5528"))
		Grim._disc(self, jc, 3, Color("0b0908"))
		if active:
			draw_rect(cell, Grim.RED, false, 1.0)
		elif hot:
			draw_rect(cell, Color(Grim.IVORY, 0.6), false, 1.0)

func _draw_keys() -> void:
	var kw := KEYROW.size.x / KEYS.size()
	for i in KEYS.size():
		var k: Array = KEYS[i]
		var id := "key:" + str(k[0])
		var cell := Grim.snap(Rect2(KEYROW.position.x + i * kw, KEYROW.position.y, kw, KEYROW.size.y).grow(-2))
		_rects[id] = cell
		var active := active_tags.has(id)
		var hot := hover == id
		# a lever key: a bat that throws down when used
		var pivot := Vector2(cell.get_center().x, cell.position.y + 16).round()
		draw_rect(Rect2(pivot - Vector2(8, 10), Vector2(16, 14)), Color("141010"))
		var up := not (active and hot)
		var tip := pivot + (Vector2(0, -9) if up else Vector2(0, 6))
		draw_line(pivot, tip, Color("3a302a"), 3.0)
		Grim._disc(self, tip, 3, Grim.RED if active else Color("3a2e2a"))
		Grim._disc(self, pivot, 2, Color("b08d4a"))
		var plate := Rect2(cell.position.x + 2, cell.end.y - 11, cell.size.x - 4, 10)
		draw_rect(plate, Grim.AMBER if active else Color("cfc6ae"))
		Grim.text(self, plate.position + Vector2(0, 8), str(k[1]), "tiny", 8, Color("1e1a14"), plate.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if active:
			draw_rect(cell, Grim.RED, false, 1.0)
		elif hot:
			draw_rect(cell, Color(Grim.IVORY, 0.5), false, 1.0)

func _jack_point(id: String) -> Vector2:
	var key := "jack:" + id
	if _rects.has(key):
		var r: Rect2 = _rects[key]
		var inspec := r.position.y >= SPEC.position.y
		return Vector2(r.position.x + r.size.x * (0.66 if inspec else 0.64), r.end.y - (8 if inspec else 7)).round()
	return Vector2(-100, -100)

func _draw_cord() -> void:
	var home := _jack_point("home")
	var to := _jack_point(cord_to) if cord_to != "home" else home
	var from := _jack_point(_cord_from) if _cord_from != "home" else home
	var tip := from.lerp(to, ease(cord_anim, -2.0))
	if cord_to == "home" and cord_anim >= 1.0:
		_plug(home)
		return
	var sag := 30.0 + home.distance_to(tip) * 0.2
	var pts := PackedVector2Array()
	for i in 25:
		var k := i / 24.0
		var p := home.lerp(tip, k)
		p.y += sin(k * PI) * sag
		pts.append(p.round())
	draw_polyline(pts, Color("3a0f0b"), 3.0)
	draw_polyline(pts, Color("8e2a22"), 1.0)
	_plug(tip)

func _plug(p: Vector2) -> void:
	Grim._disc(self, p, 3, Color("d9b86a"))
	draw_rect(Rect2(p + Vector2(-2, 3), Vector2(4, 7)), Color("2a1d18"))

func _draw_desk() -> void:
	Grim.plate(self, DESK, "steel", 17.0)
	var tw := (DESK.size.x - 12) / TABS.size()
	for i in TABS.size():
		var tb: Array = TABS[i]
		var id := "obj:" + str(tb[0])
		var cell := Grim.snap(Rect2(DESK.position.x + 6 + i * tw, DESK.position.y + 6, tw - 2, 36))
		_rects[id] = cell
		var selected: bool = sub == str(tb[0])
		Grim.inset(self, cell, Color("211b17") if not selected else Color("3a2f27"))
		_tab_icon(str(tb[0]), cell)
		Grim.text(self, Vector2(cell.position.x, cell.end.y - 2), str(tb[1]), "tiny", 8, Grim.IVORY if selected or hover == id else Grim.IVORY_DIM, cell.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if selected:
			draw_rect(Rect2(cell.position.x, cell.end.y + 1, cell.size.x, 1), Grim.RED)
	Grim.crt(self, READ, t)
	_draw_rows()
	Grim.crt_glass(self, READ)
	Grim.text(self, Vector2(DESK.position.x + 8, DESK.end.y - 8), "WHEEL TO SCROLL", "tiny", 8, Grim.IVORY_DIM)

func _tab_icon(kind: String, cell: Rect2) -> void:
	var c := cell.get_center() - Vector2(0, 5)
	c = c.round()
	match kind:
		"strip":
			draw_rect(Rect2(c + Vector2(-9, 2), Vector2(18, 7)), Color("8a8478"))
			draw_rect(Rect2(c + Vector2(-5, -9), Vector2(10, 11)), Grim.PAPER)
			var unread := 0
			for id2 in Game.phone["contacts"]:
				unread += int(Game.phone["contacts"][id2]["unread"])
			if unread > 0:
				Grim.lamp(self, cell.position + Vector2(cell.size.x - 5, 5), Color("7fd07f"), true, 1)
		"spike":
			draw_rect(Rect2(c + Vector2(-7, 8), Vector2(14, 2)), Color("777"))
			draw_rect(Rect2(c + Vector2(0, -9), Vector2(1, 17)), Color("c8c8c0"))
			var pend := 0
			for id3 in Game.phone["contacts"]:
				if Game.phone["contacts"][id3]["reply_label"] != "":
					pend += 1
			for j in mini(pend, 4):
				draw_rect(Rect2(c + Vector2(-5, -4 + j * 3), Vector2(10, 2)), Grim.PAPER)
			if pend > 0:
				Grim.lamp(self, cell.position + Vector2(cell.size.x - 5, 5), Grim.RED, true, 1)
		"tape":
			draw_rect(Rect2(c + Vector2(-10, -7), Vector2(20, 14)), Color("3a3a3e"))
			Grim._disc(self, c + Vector2(-5, -1), 3, Color("15151a"))
			Grim._disc(self, c + Vector2(5, -1), 3, Color("15151a"))
			var nv := 0
			for v in Game.phone["voicemails"]:
				if not v["heard"]:
					nv += 1
			if nv > 0:
				Grim.lamp(self, cell.position + Vector2(cell.size.x - 5, 5), Color("ff4a3a"), Settings.reduced_motion or fmod(t, 1.2) < 0.8, 1)
		"pins":
			draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 16)), Color("8a6a48"))
			var np: int = Game.phone["gallery"].size()
			for j in mini(np, 4):
				draw_rect(Rect2(c + Vector2(-8 + (j % 2) * 9, -6 + (j / 2) * 7), Vector2(7, 6)), Grim.PAPER)
		"calls":
			for j in 3:
				draw_rect(Rect2(c + Vector2(-8 + j, -7 + j * 5), Vector2(14, 4)), Color("d8d0bc"))

func _draw_rows() -> void:
	var x := READ.position.x + 7
	var w := READ.size.x - 14
	var sz := _body_px()
	# thread tabs on one line
	var tx := x
	var top := READ.position.y + 4
	var has_tabs := false
	for r in _rows:
		if r[0] == "thread":
			has_tabs = true
			var tw := Grim.text_w(r[1], "tiny", 8) + 6
			var tr := Rect2(tx, top, tw, 10)
			draw_rect(tr, Color(r[2], 0.25))
			Grim.text(self, tr.position + Vector2(3, 8), r[1], "tiny", 8, r[2])
			_rects[r[3]] = tr
			tx += tw + 3
	var area_top := top + (14.0 if has_tabs else 0.0)
	var view_h := READ.end.y - area_top - 4
	var max_scroll := maxf(0.0, _content_h - view_h)
	_scroll = clampf(_scroll, 0.0, max_scroll)
	var y := area_top - _scroll
	for r in _rows:
		if r[0] == "thread":
			continue
		var h := _row_h(r)
		if y + h < area_top or y > READ.end.y - 4:
			y += h
			continue
		match r[0]:
			"head":
				Grim.glow_text(self, Vector2(x, y + 11), r[1], "head", 16, r[2])
				draw_rect(Rect2(x, y + 14, w, 1), Grim.PHOS_DIM)
			"stamp":
				Grim.text(self, Vector2(x, y + 8), r[1], "tiny", 8, r[2])
			"pic":
				var pr := Rect2(x, y + 2, 96, 64)
				if r[4]:
					draw_texture_rect(r[4], pr, false, Color(0.8, 1.0, 0.8))
				else:
					draw_rect(pr, Grim.PHOS_DK)
				Grim.para(self, Vector2(x + 102, y + 12), r[1], "body", sz, r[2], w - 104, 12)
				Grim.text(self, Vector2(x + 102, y + 62), "CLICK TO LOOK", "tiny", 8, Grim.PHOS_DIM)
				_rects[r[3]] = Rect2(x, y, w, h).intersection(READ)
				if hover == r[3]:
					draw_rect(pr, Grim.PHOS, false, 1.0)
			"button", "item":
				var br := Rect2(x - 2, y, w + 4, h - 2)
				var live: bool = r[3] != ""
				if live:
					_rects[r[3]] = br.intersection(READ)
				if hover == r[3] and live:
					draw_rect(br, Color(Grim.PHOS_DIM, 0.4))
				var ls := Grim.wrap_text(r[1], "body", sz, w - 10)
				if r[0] == "button":
					Grim.red_button(self, Vector2(x + 3, y + 6), hover == r[3], false, 2, r[2] if live else Color("4a3a36"))
				for k in ls.size():
					Grim.text(self, Vector2(x + (9 if r[0] == "button" else 0), y + 10 + k * 12), ls[k], "body", sz, r[2] if live or r[0] == "item" else Color(r[2], 0.4))
			_:
				var ls2 := Grim.wrap_text(r[1], "body", sz, w)
				for k in ls2.size():
					Grim.text(self, Vector2(x, y + 10 + k * 12), ls2[k], "body", sz, r[2])
		y += h

func _status_text() -> String:
	if hover.begins_with("jack:"):
		var id := hover.substr(5)
		if Game.phone["contacts"].has(id):
			var c: Dictionary = Game.phone["contacts"][id]
			var d := _cdef(id)
			if not c["known"]:
				return "%s: a flat you don't know yet." % d.get("place", id)
			var s := "%s, %s." % [d.get("name", id), d.get("place", "")]
			if active_tags.has(hover):
				return s + " Plug in."
			if c["call_label"] != "" and c["avail"]:
				return s + " Lit: you can ring."
			if c["reason"] != "":
				return s + " " + c["reason"]
			return s + " Not now."
		for s2 in SPECIALS:
			if s2[0] == id:
				return "%s: %s." % [s2[1], s2[2]]
		return "Flat %s." % id
	if hover.begins_with("key:"):
		return hover.substr(4).to_upper() + (": throw it." if active_tags.has(hover) else ": nothing to do with it just now.")
	if hover.begins_with("obj:"):
		return {"obj:strip": "The printer. Messages to 247 come out here.", "obj:spike": "The spike. Messages waiting for an answer.",
			"obj:tape": "The answering machine.", "obj:pins": "Pictures that came through, pinned up.",
			"obj:calls": "Call tickets: who rang, who you rang, who nobody answered."}.get(hover, "")
	if call_who != "":
		return "Your cord is in %s." % _cdef(call_who).get("name", call_who)
	return "Your cord is home, in 247."

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
		if h != "":
			ScreenFx.want("dial" if h.begins_with("jack:") else "use")
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll += 24
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll -= 24
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var id := _hit(event.position)
			if id != "":
				_activate(id)
		accept_event()

func _activate(id: String) -> void:
	if active_tags.has(id):
		Audio.sfx("key_throw" if id.begins_with("key:") else "plug_in", -6.0)
		control_picked.emit(id)
		return
	if id.begins_with("obj:"):
		sub = id.substr(4)
		_scroll = 0.0
		Audio.sfx("paper", -10.0)
		refresh()
		return
	if id.begins_with("thread:"):
		sel_contact = id.substr(7)
		refresh()
		return
	if id.begins_with("doc:"):
		doc_requested.emit(id.substr(4))
		return
	if id.begins_with("reply:"):
		reply_requested.emit(id.substr(6))
		return
	if id.begins_with("vm:"):
		var vid := id.substr(3)
		sel_vm = vid
		Game.mark_vm_heard(vid)
		Audio.sfx("tape_play", -6.0)
		refresh()
		return
	if id.begins_with("play:"):
		var d: Dictionary = Game.voicemail_def.get(id.substr(5), {})
		if d.has("audio"):
			Audio.sfx(d["audio"])
		return
	if id.begins_with("jack:"):
		var who := id.substr(5)
		if Game.phone["contacts"].has(who):
			var c: Dictionary = Game.phone["contacts"][who]
			if c["thread"].size() > 0:
				sel_contact = who
				sub = "strip"
			if c["call_label"] != "" and c["avail"] and Game.can_interrupt():
				call_requested.emit(who)
			else:
				Audio.sfx("key_dead", -8.0)
			refresh()
			return
		Audio.sfx("key_dead", -8.0)
		return
	if id.begins_with("key:"):
		Audio.sfx("key_dead", -8.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ids: Array = []
		for cid in Game.contacts_order:
			if Game.phone["contacts"][cid]["known"]:
				ids.append("jack:" + cid)
		for tg in active_tags:
			if not ids.has(tg):
				ids.append(tg)
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
			KEY_ESCAPE:
				close_requested.emit()
				get_viewport().set_input_as_handled()
