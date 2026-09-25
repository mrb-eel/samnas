extends SetBase
## Not a location: the photograph "Municipal Attendants, 1965", staged for the
## renderer. Eleven men in a row on the far side of the pool, the same jacket,
## the same cap, the same face. Not quite: the fourth is smiling, the fifth
## holds his hands in front of him, the eighth has his cap on crooked, the
## second wears a ring (too small to see). The pool is full; everything above
## the water is built twice, once upside down beneath it, for the reflection.

const WATER_Y := -0.22

func build(_v: String) -> void:
	title = "ATTENDANTS 1965"
	make_env(Color("0c0c0c"), Color("6c6e70"), 0.6)
	_side(self)
	var mirror := Node3D.new()
	mirror.scale = Vector3(1, -1, 1)
	mirror.position = Vector3(0, 2.0 * WATER_Y, 0)
	add_child(mirror)
	_side(mirror)
	var K := SetKit
	K.quad(self, 24, 14, Vector3(0, WATER_Y, 6.0), K.glass(Color("141a1e"), 0.62), Vector3(-PI / 2, 0, 0))
	for i in 9:
		K.quad(self, 24, 0.05, Vector3(0, WATER_Y + 0.002, 1.2 + i * 0.9 + randf() * 0.3), K.glass(Color("c8d0d4"), 0.08), Vector3(-PI / 2, 0, 0))
	# daylight from the roof lantern, and the flash
	K.omni(self, Vector3(0, 6.0, 1.0), Color("f4f6f8"), 1.4, 14.0)
	K.omni(self, Vector3(0, 1.2, 8.0), Color("fffaf0"), 1.8, 18.0)
	add_cam("main", Vector3(0.0, 1.05, 8.2), Vector3(0.0, 0.55, -0.9), 38)

func _side(root: Node3D) -> void:
	var K := SetKit
	K.box(root, Vector3(24, 0.2, 3), Vector3(0, -0.1, -1.5), K.mat("white_tile", 1.2))
	K.box(root, Vector3(24, 0.14, 0.3), Vector3(0, 0.0, 0.1), K.mat(Color("dcd8cc")))
	K.box(root, Vector3(24, 5, 0.2), Vector3(0, 2.4, -3.0), K.mat("white_tile", 0.9))
	for i in 14:
		var x := -9.75 + i * 1.5
		K.box(root, Vector3(1.1, 1.9, 0.06), Vector3(x, 1.05, -2.86), K.mat(Color("5a6a60")))
		K.box(root, Vector3(1.1, 0.1, 0.08), Vector3(x, 2.05, -2.86), K.mat(Color("3a4a40")))
		var l := Label3D.new()
		l.text = str(i + 1)
		l.font_size = 64
		l.pixel_size = 0.002
		l.modulate = Color("e8e4d8")
		l.position = Vector3(x, 1.75, -2.82)
		l.shaded = true
		root.add_child(l)
	K.tex_quad(root, "sign_fsb", 4.0, 0.58, Vector3(0, 3.2, -2.88))
	K.box(root, Vector3(24, 0.22, 0.22), Vector3(0, 2.6, -2.86), K.mat(Color("2a3a34")))
	var jacket := Color("22262e")
	for i in 11:
		var look := {"coat": jacket, "trousers": jacket, "skin": Color("d0b098"), "hair": Color("2a2420"), "hair_style": "cap",
			"cap_color": Color("1c2028"), "height": 1.76, "shape": "m", "face": "attendant", "arms": "down", "shoes": Color("0e0e0e")}
		if i == 3:
			look["expr"] = "smile"
		if i == 4:
			look["arms"] = "clasp"
		if i == 7:
			look["cap_tilt"] = 0.2
		K.person(root, Vector3(-5.25 + i * 1.05, 0.0, -0.7), 0.0, look)
