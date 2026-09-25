extends Control
## Renders sets through the real Stage for art review.
##   godot --path . res://scenes/set_preview.tscn -- out_dir "set|variant|cam|view|k=v,k=v|WxH" ...
## view: none (seen), heard, plan, or a person id (draws that frame).

var stage: Stage

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	stage = Stage.new()
	add_child(stage)
	await get_tree().process_frame
	for spec in args.slice(1):
		var p: PackedStringArray = str(spec).split("|")
		var set_name := p[0]
		var variant := p[1] if p.size() > 1 else ""
		var cam := p[2] if p.size() > 2 else "main"
		var view := p[3] if p.size() > 3 else "jad"
		var states := p[4] if p.size() > 4 else ""
		var dims := p[5] if p.size() > 5 else "800x600"
		var wh := dims.split("x")
		stage.position = Vector2.ZERO
		stage.size = Vector2(float(wh[0]), float(wh[1]))
		stage.load_set("", "")
		stage.load_set(set_name, variant)
		stage.set_cam(cam)
		if states != "":
			for kv in states.split(";"):
				var parts := kv.split("=")
				stage.apply_state(parts[0], parts[1] if parts.size() > 1 else "on")
		if view == "heard":
			stage.set_view("none", true)
		else:
			stage.set_view(view, false)
		for i in 12:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img = img.get_region(Rect2i(0, 0, int(wh[0]), int(wh[1])))
		var name := "%s_%s_%s_%s" % [set_name, variant if variant != "" else "base", cam, view]
		if states != "":
			name += "_" + states.replace("=", "").replace(";", "_").replace(",", "")
		img.save_png(out.path_join(name + ".png"))
		print("PREVIEW ", name)
	get_tree().quit()
