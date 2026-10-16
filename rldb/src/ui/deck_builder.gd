class_name DeckBuilder
extends Control
## Custom deck builder (P-03). No limits on size, category mix or duplicates; the
## deck is a flat id list and Fusion/Ritual/Arcane cards land in the Extra Deck
## automatically (shown grouped here). Presentation only: persists through DeckStore.

signal closed

const MARGIN := 16
const ROW_FONT_SIZE := 14
const SWATCH_W := 5

const COST_OPTIONS := [
	["Any cost", ""], ["0 AP", "ap:0"], ["1 AP", "ap:1"], ["2 AP", "ap:2"], ["3 AP", "ap:3"],
	["4 AP", "ap:4"], ["5+ AP", "ap:5+"], ["Fusion", "kind:fusion"], ["Ritual", "kind:ritual"],
	["Arcane", "kind:arcane"],
]

## card id -> copies in the working deck
var counts: Dictionary = {}
var deck_name_edit: LineEdit
var dirty: bool = false

var _search: LineEdit
var _cat_opt: OptionButton
var _type_opt: OptionButton
var _race_opt: OptionButton
var _cost_opt: OptionButton
var _result_label: Label
var _catalogue_box: VBoxContainer
var _deck_box: VBoxContainer
var _deck_summary: Label
var _empty_note: Label
var _preview_holder: VBoxContainer
var _preview_text: Label
var _saved_opt: OptionButton
var _starter_opt: OptionButton
var _status: Label
var _starters: Array = []
var _summaries: Dictionary = {}
var _preview_id: int = -1
var _overlay: ConfirmDialog


func _ready() -> void:
	CardDB.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_starters = Series.load_starters()
	_build()
	_refresh_saved()
	_refresh_catalogue()
	_refresh_deck()
	var all := CardDB.all()
	if not all.is_empty():
		show_preview(int(all[0]["id"]))


# ------------------------------------------------------------ pure logic (testable)

## True if card def `d` passes the filters. Empty string means "any".
## cost is "", "ap:N", "ap:5+" or "kind:fusion|ritual|arcane".
static func matches(d: Dictionary, query: String, category: String, type: String, race: String, cost: String) -> bool:
	if category != "" and d["category"] != category:
		return false
	if type != "" and String(d["type"] if d["type"] != null else "") != type:
		return false
	if race != "" and String(d["race"] if d["race"] != null else "") != race:
		return false
	if cost != "":
		var parts := cost.split(":")
		if parts[0] == "kind":
			if d["cost_kind"] != parts[1]:
				return false
		else:
			if d["cost_kind"] != "ap" or d["cost"] == null:
				return false
			if parts[1].ends_with("+"):
				if int(d["cost"]) < int(parts[1].trim_suffix("+")):
					return false
			elif int(d["cost"]) != int(parts[1]):
				return false
	var q := query.strip_edges().to_lower()
	if q != "":
		var hay := (String(d["name"]) + " " + String(Series.card_summary(int(d["id"]))["text"])).to_lower()
		for word in q.split(" ", false):
			if not hay.contains(word):
				return false
	return true


## Expands a counts dictionary to a sorted id list (the DeckStore format).
static func counts_to_cards(c: Dictionary) -> Array:
	var ids := c.keys()
	ids.sort()
	var out := []
	for id in ids:
		for i in int(c[id]):
			out.append(int(id))
	return out


## Collapses a DeckStore id list into card id -> copies.
static func cards_to_counts(cards: Array) -> Dictionary:
	var c := {}
	for id in cards:
		c[int(id)] = int(c.get(int(id), 0)) + 1
	return c


# ------------------------------------------------------------ public editing API

## Adds `n` copies of card `id` to the working deck.
func add_card(id: int, n: int = 1) -> void:
	counts[id] = int(counts.get(id, 0)) + n
	dirty = true
	_refresh_deck()
	_refresh_catalogue_counts()


## Removes one copy of card `id` (no-op when absent).
func remove_card(id: int) -> void:
	if not counts.has(id):
		return
	counts[id] = int(counts[id]) - 1
	if int(counts[id]) <= 0:
		counts.erase(id)
	dirty = true
	_refresh_deck()
	_refresh_catalogue_counts()


