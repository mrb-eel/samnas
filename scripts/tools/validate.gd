extends SceneTree
## Story validator and playthrough bot.
##
##   godot --headless --path . -s res://scripts/tools/validate.gd -- [out_dir] [runs]
##
## 1. Static checks: unknown knots, unknown commands, missing assets and data,
##    variables that are read but never initialised.
## 2. Route bots: fixed preference lists for specific routes (each ending,
##    angry at Jad, firm boundaries, renegotiated promise), transcripts saved.
## 3. Random bots with phone interrupts.
## 4. Save/load test: snapshot mid-run, restore into a fresh game, continue,
##    and check nothing was duplicated.

const KNOWN_CMDS := {
	"comp": 1, "set": 1, "cam": 1, "view": 1, "portrait": 1, "state": 1, "spot": 5, "spots_clear": 0,
	"time": 1, "chapter": 2, "title_card": 1, "wait": 1, "drift": 2, "rupture": 0, "show_doc": 1,
	"collage": 1, "collage_add": 3, "fade": 1, "sfx": 1, "amb": 1, "amb2": 1, "music": 1, "acoustic": 1,
	"casio": 0, "input_name": 2, "ending": 2, "call": 1, "hangup": 0, "ring": 1, "phone": 1,
	"phone_lock": 1, "contact_add": 1, "avail": 2, "callable": 2, "reply": 3, "reply_clear": 1,
	"text": 2, "sent": 2, "text_doc": 2, "vm_add": 1, "vm_archive_open": 0, "vm_mark": 1,
	"gallery_add": 1, "log": 2, "board": 1, "board_lock": 1, "hold": 1, "saved_as": 2, "xwin": 2, "clear": 0, "faint": 1, "pause": 0,
	"walk": 1, "walkto": 2, "place": 2,
	"cutscene": 1, "camto": 1, "shake": 1, "glitch": 1, "tint": 1, "flash": 1,
}
const SPEAKERS := ["ARI", "JAD", "INEZ", "DIMA", "SAL", "TEODOR", "KAYE", "NELL", "TOBI", "JUNE", "ADEYEMI", "MAN", "WOMAN", "LINE", "OPERATOR", "DRIVER", "RADIO"]
const SETS := ["street", "lobby", "office", "building", "courtyard", "nell", "pool", "exchange", "receiving", "copyshop", "bakery"]

