class_name StoryParser
extends RefCounted
## Compiles .hmp story files into a flat list of ops.
##
## The language is documented in docs/SCRIPT_FORMAT.md. In short:
##   === knot_name            start a knot (label)
##   JAD: text                dialogue
##   plain text               narration
##   SOUND: text              caption for a sound that carries information
##   THINK: text              a thought that arrives on its own
##   JAD> text / ARI> text    a text message in the open phone thread
##   * [tag] {cond} "Speech"  once-only choice; quoted text is said verbatim
##   + ...                    sticky choice
##   if / elif / else:        conditionals (indented blocks)
##   ~ var = expr             assignment (=, +=, -=)
##   @command args            presentation / phone / audio command
##   -> knot                  divert;  -> END ends the story
##   ->> knot                 call a knot, come back after it returns
##   return                   return from a called knot

const SPEAKER_RE := "^([A-Z][A-Z0-9 .'_-]*?)(:|>)\\s?(.*)$"

var ops: Array = []
var labels: Dictionary = {}
var knot_starts: Array = []  # [[pc, name]] sorted by pc
var errors: PackedStringArray = []
var _speaker_re := RegEx.new()
var _divert_fixups: Array = []  # [op_index, target, src]
var _choice_counter: Dictionary = {}

class Ln:
	var indent: int
	var text: String
	var src: String

func _init() -> void:
	_speaker_re.compile(SPEAKER_RE)

func parse_files(paths: Array) -> bool:
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			errors.append("Cannot open %s" % p)
			continue
		parse_text(f.get_as_text(), p.get_file())
	_resolve()
	return errors.is_empty()

func parse_text(text: String, fname: String) -> void:
	var raw := text.split("\n")
	var lines: Array = []
	for i in raw.size():
		var s: String = raw[i].replace("\t", "    ").rstrip(" \r")
		var stripped := s.strip_edges(true, false)
		if stripped == "" or stripped.begins_with("#"):
			continue
		var l := Ln.new()
		l.indent = s.length() - stripped.length()
		l.text = stripped
		l.src = "%s:%d" % [fname, i + 1]
		lines.append(l)
	var i := 0
	while i < lines.size():
		var l: Ln = lines[i]
		if l.text.begins_with("==="):
			var name := l.text.trim_prefix("===").strip_edges()
			if labels.has(name):
				errors.append("%s: duplicate knot '%s'" % [l.src, name])
			_close_knot()
			labels[name] = ops.size()
			knot_starts.append([ops.size(), name])
			_choice_counter[name] = 0
			i += 1
			var body_end := i
			while body_end < lines.size() and not lines[body_end].text.begins_with("==="):
				body_end += 1
			var body := lines.slice(i, body_end)
			if body.size() > 0:
				_block(body, 0, body.size(), body[0].indent, name)
			i = body_end
		else:
			errors.append("%s: text outside of a knot" % l.src)
			i += 1
	_close_knot()

func _close_knot() -> void:
	if knot_starts.size() > 0:
		var last_name: String = knot_starts[-1][1]
		if ops.size() == 0 or ops[-1].get("op") != "knot_end" or ops[-1].get("knot") != last_name:
			ops.append({"op": "knot_end", "knot": last_name})

## Compiles lines[a:b] which all have indent >= base.
func _block(lines: Array, a: int, b: int, base: int, knot: String) -> void:
	var i := a
	while i < b:
		var l: Ln = lines[i]
		if l.indent != base:
			errors.append("%s: unexpected indentation" % l.src)
			i += 1
			continue
		var t := l.text
		if t.begins_with("* ") or t.begins_with("+ ") or t == "*" or t == "+":
			i = _choices(lines, i, b, base, knot)
		elif t.begins_with("if ") and t.ends_with(":"):
			i = _if_chain(lines, i, b, base, knot)
		elif t.begins_with("elif ") or t == "else:":
			errors.append("%s: elif/else without if" % l.src)
			i = _skip_children(lines, i + 1, b, base)
		else:
			_simple(l, knot)
			i += 1
			var j := _skip_children(lines, i, b, base)
			if j != i:
				errors.append("%s: indented lines under a plain statement" % l.src)
			i = j

