class_name StoryExpr
extends RefCounted
## A small, forgiving expression language for the story script.
## Unset variables are null. `and`/`or`/`not` use truthiness. `==` between
## different types is simply false. Comparisons treat null as 0.
##
## Grammar: or > and > not > comparison > additive > multiplicative > unary > call/primary
## Functions: clock(minutes) -> "HH:MM", int(x), str(x), min(a,b), max(a,b), has(list_string, item)

var toks: Array = []
var pos := 0
var error := ""

static func compile(src: String) -> Array:
	var p := StoryExpr.new()
	p.toks = p._tokenize(src)
	if p.error != "":
		return ["err", p.error]
	var ast = p._or()
	if p.error == "" and p.pos < p.toks.size():
		p.error = "unexpected '%s'" % str(p.toks[p.pos][1])
	if p.error != "":
		return ["err", p.error]
	return ast

static func identifiers(ast) -> Array:
	var out: Array = []
	_collect(ast, out)
	return out

static func _collect(ast, out: Array) -> void:
	if not (ast is Array) or ast.is_empty():
		return
	if ast[0] == "var":
		if not out.has(ast[1]):
			out.append(ast[1])
		return
	for i in range(1, ast.size()):
		if ast[i] is Array:
			if ast[0] == "call" and i == 2:
				for a in ast[i]:
					_collect(a, out)
			else:
				_collect(ast[i], out)

static func truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	if v is Array or v is Dictionary:
		return not v.is_empty()
	return true

static func eval(ast, vars: Dictionary):
	match ast[0]:
		"lit":
			return ast[1]
		"var":
			return vars.get(ast[1], null)
		"not":
			return not truthy(eval(ast[1], vars))
		"neg":
			return -_num(eval(ast[1], vars))
		"and":
			var l = eval(ast[1], vars)
			if not truthy(l):
				return false
			return truthy(eval(ast[2], vars))
		"or":
			var l2 = eval(ast[1], vars)
			if truthy(l2):
				return true
			return truthy(eval(ast[2], vars))
		"bin":
			return _bin(ast[1], eval(ast[2], vars), eval(ast[3], vars))
		"call":
			var args: Array = []
			for a in ast[2]:
				args.append(eval(a, vars))
			return _call(ast[1], args)
		"err":
			return null
	return null

static func _num(v) -> float:
	if v == null:
		return 0.0
	if v is bool:
		return 1.0 if v else 0.0
	if v is int or v is float:
		return v
	if v is String and v.is_valid_float():
		return v.to_float()
	return 0.0

static func _same_kind(a, b) -> bool:
	var na := a is int or a is float
	var nb := b is int or b is float
	if na and nb:
		return true
	return typeof(a) == typeof(b)

static func _bin(op: String, a, b):
	match op:
		"==":
			if a == null or b == null:
				return a == null and b == null
			if not _same_kind(a, b):
				return false
			return a == b
		"!=":
			if a == null or b == null:
				return not (a == null and b == null)
			if not _same_kind(a, b):
				return true
			return a != b
		"<":
			return _num(a) < _num(b)
		">":
			return _num(a) > _num(b)
		"<=":
			return _num(a) <= _num(b)
		">=":
			return _num(a) >= _num(b)
		"+":
			if a is String or b is String:
				return str(a if a != null else "") + str(b if b != null else "")
			var r := _num(a) + _num(b)
			return int(r) if (a is int or a == null) and (b is int or b == null) else r
		"-":
			var r2 := _num(a) - _num(b)
			return int(r2) if (a is int or a == null) and (b is int or b == null) else r2
		"*":
			var r3 := _num(a) * _num(b)
			return int(r3) if (a is int or a == null) and (b is int or b == null) else r3
		"/":
			var d := _num(b)
			if d == 0.0:
				return 0
			if (a is int or a == null) and b is int:
				return int(_num(a)) / int(d)
			return _num(a) / d
		"%":
			var m := int(_num(b))
			if m == 0:
				return 0
			return posmod(int(_num(a)), m)
	return null

