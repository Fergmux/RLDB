class_name TutorialProgress
extends RefCounted
## Which tutorial lessons this profile has finished (design review #97: the lesson list shows a
## gold tick on finished lessons and a "Next" chip on the recommended one). Lessons are keyed by
## their stable `id` (TutorialLessons), never by title or index. One list in the user settings
## file ([tutorial] done).
##
## Presentation state only: it changes nothing in a lesson. Persistence is OFF until Main turns it
## on for a normal (unscripted) run, so tests, screenshot drivers and dev tools never write the
## player's settings file; the list then lives in memory.

## Settings file the list lives in (the same file as UIStyle's options).
const PATH := "user://ui_settings.cfg"
const SECTION := "tutorial"
const KEY := "done"

## True only in a normal run (Main sets it): the list is then read from and written to PATH.
static var persist: bool = false
static var _done: PackedStringArray = []
static var _loaded: bool = false


## True when lesson `id` has been finished on this profile.
static func is_done(id: String) -> bool:
	_load()
	return id in _done


## Ids of the finished lessons, in the order they were finished.
static func done_ids() -> PackedStringArray:
	_load()
	return _done.duplicate()


## Records that lesson `id` was finished (written to the settings file when persisting).
static func mark_done(id: String) -> void:
	_load()
	if id == "" or id in _done:
		return
	_done.append(id)
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.load(PATH)   # keep the other sections; a missing file is fine
	cf.set_value(SECTION, KEY, Array(_done))
	cf.save(PATH)


## Index of the lesson to recommend among `lessons` (Array of {id, ...}): the first one not
## finished; -1 when every lesson is done.
static func recommended(lessons: Array) -> int:
	for i in lessons.size():
		if not is_done(String((lessons[i] as Dictionary).get("id", ""))):
			return i
	return -1


## Turns persistence on (Main, normal runs only) and rereads the file on the next query.
static func enable_persistence() -> void:
	persist = true
	reset_cache()


## True when the running main loop is a script (a `-s` dev driver or the test runner), whose
## runs must never write the player's files.
static func scripted_main_loop() -> bool:
	var ml := Engine.get_main_loop()
	return ml != null and ml.get_script() != null


## Test hook: forgets the in-memory list (the next read reloads the file when persisting).
static func reset_cache() -> void:
	_done = PackedStringArray()
	_loaded = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist:
		return
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for v in cf.get_value(SECTION, KEY, []):
			if String(v) != "" and not (String(v) in _done):
				_done.append(String(v))
