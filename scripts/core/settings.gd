extends Node
## Autoload "Settings": player preferences, input actions.

signal changed()

const PATH := "user://settings.cfg"
const TEXT_SIZES := [18, 21, 24, 28]
const TEXT_SIZE_NAMES := ["Small", "Medium", "Large", "Extra large"]

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

func _ready() -> void:
	_setup_input()
	load_settings()
	apply_window()

func font_size() -> int:
	return TEXT_SIZES[clampi(text_size, 0, TEXT_SIZES.size() - 1)]

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
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)

func _setup_input() -> void:
	_bind("advance", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_bind("phone", [KEY_P, KEY_TAB])
	_bind("log", [KEY_L])
	_bind("menu", [KEY_ESCAPE])
	_bind("quicksave", [KEY_F5])
	_bind("quickload", [KEY_F9])
	_bind("ui_choice_up", [KEY_UP, KEY_W])
	_bind("ui_choice_down", [KEY_DOWN, KEY_S])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