## Sets the search text and refreshes the catalogue.
func set_filters(query: String) -> void:
	_search.text = query
	_refresh_catalogue()


## Starts an empty, unnamed deck.
func new_deck() -> void:
	counts = {}
	deck_name_edit.text = ""
	dirty = false
	_say("Started a new empty deck.")
	_refresh_deck()
	_refresh_catalogue_counts()


## Replaces the working deck with `cards` under `name` (not dirty).
func load_cards(name: String, cards: Array) -> void:
	counts = cards_to_counts(cards)
	deck_name_edit.text = name
	dirty = false
	_refresh_deck()
	_refresh_catalogue_counts()


## Saves the working deck under its name; false (with a message) when unnamed.
func save() -> bool:
	var n := deck_name_edit.text.strip_edges()
	if n == "":
		_say("Give the deck a name before saving.", true)
		return false
	DeckStore.save_deck(n, counts_to_cards(counts))
	dirty = false
	_refresh_saved()
	_say("Saved \"%s\" (%d cards)." % [n, counts_to_cards(counts).size()])
	return true


## Shows card `id` big in the preview column with its details and rules text.
func show_preview(id: int) -> void:
	_preview_id = id
	for c in _preview_holder.get_children():
		c.queue_free()
	var s := _summary(id)
	_preview_holder.add_child(CardWidget.new().setup(MatchView.summary_view(s), "big"))
	var d := CardDB.get_def(id)
	var lines := PackedStringArray()
	lines.append("%s · %s" % [UIStyle.CATEGORY_NAMES.get(d["category"], d["category"]), CardDB.cost_label(d)])
	var meta := []
	if d["race"] != null and d["race"] != "":
		meta.append(d["race"])
	if d["type"] != null and d["type"] != "":
		meta.append(d["type"])
	if d["atk"] != null:
		meta.append("ATK %s / DEF %s" % [d["atk"], d["def"]])
	if not meta.is_empty():
		lines.append(" · ".join(meta))
	lines.append("")
	lines.append(String(s["text"]) if String(s["text"]) != "" else "(No rules text.)")
	if s["support"] != "full":
		lines.append("")
		lines.append("Implementation: %s" % s["support"])
	_preview_text.text = "\n".join(lines)


# ------------------------------------------------------------ construction

