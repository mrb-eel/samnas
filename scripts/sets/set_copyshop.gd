extends SetBase
## Aldine Copy & Print at a quarter to three: six copiers with their lids up,
## one strip light over the counter, and on the counter the same form nine
## times, nearly the same.

var sweep: MeshInstance3D
var _t := 0.0

func build(_v: String) -> void:
	title = "ALDINE COPY & PRINT"
	make_env(Color("050506"), Color("56585a"), 0.6)
	var K := SetKit
	var L := 12.0
	var D := 5.0
	var H := 2.8
	K.box(self, Vector3(L, 0.1, D), Vector3(0, -0.05, 0), K.mat("lino", 1.2))
	K.box(self, Vector3(L, 0.1, D), Vector3(0, H + 0.05, 0), K.mat("ceiling_tile", 1.0))
	K.box(self, Vector3(L, H, 0.1), Vector3(0, H / 2, -D / 2), K.mat("paint_ivory", 1.0))
	K.box(self, Vector3(0.1, H, D), Vector3(-L / 2, H / 2, 0), K.mat("paint_ivory", 1.0))
	K.box(self, Vector3(0.1, H, D), Vector3(L / 2, H / 2, 0), K.mat("paint_ivory", 1.0))
	# six copiers along the back wall, lids up
	for i in 6:
		var x := -4.5 + i * 1.6
		K.box(self, Vector3(1.1, 1.0, 0.75), Vector3(x, 0.5, -D / 2 + 0.5), K.mat(Color("c4c2b8")))
		K.tex_quad(self, "copier", 1.0, 0.9, Vector3(x, 0.5, -D / 2 + 0.88))
		K.box(self, Vector3(0.9, 0.02, 0.6), Vector3(x, 1.01, -D / 2 + 0.5), K.mat(Color("3a4a4a")))
		var lid := K.box(self, Vector3(1.0, 0.04, 0.62), Vector3(x, 1.25, -D / 2 + 0.2), K.mat(Color("b8b6ac")))
		lid.rotation.x = 1.2
	sweep = K.box(self, Vector3(0.9, 0.012, 0.03), Vector3(-4.5, 1.02, -D / 2 + 0.3), K.emis(Color("c8f0ff"), 1.3))
	# the counter and the forms on it
	K.box(self, Vector3(4.0, 1.0, 0.7), Vector3(1.0, 0.5, 1.2), K.mat("wood_light", 2.0))
	for i in 9:
		K.picture(self, "res://assets/docs/dpc_form.jpg", 0.21, 0.297, Vector3(0.2 + i * 0.11, 1.005 + i * 0.001, 1.25 + (i % 2) * 0.02), Vector3(-PI / 2, 0, 0.12 - i * 0.03))
	K.box(self, Vector3(0.5, 0.35, 0.05), Vector3(2.6, 1.2, 1.05), K.mat(Color("2a2a2e")))
	K.quad(self, 0.44, 0.28, Vector3(2.6, 1.2, 1.08), K.emis(Color("7aa0c8"), 0.8))
	K.box(self, Vector3(0.6, 0.12, 0.4), Vector3(-0.6, 1.06, 1.2), K.mat(Color("8a8a84")))
	K.tex_quad(self, "sign_staff", 0.4, 0.13, Vector3(-0.6, 1.22, 1.0))
	K.shelf(self, Vector3(5.2, 0.0, -1.0), -PI / 2, 1.6, 0.4, 5, 0.4)
	for i in 4:
		K.box(self, Vector3(0.3, 0.12, 0.22), Vector3(5.2, 0.08 + i * 0.4, -1.0 + (i % 2) * 0.3), K.mat(Color("f0ece0")))
	K.tube(self, Vector3(1.0, H - 0.08, 1.0), 1.5, Color("e8f0e4"), 1.3, 7.0)
	add_cam("jad_eye", Vector3(1.1, 1.66, 2.2), Vector3(0.4, 0.95, 0.9), 62)
	add_cam("main", Vector3(-5.2, 2.4, 2.4), Vector3(2.0, 0.8, -1.0), 58)
	add_cam("row", Vector3(5.0, 1.5, -0.6), Vector3(-6.0, 0.9, -1.8), 50)

func _process(delta: float) -> void:
	if Settings.reduced_motion:
		return
	_t += delta
	var k := fmod(_t * 0.5, 2.0)
	sweep.position.z = -2.5 + 0.2 + (k if k < 1.0 else 2.0 - k) * 0.55
