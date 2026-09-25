class_name Phone
extends Control
## Ari's phone. Cheap plastic outside, readable inside.
##
## Modes: "browse" (the player looking around), "thread" (the script is
## texting), "call" (a call is open), "ring" (something is ringing).

signal call_requested(who: String)
signal reply_requested(who: String)
signal doc_requested(id: String)
signal advance_requested()
signal close_requested()

const W := 340.0
const H := 650.0
const SCREEN := Rect2(18, 70, 304, 498)

var mode := "browse"
var screen := "home"
var arg := ""
var script_thread := ""
var call_who := ""
var ring_who := ""
var view_who := "none"
var clock := "23:14"

var content: VBoxContainer
var scroll: ScrollContainer
var header: Label
var header_right: Label
var choices: ChoiceList
var footer_hint: Label
var _pulse := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scr := Control.new()
	scr.position = SCREEN.position
	scr.size = SCREEN.size
	scr.clip_contents = true
	add_child(scr)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	scr.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	header = Kit.label("", 15, Kit.IVORY, "bold")
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(header)
	header_right = Kit.label("", 14, Kit.IVORY_DIM)
	hb.add_child(header_right)
	var sep := ColorRect.new()
	sep.color = Color(Kit.IVORY_DIM, 0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	choices = ChoiceList.new()
	choices.surface = "phone"
	choices.visible = false
	vb.add_child(choices)
	footer_hint = Kit.label("", 13, Kit.IVORY_DIM, "italic")
	footer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(footer_hint)
	# hardware buttons
	var names := [["←", "back"], ["□", "home"], ["✕", "close"]]
	for i in names.size():
		var b := Button.new()
		b.text = names[i][0]
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Kit.font("bold"))
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color("d9d2c4"))
		b.position = Vector2(38 + i * 96, 588)
		b.size = Vector2(72, 40)
		b.tooltip_text = ["Back", "Home", "Put the phone away (P)"][i]
		var what: String = names[i][1]
		b.pressed.connect(func(): _hw(what))
		add_child(b)
	Game.phone_changed.connect(refresh)
	Settings.changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	if mode == "ring":
		_pulse += delta
		queue_redraw()

func _draw() -> void:
	var body := Rect2(0, 0, W, H)
	var plastic := Color("4d4852")
	var edge := Color("6c6672")
	draw_rect(body, Color(0, 0, 0, 0.45), true)
	_rounded(body.grow(-2), 28.0, plastic)
	_rounded(body.grow(-6), 24.0, Color("575160"))
	# scuffed metal trim
	draw_rect(Rect2(8, 40, W - 16, 3), Color("8d8a84"))
	draw_rect(Rect2(8, 575, W - 16, 3), Color("8d8a84"))
	# speaker grille
	for i in 7:
		draw_circle(Vector2(W / 2 - 30 + i * 10, 22), 2.2, Color("2a262e"))
	draw_string(Kit.font("display"), Vector2(26, 60), "Ferrier Court · ext 247", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c9c1b4"))
	# screen well
	var s := SCREEN.grow(6)
	draw_rect(s, Color("201d24"))
	var bg := Color("0e1714") if not Settings.clean_text else Color.BLACK
	draw_rect(SCREEN.grow(2), bg)
	if mode == "ring" and not Settings.reduced_motion:
		var a := 0.15 + 0.12 * sin(_pulse * 5.0)
		draw_rect(SCREEN.grow(2), Color(Kit.RED, a), false, 4.0)
	draw_rect(Rect2(0, 0, W, H), edge, false, 1.0)

func _rounded(r: Rect2, rad: float, col: Color) -> void:
	draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2, r.size.y), col)
	draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - rad * 2), col)
	for c in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.position.x + rad, r.end.y - rad), r.end - Vector2(rad, rad)]:
		draw_circle(c, rad, col)

func _hw(what: String) -> void:
	match what:
		"close":
			close_requested.emit()
		"home":
			if mode == "browse":
				go("home")
		"back":
			if mode == "browse":
				match screen:
					"thread", "contact":
						go("messages" if screen == "thread" else "contacts")
					"vm":
						go("voicemail")
					_:
						go("home")

func go(scr: String, a: String = "") -> void:
	screen = scr
	arg = a
	if scr == "thread" and a != "":
		Game.mark_thread_read(a)
	refresh()

