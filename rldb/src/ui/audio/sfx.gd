class_name Sfx
extends Node
## Presentation-only sound effects (F02-13). Never touches game state or network rules.
## Voices live on one lazily created node under the scene-tree root and play on an "SFX"
## bus created at runtime. Sounds are rate-limited so multi-effect sequences stay readable.
## Only public presentation events are mapped (positions/amounts, never card identities).

const DIR := "res://assets/audio/sfx/"
const BUS := "SFX"
const SETTINGS_PATH := "user://audio_settings.cfg"
const NAMES: PackedStringArray = [
	"card_draw", "card_play", "card_set", "summon", "select", "confirm", "cancel", "deny",
	"attack", "impact", "damage", "heal", "destroy", "buff", "debuff", "turn", "phase",
	"notice", "victory", "defeat", "exhaust", "fuse", "ritual", "arcane", "victory_big",
	"boom", "charge",
]
const POOL_SIZE := 8
const MIN_INTERVAL_MS := 70
const BURST_MAX := 4
const BURST_WINDOW_MS := 120
const DEFAULT_VOLUME := 0.7

static var _instance: Sfx = null
static var _voices: Array[AudioStreamPlayer] = []
static var _streams: Dictionary = {}
static var _last_by_name: Dictionary = {}
static var _recent_starts: Array[int] = []
static var _volume: float = DEFAULT_VOLUME
static var _muted: bool = false
static var _loaded: bool = false
## Names of sounds actually started (bounded; dev/QA verification only).
static var debug_played: Array[String] = []


## Plays sound `name` at `volume_db` with random pitch jitter (+/- fraction).
## Safe no-op if muted, unknown, rate-limited, or the scene tree is not available yet.
static func play(name: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	if name == "" or not NAMES.has(name):
		return
	if not _loaded:
		load_settings()
	if _muted:
		return
	var stream: AudioStream = _stream_for(name)
	if stream == null:
		return
	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		return
	if not _allow(name, Time.get_ticks_msec()):
		return
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()
	debug_played.append(name)
	if debug_played.size() > 200:
		debug_played.remove_at(0)


## Maps a public presentation event `e` (a log `fx` entry) to a sound name, or "" for silence.
## `me` is the local player index (used for victory/defeat perspective).
static func for_fx(e: Dictionary, me: int) -> String:
	match String(e.get("k", "")):
		"draw":
			return "card_draw"
		"play":
			return "card_set" if String(e.get("zone", "")) == "backrow" else "card_play"
		"summon":
			return "summon"
		"attack":
			return "attack"
		"hp":
			return "heal" if float(e.get("d", 0)) > 0.0 else "damage"
		"destroy":
			return "exhaust" if String(e.get("dest", "spent")) == "exhaust" else "destroy"
		"exhaust":
			return "exhaust"
		"status":
			var s: String = String(e.get("s", ""))
			return "buff" if (s == "rune" or CardDB.is_buff(s)) else "debuff"
		"turn":
			return "turn"
		"phase":
			return "phase"
		"game_over":
			return "victory" if int(e.get("winner", -1)) == me else "defeat"
	return ""


## Sets master SFX volume (linear 0..1, clamped) and persists it.
static func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	_apply_bus()
	_save()


## Returns the master SFX volume (linear 0..1).
static func get_volume() -> float:
	return _volume


## Mutes/unmutes all SFX and persists the choice.
static func set_muted(on: bool) -> void:
	_muted = on
	_apply_bus()
	_save()


## Returns whether SFX are muted.
static func is_muted() -> bool:
	return _muted


## Loads persisted settings (defaults: volume 0.7, unmuted) and applies them to the bus.
static func load_settings() -> void:
	_loaded = true
	_volume = DEFAULT_VOLUME
	_muted = false
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cf.get_value("audio", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
		_muted = bool(cf.get_value("audio", "muted", false))
	_apply_bus()


## Rate limiter with injectable clock: false if `name` repeated within MIN_INTERVAL_MS or more
## than BURST_MAX sounds started within BURST_WINDOW_MS. Records the start when allowed.
static func _allow(name: String, now_ms: int) -> bool:
	if _last_by_name.has(name) and now_ms - int(_last_by_name[name]) < MIN_INTERVAL_MS:
		return false
	while not _recent_starts.is_empty() and now_ms - _recent_starts[0] >= BURST_WINDOW_MS:
		_recent_starts.pop_front()
	if _recent_starts.size() >= BURST_MAX:
		return false
	_last_by_name[name] = now_ms
	_recent_starts.append(now_ms)
	return true


## Clears the rate limiter history (tests).
static func _reset_limiter() -> void:
	_last_by_name.clear()
	_recent_starts.clear()


static func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", _volume)
	cf.set_value("audio", "muted", _muted)
	cf.save(SETTINGS_PATH)


static func _ensure_bus() -> int:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	return idx


static func _apply_bus() -> void:
	var idx: int = _ensure_bus()
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(_volume, 0.0001)))
	AudioServer.set_bus_mute(idx, _muted or _volume <= 0.0)


static func _stream_for(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name] as AudioStream
	var path: String = DIR + name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_streams[name] = s
	return s


## Creates the voice pool now so the first sounds of a screen are not dropped.
static func warm_up() -> void:
	_free_voice()


## Returns an idle voice from the pool (creating the pool on first use), or null if all busy.
static func _free_voice() -> AudioStreamPlayer:
	if not is_instance_valid(_instance):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return null
		_ensure_bus()
		_instance = Sfx.new()
		_instance.name = "Sfx"
		_voices.clear()
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.bus = BUS
			_instance.add_child(p)
			_voices.append(p)
		tree.root.add_child.call_deferred(_instance)
	if not _instance.is_inside_tree():
		return null   # first frame: the pool joins the tree deferred; drop this sound
	for v in _voices:
		if is_instance_valid(v) and not v.playing:
			return v
	return null