func _skip_children(lines: Array, i: int, b: int, base: int) -> int:
	while i < b and lines[i].indent > base:
		i += 1
	return i

func _if_chain(lines: Array, i: int, b: int, base: int, knot: String) -> int:
	var end_jumps: Array = []
	var pending_jmpf := -1
	while i < b:
		var l: Ln = lines[i]
		if l.indent != base:
			break
		var t := l.text
		var cond := ""
		var is_else := false
		if t.begins_with("if ") and t.ends_with(":") and pending_jmpf == -1 and end_jumps.is_empty():
			cond = t.substr(3, t.length() - 4).strip_edges()
		elif t.begins_with("elif ") and t.ends_with(":") and (pending_jmpf != -1):
			cond = t.substr(5, t.length() - 6).strip_edges()
		elif t == "else:" and pending_jmpf != -1:
			is_else = true
		else:
			break
		if pending_jmpf != -1:
			end_jumps.append(ops.size())
			ops.append({"op": "jmp", "to": -1})
			ops[pending_jmpf]["to"] = ops.size()
			pending_jmpf = -1
		if not is_else:
			pending_jmpf = ops.size()
			ops.append({"op": "jmpf", "cond": cond, "to": -1, "src": l.src})
		var body_start := i + 1
		var body_end := _skip_children(lines, body_start, b, base)
		if body_end == body_start:
			errors.append("%s: empty block" % l.src)
		else:
			_block(lines, body_start, body_end, lines[body_start].indent, knot)
		i = body_end
		if is_else:
			break
	if pending_jmpf != -1:
		ops[pending_jmpf]["to"] = ops.size()
	for j in end_jumps:
		ops[j]["to"] = ops.size()
	return i

func _choices(lines: Array, i: int, b: int, base: int, knot: String) -> int:
	var choice_op := {"op": "choice", "options": [], "src": lines[i].src}
	var choice_index := ops.size()
	ops.append(choice_op)
	var gather_jumps: Array = []
	while i < b:
		var l: Ln = lines[i]
		if l.indent != base:
			break
		var t := l.text
		if not (t.begins_with("* ") or t.begins_with("+ ")):
			break
		var sticky := t.begins_with("+")
		var rest := t.substr(2).strip_edges()
		var tags: Array = []
		var cond := ""
		# tags like [look] [spot:coat]
		while rest.begins_with("["):
			var close := rest.find("]")
			if close == -1:
				break
			tags.append(rest.substr(1, close - 1).strip_edges())
			rest = rest.substr(close + 1).strip_edges()
		if rest.begins_with("{"):
			var depth := 0
			var k := 0
			while k < rest.length():
				var ch := rest[k]
				if ch == "{":
					depth += 1
				elif ch == "}":
					depth -= 1
					if depth == 0:
						break
				k += 1
			cond = rest.substr(1, k - 1).strip_edges()
			rest = rest.substr(k + 1).strip_edges()
		var inline_divert := ""
		var arrow := rest.rfind(" -> ")
		if arrow != -1:
			inline_divert = rest.substr(arrow + 4).strip_edges()
			rest = rest.substr(0, arrow).strip_edges()
		elif rest.begins_with("-> "):
			inline_divert = rest.substr(3).strip_edges()
			rest = ""
		var speech := false
		if rest.length() >= 2 and rest.begins_with("\"") and rest.ends_with("\""):
			speech = true
			rest = rest.substr(1, rest.length() - 2)
		_choice_counter[knot] = int(_choice_counter.get(knot, 0)) + 1
		var opt := {
			"text": rest, "tags": tags, "cond": cond, "sticky": sticky, "speech": speech,
			"id": "%s#%d" % [knot, _choice_counter[knot]], "to": -1, "src": l.src,
		}
		choice_op["options"].append(opt)
		opt["to"] = ops.size()
		var body_start := i + 1
		var body_end := _skip_children(lines, body_start, b, base)
		if body_end > body_start:
			_block(lines, body_start, body_end, lines[body_start].indent, knot)
		if inline_divert != "":
			_emit_divert(inline_divert, l.src)
		else:
			gather_jumps.append(ops.size())
			ops.append({"op": "jmp", "to": -1})
		i = body_end
	for j in gather_jumps:
		ops[j]["to"] = ops.size()
	choice_op["gather"] = ops.size()
	return i

