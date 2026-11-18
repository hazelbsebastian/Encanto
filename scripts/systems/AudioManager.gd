extends Node
## Audio (autoload)
## Central playback for everything you hear:
##   play_sfx(name)          one-shot UI / gameplay sounds (pooled, can overlap)
##   play_3d(name, pos)      positional one-shot in the 3D world (creatures...)
##   play_voice(id)          spoken lines ("San ka punta?") - one at a time
##   play_music(name)        looping music track (cross-fades)
##   play_ambient(name)      looping location ambience (birds, waves...)
##   play_loop(name)         looping SFX such as the jeepney engine
## Separate buses (Music / Voice / SFX / Ambience) keep the mix balanced.

const SFX := {
	"click": "res://assets/audio/click.wav",
	"engine": "res://assets/audio/jeepney_engine.wav",
	"horn": "res://assets/audio/jeepney_horn.wav",
	"footstep": "res://assets/audio/footstep.wav",
	"jump": "res://assets/audio/jump.wav",
	"shoot": "res://assets/audio/shoot.wav",
	"charge": "res://assets/audio/charge.wav",
	"charge_release": "res://assets/audio/charge_release.wav",
	"enemy_attack": "res://assets/audio/enemy_attack.wav",
	"damage": "res://assets/audio/damage.wav",
	"puzzle_complete": "res://assets/audio/puzzle_complete.wav",
	"enemy_defeat": "res://assets/audio/enemy_defeat.wav",
	"victory": "res://assets/audio/victory.wav",
	"game_over": "res://assets/audio/game_over.wav",
	"puzzle_pickup": "res://assets/audio/puzzle_piece_pickup.wav",
	"coin": "res://assets/audio/coin.wav",
	"bayong_open": "res://assets/audio/bayong_open.wav",
	"wing_flap": "res://assets/audio/wing_flap.wav",
	"whoosh": "res://assets/audio/whoosh.wav",
	"gallop": "res://assets/audio/gallop.wav",
	"rock_hit": "res://assets/audio/rock_hit.wav",
	"tree_hit": "res://assets/audio/tree_hit.wav",
	"tree_fall": "res://assets/audio/tree_fall.wav",
	"smoke_puff": "res://assets/audio/smoke_puff.wav",
	"heartbeat": "res://assets/audio/heartbeat.wav",
	"ui_move": "res://assets/audio/ui_move.wav",
	"puzzle_swap": "res://assets/audio/puzzle_swap.wav",
	"gong": "res://assets/audio/gong.wav",
	"kulintang": "res://assets/audio/kulintang_flourish.wav",
	"land": "res://assets/audio/land.wav",
	"jeep_brake": "res://assets/audio/jeep_brake.wav",
	"lock_on": "res://assets/audio/lock_on.wav",
}

const LOOPS := {
	"music_explore": "res://assets/audio/music_explore.wav",
	"music_boss": "res://assets/audio/music_boss.wav",
	"music_title": "res://assets/audio/music_title.wav",
	"amb_countryside": "res://assets/audio/amb_countryside.wav",
	"amb_beach": "res://assets/audio/amb_beach.wav",
	"amb_city": "res://assets/audio/amb_city.wav",
	"amb_volcano": "res://assets/audio/amb_volcano.wav",
}

const VOICE_DIR := "res://assets/audio/voice/%s.wav"
const POOL_SIZE := 10
const BUSES := {"Music": -9.0, "Voice": 2.0, "SFX": -1.0, "Ambience": -8.0}

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _loop_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _music_name: String = ""
var _ambient_name: String = ""
var _last_scene: Node = null
var _quiet_until: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for key: String in SFX:
		var s := load(str(SFX[key])) as AudioStream
		if s:
			_streams[key] = s
	for i in range(POOL_SIZE):
		_pool.append(_make_player("SFX"))
	_loop_player = _make_player("SFX")
	_voice_player = _make_player("Voice")
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_ambient_player = _make_player("Ambience")
	# soft tick whenever keyboard/gamepad focus moves between buttons
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _setup_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), float(BUSES[bus_name]))

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func stream(name: String) -> AudioStream:
	return _streams.get(name, null) as AudioStream

# ------------------------------------------------------------ one-shots --
func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = s
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

## Positional sound in the current 3D scene (falls back to 2D if none).
func play_3d(name: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0, file_path: String = "") -> void:
	var s: AudioStream = load(file_path) as AudioStream if file_path != "" else stream(name)
	var scene := get_tree().current_scene
	if s == null:
		return
	if scene == null or not (scene is Node3D):
		play_sfx(name, volume_db, pitch)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 8.0
	p.max_distance = 60.0
	scene.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()

# --------------------------------------------------------------- voice --
## Speak a line from assets/audio/voice/. Returns its length in seconds
## (0 if the file is missing) so cutscenes can wait for it.
func play_voice(id: String, volume_db: float = 0.0) -> float:
	var path := VOICE_DIR % id
	if not ResourceLoader.exists(path):
		return 0.0
	var s := load(path) as AudioStream
	if s == null:
		return 0.0
	_voice_player.stream = s
	_voice_player.volume_db = volume_db
	_voice_player.play()
	return s.get_length()

func voice_3d(id: String, position: Vector3, volume_db: float = 3.0, pitch: float = 1.0) -> void:
	play_3d("", position, volume_db, pitch, VOICE_DIR % id)

# ------------------------------------------------------ music / ambience --
func play_music(name: String, fade: float = 1.2) -> void:
	if name == _music_name:
		return
	_music_name = name
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var s := _looping(name)
	if s:
		incoming.stream = s
		incoming.volume_db = -40.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		var tw := create_tween()
		tw.tween_property(outgoing, "volume_db", -40.0, fade)
		tw.tween_callback(outgoing.stop)

func stop_music(fade: float = 1.0) -> void:
	_music_name = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, fade)
			tw.tween_callback(p.stop)

func play_ambient(name: String) -> void:
	if name == _ambient_name and _ambient_player.playing:
		return
	_ambient_name = name
	var s := _looping(name)
	if s == null:
		_ambient_player.stop()
		return
	_ambient_player.stream = s
	_ambient_player.volume_db = -30.0
	_ambient_player.play()
	create_tween().tween_property(_ambient_player, "volume_db", 0.0, 1.5)

func stop_ambient() -> void:
	_ambient_name = ""
	_ambient_player.stop()

func play_loop(name: String, volume_db: float = -6.0) -> void:
	var s := stream(name)
	if s == null:
		return
	_make_loop(s)
	_loop_player.stream = s
	_loop_player.volume_db = volume_db
	_loop_player.play()

func stop_loop() -> void:
	_loop_player.stop()

func _looping(name: String) -> AudioStream:
	if not _streams.has(name) and LOOPS.has(name):
		var s := load(str(LOOPS[name])) as AudioStream
		if s:
			_make_loop(s)
			_streams[name] = s
	return stream(name)

func _make_loop(s: AudioStream) -> void:
	var wav := s as AudioStreamWAV
	if wav and wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)

# ------------------------------------------------------------- ui tick --
func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _last_scene:
		# new screen: its automatic focus grab shouldn't tick
		_last_scene = scene
		_quiet_until = Time.get_ticks_msec() / 1000.0 + 0.3

func _on_focus_changed(control: Control) -> void:
	if Time.get_ticks_msec() / 1000.0 < _quiet_until:
		return
	if control is BaseButton or control is Slider:
		play_sfx("ui_move", -6.0)
