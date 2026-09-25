class_name Figure
extends RefCounted
## People: for the sets, the archive photographs and the portraits.
##
## Bodies are lofted from elliptical rings and jointed at the shoulder, elbow,
## wrist, hip and knee; the head is a sculpted sphere (jaw, chin, brow, nose,
## the eye sockets) wearing a painted face. At the sets' resolution they
## should read like figures from an early 3D game: plain, but somebody.
##
## look (all optional):
##   coat, trousers, skin, hair, shoes (Color)
##   hair_style: short, curly, long, bun, bald, set, cap, none
##   height (m), build (width factor), shape ("m", "f", "n")
##   long_coat, robe, barefoot, glasses (bool); glasses_color; cap_color; cap_tilt
##   face (id: assets/tex/face_<id>_<expr>.png), expr
##   arms: down, forward, phone, phone_low, clasp, card, lap, sit
##   head_turn, head_tilt, head_roll (radians); lean (radians, forward +)
##   card (String): a numbered card held in front of the chest
## pose: stand, sit, sit_low
##
## The figure faces +Z. The node is at the feet. Children: "torso", "head",
## "arm_l", "arm_r" (arm_r is on the +X side), "leg_l", "leg_r".

const SEGS := 10
static var smooth_faces := false
static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}

## The regulars. Sets pass these (with overrides) so everyone is the same
## person everywhere.
const CAST := {
	"jad": {"coat": Color("5c5e62"), "trousers": Color("2a2c34"), "skin": Color("aa7a5a"), "hair": Color("1a1614"),
		"hair_style": "curly", "height": 1.78, "shape": "m", "face": "jad"},
	"inez": {"coat": Color("3a4a5a"), "trousers": Color("3a4a5a"), "skin": Color("c8a088"), "hair": Color("b8b4ac"),
		"hair_style": "short", "height": 1.62, "shape": "f", "face": "inez"},
	"dima": {"coat": Color("7a6a8a"), "trousers": Color("3a3a4a"), "skin": Color("d8b8a8"), "hair": Color("5a3a2a"),
		"hair_style": "bun", "height": 1.68, "shape": "f", "face": "dima"},
	"sal": {"coat": Color("3e5a4e"), "trousers": Color("26262c"), "skin": Color("c89878"), "hair": Color("2a2420"),
		"hair_style": "short", "glasses": true, "height": 1.7, "shape": "n", "face": "sal"},
	"teodor": {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"),
		"hair_style": "bald", "height": 1.84, "long_coat": true, "shape": "m", "face": "teodor"},
	"kaye": {"coat": Color("9ab0d0"), "trousers": Color("5a5a6a"), "skin": Color("e0c0a8"), "hair": Color("d8d4cc"),
		"hair_style": "set", "height": 1.55, "glasses": true, "shape": "f", "face": "kaye"},
	"nell": {"coat": Color("6a3a4a"), "trousers": Color("2a2a3a"), "skin": Color("6a4636"), "hair": Color("1a1412"),
		"hair_style": "bun", "height": 1.64, "shape": "f", "face": "nell"},
	"june": {"coat": Color("7a6a8a"), "trousers": Color("4a4a4a"), "skin": Color("d8b8a8"), "hair": Color("b8a890"),
		"hair_style": "set", "height": 1.6, "shape": "f", "face": "june"},
	"adeyemi": {"coat": Color("4a4a50"), "trousers": Color("2a2a30"), "skin": Color("5a3a2a"), "hair": Color("1a1412"),
		"hair_style": "short", "height": 1.74, "build": 1.08, "shape": "m", "face": "adeyemi"},
}

## Sets that describe somebody by colour alone still get the right face.
static func identify(look: Dictionary) -> Dictionary:
	if look.has("face"):
		return look
	for id in CAST:
		var c: Dictionary = CAST[id]
		if c["skin"] == look.get("skin") and c["hair"] == look.get("hair"):
			var d := look.duplicate()
			d["face"] = c["face"]
			if not d.has("shape"):
				d["shape"] = c["shape"]
			return d
	return look