func set_mode(m: String, who: String = "") -> void:
	mode = m
	match m:
		"thread":
			script_thread = who
		"call":
			call_who = who
		"ring":
			ring_who = who
	refresh()

func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()

func refresh() -> void:
	if content == null:
		return
	clock = Game.pres.get("clock", clock)
	header_right.text = clock
	_clear()
	footer_hint.text = ""
	match mode:
		"thread":
			_thread(script_thread, true)
		"call":
			_call_screen()
		"ring":
			_ring_screen()
		_:
			match screen:
				"home":
					_home()
				"contacts":
					_contacts()
				"contact":
					_contact(arg)
				"messages":
					_messages()
				"thread":
					_thread(arg, false)
				"calls":
					_calls()
				"voicemail":
					_voicemails()
				"vm":
					_vm(arg)
				"saved":
					_saved()
	queue_redraw()

func _cdef(who: String) -> Dictionary:
	return Game.contacts_def.get(who, {"name": who.capitalize(), "place": ""})

func _row(text: String, sub: String = "", badge: String = "", on_press: Callable = Callable(), dim: bool = false) -> Control:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 46 if sub != "" else 38)
	var sb := Kit.flat(Color(1, 1, 1, 0.04), Color(Kit.IVORY_DIM, 0.18), 1, 2, 8)
	var sbh := Kit.flat(Color(1, 1, 1, 0.1), Kit.IVORY, 1, 2, 8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", Kit.flat(Color(0, 0, 0, 0), Kit.RED, 2, 2, 8))
	b.add_theme_stylebox_override("pressed", sbh)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 4
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)
	var l := Kit.label(text, 16, Kit.IVORY_DIM if dim else Kit.IVORY, "bold")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	hb.add_child(l)
	if badge != "":
		var bl := Kit.label(" " + badge + " ", 13, Kit.IVORY, "bold")
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bp := PanelContainer.new()
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bp.add_theme_stylebox_override("panel", Kit.flat(Kit.RED, Color(0, 0, 0, 0), 0, 8, 0))
		bp.add_child(bl)
		hb.add_child(bp)
	if sub != "":
		var s := Kit.label(sub, 13, Kit.IVORY_DIM)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.clip_text = true
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vb.add_child(s)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	content.add_child(b)
	return b

