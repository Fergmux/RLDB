class_name Music
extends Node
## The soundtrack (F06-02): two playlists supplied by the user. The "menu" playlist plays on the
## menus, the deck builder and between games (deck choice, draft, rewards, first-player choice,
## series over); the "battle" playlist plays while a game is in progress. Each playlist plays its
## songs in turn and loops; a song crossfades into the next one, and switching playlist (a scene
## change) crossfades into the other playlist's next song.
##
## One director node lives under the scene root so the music carries across screens. Two
## AudioStreamPlayers on the "Music" bus take turns, so a crossfade is one fading out while the
## other fades in. Volume / mute are separate from sound effects and persisted.

const PLAYLISTS := {
	"menu": ["res://assets/audio/music/menu_1.ogg", "res://assets/audio/music/menu_2.ogg"],
	"battle": ["res://assets/audio/music/battle_1.ogg", "res://assets/audio/music/battle_2.ogg",
		"res://assets/audio/music/battle_3.ogg"],
}
const BUS := "Music"
const SETTINGS_PATH := "user://music_settings.cfg"
const DEFAULT_VOLUME := 0.45
## Seconds a crossfade takes, between songs and between playlists.
const CROSSFADE := 3.0
## Silence level a fading player starts from / ends at.
const SILENT_DB := -60.0

static var _director: Music = null
static var _volume: float = DEFAULT_VOLUME
static var _muted: bool = false
static var _loaded: bool = false

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _mode := ""
## Next song index per playlist, so each new game (or return to the menu) moves on a song.
var _next := {"menu": 0, "battle": 0}
var _fading := false
var _fade_tween: Tween


## Starts the menu playlist if no music is playing yet. Safe to call repeatedly.
static func start() -> void:
	set_mode("menu")


## Switches to playlist `mode` ("menu" or "battle"), crossfading from what is playing. A no-op
## when that playlist is already playing.
static func set_mode(mode: String) -> void:
	if not PLAYLISTS.has(mode):
		return
	var d := _ensure_director()
	if d == null:
		return
	d._switch(mode)


## The playlist currently playing ("" before the first song).
static func current_mode() -> String:
	return _director._mode if is_instance_valid(_director) else ""


## Path of the song currently playing (or fading in), "" when none.
static func current_track() -> String:
	if not is_instance_valid(_director) or _director._players.is_empty():
		return ""
	var p: AudioStreamPlayer = _director._players[_director._active]
	return p.stream.resource_path if p.stream != null else ""


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


static func _ensure_director() -> Music:
	if is_instance_valid(_director):
		return _director
	load_settings()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_ensure_bus()
	_apply()
	_director = Music.new()
	_director.name = "Music"
	tree.root.add_child.call_deferred(_director)
	return _director


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)


func _switch(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	_crossfade_to(_take_next(mode))


## Path of `mode`'s next song; advances that playlist's position.
func _take_next(mode: String) -> String:
	var list: Array = PLAYLISTS[mode]
	var i: int = int(_next[mode]) % list.size()
	_next[mode] = (i + 1) % list.size()
	return list[i]


func _crossfade_to(path: String) -> void:
	if not is_inside_tree():   # the director is added to the root deferred
		ready.connect(_crossfade_to.bind(path), CONNECT_ONE_SHOT)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false   # the playlist moves on instead
	var out_p: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var in_p: AudioStreamPlayer = _players[_active]
	in_p.stream = stream
	in_p.volume_db = SILENT_DB
	in_p.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fading = true
	_fade_tween = create_tween().set_parallel(true)
	# Equal-power-ish curve: the new song rises quickly, the old one lingers then drops.
	_fade_tween.tween_property(in_p, "volume_db", 0.0, CROSSFADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if out_p.playing:
		_fade_tween.tween_property(out_p, "volume_db", SILENT_DB, CROSSFADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tween.chain().tween_callback(func():
		out_p.stop()
		_fading = false)


func _process(_d: float) -> void:
	if _mode == "" or _fading:
		return
	var p: AudioStreamPlayer = _players[_active]
	if p.stream == null:
		return
	# Crossfade into the playlist's next song as this one nears its end (or if it stopped).
	var left := p.stream.get_length() - p.get_playback_position()
	if not p.playing or left <= CROSSFADE:
		_crossfade_to(_take_next(_mode))


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
