class_name PlayerProgress
extends RefCounted
## Whether this profile has started a game or the tutorial yet (F04-09). The main menu shows
## "Play tutorial" in place of "Resume" until it has. One flag in the user settings file
## ([progress] has_played); a saved series counts as played too, so existing players never see
## the tutorial entry. Scripted shot runs set `persist` to false (like SeriesStore.DIR), so they
## never flip the real flag.

## Settings file the flag lives in (the same file as UIStyle's options).
const PATH := "user://ui_settings.cfg"
const SECTION := "progress"
const KEY := "has_played"

## False in scripted runs and tests: the flag then lives in memory only.
static var persist: bool = true
## In-memory value; read from the file on first use while `persist` is true.
static var _played: bool = false
static var _loaded: bool = false


## True once a game or the tutorial has been started on this profile, or a series is saved.
static func has_played() -> bool:
	if persist and not _loaded:
		_loaded = true
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			_played = bool(cf.get_value(SECTION, KEY, false))
	return _played or not SeriesStore.list().is_empty()


## Records that a game or the tutorial was started (written only when `persist` is set).
static func mark_played() -> void:
	var was := _played
	has_played()   # loads the stored value first so the write below keeps it
	if was or _played:
		return
	_played = true
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.load(PATH)  # keep the other sections; a missing file is fine
	cf.set_value(SECTION, KEY, true)
	cf.save(PATH)


## Test hook: forgets the in-memory state (the next `has_played` rereads the file when persisting).
static func reset_cache() -> void:
	_played = false
	_loaded = false
