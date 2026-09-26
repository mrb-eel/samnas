class_name Hud
extends Control
## The strip across the top: the time on a cheap LCD, the chapter on label
## tape, and three bakelite keys (the board, the transcript, the menu).
## Under it, room-sound captions on caption tape, and notices from the
## board that fade after a while.

signal board_pressed()
signal log_pressed()
signal menu_pressed()

const STRIP_H := 18.0

var clock := ""
var chapter := ""
var badge := 0
var board_locked := false
var hover_key := ""
var down_key := ""
var _keys: Dictionary = {}
var _caption := ""
var _caption_life := 0.0
var _toasts: Array = []  # [{title, body, life}]
var t := 0.0
var strip_visible := true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_clock(s: String) -> void:
	if s != clock and clock != "" and Game.playing:
		Audio.sfx("flap", -18.0)
	clock = s
	queue_redraw()

func set_chapter(s: String) -> void:
	chapter = s
	queue_redraw()

func set_badge(n: int, locked: bool) -> void:
	badge = n
	board_locked = locked
	queue_redraw()

func caption(s: String) -> void:
	_caption = s
	_caption_life = 7.0

func toast(title: String, body: String) -> void:
	_toasts.append({"title": title, "body": body, "life": 6.0})
	while _toasts.size() > 3:
		_toasts.pop_front()

func _process(d: float) -> void:
	t += d
	if _caption_life > 0.0:
		_caption_life -= d
	for x in _toasts:
		x["life"] -= d
	_toasts = _toasts.filter(func(x): return x["life"] > 0.0)
	queue_redraw()

func _has_point(p: Vector2) -> bool:
	if not strip_visible:
		return false
	for k in _keys:
		if _keys[k].has_point(p):
			return true
	return false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := ""
		for k in _keys:
			if _keys[k].has_point(e.position):
				h = k
		if h != hover_key:
			hover_key = h
			queue_redraw()
		if h != "":
			ScreenFx.want("use")
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			down_key = hover_key
		else:
			if down_key != "" and down_key == hover_key:
				Audio.sfx("key_throw", -10.0)
				match down_key:
					"board":
						board_pressed.emit()
					"log":
						log_pressed.emit()
					"menu":
						menu_pressed.emit()
			down_key = ""
		accept_event()

func _draw() -> void:
	_keys.clear()
	if strip_visible:
		_draw_strip()
	_draw_caption()
	_draw_toasts()

func _draw_strip() -> void:
	var r := Rect2(0, 0, size.x, STRIP_H)
	Grim.plate(self, r, "bakelite", 3.0, false)
	# the clock: a scratched LCD in a steel bezel
	var lr := Rect2(4, 2, 44, 14)
	Grim.inset(self, lr, Color("1b2014"))
	if not Grim.plain():
		draw_rect(lr.grow(-1), Color("3d4a2a"))
		Grim.text(self, Vector2(lr.position.x + 3, lr.end.y - 2), "88:88", "lcd", 17, Color(0, 0, 0, 0.12))
	Grim.text(self, Vector2(lr.position.x + 3, lr.end.y - 2), clock, "lcd", 17, Color("0c1006") if not Grim.plain() else Color.WHITE)
	# the chapter on label tape
	if chapter != "":
		Grim.dymo(self, Vector2(54, 2), chapter.to_upper(), 11, Color("5a1814"))
	# keys, right to left
	var x := size.x - 4
	for k in [["menu", "MENU", "ESC"], ["log", "LOG", "L"], ["board", "BOARD", "TAB"]]:
		var label: String = k[1]
		var w := Grim.text_w(label, "head", 16) + Grim.text_w(k[2], "tiny", 8) + 14
		x -= w
		var kr := Rect2(x, 2, w, 14)
		_keys[k[0]] = kr
		var hot: bool = hover_key == k[0]
		var dn: bool = down_key == k[0] and hot
		var disabled: bool = k[0] == "board" and board_locked
		Grim.inset(self, kr.grow(1), Grim.INK)
		draw_rect(kr, Color("2e2420") if not hot else Color("4a3a30"))
		draw_rect(Rect2(kr.position, Vector2(kr.size.x, 1)), Color(1, 1, 1, 0.12 if not dn else 0.0))
		var lc := Grim.IVORY if hot else Grim.IVORY_DIM
		if disabled:
			lc = Color(Grim.IVORY_DIM, 0.35)
		Grim.text(self, kr.position + Vector2(4, 12 + (1 if dn else 0)), label, "head", 16, lc)
		Grim.text(self, kr.position + Vector2(w - Grim.text_w(k[2], "tiny", 8) - 4, 11), k[2], "tiny", 8, Color(Grim.AMBER_DIM, 0.9))
		if k[0] == "board" and badge > 0:
			var c := Vector2(kr.position.x + 1, kr.position.y + 1)
			Grim.lamp(self, c, Grim.RED, int(t * 2.0) % 2 == 0 or Settings.reduced_motion, 2)
		x -= 4

func _draw_caption() -> void:
	if _caption_life <= 0.0 or _caption == "" or not Settings.ambient_captions:
		return
	var a := clampf(_caption_life / 1.0, 0.0, 1.0)
	var s := "~ " + _caption
	var w := Grim.text_w(s, "body", 16) + 12
	var r := Rect2(round((size.x - w) * 0.5), STRIP_H + 4, w, 15)
	draw_rect(r, Color(0.02, 0.05, 0.03, 0.85 * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(Grim.PHOS_DIM, 0.6 * a))
	Grim.text(self, r.position + Vector2(6, 12), s, "body", 16, Color(Grim.PHOS_MID, a))

func _draw_toasts() -> void:
	var y := STRIP_H + 4.0
	for x in _toasts:
		var a := clampf(float(x["life"]) / 0.8, 0.0, 1.0)
		var body := Grim.wrap_text(x["body"], "body", 16, 190)
		var h := 14.0 + body.size() * 13.0 + 4.0
		var r := Rect2(size.x - 210, y, 204, h)
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.5 * a))
		draw_rect(r, Color(Grim.PAPER, a))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 12)), Color(Grim.RED_DK, a))
		Grim.text(self, r.position + Vector2(4, 10), str(x["title"]).to_upper(), "tiny", 8, Color(Grim.IVORY, a))
		var yy := r.position.y + 24
		for l in body:
			Grim.text(self, Vector2(r.position.x + 5, yy), l, "body", 16, Color(Grim.INK, a))
			yy += 13
		y += h + 4
