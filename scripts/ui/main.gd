extends Control
## Main scene. Builds the screen, routes story output to the console and
## the room, turns choices that live in the room into things to click, runs
## overlays for blocking commands, and owns the menus.
##
## The screen is 640x360. The room fills it. The console sits along the
## bottom when someone is talking; when the player is free to walk, it
## shrinks away and the room is the interface.

const BASE := Vector2(640, 360)

var root: Control
var bg: ColorRect
var xlayer: Layers.ExchangeLayer
var stage: Stage
var collage: Layers.CollageLayer
var console: Console
var hud: Hud
var board: Board
var fade_rect: ColorRect
var overlay_root: Control
var menu_root: Control
var post: ScreenFx.Post

var comp := "black"
var browsing := false
var overlay_open := false
var menu_open := false
var title_screen: Control
var options: Array = []  # the choices on offer, as the runner gave them
var _wait_timer: SceneTreeTimer
var _walkto_token := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = Color("050505")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root = Control.new()
	root.size = BASE
	add_child(root)

	xlayer = Layers.ExchangeLayer.new()
	xlayer.size = BASE
	root.add_child(xlayer)
	stage = Stage.new()
	stage.size = BASE
	root.add_child(stage)
	xlayer.stage = stage
	collage = Layers.CollageLayer.new()
	collage.size = BASE
	collage.visible = false
	root.add_child(collage)
	console = Console.new()
	console.size = BASE
	root.add_child(console)
	hud = Hud.new()
	hud.size = BASE
	root.add_child(hud)
	board = Board.new()
	root.add_child(board)
	board.visible = false
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

	console.advance_requested.connect(_advance)
	console.chosen.connect(_on_chosen)
	stage.clicked.connect(_advance)
	stage.spot_clicked.connect(_on_spot)
	stage.walk_picked.connect(_on_walk_pick)
	stage.actor_settled.connect(_remember_actor)
	hud.board_pressed.connect(_toggle_board)
	hud.log_pressed.connect(_open_backlog)
	hud.menu_pressed.connect(_open_pause)
	board.close_requested.connect(func(): _set_browsing(false))
	board.call_requested.connect(_board_call)
	board.reply_requested.connect(_board_reply)
	board.doc_requested.connect(func(id): _open_doc(id, false))
	board.control_picked.connect(_on_control)

	Game.story_line.connect(_on_line)
	Game.story_choices.connect(_on_choices)
	Game.pres_command.connect(_on_pres)
	Game.notify.connect(_on_notify)
	Game.story_finished.connect(_on_finished)
	Game.phone_changed.connect(_update_badge)
	Audio.caption.connect(func(s): hud.caption(s))
	Settings.changed.connect(func(): _layout(); console.restyle())

	# the grime over everything, and the pointer over that
	var post_layer := CanvasLayer.new()
	post_layer.layer = 100
	add_child(post_layer)
	post = ScreenFx.Post.new()
	post_layer.add_child(post)
	var ptr_layer := CanvasLayer.new()
	ptr_layer.layer = 120
	add_child(ptr_layer)
	ptr_layer.add_child(ScreenFx.Pointer.new())

	_apply_comp("black")
	_show_title()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--shots":
		var h = load("res://scripts/tools/shots.gd").new()
		add_child(h)
		h.run(self, args.slice(1))

# ------------------------------------------------------------------ compositions

func _apply_comp(c: String) -> void:
	comp = c
	_layout()

func _layout() -> void:
	var call_active: bool = Game.phone.get("call", {}).get("active", false)
	var xw: Dictionary = Game.pres.get("xwins", {})
	var xview: bool = xw.has("1") and xw["1"].size() > 0 and xw["1"][0] == "view"
	xlayer.visible = comp == "exchange"
	stage.visible = comp in ["room", "building", "call"] or (comp == "exchange" and xview)
	xlayer.stage_full = stage.visible
	if comp == "black":
		if console.mode != "center":
			console.set_mode("center")
	elif console.mode == "center" or console.mode == "hidden":
		console.set_mode("panel")
	stage.set_view(Game.pres.get("view", "none"), call_active)
	_update_badge()

func _update_badge() -> void:
	var locked: bool = Game.pres.get("phone_locked", false)
	hud.set_badge(Game.unread_total(), locked and not browsing)
	if board.visible:
		board.refresh()

