class_name SetBase
extends Node3D
## A location built from primitives. Subclasses fill `cams` and react to
## `apply_state` so the script can change a room without new art.

var cams: Dictionary = {}
var title := ""
var variant := ""
var states: Dictionary = {}
var env: WorldEnvironment

func build(_variant: String) -> void:
	pass

func apply_state(key: String, value: String) -> void:
	states[key] = value

func cam(name: String) -> Camera3D:
	if cams.has(name):
		return cams[name]
	if cams.has("main"):
		return cams["main"]
	for k in cams:
		return cams[k]
	return null

func add_cam(name: String, pos: Vector3, look: Vector3, fov: float = 60.0, ortho: float = 0.0) -> Camera3D:
	var c := Camera3D.new()
	c.name = "cam_" + name
	add_child(c)
	c.position = pos
	if pos.distance_to(look) > 0.001:
		var up := Vector3.UP
		if abs((look - pos).normalized().dot(up)) > 0.99:
			up = Vector3.FORWARD
		c.look_at_from_position(pos, look, up)
	if ortho > 0.0:
		c.projection = Camera3D.PROJECTION_ORTHOGONAL
		c.size = ortho
	else:
		c.fov = fov
	c.near = 0.05
	c.far = 200.0
	cams[name] = c
	return c

func make_env(bg: Color, ambient: Color, ambient_energy: float = 1.0, fog_color: Color = Color.BLACK, fog_density: float = 0.0) -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient
	e.ambient_light_energy = ambient_energy
	if fog_density > 0.0:
		e.fog_enabled = true
		e.fog_light_color = fog_color
		e.fog_density = fog_density
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
