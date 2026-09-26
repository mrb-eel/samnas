extends SetBase
## The lobby of Ferrier Court and the corridor off the back of it.
## The Overnight Support desk, eight orange chairs on a rail, the notice, the
## tube with a tick in it. States: starter (hate: tube dark), desk (closed),
## morning (on), residents (on), sal (desk).

var tube: Dictionary
var tube_chair: Node3D
var desk_sign: MeshInstance3D
var closed_sign: MeshInstance3D
var desk_lamp_light: OmniLight3D
var residents: Node3D
var sal: Node3D
var sun: OmniLight3D
var _resident_blocks: Array = []
var _chair_block := Rect2(0.72, -1.08, 0.56, 0.56)
var _t := 0.0

func build(_v: String) -> void:
	title = "LOBBY"
	make_env(Color("0a0a0c"), Color("6a6a66"), 0.75)
	var K := SetKit
	var L := 14.0
	var D := 5.0
	var H := 2.7
	K.box(self, Vector3(L, 0.1, D), Vector3(0, -0.05, 0), K.mat("lobby_floor", 1.2))
	var ceiling := K.box(self, Vector3(L, 0.1, D), Vector3(0, H + 0.05, 0), K.mat("ceiling_tile", 1.0))
	# north wall with green dado, west wall with the entrance, east wall to the corridor
	K.box(self, Vector3(L, H - 1.1, 0.1), Vector3(0, 1.1 + (H - 1.1) / 2, -D / 2), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(L, 1.1, 0.1), Vector3(0, 0.55, -D / 2), K.mat("paint_green", 1.0))
	K.box(self, Vector3(0.1, H, 1.7), Vector3(-L / 2, H / 2, -D / 2 + 0.85), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(0.1, H, 1.7), Vector3(-L / 2, H / 2, D / 2 - 0.85), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(0.1, 0.5, 1.6), Vector3(-L / 2, H - 0.25, 0), K.mat("paint_cream", 1.0))
	K.tex_quad(self, "wired_glass", 1.3, 2.2, Vector3(-L / 2 + 0.06, 1.1, 0), Vector3(0, PI / 2, 0), false, "alpha")
	K.box(self, Vector3(0.1, H, 1.8), Vector3(L / 2, H / 2, -D / 2 + 0.9), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(0.1, H, 1.8), Vector3(L / 2, H / 2, D / 2 - 0.9), K.mat("paint_cream", 1.0))
	K.box(self, Vector3(0.1, 0.6, 1.4), Vector3(L / 2, H - 0.3, 0), K.mat("paint_cream", 1.0))
	# the desk
	var desk := K.desk(self, Vector3(1.0, 0, -1.7), 0.0, 2.4, 0.7, 1.0, K.mat("wood_panel", 2.0), K.mat("wood_panel", 2.0))
	K.box(desk, Vector3(2.4, 0.95, 0.05), Vector3(0, 0.5, 0.33), K.mat("wood_panel", 2.0))
	K.box(self, Vector3(0.36, 0.16, 0.012), Vector3(0.6, 1.1, -1.37), K.mat(Color("3a3a3a"))).rotation.x = -0.2
	desk_sign = K.tex_quad(self, "sign_desk", 0.34, 0.14, Vector3(0.6, 1.1, -1.36), Vector3(-0.2, 0, 0))
	closed_sign = K.tex_quad(self, "sign_closed", 0.34, 0.14, Vector3(0.6, 1.1, -1.36), Vector3(-0.2, 0, 0))
	closed_sign.visible = false
	K.mug(self, Vector3(1.4, 1.02, -1.8), Color("4a6a8a"))
	K.picture(self, "res://assets/docs/timetable.jpg", 0.21, 0.305, Vector3(1.0, 1.025, -1.7), Vector3(-PI / 2, 0, 0.15))
	desk_lamp_light = K.desk_lamp(self, Vector3(2.0, 1.02, -1.9), -0.5, true)
	K.desk_phone(self, Vector3(0.1, 1.02, -1.8), 0.2)
	K.box(self, Vector3(0.36, 0.08, 0.26), Vector3(-0.35, 1.06, -1.8), K.mat(Color("7a7a70")))
	for i in 5:
		K.picture(self, "res://assets/docs/dpc_blank.jpg", 0.21, 0.297, Vector3(-0.35, 1.07 + i * 0.006, -1.8), Vector3(-PI / 2, 0, PI / 2 + 0.03 * i))
	K.chair(self, Vector3(1.2, 0, -2.2), PI, K.mat(Color("2a3a4a")), K.mat(Color("333")))
	sal = K.person(self, Vector3(1.2, 0, -2.15), 0.0, {"coat": Color("3e5a4e"), "trousers": Color("26262c"), "skin": Color("c89878"),
		"hair": Color("2a2420"), "hair_style": "short", "glasses": true, "height": 1.7}, "sit")
	sal.visible = false
	# the tube over the desk
	tube = K.tube(self, Vector3(1.0, H - 0.08, -1.2), 1.5, Color("e4f0e0"), 1.6, 9.0)
	tube_chair = K.plastic_chair(self, Vector3(1.0, 0, -0.8), 0.3)
	tube_chair.visible = false
	# notice board
	K.box(self, Vector3(1.4, 0.95, 0.03), Vector3(3.8, 1.55, -D / 2 + 0.07), K.mat("cork", 2.0))
	K.picture(self, "res://assets/docs/notice_lobby.jpg", 0.42, 0.58, Vector3(3.6, 1.55, -D / 2 + 0.095))
	K.picture(self, "res://assets/docs/leaflet_arrivals.jpg", 0.21, 0.3, Vector3(4.2, 1.7, -D / 2 + 0.095), Vector3(0, 0, 0.05))
	# eight orange chairs on a rail, facing the desk
	K.box(self, Vector3(4.2, 0.05, 0.08), Vector3(-2.6, 0.25, 1.35), K.mat(Color("555")))
	for i in 8:
		var c := K.plastic_chair(self, Vector3(-4.35 + i * 0.5, 0, 1.4), PI, Color("d8702e"))
		if i == 2:
			K.box(c, Vector3(0.44, 0.05, 0.42), Vector3(0, 0.49, 0), K.mat("crochet", 8.0))
	# pigeonholes and the vending machine
	var ph := Node3D.new()
	ph.position = Vector3(-5.6, 1.0, -D / 2 + 0.2)
	add_child(ph)
	for r in 6:
		for c2 in 5:
			K.box(ph, Vector3(0.24, 0.02, 0.3), Vector3(-0.5 + c2 * 0.25, r * 0.18, 0), K.mat("wood_light", 3.0))
			K.box(ph, Vector3(0.02, 0.18, 0.3), Vector3(-0.62 + c2 * 0.25, r * 0.18 + 0.09, 0), K.mat("wood_light", 3.0))
			if (r * 5 + c2) % 3 == 0:
				K.box(ph, Vector3(0.16, 0.02, 0.22), Vector3(-0.5 + c2 * 0.25, r * 0.18 + 0.02, 0.02), K.mat(Color("e8e2d0")))
	var vm := K.box(self, Vector3(0.9, 1.85, 0.8), Vector3(-3.0, 0.925, -D / 2 + 0.45), K.mat(Color("8a2020")))
	K.tex_quad(self, "vending", 0.86, 1.8, Vector3(-3.0, 0.93, -D / 2 + 0.86))
	K.tex_quad(self, "sign_exact", 0.3, 0.15, Vector3(-2.75, 1.1, -D / 2 + 0.87))
	K.omni(self, Vector3(-3.0, 1.1, -D / 2 + 1.3), Color("c8d8ff"), 0.45, 2.2)
	# exit sign
	K.box(self, Vector3(0.4, 0.15, 0.06), Vector3(L / 2 - 0.08, 2.35, 0), K.emis(Color("40c060")), 0.0).rotation.y = PI / 2
	# the corridor to G/1
	var cor := Node3D.new()
	cor.position = Vector3(L / 2, 0, 0)
	add_child(cor)
	K.box(cor, Vector3(10, 0.1, 1.5), Vector3(5, -0.05, 0), K.mat("lino", 1.5))
	K.box(cor, Vector3(10, 0.1, 1.5), Vector3(5, 2.45, 0), K.mat("ceiling_tile", 1.0))
	K.box(cor, Vector3(10, 2.4, 0.1), Vector3(5, 1.2, -0.75), K.mat("paint_ivory", 1.0))
	K.box(cor, Vector3(10, 2.4, 0.1), Vector3(5, 1.2, 0.75), K.mat("paint_ivory", 1.0))
	K.box(cor, Vector3(0.1, 2.4, 1.5), Vector3(10, 1.2, 0), K.mat("paint_green", 1.0))
	for x in [3.0, 6.5]:
		K.door_leaf(cor, Vector3(x, 0, -0.72), 0.0, 0.7, 2.1, K.mat(Color("7a5a3e")), -1.4)
		K.box(cor, Vector3(0.1, 0.06, 0.14), Vector3(x + 0.1, 0.03, -0.3), K.mat(Color("2a2a2a")))
	K.cyl(cor, 0.16, 0.13, 0.3, Vector3(4.5, 0.15, 0.4), K.mat(Color("d8b020")), 10)
	var ct := K.tube(cor, Vector3(5, 2.36, 0), 1.2, Color("e8f0e4"), 0.9, 6.0)
	# a warm morning through the door, when there is one
	sun = K.omni(self, Vector3(-L / 2 - 1.0, 1.6, 0), Color("ffe0b0"), 0.0, 14.0)
	# residents, for the morning
	residents = Node3D.new()
	add_child(residents)
	K.person(residents, Vector3(-1.2, 0, 0.3), -0.6, {"coat": Color("6a3a4a"), "trousers": Color("2a2a3a"), "skin": Color("6a4636"), "hair": Color("1a1412"), "hair_style": "bun", "height": 1.64})
	K.person(residents, Vector3(-0.2, 0, 0.9), -0.2, {"coat": Color("9ab0d0"), "trousers": Color("5a5a6a"), "skin": Color("e0c0a8"), "hair": Color("d8d4cc"), "hair_style": "set", "height": 1.55, "glasses": true})
	K.person(residents, Vector3(0.9, 0, 0.5), 0.3, {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"), "hair_style": "bald", "height": 1.84})
	residents.visible = false
	cam_hide = {"main": [ceiling]}
	add_cam("main", Vector3(0.0, 5.4, 8.6), Vector3(0.2, 0.7, -0.8), 50)
	add_cam("jad_eye", Vector3(-1.4, 1.66, 0.9), Vector3(2.6, 1.3, -2.3), 58)
	add_cam("corridor", Vector3(L / 2 + 0.4, 1.62, 0.1), Vector3(L / 2 + 10.0, 1.2, 0.0), 62)
	add_cam("sal_desk", Vector3(1.0, 1.25, -2.05), Vector3(-4.0, 0.9, 1.6), 64)
	_walk(L)

## Where people can go in the lobby, and what they can be asked to look at.
func _walk(L: float) -> void:
	add_floor(Rect2(-L / 2 + 0.1, -2.4, L - 0.2, 4.8))
	add_floor(Rect2(L / 2 - 1.0, -0.7, 11.0, 1.4))  # through to the corridor
	add_block(1.0, -1.95, 2.6, 1.2)  # the desk and the space behind it
	add_block(-3.0, -2.05, 0.95, 0.85)  # vending machine
	add_block(-5.6, -2.25, 1.35, 0.45)  # pigeonholes
	add_block(-2.6, 1.42, 4.35, 0.55)  # the chairs on their rail
	add_block(L / 2 + 4.5, 0.4, 0.4, 0.4)  # the mop bucket
	add_entry("street_door", Vector3(-L / 2 + 0.7, 0, 0.0), PI / 2)
	add_entry("corridor", Vector3(L / 2 + 0.8, 0, 0.0), -PI / 2)
	add_entry("desk", Vector3(1.0, 0, -0.9), PI)
	add_entry("corridor_mouth", Vector3(L / 2 - 0.9, 0, 0.0), -PI / 2)
	add_hotspot("notice", Vector3(3.7, 1.55, -2.42), Vector3(1.4, 0.95, 0.14), Vector3(3.7, 0, -1.55), "The notice", "read")
	add_hotspot("chairs", Vector3(-2.6, 0.45, 1.4), Vector3(4.2, 0.9, 0.5), Vector3(-3.35, 0, 0.72), "The chairs", "look", Vector3(-3.35, 0.45, 1.4))
	add_hotspot("tray", Vector3(-0.35, 1.1, -1.8), Vector3(0.5, 0.2, 0.45), Vector3(-0.35, 0, -0.98), "The wire tray", "look")
	add_hotspot("tube", Vector3(1.0, 2.62, -1.2), Vector3(1.6, 0.2, 0.3), Vector3(1.0, 0, -0.95), "The tube light", "listen")
	add_hotspot("vending", Vector3(-3.0, 0.93, -2.05), Vector3(0.9, 1.85, 0.8), Vector3(-3.0, 0, -1.25), "The vending machine")
	add_hotspot("pigeonholes", Vector3(-5.6, 1.45, -2.3), Vector3(1.3, 1.1, 0.35), Vector3(-5.6, 0, -1.6), "The pigeonholes")
	add_hotspot("desk_sign", Vector3(0.6, 1.1, -1.36), Vector3(0.42, 0.22, 0.12), Vector3(0.6, 0, -0.95), "The sign on the desk", "read")
	add_hotspot("desk_phone", Vector3(0.1, 1.08, -1.8), Vector3(0.3, 0.16, 0.26), Vector3(0.15, 0, -0.95), "The desk phone")
	add_hotspot("street_door", Vector3(-L / 2 + 0.05, 1.1, 0.0), Vector3(0.3, 2.2, 1.5), Vector3(-L / 2 + 0.7, 0, 0.0), "The street door", "go")
	add_hotspot("corridor", Vector3(L / 2 + 0.3, 1.1, 0.0), Vector3(0.7, 2.2, 1.4), Vector3(L / 2 + 0.9, 0, 0.0), "The corridor", "go", Vector3(L / 2 + 6.0, 1.2, 0.0))
	add_hotspot("g1_door", Vector3(L / 2 + 9.9, 1.1, 0.0), Vector3(0.2, 2.2, 1.4), Vector3(L / 2 + 9.2, 0, 0.0), "G/1", "go")
	walk_cam = {"offset": Vector3(0, 3.2, 5.2), "look": Vector3(0, 0.95, -0.6), "fov": 50.0,
		"min": Vector3(-4.0, 0, 0), "max": Vector3(4.0, 0, 0)}

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	match key:
		"starter":
			var dark := value == "hate"
			tube["mesh"].visible = not dark
			tube["light"].light_energy = 0.0 if dark else 1.6
			tube_chair.visible = dark
			# the chair somebody dragged under it is in the way
			blocks.erase(_chair_block)
			if dark:
				blocks.append(_chair_block)
			if hotspots.has("tube"):
				hotspots["tube"]["stand"] = Vector3(0.3, 0, -0.9) if dark else Vector3(1.0, 0, -0.95)
			nav_changed = true
		"desk":
			var closed := value == "closed"
			desk_sign.visible = not closed
			closed_sign.visible = closed
			desk_lamp_light.light_energy = 0.0 if closed else 1.1
		"morning":
			sun.light_energy = 2.2 if value == "on" else 0.0
			env.environment.ambient_light_energy = 1.2 if value == "on" else 0.75
		"residents":
			residents.visible = value == "on"
			# people standing about are in the way
			for rp in _resident_blocks:
				blocks.erase(rp)
			_resident_blocks.clear()
			if value == "on":
				for c in residents.get_children():
					var b := Rect2(c.position.x - 0.3, c.position.z - 0.3, 0.6, 0.6)
					blocks.append(b)
					_resident_blocks.append(b)
			nav_changed = true
		"sal":
			sal.visible = value == "desk"

func _process(delta: float) -> void:
	if tube.is_empty() or not tube["mesh"].visible:
		return
	_t += delta
	# the starter trying, once a second
	var tick := fmod(_t, 1.0) < 0.06 and not Settings.reduced_motion
	tube["light"].light_energy = 0.9 if tick else 1.6
	tube["mesh"].transparency = 0.5 if tick else 0.0
