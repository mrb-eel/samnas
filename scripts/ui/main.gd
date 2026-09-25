extends Control
## Main scene. Builds the screen, routes story output to the right surface,
## runs overlays for blocking commands, and owns the menus.

const BASE := Vector2(1280, 720)
const ROOM_STAGE := Rect2(24, 56, 800, 600)
const ROOM_FEED := Rect2(846, 56, 410, 644)
const CALL_FEED := Rect2(28, 444, 850, 258)
const XCH_FEED := Rect2(34, 486, 850, 216)
const BLACK_FEED := Rect2(250, 120, 620, 500)

var root: Control
var bg: ColorRect
var xlayer: Layers.ExchangeLayer
var stage: Stage
var collage: Layers.CollageLayer
var portraits: Layers.PortraitLayer
var feed: Feed
var phone: Phone
var hud: Control
var clock_label: Label
var chapter_label: Label
var phone_btn: Button
var phone_badge: Label
var toast_box: VBoxContainer
var caption_label: Label
var fade_rect: ColorRect
var overlay_root: Control
var menu_root: Control

var comp := "black"
var browsing := false
var choice_surface := "feed"
var overlay_open := false
var menu_open := false
var title_screen: Control
var _wait_timer: SceneTreeTimer
var _pending_lines := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = Color("0b0a0e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root = Control.new()
	root.size = BASE
	root.clip_contents = false
	add_child(root)
	get_viewport().size_changed.connect(_center)
	_center()

	xlayer = Layers.ExchangeLayer.new()
	xlayer.size = BASE
	root.add_child(xlayer)
	stage = Stage.new()
	root.add_child(stage)
	xlayer.stage = stage
	collage = Layers.CollageLayer.new()
	collage.size = BASE
	collage.visible = false
	root.add_child(collage)
	portraits = Layers.PortraitLayer.new()
	portraits.size = BASE
	root.add_child(portraits)
	feed = Feed.new()
	root.add_child(feed)
	phone = Phone.new()
	root.add_child(phone)
	phone.visible = false
	_build_hud()
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(430, 58)
	toast_box.size = Vector2(420, 10)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	caption_label = Kit.label("", 14, Color("79a88c"), "italic")
	caption_label.position = Vector2(28, 694)
	caption_label.size = Vector2(800, 22)
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(caption_label)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size = BASE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	overlay_root = Control.new()
	overlay_root.size = BASE
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay_root)
	menu_root = Control.new()
	menu_root.size = BASE
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_root)

	feed.clicked.connect(_advance)
	stage.clicked.connect(_advance)
	stage.spot_clicked.connect(_on_spot)
	feed.choices.chosen.connect(_on_chosen)
	phone.choices.chosen.connect(_on_chosen)
	phone.advance_requested.connect(_advance)
	phone.close_requested.connect(func(): _set_browsing(false))
	phone.call_requested.connect(_phone_call)
	phone.reply_requested.connect(_phone_reply)
	phone.doc_requested.connect(func(id): _open_doc(id, false))

	Game.story_line.connect(_on_line)
	Game.story_choices.connect(_on_choices)
	Game.pres_command.connect(_on_pres)
	Game.notify.connect(_on_notify)
	Game.story_finished.connect(_on_finished)
	Game.phone_changed.connect(_update_badge)
	Audio.caption.connect(_on_caption)
	Settings.changed.connect(func(): _layout(); feed.restyle())

	_apply_comp("black")
	_show_title()
	# screenshot / autoplay harness hooks
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--shots":
		var h = load("res://scripts/tools/shots.gd").new()
		add_child(h)
		h.run(self, args.slice(1))

func _center() -> void:
	var vs := get_viewport_rect().size
	var s := minf(vs.x / BASE.x, vs.y / BASE.y)
	root.scale = Vector2(s, s)
	root.position = (vs - BASE * s) / 2.0

# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = Control.new()
	hud.size = Vector2(BASE.x, 46)
	root.add_child(hud)
	var strip := ColorRect.new()
	strip.color = Color(0.03, 0.03, 0.04, 0.7)
	strip.size = Vector2(BASE.x, 46)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(strip)
	clock_label = Kit.label("", 24, Kit.IVORY, "display")
	clock_label.position = Vector2(26, 8)
	hud.add_child(clock_label)
	chapter_label = Kit.label("", 17, Kit.IVORY_DIM, "display")
	chapter_label.position = Vector2(108, 14)
	hud.add_child(chapter_label)
	var hb := HBoxContainer.new()
	hb.position = Vector2(700, 6)
	hb.size = Vector2(560, 34)
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 6)
	hud.add_child(hb)
	phone_btn = _hud_btn(hb, "Phone  P", func(): _toggle_phone())
	phone_badge = Kit.label("", 13, Kit.IVORY, "bold")
	phone_badge.position = Vector2(-6, -6)
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", Kit.flat(Kit.RED, Color(0, 0, 0, 0), 0, 8, 2))
	bp.add_child(phone_badge)
	bp.position = Vector2(-8, -4)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_btn.add_child(bp)
	_hud_btn(hb, "History  L", func(): _open_backlog())
	_hud_btn(hb, "Save", func(): _open_saveload(true))
	_hud_btn(hb, "Load", func(): _open_saveload(false))
	_hud_btn(hb, "Settings", func(): _open_settings())
	_hud_btn(hb, "Menu  Esc", func(): _open_pause())