func _set_browsing(v: bool) -> void:
	browsing = v
	if v:
		Audio.sfx("board_open", -6.0)
		board.set_mode("full")
		board.visible = true
		var ring: String = Game.pres.get("ring", "")
		var call_active: bool = Game.phone.get("call", {}).get("active", false)
		board.sync(ring, str(Game.phone["call"]["who"]) if call_active else "", Game.pres.get("view", "none"), Game.pres.get("phone_thread", ""))
		board.set_active_tags(options)
		board.refresh()
	else:
		board.visible = false
	_update_badge()

func _toggle_board() -> void:
	if menu_open or overlay_open or title_screen:
		return
	if Game.pres.get("phone_locked", false) and not browsing:
		hud.toast("The board", "Not now.")
		return
	_set_browsing(not browsing)

# ------------------------------------------------------------------ story output

func _on_line(entry: Dictionary) -> void:
	stage.clear_walk_spots()
	if console.mode == "walk":
		console.set_mode("panel" if comp != "black" else "center")
	console.clear_choices()
	console.add_line(entry)
	if browsing and entry.get("kind", "") == "sms":
		board.refresh()

## Choices that name a hotspot in a walkable room become things in the
## room. The rest stay on the console.
func _on_choices(opts: Array) -> void:
	options = opts
	console.finish_typing()
	var world := {}
	var rest: Array = []
	var screen_spots: Array = []
	var labels := {}
	var verbs := {}
	var in_room := stage.walking and stage.current != null
	for i in opts.size():
		var o: Dictionary = opts[i]
		var spot := ""
		for t in o["tags"]:
			if t.begins_with("spot:"):
				spot = t.substr(5)
		var verb := ScreenFx.verb_for_tags(o["tags"])
		var label := _label_of(o)
		if spot != "" and in_room and stage.current.hotspots.has(spot):
			world[spot] = {"index": i, "label": label, "verb": verb}
			continue
		if spot != "" and Game.pres.get("spots", {}).has(spot):
			screen_spots.append(spot)
			labels[spot] = label
			verbs[spot] = verb
		var oo := o.duplicate()
		oo["index"] = i
		rest.append(oo)
	if not world.is_empty():
		console.set_mode("walk")
		stage.set_walk_spots(world)
	else:
		stage.clear_walk_spots()
		if console.mode == "walk":
			console.set_mode("panel" if comp != "black" else "center")
	console.show_choices(rest)
	stage.set_spots(Game.pres.get("spots", {}), screen_spots)
	stage.set_spot_labels(labels, verbs)
	if browsing:
		board.set_active_tags(opts)

func _label_of(o: Dictionary) -> String:
	var s: String = o["text"]
	s = s.strip_edges()
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	if o.get("speech", false):
		s = "\"" + s + "\""
	return s

func _on_chosen(i: int) -> void:
	stage.set_spots({}, [])
	stage.clear_walk_spots()
	console.clear_choices()
	board.clear_active()
	options = []
	_remember_actor()
	Audio.sfx("click", -8.0)
	Game.runner.choose(i)

func _on_walk_pick(spot: String) -> void:
	for i in options.size():
		for t in options[i]["tags"]:
			if t == "spot:" + spot:
				_on_chosen(i)
				return

func _on_spot(spot: String) -> void:
	for i in options.size():
		for t in options[i]["tags"]:
			if t == "spot:" + spot:
				_on_chosen(i)
				return

func _on_control(tag: String) -> void:
	if Game.runner.waiting != "choice":
		return
	for i in options.size():
		if options[i]["tags"].has(tag):
			_set_browsing(false)
			_on_chosen(i)
			return

func _remember_actor() -> void:
	var st := stage.actor_state()
	if not st.is_empty():
		Game.pres["actor"] = st

func _advance() -> void:
	if overlay_open or menu_open or title_screen or browsing:
		return
	if console.consume_advance():
		return
	if Game.runner.waiting == "line":
		Game.runner.advance()

