# SoundManager (autoload): 8-bit sound effects + looping chiptune music.
# Assets come from tools/chiptune.py (Assets/Audio/sfx/*.wav, music/*.wav).
# - play("coin") fires a one-shot on a small voice pool (slight pitch jitter).
# - play_music("battle") crossfades to a looping track.
# - Every Button with text gets a click (and a soft hover tick) automatically;
#   set_meta("no_ui_sfx", true) on a button to opt out.
# - M toggles mute. Volumes persist in user://audio.cfg.
extends Node

const SFX_DIR := "res://Assets/Audio/sfx/%s.wav"
const MUSIC_DIR := "res://Assets/Audio/music/%s.wav"
const VOICES := 10
const FADE_SEC := 0.8
const CFG_PATH := "user://audio.cfg"

var music_volume_db: float = -10.0
var sfx_volume_db: float = -4.0
var muted: bool = false

signal mute_changed(is_muted: bool)

var _streams: Dictionary = {}
var _voices: Array = []
var _next_voice: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name: String = ""
var _last_played: Dictionary = {} # name -> msec, to thin out rapid repeats

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load_cfg()
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for mp in [_music_a, _music_b]:
		mp.bus = "Music"
		mp.volume_db = -80.0
		add_child(mp)
	_apply_volumes()
	get_tree().node_added.connect(_on_node_added)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_volume_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_volume_db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func _load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		music_volume_db = float(cfg.get_value("audio", "music_db", music_volume_db))
		sfx_volume_db = float(cfg.get_value("audio", "sfx_db", sfx_volume_db))
		muted = bool(cfg.get_value("audio", "muted", muted))

func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_db", music_volume_db)
	cfg.set_value("audio", "sfx_db", sfx_volume_db)
	cfg.set_value("audio", "muted", muted)
	cfg.save(CFG_PATH)

func set_muted(on: bool) -> void:
	muted = on
	_apply_volumes()
	_save_cfg()
	mute_changed.emit(muted)

func toggle_mute() -> void:
	set_muted(not muted)

func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path) as AudioStream
	_streams[path] = st
	return st

# One-shot sound effect. min_gap_ms drops repeats of the same sound fired
# closer together than that (e.g. 10 rifles in one frame).
func play(sfx_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.04, min_gap_ms: int = 35) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -100000)) < min_gap_ms:
		return
	_last_played[sfx_name] = now
	var st := _stream(SFX_DIR % sfx_name)
	if st == null:
		return
	var p: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

func play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	var st := _stream(MUSIC_DIR % track)
	if st is AudioStreamWAV:
		# Loop the whole file (the WAV also carries a smpl loop chunk).
		var wav := st as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var out_p := _music_a if _music_a.playing else _music_b
	var in_p := _music_b if out_p == _music_a else _music_a
	if not out_p.playing:
		out_p = null
	in_p.stream = st
	in_p.volume_db = -40.0
	if st != null:
		in_p.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(in_p, "volume_db", 0.0, FADE_SEC)
	if out_p != null:
		tw.tween_property(out_p, "volume_db", -60.0, FADE_SEC)
		tw.chain().tween_callback(out_p.stop)

func stop_music() -> void:
	_music_name = ""
	for mp in [_music_a, _music_b]:
		if mp.playing:
			var tw := create_tween()
			tw.tween_property(mp, "volume_db", -60.0, FADE_SEC)
			tw.tween_callback(mp.stop)

# A "Sound: On/Off" toggle button that stays in sync with the M key.
func make_toggle_button() -> Button:
	var b := Button.new()
	b.name = "SoundToggle"
	b.focus_mode = Control.FOCUS_NONE
	var sync := func(): b.text = "Sound: Off" if muted else "Sound: On"
	sync.call()
	b.pressed.connect(func():
		toggle_mute()
		sync.call())
	var on_mute := func(_m): sync.call()
	mute_changed.connect(on_mute)
	# the autoload outlives scenes: drop the connection when the button goes away
	b.tree_exiting.connect(func():
		if mute_changed.is_connected(on_mute):
			mute_changed.disconnect(on_mute))
	return b

func _on_node_added(node: Node) -> void:
	if node is Button:
		var b := node as Button
		b.pressed.connect(func():
			if not b.has_meta("no_ui_sfx") and b.text != "":
				play("ui_click", -2.0, 0.02))
		b.mouse_entered.connect(func():
			if not b.has_meta("no_ui_sfx") and b.text != "" and not b.disabled:
				play("ui_hover", -8.0, 0.0, 60))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M:
		toggle_mute()
		get_viewport().set_input_as_handled()
