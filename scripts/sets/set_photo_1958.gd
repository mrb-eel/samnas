extends SetBase
## Not a location: the photograph "Arrivals, winter 1958", staged for the
## renderer. Six people in towelling robes on the shallow-end steps, each with
## a numbered card. Mrs. Doyle is laughing; state "blur" 0..2 moves her
## between exposures so the print can smear her.

var doyle: Node3D

func build(_v: String) -> void:
	title = "ARRIVALS 1958"
	make_env(Color("101010"), Color("7a7a78"), 0.55)
	var K := SetKit
	var tile := K.mat("white_tile", 1.4)
	var wet := K.mat("white_tile", 1.4)
	# the deck, the steps down into the shallow end, the water
	K.box(self, Vector3(12, 0.2, 6), Vector3(0, -0.1, -3.0), tile)
	for i in 3:
		var y := -0.25 * (i + 1)
		K.box(self, Vector3(4.6, 0.25, 0.45), Vector3(0, y + 0.125 - 0.25, 0.22 + i * 0.45), wet)
		K.box(self, Vector3(4.6, 0.04, 0.45), Vector3(0, y - 0.0, 0.22 + i * 0.45), K.mat(Color("e8e6de")))
	K.box(self, Vector3(12, 0.2, 10), Vector3(0, -1.1, 6.0), K.mat("pool_tile", 1.0))
	var water := K.quad(self, 12, 10, Vector3(0, -0.62, 6.0), K.glass(Color("202830"), 0.55), Vector3(-PI / 2, 0, 0))
	water.name = "water"
	# chrome rails either side of the steps
	for sx in [-2.45, 2.45]:
		var rail := K.cyl(self, 0.03, 0.03, 1.5, Vector3(sx, 0.2, 0.55), K.mat(Color("c8c8c4")), 8)
		rail.rotation.x = 1.0
		K.cyl(self, 0.03, 0.03, 0.9, Vector3(sx, 0.45, -0.2), K.mat(Color("c8c8c4")), 8)
	# the end wall: tiles, a dark band, the sign, a clock, a high window
	K.box(self, Vector3(12, 5, 0.2), Vector3(0, 2.3, -2.4), K.mat("white_tile", 0.9))
	K.box(self, Vector3(12, 0.28, 0.22), Vector3(0, 1.45, -2.38), K.mat(Color("2a3a34")))
	K.tex_quad(self, "sign_fsb", 3.4, 0.5, Vector3(0, 2.05, -2.28))
	K.cyl(self, 0.28, 0.28, 0.06, Vector3(3.2, 2.1, -2.28), K.mat(Color("f0ece0")), 20).rotation.x = PI / 2
	K.box(self, Vector3(0.02, 0.2, 0.02), Vector3(3.2, 2.16, -2.24), K.mat(Color("111111")))
	var hand := K.box(self, Vector3(0.02, 0.16, 0.02), Vector3(3.25, 2.08, -2.24), K.mat(Color("111111")))
	hand.rotation.z = -1.1
	K.box(self, Vector3(3.0, 1.0, 0.1), Vector3(-2.6, 3.7, -2.3), K.emis(Color("d8dcd8"), 0.9))
	for x in [-5.0, 5.0]:
		K.box(self, Vector3(0.5, 5, 0.5), Vector3(x, 2.3, -2.1), K.mat(Color("d8d4c8")))
	# six arrivals in towelling robes, numbered
	var robes := [Color("ece8dc"), Color("f0ece4"), Color("e4e0d4"), Color("ece6da"), Color("f2eee6"), Color("e8e4d8")]
	var who := [
		# back row, on the edge of the deck, feet on the first step
		[Vector3(-1.3, -0.25, 0.18), {"skin": Color("d8b8a0"), "hair": Color("3a2a1a"), "hair_style": "short", "shape": "m", "height": 1.8, "card": "24", "head_turn": 0.1}],
		[Vector3(0.0, -0.25, 0.14), {"skin": Color("c89878"), "hair": Color("2a2020"), "hair_style": "bun", "shape": "f", "height": 1.6, "card": "25", "head_tilt": 0.08}],
		[Vector3(1.3, -0.25, 0.2), {"skin": Color("e0c4b0"), "hair": Color("8a6a4a"), "hair_style": "long", "shape": "f", "height": 1.64, "card": "26", "head_turn": -0.15}],
		# front row, on the first step, feet on the second
		[Vector3(-1.9, -0.5, 0.62), {"skin": Color("7a5040"), "hair": Color("1a1412"), "hair_style": "short", "shape": "m", "height": 1.76, "card": "27", "head_turn": 0.25}],
		[Vector3(-0.55, -0.5, 0.64), {"skin": Color("d8b8a8"), "hair": Color("6a4a2a"), "hair_style": "set", "shape": "f", "height": 1.6, "card": "28", "expr": "open", "head_tilt": -0.42, "lean": -0.12}],
		[Vector3(0.9, -0.5, 0.6), {"skin": Color("d0a888"), "hair": Color("c8c0b0"), "hair_style": "bald", "shape": "m", "height": 1.72, "card": "29", "head_turn": -0.1}],
	]
	for i in who.size():
		var look: Dictionary = who[i][1].duplicate()
		look["robe"] = true
		look["coat"] = robes[i]
		look["arms"] = "card"
		var f := K.person(self, who[i][0], 0.0, look, "sit_low")
		if i == 4:
			doyle = f
	# the flash, from the camera
	K.omni(self, Vector3(0.2, 1.1, 6.0), Color("fffaf0"), 2.4, 16.0)
	K.omni(self, Vector3(-2.6, 3.5, -1.5), Color("e8ecf0"), 0.6, 8.0)
	add_cam("main", Vector3(-0.1, 0.72, 4.6), Vector3(-0.35, 0.55, 0.25), 41)

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	if key == "blur" and doyle:
		var k := float(value)
		doyle.rotation.y = 0.12 * k
		doyle.position.x = -0.55 + 0.05 * k
		var head: Node3D = doyle.find_child("head", true, false)
		if head:
			head.rotation.x = -0.42 - 0.22 * k
			head.rotation.z = 0.12 * k
