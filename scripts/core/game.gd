extends Node
## Autoload "Game": story state, phone state, presentation snapshot, saving.
##
## Presentation (the Main scene) listens to the runner and to `pres_command`.
## Everything that must survive a save lives in this node's dictionaries.

signal pres_command(name: String, args: Array)
signal phone_changed()
signal notify(kind: String, who: String, text: String)
signal story_line(entry: Dictionary)
signal story_choices(options: Array)
signal story_finished(reason: String)
signal story_error(msg: String)

const SAVE_VERSION := 3
const STORY_DIR := "res://story/"
const START_KNOT := "start"
const MAX_BACKLOG := 600

var parser: StoryParser
var runner: StoryRunner
var story_ok := false
var load_errors: PackedStringArray = []

var vars: Dictionary = {}
var seen_choices: Dictionary = {}
var phone: Dictionary = {}
var pres: Dictionary = {}
var backlog: Array = []

var contacts_def: Dictionary = {}
var contacts_order: Array = []
var voicemail_def: Dictionary = {}
var docs_def: Dictionary = {}
var playing := false
var headless_bot := false

func _ready() -> void:
	load_story()
	reset_state()

# ------------------------------------------------------------------ loading

func load_story() -> void:
	parser = StoryParser.new()
	var files: Array = []
	var d := DirAccess.open(STORY_DIR)
	if d:
		for f in d.get_files():
			if f.ends_with(".hmp"):
				files.append(STORY_DIR + f)
	files.sort()
	story_ok = parser.parse_files(files)
	load_errors = parser.errors
	for e in load_errors:
		push_error(e)
	contacts_def = _load_json(STORY_DIR + "contacts.json")
	contacts_order = contacts_def.get("_order", [])
	contacts_def.erase("_order")
	voicemail_def = _load_json(STORY_DIR + "voicemails.json")
	docs_def = _load_json(STORY_DIR + "documents.json")
	runner = StoryRunner.new()
	runner.setup(parser, self)
	runner.line.connect(_on_line)
	runner.choices.connect(_on_choices)
	runner.command.connect(_on_command)
	runner.finished.connect(func(r): story_finished.emit(r))
	runner.runtime_error.connect(func(m): push_error(m); story_error.emit(m))

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data == null:
		push_error("Bad JSON in %s" % path)
		return {}
	return data

# ------------------------------------------------------------------ new game

func new_game() -> void:
	reset_state()
	playing = true
	runner.start(START_KNOT)

func reset_state() -> void:
	vars = {}
	seen_choices = {}
	backlog = []
	pres = {"comp": "black", "set": "", "variant": "", "cam": "", "view": "none", "portraits": {},
		"clock": "23:14", "chapter": 0, "chapter_title": "", "amb": "", "amb2": "", "music": "",
		"acoustic": "", "phone_open": false, "phone_thread": "", "phone_locked": false,
		"states": {}, "spots": {}, "collage": false, "collage_items": [], "ring": "", "xwins": {}}
	phone = {"contacts": {}, "voicemails": [], "gallery": [], "log": [], "call": {"active": false, "who": ""},
		"archive_open": false}
	for id in contacts_order:
		var c: Dictionary = contacts_def[id]
		phone["contacts"][id] = {"known": c.get("known", false), "avail": true, "reason": "",
			"call_label": "", "reply_label": "", "reply_prompt": "", "unread": 0, "thread": [],
			"saved_as": ""}
	for vm_id in voicemail_def.keys():
		var v: Dictionary = voicemail_def[vm_id]
		if v.get("preloaded", false):
			phone["voicemails"].append({"id": vm_id, "heard": false})
	phone["log"].append({"who": "jad", "when": "23:09", "dir": "missed"})

# ------------------------------------------------------------------ runner hooks

func _on_line(entry: Dictionary) -> void:
	if entry["kind"] == "sms" or (entry["kind"] == "echo" and pres.get("phone_open", false) and pres.get("phone_thread", "") != ""):
		var who: String = entry["speaker"].to_lower()
		var thread_id: String = pres.get("phone_thread", "")
		var from_ari := who == "ari"
		if not from_ari:
			thread_id = who
		if thread_id != "" and phone["contacts"].has(thread_id):
			_append_msg(thread_id, "ari" if from_ari else "them", entry["text"], entry.get("src", ""), true)
		entry["kind"] = "sms"
		entry["thread"] = thread_id
	_add_backlog(entry)
	story_line.emit(entry)

