extends Node
## Autoload "Settings": player preferences, input actions.

signal changed()

const PATH := "user://settings.cfg"
const TEXT_SIZES := [18, 21, 24, 28]
const TEXT_SIZE_NAMES := ["Small", "Medium", "Large", "Extra large"]
## Body text on the 640x360 grid: the pixel face at sizes where its pixels
## land on whole pixels, and the plain face at roughly the same x-height.
const PIXEL_SIZES := [16, 20, 24, 32]
const PLAIN_SIZES := [11, 13, 15, 18]

var text_size := 1
var text_speed := 0.55  # 0 slow .. 1 fast
var instant_text := false
var reduced_motion := false
var clean_text := false
var ambient_captions := true
var master_vol := 0.9
var music_vol := 0.8
var sfx_vol := 0.9
var amb_vol := 0.8
var fullscreen := false
var plain_cursor := false
## Accessibility: legible type instead of the pixel faces, drawn at the
## window's own resolution, with no scanlines or flicker on words.
var plain_text := false
## Always mark every clickable thing in a room (otherwise: hold H).
var show_hotspots := false
## The world's resolution: 0 = 320x180, 1 = 640x360.
var world_res := 1

func _ready() -> void:
	_setup_input()
	load_settings()
	apply_window()

func font_size() -> int:
	return TEXT_SIZES[clampi(text_size, 0, TEXT_SIZES.size() - 1)]

func body_px() -> int:
	var i := clampi(text_size, 0, PIXEL_SIZES.size() - 1)
	return PLAIN_SIZES[i] if plain_text else PIXEL_SIZES[i]

func chars_per_second() -> float:
	return lerp(22.0, 140.0, text_speed)

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	text_size = cf.get_value("text", "size", text_size)
	text_speed = cf.get_value("text", "speed", text_speed)
	instant_text = cf.get_value("text", "instant", instant_text)
	clean_text = cf.get_value("text", "clean", clean_text)
	ambient_captions = cf.get_value("text", "ambient_captions", ambient_captions)
	reduced_motion = cf.get_value("display", "reduced_motion", reduced_motion)
	fullscreen = cf.get_value("display", "fullscreen", fullscreen)
	plain_cursor = cf.get_value("display", "plain_cursor", plain_cursor)
	plain_text = cf.get_value("text", "plain", plain_text)
	show_hotspots = cf.get_value("display", "show_hotspots", show_hotspots)
	world_res = cf.get_value("display", "world_res", world_res)
	master_vol = cf.get_value("audio", "master", master_vol)
	music_vol = cf.get_value("audio", "music", music_vol)
	sfx_vol = cf.get_value("audio", "sfx", sfx_vol)
	amb_vol = cf.get_value("audio", "amb", amb_vol)

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("text", "size", text_size)
	cf.set_value("text", "speed", text_speed)
	cf.set_value("text", "instant", instant_text)
	cf.set_value("text", "clean", clean_text)
	cf.set_value("text", "ambient_captions", ambient_captions)
	cf.set_value("display", "reduced_motion", reduced_motion)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "plain_cursor", plain_cursor)
	cf.set_value("text", "plain", plain_text)
	cf.set_value("display", "show_hotspots", show_hotspots)
	cf.set_value("display", "world_res", world_res)
	cf.set_value("audio", "master", master_vol)
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.set_value("audio", "amb", amb_vol)
	cf.save(PATH)

func set_and_save(key: String, value) -> void:
	set(key, value)
	save_settings()
	apply_window()
	changed.emit()

func apply_window() -> void:
	var tree := get_tree()
	if tree and tree.root:
		# pixel mode draws everything on the 640x360 grid and scales it up;
		# plain text draws at the window's resolution so words stay sharp
		tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if plain_text else Window.CONTENT_SCALE_MODE_VIEWPORT
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)

func _setup_input() -> void:
	_bind("advance", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_bind("board", [KEY_TAB, KEY_B])
	_bind("log", [KEY_L])
	_bind("menu", [KEY_ESCAPE])
	_bind("quicksave", [KEY_F5])
	_bind("quickload", [KEY_F9])
	_bind("ui_choice_up", [KEY_UP, KEY_W])
	_bind("ui_choice_down", [KEY_DOWN, KEY_S])
	_bind("reveal", [KEY_H])
	_bind("spot_next", [KEY_E, KEY_RIGHT])
	_bind("spot_prev", [KEY_Q, KEY_LEFT])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