static func cast(id: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = CAST.get(id, {}).duplicate()
	d.merge(extra, true)
	return d

# ------------------------------------------------------------------ meshes

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)

## A tube through rings, running up the Y axis. Each ring is
## [y, rx, rz] or [y, rx, rz, offset_x, offset_z].
static func loft(rings: Array, segs: int = SEGS, cap_bottom: bool = true, cap_top: bool = true) -> ArrayMesh:
	var key := "loft|%s|%d|%s|%s" % [str(rings), segs, cap_bottom, cap_top]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for r in rings:
		var ring: Array = []
		var ox: float = r[3] if r.size() > 3 else 0.0
		var oz: float = r[4] if r.size() > 4 else 0.0
		var fold: float = r[5] if r.size() > 5 else 0.0
		var nf: float = r[6] if r.size() > 6 else 7.0
		for i in segs:
			var a := TAU * i / segs
			var fm := 1.0 + fold * sin(a * nf)
			ring.append(Vector3(ox + cos(a) * r[1] * fm, r[0], oz + sin(a) * r[2] * fm))
		pts.append(ring)
	var up: bool = rings[-1][0] > rings[0][0]
	for j in range(pts.size() - 1):
		var A: Array = pts[j]
		var B: Array = pts[j + 1]
		for i in segs:
			var i2 := (i + 1) % segs
			if up:
				_tri(st, A[i], B[i2], B[i])
				_tri(st, A[i], A[i2], B[i2])
			else:
				_tri(st, A[i], B[i], B[i2])
				_tri(st, A[i], B[i2], A[i2])
	var lo: Array = pts[0] if up else pts[-1]
	var hi: Array = pts[-1] if up else pts[0]
	var lo_r: Array = rings[0] if up else rings[-1]
	var hi_r: Array = rings[-1] if up else rings[0]
	if cap_bottom:
		var c := Vector3(lo_r[3] if lo_r.size() > 3 else 0.0, lo_r[0], lo_r[4] if lo_r.size() > 4 else 0.0)
		for i in segs:
			_tri(st, c, lo[(i + 1) % segs], lo[i])
	if cap_top:
		var c2 := Vector3(hi_r[3] if hi_r.size() > 3 else 0.0, hi_r[0], hi_r[4] if hi_r.size() > 4 else 0.0)
		for i in segs:
			_tri(st, c2, hi[i], hi[(i + 1) % segs])
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m