func _emit_divert(target: String, src: String) -> void:
	if target == "END":
		ops.append({"op": "end", "src": src})
	else:
		_divert_fixups.append([ops.size(), target, src])
		ops.append({"op": "jmp", "to": -1, "target": target, "src": src})

func _simple(l: Ln, _knot: String) -> void:
	var t := l.text
	if t.begins_with("->> "):
		var target := t.substr(4).strip_edges()
		_divert_fixups.append([ops.size(), target, l.src])
		ops.append({"op": "call", "to": -1, "target": target, "src": l.src})
	elif t.begins_with("-> "):
		_emit_divert(t.substr(3).strip_edges(), l.src)
	elif t == "return":
		ops.append({"op": "ret", "src": l.src})
	elif t.begins_with("~ "):
		var body := t.substr(2).strip_edges()
		var m := RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_]*)\\s*(\\+=|-=|=)\\s*(.+)$").search(body)
		if m == null:
			errors.append("%s: bad assignment '%s'" % [l.src, body])
			return
		ops.append({"op": "set", "var": m.get_string(1), "oper": m.get_string(2), "expr": m.get_string(3), "src": l.src})
	elif t.begins_with("@"):
		var parts := _split_args(t.substr(1))
		if parts.is_empty():
			errors.append("%s: empty command" % l.src)
			return
		var name: String = parts[0]
		parts.remove_at(0)
		ops.append({"op": "cmd", "name": name, "args": parts, "src": l.src})
	else:
		var m := _speaker_re.search(t)
		if m != null and m.get_string(1).length() <= 14:
			var who := m.get_string(1).strip_edges()
			var mark := m.get_string(2)
			var body := m.get_string(3)
			if mark == ">":
				ops.append({"op": "line", "speaker": who, "text": body, "kind": "sms", "src": l.src})
			elif who == "SOUND":
				ops.append({"op": "line", "speaker": "", "text": body, "kind": "sound", "src": l.src})
			elif who == "THINK":
				ops.append({"op": "line", "speaker": "", "text": body, "kind": "think", "src": l.src})
			else:
				ops.append({"op": "line", "speaker": who, "text": body, "kind": "say", "src": l.src})
		else:
			ops.append({"op": "line", "speaker": "", "text": t, "kind": "narr", "src": l.src})

func _split_args(s: String) -> Array:
	var out: Array = []
	var cur := ""
	var in_q := false
	var had := false
	for ch in s:
		if ch == "\"":
			in_q = not in_q
			had = true
		elif ch == " " and not in_q:
			if had or cur != "":
				out.append(cur)
			cur = ""
			had = false
		else:
			cur += ch
	if had or cur != "":
		out.append(cur)
	return out

func _resolve() -> void:
	for fx in _divert_fixups:
		var idx: int = fx[0]
		var target: String = fx[1]
		if labels.has(target):
			ops[idx]["to"] = labels[target]
		else:
			errors.append("%s: unknown knot '%s'" % [fx[2], target])
	knot_starts.sort_custom(func(a, b): return a[0] < b[0])

## Returns [knot_name, offset] for a pc.
func locate(pc: int) -> Array:
	var best: Array = ["", 0]
	for ks in knot_starts:
		if ks[0] <= pc:
			best = [ks[1], pc - ks[0]]
		else:
			break
	return best

func hash_text() -> int:
	return str(ops).hash()
