class_name Music
extends Node
## Looping backing track for the menu and the match ("Steady Pulse", supplied by the user).
## One player on a "Music" bus, created lazily under the scene root so it keeps playing across
## screens. Volume / mute are separate from sound effects and persisted.

const TRACK := "res://assets/audio/music/steady_pulse.mp3"
const BUS := "Music"
const SETTINGS_PATH := "user://music_settings.cfg"
const DEFAULT_VOLUME := 0.45

static var _player: AudioStreamPlayer = null
static var _volume: float = DEFAULT_VOLUME
static var _muted: bool = false
static var _loaded: bool = false


## Starts the track if it is not already playing. Safe to call repeatedly.
static func start() -> void:
	load_settings()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if not is_instance_valid(_player):
		_ensure_bus()
		_player = AudioStreamPlayer.new()
		_player.name = "Music"
		_player.bus = BUS
		var stream := load(TRACK)
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_player.stream = stream
		tree.root.add_child.call_deferred(_player)
		_player.ready.connect(func(): _player.play())
		_apply()
	elif not _player.playing and _player.is_inside_tree():
		_player.play()


## Sets the music volume (linear 0..1, clamped) and persists it.
static func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	_apply()
	_save()


## Returns the music volume (linear 0..1).
static func get_volume() -> float:
	load_settings()
	return _volume


## Mutes/unmutes the music and persists the choice.
static func set_muted(on: bool) -> void:
	_muted = on
	_apply()
	_save()


## Returns whether the music is muted.
static func is_muted() -> bool:
	load_settings()
	return _muted


## Loads the persisted music settings once (later calls are no-ops).
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cf.get_value("music", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
		_muted = bool(cf.get_value("music", "muted", false))


static func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("music", "volume", _volume)
	cf.set_value("music", "muted", _muted)
	cf.save(SETTINGS_PATH)


static func _ensure_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	return idx


static func _apply() -> void:
	var idx := _ensure_bus()
	AudioServer.set_bus_mute(idx, _muted or _volume <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(_volume, 0.0001)))