var game
var out_dir := ""
var problems: PackedStringArray = []
var warnings: PackedStringArray = []
var _set_cache: Dictionary = {}
var _spot_warned: Dictionary = {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://validate"
	var runs := int(args[1]) if args.size() > 1 else 40
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scripts/core/game.gd").new()
	root.add_child(game)
	if game.parser == null:
		game.load_story()
	game.headless_bot = true
	for e in game.load_errors:
		problems.append("PARSE " + e)
	_static_checks()
	var summary: Array = []
	for route in _routes():
		summary.append(_run_route(route))
	var endings := {}
	var failures := 0
	for i in runs:
		var r := _run_random(i, i % 3 == 0)
		endings[r["ending"]] = int(endings.get(r["ending"], 0)) + 1
		if r["error"] != "":
			failures += 1
	var sl := _saveload_test(12)
	var report := PackedStringArray()
	report.append("== problems (%d)" % problems.size())
	report.append_array(problems)
	report.append("== warnings (%d)" % warnings.size())
	report.append_array(warnings)
	report.append("== routes")
	for s in summary:
		report.append(s)
	report.append("== random runs: %d, failures: %d, endings: %s" % [runs, failures, str(endings)])
	report.append("== save/load: " + sl)
	var f := FileAccess.open(out_dir.path_join("report.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report))
	print("\n".join(report))
	quit(0 if problems.is_empty() else 1)

# ------------------------------------------------------------------ static

func _static_checks() -> void:
	var p: StoryParser = game.parser
	var assigned := {}
	var read := {}
	var init_vars := {}
	var in_init := false
	var init_start: int = p.labels.get("init_vars", -1)
	var docs: Dictionary = game.docs_def
	var vms: Dictionary = game.voicemail_def
	var contacts: Dictionary = game.contacts_def
	var interp := RegEx.create_from_string("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	for i in p.ops.size():
		var op: Dictionary = p.ops[i]
		if init_start >= 0 and i >= init_start and p.locate(i)[0] == "init_vars" and op["op"] == "set":
			init_vars[op["var"]] = true
		match op["op"]:
			"set":
				assigned[op["var"]] = true
				for id in StoryExpr.identifiers(StoryExpr.compile(op["expr"])):
					read[id] = op["src"]
				var ast = StoryExpr.compile(op["expr"])
				if ast[0] == "err":
					problems.append("%s: bad expression '%s': %s" % [op["src"], op["expr"], ast[1]])
			"jmpf":
				var ast2 = StoryExpr.compile(op["cond"])
				if ast2[0] == "err":
					problems.append("%s: bad condition '%s': %s" % [op["src"], op["cond"], ast2[1]])
				for id in StoryExpr.identifiers(ast2):
					read[id] = op["src"]
			"choice":
				for o in op["options"]:
					if o["cond"] != "":
						var ast3 = StoryExpr.compile(o["cond"])
						if ast3[0] == "err":
							problems.append("%s: bad choice condition '%s'" % [o["src"], o["cond"]])
						for id in StoryExpr.identifiers(ast3):
							read[id] = o["src"]
					for m in interp.search_all(o["text"]):
						read[m.get_string(1)] = o["src"]
			"line":
				if op["kind"] in ["say", "sms"] and not SPEAKERS.has(op["speaker"]):
					problems.append("%s: unknown speaker '%s'" % [op["src"], op["speaker"]])
				for m in interp.search_all(op["text"]):
					read[m.get_string(1)] = op["src"]
			"cmd":
				var name: String = op["name"]
				var args: Array = op["args"]
				for a in args:
					for m in interp.search_all(str(a)):
						read[m.get_string(1)] = op["src"]
				if not KNOWN_CMDS.has(name):
					problems.append("%s: unknown command @%s" % [op["src"], name])
					continue
				if args.size() < KNOWN_CMDS[name]:
					problems.append("%s: @%s needs %d args, has %d" % [op["src"], name, KNOWN_CMDS[name], args.size()])
					continue
				match name:
					"callable", "reply":
						if args[1] != "off" and not p.labels.has(args[1]):
							problems.append("%s: @%s to unknown knot %s" % [op["src"], name, args[1]])
						if not contacts.has(args[0]):
							problems.append("%s: unknown contact %s" % [op["src"], args[0]])
					"show_doc", "gallery_add":
						if not docs.has(args[0]):
							problems.append("%s: unknown document %s" % [op["src"], args[0]])
						elif not ResourceLoader.exists(docs[args[0]].get("image", "")):
							warnings.append("%s: document image missing for %s" % [op["src"], args[0]])
					"text_doc":
						if not docs.has(args[1]):
							problems.append("%s: unknown document %s" % [op["src"], args[1]])
						if not contacts.has(args[0]):
							problems.append("%s: unknown contact %s" % [op["src"], args[0]])
					"vm_add", "vm_mark":
						if not vms.has(args[0]):
							problems.append("%s: unknown voicemail %s" % [op["src"], args[0]])
					"contact_add", "avail", "text", "sent", "saved_as", "call", "reply_clear":
						if not contacts.has(args[0]) and not args[0].begins_with("{"):
							problems.append("%s: unknown contact %s" % [op["src"], args[0]])
					"ring":
						if args[0] != "off" and not contacts.has(args[0]) and not args[0].begins_with("{"):
							problems.append("%s: unknown contact %s" % [op["src"], args[0]])
					"set":
						if not SETS.has(args[0]):
							problems.append("%s: unknown set %s" % [op["src"], args[0]])
						elif not ResourceLoader.exists("res://scripts/sets/set_%s.gd" % args[0]):
							warnings.append("%s: set script missing: %s" % [op["src"], args[0]])
					"sfx", "amb", "amb2", "music":
						var id: String = args[0]
						if id != "off" and not id.contains("{") and not ResourceLoader.exists("res://assets/audio/%s.wav" % id) and not ResourceLoader.exists("res://assets/audio/%s.ogg" % id):
							warnings.append("%s: audio missing: %s" % [op["src"], id])
					"collage_add":
						if not ResourceLoader.exists("res://assets/collage/%s.png" % args[0]):
							warnings.append("%s: collage image missing: %s" % [op["src"], args[0]])
					"portrait":
						if args[0] != "off" and not ResourceLoader.exists("res://assets/portraits/%s_neutral.png" % args[0]):
							warnings.append("%s: portrait missing: %s" % [op["src"], args[0]])
	for v in read:
		if not init_vars.has(v) and v not in ["casio_resolved", "casio_played"]:
			problems.append("variable '%s' read (e.g. %s) but not initialised in init_vars" % [v, read[v]])
		if not assigned.has(v) and v not in ["casio_resolved", "casio_played"]:
			warnings.append("variable '%s' read but never assigned" % v)
	for v in assigned:
		if not read.has(v) and not init_vars.has(v):
			warnings.append("variable '%s' assigned but never read (tracked fact only?)" % v)
	for c in contacts:
		pass

# ------------------------------------------------------------------ bots

func _routes() -> Array:
	return [
		{"name": "accept_warm", "prefer": ["Plug in", "Pick it up", "\"Yes.\"", "Please", "Look", "look", "I'll look away", "I'll ring at three", "Tell me about paper", "Yes. Do it.", "Do it.", "Would you hold the place", "Ring Nell", "Could you take Mrs. Kaye", "If the desk's gone", "Ring Teodor", "I know what I want", "come through. And take the job", "Jad said he would", "Cross out continuous", "Stay.", "Tomorrow"]},
		{"name": "refuse_name", "prefer": ["Plug in", "Pick it up", "Can I look", "Don't go through it", "\"I'll look away", "Look at the ceiling", "I'm not him", "Text Dima", "Ring Dima", "Did you make me up", "\"Now.\"", "Who knew", "Why?", "Is your name on one", "Do it.", "Ring Teodor", "Would you hold the place", "Ring Mrs. Kaye", "Can I tell you what I am", "I can't promise Thursday", "Ring Nell", "Could you take Mrs. Kaye", "I know what I want", "Not the job", "Teodor said he would", "Something else", "Go.", "Tomorrow"]},
		{"name": "shared_line", "prefer": ["Plug in", "Pick it up", "Can I look", "Please", "The rain", "Okay.", "I'll look away", "I'll stay on, but I won't look", "Can I keep it", "What rules", "Ring Nell", "If the desk's gone", "Ring Teodor", "Ring Mrs. Kaye", "I'll make sure someone takes you", "Could you take Mrs. Kaye", "Would you check the frame", "I know what I want", "stay on the line", "Yes. To the rules", "I don't want to decide", "Tomorrow"]},
		{"name": "angry_at_jad", "prefer": ["Plug in", "Pick it up", "Why would you", "I'll manage", "\"Don't.\"", "You've got another reason", "Did you make me up", "\"Now.\"", "You made me up to fill a box", "You let me think the bag was mine", "You listened", "Get out of my office", "Let it ring", "No. Don't.", "Don't ring me again", "I know what I want", "Not the job", "You. Would you", "Tomorrow"]},
		{"name": "firm_boundaries", "prefer": ["Plug in", "Pick it up", "Don't go through it", "I'll manage", "I'll look away", "I might not be able to", "Look at the ceiling", "I don't think I've got hands", "Okay.", "I might be busy", "I don't know if I play", "\"Don't look at it like that", "Don't do anything else for me", "No. Don't.", "I can't do Thursday", "I know what I want", "Not the job", "Teodor said he would", "You. Would you", "I don't want to decide", "Tomorrow"]},
		{"name": "renegotiate", "prefer": ["Plug in", "Pick it up", "Read it now", "Thursday, the 36", "I'll ring at three", "I'll pick up", "Text Dima", "Ring Dima", "Ring Mrs. Kaye", "I can't promise Thursday", "Ring Teodor", "Could you take Mrs. Kaye", "Would you hold the place", "I know what I want", "stay on the line", "Yes. And I want to be able", "Tomorrow"]},
		{"name": "violations", "prefer": ["Plug in", "Pick it up", "Keep looking", "Read the name", "Why fake", "Get out of my office", "Let it ring", "I know what I want", "take the job", "You. Would you", "Sign it as it is", "Go."]},
	]

## What the set that's up declares: hotspots, doors, whether it has a floor.
## Read from the set's source (sets use autoloads, which a -s script can't
## compile), so every add_hotspot / add_entry / person_spot must name its
## spot with a literal string.
func _current_set() -> Dictionary:
	var name: String = game.pres.get("set", "")
	if name == "":
		return {}
	if not _set_cache.has(name):
		var path := "res://scripts/sets/set_%s.gd" % name
		var info := {"hotspots": {}, "entries": {}, "cams": {}, "floor": false}
		if FileAccess.file_exists(path):
			var src := FileAccess.get_file_as_string(path)
			for m in RegEx.create_from_string("(?:add_hotspot|person_spot)\\(\"([A-Za-z0-9_]+)\"").search_all(src):
				info["hotspots"][m.get_string(1)] = true
			for m in RegEx.create_from_string("add_entry\\(\"([A-Za-z0-9_]+)\"").search_all(src):
				info["entries"][m.get_string(1)] = true
			for m in RegEx.create_from_string("add_cam\\(\"([A-Za-z0-9_]+)\"").search_all(src):
				info["cams"][m.get_string(1)] = true
			info["floor"] = src.find("add_floor(") != -1
			if src.find("_flat_spot(") != -1:
				for f in range(1, 7):
					for l in ["A", "B", "C", "D", "E", "F", "G"]:
						info["hotspots"]["%d%s" % [f, l]] = true
		_set_cache[name] = info
	return _set_cache[name]

func _check_target(target: String, src: String) -> void:
	var st := _current_set()
	if st.is_empty():
		return
	if not st["hotspots"].has(target) and not st["entries"].has(target):
		var k := "%s:%s" % [src, target]
		if not _spot_warned.has(k):
			_spot_warned[k] = true
			problems.append("%s: '%s' is neither a hotspot nor a door in set '%s'" % [src, target, game.pres.get("set", "")])

## A camera the set doesn't have falls back to its main camera without a
## word, so say so here.
func _check_cam(cam: String) -> void:
	var st := _current_set()
	if st.is_empty() or st["cams"].is_empty() or st["cams"].has(cam):
		return
	var k := "cam:%s:%s" % [game.pres.get("set", ""), cam]
	if not _spot_warned.has(k):
		_spot_warned[k] = true
		var at: Array = game.parser.locate(game.runner.pc)
		problems.append("%s: no camera '%s' in set '%s'" % [at[0], cam, game.pres.get("set", "")])

func _check_spots() -> void:
	if game.pres.get("cutscene", false):
		for o in game.runner.current_options:
			for t in o["tags"]:
				if str(t).begins_with("spot:"):
					var kc := "cut:%s" % o["src"]
					if not _spot_warned.has(kc):
						_spot_warned[kc] = true
						problems.append("%s: a room choice (%s) while a cutscene has the camera" % [o["src"], t])
	var w: Array = game.pres.get("walk", [])
	if w.is_empty():
		return
	var st := _current_set()
	if st.is_empty():
		return
	if w.size() > 1 and w[1] != "" and not st["entries"].has(w[1]):
		var k0 := "entry:%s:%s" % [game.pres.get("set", ""), w[1]]
		if not _spot_warned.has(k0):
			_spot_warned[k0] = true
			problems.append("@walk %s: no door '%s' in set '%s'" % [w[0], w[1], game.pres.get("set", "")])
	if w[0] != "none" and not st["floor"]:
		var k1 := "floor:%s" % game.pres.get("set", "")
		if not _spot_warned.has(k1):
			_spot_warned[k1] = true
			problems.append("@walk %s: set '%s' has no floor" % [w[0], game.pres.get("set", "")])
	for o in game.runner.current_options:
		for t in o["tags"]:
			if str(t).begins_with("spot:") and not st["hotspots"].has(str(t).substr(5)):
				var k := "%s:%s" % [o["src"], t]
				if not _spot_warned.has(k):
					_spot_warned[k] = true
					problems.append("%s: %s has no hotspot in set '%s'" % [o["src"], t, game.pres.get("set", "")])

func _pick(options: Array, prefer: Array, rng: RandomNumberGenerator) -> int:
	for want in prefer:
		for i in options.size():
			var t: String = options[i]["text"]
			if options[i]["speech"]:
				t = "\"" + t + "\""
			if t.findn(want) != -1:
				return i
	return rng.randi_range(0, options.size() - 1)

func _new_run() -> void:
	game.reset_state()
	game.playing = true
	game.runner.start("start")

func _play(prefer: Array, rng: RandomNumberGenerator, interrupts: bool, transcript: PackedStringArray, max_steps: int = 6000) -> String:
	var err := ""
	var cb_line := func(e): transcript.append("%s%s: %s" % [("[%s] " % e["kind"]) if e["kind"] != "say" else "", e["speaker"], e["text"]])
	var cb_err := func(m): transcript.append("!! ERROR " + m)
	var cb_pres := func(n, a):
		if n in ["cam", "camto"] and a.size() > 0:
			_check_cam(str(a[0]))
	game.runner.line.connect(cb_line)
	game.runner.runtime_error.connect(cb_err)
	game.pres_command.connect(cb_pres)
	var steps := 0
	var picks_seen := {}
	while game.runner.waiting != "end" and steps < max_steps:
		steps += 1
		match game.runner.waiting:
			"line":
				if interrupts and rng.randf() < 0.03:
					_try_interrupt(rng, transcript)
					continue
				game.runner.advance()
			"choice":
				_check_spots()
				if interrupts and rng.randf() < 0.05:
					_try_interrupt(rng, transcript)
					continue
				var opts: Array = []
				for o in game.runner.current_options:
					opts.append({"text": o["text"], "speech": o["speech"]})
				var i := _pick(opts, prefer, rng)
				var key := str(game.runner.pc) + ":" + str(i)
				picks_seen[key] = int(picks_seen.get(key, 0)) + 1
				if picks_seen[key] > 12:
					i = rng.randi_range(0, opts.size() - 1)
				transcript.append("  > " + opts[i]["text"])
				game.runner.choose(i)
			"cmd":
				var op: Dictionary = game.parser.ops[game.runner.pc]
				if op["name"] == "input_name":
					game.vars[op["args"][0]] = "Wren"
				elif op["name"] == "casio":
					game.vars["casio_resolved"] = rng.randf() < 0.5
					game.vars["casio_played"] = 5
				elif op["name"] == "ending":
					transcript.append("== ENDING %s %s" % op["args"])
					game.vars["ending_seen"] = op["args"][0]
				elif op["name"] == "walkto":
					_check_target(op["args"][1], op["src"])
				game.runner.resume()
			_:
				err = "stuck waiting='%s'" % game.runner.waiting
				break
	if steps >= max_steps:
		err = "step limit"
	for l in transcript:
		if l.begins_with("!! ERROR"):
			err = l
			break
	if err == "" and game.pres.get("cutscene", false):
		err = "the night ended inside a cutscene"
	game.runner.line.disconnect(cb_line)
	game.runner.runtime_error.disconnect(cb_err)
	game.pres_command.disconnect(cb_pres)
	return err

func _try_interrupt(rng: RandomNumberGenerator, transcript: PackedStringArray) -> void:
	var ids: Array = []
	for id in game.phone["contacts"]:
		var c: Dictionary = game.phone["contacts"][id]
		if c["call_label"] != "" and c["avail"]:
			ids.append(["call", id])
		if c["reply_label"] != "":
			ids.append(["reply", id])
	if ids.is_empty() or not game.can_interrupt():
		if game.runner.waiting == "line":
			game.runner.advance()
		return
	var pick: Array = ids[rng.randi_range(0, ids.size() - 1)]
	transcript.append("  [phone %s %s]" % pick)
	if pick[0] == "call":
		game.phone_call(pick[1])
	else:
		game.phone_reply(pick[1])

func _run_route(route: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_new_run()
	var tr := PackedStringArray()
	var err := _play(route["prefer"], rng, false, tr)
	var f := FileAccess.open(out_dir.path_join("route_%s.txt" % route["name"]), FileAccess.WRITE)
	f.store_string("\n".join(tr))
	var v: Dictionary = game.vars
	var words := 0
	for l in tr:
		words += l.split(" ", false).size()
	return "%-16s ending=%s err=%s words=%d  jad=%s body=%s appt=%s holder=%s kaye=%s/%s dima=%s b_dima=%s b_inez=%s b_nell=%s view=%s casio=%s" % [
		route["name"], v.get("ending_seen", game.pres.get("ending", "?")), err, words, v.get("jad_state"), v.get("end_body"),
		v.get("end_appointment"), v.get("holder"), v.get("p_kaye_thursday"), v.get("arr_kaye"), v.get("p_dima_call"),
		v.get("b_dima"), v.get("b_inez"), v.get("b_nell_phone"), v.get("view_caller"), v.get("phrase_resolved")]

func _run_random(i: int, interrupts: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + i
	_new_run()
	var tr := PackedStringArray()
	var err := _play([], rng, interrupts, tr)
	if err != "":
		var f := FileAccess.open(out_dir.path_join("random_fail_%d.txt" % i), FileAccess.WRITE)
		f.store_string(err + "\n\n" + "\n".join(tr.slice(max(0, tr.size() - 80))))
	return {"ending": str(game.vars.get("end_appointment", "none")) + ("" if err == "" else "!"), "error": err}

## Deterministic policy so two copies of a run choose the same way.
func _det_pick(n: int) -> int:
	return absi(hash(str(game.runner.pc) + str(game.seen_choices.size()) + str(game.phone["log"].size()))) % n

func _det_play_until(stop_after: int) -> int:
	var steps := 0
	while game.runner.waiting != "end" and steps < stop_after:
		steps += 1
		match game.runner.waiting:
			"line":
				game.runner.advance()
			"choice":
				game.runner.choose(_det_pick(game.runner.current_options.size()))
			"cmd":
				var op: Dictionary = game.parser.ops[game.runner.pc]
				if op["name"] == "input_name":
					game.vars[op["args"][0]] = "Wren"
				elif op["name"] == "casio":
					game.vars["casio_resolved"] = true
					game.vars["casio_played"] = 5
				game.runner.resume()
	return steps

func _fingerprint() -> String:
	var parts: Array = []
	var cids: Array = game.phone["contacts"].keys()
	cids.sort()
	for id in cids:
		parts.append("%s:%d:%d" % [id, game.phone["contacts"][id]["thread"].size(), int(game.phone["contacts"][id]["unread"])])
	parts.append("vm:%d" % game.phone["voicemails"].size())
	parts.append("gal:%d" % game.phone["gallery"].size())
	parts.append("log:%d" % game.phone["log"].size())
	var keys: Array = game.vars.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [k, str(game.vars[k])])
	return "|".join(parts)

func _saveload_test(n: int) -> String:
	var fails := 0
	var detail := ""
	for i in n:
		_new_run()
		var cut := 60 + i * 97
		_det_play_until(cut)
		if game.runner.waiting == "end" or game.runner.waiting == "":
			continue
		var snap := JSON.stringify(game.make_save())
		var before_threads := _fingerprint()
		# continue the original
		_det_play_until(400)
		var a := _fingerprint()
		# restore into the same game object from the snapshot and continue identically
		game.apply_save(JSON.parse_string(snap))
		var after_load := _fingerprint()
		if after_load != before_threads:
			fails += 1
			detail += "\n  load changed state at cut %d:\n    before %s\n    after  %s" % [cut, before_threads.substr(0, 300), after_load.substr(0, 300)]
			continue
		_det_play_until(400)
		var b := _fingerprint()
		if a != b:
			fails += 1
			detail += "\n  divergence after load at cut %d" % cut
	return "%d/%d ok%s" % [n - fails, n, detail]
