extends SetBase
## Ferrier Court as the wiring knows it: a dollhouse section. Six floors of
## seven flats over the ground floor, and under all of it the pool hall and
## the frame room. State "lit" takes a comma list of flats ("3D,3B,5A,lobby").

const FLATS := ["A", "B", "C", "D", "E", "F", "G"]
const FH := 2.8
const FW := 3.0
const DEPTH := 5.0

var glow: Dictionary = {}
var figures: Dictionary = {}

func build(_v: String) -> void:
	title = "FERRIER COURT"
	make_env(Color("070a12"), Color("6a7080"), 1.05)
	var K := SetKit
	var width := FW * 7
	var x0 := -width / 2 + FW / 2
	var walls := ["wallpaper_mauve", "paint_cream", "wallpaper_green", "paint_ivory", "carpet", "paint_blue", "wallpaper_mauve"]
	# floors 1..6 and the roof
	for f in range(0, 8):
		K.box(self, Vector3(width + 0.4, 0.18, DEPTH), Vector3(0, f * FH, -DEPTH / 2), K.mat("concrete", 0.6))
	K.box(self, Vector3(width + 0.4, FH * 7, 0.2), Vector3(0, FH * 3.5, -DEPTH), K.mat("concrete", 0.4))
	for f in range(1, 7):
		for i in 7:
			var flat := "%d%s" % [f, FLATS[i]]
			var cx := x0 + i * FW
			var y := f * FH
			K.box(self, Vector3(0.12, FH, DEPTH), Vector3(cx - FW / 2, y + FH / 2, -DEPTH / 2), K.mat("concrete", 0.6))
			K.box(self, Vector3(FW - 0.12, FH - 0.2, 0.05), Vector3(cx, y + FH / 2, -DEPTH + 0.13), K.mat(walls[(f * 3 + i) % walls.size()], 1.2))
			var win := K.quad(self, 0.9, 1.0, Vector3(cx + 0.5, y + 1.5, -DEPTH + 0.17), K.emis(Color("1a2030")))
			var g := K.quad(self, FW - 0.3, FH - 0.4, Vector3(cx, y + FH / 2, -DEPTH + 0.18), K.glass(Color("ffcf88"), 0.0))
			K.quad(self, FW - 0.12, FH - 0.2, Vector3(cx, y + FH / 2, -DEPTH + 0.16), K.glass(Color("000000"), 0.45))
			glow[flat] = [win, g]
			K.box(self, Vector3(1.0, 0.3, 1.7), Vector3(cx - 0.75, y + 0.24, -DEPTH + 1.1), K.mat(Color("2e2a2e")))
	K.box(self, Vector3(0.12, FH * 7, DEPTH), Vector3(width / 2, FH * 3.5, -DEPTH / 2), K.mat("concrete", 0.6))
	# ground floor: lobby, desk, G/1
	K.box(self, Vector3(width * 0.55, FH - 0.2, 0.05), Vector3(-width * 0.22, FH / 2, -DEPTH + 0.13), K.mat("paint_green", 1.0))
	K.desk(self, Vector3(-2.0, 0, -DEPTH + 1.0), 0.0, 2.0, 0.6, 1.0, K.mat("wood_panel", 2.0))
	for i in 8:
		K.plastic_chair(self, Vector3(-8.5 + i * 0.5, 0, -1.2), PI, Color("d8702e"))
	var lobby_g := K.quad(self, width * 0.55, FH - 0.3, Vector3(-width * 0.22, FH / 2, -DEPTH + 0.18), K.glass(Color("d8f0d0"), 0.0))
	glow["lobby"] = [null, lobby_g]
	K.box(self, Vector3(0.12, FH, DEPTH), Vector3(3.0, FH / 2, -DEPTH / 2), K.mat("concrete", 0.6))
	K.box(self, Vector3(width * 0.3, FH - 0.2, 0.05), Vector3(6.2, FH / 2, -DEPTH + 0.13), K.mat("paint_ivory", 1.0))
	K.camp_bed(self, Vector3(4.5, 0, -2.5), PI / 2, K.mat("crochet", 6.0))
	K.desk(self, Vector3(7.8, 0, -DEPTH + 0.8), 0.0, 1.4, 0.6)
	var g1_g := K.quad(self, width * 0.3, FH - 0.3, Vector3(6.2, FH / 2, -DEPTH + 0.18), K.glass(Color("ffe0a0"), 0.0))
	glow["g1"] = [null, g1_g]
	# below: the pool hall and the frame room
	K.box(self, Vector3(width + 0.4, 0.2, DEPTH), Vector3(0, -4.4, -DEPTH / 2), K.mat("white_tile", 0.6))
	K.box(self, Vector3(width * 0.62, 1.8, DEPTH - 1.2), Vector3(-2.0, -3.4, -DEPTH / 2 - 0.2), K.mat("pool_tile_deep", 1.2))
	K.box(self, Vector3(width * 0.62 - 0.4, 0.02, DEPTH - 1.6), Vector3(-2.0, -2.49, -DEPTH / 2 - 0.2), K.glass(Color("10203a"), 0.4))
	K.box(self, Vector3(0.2, 4.4, DEPTH), Vector3(6.0, -2.2, -DEPTH / 2), K.mat("concrete", 0.6))
	K.box(self, Vector3(3.6, 2.4, 0.4), Vector3(8.2, -3.2, -DEPTH + 0.35), K.mat("relays", 1.5))
	K.omni(self, Vector3(8.0, -2.0, -2.0), Color("f0b24a"), 0.9, 5.0)
	K.omni(self, Vector3(-2.0, -1.2, -1.5), Color("4060a0"), 0.8, 12.0)
	K.box(self, Vector3(width + 0.4, 0.3, 0.2), Vector3(0, 0.0, 0.05), K.mat(Color("2a2a2a")))
	# people who are awake
	figures["3D"] = K.person(self, Vector3(x0 + 3 * FW, 3 * FH, -2.5), 0.3, {"coat": Color("7a6a8a"), "trousers": Color("3a3a4a"), "skin": Color("d8b8a8"), "hair": Color("5a3a2a"), "hair_style": "bun", "height": 1.68})
	figures["3B"] = K.person(self, Vector3(x0 + 1 * FW, 3 * FH, -2.5), -0.2, {"coat": Color("6a3a4a"), "trousers": Color("2a2a3a"), "skin": Color("6a4636"), "hair": Color("1a1412"), "hair_style": "bun", "height": 1.64})
	figures["5A"] = K.person(self, Vector3(x0, 5 * FH, -2.5), 0.1, {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"), "hair_style": "bald", "height": 1.84})
	figures["4B"] = K.person(self, Vector3(x0 + 1 * FW, 4 * FH, -2.5), 0.4, Figure.cast("jad"))
	for k in figures:
		figures[k].visible = false
	add_cam("main", Vector3(5.0, 9.5, 32.0), Vector3(0.0, 7.4, -2.5), 0.0, 25.0)
	# every flat can be pointed at; the story decides which ones answer
	for f in range(1, 7):
		for i in 7:
			var flat := "%d%s" % [f, FLATS[i]]
			_flat_spot(flat, Vector3(x0 + i * FW, f * FH + FH / 2, -DEPTH / 2))
	add_hotspot("lobby", Vector3(-width * 0.22, FH / 2, -DEPTH / 2), Vector3(width * 0.55, FH, DEPTH), Vector3.ZERO, "The lobby desk", "dial")
	add_hotspot("g1", Vector3(6.2, FH / 2, -DEPTH / 2), Vector3(width * 0.3, FH, DEPTH), Vector3.ZERO, "G/1", "look")
	add_hotspot("frame", Vector3(8.2, -2.2, -DEPTH / 2), Vector3(4.4, 4.4, DEPTH), Vector3.ZERO, "The frame", "look")

func _flat_spot(flat: String, c: Vector3) -> void:
	add_hotspot(flat, c, Vector3(FW - 0.1, FH - 0.1, DEPTH), Vector3.ZERO, flat, "dial")

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	if key != "lit":
		return
	var list := value.split(",")
	for k in glow:
		var on := list.has(k)
		var win: MeshInstance3D = glow[k][0]
		var g: MeshInstance3D = glow[k][1]
		if win:
			win.material_override = SetKit.emis(Color("ffd890") if on else Color("1a2030"))
		g.material_override = SetKit.glass(Color("ffcf88"), 0.42 if on else 0.0)
	for f in figures:
		figures[f].visible = list.has(f)
