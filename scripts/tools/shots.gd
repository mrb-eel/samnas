extends Node
## Scripted screenshot harness.
## godot --path . -- --shots out_dir "new" "adv 3" "shot a" "choose 1" ...
## Commands: new | load N | adv N | choose I | shot NAME | wait S | phone | key NAME | untilchoice | play N (auto-advance N steps picking first choice)

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
						main.feed.finish_typing()
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
						main.feed.finish_typing()
						Game.runner.advance()
					elif Game.runner.waiting == "cmd":
						Game.runner.resume()
						for ch in main.overlay_root.get_children():
							ch.queue_free()
						main.overlay_open = false
			"play":
				for i in int(parts[1]):
					await _settle()
					match Game.runner.waiting:
						"line":
							main.feed.finish_typing()
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
				main.feed.finish_typing()
				await get_tree().process_frame
				await get_tree().process_frame
				var img := get_viewport().get_texture().get_image()
				img.save_png(out_dir.path_join(parts[1] + ".png"))
				print("SHOT ", parts[1], " waiting=", Game.runner.waiting, " at ", Game.parser.locate(Game.runner.pc))
			"wait":
				await get_tree().create_timer(float(parts[1])).timeout
			"phone":
				main._toggle_phone()
			"save":
				Game.save_to(int(parts[1]))
			"var":
				print("VAR ", parts[1], "=", Game.vars.get(parts[1]))
	get_tree().quit()

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
