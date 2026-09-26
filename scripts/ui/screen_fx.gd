class_name ScreenFx
extends RefCounted
## The last things drawn: the grime pass over the whole picture, and the
## pointer, which is part of the picture rather than the operating
## system's arrow.

const VERBS := ["point", "walk", "look", "listen", "ask", "use", "read", "go", "dial", "wait", "no"]
## Story verbs (choice tags) to the pointer that shows them.
const TAG_VERB := {
	"look": "look", "listen": "listen", "ask": "ask", "read": "read", "go": "go", "leave": "go",
	"dial": "dial", "call": "dial", "callback": "dial", "answer": "dial", "text": "read", "sign": "use",
	"hold": "use", "end": "use", "wait": "wait", "stay": "wait", "respect": "no", "decline": "no",
	"defer": "wait", "use": "use", "talk": "ask", "take": "use",
}

static var _verb := "point"
static var _label := ""
static var _frame := -1

## Anyone under the mouse says what the pointer should be this frame.
static func want(verb: String, label: String = "") -> void:
	_verb = verb
	_label = label
	_frame = Engine.get_process_frames()

static func verb_for_tags(tags: Array) -> String:
	for t in tags:
		if TAG_VERB.has(t):
			return TAG_VERB[t]
	return "use"

class Post extends ColorRect:
	var mat: ShaderMaterial
	var tear := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/grim_post.gdshader")
		material = mat
		Settings.changed.connect(_apply)
		_apply()
	func _apply() -> void:
		mat.set_shader_parameter("motion", 0.0 if Settings.reduced_motion else 1.0)
		mat.set_shader_parameter("plain", 1.0 if Settings.plain_text else 0.0)
		mat.set_shader_parameter("grain", 0.03 if Settings.reduced_motion else 0.045)
	func kick(amount: float) -> void:
		if Settings.reduced_motion:
			return
		tear = maxf(tear, amount)
	func _process(d: float) -> void:
		if tear > 0.0:
			tear = maxf(0.0, tear - d * 2.5)
			mat.set_shader_parameter("tear", tear)

class Pointer extends Control:
	var sheet: Texture2D
	var pos := Vector2(-100, -100)
	var shown_verb := "point"
	var shown_label := ""
	var press := 0.0
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet = load("res://assets/ui/grim/cursors.png")
		Settings.changed.connect(_apply)
		_apply()
	func _apply() -> void:
		if DisplayServer.get_name() == "headless":
			return
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Settings.plain_cursor else Input.MOUSE_MODE_HIDDEN
		visible = not Settings.plain_cursor
	func _input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			press = 1.0
	func _process(d: float) -> void:
		pos = get_local_mouse_position()
		press = maxf(0.0, press - d * 8.0)
		if Engine.get_process_frames() - ScreenFx._frame > 1:
			ScreenFx._verb = "point"
			ScreenFx._label = ""
		shown_verb = ScreenFx._verb
		shown_label = ScreenFx._label
		queue_redraw()
	func _draw() -> void:
		if not sheet:
			return
		var i := ScreenFx.VERBS.find(shown_verb)
		if i < 0:
			i = 0
		var hot := Vector2.ZERO if shown_verb == "point" else Vector2(8, 8)
		var p := (pos - hot).floor()
		if press > 0.0 and shown_verb != "point":
			p += Vector2(0, 1)
		draw_texture_rect_region(sheet, Rect2(p, Vector2(16, 16)), Rect2(i * 16, 0, 16, 16))
		if shown_label != "":
			var f := Grim.font("head")
			var w := f.get_string_size(shown_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var lp := p + Vector2(18, 12)
			if lp.x + w + 8 > size.x:
				lp.x = p.x - w - 10
			lp.y = clampf(lp.y, 2, size.y - 16)
			var r := Rect2(lp - Vector2(3, 11), Vector2(w + 7, 14)).abs()
			Grim.band(self, r, 0.85)
			draw_string(f, lp.round() + Vector2(1, 1), shown_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.8))
			draw_string(f, lp.round(), shown_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Grim.IVORY)
