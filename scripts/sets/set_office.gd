extends SetBase
## G/1, the old lifeguard office: a desk under a window that looks down into
## the dark pool hall, a camp bed somebody made up, a kettle, a coat hook.
## States: jad (stand/bed/off), teodor (door/bed/off), coat (bed/hook),
## flask, postcard, reflect, pool_figure, roster, lanyard, morning,
## window_hand (on: a hand on the glass, from outside).

var jad: Node3D
var jad_bed: Node3D
var folder: Node3D
var teodor_door: Node3D
var teodor_bed: Node3D
var coat_bed: Node3D
var coat_hook: Node3D
var flask_n: Node3D
var postcard: MeshInstance3D
var paperback: Node3D
var reflection: Node3D
var reflection_ari: Node3D
var window_hand: MeshInstance3D
var pool_fig: Node3D
var roster: MeshInstance3D
var roster_lim: MeshInstance3D
var lanyard: Node3D
var bag: Node3D
var lamp_light: OmniLight3D
var _hall: Node3D
var hall_light: OmniLight3D
var _t := 0.0

func build(_v: String) -> void:
	title = "G/1"
	make_env(Color("050608"), Color("5c5a58"), 0.7)
	var K := SetKit
	var W := 3.4
	var D := 2.8
	var H := 2.6
	K.box(self, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), K.mat("checker", 1.6))
	# north wall with the window onto the pool hall (a hole 1.6 x 1.0 at sill 1.0)
	var wall := K.mat("paint_ivory", 1.2)
	var dado := K.mat("paint_green", 1.2)
	K.box(self, Vector3(0.9, H, 0.12), Vector3(-W / 2 + 0.45, H / 2, -D / 2), wall)
	K.box(self, Vector3(0.9, H, 0.12), Vector3(W / 2 - 0.45, H / 2, -D / 2), wall)
	K.box(self, Vector3(1.6, 1.0, 0.12), Vector3(0, 0.5, -D / 2), dado)
	K.box(self, Vector3(1.6, H - 2.0, 0.12), Vector3(0, 2.0 + (H - 2.0) / 2, -D / 2), wall)
	K.window(self, Vector3(0, 1.5, -D / 2), 1.6, 1.0, 0.0, Color(0.02, 0.04, 0.07), 0.55)
	# west wall, east wall with the door near the corner
	K.box(self, Vector3(0.12, H, D), Vector3(-W / 2, H / 2, 0), wall)
	K.box(self, Vector3(0.12, H, 1.6), Vector3(W / 2, H / 2, -D / 2 + 0.8), wall)
	K.box(self, Vector3(0.12, 0.5, 1.2), Vector3(W / 2, H - 0.25, D / 2 - 0.6), wall)
	K.door_leaf(self, Vector3(W / 2 - 0.04, 0, 0.3), -PI / 2, 0.86, 2.1, K.mat(Color("7a5a3e")), 1.2)
	# the desk under the window, the phone that is 247
	K.desk(self, Vector3(0.1, 0, -D / 2 + 0.4), 0.0, 1.5, 0.6, 0.74, K.mat("wood_light", 2.0))
	K.desk_phone(self, Vector3(-0.25, 0.76, -D / 2 + 0.42), 0.15)
	lamp_light = K.desk_lamp(self, Vector3(0.6, 0.76, -D / 2 + 0.3), -0.3, true)
	K.chair(self, Vector3(0.05, 0, -D / 2 + 0.95), PI, K.mat("wood_light", 3.0), K.mat(Color("4a4440")))
	# camp bed along the west wall
	K.camp_bed(self, Vector3(-W / 2 + 0.5, 0, 0.2), 0.0, K.mat("crochet", 6.0))
	coat_bed = K.folded_coat(self, Vector3(-W / 2 + 0.5, 0.46, 0.95), 0.2)
	bag = K.plastic_bag(self, Vector3(-W / 2 + 0.5, 0, 1.35), 0.3)
	# cabinet, kettle, mug
	K.cabinet(self, Vector3(W / 2 - 0.35, 0, -D / 2 + 0.4), -PI / 2, 0.46, 0.6, 1.05)
	K.kettle(self, Vector3(W / 2 - 0.35, 1.05, -D / 2 + 0.28))
	K.mug(self, Vector3(W / 2 - 0.35, 1.05, -D / 2 + 0.58))
	# coat hook on the west wall
	K.box(self, Vector3(0.05, 0.05, 0.12), Vector3(-W / 2 + 0.08, 1.75, -0.95), K.mat(Color("b08d4a")))
	coat_hook = K.hanging_coat(self, Vector3(-W / 2 + 0.2, 1.72, -0.95), PI / 2)
	coat_hook.visible = false
	# Teodor's things, later
	flask_n = Node3D.new()
	add_child(flask_n)
	K.flask(flask_n, Vector3(-0.55, 0.76, -D / 2 + 0.35))
	flask_n.visible = false
	postcard = K.tex_quad(self, "tram_postcard", 0.16, 0.11, Vector3(-W / 2 + 0.065, 1.2, 0.1), Vector3(0, PI / 2, 0.05))
	postcard.visible = false
	paperback = Node3D.new()
	add_child(paperback)
	K.box(paperback, Vector3(0.12, 0.025, 0.18), Vector3(-W / 2 + 1.05, 0.013, 0.4), K.mat(Color("2a3a6a")))
	paperback.visible = false
	# the roster and the lanyard, if Ari takes the job
	roster = K.picture(self, "res://assets/docs/roster_continuous.jpg", 0.56, 0.418, Vector3(W / 2 - 0.07, 1.5, -0.2), Vector3(0, -PI / 2, 0))
	roster.visible = false
	roster_lim = K.picture(self, "res://assets/docs/roster_limited.jpg", 0.56, 0.418, Vector3(W / 2 - 0.07, 1.5, -0.2), Vector3(0, -PI / 2, 0))
	roster_lim.visible = false
	lanyard = Node3D.new()
	add_child(lanyard)
	K.box(lanyard, Vector3(0.08, 0.004, 0.12), Vector3(0.35, 0.765, -D / 2 + 0.55), K.mat(Color("e8e4d8")))
	K.box(lanyard, Vector3(0.3, 0.003, 0.012), Vector3(0.2, 0.765, -D / 2 + 0.5), K.mat(Color("c83a2a")))
	lanyard.visible = false
	# the ceiling light
	K.tube(self, Vector3(0, H - 0.05, 0), 1.2, Color("f0ece0"), 0.9, 5.0)
	# people
	var jad_look := Figure.cast("jad")
	jad = K.person(self, Vector3(0.1, 0, -0.2), PI, Figure.cast("jad", {"arms": "phone"}))
	set_actor("jad", jad)
	var jl2 := jad_look.duplicate()
	jl2["arms"] = "forward"
	jad_bed = K.person(self, Vector3(-W / 2 + 0.55, 0.0, 0.1), PI / 2, jl2, "sit")
	jad_bed.visible = false
	folder = Node3D.new()
	add_child(folder)
	var fb := K.box(folder, Vector3(0.24, 0.02, 0.32), Vector3(-W / 2 + 0.95, 0.52, 0.1), K.mat(Color("c8a868")))
	fb.rotation.z = 0.12
	K.picture(folder, "res://assets/docs/dpc_nell.jpg", 0.2, 0.28, Vector3(-W / 2 + 0.96, 0.535, 0.1), Vector3(-PI / 2, 0, 0.12))
	K.hand(folder, Vector3(-W / 2 + 0.92, 0.56, -0.08), Vector3(0.1, PI / 2 + 0.3, 0), K.mat("skin_jad", 8.0), K.mat(Color("26282e")), true, 0.2)
	K.hand(folder, Vector3(-W / 2 + 0.92, 0.56, 0.3), Vector3(0.1, PI / 2 - 0.2, 0), K.mat("skin_jad", 8.0), K.mat(Color("26282e")), false, 0.3)
	folder.visible = false
	var teo := {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"), "hair_style": "bald", "height": 1.84, "long_coat": true}
	teodor_door = K.person(self, Vector3(W / 2 + 0.25, 0, 0.75), -PI / 2, teo)
	teodor_door.visible = false
	teodor_bed = K.person(self, Vector3(-W / 2 + 0.55, 0.0, 0.3), PI / 2, teo, "sit")
	teodor_bed.visible = false
	# the reflection in the window: the room, reversed, dim, behind the glass
	reflection = Node3D.new()
	add_child(reflection)
	var rj := K.person(reflection, Vector3(0.1, 0, -D - 0.35), 0.0, jad_look)
	for m in rj.find_children("*", "MeshInstance3D"):
		(m as MeshInstance3D).transparency = 0.45
	K.sphere(reflection, 0.08, Vector3(0.6, 1.1, -D - 1.1), K.emis(Color("ffe0a0"), 0.7), 6)
	reflection.visible = false
	# the same glass, later: somebody in it who isn't anybody else
	reflection_ari = Node3D.new()
	add_child(reflection_ari)
	var ra := K.person(reflection_ari, Vector3(0.55, 0, -D - 0.45), 0.0, Figure.cast("ari"))
	for m in ra.find_children("*", "MeshInstance3D"):
		(m as MeshInstance3D).transparency = 0.45
	K.sphere(reflection_ari, 0.08, Vector3(0.6, 1.1, -D - 1.1), K.emis(Color("ffe0a0"), 0.7), 6)
	reflection_ari.visible = false
	# a hand on the far side of the glass, from the pool hall, where nobody is
	window_hand = K.blood(self, "hand", 0.22, 0.44, Vector3(0.35, 1.42, -D / 2 - 0.04))
	window_hand.visible = false
	# the pool hall below, dark
	var hall := Node3D.new()
	hall.position = Vector3(0, -3.2, -D / 2 - 8.0)
	add_child(hall)
	_hall = hall
	K.box(hall, Vector3(30, 0.1, 16), Vector3(0, -0.05, 0), K.mat("white_tile", 0.6))
	K.box(hall, Vector3(10, 0.12, 12), Vector3(0, 0.0, -1), K.mat("pool_tile_deep", 1.2))
	K.box(hall, Vector3(10.4, 0.14, 0.3), Vector3(0, 0.02, 5.1), K.mat(Color("d8d4c8")))
	K.box(hall, Vector3(0.2, 1.6, 0.2), Vector3(3.5, 0.8, 5.2), K.mat(Color("c8c4b8")))
	K.box(hall, Vector3(1.2, 0.1, 0.4), Vector3(3.5, 1.6, 4.9), K.mat(Color("c8c4b8")))
	hall_light = K.omni(hall, Vector3(0, 3.0, 2.0), Color("5070a0"), 0.6, 14.0)
	pool_fig = K.person(hall, Vector3(-3.0, 0, 0.0), PI / 2, teo)
	pool_fig.visible = false
	cam_hide = {"window": [jad], "window_close": [jad], "jad_bed": [jad_bed], "teodor_eye": [teodor_bed], "door": [jad], "walk": [hall], "main": [hall]}
	add_cam("main", Vector3(2.9, 3.3, 4.4), Vector3(-0.3, 0.55, -0.35), 50)
	add_cam("window", Vector3(0.1, 1.66, -0.25), Vector3(0.05, 1.35, -2.2), 56)
	add_cam("window_close", Vector3(0.05, 1.55, -1.15), Vector3(0.0, -3.0, -12.0), 60)
	add_cam("jad_bed", Vector3(-W / 2 + 0.6, 1.12, 0.1), Vector3(-0.8, 0.25, 0.2), 64)
	add_cam("teodor_eye", Vector3(-W / 2 + 0.6, 1.08, 0.3), Vector3(0.6, 1.55, -0.9), 66)
	add_cam("door", Vector3(-0.2, 1.62, -0.5), Vector3(W / 2 + 0.3, 1.45, 0.75), 58)
	add_cam("ari_eye", Vector3(-0.5, 1.62, 0.6), Vector3(W / 2, 1.45, -0.2), 60)
	_walk(W, D)

func _walk(W: float, D: float) -> void:
	floor_sound = "soft"
	add_floor(Rect2(-W / 2 + 0.06, -D / 2 + 0.06, W - 0.12, D - 0.12))
	add_floor(Rect2(W / 2 - 0.5, 0.25, 1.6, 1.1))  # the doorway and the corridor outside
	add_block(0.1, -1.0, 1.55, 0.65)  # desk
	add_block(0.05, -0.45, 0.45, 0.45)  # chair
	add_block(-W / 2 + 0.5, 0.3, 0.75, 1.95)  # camp bed
	add_block(W / 2 - 0.35, -1.0, 0.62, 0.62)  # cabinet
	add_block(W / 2 - 0.44, 0.45, 0.8, 0.22)  # the open door leaf, across the corner
	add_entry("door", Vector3(W / 2 + 0.5, 0, 0.85), -PI / 2)
	add_entry("middle", Vector3(0.3, 0, 0.35), PI)
	add_hotspot("bed", Vector3(-W / 2 + 0.5, 0.35, 0.3), Vector3(0.75, 0.5, 1.9), Vector3(-0.55, 0, 0.3), "The camp bed")
	add_hotspot("mug", Vector3(W / 2 - 0.35, 1.1, -D / 2 + 0.58), Vector3(0.22, 0.16, 0.22), Vector3(1.0, 0, -0.35), "The mug")
	add_hotspot("kettle", Vector3(W / 2 - 0.35, 1.16, -D / 2 + 0.28), Vector3(0.24, 0.28, 0.2), Vector3(1.0, 0, -0.35), "The kettle")
	add_hotspot("phone", Vector3(-0.25, 0.83, -D / 2 + 0.42), Vector3(0.3, 0.16, 0.26), Vector3(-0.5, 0, -0.35), "The desk phone")
	add_hotspot("window", Vector3(0, 1.5, -D / 2 + 0.02), Vector3(1.6, 1.0, 0.1), Vector3(0.55, 0, -0.38), "The window")
	add_hotspot("bag", Vector3(-W / 2 + 0.5, 0.2, 1.35), Vector3(0.42, 0.42, 0.36), Vector3(-0.6, 0, 1.15), "The bag")
	add_hotspot("hook", Vector3(-W / 2 + 0.1, 1.72, -0.95), Vector3(0.2, 0.3, 0.3), Vector3(-0.45, 0, -0.25), "The coat hook")
	add_hotspot("door", Vector3(W / 2 + 0.02, 1.05, 0.8), Vector3(0.2, 2.1, 1.2), Vector3(W / 2 - 0.2, 0, 0.95), "The door", "go", Vector3(W / 2 + 2.0, 1.2, 0.8))
	add_hotspot("roster", Vector3(W / 2 - 0.07, 1.5, -0.2), Vector3(0.1, 0.45, 0.6), Vector3(1.1, 0, 0.0), "The roster", "read")
	add_hotspot("lanyard", Vector3(0.3, 0.78, -D / 2 + 0.55), Vector3(0.32, 0.08, 0.2), Vector3(0.58, 0, -0.38), "The lanyard")
	if teodor_door:
		person_spot("teodor", teodor_door, "Teodor", Vector3(0, 0, 0.8))
	walk_cam = {"offset": Vector3(2.9, 3.3, 4.4), "look": Vector3(-0.3, 0.55, -0.35), "fov": 50.0,
		"min": Vector3.ZERO, "max": Vector3.ZERO}

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	match key:
		"jad":
			show_node(jad, value == "stand")
			show_node(jad_bed, value == "bed")
			folder.visible = value == "bed"
		"teodor":
			teodor_door.visible = value == "door"
			show_node(teodor_bed, value == "bed")
			if value == "bed":
				coat_bed.visible = false
				coat_hook.visible = true
				postcard.visible = true
				paperback.visible = true
				flask_n.visible = true
		"coat":
			coat_bed.visible = value == "bed"
			coat_hook.visible = value == "hook"
		"flask":
			flask_n.visible = value == "on"
		"postcard":
			postcard.visible = value == "on"
			paperback.visible = value == "on"
		"reflect":
			reflection.visible = value == "on"
			reflection_ari.visible = value == "ari"
		"window_hand":
			window_hand.visible = value == "on"
		"pool_figure":
			pool_fig.visible = value == "on"
		"roster":
			roster.visible = value == "on"
			roster_lim.visible = value == "limited"
		"lanyard":
			lanyard.visible = value == "on"
		"bag":
			bag.visible = value != "off"
		"morning":
			hall_light.light_color = Color("c8d8e8") if value == "on" else Color("5070a0")
			hall_light.light_energy = 1.6 if value == "on" else 0.6

func _process(delta: float) -> void:
	if not pool_fig.visible:
		return
	_t += delta * (0.0 if Settings.reduced_motion else 1.0)
	pool_fig.position.x = -4.0 + fmod(_t * 0.6, 8.0)