## A bronze-trimmed plate for one of the three columns.
static func _plate(color: Color = UIStyle.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(color, UIStyle.BRONZE, 1, 6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIStyle.TABLE_WOOD
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := UIStyle.full_rect_margin(MARGIN)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var t := UIStyle.title_label("DECK BUILDER", 30, UIStyle.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIStyle.label("No limits on size, mix or duplicates. Fusion, Ritual and Arcane cards go to the Extra Deck automatically.", 13, UIStyle.TEXT_DIM))
	var back := UIStyle.button("Back", 15)
	back.pressed.connect(_on_back)
	head.add_child(back)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_build_catalogue(body)
	_build_preview(body)
	_build_deck(body)

	_status = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	root.add_child(_status)


func _opt(items: Array, first: String) -> OptionButton:
	var o := OptionButton.new()
	o.add_item(first)
	o.set_item_metadata(0, "")
	for it in items:
		o.add_item(String(it))
		o.set_item_metadata(o.item_count - 1, String(it))
	o.item_selected.connect(func(_i): _refresh_catalogue())
	return o


func _build_catalogue(body: HBoxContainer) -> void:
	var plate := _plate()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = 3.0
	body.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	plate.add_child(v)
	v.add_child(UIStyle.title_label("Card catalogue", 18, UIStyle.TEXT))
	_search = LineEdit.new()
	_search.placeholder_text = "Search name or rules text..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _refresh_catalogue())
	v.add_child(_search)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	v.add_child(filters)
	_cat_opt = OptionButton.new()
	_cat_opt.add_item("Any category")
	_cat_opt.set_item_metadata(0, "")
	for k in UIStyle.CATEGORY_NAMES:
		_cat_opt.add_item(UIStyle.CATEGORY_NAMES[k])
		_cat_opt.set_item_metadata(_cat_opt.item_count - 1, k)
	_cat_opt.item_selected.connect(func(_i): _refresh_catalogue())
	filters.add_child(_cat_opt)
	_type_opt = _opt(CardDB.ELEMENTS, "Any Type")
	filters.add_child(_type_opt)
	_race_opt = _opt(CardDB.RACES, "Any Race")
	filters.add_child(_race_opt)
	_cost_opt = OptionButton.new()
	for c in COST_OPTIONS:
		_cost_opt.add_item(c[0])
		_cost_opt.set_item_metadata(_cost_opt.item_count - 1, c[1])
	_cost_opt.item_selected.connect(func(_i): _refresh_catalogue())
	filters.add_child(_cost_opt)
	var reset := UIStyle.button("Clear filters", 13)
	reset.pressed.connect(func():
		_search.text = ""
		for o in [_cat_opt, _type_opt, _race_opt, _cost_opt]:
			o.select(0)
		_refresh_catalogue())
	filters.add_child(reset)
	_result_label = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	v.add_child(_result_label)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_catalogue_box = VBoxContainer.new()
	_catalogue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalogue_box.add_theme_constant_override("separation", 2)
	sc.add_child(_catalogue_box)


func _build_preview(body: HBoxContainer) -> void:
	var plate := _plate(UIStyle.PANEL_INK)
	plate.custom_minimum_size = Vector2(300, 0)
	body.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	plate.add_child(v)
	v.add_child(UIStyle.title_label("Preview", 18, UIStyle.TEXT))
	_preview_holder = VBoxContainer.new()
	_preview_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_preview_holder)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_preview_text = UIStyle.label("", 14, UIStyle.TEXT, true)
	_preview_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_preview_text)
	var row := HBoxContainer.new()
	v.add_child(row)
	var add := UIStyle.button("Add to deck", 14)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.pressed.connect(func(): if _preview_id >= 0: add_card(_preview_id))
	row.add_child(add)
	var rem := UIStyle.button("Remove one", 14)
	rem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rem.pressed.connect(func(): if _preview_id >= 0: remove_card(_preview_id))
	row.add_child(rem)


func _build_deck(body: HBoxContainer) -> void:
	var plate := _plate()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = 2.2
	body.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	plate.add_child(v)
	v.add_child(UIStyle.title_label("Your deck", 18, UIStyle.TEXT))
	deck_name_edit = LineEdit.new()
	deck_name_edit.placeholder_text = "Deck name"
	deck_name_edit.text_changed.connect(func(_t): dirty = true)
	v.add_child(deck_name_edit)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	v.add_child(actions)
	var save_b := UIStyle.button("Save", 14)
	save_b.pressed.connect(save)
	actions.add_child(save_b)
	var new_b := UIStyle.button("New", 14)
	new_b.pressed.connect(func(): _guard_unsaved(new_deck))
	actions.add_child(new_b)
	var del_b := UIStyle.button("Delete", 14)
	del_b.pressed.connect(_ask_delete)
	actions.add_child(del_b)
	var loadrow := HBoxContainer.new()
	v.add_child(loadrow)
	_saved_opt = OptionButton.new()
	_saved_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saved_opt.clip_text = true
	loadrow.add_child(_saved_opt)
	var load_b := UIStyle.button("Load", 14)
	load_b.pressed.connect(func(): _guard_unsaved(_load_selected))
	loadrow.add_child(load_b)
	var strow := HBoxContainer.new()
	v.add_child(strow)
	_starter_opt = OptionButton.new()
	_starter_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_starter_opt.clip_text = true
	for s in _starters:
		_starter_opt.add_item(String(s["name"]))
	strow.add_child(_starter_opt)
	var st_b := UIStyle.button("Copy starter", 14)
	st_b.pressed.connect(func(): _guard_unsaved(_copy_starter))
	strow.add_child(st_b)
	v.add_child(HSeparator.new())
	_deck_summary = UIStyle.label("", 14, UIStyle.GOLD_HI)
	v.add_child(_deck_summary)
	_empty_note = UIStyle.label("Your deck is empty. Add cards from the catalogue; there is no size limit, but an empty deck cannot play.", 13, UIStyle.TEXT_DIM, true)
	v.add_child(_empty_note)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_deck_box = VBoxContainer.new()
	_deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_box.add_theme_constant_override("separation", 2)
	sc.add_child(_deck_box)