func _input(event: InputEvent) -> void:
	if title_screen or menu_open:
		return
	if event.is_action_pressed("board"):
		_toggle_board()
		get_viewport().set_input_as_handled()
	elif event.is_action("reveal"):
		stage.reveal = event.is_pressed()
		stage.marks.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if title_screen:
		return
	if event.is_action_pressed("menu") and not menu_open and not overlay_open:
		if browsing:
			_set_browsing(false)
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("log") and not menu_open and not overlay_open:
		_open_backlog()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quicksave") and not menu_open:
		Game.thumb = _snapshot()
		_remember_actor()
		if Game.save_to(6):
			hud.toast("Saved", "Quicksave, slot 6.")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quickload") and not menu_open:
		if Game.read_save(6).size() > 0:
			_load_slot(6)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spot_next") and stage.interactive:
		stage.cycle_spot(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spot_prev") and stage.interactive:
		stage.cycle_spot(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("advance"):
		if stage.interactive and stage.hover_spot != "":
			stage.pick_hovered()
		elif console.options.is_empty():
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
		"walk":
			if args.is_empty() or args[0] == "off":
				stage.walk_end()
				stage.set_cam(Game.pres.get("cam", "main"))
			else:
				if comp == "black":
					Game.pres["comp"] = "room"
					_apply_comp("room")
				stage.walk_begin(args[0], args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "phone")
				_remember_actor()
		"walkto":
			_walkto_token += 1
			var tok := _walkto_token
			stage.walk_to(args[0], args[1], func():
				if tok == _walkto_token and Game.runner.waiting == "cmd":
					_remember_actor()
					Game.runner.resume())
		"place":
			stage.place(args[0], args[1])
			_remember_actor()
		"view":
			_layout()
			var acoustic: String = Game.pres.get("acoustic", "")
			Audio.set_far(Game.phone["call"]["active"], args[0] != "none", acoustic)
			if args[0] != "none":
				Audio.sfx("view_open", -6.0)
				post.kick(0.5)
		"state":
			stage.apply_state(args[0], args[1] if args.size() > 1 else "on")
		"portrait":
			pass
		"time":
			hud.set_clock(args[0])
			board.refresh()
		"clear":
			console.clear()
		"call":
			Audio.stop_sfx("ring")
			Audio.sfx("pickup", -4.0)
			if comp != "exchange":
				_apply_comp("call")
			Audio.set_far(true, Game.pres.get("view", "none") != "none", Game.pres.get("acoustic", ""))
			_update_badge()
		"hangup":
			Audio.sfx("hangup", -4.0)
			Audio.set_far(false, false, "")
			_layout()
		"ring":
			if args[0] == "off":
				Audio.stop_sfx("ring")
			else:
				Audio.sfx("ring")
			_update_badge()
		"phone", "phone_lock":
			_update_badge()
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
		"hold":
			Audio.sfx("plug_in", -8.0)
			_update_badge()
		"collage":
			collage.visible = args[0] == "on"
			collage.set_items(Game.pres.get("collage_items", []))
		"collage_add":
			collage.set_items(Game.pres.get("collage_items", []))
		"xwin":
			xlayer.wins = Game.pres.get("xwins", {})
			_layout()
		"fade":
			var target := 1.0 if args[0] == "out" else 0.0
			if Settings.reduced_motion:
				fade_rect.color.a = target
			else:
				create_tween().tween_property(fade_rect, "color:a", target, 0.7)
		"chapter":
			hud.set_chapter(_chapter_tape(int(args[0]), args[1] if args.size() > 1 else ""))
			var card := Overlays.ChapterCard.new()
			card.num = int(args[0])
			card.title = args[1] if args.size() > 1 else ""
			Audio.sfx("chapter", -4.0)
			post.kick(1.0)
			_overlay(card, _after_chapter_card)
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
			hud.set_clock(d.to)
			post.kick(1.0)
			_overlay(d, func(): Game.runner.resume())
		"rupture":
			fade_rect.color = Color(0.95, 0.93, 0.88, 1.0)
			Audio.sfx("rupture")
			post.kick(1.0)
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
			ni.size = BASE
			overlay_root.add_child(ni)
			ni.done.connect(func(v):
				Game.vars[var_name] = v
				ni.queue_free()
				overlay_open = false
				Game.runner.resume())
		"casio":
			var cs := Overlays.Casio.new()
			overlay_open = true
			cs.size = BASE
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

## The autosave's picture is taken once the card has gone and the first
## frame of the chapter is on screen, not the card or the title.
func _after_chapter_card() -> void:
	Game.runner.resume()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.thumb = _snapshot()
	Game.save_to(0)

func _chapter_tape(n: int, title: String) -> String:
	var roman: String = ["", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]
	return (roman + ". " if roman != "" else "") + title

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
	_set_browsing(false)
	console.clear()
	console.clear_choices()
	board.clear_active()
	options = []
	stage.load_set(p.get("set", ""), p.get("variant", ""))
	var st: Dictionary = p.get("states", {})
	for k in st:
		stage.apply_state(k, st[k])
	stage.set_cam(p.get("cam", "main"))
	var w: Array = p.get("walk", [])
	if w.size() > 0:
		stage.walk_begin(w[0], w[1] if w.size() > 1 else "", w[2] if w.size() > 2 else "phone")
		stage.actor_restore(p.get("actor", {}))
	hud.set_clock(p.get("clock", ""))
	hud.set_chapter(_chapter_tape(int(p.get("chapter", 0)), p.get("chapter_title", "")))
	xlayer.wins = p.get("xwins", {})
	collage.visible = p.get("collage", false)
	collage.set_items(p.get("collage_items", []))
	Audio.set_amb(p.get("amb", ""))
	Audio.set_amb2(p.get("amb2", ""))
	Audio.set_music(p.get("music", ""))
	Audio.set_far(Game.phone["call"]["active"], p.get("view", "none") != "none", p.get("acoustic", ""))
	fade_rect.color = Color(0, 0, 0, 0)
	_apply_comp(p.get("comp", "black"))
	# the last few lines, so the screen isn't blank
	var bl: Array = Game.backlog
	var start := maxi(0, bl.size() - (6 if comp == "black" else 1))
	for i in range(start, bl.size()):
		console.add_line(bl[i], true)

func _on_notify(kind: String, who: String, text: String) -> void:
	var name: String = Game.contacts_def.get(who, {}).get("name", who.capitalize())
	match kind:
		"text":
			if browsing and board.sub == "strip" and board.sel_contact == who:
				board.refresh()
				Game.mark_thread_read(who)
				return
			if Game.pres.get("phone_open", false) and Game.pres.get("phone_thread", "") == who:
				return
			Audio.sfx("printer", -4.0)
			hud.toast("Printer: " + name, text if text != "" else "[a picture, in dots]")
		"reply":
			hud.toast("On the spike: " + name, text + "  (TAB)")
		"voicemail":
			Audio.sfx("tape_click", -6.0)
			hud.toast("On the tape", "A new message from " + name)

func _board_call(who: String) -> void:
	_set_browsing(false)
	if not Game.phone_call(who):
		hud.toast("The board", "You can't ring out just now.")

func _board_reply(who: String) -> void:
	_set_browsing(false)
	if not Game.phone_reply(who):
		hud.toast("The board", "Not right now.")

func _on_finished(reason: String) -> void:
	Game.playing = false
	if reason == "error":
		hud.toast("Story error", "The night stopped. Check the output log.")
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
	console.visible = false

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
	console.visible = true
	Audio.stop_all()

func _to_title() -> void:
	for c in overlay_root.get_children():
		c.queue_free()
	overlay_open = false
	_set_browsing(false)
	console.clear()
	console.clear_choices()
	board.clear_active()
	options = []
	stage.load_set("", "")
	collage.visible = false
	_apply_comp("black")
	_show_title()

## A picture of the night as it is, before a menu covers it.
func _snapshot() -> Image:
	var img := get_viewport().get_texture().get_image()
	img.resize(160, 90, Image.INTERPOLATE_NEAREST)
	return img

func _open_pause() -> void:
	if menu_open or title_screen:
		return
	Game.thumb = _snapshot()
	_remember_actor()
	menu_open = true
	var p := Menus.Pause.new()
	p.size = BASE
	menu_root.add_child(p)
	p.action.connect(_on_pause_action.bind(p))

func _on_pause_action(what: String, p: Control) -> void:
	p.queue_free()
	menu_open = false
	match what:
		"save":
			_open_saveload(true)
		"load":
			_open_saveload(false)
		"log":
			_open_backlog()
		"settings":
			_open_settings()
		"title":
			if Game.playing:
				Game.save_to(0)
			Game.playing = false
			_to_title()
		"quit":
			if Game.playing:
				Game.save_to(0)
			get_tree().quit()

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
			_remember_actor()
			if Game.save_to(slot):
				hud.toast("Saved", "Slot %d." % slot)
			else:
				hud.toast("Can't save", "Try again after this moment.")
		else:
			if title_screen:
				_close_title()
			_load_slot(slot))

func _load_slot(slot: int) -> void:
	Audio.stop_all()
	if not Game.load_from(slot):
		hud.toast("Can't load", "That save couldn't be read.")

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
