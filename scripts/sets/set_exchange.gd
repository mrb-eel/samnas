extends SetBase
## The frame room, behind the deep end. A wall of relays and circuit boards
## grown over sixty years; a plaster Virgin in the gap where a board was lost
## in the 2009 flood, Inez's head torch on her raised hand; the attendant's
## board against the side wall, which is where Ari is.
## States: hold (on/off), torch (on/off), inez (on/off), morning, cord (home/held/virgin).

var hold_lamp: MeshInstance3D
var hold_light: OmniLight3D
var torch: SpotLight3D
var torch_lens: MeshInstance3D
var inez: Node3D
var cord_plug_home: Node3D
var cord_on_virgin: Node3D
var work_light: OmniLight3D

func build(_v: String) -> void:
	title = "THE FRAME"
	make_env(Color("060606"), Color("50504c"), 0.55)
	var K := SetKit
	var W := 9.0
	var D := 6.0
	var H := 3.2
	K.box(self, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), K.mat("concrete", 0.8))
	var lower := K.mat("paint_green", 0.9)
	var upper := K.mat("paint_ivory", 0.9)
	K.box(self, Vector3(W, 1.2, 0.2), Vector3(0, 0.6, -D / 2), lower)
	K.box(self, Vector3(W, H - 1.2, 0.2), Vector3(0, 1.2 + (H - 1.2) / 2, -D / 2), upper)
	K.box(self, Vector3(0.2, 1.2, D), Vector3(-W / 2, 0.6, 0), lower)
	K.box(self, Vector3(0.2, H - 1.2, D), Vector3(-W / 2, 1.2 + (H - 1.2) / 2, 0), upper)
	K.box(self, Vector3(0.2, 1.2, D), Vector3(W / 2, 0.6, 0), lower)
	K.box(self, Vector3(0.2, H - 1.2, D), Vector3(W / 2, 1.2 + (H - 1.2) / 2, 0), upper)
	# the frame: panels of relays and boards, one gap in the middle
	var texs := ["relays", "circuit_green", "relays", "wires", "circuit_blue", "relays", "circuit_purple", "relays", "circuit_green", "wires", "relays", "circuit_blue", "relays"]
	var cols := 13
	var pw := 0.6
	var x0 := -pw * cols / 2.0 + pw / 2
	for c in cols:
		for r in 3:
			var cx := x0 + c * pw
			var cy := 0.55 + r * 0.8
			if c == 6 and r == 1:
				continue
			var tname: String = texs[(c * 3 + r * 5) % texs.size()]
			var clean := c >= 2 and c <= 3
			var m := K.mat(tname, 1.6)
			if clean:
				m = K.mat("circuit_blue", 1.6)
			K.box(self, Vector3(pw - 0.03, 0.77, 0.34), Vector3(cx, cy, -D / 2 + 0.3), m)
	# the gap: a dark recess, and the Virgin standing in it
	K.box(self, Vector3(pw - 0.03, 0.77, 0.1), Vector3(0.0, 1.35, -D / 2 + 0.16), K.mat(Color("141212")))
	_virgin(Vector3(0.0, 0.98, -D / 2 + 0.33))
	# cable looms along the top, drooping bundles, tags cut from packets
	for i in 5:
		K.cyl(self, 0.05 + i * 0.008, 0.05 + i * 0.008, 7.8, Vector3(0, 2.86 + i * 0.07, -D / 2 + 0.36 + i * 0.03), K.mat(["wires", "relays", "wires", "metal_dark", "wires"][i], 3.0), 6).rotation.z = PI / 2
	for i in 9:
		var bx := -3.4 + i * 0.85
		for j in 5:
			var seg := K.cyl(self, 0.025, 0.025, 0.28, Vector3(bx + j * 0.05, 2.65 - j * 0.12 - sin(j * 0.6) * 0.05, -D / 2 + 0.5), K.mat("wires", 4.0), 5)
			seg.rotation.z = 0.5 - j * 0.25
	var pcols := [Color("3a6fb0"), Color("c43a2e"), Color("3d8a4f"), Color("d49a2a"), Color("7a4a9a")]
	for i in 14:
		var tx := -3.6 + fmod(i * 1.37, 7.2)
		var ty := 0.4 + fmod(i * 0.61, 2.2)
		var tag := K.box(self, Vector3(0.07, 0.04, 0.004), Vector3(tx, ty, -D / 2 + 0.48), K.mat(Color("ece6d6")))
		K.box(self, Vector3(0.07, 0.012, 0.005), Vector3(tx, ty + 0.016, -D / 2 + 0.483), K.mat(pcols[i % pcols.size()]))
	K.box(self, Vector3(0.012, 0.22, 0.004), Vector3(1.28, 1.72, -D / 2 + 0.49), K.mat(Color("e888b0")))
	K.box(self, Vector3(0.05, 0.02, 0.02), Vector3(-1.9, 2.05, -D / 2 + 0.49), K.mat(Color("7a4a2a")))
	# Inez's bench: the Casio, the stove, the tape machine and the booking printer
	K.shelf(self, Vector3(2.7, 0.9, -D / 2 + 0.95), 0.0, 1.8, 0.45, 2, 0.5)
	K.box(self, Vector3(0.9, 0.07, 0.24), Vector3(2.5, 0.95, -D / 2 + 0.95), K.mat(Color("2a2a2e")))
	K.tex_quad(self, "casio_keys", 0.86, 0.2, Vector3(2.5, 0.99, -D / 2 + 0.95), Vector3(-PI / 2, 0, 0))
	K.box(self, Vector3(0.36, 0.2, 0.26), Vector3(3.3, 1.5, -D / 2 + 0.95), K.mat(Color("46464c")))
	K.tex_quad(self, "tape_machine", 0.34, 0.2, Vector3(3.3, 1.5, -D / 2 + 1.085))
	K.box(self, Vector3(0.4, 0.16, 0.3), Vector3(2.1, 1.48, -D / 2 + 0.95), K.mat(Color("8a8478")))
	K.tex_quad(self, "printer_face", 0.38, 0.14, Vector3(2.1, 1.48, -D / 2 + 1.105))
	K.quad(self, 0.2, 0.34, Vector3(2.1, 1.72, -D / 2 + 0.92), K.mat(Color("ece5d2")))
	K.cyl(self, 0.08, 0.1, 0.1, Vector3(1.5, 0.95, -D / 2 + 1.0), K.mat(Color("3a5a8a")), 8)
	K.mug(self, Vector3(3.5, 0.95, -D / 2 + 1.0), Color("d8b85a"))
	# the attendant's board, against the west wall
	var board := Node3D.new()
	board.position = Vector3(-W / 2 + 0.55, 0, -0.2)
	board.rotation.y = PI / 2
	add_child(board)
	K.box(board, Vector3(1.7, 0.75, 0.8), Vector3(0, 0.375, 0), K.mat("wood_panel", 2.0))
	var face := K.box(board, Vector3(1.7, 1.0, 0.08), Vector3(0, 1.25, -0.28), K.mat(Color("2a211d")))
	face.rotation.x = -0.32
	var fq := K.tex_quad(board, "board_face", 1.62, 0.95, Vector3(0, 1.26, -0.23), Vector3(-0.32, 0, 0))
	K.box(board, Vector3(1.7, 0.04, 0.34), Vector3(0, 0.77, 0.2), K.mat(Color("3b2f28")))
	for i in 5:
		K.cyl(board, 0.012, 0.012, 0.09, Vector3(-0.6 + i * 0.3, 0.83, 0.22), K.mat(Color("1a1412")), 5)
		K.sphere(board, 0.022, Vector3(-0.6 + i * 0.3, 0.88, 0.22), K.mat(Color("2a221e")), 6)
	# Ari's cord: a red cord and a brass plug, home in 247
	cord_plug_home = Node3D.new()
	board.add_child(cord_plug_home)
	for j in 6:
		var cs := K.cyl(cord_plug_home, 0.012, 0.012, 0.14, Vector3(0.55 + j * 0.02, 0.8 + j * 0.03, 0.05 - j * 0.03), K.mat(Color("8e2a22")), 5)
		cs.rotation.x = 0.9
	K.cyl(cord_plug_home, 0.018, 0.018, 0.08, Vector3(0.67, 0.99, -0.13), K.mat(Color("d9b86a")), 6).rotation.x = -1.2
	hold_lamp = K.sphere(board, 0.025, Vector3(0.45, 1.0, -0.13), K.emis(Color("f0b24a")), 6)
	hold_light = K.omni(board, Vector3(0.45, 1.05, 0.0), Color("f0b24a"), 0.5, 1.5)
	K.box(board, Vector3(0.36, 0.45, 0.36), Vector3(0, 0.225, 0.8), K.mat(Color("3a3230")))
	# the cord, hung over the Virgin's raised hand (an ending): it drapes, and
	# the brass plug swings at the end of it
	cord_on_virgin = Node3D.new()
	add_child(cord_on_virgin)
	var hand := Vector3(0.093, 1.495, -D / 2 + 0.366)
	var pts: Array = []
	for j in 12:
		var t := j / 11.0
		pts.append(hand + Vector3(0.012 * sin(t * 3.0) + 0.05 * t, -0.42 * t + 0.03 * sin(t * PI), 0.03 * sin(t * PI) + 0.02 * t))
	for j in 11:
		var a: Vector3 = pts[j]
		var b: Vector3 = pts[j + 1]
		var seg := K.cyl(cord_on_virgin, 0.0065, 0.0065, a.distance_to(b) + 0.004, (a + b) / 2.0, K.mat(Color("9a2a22")), 5)
		seg.look_at_from_position((a + b) / 2.0, b, Vector3.FORWARD if absf((b - a).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2)
	var plug_pos: Vector3 = pts[11]
	K.cyl(cord_on_virgin, 0.011, 0.011, 0.05, plug_pos + Vector3(0, -0.025, 0), K.mat(Color("d9b86a")), 6)
	K.cyl(cord_on_virgin, 0.005, 0.005, 0.03, plug_pos + Vector3(0, -0.065, 0), K.mat(Color("e8d08a")), 5)
	cord_on_virgin.visible = false
	# light: a clamp lamp over the frame
	K.cyl(self, 0.06, 0.12, 0.14, Vector3(-1.2, 2.6, -D / 2 + 0.9), K.mat(Color("3a3a36")), 8)
	work_light = K.omni(self, Vector3(-1.2, 2.3, -D / 2 + 1.2), Color("fff0d0"), 1.3, 6.0)
	K.omni(self, Vector3(0, 2.4, 1.0), Color("c0c8d0"), 0.4, 8.0)
	# Inez
	inez = K.person(self, Vector3(0.3, 0, -1.7), PI, {"coat": Color("3a4a5a"), "trousers": Color("3a4a5a"), "skin": Color("c8a088"), "hair": Color("b8b4ac"), "hair_style": "short", "height": 1.62, "arms": "phone_low"})
	set_actor("inez", inez)
	cam_hide = {"inez_eye": [inez], "casio": [inez]}
	add_cam("main", Vector3(1.8, 3.9, 6.8), Vector3(-0.2, 1.1, -1.6), 56)
	add_cam("inez_eye", Vector3(0.15, 1.55, -1.75), Vector3(0.0, 1.28, -3.0), 56)
	add_cam("board_outside", Vector3(-2.4, 1.62, 0.9), Vector3(-4.25, 0.95, -0.35), 58)
	add_cam("casio", Vector3(2.4, 1.55, -1.7), Vector3(2.55, 0.95, -2.9), 58)
	_walk(W, D)

func _walk(W: float, D: float) -> void:
	add_floor(Rect2(-W / 2 + 0.15, -D / 2 + 0.55, W - 0.3, D - 0.7))
	add_block(2.7, -D / 2 + 0.95, 1.95, 0.6)  # Inez's bench
	add_block(-W / 2 + 0.55, -0.2, 0.95, 1.85)  # the attendant's board
	add_block(-W / 2 + 1.35, -0.2, 0.45, 0.45)  # its stool
	add_entry("door", Vector3(0.6, 0, D / 2 - 0.5), PI)
	add_entry("frame", Vector3(0.3, 0, -1.8), PI)
	add_hotspot("figure", Vector3(0.0, 1.3, -D / 2 + 0.33), Vector3(0.34, 0.75, 0.3), Vector3(0.0, 0, -D / 2 + 1.15), "The figure in the gap", "ask")
	add_hotspot("tags", Vector3(1.4, 1.8, -D / 2 + 0.5), Vector3(1.2, 1.0, 0.12), Vector3(1.4, 0, -D / 2 + 1.15), "The labels on the cables")
	add_hotspot("clean", Vector3(-2.1, 1.35, -D / 2 + 0.35), Vector3(1.2, 2.3, 0.3), Vector3(-2.1, 0, -D / 2 + 1.15), "The clean section")
	add_hotspot("casio", Vector3(2.5, 0.99, -D / 2 + 0.95), Vector3(0.9, 0.14, 0.3), Vector3(2.5, 0, -D / 2 + 1.6), "The Casio")
	add_hotspot("tape", Vector3(3.3, 1.5, -D / 2 + 0.95), Vector3(0.4, 0.26, 0.3), Vector3(3.3, 0, -D / 2 + 1.6), "The answering machine")
	add_hotspot("printer", Vector3(2.1, 1.55, -D / 2 + 0.95), Vector3(0.42, 0.5, 0.32), Vector3(2.0, 0, -D / 2 + 1.6), "The printer")
	add_hotspot("board", Vector3(-W / 2 + 0.55, 1.0, -0.2), Vector3(0.9, 1.4, 1.8), Vector3(-W / 2 + 1.9, 0, -0.2), "The board", "look")
	add_hotspot("looms", Vector3(-2.6, 2.7, -D / 2 + 0.45), Vector3(2.4, 0.5, 0.3), Vector3(-2.6, 0, -D / 2 + 1.2), "The cable looms")
	walk_cam = {"offset": Vector3(0.8, 3.8, 5.6), "look": Vector3(0, 1.0, -1.2), "fov": 54.0,
		"min": Vector3(-1.6, 0, 0), "max": Vector3(1.6, 0, 0)}

## A painted plaster Madonna, about two feet high: white robe, a mantle whose
## blue has faded to the colour of the frame's oldest boards, one hand raised.
## Somebody wired her a halo of grain-of-wheat bulbs from the frame.
func _virgin(p: Vector3) -> void:
	var K := SetKit
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var plaster := K.mat(Color("e4dccb"))
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("4a6a8e")
	blue.cull_mode = BaseMaterial3D.CULL_DISABLED
	blue.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var gold := K.mat(Color("b8964a"))
	# the plinth, and the robe falling in folds to it
	K.cyl(n, 0.075, 0.085, 0.045, Vector3(0, 0.022, 0), K.mat(Color("7a7064")), 8)
	var robe := [[0.045, .07, .06, 0, 0, 0.09, 9.0], [0.16, .058, .05, 0, 0, 0.07, 9.0], [0.3, .048, .04, 0, 0.004, 0.03, 7.0],
		[0.38, .05, .038, 0, 0.004], [0.46, .054, .04, 0, 0.004], [0.52, .046, .034], [0.54, .022, .022]]
	Figure._mi(n, Figure.loft(robe, 16), plaster)
	# the mantle: over the head, down the back to the hem, open in front
	var mantle := [[0.06, .082, .07, 0, -0.004, 0.08, 9.0], [0.2, .068, .058, 0, -0.004, 0.06, 9.0], [0.36, .064, .05, 0, -0.004, 0.03, 7.0],
		[0.5, .066, .05, 0, -0.006], [0.56, .044, .042, 0, -0.004], [0.62, .036, .038, 0, 0.0], [0.645, .02, .024, 0, 0.0]]
	Figure._mi(n, Figure.arc_loft(mantle, PI * 0.62, PI * 2.38, 18), blue)
	# gold along the mantle's edge
	for side in [-1, 1]:
		var trim := K.box(n, Vector3(0.006, 0.5, 0.006), Vector3(side * 0.03, 0.3, 0.052), gold)
		trim.rotation.z = side * 0.06
	# the face, small and pale, eyes lowered
	var head := Node3D.new()
	head.position = Vector3(0, 0.585, 0.012)
	head.scale = Vector3.ONE * 0.36
	head.rotation.x = 0.22
	n.add_child(head)
	var fm := Figure.face_mat({"face": "virgin", "expr": "closed", "skin": Color("e8dccc")})
	Figure._mi(head, Figure.head_mesh(0.8, 0.9), fm)
	# hands: the left open at her side, the right raised, palm out
	var lh := K.sphere(n, 0.014, Vector3(-0.052, 0.33, 0.046), plaster, 6, Vector3(0.8, 1.3, 0.6))
	lh.rotation.z = 0.3
	var arm := K.cyl(n, 0.011, 0.014, 0.13, Vector3(0.06, 0.45, 0.03), plaster, 6)
	arm.rotation.z = -0.5
	K.sphere(n, 0.015, Vector3(0.093, 0.515, 0.036), plaster, 6, Vector3(0.8, 1.3, 0.6))
	# the halo: twelve little bulbs on a wire ring, and the wire back into the frame
	var halo := Node3D.new()
	halo.position = Vector3(0, 0.6, -0.03)
	n.add_child(halo)
	for i in 12:
		var a := TAU * i / 12.0
		K.sphere(halo, 0.006, Vector3(cos(a) * 0.058, sin(a) * 0.058, 0), K.emis(Color("ffcc70"), 0.9), 5)
	for i in 24:
		var a2 := TAU * i / 24.0
		var seg := K.box(halo, Vector3(0.016, 0.0025, 0.0025), Vector3(cos(a2) * 0.058, sin(a2) * 0.058, 0), K.mat(Color("6a6048")))
		seg.rotation.z = a2 + PI / 2
	var lead := K.cyl(n, 0.003, 0.003, 0.3, Vector3(0.1, 0.72, -0.08), K.mat(Color("2a2a2a")), 4)
	lead.rotation.z = -0.9
	K.omni(n, Vector3(0, 0.62, -0.06), Color("ffcc70"), 0.12, 0.6)
	# Inez's head torch, hung on the raised hand
	K.box(n, Vector3(0.05, 0.004, 0.05), Vector3(0.096, 0.53, 0.036), K.mat(Color("2a2a2a")))
	torch_lens = K.cyl(n, 0.018, 0.018, 0.03, Vector3(0.1, 0.495, 0.06), K.emis(Color("fff4d8"), 1.0), 8)
	torch_lens.rotation.x = PI / 2
	torch = K.spot(n, Vector3(0.1, 0.495, 0.09), Vector3(0.0, -0.3, 1.8), Color("fff4d8"), 1.2, 5.0, 35.0)

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	match key:
		"hold":
			hold_lamp.visible = value == "on"
			hold_light.light_energy = 0.5 if value == "on" else 0.0
		"torch":
			torch.light_energy = 1.2 if value == "on" else 0.0
			torch_lens.visible = value == "on"
		"inez":
			show_node(inez, value == "on")
		"morning":
			work_light.light_energy = 0.8 if value == "on" else 1.3
		"cord":
			cord_plug_home.visible = value != "virgin" and value != "held"
			cord_on_virgin.visible = value == "virgin"
