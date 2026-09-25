extends SetBase
## Dima's flat, 3D, and the courtyard it looks over: bins, a bike, a dead
## Christmas tree, and across the way the other wing, where a man on the
## third floor is trying to get a standard lamp through a doorway.
## States: lampman 0..6. Variant "fog": the courtyard full of fog to the
## third floor, the lamp through at last. Cams: dima_sill, dima_room,
## teodor_window, roof.

const FH := 2.8
var man: Node3D
var woman: Node3D
var lamp: Node3D
var lamp_shade: MeshInstance3D
var dima: Node3D
var hands: Node3D
var lamp_state := 0
var room: Node3D

func build(v: String) -> void:
	title = "3D · THE COURTYARD"
	var fog := v == "fog"
	if fog:
		make_env(Color("b0b8bc"), Color("c0c8cc"), 0.95, Color("e0e4e2"), 0.01, 7.5, 1.2)
	else:
		make_env(Color("04050a"), Color("3e4658"), 0.6, Color("06070c"), 0.012)
	var K := SetKit
	var fy := 3 * FH
	# the courtyard floor, bins, bike, the tree nobody claimed
	K.box(self, Vector3(24, 0.2, 30), Vector3(10, -0.1, 0), K.mat("concrete", 0.5))
	K.bin(self, Vector3(4.0, 0, -6.0))
	K.bin(self, Vector3(4.8, 0, -6.0), Color("3a3a5a"))
	K.cyl(self, 0.3, 0.3, 0.04, Vector3(7.0, 0.3, 4.0), K.mat(Color("2a2a2a")), 10).rotation.x = PI / 2
	K.cyl(self, 0.3, 0.3, 0.04, Vector3(8.0, 0.3, 4.0), K.mat(Color("2a2a2a")), 10).rotation.x = PI / 2
	K.box(self, Vector3(1.0, 0.04, 0.04), Vector3(7.5, 0.55, 4.0), K.mat(Color("8a2a2a")))
	var tree := K.cyl(self, 0.02, 0.5, 1.6, Vector3(10.0, 0.4, -3.0), K.mat(Color("6a5a3a")), 7)
	tree.rotation.z = 1.35
	# our wing: the wall with Dima's window in it
	var ourwall := K.mat("facade", 0.12)
	K.box(self, Vector3(0.3, fy, 30), Vector3(-0.15, fy / 2, 0), ourwall)
	K.box(self, Vector3(0.3, 20 - fy - 2.2, 30), Vector3(-0.15, fy + 2.2 + (20 - fy - 2.2) / 2, 0), ourwall)
	K.box(self, Vector3(0.3, 2.2, 14.0), Vector3(-0.15, fy + 1.1, -8.0), ourwall)
	K.box(self, Vector3(0.3, 2.2, 14.0), Vector3(-0.15, fy + 1.1, 8.0), ourwall)
	K.window(self, Vector3(-0.1, fy + 1.45, 0), 2.0, 1.3, PI / 2, Color(0.05, 0.06, 0.08), 0.12, Color("d8d2c0"), false)
	# Dima's room behind the window
	room = Node3D.new()
	room.position = Vector3(-2.0, fy, 0)
	add_child(room)
	K.box(room, Vector3(3.8, 0.1, 4.0), Vector3(0, -0.05, 0), K.mat("carpet", 1.2))
	K.box(room, Vector3(0.1, FH, 4.0), Vector3(-1.9, FH / 2, 0), K.mat("wallpaper_green", 1.0))
	K.box(room, Vector3(3.8, FH, 0.1), Vector3(0, FH / 2, -2.0), K.mat("wallpaper_green", 1.0))
	K.box(room, Vector3(0.9, 0.55, 0.12), Vector3(1.6, 0.7, 0), K.mat(Color("d8d4c8")))
	# eleven chilli plants on the sill, in yoghurt pots
	var pod_cols := [Color("e87a2a"), Color("f0d040"), Color("c82a2a"), Color("c82a2a"), Color("5a8a3a"), Color("f0e060"), Color("c82a2a"), Color("d83a2a"), Color("e8a030"), Color("8a4ab0"), Color("c82a2a")]
	for i in 11:
		K.pot_plant(self, Vector3(-0.15, fy + 0.84, -0.9 + i * 0.18), pod_cols[i], 3 + (i % 3), 0.16 + (i % 4) * 0.03)
	K.box(self, Vector3(0.5, 0.3, 0.4), Vector3(-0.7, fy + 0.62, -1.2), K.mat(Color("c8c0a8")))
	K.desk_lamp(room, Vector3(-1.4, 0.6, -1.6), 0.4, true)
	K.omni(room, Vector3(0.0, 2.2, 0.0), Color("ffe4c0"), 0.9, 6.0)
	dima = K.person(room, Vector3(1.2, 0, -0.1), -PI / 2, {"coat": Color("7a6a8a"), "trousers": Color("3a3a4a"), "skin": Color("d8b8a8"), "hair": Color("5a3a2a"), "hair_style": "bun", "height": 1.68, "arms": "forward"})
	hands = Node3D.new()
	add_child(hands)
	var towel := K.box(hands, Vector3(0.36, 0.03, 0.3), Vector3(-0.5, fy + 1.12, 0.05), K.mat(Color("d8c8a0")))
	towel.rotation.z = -0.2
	K.hand(hands, Vector3(-0.46, fy + 1.15, -0.18), Vector3(-0.3, PI / 2 + 0.3, 0.2), K.mat("skin_pale", 8.0), K.mat("fleece_mauve", 8.0), false, 0.5)
	K.hand(hands, Vector3(-0.46, fy + 1.15, 0.26), Vector3(-0.3, PI / 2 - 0.3, -0.2), K.mat("skin_pale", 8.0), K.mat("fleece_mauve", 8.0), false, 0.5)
	# the other wing, across
	var opp_m := K.mat("facade_opposite", 0.12)
	var wy0 := fy + 0.75
	var wy1 := fy + 2.15
	K.box(self, Vector3(0.3, wy0, 30), Vector3(20.15, wy0 / 2, 0), opp_m)
	K.box(self, Vector3(0.3, 20 - wy1, 30), Vector3(20.15, wy1 + (20 - wy1) / 2, 0), opp_m)
	K.box(self, Vector3(0.3, wy1 - wy0, 14.5), Vector3(20.15, (wy0 + wy1) / 2, -7.75 + 0.5), opp_m)
	K.box(self, Vector3(0.3, wy1 - wy0, 13.5), Vector3(20.15, (wy0 + wy1) / 2, 8.25 + 0.5), opp_m)
	# the lamp man's flat: a lit window on the third floor with a room behind it
	var opp := Node3D.new()
	opp.position = Vector3(20.0, fy, 1.5)
	add_child(opp)
	K.quad(opp, 2.0, 1.4, Vector3(-0.02, 1.45, 0), K.glass(Color("ffe0a8"), 0.12), Vector3(0, -PI / 2, 0))
	K.box(opp, Vector3(3.0, 0.1, 4.0), Vector3(1.5, -0.05, 0), K.mat("carpet", 1.2))
	K.box(opp, Vector3(0.1, FH, 4.0), Vector3(3.0, FH / 2, 0), K.mat("wallpaper_mauve", 1.2))
	K.box(opp, Vector3(0.12, 2.1, 0.12), Vector3(2.9, 1.05, -0.45), K.mat(Color("f0ece0")))
	K.box(opp, Vector3(0.12, 2.1, 0.12), Vector3(2.9, 1.05, 0.45), K.mat(Color("f0ece0")))
	K.box(opp, Vector3(0.12, 0.12, 1.0), Vector3(2.9, 2.1, 0), K.mat(Color("f0ece0")))
	K.quad(opp, 0.8, 2.0, Vector3(2.93, 1.0, 0), K.emis(Color("4a3a30")), Vector3(0, -PI / 2, 0))
	K.omni(opp, Vector3(1.0, 2.3, 0.0), Color("ffe0b0"), 2.4, 6.0)
	man = K.person(opp, Vector3(2.0, 0, 0.2), PI / 2, {"coat": Color("e0dcd0"), "trousers": Color("3a3a4a"), "skin": Color("d0a888"), "hair": Color("3a2a1a"), "hair_style": "short", "height": 1.76, "arms": "forward"})
	woman = K.person(opp, Vector3(1.2, 0, -0.8), PI / 2, {"coat": Color("b0708a"), "trousers": Color("b0708a"), "skin": Color("d8b8a0"), "hair": Color("6a4a2a"), "hair_style": "long", "height": 1.64, "arms": "forward"})
	woman.visible = false
	lamp = K.standard_lamp(opp, Vector3(2.35, 0, 0.2), true, true)
	lamp_shade = lamp.get_node("shade")
	if fog:
		# the lamp got through, shade on, and it's lit in the window
		lamp.position = Vector3(0.5, 0, 0.6)
		man.visible = false
		for j in 14:
			K.quad(self, 19.6, 36, Vector3(10.1, 0.5 + j * 0.62, 0), K.glass(Color("ffffff"), 0.34), Vector3(-PI / 2, 0, 0))
	cam_hide = {"dima_sill": [dima]}
	add_cam("dima_sill", Vector3(-0.85, fy + 1.62, 0.1), Vector3(20.0, fy + 1.1, 1.5), 22)
	add_cam("dima_hands", Vector3(-0.95, fy + 1.66, 0.05), Vector3(8.0, fy - 3.0, 0.4), 60)
	cam_hide["dima_hands"] = [dima]
	add_cam("dima_room", Vector3(-6.5, fy + 3.2, 4.8), Vector3(-1.5, fy + 0.8, -0.3), 52)
	add_cam("teodor_window", Vector3(0.4, 5 * FH + 1.6, 4.0), Vector3(14.0, fy + 1.0, 1.0), 52)
	add_cam("roof", Vector3(0.6, 20.6, 3.0), Vector3(16.0, fy + 1.0, 1.5), 50)
	cam_hide["teodor_window"] = [room]
	cam_hide["roof"] = [room]
	if not fog:
		hands.visible = true
	else:
		hands.visible = false

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	if key != "lampman":
		return
	lamp_state = int(value)
	woman.visible = false
	lamp.rotation = Vector3.ZERO
	lamp_shade.visible = true
	match lamp_state:
		0:
			man.position = Vector3(2.0, 0, 0.2)
			lamp.position = Vector3(2.35, 0, 0.2)
		1:
			man.position = Vector3(2.2, 0, 0.3)
			lamp.position = Vector3(2.55, 0, 0.1)
		2:
			man.position = Vector3(2.0, 0, 0.3)
			lamp.position = Vector3(2.5, 0.2, 0.1)
			lamp.rotation.z = -0.5
		3:
			man.position = Vector3(1.9, 0, 0.3)
			lamp.position = Vector3(2.3, 0.3, 0.1)
			lamp.rotation.z = -1.35
		4:
			man.position = Vector3(1.6, 0, 0.4)
			lamp.position = Vector3(2.2, 0, 0.1)
		5:
			man.position = Vector3(2.4, 0, 0.1)
			man.rotation.y = PI / 2 + 0.8
			lamp.position = Vector3(2.55, 0, -0.1)
		6:
			man.position = Vector3(2.5, 0, 0.2)
			man.rotation.y = PI / 2
			lamp.position = Vector3(2.6, 0, 0.2)
			lamp_shade.visible = false
			woman.visible = true
			woman.position = Vector3(2.75, 0, -0.2)
