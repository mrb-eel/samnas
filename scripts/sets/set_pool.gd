extends SetBase
## The Ferrier Street Baths pool hall, drained since 1988.
## Six underwater lamps in the deep-end walls, a wooden chair in the deep end.
## Variants: "meeting" (chairs round the deep end, the speakerphone on the
## chair), "fog" (morning; the pool full of fog to the brim).
## States: lights 0..6, chairs on/off, teodor (walk), torch on/off.

const PL := 25.0   # pool length (x)
const PW := 10.0   # pool width (z)
const DEEP := 3.2
const SHALLOW := 1.0

var lamps: Array = []       # [{light, glass}]
var lights_on := 0
var chairs_group: Node3D
var people: Node3D
var walker: Node3D
var torch: SpotLight3D
var _t := 0.0

func build(v: String) -> void:
	title = "POOL HALL"
	var fog := v == "fog"
	if fog:
		make_env(Color("9aa4aa"), Color("b8c4c8"), 0.9, Color("dde4e4"), 0.02, -0.2, 0.6)
	else:
		make_env(Color("03050a"), Color("24324a"), 0.55, Color("050810"), 0.015)
	var K := SetKit
	var deck := K.mat("white_tile", 0.5)
	var tile := K.mat("pool_tile", 1.0)
	var tile_d := K.mat("pool_tile_deep", 1.0)
	var hx := 17.0
	var hz := 9.0
	# deck around the basin
	K.box(self, Vector3(hx * 2, 0.2, hz - PW / 2), Vector3(0, -0.1, (hz + PW / 2) / 2), deck)
	K.box(self, Vector3(hx * 2, 0.2, hz - PW / 2), Vector3(0, -0.1, -(hz + PW / 2) / 2), deck)
	K.box(self, Vector3(hx - PL / 2, 0.2, PW), Vector3(-(hx + PL / 2) / 2, -0.1, 0), deck)
	K.box(self, Vector3(hx - PL / 2, 0.2, PW), Vector3((hx + PL / 2) / 2, -0.1, 0), deck)
	# the basin: floor sloping from shallow to deep
	var x0 := -PL / 2
	var seg := [[x0, x0 + 10.0, SHALLOW, 1.5], [x0 + 10.0, x0 + 17.0, 1.5, DEEP], [x0 + 17.0, PL / 2, DEEP, DEEP]]
	for sgm in seg:
		var a: float = sgm[0]
		var b: float = sgm[1]
		var da: float = sgm[2]
		var db: float = sgm[3]
		var len := sqrt(pow(b - a, 2) + pow(db - da, 2))
		var fl := K.box(self, Vector3(len, 0.2, PW), Vector3((a + b) / 2, -(da + db) / 2 - 0.1, 0), tile_d if da > 1.4 else tile)
		fl.rotation.z = -atan2(db - da, b - a)
	# basin walls
	K.box(self, Vector3(PL, DEEP, 0.2), Vector3(0, -DEEP / 2, PW / 2 + 0.1), tile)
	K.box(self, Vector3(PL, DEEP, 0.2), Vector3(0, -DEEP / 2, -PW / 2 - 0.1), tile)
	K.box(self, Vector3(0.2, DEEP, PW), Vector3(PL / 2 + 0.1, -DEEP / 2, 0), tile_d)
	K.box(self, Vector3(0.2, SHALLOW, PW), Vector3(-PL / 2 - 0.1, -SHALLOW / 2, 0), tile)
	# coping
	var cop := K.mat(Color("dcd8cc"))
	K.box(self, Vector3(PL + 0.6, 0.12, 0.3), Vector3(0, 0.02, PW / 2 + 0.15), cop)
	K.box(self, Vector3(PL + 0.6, 0.12, 0.3), Vector3(0, 0.02, -PW / 2 - 0.15), cop)
	K.box(self, Vector3(0.3, 0.12, PW), Vector3(PL / 2 + 0.15, 0.02, 0), cop)
	K.box(self, Vector3(0.3, 0.12, PW), Vector3(-PL / 2 - 0.15, 0.02, 0), cop)
	# lane lines on the floor
	for z in [-2.5, 0.0, 2.5]:
		for sgm in seg:
			var a2: float = sgm[0] + 0.6
			var b2: float = sgm[1] - 0.2
			var da2: float = sgm[2]
			var db2: float = sgm[3]
			var len2 := sqrt(pow(b2 - a2, 2) + pow(db2 - da2, 2))
			var ln := K.box(self, Vector3(len2, 0.02, 0.25), Vector3((a2 + b2) / 2, -(da2 + db2) / 2 + 0.01, z), K.mat(Color("162a4a")))
			ln.rotation.z = -atan2(db2 - da2, b2 - a2)
	# litter
	for i in 16:
		var lx := 4.6 + fmod(i * 3.7, 7.6)
		var lz := -4.2 + fmod(i * 2.9, 8.4)
		var lq := K.tex_quad(self, "leaves", 0.55, 0.55, Vector3(lx, -DEEP + 0.02, lz), Vector3(-PI / 2, 0, i), false, "scissor")
		lq.transparency = 0.25
	K.crisp_packet(self, Vector3(-2.0, -1.45, 1.8), 0.7)
	# ladders at the deep end
	for z in [PW / 2 - 0.7, -PW / 2 + 0.7]:
		for dz in [-0.25, 0.25]:
			var rail := K.cyl(self, 0.03, 0.03, DEEP + 1.0, Vector3(PL / 2 - 0.25, -DEEP / 2 + 0.5, z + dz), K.mat(Color("c8c8c0")), 6)
		for r in 6:
			K.box(self, Vector3(0.1, 0.03, 0.5), Vector3(PL / 2 - 0.2, -0.3 - r * 0.5, z), K.mat(Color("b8b8b0")))
	# the diving stand, no board
	K.box(self, Vector3(1.2, 1.6, 1.4), Vector3(PL / 2 + 1.4, 0.8, 0), K.mat("concrete", 0.8))
	K.box(self, Vector3(0.4, 0.1, 0.5), Vector3(PL / 2 + 0.7, 1.62, 0), K.mat(Color("5a5a58")))
	# the chair in the deep end
	K.chair(self, Vector3(9.5, -DEEP, 0.0), -PI / 2, K.mat("wood_light", 3.0), K.mat("wood_light", 3.0))
	# the underwater lamps: three on each long wall at the deep end
	for side in [1, -1]:
		for x in [4.0, 7.5, 11.0]:
			var zc: float = side * (PW / 2 - 0.01)
			var gl := K.tex_quad(self, "lamp_glass", 0.5, 0.5, Vector3(x, -2.2, zc), Vector3(0, PI if side > 0 else 0.0, 0), true)
			gl.transparency = 0.6
			var sp := K.spot(self, Vector3(x, -2.2, zc - side * 0.2), Vector3(x - 0.5, -2.9, -side * 3.0), Color("bfe6ff"), 0.0, 14.0, 62.0)
			var pool_q := K.tex_quad(self, "light_pool", 4.2, 4.2, Vector3(x, -DEEP + 0.03, zc - side * 2.0), Vector3(-PI / 2, 0, 0), true, "add")
			var wall_q := K.tex_quad(self, "light_pool", 3.0, 2.2, Vector3(x, -1.8, zc - side * 0.02), Vector3(0, PI if side > 0 else 0.0, 0), true, "add")
			pool_q.visible = false
			wall_q.visible = false
			lamps.append({"light": sp, "glass": gl, "pools": [pool_q, wall_q]})
	# hall walls: tile below, blue paint above, high windows, a skylight
	var wall_hi := K.mat("paint_blue", 0.4)
	var near_walls: Array = []
	for zs in [hz, -hz]:
		var w1 := K.box(self, Vector3(hx * 2, 2.0, 0.3), Vector3(0, 1.0, zs), deck)
		var w2 := K.box(self, Vector3(hx * 2, 6.0, 0.3), Vector3(0, 5.0, zs), wall_hi)
		if zs > 0:
			near_walls.append(w1)
			near_walls.append(w2)
		for i in 6:
			K.quad(self, 2.0, 1.6, Vector3(-12.5 + i * 5.0, 5.4, zs - sign(zs) * 0.16), K.emis(Color("101828") if not fog else Color("c8d0d4"), 1.0), Vector3(0, 0 if zs < 0 else PI, 0))
	for xs in [hx, -hx]:
		K.box(self, Vector3(0.3, 8.0, hz * 2), Vector3(xs, 4.0, 0), wall_hi)
	var roof := K.box(self, Vector3(hx * 2, 0.3, hz * 2), Vector3(0, 8.1, 0), K.mat(Color("1a2030")))
	var sky := K.quad(self, 20.0, 2.4, Vector3(0, 7.94, 0), K.emis(Color("0a1220") if not fog else Color("e0e6e8"), 1.0), Vector3(PI / 2, 0, 0))
	# G/1's window, high on the shallow-end wall, lit
	K.quad(self, 1.6, 1.0, Vector3(-hx + 0.16, 4.7, -3.0), K.emis(Color("d8c898"), 0.8), Vector3(0, PI / 2, 0))
	# the switch box by the deep end, and the door to the plant room
	K.box(self, Vector3(0.5, 0.7, 0.14), Vector3(PL / 2 + 2.6, 1.4, hz - 0.2), K.mat(Color("7a7c78")))
	for i in 6:
		K.box(self, Vector3(0.04, 0.12, 0.05), Vector3(PL / 2 + 2.42 + i * 0.07, 1.4, hz - 0.3), K.mat(Color("b08d4a")))
	K.box(self, Vector3(0.12, 2.1, 1.0), Vector3(hx - 0.2, 1.05, -4.0), K.mat("paint_cream", 1.0))
	K.tex_quad(self, "sign_receiving", 0.5, 0.1, Vector3(hx - 0.27, 2.25, -4.0), Vector3(0, -PI / 2, 0))
	if fog:
		# fire door open to the yard
		K.quad(self, 1.4, 2.2, Vector3(hx - 0.16, 1.1, 3.5), K.emis(Color("f0f2f0"), 1.0), Vector3(0, -PI / 2, 0))
		for j in 12:
			var fy := -DEEP + 0.3 + j * 0.28
			K.quad(self, PL, PW, Vector3(0, fy, 0), K.glass(Color("e8ecea"), 0.16 + j * 0.01), Vector3(-PI / 2, 0, 0))
		K.quad(self, PL + 0.3, PW + 0.3, Vector3(0, 0.06, 0), K.glass(Color("f4f6f4"), 0.3), Vector3(-PI / 2, 0, 0))
		for side2 in [1, -1]:
			for x2 in [4.0, 7.5, 11.0]:
				K.quad(self, 3.0, 3.0, Vector3(x2, -0.4, side2 * 3.2), K.glass(Color("d8f0ff"), 0.25), Vector3(-PI / 2, 0, 0))
	# the meeting: chairs round the deep end, everyone facing the chair
	chairs_group = Node3D.new()
	add_child(chairs_group)
	var target := Vector3(9.5, 0, 0)
	var spots: Array = []
	for i in 7:
		spots.append(Vector3(3.5 + i * 1.6, 0, PW / 2 + 0.9))
		spots.append(Vector3(3.5 + i * 1.6, 0, -PW / 2 - 0.9))
	for z in [-3.0, -1.0, 1.0, 3.0]:
		spots.append(Vector3(PL / 2 + 0.9, 0, z))
	var cols := [Color("d8702e"), Color("8a6a48"), Color("d8702e"), Color("4a6a8a"), Color("d8702e")]
	for i in spots.size():
		var p: Vector3 = spots[i]
		var ang := atan2(target.x - p.x, target.z - p.z)
		K.plastic_chair(chairs_group, p, ang + PI, cols[i % cols.size()])
	people = Node3D.new()
	chairs_group.add_child(people)
	var sat := [
		[spots[2], {"coat": Color("9ab0d0"), "trousers": Color("5a5a6a"), "skin": Color("e0c0a8"), "hair": Color("d8d4cc"), "hair_style": "set", "height": 1.55, "glasses": true}, "sit"],
		[spots[5], {"coat": Color("6a3a4a"), "trousers": Color("3a2a3a"), "skin": Color("6a4636"), "hair": Color("1a1412"), "hair_style": "bun", "height": 1.64}, "sit"],
		[spots[7], {"coat": Color("4a4a50"), "trousers": Color("2a2a30"), "skin": Color("5a3a2a"), "hair": Color("1a1412"), "hair_style": "short", "height": 1.74}, "sit"],
		[spots[8], {"coat": Color("7a6a8a"), "trousers": Color("4a4a4a"), "skin": Color("d8b8a8"), "hair": Color("b8a890"), "hair_style": "set", "height": 1.6}, "sit"],
		[spots[1], Figure.cast("jad"), "sit"],
	]
	for s in sat:
		var p2: Vector3 = s[0]
		var ang2 := atan2(target.x - p2.x, target.z - p2.z)
		K.person(people, p2, ang2, s[1], s[2])
	var standers := [
		[Vector3(PL / 2 + 1.8, 0, 2.2), {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"), "hair_style": "bald", "height": 1.84, "long_coat": true}],
		[Vector3(PL / 2 + 1.8, 0, -2.6), {"coat": Color("3e5a4e"), "trousers": Color("26262c"), "skin": Color("c89878"), "hair": Color("2a2420"), "hair_style": "short", "glasses": true, "height": 1.7, "arms": "forward"}],
		[Vector3(2.4, 0, PW / 2 + 1.2), {"coat": Color("3a4a5a"), "trousers": Color("3a4a5a"), "skin": Color("c8a088"), "hair": Color("b8b4ac"), "hair_style": "short", "height": 1.62}],
	]
	for s2 in standers:
		var p3: Vector3 = s2[0]
		K.person(people, p3, atan2(target.x - p3.x, target.z - p3.z), s2[1])
	# the speakerphone on the chair in the deep end
	var sp_mat := K.mat(Color("7a7c80"))
	var tri := K.cyl(chairs_group, 0.2, 0.2, 0.05, Vector3(9.5, -DEEP + 0.5, 0.0), sp_mat, 3)
	for i in 3:
		var a3 := TAU * i / 3.0
		K.sphere(chairs_group, 0.025, Vector3(9.5 + cos(a3) * 0.12, -DEEP + 0.53, sin(a3) * 0.12), K.mat(Color("222")), 5)
	K.cyl(chairs_group, 0.01, 0.01, DEEP + 0.4, Vector3(9.3, -DEEP / 2 + 0.2, 0.1), K.mat(Color("1a1a1a")), 4)
	chairs_group.visible = v == "meeting"
	if v == "meeting":
		# Inez's work lights on stands, pointed at the ceiling so the room fills
		for wp in [Vector3(PL / 2 + 2.2, 0, 6.5), Vector3(PL / 2 + 2.2, 0, -6.5), Vector3(2.0, 0, 7.0)]:
			K.cyl(self, 0.02, 0.02, 1.8, wp + Vector3(0, 0.9, 0), K.mat(Color("2a2a2a")), 5)
			K.box(self, Vector3(0.3, 0.22, 0.14), wp + Vector3(0, 1.85, 0), K.emis(Color("ffe8c0"), 1.0))
			K.omni(self, wp + Vector3(0, 2.4, 0), Color("ffe0b0"), 1.8, 14.0)
	# Teodor, walking lengths, when he's walking them
	walker = K.person(self, Vector3(5.2, -DEEP, -2.2), PI / 2, {"coat": Color("6a5a48"), "trousers": Color("3a3a3a"), "skin": Color("d8b8a0"), "hair": Color("c8c4bc"), "hair_style": "bald", "height": 1.84, "long_coat": true})
	walker.visible = false
	# Inez's head torch
	torch = K.spot(self, Vector3(PL / 2 + 1.0, 1.6, 5.8), Vector3(4, -2.5, -1), Color("fff4d8"), 0.0, 22.0, 18.0)
	cam_hide = {"meeting": [roof, sky] + near_walls, "main": near_walls}
	add_cam("main", Vector3(-15.5, 6.2, 10.5), Vector3(6.0, -1.8, 0.0), 52)
	_walk(hx, hz, near_walls)
	add_cam("inez_eye", Vector3(PL / 2 + 1.0, 1.62, 5.9), Vector3(4.0, -2.4, -1.2), 60)
	add_cam("deep", Vector3(6.2, -2.3, 3.0), Vector3(10.0, -2.8, -0.4), 60)
	add_cam("meeting", Vector3(9.5, 10.5, 12.5), Vector3(9.3, -2.2, 0.0), 44)
	add_cam("skylight", Vector3(9.0, 0.5, 0.0), Vector3(9.2, 8.0, 0.2), 70)
	add_cam("title", Vector3(6.4, -2.35, 2.6), Vector3(9.6, -2.6, -0.2), 46)
	if v == "meeting":
		apply_state("lights", "4")
		env.environment.ambient_light_energy = 0.9
	if fog:
		apply_state("lights", "4")

func apply_state(key: String, value: String) -> void:
	super.apply_state(key, value)
	match key:
		"lights":
			lights_on = int(value)
			for i in lamps.size():
				var on := i < lights_on
				lamps[i]["light"].light_energy = 4.5 if on else 0.0
				lamps[i]["glass"].transparency = 0.0 if on else 0.6
				for q in lamps[i]["pools"]:
					q.visible = on
			if env and variant == "":
				env.environment.ambient_light_energy = 0.55 + lights_on * 0.08
		"chairs":
			chairs_group.visible = value == "on"
		"teodor":
			walker.visible = value == "walk"
		"torch":
			torch.light_energy = 2.0 if value == "on" else 0.0

func _process(delta: float) -> void:
	_t += delta
	# the head torch goes where Inez goes, pointing where she's facing
	if states.get("torch", "") == "on" and actors.has("inez") and is_instance_valid(actors["inez"]):
		var f: Node3D = actors["inez"]
		var fwd := Vector3(sin(f.rotation.y), 0, cos(f.rotation.y))
		torch.position = f.position + Vector3(0, 1.62, 0) + fwd * 0.15
		torch.look_at(f.position + fwd * 5.0 + Vector3(0, -1.6, 0), Vector3.UP)
	if Settings.reduced_motion:
		return
	# old ballasts: the light wobbles like light through water
	for i in lamps.size():
		if i < lights_on:
			var l: SpotLight3D = lamps[i]["light"]
			l.light_energy = 4.2 + 0.6 * sin(_t * (2.1 + i * 0.37)) + 0.3 * sin(_t * 5.3 + i)
			for q in lamps[i]["pools"]:
				q.transparency = 0.15 + 0.12 * sin(_t * (1.3 + i * 0.29))
	if walker.visible:
		var ph := fmod(_t * 0.08, 2.0)
		var k := ph if ph < 1.0 else 2.0 - ph
		walker.position = Vector3(5.2 + k * 7.0, -DEEP, -2.2)
		walker.rotation.y = PI / 2 if ph < 1.0 else -PI / 2

## The deck round the basin is walkable; the basin isn't (it's a long way down).
func _walk(hx: float, hz: float, near_walls: Array) -> void:
	add_floor(Rect2(-hx + 0.3, PW / 2 + 0.35, hx * 2 - 0.6, hz - PW / 2 - 0.6))
	add_floor(Rect2(-hx + 0.3, -hz + 0.3, hx * 2 - 0.6, hz - PW / 2 - 0.65))
	add_floor(Rect2(-hx + 0.3, -PW / 2 - 0.5, hx - PL / 2 - 0.65, PW + 1.0))
	add_floor(Rect2(PL / 2 + 0.35, -PW / 2 - 0.5, hx - PL / 2 - 0.65, PW + 1.0))
	add_block(PL / 2 + 1.4, 0.0, 1.3, 1.5)  # the diving stand
	add_entry("frame_door", Vector3(hx - 0.9, 0, 6.6), -PI / 2)
	add_entry("receiving_door", Vector3(hx - 1.0, 0, -4.0), -PI / 2)
	add_entry("deep_edge", Vector3(9.5, 0, PW / 2 + 0.8), PI)
	add_hotspot("switchbox", Vector3(PL / 2 + 2.6, 1.4, hz - 0.2), Vector3(0.7, 0.9, 0.3), Vector3(PL / 2 + 2.6, 0, hz - 1.0), "The switch box", "use")
	add_hotspot("ladder", Vector3(PL / 2 - 0.25, -1.2, PW / 2 - 0.7), Vector3(0.5, 3.4, 0.9), Vector3(PL / 2 + 0.9, 0, PW / 2 - 0.7), "The ladder")
	add_hotspot("chair", Vector3(9.5, -DEEP + 0.45, 0.0), Vector3(0.7, 1.0, 0.7), Vector3(9.5, 0, PW / 2 + 0.8), "The chair in the deep end")
	add_hotspot("crisps", Vector3(-2.0, -1.4, 1.8), Vector3(0.5, 0.3, 0.4), Vector3(-2.0, 0, PW / 2 + 0.8), "The crisp packet")
	add_hotspot("g1_window", Vector3(-hx + 0.16, 4.7, -3.0), Vector3(0.3, 1.2, 1.8), Vector3(-hx + 1.4, 0, -3.0), "The lit window, high up")
	add_hotspot("receiving_door", Vector3(hx - 0.2, 1.05, -4.0), Vector3(0.3, 2.1, 1.1), Vector3(hx - 1.0, 0, -4.0), "The door with the enamel plate", "go")
	add_hotspot("shallow", Vector3(-8.0, -0.6, 0.0), Vector3(8.0, 1.2, PW - 1.0), Vector3(-8.0, 0, PW / 2 + 0.8), "The shallow end")
	walk_cam = {"offset": Vector3(0, 5.2, 6.8), "look": Vector3(0, 0.2, -1.2), "fov": 56.0,
		"min": Vector3(-12.0, 0, -3.5), "max": Vector3(14.5, 0, 3.0)}
	cam_hide["walk"] = near_walls
