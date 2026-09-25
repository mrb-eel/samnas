extends Node
## Renders the 3D pieces of the chapter 4 collage (who everyone thinks Ari is).
##   godot --path . res://scenes/collage_render.tscn -- out_dir
## tools/art/gen_collage.py cuts them out and prints them.

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	SetKit.smooth = true
	Figure.smooth_faces = true
	await _shoot("chair_phone", Vector2i(700, 800), out, true)
	await _shoot("kaye_glasses", Vector2i(640, 720), out, true)
	await _shoot("teodor_coat", Vector2i(520, 900), out, true)
	await _shoot("june_friend", Vector2i(900, 700), out, false)
	await _shoot("attendant_cap", Vector2i(600, 640), out, true)
	get_tree().quit()

func _light(root: Node3D, pos: Vector3, energy: float, col: Color = Color("fff4e8"), rng: float = 5.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.light_color = col
	l.omni_range = rng
	root.add_child(l)

func _shoot(what: String, size: Vector2i, out: String, clear: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.transparent_bg = clear
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR if clear else Environment.BG_COLOR
	e.background_color = Color("6a5a4a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a8c92")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var K := SetKit
	var cam := Camera3D.new()
	root.add_child(cam)
	match what:
		"chair_phone":
			K.chair(root, Vector3.ZERO, 0.4, K.mat(Color("8a6a48")), K.mat(Color("6a4e34")))
			var sp := K.cyl(root, 0.17, 0.17, 0.05, Vector3(0.0, 0.5, 0.02), K.mat(Color("5a5c60")), 3)
			sp.rotation.y = 0.3
			for i in 3:
				var a := TAU * i / 3.0 + 0.3
				K.sphere(root, 0.022, Vector3(cos(a) * 0.1, 0.53, 0.02 + sin(a) * 0.1), K.mat(Color("1a1a1a")), 6)
			var cable := K.cyl(root, 0.008, 0.008, 0.6, Vector3(0.12, 0.25, -0.1), K.mat(Color("141414")), 5)
			cable.rotation.z = 0.35
			cam.fov = 34.0
			cam.look_at_from_position(Vector3(1.1, 1.25, 1.6), Vector3(0, 0.45, 0), Vector3.UP)
			_light(root, Vector3(-1.0, 2.0, 1.4), 2.0)
			_light(root, Vector3(1.2, 0.6, -0.8), 0.9, Color("c8d8ff"))
		"kaye_glasses":
			# the young lady from the council: short fair hair, red glasses
			var look := {"coat": Color("2a4a7a"), "skin": Color("e8c8b0"), "hair": Color("d8c088"), "hair_style": "short", "shape": "f",
				"glasses": true, "glasses_color": Color("c81e1e"), "expr": "smile", "height": 1.66, "head_turn": 0.25}
			var f := Figure.build(root, Vector3.ZERO, 0.0, look)
			var hp: Vector3 = f.find_child("head", true, false).global_position
			cam.fov = 24.0
			cam.look_at_from_position(hp + Vector3(0.12, 0.04, 1.1), hp + Vector3(0, -0.08, 0), Vector3.UP)
			_light(root, hp + Vector3(-0.6, 0.5, 0.9), 2.0)
			_light(root, hp + Vector3(0.8, 0.0, 0.5), 0.6, Color("d0e0ff"))
			_light(root, hp + Vector3(0.2, 0.3, -0.7), 1.2)
		"teodor_coat":
			# a tall young man in a long brown coat: Mikael at nineteen
			var look2 := {"coat": Color("6a4a30"), "trousers": Color("2a2a2a"), "skin": Color("dcbca4"), "hair": Color("3a2a1c"), "hair_style": "short",
				"shape": "m", "long_coat": true, "height": 1.9, "build": 0.95, "head_turn": -0.2}
			Figure.build(root, Vector3.ZERO, -0.15, look2)
			cam.fov = 30.0
			cam.look_at_from_position(Vector3(0.2, 0.9, 4.0), Vector3(0, 0.98, 0), Vector3.UP)
			_light(root, Vector3(-1.5, 2.5, 2.0), 2.4, Color("fff4e0"), 8.0)
			_light(root, Vector3(1.5, 1.0, -1.0), 1.0, Color("fff4e0"), 6.0)
		"june_friend":
			# a snapshot: Jad and a friend, at somebody's party
			var wall := K.box(root, Vector3(4, 3, 0.1), Vector3(0, 1.5, -0.8), K.mat("wallpaper_green", 1.4))
			wall.name = "wall"
			Figure.build(root, Vector3(-0.28, 0, 0), 0.15, Figure.cast("jad", {"expr": "smile", "head_turn": 0.2}))
			Figure.build(root, Vector3(0.32, 0, -0.05), -0.2, {"coat": Color("8a3a2a"), "skin": Color("c89878"), "hair": Color("4a3020"),
				"hair_style": "short", "shape": "m", "height": 1.8, "expr": "smile", "head_turn": -0.25})
			cam.fov = 40.0
			cam.look_at_from_position(Vector3(0.05, 1.55, 1.6), Vector3(0.02, 1.42, 0), Vector3.UP)
			_light(root, Vector3(0.1, 1.6, 1.5), 2.4, Color("fffaf0"), 6.0)
		"attendant_cap":
			var look3 := {"coat": Color("22262e"), "skin": Color("d0b098"), "hair": Color("2a2420"), "hair_style": "cap", "cap_color": Color("1c2028"),
				"shape": "m", "face": "attendant", "height": 1.76, "head_turn": 0.35}
			var f3 := Figure.build(root, Vector3.ZERO, 0.0, look3)
			var hp3: Vector3 = f3.find_child("head", true, false).global_position
			cam.fov = 24.0
			cam.look_at_from_position(hp3 + Vector3(0.1, 0.06, 1.05), hp3 + Vector3(0, -0.04, 0), Vector3.UP)
			_light(root, hp3 + Vector3(-0.6, 0.6, 0.9), 2.0)
			_light(root, hp3 + Vector3(0.3, 0.3, -0.7), 1.2)
	cam.current = true
	for i in 6:
		await RenderingServer.frame_post_draw
	var path := out.path_join(what + ".png")
	vp.get_texture().get_image().save_png(path)
	print("COLLAGE ", path)
	vp.queue_free()
	await get_tree().process_frame