func _on_choices(options: Array) -> void:
	story_choices.emit(options)

func _add_backlog(entry: Dictionary) -> void:
	if backlog.size() > 0:
		var last: Dictionary = backlog[-1]
		if last.get("src", "") == entry.get("src", "") and last.get("text", "") == entry.get("text", "") and entry.get("src", "") != "":
			return  # re-emitted after a load
	backlog.append({"speaker": entry["speaker"], "text": entry["text"], "kind": entry["kind"],
		"src": entry.get("src", ""), "clock": pres.get("clock", "")})
	if backlog.size() > MAX_BACKLOG:
		backlog = backlog.slice(backlog.size() - MAX_BACKLOG)

func _append_msg(who: String, from: String, text: String, src: String, dedupe: bool, doc: String = "") -> void:
	var c: Dictionary = phone["contacts"][who]
	var th: Array = c["thread"]
	if dedupe and src != "" and th.size() > 0 and th[-1].get("src", "") == src and th[-1].get("text", "") == text:
		return
	th.append({"from": from, "text": text, "src": src, "clock": pres.get("clock", ""), "doc": doc})
	c["known"] = true
	var viewing: bool = pres.get("phone_open", false) and pres.get("phone_thread", "") == who
	if from == "them" and not viewing:
		c["unread"] = int(c["unread"]) + 1
		notify.emit("text", who, text)
	phone_changed.emit()

func _on_command(name: String, args: Array) -> void:
	# Ari's interface is the attendant's board; "board" commands drive the same state.
	if name == "board":
		name = "phone"
	elif name == "board_lock":
		name = "phone_lock"
	match name:
		# ---------------- phone / state (handled here, never blocking)
		"contact_add":
			_c(args[0])["known"] = true
			phone_changed.emit()
		"avail":
			var c := _c(args[0])
			c["avail"] = args[1] == "on"
			c["reason"] = args[2] if args.size() > 2 else ""
			phone_changed.emit()
		"callable":
			var c2 := _c(args[0])
			if args[1] == "off":
				c2["call_label"] = ""
				c2["reason"] = args[2] if args.size() > 2 else c2["reason"]
				c2["avail"] = false
			else:
				c2["call_label"] = args[1]
				c2["avail"] = true
				c2["reason"] = ""
			c2["known"] = true
			phone_changed.emit()
		"reply":
			var c3 := _c(args[0])
			c3["reply_label"] = args[1]
			c3["reply_prompt"] = args[2] if args.size() > 2 else "Reply"
			c3["known"] = true
			phone_changed.emit()
			notify.emit("reply", args[0], c3["reply_prompt"])
		"reply_clear":
			var c4 := _c(args[0])
			var had: bool = c4["reply_label"] != ""
			c4["reply_label"] = ""
			c4["reply_prompt"] = ""
			if had and args.size() > 1 and args[1] != "":
				c4["thread"].append({"from": "sys", "text": args[1], "src": "", "clock": pres.get("clock", ""), "doc": ""})
			phone_changed.emit()
		"text":
			_append_msg(args[0], "them", args[1], "", false)
		"sent":
			_append_msg(args[0], "ari", args[1], "", false)
		"text_doc":
			var cap: String = args[2] if args.size() > 2 else ""
			_append_msg(args[0], "them", cap, "", false, args[1])
			_gallery_add(args[1], args[0])
		"vm_add":
			for v in phone["voicemails"]:
				if v["id"] == args[0]:
					return
			phone["voicemails"].append({"id": args[0], "heard": false})
			notify.emit("voicemail", voicemail_def.get(args[0], {}).get("from", ""), "New voicemail")
			phone_changed.emit()
		"vm_archive_open":
			phone["archive_open"] = true
			for vm_id in voicemail_def.keys():
				if voicemail_def[vm_id].get("archived", false):
					var present := false
					for v in phone["voicemails"]:
						if v["id"] == vm_id:
							present = true
					if not present:
						phone["voicemails"].append({"id": vm_id, "heard": false})
			phone_changed.emit()
		"gallery_add":
			_gallery_add(args[0], args[1] if args.size() > 1 else "")
		"log":
			phone["log"].append({"who": args[0], "dir": args[1], "when": args[2] if args.size() > 2 else pres.get("clock", "")})
			phone_changed.emit()
		"saved_as":
			_c(args[0])["saved_as"] = args[1]
			phone_changed.emit()
		"call":
			var dir := "in" if pres.get("ring", "") == args[0] else "out"
			phone["call"] = {"active": true, "who": args[0]}
			pres["ring"] = ""
			_c(args[0])["known"] = true
			phone["log"].append({"who": args[0], "dir": dir, "when": pres.get("clock", "")})
			pres_command.emit(name, args)
			phone_changed.emit()
		"hangup":
			phone["call"] = {"active": false, "who": ""}
			pres["view"] = "none"
			pres_command.emit(name, args)
			phone_changed.emit()
		# ---------------- presentation (recorded, then forwarded)
		_:
			_record_pres(name, args)
			pres_command.emit(name, args)

