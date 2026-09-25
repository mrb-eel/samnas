extends Node
## Renders head-and-shoulders of each regular for the portrait cameos.
##   godot --path . res://scenes/portrait_render.tscn -- out_dir
## tools/art/gen_portraits.py prints them in two colours.

const WHO := {
	"jad": ["neutral", "worried", "smile"],
	"inez": ["neutral", "smile"],
	"dima": ["neutral", "smile", "worried"],
	"sal": ["neutral", "worried"],
	"teodor": ["neutral", "worried"],
	"kaye": ["neutral", "smile", "worried"],
	"nell": ["neutral", "worried", "smile"],
}
## a slight turn and tilt each, so they don't all sit for the same photographer
const TURN := {"jad": -0.32, "inez": 0.28, "dima": -0.22, "sal": 0.18, "teodor": 0.34, "kaye": -0.26, "nell": 0.24}

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	SetKit.smooth = true
	Figure.smooth_faces = true
	for id in WHO:
		for e in WHO[id]:
			await _shoot(id, e, out.path_join("%s_%s.png" % [id, e]))
	get_tree().quit()

func _shoot(id: String, expr: String, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 800)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a8c92")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var look := Figure.cast(id, {"expr": expr, "arms": "down", "head_turn": TURN.get(id, 0.0)})
	var f := Figure.build(root, Vector3.ZERO, 0.0, look)
	var head: Node3D = f.find_child("head", true, false)
	var hp := head.global_position
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 26.0
	cam.look_at_from_position(hp + Vector3(0.1, 0.03, 1.12), hp + Vector3(0, -0.085, 0), Vector3.UP)
	cam.current = true
	# key light high on the left, a cool fill, a rim from behind
	var key := OmniLight3D.new()
	key.position = hp + Vector3(-0.7, 0.5, 0.9)
	key.light_energy = 2.2
	key.omni_range = 4.0
	key.light_color = Color("fff2e0")
	root.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = hp + Vector3(0.9, -0.1, 0.6)
	fill.light_energy = 0.5
	fill.omni_range = 4.0
	fill.light_color = Color("c8d8ff")
	root.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = hp + Vector3(0.3, 0.3, -0.7)
	rim.light_energy = 1.4
	rim.omni_range = 3.0
	root.add_child(rim)
	for i in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("PORTRAIT ", path)
	vp.queue_free()
	await get_tree().process_frame
