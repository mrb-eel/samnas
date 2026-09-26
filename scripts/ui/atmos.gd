class_name Atmos
extends RefCounted
## What hangs between the player and everything else: the lamp over the
## frame, film grain, dust turning in the lamp's beam, the parallax of the
## wall, and Ari's red cord, which is the pointer. Choosing anything is
## plugging into it.

## Where the pointer is, smoothed, in -1..1 either way. Layers use it for
## parallax: the further back a layer is, the less it moves.
static var look := Vector2.ZERO

static func off(depth: float) -> Vector2:
	if Settings.reduced_motion:
		return Vector2.ZERO
	return -look * depth * 12.0

## Screens can say where the cord comes from (in viewport coordinates), and
## where the plug should rest when it isn't following the hand.
static var anchor_override := Vector2(-1, -1)
static var magnet := Vector2(-1, -1)

# ------------------------------------------------------------------ the air

class Air extends Control:
	var motes: Array = []
	var t := 0.0
	var grain_off := Vector2.ZERO
	var grain_t := 0.0
	var lamp: Control

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		lamp = _LampGlow.new()
		lamp.set_anchors_preset(Control.PRESET_FULL_RECT)
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		lamp.material = m
		add_child(lamp)
		for i in 34:
			motes.append({"p": Vector2(Kit.rnd(i, 1.0), Kit.rnd(i, 2.0)), "d": 0.3 + Kit.rnd(i, 3.0) * 0.9,
				"s": 0.6 + Kit.rnd(i, 4.0) * 1.8, "ph": Kit.rnd(i, 5.0) * TAU})

	func _process(delta: float) -> void:
		t += delta
		var vs := get_viewport_rect().size
		var mp := get_viewport().get_mouse_position()
		var target := Vector2(clampf(mp.x / maxf(vs.x, 1.0) * 2.0 - 1.0, -1, 1), clampf(mp.y / maxf(vs.y, 1.0) * 2.0 - 1.0, -1, 1))
		Atmos.look = Atmos.look.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
		if not Settings.reduced_motion:
			grain_t += delta
			if grain_t > 0.055:
				grain_t = 0.0
				grain_off = Vector2(randf() * 256.0, randf() * 256.0)
			for m in motes:
				m["p"] += Vector2(0.006, 0.004) * m["d"] * delta
				m["p"].y += sin(t * 0.4 + m["ph"]) * 0.0006
				if m["p"].x > 1.05:
					m["p"].x -= 1.1
				if m["p"].y > 1.05:
					m["p"].y -= 1.1
		queue_redraw()

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var vig := Kit.tex("res://assets/ui/vignette.png")
		if vig:
			draw_texture_rect(vig, Rect2(Vector2.ZERO, vs), false, Color(1, 1, 1, 0.55 if Settings.clean_text else 0.85))
		if Settings.clean_text:
			return
		var g := Kit.tex("res://assets/ui/grain.png")
		if g:
			draw_texture_rect_region(g, Rect2(Vector2.ZERO, vs), Rect2(grain_off, vs * 0.5), Color(1, 1, 1, 0.3))
		# dust, lit only where it crosses the lamp's beam
		var glow := Kit.tex("res://assets/ui/glow.png")
		if glow == null or Settings.reduced_motion:
			return
		var src := Vector2(vs.x * 0.12, -vs.y * 0.1)
		var axis := Vector2(0.62, 0.78).normalized()
		for m in motes:
			var p: Vector2 = m["p"] * vs + Atmos.off(m["d"] * 1.6)
			var rel := p - src
			var across := absf(rel.x * axis.y - rel.y * axis.x)
			var lit := clampf(1.0 - across / (vs.y * 0.34), 0.0, 1.0)
			if lit <= 0.02:
				continue
			var s: float = m["s"] * 3.0
			var tw := 0.6 + 0.4 * sin(t * 1.3 + m["ph"])
			draw_texture_rect(glow, Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(1.0, 0.92, 0.76, 0.35 * lit * tw))