## Like loft, but only over the arc a0..a1 (radians, 0 = +X, PI/2 = +Z), open,
## so it needs a two-sided material: cloaks, veils, a cape's back.
static func arc_loft(rings: Array, a0: float, a1: float, segs: int = 12) -> ArrayMesh:
	var key := "arc|%s|%s|%s|%d" % [str(rings), a0, a1, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for r in rings:
		var ring: Array = []
		var fold: float = r[5] if r.size() > 5 else 0.0
		var nf: float = r[6] if r.size() > 6 else 7.0
		for i in range(segs + 1):
			var a := lerpf(a0, a1, float(i) / segs)
			var fm := 1.0 + fold * sin(a * nf)
			ring.append(Vector3((r[3] if r.size() > 3 else 0.0) + cos(a) * r[1] * fm, r[0], (r[4] if r.size() > 4 else 0.0) + sin(a) * r[2] * fm))
		pts.append(ring)
	for j in range(pts.size() - 1):
		for i in segs:
			_tri(st, pts[j][i], pts[j + 1][i + 1], pts[j + 1][i])
			_tri(st, pts[j][i], pts[j][i + 1], pts[j + 1][i + 1])
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m

static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3 = Vector3.ZERO, name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi

static func _pivot(parent: Node3D, pos: Vector3, name: String = "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if name != "":
		n.name = name
	parent.add_child(n)
	return n

# ------------------------------------------------------------------ the head

const HEAD_R := Vector3(0.079, 0.115, 0.098)

static func _ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Where a unit direction on the skull ends up once it has a face.
static func _sculpt(d: Vector3, nose: float, jaw: float) -> Vector3:
	var p := Vector3(d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z)
	# the jaw: square at the angle, narrowing only at the chin
	var s := _ss(-0.62, -0.98, d.y)
	p.x *= (1.0 - 0.18 * s * (2.0 - jaw)) * (1.0 + 0.06 * exp(-pow((d.y + 0.5) / 0.16, 2.0)) * jaw)
	if d.z > 0.0:
		p.z += 0.012 * s * d.z
	else:
		p.z *= 1.0 - 0.22 * s
	# the back of the skull is fuller than the front
	if d.z < 0.0 and d.y > -0.1:
		p.z *= 1.0 + 0.07 * _ss(-0.1, 0.5, d.y)
	if d.z > 0.3:
		var f := _ss(0.3, 0.9, d.z)
		p.z *= 1.0 - 0.05 * f
		# brow
		p.z += 0.007 * f * exp(-pow((d.y - 0.2) / 0.08, 2.0))
		# the eyes sit back under it
		p.z -= 0.008 * f * exp(-pow((d.y - 0.065) / 0.08, 2.0)) * exp(-pow((absf(d.x) - 0.4) / 0.13, 2.0))
		# cheekbones
		p.x *= 1.0 + 0.04 * exp(-pow((d.y + 0.04) / 0.14, 2.0))
		# the nose, a ridge that grows toward its tip
		var ridge := exp(-pow(d.x / (0.11 + 0.03 * nose), 2.0))
		var prof := _ss(0.12, -0.3, d.y) * (1.0 - _ss(-0.31, -0.42, d.y))
		p.z += 0.024 * nose * ridge * prof * f
		# lips
		p.z += 0.004 * exp(-pow((d.y + 0.555) / 0.06, 2.0)) * exp(-pow(d.x / 0.3, 2.0)) * f
	return p

static func _head_uv(p: Vector3) -> Vector2:
	var v := 0.5 - p.y / (2.0 * 0.125)
	if p.z < -0.012:
		return Vector2(0.015 if p.x < 0.0 else 0.985, v)
	return Vector2(clampf(0.5 + p.x / (2.0 * 0.086), 0.0, 1.0), v)

static func head_mesh(nose: float = 1.0, jaw: float = 1.0) -> ArrayMesh:
	var key := "head|%s|%s" % [nose, jaw]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 14
	var segs := 18
	var grid: Array = []
	for j in range(rows + 1):
		var th := PI * (1.0 - float(j) / rows)
		var ring: Array = []
		for i in segs:
			var a := TAU * i / segs
			var d := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a))
			ring.append(_sculpt(d, nose, jaw))
		grid.append(ring)
	for j in range(rows):
		for i in segs:
			var i2 := (i + 1) % segs
			var a0: Vector3 = grid[j][i]
			var a1: Vector3 = grid[j][i2]
			var b0: Vector3 = grid[j + 1][i]
			var b1: Vector3 = grid[j + 1][i2]
			_tri_uv(st, a0, b1, b0, _head_uv(a0), _head_uv(b1), _head_uv(b0))
			_tri_uv(st, a0, a1, b1, _head_uv(a0), _head_uv(a1), _head_uv(b1))
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m

