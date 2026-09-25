extends SceneTree
## Minimal engine self-test: godot --headless -s res://scripts/tools/engine_test.gd -- <story.hmp>

func _init() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var game = load("res://scripts/core/game.gd").new()
	root.add_child(game)
	game.parser = StoryParser.new()
	game.parser.parse_files([path])
	print("errors: ", game.parser.errors)
	game.runner = StoryRunner.new()
	game.runner.setup(game.parser, game)
	var out: Array = []
	game.runner.line.connect(func(e): game._on_line(e); out.append("%s|%s|%s" % [e.kind, e.speaker, e.text]))
	game.runner.choices.connect(func(o): out.append("CHOICES " + str(o.map(func(x): return x.text))))
	game.runner.command.connect(func(n, a): game._on_command(n, a); out.append("CMD %s %s" % [n, a]))
	game.runner.runtime_error.connect(func(m): out.append("ERR " + m))
	game.runner.finished.connect(func(r): out.append("FIN " + r))
	game.reset_state()
	game.runner.start("start")
	var picks := [1, 0, 0, 0]
	var saved = null
	var guard := 0
	while game.runner.waiting != "end" and guard < 200:
		guard += 1
		match game.runner.waiting:
			"line":
				if saved == null and game.runner.last_line.get("text", "") == "I've got your bag.":
					saved = JSON.stringify(game.make_save())
				game.runner.advance()
			"choice":
				var p = picks.pop_front() if picks.size() > 0 else 0
				game.runner.choose(min(p, game.runner.current_options.size() - 1))
			"cmd":
				game.runner.resume()
	for l in out:
		print(l)
	print("thread: ", game.phone.contacts.jad.thread.map(func(m): return m.text))
	print("--- load test")
	out.clear()
	game.apply_save(JSON.parse_string(saved))
	print("after load waiting=", game.runner.waiting, " x=", game.vars.get("x"))
	for l in out:
		print(l)
	quit()
