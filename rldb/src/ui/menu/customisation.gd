class_name Customisation
extends RefCounted
## The player's cosmetic choices (owner feedback 5 Nov, L25 / L28 / L31): the table the game is
## played on and the card back. Chosen in Options > Customisation; the table is read when a game screen
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
## The card backs, in picker order (L31); `short` is the name under the picker tile. How each one
## is drawn (palette, painted centre) lives in CardBack.STYLES under the same id. A local display
## choice: it dresses every face-down card on this screen (both players'), is never sent over the
## network and never reveals anything.
const CARD_BACKS := [
	{"id": "violet", "name": "Violet Sigil", "short": "Violet", "blurb": "The house back: a gold sigil on deep violet"},
	{"id": "wyrm", "name": "Crimson Wyrm", "short": "Wyrm", "blurb": "A coiled dragon crest on oxblood lacquer"},
	{"id": "grove", "name": "Verdant Grove", "short": "Grove", "blurb": "The sacred oak, rooted and crowned, on forest leather"},
	{"id": "tide", "name": "Abyssal Tide", "short": "Tide", "blurb": "The kraken of the deep in pearl and moonlit silver"},
	{"id": "runes", "name": "Obsidian Runes", "short": "Runes", "blurb": "A rune seal of molten ember in black volcanic glass"},
	{"id": "sun", "name": "Gilded Sun", "short": "Sun", "blurb": "A radiant sun of beaten gold on ivory enamel"},
	{"id": "stars", "name": "Arcane Starfield", "short": "Stars", "blurb": "A silver star in a brass astrolabe on the night sky"},
]
const DEFAULT_CARD_BACK := "violet"

const SECTION := "customise"
const SETTINGS_PATH := "user://ui_settings.cfg"
const TEST_PATH := "user://test_ui_customise.cfg"
## Tests may point the store at a file of their own ("" = the automatic choice).
static var path_override: String = ""

static var _table: String = ""
static var _card_back: String = ""
static var _loaded_path: String = ""


## The settings file in use: `path_override`, else TEST_PATH in automated runs, else SETTINGS_PATH.
static func settings_path() -> String:
	if path_override != "":
		return path_override
	return TEST_PATH if DeckStore.PATH == DeckStore.TEST_PATH else SETTINGS_PATH


## Forgets the loaded choice (the next read reloads the file). Test hook.
static func reset_cache() -> void:
	_table = ""
	_card_back = ""
	_loaded_path = ""


static func _load() -> void:
	var p := settings_path()
	if _loaded_path == p:
		return
	_loaded_path = p
	_table = DEFAULT_TABLE
	_card_back = DEFAULT_CARD_BACK
	var cf := ConfigFile.new()
	if cf.load(p) == OK:
		var id := String(cf.get_value(SECTION, "table", DEFAULT_TABLE))
		if has_table(id):
			_table = id
		var back := String(cf.get_value(SECTION, "card_back", DEFAULT_CARD_BACK))
		if has_card_back(back):
			_card_back = back
	CardWidget.face_epoch += 1   # the back may differ from the one faces were last painted with


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
	_save_value("table", id)
	return true


# Writes one key of [customise], keeping every other section ([ui], [privacy], [progress] ...).
static func _save_value(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(settings_path())
	cf.set_value(SECTION, key, value)
	cf.save(settings_path())


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


## True when `id` names one of CARD_BACKS.
static func has_card_back(id: String) -> bool:
	for b in CARD_BACKS:
		if String(b["id"]) == id:
			return true
	return false


## The id of the card back in use (DEFAULT_CARD_BACK until the player picks one, or when the saved
## id is unknown, e.g. a back removed in a later version).
static func card_back_id() -> String:
	_load()
	return _card_back


## Chooses and saves card back `id`. Returns false (and changes nothing) for an unknown id. Every
## face-down card (CardBack) uses it from its next redraw.
static func set_card_back(id: String) -> bool:
	if not has_card_back(id):
		return false
	_load()
	var changed := _card_back != id
	_card_back = id
	_save_value("card_back", id)
	if changed:
		refresh_card_backs()
	return true


## Makes every card back on screen show the chosen back now: bumps CardWidget.face_epoch (a card
## face repaints only when its face_key changes) and asks each card widget and pile in the tree to
## repaint. Called when the back changes; cheap enough for a one-off pick.
static func refresh_card_backs() -> void:
	CardWidget.face_epoch += 1
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	for n in tree.root.find_children("*", "Control", true, false):
		if n is CardWidget:
			(n as CardWidget).request_face()
		elif n is PileStack:
			(n as PileStack).queue_redraw()


## The entry of CARD_BACKS for `id` (the chosen back when `id` is ""; the default for an unknown id).
static func card_back(id: String = "") -> Dictionary:
	var want := id if id != "" else card_back_id()
	var fallback: Dictionary = CARD_BACKS[0]
	for b in CARD_BACKS:
		if String(b["id"]) == want:
			return b
		if String(b["id"]) == DEFAULT_CARD_BACK:
			fallback = b
	return fallback