## Hair as a shell over the skull, kept above a hairline that runs from the
## nape round the ears to the forehead.
static func hair_mesh(style: String) -> ArrayMesh:
	var key := "hair|" + style
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var back := -0.45
	var side := 0.05
	var front := 0.52
	var thick := 0.012
	var bumps := 0.0
	var band := false
	match style:
		"curly":
			back = -0.3
			side = 0.02
			front = 0.5
			thick = 0.022
			bumps = 0.006
		"long":
			back = -0.5
			side = -0.15
			front = 0.55
			thick = 0.014
		"bun":
			back = -0.35
			side = 0.08
			front = 0.56
			thick = 0.009
		"set":
			back = -0.2
			side = 0.1
			front = 0.46
			thick = 0.02
			bumps = 0.006
		"bald":
			band = true
			thick = 0.008
		"cap":
			back = -0.4
			side = 0.0
			front = 0.6
			thick = 0.008
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 14
	var segs := 18
	var grid: Array = []
	var keep: Array = []
	for j in range(rows + 1):
		var th := PI * (1.0 - float(j) / rows)
		var ring: Array = []
		var kr: Array = []
		for i in segs:
			var a := TAU * i / segs
			var d := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a))
			var f := d.z
			var hl := lerpf(back, side, _ss(-1.0, 0.0, f)) if f < 0.0 else lerpf(side, front, _ss(0.0, 1.0, f))
			var k := d.y > hl
			if band:
				k = d.y > -0.42 and d.y < 0.1 and f < 0.15
			var p := _sculpt(d, 1.0, 1.0)
			var taper := 1.0 if band else _ss(hl - 0.02, hl + 0.3, d.y)
			var out := 0.002 + thick * taper
			if bumps > 0.0:
				out += bumps * taper * (0.55 + 0.45 * sin(a * 5.0 + th * 4.0) * cos(a * 3.0 - th * 5.0))
			p += Vector3(d.x, d.y * 0.6, d.z).normalized() * out
			ring.append(p)
			kr.append(k)
		grid.append(ring)
		keep.append(kr)
	for j in range(rows):
		for i in segs:
			var i2 := (i + 1) % segs
			if keep[j][i] and keep[j][i2] and keep[j + 1][i] and keep[j + 1][i2]:
				_tri(st, grid[j][i], grid[j + 1][i2], grid[j + 1][i])
				_tri(st, grid[j][i], grid[j][i2], grid[j + 1][i2])
			elif keep[j + 1][i] and keep[j + 1][i2] and (keep[j][i] or keep[j][i2]):
				# ragged edge: one triangle of the quad
				if keep[j][i]:
					_tri(st, grid[j][i], grid[j + 1][i2], grid[j + 1][i])
				else:
					_tri(st, grid[j][i2], grid[j + 1][i2], grid[j + 1][i])
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m

# ------------------------------------------------------------------ materials

static func _m(c: Color) -> StandardMaterial3D:
	return SetKit.mat(c)

static func face_mat(look: Dictionary) -> StandardMaterial3D:
	var skin: Color = look.get("skin", Color("c8a58a"))
	var id: String = look.get("face", "")
	var expr: String = look.get("expr", "neutral")
	var path := ""
	var modulate := false
	if id != "":
		path = "res://assets/tex/face_%s_%s.png" % [id, expr]
		if not ResourceLoader.exists(path):
			path = "res://assets/tex/face_%s_neutral.png" % id
	if path == "" or not ResourceLoader.exists(path):
		var g := "f" if look.get("shape", "m") == "f" else "m"
		path = "res://assets/tex/face_gen_%s_%s.png" % [g, expr]
		if not ResourceLoader.exists(path):
			path = "res://assets/tex/face_gen_%s_neutral.png" % g
		modulate = true
	var key := "%s|%s|%s" % [path, skin if modulate else Color.WHITE, smooth_faces]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth_faces else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.albedo_color = skin if modulate else Color.WHITE
	else:
		m.albedo_color = skin
	_mat_cache[key] = m
	return m

# ------------------------------------------------------------------ the body

