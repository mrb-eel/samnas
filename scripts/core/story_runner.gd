class_name StoryRunner
extends RefCounted
## Executes compiled story ops. Presentation lives elsewhere; this only emits
## signals and waits.
##
## Resume rule: the runner only ever stops ON an op that has no side effects
## when re-emitted (a line, a choice, or a blocking presentation command).
## Saving stores that pc. Loading re-emits it. Nothing before it runs again.

signal line(entry: Dictionary)
signal choices(options: Array)
signal command(name: String, args: Array)
signal finished(reason: String)
signal runtime_error(msg: String)

## Commands that stop the runner until resume() is called. They must be
## idempotent, because loading a save re-issues them.
const BLOCKING := {
	"wait": true, "chapter": true, "show_doc": true, "casio": true, "input_name": true,
	"drift": true, "rupture": true, "pause": true, "ending": true, "title_card": true,
}

var parser: StoryParser
var state  # Game (vars, seen_choices)
var pc: int = -1
var stack: Array = []
var waiting: String = ""  # "", "line", "choice", "cmd", "end"
var current_options: Array = []
var last_line: Dictionary = {}
var _expr_cache: Dictionary = {}
var _interp_re := RegEx.create_from_string("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
var steps_guard := 0

func setup(p: StoryParser, s) -> void:
	parser = p
	state = s

func start(label: String) -> void:
	if not parser.labels.has(label):
		runtime_error.emit("No knot named %s" % label)
		return
	pc = parser.labels[label]
	stack.clear()
	waiting = ""
	_run()

## Call a knot from outside the current flow (phone interrupts). The current
## op is re-emitted when the called knot returns.
func interrupt(label: String) -> bool:
	if not parser.labels.has(label):
		runtime_error.emit("No knot named %s" % label)
		return false
	if waiting != "line" and waiting != "choice":
		return false
	stack.append(pc)  # return to the op we were waiting on, so it re-emits
	pc = parser.labels[label]
	waiting = ""
	_run()
	return true

func advance() -> void:
	if waiting != "line":
		return
	waiting = ""
	pc += 1
	_run()

func resume() -> void:
	if waiting != "cmd":
		return
	waiting = ""
	pc += 1
	_run()

func choose(i: int) -> void:
	if waiting != "choice" or i < 0 or i >= current_options.size():
		return
	var opt: Dictionary = current_options[i]
	waiting = ""
	state.seen_choices[opt["id"]] = true
	if opt["speech"]:
		var entry := {"speaker": "ARI", "text": interpolate(opt["text"]), "kind": "echo", "src": opt["src"]}
		last_line = entry
		line.emit(entry)
	pc = opt["to"]
	_run()

## Re-emit whatever we are waiting on (after load or after an interrupt).
func reemit() -> void:
	var op: Dictionary = parser.ops[pc]
	match op["op"]:
		"line":
			waiting = ""
			_run()
		"choice":
			waiting = ""
			_run()
		"cmd":
			waiting = ""
			_run()
		_:
			_run()

func _run() -> void:
	steps_guard = 0
	while true:
		steps_guard += 1
		if steps_guard > 20000:
			runtime_error.emit("Runaway loop near %s" % str(parser.locate(pc)))
			waiting = "end"
			return
		if pc < 0 or pc >= parser.ops.size():
			runtime_error.emit("pc out of range: %d" % pc)
			waiting = "end"
			return
		var op: Dictionary = parser.ops[pc]
		match op["op"]:
			"line":
				var entry := {"speaker": op["speaker"], "text": interpolate(op["text"]), "kind": op["kind"], "src": op["src"]}
				last_line = entry
				waiting = "line"
				line.emit(entry)
				return
			"cmd":
				var args: Array = []
				for a in op["args"]:
					args.append(interpolate(str(a)))
				if BLOCKING.has(op["name"]):
					waiting = "cmd"
					command.emit(op["name"], args)
					return
				command.emit(op["name"], args)
				pc += 1
			"set":
				_assign(op)
				pc += 1
			"jmpf":
				if _truthy(eval_expr(op["cond"], op["src"])):
					pc += 1
				else:
					pc = op["to"]
			"jmp":
				pc = op["to"]
			"call":
				stack.append(pc + 1)
				pc = op["to"]
			"ret", "knot_end":
				if stack.is_empty():
					if op["op"] == "knot_end":
						runtime_error.emit("Fell off the end of knot '%s' with nothing to return to" % op["knot"])
					else:
						runtime_error.emit("return with empty stack at %s" % op.get("src", "?"))
					waiting = "end"
					finished.emit("error")
					return
				pc = stack.pop_back()
				# returning to an op we were waiting on: re-run it (it re-emits)
			"choice":
				var opts: Array = []
				for o in op["options"]:
					if not o["sticky"] and state.seen_choices.has(o["id"]):
						continue
					if o["cond"] != "" and not _truthy(eval_expr(o["cond"], o["src"])):
						continue
					opts.append(o)
				if opts.is_empty():
					# nothing available: fall through to the gather point
					pc = _gather_of(op)
					continue
				current_options = opts
				waiting = "choice"
				var shown: Array = []
				for o in opts:
					shown.append({"text": interpolate(o["text"]), "tags": o["tags"], "speech": o["speech"], "id": o["id"]})
				choices.emit(shown)
				return
			"end":
				waiting = "end"
				finished.emit("end")
				return
			_:
				runtime_error.emit("Unknown op %s" % op["op"])
				waiting = "end"
				return

func _gather_of(choice_op: Dictionary) -> int:
	return int(choice_op["gather"])

func _assign(op: Dictionary) -> void:
	var v = eval_expr(op["expr"], op["src"])
	var name: String = op["var"]
	match op["oper"]:
		"=":
			state.vars[name] = v
		"+=":
			var cur = state.vars.get(name, 0)
			if cur == null:
				cur = 0
			state.vars[name] = cur + v
		"-=":
			var cur2 = state.vars.get(name, 0)
			if cur2 == null:
				cur2 = 0
			state.vars[name] = cur2 - v

func _truthy(v) -> bool:
	return StoryExpr.truthy(v)

func eval_expr(src: String, where: String = ""):
	var ast = _expr_cache.get(src)
	if ast == null:
		ast = StoryExpr.compile(src)
		_expr_cache[src] = ast
	if ast[0] == "err":
		runtime_error.emit("%s: cannot parse '%s': %s" % [where, src, ast[1]])
		return null
	return StoryExpr.eval(ast, state.vars)

func interpolate(text: String) -> String:
	if text.find("{") == -1:
		return text
	var out := text
	for m in _interp_re.search_all(text):
		var v = state.vars.get(m.get_string(1), "")
		out = out.replace(m.get_string(), str(v))
	return out

# ---------------------------------------------------------------- save/load

func snapshot() -> Dictionary:
	var frames: Array = []
	for r in stack:
		frames.append(parser.locate(r))
	return {"at": parser.locate(pc), "stack": frames, "waiting": waiting, "hash": parser.hash_text()}

func restore(snap: Dictionary) -> bool:
	var same: bool = int(snap.get("hash", 0)) == parser.hash_text()
	var at: Array = snap["at"]
	if not parser.labels.has(at[0]):
		return false
	pc = parser.labels[at[0]] + (int(at[1]) if same else 0)
	stack.clear()
	for f in snap.get("stack", []):
		if parser.labels.has(f[0]):
			stack.append(parser.labels[f[0]] + (int(f[1]) if same else 0))
	waiting = ""
	return same