func _hud_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Kit.button(text, 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _update_badge() -> void:
	var n := Game.unread_total()
	phone_badge.text = " %d " % n if n > 0 else ""
	phone_badge.get_parent().visible = n > 0
	var locked: bool = Game.pres.get("phone_locked", false)
	phone_btn.disabled = locked and not browsing
	phone_btn.tooltip_text = "Not now." if locked else "Open the phone (P or Tab)"
	if phone.visible:
		phone.refresh()

# ------------------------------------------------------------------ compositions

func _apply_comp(c: String) -> void:
	comp = c
	_layout()

func _layout() -> void:
	var call_active: bool = Game.phone.get("call", {}).get("active", false)
	xlayer.visible = comp == "exchange"
	stage.visible = comp in ["room", "building", "call", "exchange"]
	match comp:
		"room", "building":
			_place(stage, ROOM_STAGE)
			_place(feed, ROOM_FEED)
			feed.set_mode("column")
		"call":
			_place(stage, Rect2(Vector2.ZERO, BASE))
			var fr := CALL_FEED
			if Game.pres.get("portraits", {}).size() > 0:
				fr = Rect2(300, 444, 590, 258)
			_place(feed, fr)
			feed.set_mode("band")
		"exchange":
			_place(stage, Layers.ExchangeLayer.SLOTS["1"])
			_place(feed, XCH_FEED)
			feed.set_mode("band")
		_:
			_place(feed, BLACK_FEED)
			feed.set_mode("center")
	_update_phone()
	portraits.show_all(Game.pres.get("portraits", {}), stage.get_rect() if stage.visible else Rect2(Vector2.ZERO, BASE))
	stage.set_view(Game.pres.get("view", "none"), call_active)

func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size

func _update_phone() -> void:
	var call_active: bool = Game.phone.get("call", {}).get("active", false)
	var ring: String = Game.pres.get("ring", "")
	var scripted: bool = Game.pres.get("phone_open", false)
	var m := "browse"
	if ring != "":
		m = "ring"
		phone.ring_who = ring
	elif call_active:
		m = "call"
		phone.call_who = Game.phone["call"]["who"]
	elif scripted:
		m = "thread"
		phone.script_thread = Game.pres.get("phone_thread", "")
	phone.view_who = Game.pres.get("view", "none")
	phone.mode = m
	var docked := comp in ["call", "exchange"]
	phone.visible = docked or m != "browse" or browsing
	if comp in ["room", "building"]:
		phone.position = Vector2(470, 44)
	else:
		phone.position = Vector2(918, 50)
	phone.refresh()
	_update_badge()

func _set_browsing(v: bool) -> void:
	browsing = v
	if v:
		phone.go("home")
	_update_phone()

func _toggle_phone() -> void:
	if menu_open or overlay_open or title_screen:
		return
	if Game.pres.get("phone_locked", false) and not browsing:
		_toast("Phone", "Not now.")
		return
	_set_browsing(not browsing)

# ------------------------------------------------------------------ story output

func _on_line(entry: Dictionary) -> void:
	if entry["kind"] == "sms" and Game.pres.get("phone_open", false):
		phone.refresh()
		if entry["speaker"] != "ARI":
			Audio.sfx("sms_in", -6.0)
		feed.show_more(false)
	else:
		feed.add_line(entry)
	if entry["kind"] == "sound" and entry["text"].length() > 0:
		pass

func _on_choices(options: Array) -> void:
	var m := phone.mode
	var surface := "phone" if (phone.visible and m in ["thread", "call", "ring"]) else "feed"
	choice_surface = surface
	feed.finish_typing()
	feed.show_more(false)
	if surface == "phone":
		phone.choices.show_options(options)
		feed.choices.clear()
	else:
		feed.choices.show_options(options)
		phone.choices.clear()
	var active_spots: Array = []
	var labels := {}
	for o in options:
		for t in o["tags"]:
			if t.begins_with("spot:"):
				active_spots.append(t.substr(5))
				labels[t.substr(5)] = o["text"]
	stage.set_spots(Game.pres.get("spots", {}), active_spots)
	stage.set_spot_labels(labels)

func _on_chosen(i: int) -> void:
	stage.set_spots({}, [])
	feed.choices.clear()
	phone.choices.clear()
	Audio.sfx("click", -8.0)
	Game.runner.choose(i)

func _on_spot(spot: String) -> void:
	var list: ChoiceList = phone.choices if choice_surface == "phone" else feed.choices
	var idx := list.spot_index(spot)
	if idx >= 0:
		list.pick(idx)

func _advance() -> void:
	if overlay_open or menu_open or title_screen:
		return
	if feed.is_typing():
		feed.finish_typing()
		return
	if Game.runner.waiting == "line":
		Game.runner.advance()

func _unhandled_input(event: InputEvent) -> void:
	if title_screen:
		return
	if event.is_action_pressed("menu") and not menu_open and not overlay_open:
		if browsing:
			_set_browsing(false)
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("phone") and not menu_open:
		_toggle_phone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("log") and not menu_open and not overlay_open:
		_open_backlog()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quicksave") and not menu_open:
		if Game.save_to(6):
			_toast("Saved", "Quicksave written to slot 6.")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quickload") and not menu_open:
		if Game.read_save(6).size() > 0:
			_load_slot(6)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("advance"):
		var list_visible := feed.choices.visible or phone.choices.visible
		if not list_visible:
			_advance()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ presentation commands

func _on_pres(name: String, args: Array) -> void:
	match name:
		"__restore":
			_restore_all()
		"comp":
			_apply_comp(args[0])
		"set":
			stage.load_set(args[0], args[1] if args.size() > 1 else "")
		"cam":
			stage.set_cam(args[0])
		"view":
			_layout()
			var acoustic: String = Game.pres.get("acoustic", "")
			Audio.set_far(Game.phone["call"]["active"], args[0] != "none", acoustic)
			if args[0] != "none":
				Audio.sfx("view_open", -6.0)
		"state":
			stage.apply_state(args[0], args[1] if args.size() > 1 else "on")
		"portrait":
			_layout()
		"time":
			clock_label.text = args[0]
			phone.refresh()
		"clear":
			feed.clear()
		"call":
			Audio.stop_sfx("ring")
			Audio.sfx("pickup", -4.0)
			if comp != "exchange":
				_apply_comp("call")
			Audio.set_far(true, Game.pres.get("view", "none") != "none", Game.pres.get("acoustic", ""))
			_update_phone()
		"hangup":
			Audio.sfx("hangup", -4.0)
			Audio.set_far(false, false, "")
			_layout()
		"ring":
			if args[0] == "off":
				Audio.stop_sfx("ring")
			else:
				Audio.sfx("ring")
			_update_phone()
		"phone", "phone_lock":
			if name == "phone" and args[0] != "close":
				browsing = false
			_update_phone()
		"sfx":
			Audio.sfx(args[0], float(args[1]) if args.size() > 1 else 0.0)
		"amb":
			Audio.set_amb(args[0])
		"amb2":
			Audio.set_amb2(args[0])
		"music":
			Audio.set_music(args[0])
		"acoustic":
			Audio.set_far(Game.phone["call"]["active"], Game.pres.get("view", "none") != "none", args[0])
		"spot", "spots_clear":
			pass
		"collage":
			collage.visible = args[0] == "on"
			collage.set_items(Game.pres.get("collage_items", []))
		"collage_add":
			collage.set_items(Game.pres.get("collage_items", []))
		"xwin":
			xlayer.wins = Game.pres.get("xwins", {})
		"fade":
			var target := 1.0 if args[0] == "out" else 0.0
			if Settings.reduced_motion:
				fade_rect.color.a = target
			else:
				create_tween().tween_property(fade_rect, "color:a", target, 0.7)
		"chapter":
			Game.save_to(0)
			chapter_label.text = args[1] if args.size() > 1 else ""
			var card := Overlays.ChapterCard.new()
			card.num = int(args[0])
			card.title = args[1] if args.size() > 1 else ""
			Audio.sfx("chapter", -4.0)
			_overlay(card, func(): Game.runner.resume())
		"title_card":
			var card2 := Overlays.ChapterCard.new()
			card2.num = 0
			card2.title = args[0]
			_overlay(card2, func(): Game.runner.resume())
		"wait":
			var secs := float(args[0])
			if Settings.instant_text:
				secs = minf(secs, 0.4)
			_wait_timer = get_tree().create_timer(secs)
			var tm := _wait_timer
			tm.timeout.connect(func():
				if _wait_timer == tm and Game.runner.waiting == "cmd":
					Game.runner.resume())
		"pause":
			Game.runner.resume()
		"drift":
			var d := Overlays.DriftCard.new()
			d.from = args[0]
			d.to = args[1] if args.size() > 1 else args[0]
			clock_label.text = d.to
			_overlay(d, func(): Game.runner.resume())
		"rupture":
			fade_rect.color = Color(0.95, 0.93, 0.88, 1.0)
			Audio.sfx("rupture")
			var tw := create_tween()
			tw.tween_interval(0.2 if Settings.reduced_motion else 1.4)
			tw.tween_property(fade_rect, "color:a", 0.0, 0.2 if Settings.reduced_motion else 2.2)
			tw.tween_callback(func():
				fade_rect.color = Color(0, 0, 0, 0)
				Game.runner.resume())
		"show_doc":
			_open_doc(args[0], true)
		"input_name":
			var ni := Overlays.NameInput.new()
			ni.prompt = args[1] if args.size() > 1 else "Name"
			ni.default_value = str(Game.vars.get(args[0], "Ari"))
			var var_name: String = args[0]
			overlay_open = true
			overlay_root.add_child(ni)
			ni.done.connect(func(v):
				Game.vars[var_name] = v
				ni.queue_free()
				overlay_open = false
				Game.runner.resume())
		"casio":
			var cs := Overlays.Casio.new()
			overlay_open = true
			overlay_root.add_child(cs)
			cs.done.connect(func(res, n):
				Game.vars["casio_resolved"] = res
				Game.vars["casio_played"] = n
				cs.queue_free()
				overlay_open = false
				Game.runner.resume())
		"ending":
			Game.vars["ending_seen"] = args[0]
			var ec := Overlays.EndingCard.new()
			ec.title = args[1] if args.size() > 1 else ""
			Audio.set_music("off")
			_overlay(ec, func(): Game.runner.resume())
		_:
			push_warning("Unhandled presentation command @%s %s" % [name, args])

func _overlay(ctl: Control, on_done: Callable) -> void:
	overlay_open = true
	ctl.size = BASE
	overlay_root.add_child(ctl)
	ctl.done.connect(func():
		ctl.queue_free()
		overlay_open = false
		on_done.call())

func _open_doc(id: String, blocking: bool) -> void:
	var dv := Overlays.DocViewer.new()
	dv.doc_id = id
	Audio.sfx("paper", -6.0)
	if blocking:
		_overlay(dv, func(): Game.runner.resume())
	else:
		overlay_open = true
		dv.size = BASE
		overlay_root.add_child(dv)
		dv.done.connect(func():
			dv.queue_free()
			overlay_open = false)

func _restore_all() -> void:
	var p: Dictionary = Game.pres
	for c in overlay_root.get_children():
		c.queue_free()
	overlay_open = false
	browsing = false
	feed.clear()
	feed.choices.clear()
	phone.choices.clear()
	stage.load_set(p.get("set", ""), p.get("variant", ""))
	stage.set_cam(p.get("cam", "main"))
	var st: Dictionary = p.get("states", {})
	for k in st:
		stage.apply_state(k, st[k])
	clock_label.text = p.get("clock", "")
	chapter_label.text = p.get("chapter_title", "")
	xlayer.wins = p.get("xwins", {})
	collage.visible = p.get("collage", false)
	collage.set_items(p.get("collage_items", []))
	Audio.set_amb(p.get("amb", ""))
	Audio.set_amb2(p.get("amb2", ""))
	Audio.set_music(p.get("music", ""))
	Audio.set_far(Game.phone["call"]["active"], p.get("view", "none") != "none", p.get("acoustic", ""))
	fade_rect.color = Color(0, 0, 0, 0)
	_apply_comp(p.get("comp", "black"))
	var bl: Array = Game.backlog
	var start := maxi(0, bl.size() - 6)
	for i in range(start, bl.size()):
		var e: Dictionary = bl[i]
		if e.get("kind", "") == "sms" and p.get("phone_open", false):
			continue
		feed.add_line(e, true)

func _on_notify(kind: String, who: String, text: String) -> void:
	var name: String = Game.contacts_def.get(who, {}).get("name", who.capitalize())
	match kind:
		"text":
			if phone.visible and phone.mode == "thread" and phone.script_thread == who:
				return
			if browsing and phone.screen == "thread" and phone.arg == who:
				phone.refresh()
				Game.mark_thread_read(who)
				return
			Audio.sfx("sms_in", -4.0)
			_toast("Text from " + name, text if text != "" else "[a picture]")
		"reply":
			_toast(name + " is waiting", text + "  (open the phone)")
		"voicemail":
			Audio.sfx("sms_in", -6.0)
			_toast("Voicemail", "New message from " + name)

func _toast(title: String, body: String) -> void:
	var t := Overlays.Toast.new()
	t.setup(title, body)
	toast_box.add_child(t)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()

func _on_caption(text: String) -> void:
	caption_label.text = "≈ " + text
	var tw := create_tween()
	caption_label.modulate.a = 1.0
	tw.tween_interval(6.0)
	tw.tween_property(caption_label, "modulate:a", 0.0, 1.5)

func _phone_call(who: String) -> void:
	_set_browsing(false)
	if not Game.phone_call(who):
		_toast("Phone", "You can't call right now.")

func _phone_reply(who: String) -> void:
	_set_browsing(false)
	if not Game.phone_reply(who):
		_toast("Phone", "Not right now.")

func _on_finished(reason: String) -> void:
	Game.playing = false
	if reason == "error":
		_toast("Story error", "The night stopped unexpectedly. Check the output log.")
	await get_tree().create_timer(0.5).timeout
	_to_title()

# ------------------------------------------------------------------ menus

func _show_title() -> void:
	Audio.stop_all()
	Audio.set_amb("title_room")
	title_screen = Menus.Title.new()
	title_screen.size = BASE
	menu_root.add_child(title_screen)
	title_screen.action.connect(_on_title_action)
	hud.visible = false

func _on_title_action(what: String) -> void:
	match what:
		"new":
			_close_title()
			Game.new_game()
		"continue":
			var slot := Game.latest_slot()
			if slot >= 0:
				_close_title()
				_load_slot(slot)
		"load":
			_open_saveload(false)
		"settings":
			_open_settings()
		"quit":
			get_tree().quit()

func _close_title() -> void:
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	hud.visible = true
	Audio.stop_all()

func _to_title() -> void:
	for c in overlay_root.get_children():
		c.queue_free()
	overlay_open = false
	browsing = false
	feed.clear()
	feed.choices.clear()
	phone.choices.clear()
	stage.load_set("", "")
	collage.visible = false
	_apply_comp("black")
	_show_title()

func _open_pause() -> void:
	if menu_open or title_screen:
		return
	menu_open = true
	var p := Menus.Pause.new()
	p.size = BASE
	menu_root.add_child(p)
	p.action.connect(func(what):
		match what:
			"resume":
				p.queue_free()
				menu_open = false
			"save":
				p.queue_free()
				menu_open = false
				_open_saveload(true)
			"load":
				p.queue_free()
				menu_open = false
				_open_saveload(false)
			"log":
				p.queue_free()
				menu_open = false
				_open_backlog()
			"settings":
				p.queue_free()
				menu_open = false
				_open_settings()
			"title":
				p.queue_free()
				menu_open = false
				if Game.playing:
					Game.save_to(0)
				Game.playing = false
				_to_title()
			"quit":
				if Game.playing:
					Game.save_to(0)
				get_tree().quit())

func _open_saveload(saving: bool) -> void:
	if menu_open:
		return
	if saving and (title_screen or not Game.playing):
		return
	menu_open = true
	var s := Menus.SaveLoad.new()
	s.saving = saving
	s.size = BASE
	menu_root.add_child(s)
	s.closed.connect(func():
		s.queue_free()
		menu_open = false)
	s.picked.connect(func(slot):
		s.queue_free()
		menu_open = false
		if saving:
			if Game.save_to(slot):
				_toast("Saved", "Slot %d." % slot)
			else:
				_toast("Can't save", "Try again after this moment.")
		else:
			if title_screen:
				_close_title()
			_load_slot(slot))

func _load_slot(slot: int) -> void:
	Audio.stop_all()
	if not Game.load_from(slot):
		_toast("Can't load", "That save couldn't be read.")

func _open_settings() -> void:
	if menu_open:
		return
	menu_open = true
	var s := Menus.SettingsMenu.new()
	s.size = BASE
	menu_root.add_child(s)
	s.closed.connect(func():
		s.queue_free()
		menu_open = false)

func _open_backlog() -> void:
	if menu_open or title_screen:
		return
	menu_open = true
	var b := Menus.Backlog.new()
	b.size = BASE
	menu_root.add_child(b)
	b.closed.connect(func():
		b.queue_free()
		menu_open = false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Game.playing:
			Game.save_to(0)