class _LampGlow extends Control:
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var glow := Kit.tex("res://assets/ui/glow.png")
		if glow == null or Settings.clean_text:
			return
		var vs := get_viewport_rect().size
		var c := Vector2(vs.x * 0.12, -vs.y * 0.08) + Atmos.off(0.3)
		var r := vs.y * 1.15
		draw_texture_rect(glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.8, 0.52, 0.075))

# ------------------------------------------------------------------ the cord

## The pointer: Ari's red cord and its brass plug. The cord comes up from
## the board at the bottom of the screen; the plug's tip is the hotspot.
class Cord extends Control:
	const N := 22
	var pts: Array = []
	var prev: Array = []
	var tip := Vector2.ZERO
	var dir := Vector2(-0.45, -0.9).normalized()
	var alpha := 1.0
	var idle := 0.0
	var kbd := false
	var focus_target := Vector2(-1, -1)
	var hot := 0.0
	var press := 0.0
	var sparks: Array = []
	var _was_down := false
	var _ready_once := false

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_viewport().gui_focus_changed.connect(_on_focus)
		Settings.changed.connect(_apply_cursor)
		_apply_cursor()

	func _apply_cursor() -> void:
		if DisplayServer.get_name() == "headless":
			return
		if Settings.plain_cursor:
			for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM]:
				Input.set_custom_mouse_cursor(null, shape)
			return
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var t := ImageTexture.create_from_image(img)
		for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_MOVE, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_HELP, Input.CURSOR_FORBIDDEN, Input.CURSOR_BUSY, Input.CURSOR_WAIT]:
			Input.set_custom_mouse_cursor(t, shape)

	func _anchor() -> Vector2:
		if Atmos.anchor_override.x >= 0.0:
			return Atmos.anchor_override
		var vs := get_viewport_rect().size
		return Vector2(vs.x - 70.0, vs.y + 70.0)

	func _on_focus(c: Control) -> void:
		if c == null or not kbd:
			return
		var r := c.get_global_rect()
		focus_target = r.get_center()

	func _input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			kbd = false
			idle = 0.0
			focus_target = Vector2(-1, -1)
		elif e is InputEventKey or e is InputEventJoypadButton:
			if e.is_pressed():
				kbd = true
				idle = 0.0

	func _process(delta: float) -> void:
		var dt := clampf(delta, 0.001, 1.0 / 30.0)
		var a := _anchor()
		var target := get_viewport().get_mouse_position()
		if kbd and focus_target.x >= 0.0:
			target = focus_target + Vector2(0, -6)
		if Atmos.magnet.x >= 0.0 and not kbd:
			target = target.lerp(Atmos.magnet, 0.55)
		if not _ready_once:
			_ready_once = true
			tip = target
			for i in N:
				var p := a.lerp(target, float(i) / (N - 1))
				pts.append(p)
				prev.append(p)
		if Settings.reduced_motion or not kbd:
			tip = tip.lerp(target, 1.0 if Settings.reduced_motion else clampf(dt * 30.0, 0.0, 1.0))
		else:
			tip = tip.lerp(target, clampf(dt * 12.0, 0.0, 1.0))
		# the plug's body trails back from the tip toward the cord
		var tail := tip - dir * 44.0
		var span := a.distance_to(tail)
		var seg := maxf(span * 1.07, 90.0) / (N - 1)
		if Settings.reduced_motion:
			for i in N:
				var k := float(i) / (N - 1)
				pts[i] = a.lerp(tail, k) + Vector2(0, sin(k * PI) * span * 0.05)
		else:
			var g := Vector2(0, 1500.0) * dt * dt
			for i in range(1, N - 1):
				var cur: Vector2 = pts[i]
				var v: Vector2 = (cur - prev[i]) * 0.985
				prev[i] = cur
				pts[i] = cur + v + g
			pts[0] = a
			pts[N - 1] = tail
			for _it in 16:
				for i in range(N - 1):
					var p0: Vector2 = pts[i]
					var p1: Vector2 = pts[i + 1]
					var d := p1 - p0
					var l := d.length()
					if l < 0.0001:
						continue
					var corr := d * (1.0 - seg / l) * 0.5
					if i > 0:
						pts[i] = p0 + corr
					if i + 1 < N - 1:
						pts[i + 1] = p1 - corr
				pts[0] = a
				pts[N - 1] = tail
		var want: Vector2 = (tip - pts[N - 3]).normalized()
		if want.length() > 0.5:
			dir = dir.lerp(want, clampf(dt * 10.0, 0.0, 1.0)).normalized()
		# is the plug over something it could go into?
		var c := get_viewport().gui_get_hovered_control()
		var over := false
		if c and not kbd:
			over = c is BaseButton or bool(c.get_meta("plug", c.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND))
		if kbd and focus_target.x >= 0.0:
			over = true
		hot = lerpf(hot, 1.0 if over else 0.0, clampf(dt * 10.0, 0.0, 1.0))
		var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if down and not _was_down:
			press = 1.0
			if not Settings.reduced_motion:
				for i in 6:
					var ang := randf() * TAU
					sparks.append({"p": tip, "v": Vector2(cos(ang), sin(ang)) * (80.0 + randf() * 120.0), "life": 0.22})
		_was_down = down
		press = maxf(0.0, press - dt * 5.0)
		for s in sparks:
			s["p"] += s["v"] * dt
			s["life"] -= dt
		sparks = sparks.filter(func(s): return s["life"] > 0.0)
		idle += dt
		var want_a := 1.0 if (idle < 2.5 or over) else 0.28
		alpha = lerpf(alpha, want_a, clampf(dt * 3.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		if Settings.plain_cursor or pts.size() < N:
			return
		var line := PackedVector2Array(pts)
		line.append(tip - dir * 44.0)
		var sh := PackedVector2Array()
		for p in line:
			sh.append(p + Vector2(8, 13))
		draw_polyline(sh, Color(0, 0, 0, 0.22 * alpha), 9.0, true)
		draw_polyline(line, Color(Kit.CORD_DK, alpha), 7.5, true)
		draw_polyline(line, Color(Kit.CORD, alpha), 5.0, true)
		var hl := PackedVector2Array()
		for p in line:
			hl.append(p + Vector2(-1.2, -1.6))
		draw_polyline(hl, Color(0.95, 0.45, 0.38, 0.55 * alpha), 1.6, true)
		# the plug: rubber boot, brass sleeve, collar, tip
		var s := 1.0 + hot * 0.08 - press * 0.1
		var n := Vector2(-dir.y, dir.x)
		var base := tip - dir * 44.0 * s
		var boot0 := base
		var boot1 := tip - dir * 26.0 * s
		_seg(boot0 + Vector2(6, 10), boot1 + Vector2(6, 10), 7.0 * s, Color(0, 0, 0, 0.25 * alpha))
		_seg(boot0, boot1, 6.5 * s, Color(0.08, 0.07, 0.07, alpha))
		_seg(boot0 + n * 2.0, boot1 + n * 2.0, 1.4 * s, Color(1, 1, 1, 0.12 * alpha))
		var brass := Kit.BRASS.lerp(Kit.BRASS_LT, hot * 0.5)
		_seg(boot1, tip - dir * 9.0 * s, 4.6 * s, Color(brass, alpha))
		_seg(boot1 + n * 1.6, tip - dir * 9.0 * s + n * 1.6, 1.2 * s, Color(1, 1, 0.85, 0.5 * alpha))
		_seg(tip - dir * 11.0 * s, tip - dir * 8.0 * s, 5.8 * s, Color(Kit.BRASS_DK, alpha))
		_seg(tip - dir * 8.0 * s, tip, 2.6 * s, Color(brass.lightened(0.15), alpha))
		draw_circle(tip, 2.4 * s, Color(brass.lightened(0.3), alpha))
		if hot > 0.05:
			var glow := Kit.tex("res://assets/ui/glow.png")
			if glow:
				var r := 22.0
				draw_texture_rect(glow, Rect2(tip - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.8, 0.4, 0.45 * hot * alpha))
		for sp in sparks:
			var lp: float = sp["life"] / 0.22
			draw_line(sp["p"], sp["p"] - sp["v"] * 0.03, Color(1.0, 0.85, 0.5, lp), 1.5)

	func _seg(a: Vector2, b: Vector2, r: float, col: Color) -> void:
		draw_line(a, b, col, r * 2.0)
		draw_circle(a, r, col)
		draw_circle(b, r, col)
