class_name SeriesStore
extends RefCounted
## Between-game series saves (P-02: a series can be paused and resumed at a later date,
## at between-game checkpoints only). Saves live in user://saves/<save_id>.json.

const DIR := "user://saves"


static func save(s: Series) -> void:
	if not s.at_checkpoint():
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open("%s/%s.json" % [DIR, s.save_id], FileAccess.WRITE)
	if f == null:
		push_warning("SeriesStore: cannot write save %s" % s.save_id)
		return
	f.store_string(JSON.stringify(s.to_save()))


## Saved series that are not finished, newest first: [{id, names, scores, best_of, saved_at, stage}].
static func list() -> Array:
	var out := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for fn in dir.get_files():
		if not fn.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, fn]))
		if d == null or d.get("stage", "") == Series.STAGE_OVER:
			continue
		out.append({"id": d["save_id"], "names": d["names"], "scores": d["scores"],
			"best_of": d["cfg"]["best_of"], "saved_at": d.get("saved_at", ""), "stage": d["stage"]})
	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out


static func load_series(id: String) -> Series:
	var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIR, id]))
	if d == null:
		return null
	return Series.from_save(d)


static func delete(id: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [DIR, id])