# ------------------------------------------------------------ refresh

func _summary(id: int) -> Dictionary:
	if not _summaries.has(id):
		_summaries[id] = Series.card_summary(id)
	return _summaries[id]


func _sel(o: OptionButton) -> String:
	return String(o.get_item_metadata(o.selected)) if o.selected >= 0 else ""


func _refresh_catalogue() -> void:
	for c in _catalogue_box.get_children():
		_catalogue_box.remove_child(c)
		c.queue_free()
	var cat := _sel(_cat_opt)
	var type := _sel(_type_opt)
	var race := _sel(_race_opt)
	var cost := _sel(_cost_opt)
	var n := 0
	for d in CardDB.all():
		if not matches(d, _search.text, cat, type, race, cost):
			continue
		n += 1
		_catalogue_box.add_child(_catalogue_row(d))
	_result_label.text = "%d of %d cards" % [n, CardDB.all().size()]
	if n == 0:
		_catalogue_box.add_child(UIStyle.label("No cards match these filters.", 14, UIStyle.TEXT_DIM))


func _catalogue_row(d: Dictionary) -> Control:
	var id := int(d["id"])
	var row := HBoxContainer.new()
	row.set_meta("card_id", id)
	row.add_theme_constant_override("separation", 6)
	row.add_child(_swatch(d))
	var status := String(_summary(id)["support"])
	var nm := _name_button(("! " if status != "full" else "") + String(d["name"]), UIStyle.TEXT if status == "full" else UIStyle.BAD, id)
	nm.tooltip_text = "Implementation: %s" % status if status != "full" else ""
	nm.mouse_entered.connect(func(): show_preview(id))
	row.add_child(nm)
	var info := PackedStringArray()
	info.append(UIStyle.CATEGORY_NAMES.get(d["category"], d["category"]))
	if d["type"] != null and d["type"] != "":
		info.append(String(d["type"]))
	info.append(CardDB.cost_label(d))
	var il := UIStyle.label(" · ".join(info), 12, UIStyle.TEXT_DIM)
	il.custom_minimum_size = Vector2(190, 0)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(il)
	var cnt := UIStyle.label("", 13, UIStyle.GOLD_HI)
	cnt.name = "Count"
	cnt.custom_minimum_size = Vector2(34, 0)
	row.add_child(cnt)
	var add := UIStyle.button("+", 14)
	add.custom_minimum_size = Vector2(32, 0)
	add.pressed.connect(func(): add_card(id))
	row.add_child(add)
	var rem := UIStyle.button("-", 14)
	rem.custom_minimum_size = Vector2(32, 0)
	rem.pressed.connect(func(): remove_card(id))
	row.add_child(rem)
	_set_count_label(row)
	return row


## Category colour strip at the start of a catalogue / deck row.
static func _swatch(d: Dictionary) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.color = UIStyle.CATEGORY_COLORS.get(d["category"], Color.GRAY)
	swatch.custom_minimum_size = Vector2(SWATCH_W, 0)
	return swatch


## Flat, left-aligned card-name button of a row; pressing it previews card `id`.
func _name_button(text: String, color: Color, id: int) -> Button:
	var nm := Button.new()
	nm.text = text
	nm.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nm.flat = true
	nm.focus_mode = Control.FOCUS_NONE
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	nm.add_theme_color_override("font_color", color)
	nm.pressed.connect(func(): show_preview(id))
	return nm


func _set_count_label(row: Node) -> void:
	var n := int(counts.get(int(row.get_meta("card_id")), 0))
	(row.get_node("Count") as Label).text = ("x%d" % n) if n > 0 else ""


func _refresh_catalogue_counts() -> void:
	for row in _catalogue_box.get_children():
		if row.has_meta("card_id"):
			_set_count_label(row)