func _c(who: String) -> Dictionary:
	if not phone["contacts"].has(who):
		push_error("Unknown contact %s" % who)
		phone["contacts"][who] = {"known": true, "avail": false, "reason": "", "call_label": "",
			"reply_label": "", "reply_prompt": "", "unread": 0, "thread": [], "saved_as": ""}
	return phone["contacts"][who]

func _gallery_add(id: String, from: String) -> void:
	for g in phone["gallery"]:
		if g["id"] == id:
			return
	phone["gallery"].append({"id": id, "from": from, "clock": pres.get("clock", "")})
	phone_changed.emit()

func _record_pres(name: String, args: Array) -> void:
	match name:
		"comp":
			pres["comp"] = args[0]
		"set":
			pres["set"] = args[0]
			pres["variant"] = args[1] if args.size() > 1 else ""
			pres["states"] = {}
			pres["spots"] = {}
		"cam":
			pres["cam"] = args[0]
		"view":
			pres["view"] = args[0]
		"portrait":
			if args[0] == "off":
				if args.size() > 1:
					pres["portraits"].erase(args[1])
				else:
					pres["portraits"] = {}
			else:
				pres["portraits"][args[0]] = {"expr": args[1] if args.size() > 1 else "neutral",
					"slot": args[2] if args.size() > 2 else "edge"}
		"state":
			pres["states"][args[0]] = args[1] if args.size() > 1 else "on"
		"spot":
			pres["spots"][args[0]] = [float(args[1]), float(args[2]), float(args[3]), float(args[4])]
		"spots_clear":
			pres["spots"] = {}
		"time":
			pres["clock"] = args[0]
		"chapter":
			pres["chapter"] = int(args[0])
			pres["chapter_title"] = args[1] if args.size() > 1 else ""
		"amb":
			pres["amb"] = "" if args[0] == "off" else args[0]
		"amb2":
			pres["amb2"] = "" if args[0] == "off" else args[0]
		"music":
			pres["music"] = "" if args[0] == "off" else args[0]
		"acoustic":
			pres["acoustic"] = args[0]
		"phone":
			match args[0]:
				"open":
					pres["phone_open"] = true
				"close":
					pres["phone_open"] = false
					pres["phone_thread"] = ""
				"thread":
					pres["phone_open"] = true
					pres["phone_thread"] = args[1]
					_c(args[1])["unread"] = 0
				_:
					pres["phone_open"] = true
					pres["phone_thread"] = ""
		"phone_lock":
			pres["phone_locked"] = args[0] == "on"
		"collage":
			pres["collage"] = args[0] == "on"
			if args[0] == "off":
				pres["collage_items"] = []
		"collage_add":
			pres["collage_items"].append(args)
		"ring":
			pres["ring"] = args[0] if args[0] != "off" else ""
		"hold":
			pres["cord_hold"] = args[0] == "on"
		"xwin":
			if not pres.has("xwins"):
				pres["xwins"] = {}
			if args[1] == "off":
				pres["xwins"].erase(args[0])
			else:
				pres["xwins"][args[0]] = args.slice(1)

