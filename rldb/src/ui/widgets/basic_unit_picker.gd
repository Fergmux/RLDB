class_name BasicUnitPicker
extends HBoxContainer
## Type x Race picker of a basic unit (F06-04 "Change basic units" reward, F06-06 draft setup):
## Type tiles with their element pips and Race tiles on the left, the resulting basic unit as a
## real card on the right. Updates in place (no rebuild of the host) and emits `changed`.
##
##     var p := BasicUnitPicker.new(types, races, options, "Water", "Mage")
##     p.changed.connect(func(t, r): ...)

## Emitted when the chosen Type or Race changes.
signal changed(type: String, race: String)

## Preview card size, tile size and tile title size: roomy (the Choose basic unit popup) and
## narrow (the 740 px rewards modal). Sized so the longest Type, "Lightning", is not clipped.
const PREVIEW := Vector2(170, 255)
const PREVIEW_NARROW := Vector2(150, 225)
const TILE := Vector2(166, 46)
const TILE_NARROW := Vector2(148, 44)
const TITLE_PX := 15
const TITLE_PX_NARROW := 13
## Type and Race tiles per row.
const TYPE_COLUMNS := 3

## The chosen Type and Race.
var type: String = ""
var race: String = ""
## Card summaries of every basic unit (Series.card_summary), searched by Type and Race.
var options: Array = []

var _type_tiles: Dictionary = {}
var _race_tiles: Dictionary = {}
var _preview: CardWidget
var _name: Label
var _marks: Dictionary = {}
var _narrow := false
var _card := PREVIEW


## `types` / `races`: the choices in display order; `options`: card summaries of every basic unit;
## `marked`: ids to tag as "in your deck" beside the preview name; `narrow` fits a narrow modal.
func _init(types: Array, races: Array, opts: Array, cur_type: String, cur_race: String, marked: Array = [], narrow: bool = false) -> void:
	_narrow = narrow
	_card = PREVIEW_NARROW if narrow else PREVIEW
	options = opts
	type = cur_type
	race = cur_race
	for id in marked:
		_marks[int(id)] = true
	add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	left.add_child(_caption("Type"))
	var tg := GridContainer.new()
	tg.columns = TYPE_COLUMNS
	tg.add_theme_constant_override("h_separation", 8)
	tg.add_theme_constant_override("v_separation", 8)
	left.add_child(tg)
	for t in types:
		var tt := _tile(String(t), UIStyle.type_color(String(t)), String(t))
		var tv: String = String(t)
		tt.pressed.connect(func(): choose(tv, race))
		_type_tiles[tv] = tt
		tg.add_child(tt)
	left.add_child(_caption("Race"))
	var rg := GridContainer.new()
	rg.columns = TYPE_COLUMNS
	rg.add_theme_constant_override("h_separation", 8)
	rg.add_theme_constant_override("v_separation", 8)
	left.add_child(rg)
	for r in races:
		var rt := _tile(String(r), UIStyle.BRONZE.lightened(0.15), "basic_unit")
		var rv: String = String(r)
		rt.pressed.connect(func(): choose(type, rv))
		_race_tiles[rv] = rt
		rg.add_child(rt)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(right)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = _card + Vector2(12, 12)
	right.add_child(holder)
	_preview = CardWidget.new()
	_preview.auto_hover = false
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_preview)
	_name = UIStyle.label("", 15, UIStyle.GOLD_HI, false, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size = Vector2(_card.x + 12, 0)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_name)
	_sync()


## The card summary of the chosen variant ({} when no basic unit has this Type and Race).
func chosen() -> Dictionary:
	for c in options:
		if String(c["type"]) == type and String(c["race"]) == race:
			return c
	return {}


## Moves keyboard focus to the chosen Type tile.
func focus_first() -> void:
	var t: Control = _type_tiles.get(type, null)
	if t != null:
		t.grab_focus()


func choose(t: String, r: String) -> void:
	if t == type and r == race:
		return
	type = t
	race = r
	_sync()
	changed.emit(type, race)


func _sync() -> void:
	for k in _type_tiles:
		_type_tiles[k].selected = k == type
	for k in _race_tiles:
		_race_tiles[k].selected = k == race
	var c := chosen()
	_preview.setup(MatchView.summary_view(c) if not c.is_empty() else null, "big")
	GameUi.resize_card(_preview, _card)
	if c.is_empty():
		_name.text = "No such basic unit"
	else:
		_name.text = "%s (%s)%s" % [c["name"], c["type"], "\nin your deck" if _marks.has(int(c["id"])) else ""]


func _caption(text: String) -> Label:
	return UIStyle.label(text.to_upper(), 12, UIStyle.GOLD, false, true)


func _tile(title: String, col: Color, kind: String) -> ChoiceTile:
	var t := ChoiceTile.new(title, "", col, kind, true)
	t.custom_minimum_size = TILE_NARROW if _narrow else TILE
	t.set_title_size(TITLE_PX_NARROW if _narrow else TITLE_PX)
	t.focus_mode = Control.FOCUS_ALL
	t.tooltip_text = title
	return t
