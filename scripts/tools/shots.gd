extends Node
## Scripted screenshot harness.
## godot --path . -- --shots out_dir "new" "adv 3" "shot a" "choose 1" ...
## Commands: new | load N | adv N | choose I | shot NAME | wait S | board | doc ID | closedoc |
## cmd NAME ARGS... | jump KNOT | key NAME | untilchoice | play N (auto-advance N steps picking first choice)
## Walking: spot NAME (walk to a live hotspot and use it) | hover NAME | reveal on|off | walkxz X Z
## mouse X Y takes 640x360 coordinates.

var main
var out_dir := ""
var cmds: Array = []

func run(m, args: Array) -> void:
	main = m
	out_dir = args[0]
	cmds = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_go()

func _go() -> void:
	await get_tree().create_timer(0.5).timeout
	for c in cmds:
		var parts: PackedStringArray = str(c).split(" ", false)
		var op := parts[0]
		match op:
			"new":
				main._on_title_action("new")
			"load":
				main._close_title()
				main._load_slot(int(parts[1]))
			"adv":
				for i in int(parts[1]):
					await _settle()
					if Game.runner.waiting == "line":
						main.console.finish_typing()
						Game.runner.advance()
					elif Game.runner.waiting == "cmd":
						Game.runner.resume()
						for ch in main.overlay_root.get_children():
							ch.queue_free()
						main.overlay_open = false
			"choose":
				await _settle()
				if Game.runner.waiting == "choice":
					main._on_chosen(int(parts[1]))
			"untilchoice":
				var n := 0
				while Game.runner.waiting != "choice" and Game.runner.waiting != "end" and n < 300:
					await _settle()
					n += 1
					if Game.runner.waiting == "line":
						main.console.finish_typing()
						Game.runner.advance()
					elif Game.runner.waiting == "cmd":
						Game.runner.resume()
						for ch in main.overlay_root.get_children():
							ch.queue_free()
						main.overlay_open = false
			"until":
				# auto-play (first choice each time) until a choice inside KNOT
				var n3 := 0
				while n3 < 2000:
					await _settle()
					n3 += 1
					if Game.runner.waiting == "choice" and Game.parser.locate(Game.runner.pc)[0] == parts[1]:
						break
					match Game.runner.waiting:
						"line":
							main.console.finish_typing()
							Game.runner.advance()
						"choice":
							main._on_chosen(0)
						"cmd":
							Game.runner.resume()
							for ch in main.overlay_root.get_children():
								ch.queue_free()
							main.overlay_open = false
						_:
							break
			"play":
				for i in int(parts[1]):
					await _settle()
					match Game.runner.waiting:
						"line":
							main.console.finish_typing()
							Game.runner.advance()
						"choice":
							main._on_chosen(0)
						"cmd":
							Game.runner.resume()
							for ch in main.overlay_root.get_children():
								ch.queue_free()
							main.overlay_open = false
			"shot":
				await _settle()
				await get_tree().create_timer(0.35).timeout
				main.console.finish_typing()
				await get_tree().process_frame
				await get_tree().process_frame
				var img := get_viewport().get_texture().get_image()
				if img.get_width() < 1000:
					img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
				img.save_png(out_dir.path_join(parts[1] + ".png"))
				print("SHOT ", parts[1], " waiting=", Game.runner.waiting, " at ", Game.parser.locate(Game.runner.pc))
			"wait":
				await get_tree().create_timer(float(parts[1])).timeout
			"board":
				main._toggle_board()
			"doc":
				main._open_doc(parts[1], false)
			"mouse":
				var k := Vector2(DisplayServer.window_get_size()) / Vector2(640, 360)
				var wp := Vector2(float(parts[1]), float(parts[2])) * k
				Input.warp_mouse(wp)
				var mm := InputEventMouseMotion.new()
				mm.position = wp
				mm.global_position = wp
				Input.parse_input_event(mm)
			"spot":
				await _settle()
				if main.stage.walk_spots.has(parts[1]):
					main.stage._go_spot(parts[1])
					var n := 0
					while Game.runner.waiting == "choice" and n < 600:
						await get_tree().process_frame
						n += 1
				else:
					print("NO LIVE SPOT ", parts[1], " live=", main.stage.walk_spots.keys())
			"hover":
				main.stage.hover_spot = parts[1]
				main.stage.marks.queue_redraw()
				var ws: Dictionary = main.stage.walk_spots.get(parts[1], {})
				ScreenFx.want(ws.get("verb", "look"), ws.get("label", ""))
			"reveal":
				main.stage.reveal = parts[1] == "on"
				main.stage.marks.queue_redraw()
			"walkxz":
				var dest := Vector3(float(parts[1]), 0.0, float(parts[2]))
				var w: Walker = main.stage.walker
				if w:
					w.go(main.stage.nav.path(w.fig.position, main.stage.nav.nearest(dest)))
					var n2 := 0
					while w.moving and n2 < 900:
						await get_tree().process_frame
						n2 += 1
			"pause":
				main._open_pause()
			"menu":
				# open a menu directly: save | load | settings | log
				match parts[1]:
					"save": main._open_saveload(true)
					"load": main._open_saveload(false)
					"settings": main._open_settings()
					"log": main._open_backlog()
			"closemenu":
				for ch in main.menu_root.get_children():
					if ch != main.title_screen:
						ch.queue_free()
				main.menu_open = false
			"closedoc":
				for ch in main.overlay_root.get_children():
					ch.queue_free()
				main.overlay_open = false
			"cmd":
				# a raw script command, as if the story had issued it: cmd comp exchange
				Game._on_command(parts[1], Array(parts.slice(2)))
			"jump":
				# start the story at a knot, with whatever state the game has
				for ch in main.overlay_root.get_children():
					ch.queue_free()
				main.overlay_open = false
				Game.runner.start(parts[1])
			"key":
				var ev := InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(parts[1])
				ev.pressed = true
				Input.parse_input_event(ev)
				await get_tree().process_frame
				var ev2 := ev.duplicate()
				ev2.pressed = false
				Input.parse_input_event(ev2)
			"save":
				Game.save_to(int(parts[1]))
			"var":
				print("VAR ", parts[1], "=", Game.vars.get(parts[1]))
	get_tree().quit()

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