static func _call(name: String, args: Array):
	match name:
		"clock":
			var m := posmod(int(_num(args[0] if args.size() > 0 else 0)), 1440)
			return "%02d:%02d" % [m / 60, m % 60]
		"int":
			return int(_num(args[0])) if args.size() > 0 else 0
		"str":
			return str(args[0]) if args.size() > 0 and args[0] != null else ""
		"min":
			return min(_num(args[0]), _num(args[1]))
		"max":
			return max(_num(args[0]), _num(args[1]))
		"has":
			if args.size() < 2 or args[0] == null:
				return false
			return str(args[1]) in str(args[0]).split(",")
	return null

# ------------------------------------------------------------------ parser

func _tokenize(s: String) -> Array:
	var out: Array = []
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if c == "\"" or c == "'":
			var j := s.find(c, i + 1)
			if j == -1:
				error = "unterminated string"
				return out
			out.append(["str", s.substr(i + 1, j - i - 1)])
			i = j + 1
			continue
		if c.is_valid_int():
			var j2 := i
			while j2 < s.length() and (s[j2].is_valid_int() or s[j2] == "."):
				j2 += 1
			var numtxt := s.substr(i, j2 - i)
			out.append(["num", numtxt.to_float() if numtxt.contains(".") else numtxt.to_int()])
			i = j2
			continue
		if c == "_" or (c.to_lower() != c.to_upper()):
			var j3 := i
			while j3 < s.length() and (s[j3] == "_" or s[j3].is_valid_int() or s[j3].to_lower() != s[j3].to_upper()):
				j3 += 1
			var word := s.substr(i, j3 - i)
			match word:
				"and", "or", "not":
					out.append(["op", word])
				"true":
					out.append(["lit", true])
				"false":
					out.append(["lit", false])
				"null":
					out.append(["lit", null])
				_:
					out.append(["id", word])
			i = j3
			continue
		var two := s.substr(i, 2)
		if two in ["==", "!=", "<=", ">="]:
			out.append(["op", two])
			i += 2
			continue
		if c in ["<", ">", "+", "-", "*", "/", "%", "(", ")", ","]:
			out.append(["op", c])
			i += 1
			continue
		error = "unexpected character '%s'" % c
		return out
	return out

func _peek(v: String) -> bool:
	return pos < toks.size() and toks[pos][0] == "op" and toks[pos][1] == v

func _take(v: String) -> bool:
	if _peek(v):
		pos += 1
		return true
	return false

func _or() -> Array:
	var l := _and()
	while error == "" and _take("or"):
		l = ["or", l, _and()]
	return l

func _and() -> Array:
	var l := _not()
	while error == "" and _take("and"):
		l = ["and", l, _not()]
	return l

func _not() -> Array:
	if _take("not"):
		return ["not", _not()]
	return _cmp()

func _cmp() -> Array:
	var l := _add()
	while error == "":
		var matched := false
		for op in ["==", "!=", "<=", ">=", "<", ">"]:
			if _take(op):
				l = ["bin", op, l, _add()]
				matched = true
				break
		if not matched:
			break
	return l

func _add() -> Array:
	var l := _mul()
	while error == "":
		if _take("+"):
			l = ["bin", "+", l, _mul()]
		elif _take("-"):
			l = ["bin", "-", l, _mul()]
		else:
			break
	return l

func _mul() -> Array:
	var l := _unary()
	while error == "":
		if _take("*"):
			l = ["bin", "*", l, _unary()]
		elif _take("/"):
			l = ["bin", "/", l, _unary()]
		elif _take("%"):
			l = ["bin", "%", l, _unary()]
		else:
			break
	return l

func _unary() -> Array:
	if _take("-"):
		return ["neg", _unary()]
	return _primary()

func _primary() -> Array:
	if pos >= toks.size():
		error = "unexpected end"
		return ["lit", null]
	var t: Array = toks[pos]
	pos += 1
	match t[0]:
		"num":
			return ["lit", t[1]]
		"str":
			return ["lit", t[1]]
		"lit":
			return ["lit", t[1]]
		"id":
			if _take("("):
				var args: Array = []
				if not _take(")"):
					args.append(_or())
					while _take(","):
						args.append(_or())
					if not _take(")"):
						error = "missing ) after arguments"
				return ["call", t[1], args]
			return ["var", t[1]]
		"op":
			if t[1] == "(":
				var e := _or()
				if not _take(")"):
					error = "missing )"
				return e
	error = "unexpected '%s'" % str(t[1])
	return ["lit", null]
