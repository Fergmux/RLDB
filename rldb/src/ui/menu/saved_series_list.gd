class_name SavedSeriesList
extends RefCounted
## Tiles for the unfinished series saved between games (P-02), newest first: the players, the
## score, how it was played and when, a Resume button (reopens it the same way) and Delete.

const MAX_SHOWN := 5
const MODE_NAMES := {"bot": "Against the bot", "local": "Hot-seat", "lan": "LAN (you host)", "steam": "Steam (you host)"}
const DEFAULT_MODE := "local"
## Characters of the ISO timestamp kept ("YYYY-MM-DD  HH:MM").
const TIMESTAMP_CHARS := 17


## Adds one tile per save in `saves` (at most MAX_SHOWN) to `box`, or a "No saved series." note.
## `on_resume(id, mode)` and `on_delete(id)` run when the tile's buttons are pressed.
static func add_to(box: VBoxContainer, saves: Array, on_resume: Callable, on_delete: Callable) -> void:
	if saves.is_empty():
		box.add_child(UIStyle.label("No saved series.", 15, UIStyle.TEXT_DIM))
	for sv in saves.slice(0, MAX_SHOWN):
		box.add_child(_tile(sv, on_resume, on_delete))


static func _tile(sv: Dictionary, on_resume: Callable, on_delete: Callable) -> PanelContainer:
	var tile := PanelContainer.new()
	var sb := UIStyle.flat(Color(1, 1, 1, 0.035), Color(UIStyle.BRONZE, 0.7), 1, 10)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 16)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 12)
	tile.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	tile.add_child(row)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var mode := String(sv.get("mode", DEFAULT_MODE))
	info.add_child(UIStyle.title_label("%s  vs  %s" % [sv["names"][0], sv["names"][1]], 20, UIStyle.TEXT))
	info.add_child(UIStyle.label("%s  ·  best of %d  ·  next: game %d" % [MODE_NAMES.get(mode, MODE_NAMES[DEFAULT_MODE]), int(sv["best_of"]), int(sv.get("game_no", 0)) + 1], 14, UIStyle.TEXT_DIM))
	var when := String(sv["saved_at"]).replace("T", "  ")
	info.add_child(UIStyle.label("Saved %s" % when.substr(0, TIMESTAMP_CHARS), 13, UIStyle.TEXT_DIM))
	var score := UIStyle.title_label("%d – %d" % [int(sv["scores"][0]), int(sv["scores"][1])], 30, UIStyle.GOLD)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(score)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btns)
	var id: String = sv["id"]
	var res := UIStyle.primary_button("Resume", 16)
	res.custom_minimum_size = Vector2(130, 40)
	res.disabled = mode == "steam" and not SteamBridge.available()
	if res.disabled:
		res.tooltip_text = SteamBridge.describe()
	res.pressed.connect(func(): on_resume.call(id, mode))
	btns.add_child(res)
	var del := UIStyle.button("Delete", 13)
	del.custom_minimum_size = Vector2(130, 30)
	del.pressed.connect(func(): on_delete.call(id))
	btns.add_child(del)
	return tile
