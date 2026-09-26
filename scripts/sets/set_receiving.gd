extends SetBase
## The Receiving Room. White tiles on every surface, a porcelain basin like a
## reclining bath, a brass meter, a cream handset on 201, photographs, the
## poster, the ledger in a plastic bag, and a mirror gone brown at the edges.
## States: cradle (off/on/full), fog (on/off), meter (on), mirror (on),
## holder (jad/teodor/inez/off), sal (on), sign (on), inez (on/off).

var water: MeshInstance3D
var steam: Node3D
var fog_patch: MeshInstance3D
var dial: MeshInstance3D
var mirror_shape: Node3D
var holders: Dictionary = {}
var sal: Node3D
var inez: Node3D
var pen_hand: Node3D
var _t := 0.0

func build(_v: String) -> void:
	title = "RECEIVING"
	make_env(Color("0a0b0c"), Color("8a8e90"), 0.7)
	var K := SetKit
	var W := 3.4
	var D := 3.4
	var H := 2.6
	var t := K.mat("white_tile", 0.9)
	K.box(self, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), t)
	var ceiling := K.box(self, Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), t)
	K.box(self, Vector3(W, H, 0.12), Vector3(0, H / 2, -D / 2), t)
	K.box(self, Vector3(0.12, H, D), Vector3(-W / 2, H / 2, 0), t)
	K.box(self, Vector3(0.12, H, 1.6), Vector3(W / 2, H / 2, -D / 2 + 0.8), t)
	K.box(self, Vector3(0.12, H, 0.9), Vector3(W / 2, H / 2, D / 2 - 0.45), t)
	K.box(self, Vector3(0.12, 0.5, 0.9), Vector3(W / 2, H - 0.25, 0.3), t)
	# the cradle on its plinth
	var porcelain := K.mat(Color("eeece4"))
	K.box(self, Vector3(0.9, 0.36, 1.9), Vector3(-0.4, 0.18, -0.35), K.mat("white_tile", 1.4))
	K.box(self, Vector3(0.8, 0.2, 1.1), Vector3(-0.4, 0.46, 0.0), porcelain)
	var back := K.box(self, Vector3(0.8, 0.2, 0.9), Vector3(-0.4, 0.66, -0.88), porcelain)
	back.rotation.x = 0.62
	for x in [-0.8, 0.0]:
		K.box(self, Vector3(0.06, 0.22, 1.1), Vector3(-0.4 + x / 2 + (0.37 if x == 0.0 else -0.0), 0.62, 0.0), porcelain)
	water = K.box(self, Vector3(0.7, 0.02, 1.0), Vector3(-0.4, 0.6, 0.0), K.glass(Color("9ac8e0"), 0.55))
	water.visible = false
	K.cyl(self, 0.06, 0.06, 0.02, Vector3(-0.4, 0.005, 0.8), K.mat(Color("2a2a2a")), 10)
	steam = Node3D.new()
	add_child(steam)
	for i in 5:
		K.quad(steam, 0.5, 0.5, Vector3(-0.4 + (i - 2) * 0.12, 0.9 + i * 0.12, -0.1 + (i % 2) * 0.2), K.glass(Color("f0f4f4"), 0.18), Vector3(0, i * 0.7, 0))
	steam.visible = false
	fog_patch = K.quad(self, 0.9, 1.8, Vector3(-0.4, H - 0.02, -0.3), K.glass(Color("f4f6f6"), 0.5), Vector3(PI / 2, 0, 0))
	fog_patch.visible = false
	# the meter on the east wall, and the handset on 201
	K.box(self, Vector3(0.1, 0.36, 0.26), Vector3(W / 2 - 0.1, 1.35, -0.9), K.mat(Color("b08d4a")))
	K.box(self, Vector3(0.02, 0.06, 0.008), Vector3(W / 2 - 0.16, 1.44, -0.9), K.mat(Color("2a1a0a")))
	dial = K.cyl(self, 0.05, 0.05, 0.01, Vector3(W / 2 - 0.16, 1.3, -0.9), K.mat(Color("ece4c8")), 10)
	dial.rotation.z = PI / 2
	K.cyl(self, 0.012, 0.012, 0.14, Vector3(W / 2 - 0.2, 1.2, -0.82), K.mat(Color("7a6a3a")), 5).rotation.z = PI / 2
	K.box(self, Vector3(0.24, 0.3, 0.08), Vector3(0.9, 1.35, -D / 2 + 0.1), K.mat(Color("e4dcc4")))
	K.box(self, Vector3(0.06, 0.26, 0.08), Vector3(0.9, 1.36, -D / 2 + 0.18), K.mat(Color("d8ceb0")))
	K.tex_quad(self, "sign_receiving", 0.3, 0.06, Vector3(0.9, 1.62, -D / 2 + 0.07))
	K.cyl(self, 0.012, 0.012, 0.6, Vector3(-W / 2 + 0.1, 1.2, 0.9), K.mat(Color("c8c8c0")), 6).rotation.x = PI / 2
	# the mirror, brown at the edges
	K.box(self, Vector3(0.04, 0.7, 0.5), Vector3(-W / 2 + 0.08, 1.5, 0.9), K.mat(Color("5a3a22")))
	K.quad(self, 0.44, 0.62, Vector3(-W / 2 + 0.105, 1.5, 0.9), K.mat(Color("7a8284")), Vector3(0, PI / 2, 0))
	mirror_shape = Node3D.new()
	add_child(mirror_shape)
	K.sphere(mirror_shape, 0.1, Vector3(-W / 2 + 0.11, 1.62, 0.9), K.glass(Color("e0d8cc"), 0.35), 6, Vector3(0.2, 1.2, 1.0))
	K.box(mirror_shape, Vector3(0.01, 0.3, 0.3), Vector3(-W / 2 + 0.11, 1.35, 0.9), K.glass(Color("8a6a4a"), 0.3))
	mirror_shape.visible = false
	# photographs and the poster, index cards, the ledger
	K.box(self, Vector3(0.56, 0.45, 0.03), Vector3(-0.9, 1.75, -D / 2 + 0.08), K.mat(Color("3a2a1a")))
	K.picture(self, "res://assets/docs/photo_arrivals.jpg", 0.5, 0.389, Vector3(-0.9, 1.75, -D / 2 + 0.1))
	K.box(self, Vector3(0.66, 0.39, 0.03), Vector3(0.05, 1.8, -D / 2 + 0.08), K.mat(Color("3a2a1a")))
	K.picture(self, "res://assets/docs/photo_attendants.jpg", 0.6, 0.334, Vector3(0.05, 1.8, -D / 2 + 0.1))
	K.picture(self, "res://assets/docs/poster_received.jpg", 0.45, 0.637, Vector3(W / 2 - 0.07, 1.5, 0.4), Vector3(0, -PI / 2, 0))
	for i in 3:
		K.quad(self, 0.12, 0.08, Vector3(W / 2 - 0.07, 1.0 + i * 0.1, -0.55 + i * 0.03), K.mat(Color("e8dcc0")), Vector3(0, -PI / 2, 0.05 * i))
	K.shelf(self, Vector3(W / 2 - 0.3, 0.6, 1.1), -PI / 2, 0.6, 0.26, 1, 0.3)
	K.box(self, Vector3(0.22, 0.05, 0.3), Vector3(W / 2 - 0.3, 0.64, 1.1), K.mat(Color("2c5a3a")))
	K.box(self, Vector3(0.25, 0.07, 0.33), Vector3(W / 2 - 0.3, 0.64, 1.1), K.glass(Color("e0e8f0"), 0.3))
	# lights: a caged bulb
	K.sphere(self, 0.07, Vector3(0.2, H - 0.18, 0.2), K.emis(Color("fff4e0")), 6)
	K.omni(self, Vector3(0.2, H - 0.3, 0.2), Color("fff0dc"), 1.2, 6.0)
	# people
	var looks := {
		"jad": Figure.cast("jad", {"arms": "phone"}),
		"teodor": {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"), "hair_style": "bald", "height": 1.84, "long_coat": true, "arms": "phone"},
		"inez": {"coat": Color("3a4a5a"), "trousers": Color("3a4a5a"), "skin": Color("c8a088"), "hair": Color("b8b4ac"), "hair_style": "short", "height": 1.62, "arms": "phone"},
	}
	for k in looks:
		var hp := K.person(self, Vector3(0.75, 0, -D / 2 + 0.55), PI + 0.3, looks[k])
		hp.visible = false
		holders[k] = hp
	inez = K.person(self, Vector3(1.0, 0, 0.9), PI + 0.4, looks["inez"].merged({"arms": "down"}, true))
	sal = K.person(self, Vector3(1.1, 0, 1.2), PI + 0.6, {"coat": Color("3e5a4e"), "trousers": Color("26262c"), "skin": Color("c89878"), "hair": Color("2a2420"), "hair_style": "short", "glasses": true, "height": 1.7, "arms": "forward"})
	sal.visible = false
	pen_hand = Node3D.new()
	add_child(pen_hand)
	K.picture(pen_hand, "res://assets/docs/r1_form.jpg", 0.21, 0.288, Vector3(-0.2, 0.9, 0.55), Vector3(-1.0, 0.2, 0))
	K.hand(pen_hand, Vector3(-0.15, 0.95, 0.62), Vector3(-0.9, 0.3, 0), K.mat("skin_pale", 8.0), K.mat("corduroy", 10.0), false, 0.6)
	K.cyl(pen_hand, 0.005, 0.005, 0.14, Vector3(-0.2, 0.96, 0.52), K.mat(Color("1a2a6a")), 5).rotation.x = 0.8
	pen_hand.visible = false
	cam_hide = {"main": [ceiling], "inez_eye": [inez]}
	add_cam("main", Vector3(2.6, 3.4, 4.6), Vector3(-0.2, 0.8, -0.5), 54)
	add_cam("inez_eye", Vector3(W / 2 - 0.1, 1.58, 1.3), Vector3(-0.6, 1.0, -1.0), 64)
	add_cam("ari_eye", Vector3(-0.4, 0.8, -0.2), Vector3(0.55, 2.0, -0.7), 74)
	add_cam("close", Vector3(0.9, 1.45, -0.6), Vector3(W / 2 - 0.1, 1.32, -0.9), 50)

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	match key:
		"cradle":
			water.visible = value == "on" or value == "full"
			water.position.y = 0.6 if value == "on" else 0.64
			steam.visible = value == "full"
		"fog":
			fog_patch.visible = value == "on"
		"meter":
			dial.rotation.x = 1.0 if value == "on" else 0.0
		"mirror":
			mirror_shape.visible = value == "on"
		"holder":
			for k in holders:
				holders[k].visible = k == value
			if value != "off":
				show_node(inez, false)
		"sal":
			sal.visible = value == "on"
		"sign":
			pen_hand.visible = value == "on"
		"inez":
			show_node(inez, value == "on")

func _process(delta: float) -> void:
	if not steam.visible or Settings.reduced_motion:
		return
	_t += delta
	for i in steam.get_child_count():
		var q: Node3D = steam.get_child(i)
		q.position.y = 0.9 + fmod(_t * 0.15 + i * 0.12, 0.8)