func _text(t: String, size: int = 15, col: Color = Kit.IVORY, kind: String = "text") -> Label:
	var l := Kit.label(t, size, col, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	content.add_child(l)
	return l

# ------------------------------------------------------------------ screens

func _home() -> void:
	header.text = "ARI"
	var unread := 0
	var replies := 0
	for id in Game.phone["contacts"]:
		unread += int(Game.phone["contacts"][id]["unread"])
		if Game.phone["contacts"][id]["reply_label"] != "":
			replies += 1
	var vm_new := 0
	for v in Game.phone["voicemails"]:
		if not v["heard"]:
			vm_new += 1
	_row("Messages", "%d unread%s" % [unread, (", %d waiting for a reply" % replies) if replies > 0 else ""],
		str(unread + replies) if unread + replies > 0 else "", func(): go("messages"))
	_row("Contacts", "Who you can reach", "", func(): go("contacts"))
	_row("Calls", "Recent", "", func(): go("calls"))
	_row("Voicemail", "%d new" % vm_new, str(vm_new) if vm_new > 0 else "", func(): go("voicemail"))
	_row("Saved", "%d pictures and papers" % Game.phone["gallery"].size(), "", func(): go("saved"))
	footer_hint.text = "P or Tab puts the phone away"

func _contacts() -> void:
	header.text = "CONTACTS"
	for id in Game.contacts_order:
		var c: Dictionary = Game.phone["contacts"][id]
		if not c["known"]:
			continue
		var d := _cdef(id)
		var status := ""
		if c["call_label"] != "" and c["avail"]:
			status = "● Can call"
		elif c["reason"] != "":
			status = "○ " + c["reason"]
		else:
			status = "○ Not now"
		var who: String = id
		_row(d.get("name", id), "%s · %s" % [d.get("place", ""), status], "", func(): go("contact", who), not (c["call_label"] != "" and c["avail"]))

func _contact(who: String) -> void:
	var c: Dictionary = Game.phone["contacts"].get(who, {})
	var d := _cdef(who)
	header.text = d.get("name", who).to_upper()
	_text(d.get("place", ""), 14, Kit.IVORY_DIM)
	if d.has("ext"):
		_text("Extension %s" % d["ext"], 14, Kit.IVORY_DIM)
	if c.get("saved_as", "") != "":
		_text("Has your number saved as: “%s”" % c["saved_as"], 14, Kit.PINK.lightened(0.2), "italic")
	var can: bool = c.get("call_label", "") != "" and c.get("avail", false)
	if can:
		var b := Kit.button("Call %s" % d.get("name", who), 16)
		b.disabled = not Game.can_interrupt()
		b.pressed.connect(func(): call_requested.emit(who))
		content.add_child(b)
		if b.disabled:
			_text("You can call once this conversation lets you.", 13, Kit.IVORY_DIM, "italic")
	else:
		_text("Can't call: %s" % (c.get("reason", "") if c.get("reason", "") != "" else "not now"), 14, Kit.IVORY_DIM, "italic")
	var t := Kit.button("Messages", 16)
	t.pressed.connect(func(): go("thread", who))
	content.add_child(t)

func _messages() -> void:
	header.text = "MESSAGES"
	var any := false
	for id in Game.contacts_order:
		var c: Dictionary = Game.phone["contacts"][id]
		if c["thread"].is_empty() and c["reply_label"] == "":
			continue
		any = true
		var last := ""
		if c["thread"].size() > 0:
			var m: Dictionary = c["thread"][-1]
			last = ("You: " if m["from"] == "ari" else "") + (m["text"] if m["text"] != "" else "[picture]")
		var badge := ""
		if int(c["unread"]) > 0:
			badge = str(c["unread"])
		if c["reply_label"] != "":
			badge = (badge + " " if badge != "" else "") + "↩"
		var who: String = id
		_row(_cdef(id).get("name", id), last, badge, func(): go("thread", who))
	if not any:
		_text("Nothing yet.", 15, Kit.IVORY_DIM, "italic")

func _thread(who: String, scripted: bool) -> void:
	var d := _cdef(who)
	header.text = d.get("name", who).to_upper()
	var c: Dictionary = Game.phone["contacts"].get(who, {})
	if c.is_empty():
		return
	for m in c["thread"]:
		_bubble(m)
	if not scripted and c["reply_label"] != "":
		var b := Kit.button("↩  " + c["reply_prompt"], 16)
		b.add_theme_stylebox_override("normal", Kit.flat(Color(Kit.RED, 0.25), Kit.RED, 1, 2, 8))
		b.disabled = not Game.can_interrupt()
		b.pressed.connect(func(): reply_requested.emit(who))
		content.add_child(b)
		if b.disabled:
			_text("You can answer once this conversation lets you.", 13, Kit.IVORY_DIM, "italic")
	if scripted:
		footer_hint.text = ""
	call_deferred("_scroll_bottom")

func _scroll_bottom() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _bubble(m: Dictionary) -> void:
	var from: String = m["from"]
	var hb := HBoxContainer.new()
	content.add_child(hb)
	if from == "ari":
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(sp)
	var p := PanelContainer.new()
	var col := Color("1f3a30") if from == "them" else Color("3a2a33")
	if from == "sys":
		col = Color(0, 0, 0, 0)
	if Settings.clean_text:
		col = Color(0.12, 0.12, 0.12) if from != "sys" else Color(0, 0, 0, 0)
	p.add_theme_stylebox_override("panel", Kit.flat(col, Color(Kit.IVORY_DIM, 0.2) if from != "sys" else Color(0, 0, 0, 0), 1, 8, 8))
	var vb := VBoxContainer.new()
	p.add_child(vb)
	if m.get("doc", "") != "":
		var doc_id: String = m["doc"]
		var dd: Dictionary = Game.docs_def.get(doc_id, {})
		var tb := Button.new()
		tb.flat = true
		tb.focus_mode = Control.FOCUS_ALL
		var thumb := TextureRect.new()
		var path: String = dd.get("image", "")
		if path != "" and ResourceLoader.exists(path):
			thumb.texture = load(path)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(180, 130)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(thumb)
		tb.custom_minimum_size = Vector2(180, 130)
		tb.pressed.connect(func(): doc_requested.emit(doc_id))
		vb.add_child(tb)
		var cap := Kit.label("▣ " + dd.get("title", doc_id) + "  (open)", 13, Kit.IVORY_DIM, "italic")
		vb.add_child(cap)
	if m["text"] != "":
		var l := Kit.label(m["text"], 15 if from != "sys" else 13, Kit.IVORY if from != "sys" else Kit.IVORY_DIM, "text" if from != "sys" else "italic")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(min(220, 12 + m["text"].length() * 8), 0)
		vb.add_child(l)
	var t := Kit.label(m.get("clock", ""), 11, Color(Kit.IVORY_DIM, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if from != "sys":
		vb.add_child(t)
	hb.add_child(p)
	if from == "sys":
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _calls() -> void:
	header.text = "CALLS"
	var log: Array = Game.phone["log"]
	for i in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[i]
		var arrow := {"in": "↙ in", "out": "↗ out", "missed": "✕ missed"}.get(e["dir"], e["dir"])
		_row(_cdef(e["who"]).get("name", e["who"]), "%s · %s" % [arrow, e.get("when", "")], "", Callable(), e["dir"] == "missed")

func _voicemails() -> void:
	header.text = "VOICEMAIL"
	var vms: Array = Game.phone["voicemails"].duplicate()
	vms.sort_custom(func(a, b): return str(Game.voicemail_def.get(a["id"], {}).get("sort", "")) > str(Game.voicemail_def.get(b["id"], {}).get("sort", "")))
	if vms.is_empty():
		_text("No messages.", 15, Kit.IVORY_DIM, "italic")
	for v in vms:
		var d: Dictionary = Game.voicemail_def.get(v["id"], {})
		var id: String = v["id"]
		_row(d.get("from_name", "Unknown"), d.get("when", ""), "new" if not v["heard"] else "", func(): go("vm", id), v["heard"])
	if not Game.phone.get("archive_open", false):
		_text("Older messages are kept on the frame and can't be reached from here.", 13, Kit.IVORY_DIM, "italic")

func _vm(id: String) -> void:
	var d: Dictionary = Game.voicemail_def.get(id, {})
	header.text = "VOICEMAIL"
	_text(d.get("from_name", ""), 16, Kit.IVORY, "bold")
	_text(d.get("when", "") + (" · %s" % d["length"] if d.has("length") else ""), 13, Kit.IVORY_DIM)
	var t := _text(d.get("text", ""), 15, Kit.IVORY)
	t.custom_minimum_size = Vector2(270, 0)
	Game.mark_vm_heard(id)
	if d.has("audio"):
		var b := Kit.button("▶ Play", 14)
		b.pressed.connect(func(): Audio.sfx(d["audio"]))
		content.add_child(b)

func _saved() -> void:
	header.text = "SAVED"
	if Game.phone["gallery"].is_empty():
		_text("Nothing saved yet.", 15, Kit.IVORY_DIM, "italic")
	for g in Game.phone["gallery"]:
		var d: Dictionary = Game.docs_def.get(g["id"], {})
		var id: String = g["id"]
		var from := ""
		if g.get("from", "") != "":
			from = "from " + _cdef(g["from"]).get("name", g["from"]) + " · "
		_row(d.get("title", id), from + g.get("clock", ""), "", func(): doc_requested.emit(id))

func _call_screen() -> void:
	var d := _cdef(call_who)
	header.text = "ON A CALL"
	var name := Kit.label(d.get("name", call_who), 24, Kit.IVORY, "display")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name)
	var place := Kit.label(d.get("place", ""), 14, Kit.IVORY_DIM)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(place)
	var v := "LINE ONLY: you can hear, not see"
	var col := Kit.IVORY_DIM
	if view_who != "none" and view_who != "":
		v = "SEEING THROUGH " + str(Stage.VIEW_NAMES.get(view_who, view_who.to_upper()))
		col = Stage.VIEW_COLORS.get(view_who, Kit.IVORY)
	var vl := Kit.label(v, 13, col, "bold")
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(vl)

func _ring_screen() -> void:
	var d := _cdef(ring_who)
	header.text = "INCOMING CALL"
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	content.add_child(sp)
	var name := Kit.label(d.get("name", ring_who), 26, Kit.IVORY, "display")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name)
	var place := Kit.label(d.get("place", ""), 14, Kit.IVORY_DIM)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(place)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "thread" or mode == "call" or mode == "ring":
			advance_requested.emit()
		accept_event()
