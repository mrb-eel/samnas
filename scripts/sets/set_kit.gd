class_name SetKit
extends RefCounted
## Helpers for building rooms out of boxes, cylinders and flat people.
## Low polygon counts, nearest-filtered textures and a low render resolution
## make the rooms look like an early 3D render and not a modern one.

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var p := "res://assets/tex/%s.png" % name
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex_cache[name] = t
	return t

## Material from a texture name or a colour. uv = texture repeats per metre.
static func mat(what, uv: float = 1.0, unshaded: bool = false, emission: Color = Color.BLACK, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [str(what), uv, unshaded, emission, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	if what is Color:
		m.albedo_color = what
	else:
		var t := tex(str(what))
		if t:
			m.albedo_texture = t
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(uv, uv, uv)
		else:
			m.albedo_color = Color(0.6, 0.6, 0.6)
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	_mat_cache[key] = m
	return m

## A material with a texture mapped once over a quad (posters, photos, screens).
static func decal_mat(name: String, unshaded: bool = false, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "decal|%s|%s|%s" % [name, unshaded, tint]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, material: Material, segs: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func sphere(parent: Node3D, r: float, pos: Vector3, material: Material, segs: int = 8, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = max(3, segs / 2)
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi

## A flat quad facing +Z (rotate it yourself). Good for posters, windows, photos.
static func quad(parent: Node3D, w: float, h: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func omni(parent: Node3D, pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	parent.add_child(l)
	return l

static func spot(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, rng: float, angle: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	parent.add_child(l)
	l.look_at_from_position(pos, target, Vector3.UP if abs((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	return l

## Room shell: floor, ceiling and walls, with named walls left out so the
## camera can look in like a dollhouse. Walls: n (-z), s (+z), e (+x), w (-x).
static func room(parent: Node3D, w: float, d: float, h: float, floor_m: Material, wall_m: Material, ceil_m: Material, skip: Array = []) -> void:
	box(parent, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), floor_m)
	if not skip.has("ceil"):
		box(parent, Vector3(w, 0.1, d), Vector3(0, h + 0.05, 0), ceil_m)
	if not skip.has("n"):
		box(parent, Vector3(w, h, 0.1), Vector3(0, h / 2, -d / 2), wall_m)
	if not skip.has("s"):
		box(parent, Vector3(w, h, 0.1), Vector3(0, h / 2, d / 2), wall_m)
	if not skip.has("w"):
		box(parent, Vector3(0.1, h, d), Vector3(-w / 2, h / 2, 0), wall_m)
	if not skip.has("e"):
		box(parent, Vector3(0.1, h, d), Vector3(w / 2, h / 2, 0), wall_m)

static func chair(parent: Node3D, pos: Vector3, rot_y: float, seat_m: Material, leg_m: Material) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot_y
	parent.add_child(c)
	box(c, Vector3(0.46, 0.05, 0.44), Vector3(0, 0.45, 0), seat_m)
	box(c, Vector3(0.46, 0.42, 0.04), Vector3(0, 0.7, -0.21), seat_m)
	for x in [-0.2, 0.2]:
		for z in [-0.19, 0.19]:
			box(c, Vector3(0.03, 0.45, 0.03), Vector3(x, 0.225, z), leg_m)
	return c

## A low-poly person. Deliberately stiff. `look` is a dictionary:
## coat, trousers, skin, hair, hair_style ("short","long","bald","bun","cap","curly"),
## height (metres), build (0.8..1.2).
static func person(parent: Node3D, pos: Vector3, rot_y: float, look: Dictionary, pose: String = "stand") -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = rot_y
	parent.add_child(p)
	var h: float = look.get("height", 1.72)
	var b: float = look.get("build", 1.0)
	var k := h / 1.72
	var skin := mat(look.get("skin", Color("c8a58a")))
	var coat := mat(look.get("coat", Color("4a4a52")))
	var trou := mat(look.get("trousers", Color("2b2b33")))
	var hair := mat(look.get("hair", Color("2a2220")))
	var sit := pose == "sit"
	var leg_h := 0.82 * k
	if sit:
		# thighs forward, shins down
		box(p, Vector3(0.15 * b, 0.14, 0.46 * k), Vector3(-0.1 * b, 0.47, 0.2 * k), trou)
		box(p, Vector3(0.15 * b, 0.14, 0.46 * k), Vector3(0.1 * b, 0.47, 0.2 * k), trou)
		box(p, Vector3(0.13 * b, 0.45, 0.13), Vector3(-0.1 * b, 0.23, 0.42 * k), trou)
		box(p, Vector3(0.13 * b, 0.45, 0.13), Vector3(0.1 * b, 0.23, 0.42 * k), trou)
		leg_h = 0.47
	else:
		box(p, Vector3(0.15 * b, leg_h, 0.16), Vector3(-0.1 * b, leg_h / 2, 0), trou)
		box(p, Vector3(0.15 * b, leg_h, 0.16), Vector3(0.1 * b, leg_h / 2, 0), trou)
	var torso_h := 0.62 * k
	var torso := box(p, Vector3(0.42 * b, torso_h, 0.24 * b), Vector3(0, leg_h + torso_h / 2, 0), coat)
	torso.name = "torso"
	if look.get("long_coat", false) and not sit:
		box(p, Vector3(0.44 * b, 0.45 * k, 0.26 * b), Vector3(0, leg_h - 0.18 * k, 0), coat)
	# arms
	var arm_pose: String = look.get("arms", "down")
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.26 * b, leg_h + torso_h - 0.05, 0)
		p.add_child(arm)
		box(arm, Vector3(0.1 * b, 0.6 * k, 0.11), Vector3(0, -0.3 * k, 0), coat)
		sphere(arm, 0.05, Vector3(0, -0.62 * k, 0), skin, 5)
		if arm_pose == "phone" and side == 1:
			arm.rotation = Vector3(-0.3, 0, 2.6)
		elif arm_pose == "forward" or (arm_pose == "phone_low" and side == 1):
			arm.rotation.x = -1.1
		elif sit:
			arm.rotation.x = -0.5
		arm.name = "arm_%s" % ("r" if side == 1 else "l")
	# neck + head
	var neck_y := leg_h + torso_h
	box(p, Vector3(0.1, 0.08, 0.1), Vector3(0, neck_y + 0.04, 0), skin)
	var head := Node3D.new()
	head.name = "head"
	head.position = Vector3(0, neck_y + 0.18, 0)
	p.add_child(head)
	sphere(head, 0.12, Vector3.ZERO, skin, 7, Vector3(0.9, 1.1, 0.95))
	var hs: String = look.get("hair_style", "short")
	match hs:
		"short":
			sphere(head, 0.125, Vector3(0, 0.04, -0.015), hair, 7, Vector3(0.95, 0.85, 0.98))
		"curly":
			sphere(head, 0.14, Vector3(0, 0.06, -0.02), hair, 6, Vector3(1.0, 0.8, 1.0))
		"long":
			sphere(head, 0.13, Vector3(0, 0.04, -0.02), hair, 7, Vector3(1.0, 0.9, 1.0))
			box(head, Vector3(0.26, 0.34, 0.1), Vector3(0, -0.14, -0.07), hair)
		"bun":
			sphere(head, 0.125, Vector3(0, 0.04, -0.015), hair, 7, Vector3(0.95, 0.85, 0.98))
			sphere(head, 0.06, Vector3(0, 0.12, -0.09), hair, 6)
		"cap":
			cyl(head, 0.13, 0.13, 0.06, Vector3(0, 0.1, 0), hair, 10)
			box(head, Vector3(0.2, 0.015, 0.1), Vector3(0, 0.08, 0.12), hair)
		"bald":
			box(head, Vector3(0.23, 0.07, 0.12), Vector3(0, -0.01, -0.06), hair)
		"set":
			sphere(head, 0.14, Vector3(0, 0.05, -0.01), hair, 6, Vector3(1.05, 0.85, 1.0))
	if look.get("glasses", false):
		box(head, Vector3(0.2, 0.035, 0.02), Vector3(0, 0.02, 0.115), mat(look.get("glasses_color", Color("1a1a1a"))))
	return p

# ------------------------------------------------------------------ materials

static func emis(c: Color, strength: float = 1.0) -> StandardMaterial3D:
	var key := "emis|%s|%s" % [c, strength]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * strength, c.g * strength, c.b * strength, c.a)
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m

static func glass(c: Color, a: float) -> StandardMaterial3D:
	var key := "glass|%s|%s" % [c, a]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m

## A quad showing a whole image (docs, signs). w,h in metres.
static func picture(parent: Node3D, img_path: String, w: float, h: float, pos: Vector3, rot: Vector3 = Vector3.ZERO, unshaded: bool = false, blend: String = "") -> MeshInstance3D:
	var key := "pic|%s|%s|%s" % [img_path, unshaded, blend]
	var m: StandardMaterial3D
	if _mat_cache.has(key):
		m = _mat_cache[key]
	else:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		match blend:
			"scissor":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
			"alpha":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"add":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if ResourceLoader.exists(img_path):
			m.albedo_texture = load(img_path)
		else:
			m.albedo_color = Color(0.85, 0.82, 0.74)
		_mat_cache[key] = m
	return quad(parent, w, h, pos, m, rot)

static func tex_quad(parent: Node3D, tex_name: String, w: float, h: float, pos: Vector3, rot: Vector3 = Vector3.ZERO, unshaded: bool = false, blend: String = "") -> MeshInstance3D:
	return picture(parent, "res://assets/tex/%s.png" % tex_name, w, h, pos, rot, unshaded, blend)

# ------------------------------------------------------------------ light fittings

## A fluorescent tube: returns {"mesh": MeshInstance3D, "light": OmniLight3D}.
static func tube(parent: Node3D, pos: Vector3, length: float, col: Color = Color("e8f0e4"), energy: float = 1.4, rng: float = 7.0) -> Dictionary:
	var housing := box(parent, Vector3(length + 0.06, 0.05, 0.14), pos + Vector3(0, 0.03, 0), mat(Color("c8c6bc")))
	var glow := box(parent, Vector3(length, 0.035, 0.05), pos, emis(col, 1.1))
	var l := omni(parent, pos + Vector3(0, -0.2, 0), col, energy, rng)
	return {"mesh": glow, "housing": housing, "light": l}

static func desk_lamp(parent: Node3D, pos: Vector3, rot_y: float, on: bool = true) -> OmniLight3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	cyl(n, 0.07, 0.08, 0.03, Vector3(0, 0.015, 0), mat(Color("2c2a28")), 8)
	var arm := box(n, Vector3(0.02, 0.36, 0.02), Vector3(0, 0.2, 0.05), mat(Color("2c2a28")))
	arm.rotation.x = -0.35
	cyl(n, 0.03, 0.09, 0.12, Vector3(0, 0.38, 0.14), mat(Color("3a5a44")), 8)
	var bulb := sphere(n, 0.03, Vector3(0, 0.33, 0.15), emis(Color("fff0c8"), 1.0 if on else 0.25), 6)
	var l := omni(n, Vector3(0, 0.25, 0.16), Color("ffdca0"), 1.1 if on else 0.0, 3.5)
	return l

static func standard_lamp(parent: Node3D, pos: Vector3, lit: bool = true, shade: bool = true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cyl(n, 0.16, 0.18, 0.04, Vector3(0, 0.02, 0), mat(Color("3a3028")), 10)
	cyl(n, 0.015, 0.015, 1.5, Vector3(0, 0.77, 0), mat(Color("b08d4a")), 6)
	var sh: MeshInstance3D = null
	if shade:
		sh = cyl(n, 0.18, 0.28, 0.32, Vector3(0, 1.48, 0), mat("shade_pleat", 6.0, false, Color("e8c890") if lit else Color.BLACK), 12)
		sh.name = "shade"
	if lit:
		sphere(n, 0.05, Vector3(0, 1.42, 0), emis(Color("fff0c0")), 6)
		omni(n, Vector3(0, 1.3, 0), Color("ffd89a"), 1.3, 4.0)
	return n

# ------------------------------------------------------------------ furniture

static func desk(parent: Node3D, pos: Vector3, rot_y: float, w: float = 1.2, d: float = 0.6, h: float = 0.74, top_m: Material = null, leg_m: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var tm := top_m if top_m else mat("wood_light", 2.0)
	var lm := leg_m if leg_m else mat(Color("4a4440"))
	box(n, Vector3(w, 0.04, d), Vector3(0, h, 0), tm)
	for x in [-w / 2 + 0.04, w / 2 - 0.04]:
		for z in [-d / 2 + 0.04, d / 2 - 0.04]:
			box(n, Vector3(0.04, h, 0.04), Vector3(x, h / 2, z), lm)
	box(n, Vector3(0.4, 0.5, d - 0.06), Vector3(w / 2 - 0.24, h - 0.27, 0), tm)
	return n

static func cabinet(parent: Node3D, pos: Vector3, rot_y: float, w: float = 0.46, d: float = 0.6, h: float = 1.3, col: Color = Color("6c7064")) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	box(n, Vector3(w, h, d), Vector3(0, h / 2, 0), mat(col))
	var drawers := int(h / 0.33)
	for i in drawers:
		box(n, Vector3(w - 0.06, 0.012, 0.01), Vector3(0, 0.3 + i * 0.32, d / 2 + 0.005), mat(Color("3c3e38")))
		box(n, Vector3(0.1, 0.02, 0.02), Vector3(0, 0.2 + i * 0.32, d / 2 + 0.01), mat(Color("b8b6ae")))
	return n

static func camp_bed(parent: Node3D, pos: Vector3, rot_y: float, blanket: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var frame_m := mat(Color("5a5e52"))
	box(n, Vector3(0.7, 0.05, 1.9), Vector3(0, 0.36, 0), mat(Color("3e4a3a")))
	for x in [-0.33, 0.33]:
		box(n, Vector3(0.03, 0.03, 1.9), Vector3(x, 0.38, 0), frame_m)
	for z in [-0.8, 0.0, 0.8]:
		var l1 := box(n, Vector3(0.03, 0.45, 0.03), Vector3(-0.2, 0.2, z), frame_m)
		l1.rotation.z = 0.5
		var l2 := box(n, Vector3(0.03, 0.45, 0.03), Vector3(0.2, 0.2, z), frame_m)
		l2.rotation.z = -0.5
	if blanket:
		box(n, Vector3(0.74, 0.06, 1.3), Vector3(0, 0.42, 0.28), blanket)
		box(n, Vector3(0.74, 0.02, 0.1), Vector3(0, 0.44, -0.42), blanket)
	box(n, Vector3(0.5, 0.1, 0.32), Vector3(0, 0.44, -0.72), mat(Color("e4ddc8")))
	return n

static func shelf(parent: Node3D, pos: Vector3, rot_y: float, w: float = 1.0, d: float = 0.28, levels: int = 3, spacing: float = 0.4, m: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var sm := m if m else mat("wood_light", 2.0)
	for i in levels:
		box(n, Vector3(w, 0.025, d), Vector3(0, i * spacing, 0), sm)
	for x in [-w / 2, w / 2]:
		box(n, Vector3(0.025, spacing * (levels - 1) + 0.03, d), Vector3(x, spacing * (levels - 1) / 2, 0), sm)
	return n

static func kettle(parent: Node3D, pos: Vector3) -> void:
	cyl(parent, 0.07, 0.09, 0.2, pos + Vector3(0, 0.1, 0), mat(Color("d8d2c0")), 10)
	box(parent, Vector3(0.03, 0.12, 0.1), pos + Vector3(-0.1, 0.13, 0), mat(Color("2a2a2a")))
	var spout := box(parent, Vector3(0.03, 0.03, 0.08), pos + Vector3(0.09, 0.14, 0), mat(Color("d8d2c0")))
	spout.rotation.z = -0.6

static func mug(parent: Node3D, pos: Vector3, col: Color = Color("e8e2d2")) -> void:
	cyl(parent, 0.04, 0.04, 0.09, pos + Vector3(0, 0.045, 0), mat(col), 8)
	box(parent, Vector3(0.015, 0.05, 0.03), pos + Vector3(0.05, 0.05, 0), mat(col))

static func desk_phone(parent: Node3D, pos: Vector3, rot_y: float, off_hook: bool = false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var beige := mat(Color("d6ccb0"))
	var b := box(n, Vector3(0.2, 0.07, 0.22), Vector3(0, 0.035, 0), beige)
	b.rotation.x = -0.12
	box(n, Vector3(0.1, 0.005, 0.08), Vector3(0, 0.075, 0.03), mat(Color("3a3a36")))
	if not off_hook:
		var r := box(n, Vector3(0.22, 0.05, 0.06), Vector3(0, 0.1, -0.05), beige)
		r.name = "receiver"
	tex_quad(n, "sign_247", 0.05, 0.025, Vector3(0, 0.083, 0.06), Vector3(-PI / 2 - 0.12, 0, 0))
	return n

static func flask(parent: Node3D, pos: Vector3) -> void:
	cyl(parent, 0.045, 0.045, 0.28, pos + Vector3(0, 0.14, 0), mat(Color("7a3a34")), 10)
	cyl(parent, 0.048, 0.048, 0.05, pos + Vector3(0, 0.3, 0), mat(Color("2a3a2a")), 10)

static func plastic_chair(parent: Node3D, pos: Vector3, rot_y: float, col: Color = Color("d86a2a")) -> Node3D:
	return chair(parent, pos, rot_y, mat(col), mat(Color("5a5a5a")))

static func door_leaf(parent: Node3D, pos: Vector3, rot_y: float, w: float = 0.86, h: float = 2.0, m: Material = null, open: float = 0.0) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = pos
	hinge.rotation.y = rot_y
	parent.add_child(hinge)
	var leaf := Node3D.new()
	leaf.rotation.y = open
	hinge.add_child(leaf)
	box(leaf, Vector3(w, h, 0.045), Vector3(w / 2, h / 2, 0), m if m else mat(Color("8a6a48")))
	box(leaf, Vector3(0.1, 0.02, 0.04), Vector3(w - 0.1, 1.0, 0.04), mat(Color("b8b6ae")))
	return hinge

## A window hole's frame and glass, facing +Z. Glass alpha is low so what's beyond shows.
static func window(parent: Node3D, center: Vector3, w: float, h: float, rot_y: float = 0.0, glass_col: Color = Color(0.08, 0.1, 0.14), glass_a: float = 0.35, frame_col: Color = Color("d8d2c0"), mullion: bool = true) -> Node3D:
	var n := Node3D.new()
	n.position = center
	n.rotation.y = rot_y
	parent.add_child(n)
	var fm := mat(frame_col)
	box(n, Vector3(w, 0.06, 0.1), Vector3(0, h / 2, 0), fm)
	box(n, Vector3(w, 0.06, 0.1), Vector3(0, -h / 2, 0), fm)
	box(n, Vector3(0.06, h, 0.1), Vector3(-w / 2, 0, 0), fm)
	box(n, Vector3(0.06, h, 0.1), Vector3(w / 2, 0, 0), fm)
	if mullion:
		box(n, Vector3(0.04, h, 0.08), Vector3(0, 0, 0), fm)
	box(n, Vector3(w + 0.1, 0.04, 0.22), Vector3(0, -h / 2 - 0.02, 0.08), fm)
	var g := quad(n, w, h, Vector3.ZERO, glass(glass_col, glass_a))
	g.name = "glass"
	return n

# ------------------------------------------------------------------ the bag and what's in it

static func plastic_bag(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var bm := mat("bag_blue", 6.0)
	var w := 0.44
	var d := 0.26
	var h := 0.34
	box(n, Vector3(w, 0.01, d), Vector3(0, 0.005, 0), bm)
	var f1 := box(n, Vector3(w, h, 0.008), Vector3(0, h / 2, d / 2), bm)
	f1.rotation.x = 0.12
	var f2 := box(n, Vector3(w, h * 0.9, 0.008), Vector3(0, h * 0.45, -d / 2), bm)
	f2.rotation.x = -0.18
	box(n, Vector3(0.008, h * 0.8, d), Vector3(-w / 2, h * 0.4, 0), bm)
	box(n, Vector3(0.008, h * 0.8, d), Vector3(w / 2, h * 0.4, 0), bm)
	var handle := box(n, Vector3(0.14, 0.02, 0.01), Vector3(0, h + 0.06, d / 2 + 0.03), bm)
	handle.name = "handle"
	tex_quad(n, "label_ari", 0.09, 0.022, Vector3(0, h + 0.06, d / 2 + 0.041))
	return n

static func folded_coat(parent: Node3D, pos: Vector3, rot_y: float = 0.0, m: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var cm := m if m else mat("corduroy", 10.0)
	box(n, Vector3(0.38, 0.09, 0.26), Vector3(0, 0.045, 0), cm)
	box(n, Vector3(0.36, 0.03, 0.08), Vector3(0, 0.1, -0.08), cm)
	box(n, Vector3(0.12, 0.025, 0.06), Vector3(0, 0.1, 0.1), mat(Color("c8c0a8")))
	return n

static func hanging_coat(parent: Node3D, pos: Vector3, rot_y: float = 0.0, m: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var cm := m if m else mat("corduroy", 10.0)
	var body := cyl(n, 0.2, 0.26, 0.95, Vector3(0, -0.52, 0), cm, 8)
	body.scale = Vector3(1.0, 1.0, 0.45)
	for x in [-0.22, 0.22]:
		var sl := cyl(n, 0.05, 0.06, 0.78, Vector3(x, -0.5, 0.02), cm, 6)
		sl.rotation.z = -0.08 if x < 0 else 0.08
	box(n, Vector3(0.28, 0.08, 0.1), Vector3(0, -0.04, 0), cm)
	return n

## A low-poly hand, palm down, fingers towards -Z. `split` adds the cut beside the thumbnail.
static func hand(parent: Node3D, pos: Vector3, rot: Vector3, skin_m: Material, sleeve_m: Material, split: bool = false, curl: float = 0.5) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation = rot
	parent.add_child(h)
	box(h, Vector3(0.088, 0.03, 0.1), Vector3(0, 0, 0), skin_m)
	for i in 4:
		var f := Node3D.new()
		f.position = Vector3(-0.032 + i * 0.021, 0.0, -0.05)
		f.rotation.x = -curl * (0.8 + i * 0.1)
		h.add_child(f)
		var ln := 0.075 - absf(i - 1.5) * 0.01
		box(f, Vector3(0.018, 0.02, ln), Vector3(0, 0, -ln / 2), skin_m)
		box(f, Vector3(0.014, 0.004, 0.012), Vector3(0, 0.011, -ln + 0.008), mat(Color("e8c8b8")))
	var th := Node3D.new()
	th.position = Vector3(0.05, -0.005, -0.01)
	th.rotation.y = 0.7
	th.rotation.x = -0.2
	h.add_child(th)
	box(th, Vector3(0.024, 0.024, 0.06), Vector3(0, 0, -0.03), skin_m)
	box(th, Vector3(0.018, 0.005, 0.016), Vector3(0, 0.013, -0.052), mat(Color("ecd0c0")))
	if split:
		box(th, Vector3(0.003, 0.006, 0.014), Vector3(-0.012, 0.012, -0.05), emis(Color("f0e6e0")))
		box(th, Vector3(0.002, 0.006, 0.012), Vector3(-0.0135, 0.0125, -0.05), mat(Color("a83a30")))
	cyl(h, 0.04, 0.045, 0.16, Vector3(0, 0.0, 0.12), sleeve_m, 8).rotation.x = PI / 2
	return h

static func slip(parent: Node3D, pos: Vector3, rot: Vector3, w: float = 0.2, h: float = 0.13) -> MeshInstance3D:
	return picture(parent, "res://assets/docs/slip.png", w, h, pos, rot)

static func key_with_tag(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	box(n, Vector3(0.05, 0.004, 0.018), Vector3(0, 0.002, 0), mat(Color("c8b070")))
	cyl(n, 0.012, 0.012, 0.004, Vector3(-0.03, 0.002, 0), mat(Color("b0a070")), 8)
	tex_quad(n, "keytag", 0.05, 0.032, Vector3(-0.07, 0.003, 0.01), Vector3(-PI / 2, 0, 0.3))

static func token(parent: Node3D, pos: Vector3) -> void:
	cyl(parent, 0.018, 0.018, 0.004, pos, mat(Color("b8964a")), 12)
	tex_quad(parent, "token", 0.034, 0.034, pos + Vector3(0, 0.0025, 0), Vector3(-PI / 2, 0, 0))

# ------------------------------------------------------------------ small props

static func pot_plant(parent: Node3D, pos: Vector3, pods: Color, pod_count: int = 3, h: float = 0.22) -> void:
	cyl(parent, 0.045, 0.035, 0.08, pos + Vector3(0, 0.04, 0), mat(Color("ece6d8")), 8)
	sphere(parent, 0.07, pos + Vector3(0, 0.08 + h * 0.5, 0), mat(Color("3d6a34")), 6, Vector3(1, h / 0.14, 1))
	var r := RandomNumberGenerator.new()
	r.seed = int(pos.x * 1000.0 + pos.z * 77.0)
	for i in pod_count:
		var a := r.randf() * TAU
		sphere(parent, 0.018, pos + Vector3(cos(a) * 0.06, 0.1 + r.randf() * h, sin(a) * 0.06), mat(pods), 5, Vector3(1, 1.8, 1))

static func bin(parent: Node3D, pos: Vector3, col: Color = Color("2a3a2a")) -> void:
	box(parent, Vector3(0.6, 1.05, 0.7), pos + Vector3(0, 0.52, 0), mat(col))
	box(parent, Vector3(0.62, 0.04, 0.72), pos + Vector3(0, 1.06, 0), mat(col.darkened(0.2)))

static func crisp_packet(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var q := box(parent, Vector3(0.12, 0.01, 0.16), pos, mat(Color("c83a2a")))
	q.rotation.y = rot_y