func _refresh_deck() -> void:
	for c in _deck_box.get_children():
		_deck_box.remove_child(c)
		c.queue_free()
	var cards := counts_to_cards(counts)
	var sc := DeckStore.split_counts(cards)
	_deck_summary.text = "%d cards   Main %d   Extra %d   (%d unique)" % [cards.size(), sc["main"], sc["extra"], counts.size()]
	_empty_note.visible = cards.is_empty()
	for group in ["Main Deck", "Extra Deck"]:
		var want_extra: bool = group == "Extra Deck"
		var ids := []
		var total := 0
		for id in counts.keys():
			if CardDB.is_extra_category(CardDB.get_def(int(id))["category"]) == want_extra:
				ids.append(int(id))
				total += int(counts[id])
		if ids.is_empty():
			continue
		ids.sort_custom(func(a, b):
			var da := CardDB.get_def(a)
			var db := CardDB.get_def(b)
			if da["category"] != db["category"]:
				return String(da["category"]) < String(db["category"])
			return String(da["name"]) < String(db["name"]))
		var h := UIStyle.title_label("%s  (%d)" % [group, total], 15, UIStyle.GOLD)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deck_box.add_child(h)
		for id in ids:
			_deck_box.add_child(_deck_row(id))


func _deck_row(id: int) -> Control:
	var d := CardDB.get_def(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_swatch(d))
	row.add_child(_name_button("%dx  %s" % [counts[id], d["name"]], UIStyle.TEXT, id))
	row.add_child(UIStyle.label(CardDB.cost_label(d), 12, UIStyle.TEXT_DIM))
	var add := UIStyle.button("+", 13)
	add.custom_minimum_size = Vector2(30, 0)
	add.pressed.connect(func(): add_card(id))
	row.add_child(add)
	var rem := UIStyle.button("-", 13)
	rem.custom_minimum_size = Vector2(30, 0)
	rem.pressed.connect(func(): remove_card(id))
	row.add_child(rem)
	return row


func _refresh_saved() -> void:
	var keep := deck_name_edit.text if deck_name_edit != null else ""
	_saved_opt.clear()
	var decks := DeckStore.list()
	if decks.is_empty():
		_saved_opt.add_item("(no saved decks)")
		_saved_opt.disabled = true
		return
	_saved_opt.disabled = false
	for i in decks.size():
		var dk: Dictionary = decks[i]
		var c := DeckStore.split_counts(dk["cards"])
		_saved_opt.add_item("%s  (%d+%d)" % [dk["name"], c["main"], c["extra"]])
		_saved_opt.set_item_metadata(i, dk["name"])
		if dk["name"] == keep:
			_saved_opt.select(i)


# ------------------------------------------------------------ actions

func _say(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UIStyle.BAD if bad else UIStyle.TEXT_DIM)


func _load_selected() -> void:
	if _saved_opt.disabled or _saved_opt.selected < 0:
		return
	var n := String(_saved_opt.get_item_metadata(_saved_opt.selected))
	for dk in DeckStore.list():
		if dk["name"] == n:
			load_cards(n, dk["cards"])
			_say("Loaded \"%s\"." % n)
			return


func _copy_starter() -> void:
	var i := _starter_opt.selected
	if i < 0 or i >= _starters.size():
		return
	var s: Dictionary = _starters[i]
	load_cards(String(s["name"]) + " (copy)", s["main"] + s["extra"])
	dirty = true
	_say("Copied starter deck \"%s\". Save to keep your edits." % s["name"])


## Runs `proceed` immediately, or after confirmation if there are unsaved edits.
func _guard_unsaved(proceed: Callable) -> void:
	if dirty and not counts.is_empty():
		_confirm("Unsaved changes", "You have unsaved changes to this deck. Discard them?", "Discard", proceed)
	else:
		proceed.call()


func _on_back() -> void:
	_guard_unsaved(func(): closed.emit())


func _ask_delete() -> void:
	var n := deck_name_edit.text.strip_edges()
	var exists := false
	for dk in DeckStore.list():
		if dk["name"] == n:
			exists = true
	if not exists:
		_say("No saved deck named \"%s\" to delete." % n, true)
		return
	_confirm("Delete deck", "Delete the saved deck \"%s\"? This cannot be undone." % n, "Delete", func():
		DeckStore.delete_deck(n)
		_refresh_saved()
		_say("Deleted \"%s\"." % n))


## Asks `text` in the shared ConfirmDialog; `on_yes` runs when `yes_text` is pressed.
func _confirm(title: String, text: String, yes_text: String, on_yes: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = ConfirmDialog.open(self, title, text, yes_text, on_yes, "Cancel")
