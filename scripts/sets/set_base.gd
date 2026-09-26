class_name SetBase
extends Node3D
## A location built from primitives. Subclasses fill `cams` and react to
## `apply_state` so the script can change a room without new art.

var cams: Dictionary = {}
var title := ""
var variant := ""
var states: Dictionary = {}
var env: WorldEnvironment
## cam name -> nodes to hide while that camera is looking (the lender's own body).
var cam_hide: Dictionary = {}
var current_cam := ""

# ---------------------------------------------------------------- walking
## The floor a lender can be asked to walk on (rects in XZ), what's in the
## way, the things that can be clicked, the doors people arrive by, and
## the people themselves. A set with no floor can't be walked in.
var floors: Array = []  # Rect2(x, z, w, d)
var blocks: Array = []  # Rect2(x, z, w, d)
var floor_y := 0.0
var hotspots: Dictionary = {}  # name -> {box: AABB, stand: Vector3, face: Vector3, label: String, verb: String}
var entries: Dictionary = {}  # name -> [Vector3, rot_y]
var actors: Dictionary = {}  # who -> Node3D
## Where the walking camera sits relative to the lender, where it looks,
## its lens, and the box its target is kept inside so it never ends up in
## a wall. Orientation never changes: the room holds still, people move.
var walk_cam := {"offset": Vector3(0, 3.4, 4.2), "look": Vector3(0, 0.9, 0), "fov": 50.0,
	"min": Vector3(-100, 0, -100), "max": Vector3(100, 0, 100)}

## Set true when a state change moves furniture or people about, so the
## stage rebuilds its walking grid.
var nav_changed := false
## What shoes sound like on this floor: "tile" (hard) or "soft".
var floor_sound := "tile"

func can_walk() -> bool:
	return not floors.is_empty()

func add_floor(r: Rect2) -> void:
	floors.append(r)

func add_block(center_x: float, center_z: float, w: float, d: float) -> void:
	blocks.append(Rect2(center_x - w * 0.5, center_z - d * 0.5, w, d))

## `center`/`size` bound what the pointer can hit; `stand` is where the
## lender goes to deal with it; `face` is what they turn to (defaults to
## the centre).
func add_hotspot(name: String, center: Vector3, size: Vector3, stand: Vector3, label: String = "", verb: String = "look", face: Vector3 = Vector3.INF) -> void:
	hotspots[name] = {"box": AABB(center - size * 0.5, size), "stand": stand, "face": center if face == Vector3.INF else face,
		"label": label, "verb": verb}

func add_entry(name: String, pos: Vector3, rot_y: float) -> void:
	entries[name] = [pos, rot_y]

func set_actor(who: String, node: Node3D) -> void:
	actors[who] = node
	if node:
		node.set_meta("who", who)

## A person in the room is a hotspot too: talk to them where they stand.
func person_spot(name: String, node: Node3D, label: String, stand_offset: Vector3 = Vector3(0, 0, 0.9)) -> void:
	var p := node.position
	var off := stand_offset.rotated(Vector3.UP, node.rotation.y)
	add_hotspot(name, p + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6), p + off, label, "ask", p + Vector3(0, 1.5, 0))

func on_cam(name: String) -> void:
	current_cam = name
	var all_nodes: Array = []
	for c in cam_hide:
		for n in cam_hide[c]:
			if is_instance_valid(n) and not all_nodes.has(n):
				all_nodes.append(n)
	for n in all_nodes:
		if not n.has_meta("shown"):
			n.set_meta("shown", n.visible)
		var hide_now: bool = cam_hide.get(name, []).has(n)
		n.set_meta("cam_hidden", hide_now)
		n.visible = false if hide_now else bool(n.get_meta("shown"))

## Use instead of `visible =` for nodes that cameras may hide.
func show_node(n: Node3D, v: bool) -> void:
	n.set_meta("shown", v)
	if not n.get_meta("cam_hidden", false):
		n.visible = v

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

func make_env(bg: Color, ambient: Color, ambient_energy: float = 1.0, fog_color: Color = Color.BLACK, fog_density: float = 0.0, fog_height: float = 0.0, fog_height_density: float = 0.0) -> void:
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
		if fog_height_density > 0.0:
			e.fog_height = fog_height
			e.fog_height_density = fog_height_density
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
