extends Node
## Renders the archive photographs at full size, without the stage's dither.
##   godot --path . res://scenes/photo_render.tscn -- out_dir
## tools/art/gen_photos.py turns the renders into prints.

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	SetKit.smooth = true
	Figure.smooth_faces = true
	for k in 3:
		await _shoot("photo_1958", Vector2i(1390, 1000), out.path_join("photo_1958_%d.png" % k), {"blur": str(k)})
	await _shoot("photo_1965", Vector2i(1600, 800), out.path_join("photo_1965.png"), {})
	get_tree().quit()

func _shoot(set_name: String, size: Vector2i, path: String, states: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var s: SetBase = load("res://scripts/sets/set_%s.gd" % set_name).new()
	vp.add_child(s)
	s.build("")
	for k in states:
		s.apply_state(k, states[k])
	var c := s.cam("main")
	c.current = true
	s.on_cam("main")
	for i in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("PHOTO ", path)
	vp.queue_free()
	await get_tree().process_frame