# ------------------------------------------------------------------ phone actions from UI

func can_interrupt() -> bool:
	return playing and (runner.waiting == "line" or runner.waiting == "choice") \
		and not pres.get("phone_locked", false) and not pres.get("phone_open", false) \
		and pres.get("ring", "") == "" \
		and not phone["call"]["active"]

func phone_call(who: String) -> bool:
	var c: Dictionary = phone["contacts"].get(who, {})
	if c.is_empty() or c["call_label"] == "" or not can_interrupt():
		return false
	return runner.interrupt(c["call_label"])

func phone_reply(who: String) -> bool:
	var c: Dictionary = phone["contacts"].get(who, {})
	if c.is_empty() or c["reply_label"] == "" or not can_interrupt():
		return false
	var label: String = c["reply_label"]
	c["reply_label"] = ""
	c["reply_prompt"] = ""
	phone_changed.emit()
	return runner.interrupt(label)

func mark_thread_read(who: String) -> void:
	if phone["contacts"].has(who):
		phone["contacts"][who]["unread"] = 0
		phone_changed.emit()

func mark_vm_heard(id: String) -> void:
	for v in phone["voicemails"]:
		if v["id"] == id:
			v["heard"] = true
	phone_changed.emit()

func unread_total() -> int:
	var n := 0
	for id in phone["contacts"]:
		n += int(phone["contacts"][id]["unread"])
		if phone["contacts"][id]["reply_label"] != "":
			n += 1
	for v in phone["voicemails"]:
		if not v["heard"]:
			n += 1
	return n

func set_var(name: String, value) -> void:
	vars[name] = value

# ------------------------------------------------------------------ save/load

func save_path(slot: int) -> String:
	return "user://save_%d.json" % slot

func make_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"runner": runner.snapshot(),
		"vars": vars.duplicate(true),
		"seen_choices": seen_choices.duplicate(true),
		"phone": phone.duplicate(true),
		"pres": pres.duplicate(true),
		"backlog": backlog.duplicate(true),
	}

func save_to(slot: int) -> bool:
	if not playing or runner.waiting == "" or runner.waiting == "end":
		return false
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(make_save(), "  "))
	return true

func read_save(slot: int) -> Dictionary:
	if not FileAccess.file_exists(save_path(slot)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	return data if data is Dictionary else {}

func load_from(slot: int) -> bool:
	var data := read_save(slot)
	if data.is_empty():
		return false
	return apply_save(data)

## Restores state and re-emits the op the save was waiting on. Nothing that
## ran before the save runs again: messages, promises and variables come back
## exactly as stored.
func apply_save(data: Dictionary) -> bool:
	vars = _fix_numbers(data.get("vars", {}))
	seen_choices = data.get("seen_choices", {})
	phone = _fix_numbers(data.get("phone", {}))
	pres = data.get("pres", {})
	backlog = data.get("backlog", [])
	var exact := runner.restore(data["runner"])
	if not exact:
		push_warning("Story changed since this save; resuming from the start of the scene.")
	playing = true
	pres_command.emit("__restore", [])
	phone_changed.emit()
	runner.reemit()
	return true

## JSON turns ints into floats. Story variables are whole numbers or strings.
func _fix_numbers(d):
	if d is Dictionary:
		var out := {}
		for k in d:
			out[k] = _fix_numbers(d[k])
		return out
	if d is Array:
		var arr: Array = []
		for x in d:
			arr.append(_fix_numbers(x))
		return arr
	if d is float and d == floor(d):
		return int(d)
	return d

func has_any_save() -> bool:
	for s in range(0, 7):
		if FileAccess.file_exists(save_path(s)):
			return true
	return false

func latest_slot() -> int:
	var best := -1
	var best_t := ""
	for s in range(0, 7):
		var d := read_save(s)
		if d.is_empty():
			continue
		if best == -1 or str(d.get("saved_at", "")) > best_t:
			best = s
			best_t = str(d.get("saved_at", ""))
	return best
