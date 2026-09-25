extends SetBase
## Nell's bathroom, 3B: a paper lampshade with a moth in it, a pint glass,
## a council letter for a lid. Variant "fog": the front-room window in the
## morning, Tobi's handprints at the height of Tobi.
## States: moth (on/caught).

var moth: MeshInstance3D
var glass_hand: Node3D
var _t := 0.0

func build(v: String) -> void:
	title = "3B"
	var fog := v == "fog"
	make_env(Color("050506"), Color("7a7470"), 0.7 if not fog else 1.0)
	var K := SetKit
	if fog:
		_front_window()
		return
	var W := 2.2
	var D := 2.4
	var H := 2.5
	K.box(self, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), K.mat("lino", 1.5))
	K.box(self, Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), K.mat("paint_cream", 1.0))
	for wall in [[Vector3(W, H, 0.1), Vector3(0, H / 2, -D / 2)], [Vector3(0.1, H, D), Vector3(-W / 2, H / 2, 0)], [Vector3(0.1, H, D), Vector3(W / 2, H / 2, 0)]]:
		K.box(self, wall[0], wall[1], K.mat("paint_cream", 1.0))
	K.box(self, Vector3(W, 1.2, 0.12), Vector3(0, 0.6, -D / 2 + 0.02), K.mat("white_tile", 1.0))
	# the bath along the back wall
	K.box(self, Vector3(W - 0.2, 0.55, 0.72), Vector3(0, 0.275, -D / 2 + 0.42), K.mat(Color("eceae2")))
	K.box(self, Vector3(W - 0.4, 0.05, 0.56), Vector3(0, 0.53, -D / 2 + 0.42), K.mat(Color("c8d0d4")))
	K.cyl(self, 0.03, 0.03, 0.2, Vector3(0.7, 0.75, -D / 2 + 0.1), K.mat(Color("c8c8c0")), 6)
	# the lampshade, lit from inside, a moth's shadow opening and shutting on it
	K.cyl(self, 0.005, 0.005, 0.3, Vector3(0, H - 0.15, -0.2), K.mat(Color("2a2a2a")), 4)
	var shade := K.cyl(self, 0.22, 0.26, 0.3, Vector3(0, H - 0.42, -0.2), K.emis(Color("f4e8c8"), 0.95), 12)
	K.omni(self, Vector3(0, H - 0.5, -0.2), Color("fff0d0"), 1.4, 5.0)
	moth = K.tex_quad(self, "moth", 0.2, 0.2, Vector3(0.0, H - 0.42, 0.065), Vector3.ZERO, true, "alpha")
	# her hand with a pint glass, and the letter for a lid
	glass_hand = Node3D.new()
	add_child(glass_hand)
	K.hand(glass_hand, Vector3(0.22, 1.72, 0.25), Vector3(0.9, 0.2, 0), K.mat("skin_dark", 8.0), K.mat(Color("6a3a4a")), false, 0.9)
	K.cyl(glass_hand, 0.05, 0.045, 0.15, Vector3(0.2, 1.84, 0.12), K.glass(Color("d8e8f0"), 0.35), 10)
	K.picture(glass_hand, "res://assets/docs/letter_crest.jpg", 0.2, 0.28, Vector3(-0.28, 1.7, 0.2), Vector3(0.9, 0.3, 0))
	add_cam("nell_eye", Vector3(0.05, 1.58, 0.75), Vector3(0.0, H - 0.4, -0.25), 58)
	add_cam("main", Vector3(0.8, 2.3, 1.9), Vector3(-0.1, 1.0, -0.5), 62)
	add_cam("nell_window", Vector3(0.05, 1.58, 0.75), Vector3(0.0, H - 0.4, -0.25), 58)

func _front_window() -> void:
	var K := SetKit
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("e4e8e6")
	env.environment.fog_density = 0.08
	K.box(self, Vector3(4, 0.1, 3), Vector3(0, -0.05, 0), K.mat("carpet", 1.2))
	K.box(self, Vector3(4, 2.6, 0.2), Vector3(0, 1.3, -1.5), K.mat("paint_cream", 1.0))
	K.window(self, Vector3(0, 1.4, -1.38), 1.8, 1.4, 0.0, Color(0.92, 0.94, 0.93), 0.85)
	K.tex_quad(self, "handprints", 0.5, 0.5, Vector3(-0.3, 1.0, -1.34), Vector3.ZERO, true, "alpha")
	K.tex_quad(self, "handprints", 0.4, 0.4, Vector3(0.35, 1.1, -1.34), Vector3(0, 0, 0.8), true, "alpha")
	K.omni(self, Vector3(0, 1.5, 0.2), Color("e8ecf0"), 0.8, 5.0)
	add_cam("nell_window", Vector3(0.1, 1.2, 0.6), Vector3(0.0, 1.35, -1.5), 56)
	add_cam("main", Vector3(0.1, 1.2, 0.6), Vector3(0.0, 1.35, -1.5), 56)

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	if key == "moth" and moth:
		moth.visible = value != "caught"

func _process(delta: float) -> void:
	if moth == null or not moth.visible or Settings.reduced_motion:
		return
	_t += delta
	moth.scale.x = 0.4 + absf(sin(_t * 9.0)) * 0.9
