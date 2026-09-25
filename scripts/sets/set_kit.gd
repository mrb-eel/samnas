class_name SetKit
extends RefCounted
## Helpers for building rooms out of boxes, cylinders and flat people.
## Everything uses per-vertex shading and nearest-filtered textures so the
## rooms look like an early 3D render and not a modern one.

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
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_VERTEX
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
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_VERTEX
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
