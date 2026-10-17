class_name SeriesStore
extends RefCounted
## Between-game series saves (P-02: a series can be paused and resumed at a later date,
## at between-game checkpoints only). Saves live in user://saves/<save_id>.json.

## Save directory. Automated runs (GdUnit, `-s` dev scripts, `--*-shots` drivers) start in a test
## directory, like DeckStore and PlayerStats, so no test can create, list or delete the player's
## real saves even if it forgets to set DIR itself. Tests may still point DIR elsewhere.
static var DIR := _default_dir()
const PLAYER_DIR := "user://saves"
const TEST_DIR := "user://test_saves"
## Scripted screenshot runs (main.gd sets this too, for `--*-shots` arguments).
const DEV_DIR := "user://dev_saves"


## The save directory for this process: TEST_DIR under a test runner or `-s` script, DEV_DIR for
## a shots run, PLAYER_DIR otherwise.
static func _default_dir() -> String:
	return dir_for(OS.get_cmdline_args(), OS.get_cmdline_user_args())


## The save directory for these command-line arguments (see `_default_dir`).
static func dir_for(args: PackedStringArray, user_args: PackedStringArray) -> String:
	for a in args:
		if a == "-s" or a == "--script" or String(a).contains("GdUnitCmdTool"):
			return TEST_DIR
	for a in user_args:
		if String(a).contains("shots"):
			return DEV_DIR
	return PLAYER_DIR


static func save(s: Series) -> void:
	if not s.at_checkpoint():
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open("%s/%s.json" % [DIR, s.save_id], FileAccess.WRITE)
	if f == null:
		push_warning("SeriesStore: cannot write save %s" % s.save_id)
		return
	f.store_string(JSON.stringify(s.to_save()))


## Saved series that are not finished, newest first: [{id, names, scores, best_of, saved_at, stage,
## mode, game_no}]. Malformed files are skipped (one bad file must not hide the others) and saves
## of finished series are deleted.
static func list() -> Array:
	var out := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for fn in dir.get_files():
		if not fn.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, fn]))
		if not Series.is_valid_save(d):
			continue
		if d["stage"] == Series.STAGE_OVER:
			DirAccess.remove_absolute("%s/%s" % [DIR, fn])
			continue
		# How the series was played, so Resume can reopen it the same way (older bot saves are
		# recognised by the "Bot" seat name).
		var mode: String = String(d["cfg"].get("mode", "bot" if String(d["names"][1]) == "Bot" else "local"))
		out.append({"id": d["save_id"], "names": d["names"], "scores": d["scores"],
			"best_of": d["cfg"]["best_of"], "saved_at": d.get("saved_at", ""), "stage": d["stage"],
			"mode": mode, "game_no": int(d.get("game_no", 0))})
	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out


static func load_series(id: String) -> Series:
	var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIR, id]))
	if not Series.is_valid_save(d) or d["stage"] == Series.STAGE_OVER:
		return null
	return Series.from_save(d)


static func delete(id: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [DIR, id])
