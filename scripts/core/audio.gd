extends Node
## Autoload "Audio": ambience beds, effects, rare music, call acoustics.
##
## Sounds live in res://assets/audio/<id>.wav (or .ogg). Captions for ambient
## beds live in assets/audio/captions.json so silence never hides information.

signal caption(text: String)

const DIR := "res://assets/audio/"

var amb_a: AudioStreamPlayer
var amb_b: AudioStreamPlayer
var amb2: AudioStreamPlayer
var music: AudioStreamPlayer
var sfx_pool: Array = []
var captions: Dictionary = {}
var _amb_id := ""
var _amb2_id := ""
var _music_id := ""
var _far := false
var _cache: Dictionary = {}

func _ready() -> void:
	_make_buses()
	amb_a = _player("Amb")
	amb_b = _player("Amb")
	amb2 = _player("Amb")
	music = _player("Music")
	for i in 8:
		sfx_pool.append(_player("SFX"))
	if FileAccess.file_exists(DIR + "captions.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "captions.json"))
		if d is Dictionary:
			captions = d
	Settings.changed.connect(apply_volumes)
	apply_volumes()

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _make_buses() -> void:
	for name in ["Music", "SFX", "Amb", "Far"]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")
	# "Far" is the other end of a phone call: narrow band, a little room.
	var far := AudioServer.get_bus_index("Far")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 320.0
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3400.0
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.3
	rv.wet = 0.0
	rv.dry = 1.0
	AudioServer.add_bus_effect(far, hp)
	AudioServer.add_bus_effect(far, lp)
	AudioServer.add_bus_effect(far, rv)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Amb"), "Master")

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(Settings.master_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(max(Settings.music_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(Settings.sfx_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), linear_to_db(max(Settings.amb_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Far"), linear_to_db(max(Settings.amb_vol, 0.0001)))

func stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	for ext in [".wav", ".ogg"]:
		var p: String = DIR + id + ext
		if ResourceLoader.exists(p):
			var s: AudioStream = load(p)
			_cache[id] = s
			return s
	_cache[id] = null
	return null

func _loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	elif s is AudioStreamOggVorbis:
		s.loop = true

func sfx(id: String, volume_db: float = 0.0) -> void:
	var s := stream(id)
	if s == null:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.bus = "Far" if _far and id.begins_with("far_") else "SFX"
			p.play()
			return

func stop_sfx(id: String) -> void:
	var s := stream(id)
	for p in sfx_pool:
		if p.playing and p.stream == s:
			p.stop()

func set_amb(id: String, fade: float = 1.2) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	var old := amb_a
	amb_a = amb_b
	amb_b = old
	_fade_out(amb_b, fade)
	if id != "" and id != "off":
		var s := stream(id)
		if s:
			_loop(s)
			amb_a.stream = s
			amb_a.bus = "Far" if _far else "Amb"
			amb_a.volume_db = -40.0
			amb_a.play()
			create_tween().tween_property(amb_a, "volume_db", 0.0, fade)
		if Settings.ambient_captions and captions.has(id):
			caption.emit(captions[id])

func set_amb2(id: String) -> void:
	if id == _amb2_id:
		return
	_amb2_id = id
	if id == "" or id == "off":
		_fade_out(amb2, 0.8)
		return
	var s := stream(id)
	if s:
		_loop(s)
		amb2.stream = s
		amb2.bus = "Amb"
		amb2.volume_db = -40.0
		amb2.play()
		create_tween().tween_property(amb2, "volume_db", -4.0, 1.0)
	if Settings.ambient_captions and captions.has(id):
		caption.emit(captions[id])

func set_music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	if id == "" or id == "off":
		_fade_out(music, 2.0)
		return
	var s := stream(id)
	if s:
		_loop(s)
		music.stream = s
		music.volume_db = -30.0
		music.play()
		create_tween().tween_property(music, "volume_db", -3.0, 2.5)

func _fade_out(p: AudioStreamPlayer, t: float) -> void:
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, t)
	tw.tween_callback(p.stop)

## Calls route the far end's ambience through a narrow telephone band.
## Borrowing a view opens the band up: you're nearly there.
func set_far(active: bool, viewing: bool, acoustic: String) -> void:
	_far = active
	amb_a.bus = "Far" if active else "Amb"
	var far := AudioServer.get_bus_index("Far")
	var hp: AudioEffectHighPassFilter = AudioServer.get_bus_effect(far, 0)
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(far, 1)
	var rv: AudioEffectReverb = AudioServer.get_bus_effect(far, 2)
	hp.cutoff_hz = 90.0 if viewing else 320.0
	lp.cutoff_hz = 9000.0 if viewing else 3400.0
	match acoustic:
		"pool", "tiles":
			rv.room_size = 0.85
			rv.wet = 0.35
		"flat", "office":
			rv.room_size = 0.25
			rv.wet = 0.08
		"shop", "bakery", "lobby":
			rv.room_size = 0.5
			rv.wet = 0.15
		_:
			rv.room_size = 0.2
			rv.wet = 0.0

func stop_all() -> void:
	for p in [amb_a, amb_b, amb2, music]:
		p.stop()
	for p in sfx_pool:
		p.stop()
	_amb_id = ""
	_amb2_id = ""
	_music_id = ""