static func build(parent: Node3D, pos: Vector3, rot_y: float, look_in: Dictionary, pose: String = "stand") -> Node3D:
	var look := identify(look_in)
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = rot_y
	parent.add_child(p)
	var h: float = look.get("height", 1.72)
	var b: float = look.get("build", 1.0)
	var k := h / 1.72
	var hk := lerpf(1.0, k, 0.5)
	var shape: String = look.get("shape", "m")
	var skin := _m(look.get("skin", Color("c8a58a")))
	var robe: bool = look.get("robe", false)
	var coat := _m(look.get("coat", Color("4a4a52")))
	var trou := _m(look.get("trousers", Color("2b2b33")))
	var hair := _m(look.get("hair", Color("2a2220")))
	var shoes := _m(look.get("shoes", Color("1e1c1c")))
	var barefoot: bool = look.get("barefoot", robe)
	var sit := pose.begins_with("sit")
	var low := pose == "sit_low"
	var hip_y := (0.83 * k + 0.07) if not sit else (0.5 if not low else 0.3)
	var pelvis := _pivot(p, Vector3(0, hip_y, 0), "pelvis")
	pelvis.rotation.x = float(look.get("lean", 0.0)) + (-0.06 if sit else 0.0)
	# --- torso
	var tr: Array
	match shape:
		"f":
			tr = [[-0.09, .16, .11], [0.0, .178, .115], [.12, .15, .1], [.24, .14, .096], [.34, .163, .118], [.42, .17, .106], [.47, .158, .088], [.51, .112, .07], [.54, .062, .054]]
		"n":
			tr = [[-0.09, .155, .105], [0.0, .172, .112], [.12, .155, .102], [.24, .152, .102], [.35, .175, .118], [.43, .182, .108], [.48, .17, .09], [.52, .12, .072], [.55, .066, .056]]
		_:
			tr = [[-0.09, .15, .105], [0.0, .168, .11], [.12, .16, .104], [.24, .165, .108], [.36, .186, .12], [.44, .196, .11], [.49, .184, .092], [.53, .128, .074], [.56, .07, .058]]
	var rings: Array = []
	for r in tr:
		rings.append([r[0] * k, r[1] * b, r[2] * lerpf(1.0, b, 0.6)])
	_mi(pelvis, loft(rings, 12), coat, Vector3.ZERO, "torso")
	var top_y: float = tr[-1][0] * k
	var shoulder_y: float = tr[-4][0] * k
	var shoulder_x: float = tr[-4][1] * b - 0.012
	# skirts: a long coat or a robe, standing
	if (look.get("long_coat", false) or robe) and not sit:
		var bottom := -0.46 * k if not robe else -0.62 * k
		var fl := 1.0 if not robe else 1.12
		_mi(pelvis, loft([[bottom, .225 * b * fl, .165 * fl], [-0.2 * k, .2 * b, .14], [0.06 * k, .172 * b, .116]], 12, true, false), coat)
	elif robe and sit:
		_mi(pelvis, loft([[-0.12, .2 * b, .13], [0.06 * k, .172 * b, .116]], 12, true, false), coat)
	if robe:
		# the tie, and a wrap of towelling at the neck
		_mi(pelvis, loft([[0.1 * k, .158 * b, .108], [0.14 * k, .158 * b, .108]], 12), _m(Color(look.get("coat", Color.WHITE)).darkened(0.12)))
		_mi(pelvis, loft([[top_y - 0.06, .1, .075], [top_y + 0.01, .085, .065]], 10), coat)
	else:
		# a collar
		_mi(pelvis, loft([[top_y - 0.03, .076, .066], [top_y + 0.035, .064, .058]], 10, false, false), _m(Color(look.get("coat", Color("4a4a52"))).darkened(0.15)))
	# --- neck and head
	_mi(pelvis, loft([[top_y - 0.03, .056, .054, 0, 0.004], [top_y + 0.06, .05, .05, 0, 0.01]], 8), skin)
	var head := _pivot(pelvis, Vector3(0, top_y + 0.045 + 0.1 * hk, 0.016), "head")
	head.scale = Vector3.ONE * hk
	var roll := float(look.get("head_roll", -0.12 if look.get("arms", "") == "phone" else 0.0))
	head.rotation = Vector3(float(look.get("head_tilt", 0.0)), float(look.get("head_turn", 0.0)), roll)
	_mi(head, head_mesh(float(look.get("nose", 1.0)), float(look.get("jaw", 1.0))), face_mat(look), Vector3.ZERO, "face")
	for s in [-1, 1]:
		var ear := SetKit.sphere(head, 0.02, Vector3(s * 0.077, -0.005, -0.004), skin, 5, Vector3(0.45, 1.25, 0.9))
		ear.name = "ear"
	var hs: String = look.get("hair_style", "short")
	if hs != "none":
		_mi(head, hair_mesh(hs), hair, Vector3.ZERO, "hair")
	match hs:
		"bun":
			SetKit.sphere(head, 0.042, Vector3(0, 0.085, -0.092), hair, 7)
		"long":
			_mi(head, loft([[-0.3, .09, .04, 0, -0.06], [-0.12, .088, .05, 0, -0.07], [0.02, .086, .06, 0, -0.05]], 10), hair)
		"cap":
			var capm := _m(look.get("cap_color", Color("1e2430")))
			var cap := _pivot(head, Vector3(0, 0.07, -0.004), "cap")
			cap.rotation.z = float(look.get("cap_tilt", 0.0))
			_mi(cap, loft([[0.0, .088, .104], [0.05, .1, .116], [0.07, .098, .114]], 14), capm)
			var peak := SetKit.box(cap, Vector3(0.15, 0.012, 0.07), Vector3(0, 0.004, 0.125), _m(Color("141414")))
			peak.rotation.x = 0.28
			SetKit.box(cap, Vector3(0.03, 0.03, 0.006), Vector3(0, 0.035, 0.117), _m(Color("b8964a")))
	if look.get("glasses", false):
		var gm := _m(look.get("glasses_color", Color("1a1a1a")))
		for s in [-1, 1]:
			var x: float = s * 0.031
			SetKit.box(head, Vector3(0.046, 0.005, 0.005), Vector3(x, 0.031, 0.101), gm)
			SetKit.box(head, Vector3(0.046, 0.005, 0.005), Vector3(x, 0.0, 0.099), gm)
			SetKit.box(head, Vector3(0.005, 0.036, 0.005), Vector3(x + s * 0.023, 0.0155, 0.098), gm)
			SetKit.box(head, Vector3(0.005, 0.036, 0.005), Vector3(x - s * 0.023, 0.0155, 0.101), gm)
			SetKit.box(head, Vector3(0.022, 0.005, 0.005), Vector3(s * 0.064, 0.03, 0.094), gm)
			SetKit.box(head, Vector3(0.005, 0.005, 0.11), Vector3(s * 0.077, 0.03, 0.038), gm)
		SetKit.box(head, Vector3(0.018, 0.005, 0.005), Vector3(0, 0.024, 0.104), gm)
	# --- arms
	var arm_pose: String = look.get("arms", "down" if not sit else "sit")
	for s in [-1, 1]:
		var sh := _pivot(pelvis, Vector3(s * shoulder_x, shoulder_y - 0.02, 0), "arm_r" if s == 1 else "arm_l")
		_mi(sh, loft([[-0.29 * k, .038, .04], [-0.14 * k, .043, .046], [-0.02, .048, .05], [0.03, .036, .04], [0.05, .012, .014]], 8), coat)
		var el := _pivot(sh, Vector3(0, -0.29 * k, 0), "elbow")
		var cuff := 0.036 if not robe else 0.046
		_mi(el, loft([[-0.25 * k, cuff, cuff], [-0.12 * k, .037, .038], [0.0, .04, .042]], 8), coat)
		var wr := _pivot(el, Vector3(0, -0.25 * k, 0), "wrist")
		_mi(wr, loft([[-0.17 * hk, .012, .018], [-0.12 * hk, .016, .036], [-0.05 * hk, .02, .042], [0.0, .018, .03]], 8), skin, Vector3.ZERO, "hand")
		var q := _arm_pose(arm_pose, s, sit)
		sh.rotation = q[0]
		el.rotation = q[1]
		wr.rotation = q[2]
	if str(look.get("card", "")) != "":
		_card(pelvis, str(look["card"]), Vector3(0, shoulder_y - 0.22 * k, 0.3 * k))
	# --- legs
	var leg_m := coat if robe else trou
	for s in [-1, 1]:
		var hipj := _pivot(pelvis, Vector3(s * 0.088 * b, -0.02, 0), "leg_r" if s == 1 else "leg_l")
		_mi(hipj, loft([[-0.43 * k, .052, .056], [-0.2 * k, .074, .08], [0.02, .086, .09]], 9), leg_m)
		var knee := _pivot(hipj, Vector3(0, -0.43 * k, 0), "knee")
		var shin_m := skin if robe else trou
		_mi(knee, loft([[-0.4 * k, .034, .038], [-0.12 * k, .056, .064], [0.0, .052, .056]], 9), shin_m)
		var ank := _pivot(knee, Vector3(0, -0.4 * k, 0), "ankle")
		var fm := skin if barefoot else shoes
		var foot := SetKit.box(ank, Vector3(0.09, 0.06 if barefoot else 0.075, 0.24), Vector3(0, -0.035, 0.06), fm)
		foot.name = "foot"
		if sit:
			var up := -1.45 if not low else -1.95
			hipj.rotation = Vector3(up, s * 0.08, 0)
			knee.rotation.x = -up + (0.0 if not low else 0.25)
			ank.rotation.x = 0.0
		else:
			hipj.rotation.z = s * 0.02
	return p

