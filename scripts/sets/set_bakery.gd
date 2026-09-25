extends SetBase
## The Fenwick Road bakery's loading bay. Racks of trays under orange light,
## a roller door open onto the yard, the van. Variant "fog": morning, the yard
## gone white, loaves wheeled out to cool in it, steaming.

var steam: Node3D
var _t := 0.0

func build(v: String) -> void:
	title = "FENWICK ROAD"
	var fog := v == "fog"
	if fog:
		make_env(Color("c0c4c4"), Color("b8bcbc"), 0.95, Color("e4e6e4"), 0.09)
	else:
		make_env(Color("040406"), Color("5a4a3a"), 0.7, Color("060606"), 0.02)
	var K := SetKit
	K.box(self, Vector3(12, 0.1, 10), Vector3(0, -0.05, -2), K.mat("concrete", 0.8))
	K.box(self, Vector3(24, 0.1, 20), Vector3(0, -0.35, 12), K.mat("asphalt", 0.5))
	K.box(self, Vector3(12, 3.6, 0.2), Vector3(0, 1.8, -7), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(0.2, 3.6, 10), Vector3(-6, 1.8, -2), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(0.2, 3.6, 10), Vector3(6, 1.8, -2), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(12, 0.2, 10), Vector3(0, 3.7, -2), K.mat(Color("3a3a3a")))
	K.box(self, Vector3(12, 1.0, 0.4), Vector3(0, 3.2, 3.0), K.mat(Color("6a6a66")))
	K.cyl(self, 0.35, 0.35, 11.5, Vector3(0, 3.35, 2.9), K.mat(Color("8a8a84")), 10).rotation.z = PI / 2
	K.tex_quad(self, "sign_bakery", 3.0, 0.4, Vector3(0, 3.2, 3.22), Vector3.ZERO, true)
	# racks of trays
	for i in 4:
		var rx := -3.5 + i * 1.6
		var inyard := fog and i == 3
		var rp := Vector3(rx if not inyard else 1.5, 0, 0.0 if not inyard else 5.0)
		for j in 8:
			K.box(self, Vector3(0.7, 0.02, 0.5), rp + Vector3(0, 0.25 + j * 0.2, 0), K.mat(Color("9a9a94")))
			for k in 3:
				K.sphere(self, 0.07, rp + Vector3(-0.2 + k * 0.2, 0.3 + j * 0.2, 0), K.mat("bread", 3.0), 6, Vector3(1.2, 0.7, 1.0))
		for c in [Vector3(-0.35, 0, -0.25), Vector3(0.35, 0, -0.25), Vector3(-0.35, 0, 0.25), Vector3(0.35, 0, 0.25)]:
			K.box(self, Vector3(0.03, 1.9, 0.03), rp + c + Vector3(0, 0.95, 0), K.mat(Color("7a7a74")))
	# the van in the yard
	K.box(self, Vector3(2.0, 2.0, 4.6), Vector3(-3.5, 1.0, 9.0), K.mat(Color("d8d8d0")))
	K.box(self, Vector3(1.9, 0.8, 0.05), Vector3(-3.5, 1.5, 6.68), K.mat(Color("2a3a4a")))
	for side in [-1, 1]:
		K.quad(self, 0.3, 0.2, Vector3(-3.5 + side * 0.7, 0.7, 6.67), K.emis(Color("fff4c8"), 1.0 if fog else 0.3), Vector3(0, PI, 0))
	if fog:
		K.spot(self, Vector3(-3.5, 0.8, 6.5), Vector3(-3.0, 0.5, -2.0), Color("fff0c8"), 2.0, 16.0, 30.0)
	K.omni(self, Vector3(0, 3.0, 1.0), Color("ffa850"), 2.2, 12.0)
	K.omni(self, Vector3(0, 2.8, -4.0), Color("ffe8c8"), 1.0, 9.0)
	# a slipper-shaped roll, in the hand at the bottom of the view
	var hand_n := Node3D.new()
	add_child(hand_n)
	K.hand(hand_n, Vector3(1.18, 1.3, 2.95), Vector3(-0.5, -2.4, 0), K.mat("skin_pale", 8.0), K.mat("fleece_mauve", 8.0), false, 0.8)
	K.sphere(hand_n, 0.09, Vector3(1.12, 1.38, 2.82), K.mat("bread", 3.0), 6, Vector3(1.0, 0.5, 1.8))
	hand_n.visible = not fog
	steam = Node3D.new()
	add_child(steam)
	if fog:
		for i in 10:
			K.quad(steam, 0.8, 0.8, Vector3(1.5 + (i % 3 - 1) * 0.2, 1.9 + i * 0.25, 5.0), K.glass(Color("f4f6f4"), 0.22), Vector3(0, i * 0.6, 0))
	if fog:
		add_cam("dima_eye", Vector3(0.4, 1.62, 2.7), Vector3(0.0, 1.1, 9.0), 60)
	else:
		add_cam("dima_eye", Vector3(1.5, 1.62, 3.4), Vector3(-1.2, 0.9, -1.2), 62)
	add_cam("main", Vector3(4.5, 2.6, -5.5), Vector3(-0.5, 1.0, 3.0), 58)

func _process(delta: float) -> void:
	if steam.get_child_count() == 0 or Settings.reduced_motion:
		return
	_t += delta
	for i in steam.get_child_count():
		var q: Node3D = steam.get_child(i)
		q.position.y = 1.9 + fmod(_t * 0.2 + i * 0.25, 2.5)
