class_name Customisation
extends RefCounted
## The player's cosmetic choices (owner feedback 5 Nov, L25 / L28): the table the game is played
## on and the card back. Chosen in Options > Customisation; the table is read when a game screen
## builds its board (it cannot be changed during a game). Presentation only: nothing here reaches
## the rules engine, the network or telemetry.
##
## Saved in the [customise] section of user://ui_settings.cfg (the file UIStyle and Telemetry also
## write; each keeps the other sections). Automated runs (GdUnit, `-s` scripts, `--*-shots`
## drivers: the runs where DeckStore uses its TEST path) read and write TEST_PATH instead, so a
## test never changes the player's table.
##
##     Customisation.set_table("leather")
##     var bg := UIStyle.table_background()   # the chosen table, with its veil

## The tables, in picker order. `veil`: the dark veil over the art on the board (0..1) that keeps
## zones, cards and text readable on that table; `thumb`: a small copy for the picker.
const TABLES := [
	{"id": "ruins", "name": "Forest Ruins", "blurb": "Moss-grown flagstones in a forgotten grove",
		"path": "res://assets/art/tables/table_ruins.jpg", "thumb": "res://assets/art/tables/thumbs/table_ruins.jpg", "veil": 0.36},
	{"id": "leather", "name": "Emerald Leather", "blurb": "Tooled green hide in a brass-cornered frame",
		"path": "res://assets/art/tables/table_leather.jpg", "thumb": "res://assets/art/tables/thumbs/table_leather.jpg", "veil": 0.1},
	{"id": "parquet", "name": "Guildhall Parquet", "blurb": "Inlaid oak with bronze rosettes",
		"path": "res://assets/art/tables/table_parquet.jpg", "thumb": "res://assets/art/tables/thumbs/table_parquet.jpg", "veil": 0.3},
	{"id": "dragon", "name": "Gilded Dragon", "blurb": "Parquet guarded by golden wyrms",
		"path": "res://assets/art/tables/table_dragon.jpg", "thumb": "res://assets/art/tables/thumbs/table_dragon.jpg", "veil": 0.3},
]
## The table of a new profile (owner, 5 Nov: the "Luxury Fantasy Table Background").
const DEFAULT_TABLE := "ruins"
## The card backs, in picker order (one for now; more are planned).
const CARD_BACKS := [
	{"id": "violet", "name": "Violet Sigil", "blurb": "The house back: a gold sigil on deep violet"},
]
const DEFAULT_CARD_BACK := "violet"

const SECTION := "customise"
const SETTINGS_PATH := "user://ui_settings.cfg"
const TEST_PATH := "user://test_ui_customise.cfg"
## Tests may point the store at a file of their own ("" = the automatic choice).
static var path_override: String = ""

static var _table: String = ""
static var _loaded_path: String = ""


## The settings file in use: `path_override`, else TEST_PATH in automated runs, else SETTINGS_PATH.
static func settings_path() -> String:
	if path_override != "":
		return path_override
	return TEST_PATH if DeckStore.PATH == DeckStore.TEST_PATH else SETTINGS_PATH


## Forgets the loaded choice (the next read reloads the file). Test hook.
static func reset_cache() -> void:
	_table = ""
	_loaded_path = ""


static func _load() -> void:
	var p := settings_path()
	if _loaded_path == p:
		return
	_loaded_path = p
	_table = DEFAULT_TABLE
	var cf := ConfigFile.new()
	if cf.load(p) == OK:
		var id := String(cf.get_value(SECTION, "table", DEFAULT_TABLE))
		if has_table(id):
			_table = id


## True when `id` names one of TABLES.
static func has_table(id: String) -> bool:
	for t in TABLES:
		if String(t["id"]) == id:
			return true
	return false


## The id of the chosen table (DEFAULT_TABLE until the player picks one, or when the saved id is
## unknown, e.g. a table removed in a later version).
static func table_id() -> String:
	_load()
	return _table


## Chooses and saves table `id`. Returns false (and changes nothing) for an unknown id.
static func set_table(id: String) -> bool:
	if not has_table(id):
		return false
	_load()
	_table = id
	var cf := ConfigFile.new()
	cf.load(settings_path())   # keep the other sections ([ui], [privacy], [progress] ...)
	cf.set_value(SECTION, "table", id)
	cf.save(settings_path())
	return true


## The entry of TABLES for `id` (the chosen table when `id` is ""; the default for an unknown id).
static func table(id: String = "") -> Dictionary:
	var want := id if id != "" else table_id()
	var fallback: Dictionary = TABLES[0]
	for t in TABLES:
		if String(t["id"]) == want:
			return t
		if String(t["id"]) == DEFAULT_TABLE:
			fallback = t
	return fallback


## The art of the chosen table (res:// path).
static func table_path() -> String:
	return String(table()["path"])


## The board veil of the chosen table (0..1).
static func table_veil() -> float:
	return float(table()["veil"])


## The id of the card back in use (the only one, for now).
static func card_back_id() -> String:
	return DEFAULT_CARD_BACK