## Shoulder, elbow and wrist angles for each arm pose. s is +1 on the +X side.
static func _arm_pose(pose: String, s: int, sit: bool) -> Array:
	var sh := Vector3(0.04, 0, s * 0.05)
	var el := Vector3(-0.18, 0, 0)
	var wr := Vector3.ZERO
	match pose:
		"forward":
			sh = Vector3(-0.95, 0, s * 0.06)
			el = Vector3(-0.55, 0, 0)
		"phone":
			# elbow down and forward, forearm folded up to the side of the face
			if s == 1:
				sh = Vector3(-0.97, 0, 0.25)
				el = Vector3(-2.67, -0.2, 0)
				wr = Vector3(0.2, 0, 0)
		"phone_low":
			if s == 1:
				sh = Vector3(-0.35, 0, 0.12)
				el = Vector3(-1.45, 0, 0)
		"clasp":
			sh = Vector3(-0.2, 0, s * 0.04)
			el = Vector3(-1.15, -s * 0.62, 0)
			wr = Vector3(0, -s * 0.3, 0)
		"card":
			sh = Vector3(-0.32, 0, s * 0.03)
			el = Vector3(-1.75, -s * 0.5, 0)
		"lap":
			sh = Vector3(-0.3, 0, s * 0.03)
			el = Vector3(-1.15, -s * 0.55, 0)
		"sit":
			sh = Vector3(-0.35, 0, s * 0.06)
			el = Vector3(-0.75, 0, 0)
		"down":
			if sit:
				sh = Vector3(-0.35, 0, s * 0.06)
				el = Vector3(-0.75, 0, 0)
	return [sh, el, wr]

static func _card(parent: Node3D, text: String, pos: Vector3) -> void:
	var card := SetKit.box(parent, Vector3(0.2, 0.13, 0.004), pos, SetKit.mat(Color("ece8dc")))
	card.name = "card"
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.0011
	l.modulate = Color("141414")
	l.outline_size = 0
	l.position = pos + Vector3(0, 0, 0.004)
	l.shaded = true
	l.double_sided = false
	parent.add_child(l)
