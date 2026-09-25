extends SetBase
## Outside Ferrier Court, 23:14. A wired-glass door, a dead intercom, and a
## chemist's green cross across the road turning everything the same colour.
## Variant "fog": the morning, the street full of fog to the first floor.

var cross_light: OmniLight3D
var cross_mesh: MeshInstance3D
var bag_group: Node3D
var jad: Node3D
var green_near: OmniLight3D
var _t := 0.0

func build(v: String) -> void:
	title = "OUTSIDE"
	var fog := v == "fog"
	if fog:
		make_env(Color("aeb4b6"), Color("c8ccc8"), 0.9, Color("dfe2de"), 0.012, 2.6, 0.9)
	else:
		make_env(Color("05060a"), Color("4a5262"), 0.85, Color("0a0c12"), 0.02)
	var K := SetKit
	# ground
	K.box(self, Vector3(60, 0.2, 4), Vector3(0, -0.1, 2), K.mat("concrete", 1.0))
	K.box(self, Vector3(60, 0.25, 0.2), Vector3(0, -0.05, 4.1), K.mat(Color("8a8880")))
	K.box(self, Vector3(60, 0.2, 6), Vector3(0, -0.16, 7.2), K.mat("asphalt", 0.5))
	K.box(self, Vector3(60, 0.2, 3), Vector3(0, -0.1, 11.7), K.mat("concrete", 1.0))
	for i in range(-6, 7):
		K.box(self, Vector3(1.6, 0.01, 0.12), Vector3(i * 4.0, -0.05, 7.2), K.emis(Color("c8c4b0"), 0.5))
	# the building: brick ground storey, flats above
	var brick := K.mat("brick", 0.8)
	K.box(self, Vector3(8.6, 3.2, 0.3), Vector3(-5.5, 1.6, -0.15), brick)
	K.box(self, Vector3(8.6, 3.2, 0.3), Vector3(5.5, 1.6, -0.15), brick)
	K.box(self, Vector3(2.4, 1.0, 0.3), Vector3(0, 2.7, -0.15), brick)
	K.box(self, Vector3(20, 17, 0.3), Vector3(0, 11.7, -0.15), K.mat("facade", 0.12))
	# recessed entrance
	K.box(self, Vector3(2.4, 2.2, 0.1), Vector3(0, 1.1, -1.2), K.mat(Color("2a2a2e")))
	K.box(self, Vector3(0.1, 2.2, 1.1), Vector3(-1.2, 1.1, -0.65), brick)
	K.box(self, Vector3(0.1, 2.2, 1.1), Vector3(1.2, 1.1, -0.65), brick)
	K.box(self, Vector3(2.4, 0.1, 1.1), Vector3(0, 2.2, -0.65), K.mat(Color("5a5854")))
	# the door: steel frame and wired glass, lobby light behind it
	var frame := K.mat(Color("6a6c6a"))
	K.box(self, Vector3(1.3, 0.08, 0.08), Vector3(0, 2.1, -1.1), frame)
	K.box(self, Vector3(0.08, 2.1, 0.08), Vector3(-0.62, 1.05, -1.1), frame)
	K.box(self, Vector3(0.08, 2.1, 0.08), Vector3(0.62, 1.05, -1.1), frame)
	K.quad(self, 1.16, 2.0, Vector3(0, 1.05, -1.12), K.emis(Color("c8c090"), 0.55))
	K.tex_quad(self, "wired_glass", 1.16, 2.0, Vector3(0, 1.05, -1.1), Vector3.ZERO, false, "alpha")
	K.box(self, Vector3(0.05, 0.4, 0.05), Vector3(0.45, 1.05, -1.04), K.mat(Color("b8b6ae")))
	K.omni(self, Vector3(0, 1.6, -2.2), Color("d8e0c8"), 0.9, 4.0)
	K.omni(self, Vector3(0.2, 2.7, 0.9), Color("d8d0b0"), 0.8, 5.0)
	# intercom panel, beside the door
	K.box(self, Vector3(0.34, 0.7, 0.06), Vector3(1.55, 1.35, 0.03), K.mat(Color("8a8a86")))
	K.tex_quad(self, "door_panel", 0.3, 0.66, Vector3(1.55, 1.35, 0.065))
	# canopy and name
	K.box(self, Vector3(3.6, 0.14, 1.6), Vector3(0, 3.0, 0.5), K.mat(Color("3a3a3c")))
	K.tex_quad(self, "sign_ferrier", 2.6, 0.32, Vector3(0, 3.3, 0.02), Vector3.ZERO, true)
	# a lamp post, a bus stop
	_lamp_post(Vector3(-6.5, 0, 3.7), not fog)
	K.cyl(self, 0.04, 0.04, 2.8, Vector3(5.0, 1.4, 3.7), K.mat(Color("5a5a58")), 6)
	K.cyl(self, 0.24, 0.24, 0.04, Vector3(5.0, 2.8, 3.7), K.mat(Color("c83a2a")), 12).rotation.x = PI / 2
	# across the road: the chemist
	K.box(self, Vector3(30, 6, 0.3), Vector3(0, 3.0, 13.3), K.mat("brick", 0.8))
	K.quad(self, 5.0, 2.2, Vector3(-1.5, 1.4, 13.14), K.emis(Color("a8c0b0"), 0.35 if not fog else 0.15), Vector3(0, PI, 0))
	K.box(self, Vector3(5.4, 0.5, 0.12), Vector3(-1.5, 2.8, 13.1), K.mat(Color("2a4a36")))
	cross_mesh = K.tex_quad(self, "chemist_cross", 0.8, 0.8, Vector3(1.6, 3.3, 12.9), Vector3(0, PI, 0), true)
	K.box(self, Vector3(0.9, 0.9, 0.1), Vector3(1.6, 3.3, 13.0), K.mat(Color("141814")))
	cross_light = K.omni(self, Vector3(1.6, 3.2, 12.0), Color("50ff7a"), 3.2 if not fog else 0.0, 16.0)
	if fog:
		cross_mesh.visible = false
		for i in range(-8, 3):
			_lamp_post(Vector3(i * 8.0, 0, 3.7), true)
		for j in 5:
			K.quad(self, 120, 30, Vector3(-20, 1.2 + j * 0.45, 7), K.glass(Color("e4e6e2"), 0.22), Vector3(-PI / 2, 0, 0))
	# Jad, by the door, looking down into the bag
	jad = K.person(self, Vector3(0.35, 0, 1.25), PI, {"coat": Color("5c5e62"), "trousers": Color("2a2c34"),
		"skin": Color("aa7a5a"), "hair": Color("1a1614"), "hair_style": "curly", "height": 1.78, "arms": "forward"})
	show_node(jad, not fog)
	# the bag, held open under his eyes
	bag_group = Node3D.new()
	bag_group.position = Vector3(0.3, 0.96, 0.8)
	bag_group.rotation.y = PI
	add_child(bag_group)
	K.plastic_bag(bag_group, Vector3.ZERO, 0.0)
	K.folded_coat(bag_group, Vector3(-0.02, 0.02, 0.0), 0.08)
	K.slip(bag_group, Vector3(0.06, 0.14, 0.02), Vector3(-1.2, 0.1, 0.25), 0.19, 0.12)
	K.key_with_tag(bag_group, Vector3(-0.12, 0.13, -0.05), 0.6)
	K.token(bag_group, Vector3(0.1, 0.125, -0.06))
	K.hand(bag_group, Vector3(0.1, 0.19, 0.1), Vector3(-0.75, -0.4, 0.1), K.mat("skin_jad", 8.0), K.mat(Color("5c5e62")), true, 0.35)
	bag_group.visible = false
	green_near = K.omni(self, Vector3(0.6, 2.4, 2.4), Color("60ff88"), 1.6, 5.0)
	K.omni(self, Vector3(0.1, 1.5, 0.6), Color("d8d0b8"), 0.35, 1.6)
	# cameras
	add_cam("main", Vector3(6.5, 3.2, 11.5), Vector3(0.2, 1.4, 0), 46)
	add_cam("jad_eye", Vector3(0.33, 1.46, 1.04), Vector3(0.3, 0.98, 0.8), 50)
	add_cam("door", Vector3(0.45, 1.64, 1.55), Vector3(0.7, 1.35, -0.9), 58)
	cam_hide = {"jad_eye": [jad], "door": [jad], "bus_top": [jad]}
	add_cam("bus_top", Vector3(-2.0, 4.6, 7.2), Vector3(-40, 2.2, 6.4), 50)

func _lamp_post(p: Vector3, lit: bool) -> void:
	var K := SetKit
	K.cyl(self, 0.07, 0.09, 6.0, p + Vector3(0, 3.0, 0), K.mat(Color("3e4040")), 6)
	K.box(self, Vector3(0.9, 0.08, 0.1), p + Vector3(-0.4, 6.0, 0), K.mat(Color("3e4040")))
	K.box(self, Vector3(0.5, 0.12, 0.26), p + Vector3(-0.8, 5.94, 0), K.emis(Color("ffb060"), 1.0 if lit else 0.2))
	if lit:
		K.omni(self, p + Vector3(-0.8, 5.6, 0), Color("ffa850"), 1.6, 12.0)

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	match key:
		"bag":
			bag_group.visible = value == "open"

func _process(delta: float) -> void:
	if cross_light == null or not cross_mesh.visible:
		return
	_t += delta
	var on := Settings.reduced_motion or fmod(_t, 1.3) < 0.8
	cross_light.light_energy = 3.2 if on else 0.4
	if green_near:
		green_near.light_energy = 1.6 if on else 0.2
	cross_mesh.visible = true
	cross_mesh.transparency = 0.0 if on else 0.75
