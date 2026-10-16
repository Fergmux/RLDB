class_name DeckBuilder
extends Control
## Custom deck builder (P-03). No limits on size, category mix or duplicates; the
## deck is a flat id list and Fusion/Ritual/Arcane cards land in the Extra Deck
## automatically (shown grouped here). Presentation only: persists through DeckStore.
##
## Layout (F04 polish): catalogue of free-standing cards | preview with the in-game details
## pane | the deck (name + inline errors, saved/starter deck tiles, Main/Extra card grids).

signal closed

const MARGIN := 16
## Catalogue card ("hand" 120x180) and the cell around it (a few px of room for the glow).
const CARD_W := 120
const CARD_H := 180
const CELL_PAD := 11
const CELL_MIN_W := CARD_W + CELL_PAD * 2
const CELL_H := CARD_H + CELL_PAD * 2
## Deck grid tile: "mini" card 90x135, count badge, a -/+ strip underneath.
const TILE_W := 100
const TILE_H := 175
## Smallest gap between catalogue columns (the rest of the width is shared out between them).
const GRID_MIN_GAP := 8

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
var _grid: HFlowContainer
var _no_match: Control
## card id -> its catalogue grid cell (one per catalogue card, built once; filters only hide cells).
var _cells: Dictionary = {}
var _loaded_name: String = ""
var _deck_box: VBoxContainer
var _deck_chips: HFlowContainer
var _empty_note: Control
## card id -> its deck grid tile (reused between refreshes so hover and scroll survive a click).
var _deck_tiles: Dictionary = {}
var _preview_holder: VBoxContainer
var _details: CardDetailsPanel
var _preview_note: Label
var _preview_count: Label
var _name_err: Label
var _name_box: VBoxContainer
var _name_shake: Tween
var _list_box: VBoxContainer
var _tab_saved: Button
var _tab_starters: Button
var _show_starters: bool = false
var _status: Label
var _status_panel: PanelContainer
var _status_tw: Tween
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
	_build_cells()
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


## The up-to-`n` most common non-empty Types in a deck id list, most frequent first.
static func dominant_types(cards: Array, n: int = 3) -> Array:
	var tally := {}
	for id in cards:
		var t = CardDB.get_def(int(id))["type"]
		if t != null and String(t) != "":
			tally[String(t)] = int(tally.get(String(t), 0)) + 1
	var types := tally.keys()
	types.sort_custom(func(a, b):
		if tally[a] != tally[b]:
			return tally[a] > tally[b]
		return String(a) < String(b))
	return types.slice(0, n)


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
	_loaded_name = ""
	dirty = false
	_clear_name_error()
	_say("Started a new empty deck.")
	_refresh_saved()
	_refresh_deck()
	_refresh_catalogue_counts()


## Replaces the working deck with `cards` under `name` (not dirty).
func load_cards(name: String, cards: Array) -> void:
	counts = cards_to_counts(cards)
	deck_name_edit.text = name
	_loaded_name = name
	dirty = false
	_clear_name_error()
	_refresh_saved()
	_refresh_deck()
	_refresh_catalogue_counts()


## Saves the working deck under its name; false (with an inline message by the name field) when unnamed.
func save() -> bool:
	var n := deck_name_edit.text.strip_edges()
	if n == "":
		_say("Give the deck a name before saving.", true)
		return false
	DeckStore.save_deck(n, counts_to_cards(counts))
	dirty = false
	_loaded_name = n
	_clear_name_error()
	_refresh_saved()
	_refresh_deck()
	_say("Saved \"%s\" (%d cards). Pick it under \"Your saved decks\" when you set up a series." % [n, counts_to_cards(counts).size()])
	return true


## Renames the loaded saved deck to the text in the name field, keeping the working cards.
## False (with a message) when no saved deck is loaded, the name is empty/unchanged or taken.
func rename_loaded() -> bool:
	var n := deck_name_edit.text.strip_edges()
	if _loaded_name == "" or not _saved_exists(_loaded_name):
		_say("Load a saved deck first, then type a new name and press Rename.", true)
		return false
	if n == "" or n == _loaded_name:
		_say("Type a different name to rename \"%s\"." % _loaded_name, true)
		return false
	if _saved_exists(n):
		_say("A saved deck named \"%s\" already exists." % n, true)
		return false
	DeckStore.delete_deck(_loaded_name)
	DeckStore.save_deck(n, counts_to_cards(counts))
	_say("Renamed \"%s\" to \"%s\"." % [_loaded_name, n])
	_loaded_name = n
	dirty = false
	_clear_name_error()
	_refresh_saved()
	_refresh_deck()
	return true


func _saved_exists(n: String) -> bool:
	for dk in DeckStore.list():
		if dk["name"] == n:
			return true
	return false


## The grid cell widget of catalogue card `id` (null when absent): emit its `pressed` / `right_pressed`.
func cell_widget(id: int) -> CardWidget:
	return _cells[id]["widget"] if _cells.has(id) else null


## The deck-grid card widget of card `id` (null when it is not in the deck).
func deck_widget(id: int) -> CardWidget:
	return (_deck_tiles[id].get_meta("rec") as Dictionary)["widget"] if _deck_tiles.has(id) and counts.has(id) else null


## Number of catalogue cells currently shown (passing the filters).
func visible_cell_count() -> int:
	var n := 0
	for c in _cells.values():
		if c["cell"].visible:
			n += 1
	return n


## The text of the inline error beside the name field ("" when none is shown).
func name_error() -> String:
	return _name_err.text if _name_err.visible else ""


## The saved-deck tile for deck `n` (null when absent): click it to load.
func saved_row(n: String) -> Control:
	for r in _list_box.get_children():
		if r.has_meta("deck_name") and r.get_meta("deck_name") == n:
			return r
	return null


## Opens the shared card inspector for catalogue card `id`; the working deck is untouched.
func inspect_card(id: int) -> CardInspector:
	return CardInspector.open(self, MatchView.summary_view(_summary(id)))


## Shows card `id` big in the preview column with the same details pane as the game screen.
func show_preview(id: int) -> void:
	_preview_id = id
	for c in _preview_holder.get_children():
		_preview_holder.remove_child(c)
		c.queue_free()
	var s := _summary(id)
	var cw := CardWidget.new().setup(MatchView.summary_view(s), "big")
	cw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cw.show_tooltip = false
	cw.tooltip_text = ""
	_preview_holder.add_child(cw)
	_details.show_card(MatchView.summary_view(s))
	_preview_note.visible = s["support"] != "full"
	_preview_note.text = "Implementation: %s" % s["support"]
	_update_preview_count()


func _update_preview_count() -> void:
	var n := int(counts.get(_preview_id, 0))
	_preview_count.text = ("In your deck: x%d" % n) if n > 0 else "Not in your deck"
	_preview_count.add_theme_color_override("font_color", UIStyle.GOLD_HI if n > 0 else UIStyle.TEXT_DIM)


# ------------------------------------------------------------ small widgets

## Round-cornered icon button drawn from vectors (no font glyph needed): minus, plus, cross, pencil.
class IconBtn extends JuicyButton:
	var glyph: String = "minus"
	var tint: Color = UIStyle.TEXT

	func _draw() -> void:
		super._draw()
		var c := size / 2.0
		var col := UIStyle.DISABLED if disabled else (UIStyle.GOLD_HI if is_hovered() else tint)
		var r := minf(size.x, size.y) * 0.24
		var w := maxf(1.8, minf(size.x, size.y) * 0.1)
		match glyph:
			"minus":
				draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, w)
			"plus":
				draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, w)
				draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, w)
			"cross":
				draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, w)
				draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, w)
			"pencil":
				draw_line(c + Vector2(r, -r), c + Vector2(-r * 0.7, r * 0.7), col, w * 1.6)
				draw_line(c + Vector2(-r, r), c + Vector2(-r * 0.3, r), col, w * 0.8)
				draw_line(c + Vector2(-r, r), c + Vector2(-r, r * 0.4), col, w * 0.8)


## Gold diamond followed by a rule that fades out to the right (section underline / header ornament).
class Rule extends Control:
	var fade: bool = true

	func _init(with_fade: bool = true) -> void:
		fade = with_fade
		custom_minimum_size = Vector2(0, 10)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y / 2.0
		var d := 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(d, y - d), Vector2(d * 2, y), Vector2(d, y + d), Vector2(0, y)]), UIStyle.GOLD)
		var pts := PackedVector2Array([Vector2(d * 2 + 4, y), Vector2(size.x, y)])
		var cols := PackedColorArray([Color(UIStyle.GOLD, 0.85), Color(UIStyle.GOLD, 0.0 if fade else 0.35)])
		draw_polyline_colors(pts, cols, 1.5)


## A bronze-trimmed, softly shaded plate for one of the three columns.
static func _plate(color: Color = UIStyle.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.panel_style(color, UIStyle.BRONZE, 8)
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	# Vertical sheen: lighter at the top, gone by the middle.
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.92, 0.75, 0.07), Color(1, 0.92, 0.75, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	var sheen := TextureRect.new()
	sheen.texture = gt
	sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheen.stretch_mode = TextureRect.STRETCH_SCALE
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(sheen)
	return p


## Section heading: Cinzel title with the fading gold rule under it.
static func _heading(text: String, size: int = 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(UIStyle.title_label(text, size, UIStyle.GOLD_HI))
	v.add_child(Rule.new())
	return v


## Small rounded pill: a bold value and a dim caption.
static func _chip(value: String, caption: String, accent: Color = UIStyle.GOLD_HI) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIStyle.flat(Color(0, 0, 0, 0.32), Color(UIStyle.BRONZE, 0.7), 1, 10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var a := UIStyle.label(value, 13, accent)
	a.add_theme_font_override("font", UIStyle.font_bold())
	h.add_child(a)
	if caption != "":
		h.add_child(UIStyle.label(caption, 12, UIStyle.TEXT_DIM))
	return pc


## Gold count pill ("x3") pinned onto a card corner.
static func _count_badge() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIStyle.flat(UIStyle.GOLD, UIStyle.GOLD_HI, 1, 10)
	sb.border_color = Color("fff0b8")
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 1)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIStyle.label("", 14, UIStyle.ON_GOLD)
	l.add_theme_font_override("font", UIStyle.font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "Text"
	pc.add_child(l)
	return pc


## Round -/+/x/pencil button of `px` square; `danger` tints the rim red.
static func _icon_btn(glyph: String, px: int, tip: String, danger: bool = false) -> IconBtn:
	var b := IconBtn.new()
	b.glyph = glyph
	b.custom_minimum_size = Vector2(px, px)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	var rim := UIStyle.BAD.darkened(0.15) if danger else UIStyle.BRONZE
	var n := UIStyle.flat(Color(0.07, 0.06, 0.05, 0.94), rim, 1, px / 2)
	var h := UIStyle.flat(Color(0.16, 0.13, 0.09, 0.98), UIStyle.BAD if danger else UIStyle.GOLD_HI, 1, px / 2)
	var p := UIStyle.flat(Color(0.03, 0.025, 0.02, 1.0), UIStyle.GOLD_HI, 1, px / 2)
	for sb in [n, h, p]:
		sb.set_content_margin_all(0)
	UIStyle.lift_style(n, Color(0, 0, 0, 0.55), 3, 1)
	UIStyle.lift_style(h, Color(UIStyle.BAD if danger else UIStyle.GOLD, 0.45), 7, 0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	return b


## Gives a LineEdit the house look (ink fill, bronze rim, gold when focused).
static func _style_edit(le: LineEdit, err: bool = false) -> void:
	var n := UIStyle.flat(UIStyle.PANEL_INK, UIStyle.BAD if err else UIStyle.BRONZE, 2 if err else 1, 6)
	var f := UIStyle.flat(UIStyle.PANEL_INK, UIStyle.BAD if err else UIStyle.GOLD, 2, 6)
	for sb in [n, f]:
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
	n.shadow_color = Color(0, 0, 0, 0.35)
	n.shadow_size = 3
	n.shadow_offset = Vector2(0, 1)
	le.add_theme_stylebox_override("normal", n)
	le.add_theme_stylebox_override("focus", f)
	le.add_theme_color_override("font_color", UIStyle.TEXT)
	le.add_theme_color_override("font_placeholder_color", Color(UIStyle.TEXT_DIM, 0.7))
	le.add_theme_color_override("caret_color", UIStyle.GOLD_HI)
	le.add_theme_color_override("selection_color", Color(UIStyle.GOLD, 0.35))
	le.add_theme_font_size_override("font_size", 15)


## Pins `c` to a corner of its parent Control, `dx`/`dy` px in from the corner ("tr", "tl", "br", "bl").
static func _pin(c: Control, corner: String, dx: float, dy: float) -> void:
	var ax := 1.0 if corner.ends_with("r") else (0.5 if corner.ends_with("c") else 0.0)
	var ay := 1.0 if corner.begins_with("b") else 0.0
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if ax == 1.0 else (Control.GROW_DIRECTION_BOTH if ax == 0.5 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if ay == 1.0 else Control.GROW_DIRECTION_END
	var ox := -dx if ax == 1.0 else (0.0 if ax == 0.5 else dx)
	var oy := -dy if ay == 1.0 else dy
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy


## Empty-state block: a dashed-look slot with a title and a hint.
static func _empty_state(title: String, hint: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIStyle.flat(Color(0, 0, 0, 0.2), Color(UIStyle.BRONZE, 0.5), 1, 8)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var t := UIStyle.label(title, 16, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := UIStyle.label(hint, 13, UIStyle.TEXT_DIM, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	return pc


## Brief scale pulse on a card widget when it is clicked (skipped under reduced motion).
func _pulse(w: Control) -> void:
	if UIStyle.reduce_motion or not w.is_inside_tree():
		return
	w.pivot_offset = w.size / 2.0
	w.scale = Vector2(0.94, 0.94)
	var tw := w.create_tween()
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------ construction

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIStyle.TABLE_WOOD
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vignette := TextureRect.new()
	var vg := Gradient.new()
	vg.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.45)])
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.45)
	vt.fill_to = Vector2(1.05, 1.0)
	vt.width = 256
	vt.height = 256
	vignette.texture = vt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	var margin := UIStyle.full_rect_margin(MARGIN)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	tv.add_child(UIStyle.title_label("DECK BUILDER", 30, UIStyle.GOLD))
	tv.add_child(Rule.new())
	head.add_child(tv)
	var back := UIStyle.button("Back", 15)
	back.custom_minimum_size = Vector2(90, 36)
	back.pressed.connect(_on_back)
	head.add_child(back)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_build_catalogue(body)
	_build_preview(body)
	_build_deck(body)

	_status_panel = PanelContainer.new()
	var ssb := UIStyle.flat(Color(0, 0, 0, 0.3), Color(UIStyle.BRONZE, 0.5), 1, 6)
	ssb.content_margin_left = 12
	ssb.content_margin_right = 12
	_status_panel.add_theme_stylebox_override("panel", ssb)
	_status_panel.visible = false
	_status_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = UIStyle.label("", 14, UIStyle.TEXT)
	_status_panel.add_child(_status)
	root.add_child(_status_panel)


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
	v.add_child(_heading("Card catalogue"))
	_search = LineEdit.new()
	_search.placeholder_text = "Search name or rules text..."
	_search.clear_button_enabled = true
	_style_edit(_search)
	_search.text_changed.connect(func(_t): _refresh_catalogue())
	v.add_child(_search)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 6)
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
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(_grid)
	_grid.resized.connect(_spread_grid)
	_no_match = _empty_state("No cards match", "Loosen the search or press Clear filters.")
	v.add_child(_no_match)


func _build_preview(body: HBoxContainer) -> void:
	var plate := _plate(UIStyle.PANEL_INK)
	plate.custom_minimum_size = Vector2(320, 0)
	body.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	plate.add_child(v)
	v.add_child(_heading("Preview"))
	_preview_holder = VBoxContainer.new()
	_preview_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_preview_holder)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	_details = CardDetailsPanel.new()
	inner.add_child(_details)
	_preview_note = UIStyle.label("", 13, UIStyle.BAD)
	inner.add_child(_preview_note)
	_preview_count = UIStyle.label("", 14, UIStyle.TEXT_DIM)
	_preview_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_preview_count)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var add := UIStyle.primary_button("Add to deck", 14)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.custom_minimum_size = Vector2(0, 34)
	add.pressed.connect(func(): if _preview_id >= 0: add_card(_preview_id))
	row.add_child(add)
	var rem := UIStyle.button("Remove one", 14)
	rem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rem.custom_minimum_size = Vector2(0, 34)
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
	v.add_child(_heading("Your deck"))

	# Name field with its inline error line right under it (F04-20).
	_name_box = VBoxContainer.new()
	_name_box.add_theme_constant_override("separation", 3)
	v.add_child(_name_box)
	deck_name_edit = LineEdit.new()
	deck_name_edit.placeholder_text = "Deck name"
	deck_name_edit.max_length = 40
	_style_edit(deck_name_edit)
	deck_name_edit.text_changed.connect(func(_t):
		dirty = true
		_clear_name_error()
		_refresh_deck())
	deck_name_edit.text_submitted.connect(func(_t): _on_save_pressed())
	_name_box.add_child(deck_name_edit)
	_name_err = UIStyle.label("", 13, UIStyle.BAD, true)
	_name_err.add_theme_font_override("font", UIStyle.font_bold())
	_name_err.visible = false
	_name_box.add_child(_name_err)

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	v.add_child(actions)
	var save_b := UIStyle.primary_button("Save", 14)
	save_b.custom_minimum_size = Vector2(84, 32)
	save_b.pressed.connect(_on_save_pressed)
	actions.add_child(save_b)
	for spec in [["New", "Start a new empty deck"], ["Rename", "Rename the loaded saved deck to the name typed above"], ["Delete", "Delete the saved deck named above"]]:
		var b := UIStyle.button(spec[0], 14)
		b.custom_minimum_size = Vector2(76, 32)
		b.tooltip_text = spec[1]
		actions.add_child(b)
		match spec[0]:
			"New": b.pressed.connect(func(): _guard_unsaved(new_deck))
			"Rename": b.pressed.connect(rename_loaded)
			_: b.pressed.connect(func(): _ask_delete())

	# Saved / starter deck tiles (F04-17): a segmented switch over one scrolling list.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	_tab_saved = _tab_button("Saved decks", group, true)
	_tab_starters = _tab_button("Starter decks", group, false)
	_tab_saved.pressed.connect(func(): _show_starters = false; _refresh_saved())
	_tab_starters.pressed.connect(func(): _show_starters = true; _refresh_saved())
	tabs.add_child(_tab_saved)
	tabs.add_child(_tab_starters)
	var list_sc := ScrollContainer.new()
	list_sc.custom_minimum_size = Vector2(0, 176)
	list_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(list_sc)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 5)
	list_sc.add_child(_list_box)

	v.add_child(Rule.new(false))
	_deck_chips = HFlowContainer.new()
	_deck_chips.add_theme_constant_override("h_separation", 6)
	_deck_chips.add_theme_constant_override("v_separation", 4)
	v.add_child(_deck_chips)
	_empty_note = _empty_state("Your deck is empty", "Click cards in the catalogue to add them. Fusion, Ritual and Arcane cards go to the Extra Deck.")
	v.add_child(_empty_note)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 1.6
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_deck_box = VBoxContainer.new()
	_deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_box.add_theme_constant_override("separation", 8)
	sc.add_child(_deck_box)


func _tab_button(text: String, group: ButtonGroup, on: bool) -> Button:
	var b := UIStyle.button(text, 13)
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIStyle.flat(Color(0, 0, 0, 0.3), Color(UIStyle.BRONZE, 0.7), 1, 6)
	var h := UIStyle.flat(Color(0.14, 0.11, 0.08), UIStyle.GOLD, 1, 6)
	var p := UIStyle.flat(UIStyle.GOLD, UIStyle.GOLD_HI, 1, 6)
	for sb in [n, h, p]:
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_color_override("font_pressed_color", UIStyle.ON_GOLD)
	b.add_theme_color_override("font_hover_pressed_color", UIStyle.ON_GOLD)
	b.add_theme_color_override("font_color", UIStyle.MUTED)
	return b


# ------------------------------------------------------------ refresh

func _summary(id: int) -> Dictionary:
	if not _summaries.has(id):
		_summaries[id] = Series.card_summary(id)
	return _summaries[id]


func _sel(o: OptionButton) -> String:
	return String(o.get_item_metadata(o.selected)) if o.selected >= 0 else ""


## Builds one grid cell per catalogue card (once). Left-click adds a copy, right-click inspects.
func _build_cells() -> void:
	for d in CardDB.all():
		_grid.add_child(_make_cell(d))


## Spreads the catalogue columns across the full width: the leftover space becomes the gap
## between columns instead of a dead strip at the right edge.
func _spread_grid() -> void:
	var w := _grid.size.x
	var cw := float(CELL_MIN_W)
	var cols := maxi(1, int(floor((w + GRID_MIN_GAP) / (cw + GRID_MIN_GAP))))
	var gap := GRID_MIN_GAP if cols == 1 else int(floor((w - cols * cw) / float(cols - 1)))
	if _grid.get_theme_constant("h_separation") != gap:
		_grid.add_theme_constant_override("h_separation", gap)


## A catalogue cell: the card alone (no caption box), a glow behind it and a gold count badge plus
## a round minus control once it is in the deck. Basic variants read apart by the Type icon on the card.
func _make_cell(d: Dictionary) -> Control:
	var id := int(d["id"])
	var sm := _summary(id)
	var status := String(sm["support"])
	var cell := Control.new()
	cell.set_meta("card_id", id)
	cell.custom_minimum_size = Vector2(CELL_MIN_W, CELL_H)
	var glow := Panel.new()
	var gs := UIStyle.flat(Color(UIStyle.GOLD, 0.0), UIStyle.GOLD_HI, 2, 8)
	gs.shadow_color = Color(UIStyle.GOLD, 0.55)
	gs.shadow_size = 9
	glow.add_theme_stylebox_override("panel", gs)
	glow.position = Vector2(CELL_PAD, CELL_PAD)
	glow.size = Vector2(CARD_W, CARD_H)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(glow)
	var w := CardWidget.new().setup(MatchView.summary_view(sm), "hand")
	w.position = Vector2(CELL_PAD, CELL_PAD)
	if status != "full":
		w.tooltip_text += "\n\nImplementation: %s" % status
	w.pressed.connect(func(_w): add_card(id); _pulse(w))
	w.right_pressed.connect(func(_w): inspect_card(id))
	w.mouse_entered.connect(func(): show_preview(id))
	cell.add_child(w)
	if status != "full":
		var warn := _chip("!", "", UIStyle.BAD)
		warn.tooltip_text = "Implementation: %s" % status
		_pin(warn, "tl", 2, 2)
		cell.add_child(warn)
	var badge := _count_badge()
	_pin(badge, "bc", 0, CELL_PAD + 8)
	cell.add_child(badge)
	var rem := _icon_btn("minus", 22, "Remove one copy from the deck", true)
	_pin(rem, "br", 0, 0)
	rem.pressed.connect(func(): remove_card(id))
	cell.add_child(rem)
	_cells[id] = {"cell": cell, "widget": w, "badge": badge, "remove": rem, "glow": glow}
	_update_cell(id)
	return cell


func _update_cell(id: int) -> void:
	var c: Dictionary = _cells[id]
	var n := int(counts.get(id, 0))
	((c["badge"] as Control).get_node("Text") as Label).text = "x%d" % n
	(c["badge"] as Control).visible = n > 0
	(c["remove"] as Control).visible = n > 0
	(c["glow"] as Control).visible = n > 0


func _refresh_catalogue() -> void:
	var cat := _sel(_cat_opt)
	var type := _sel(_type_opt)
	var race := _sel(_race_opt)
	var cost := _sel(_cost_opt)
	var n := 0
	for d in CardDB.all():
		var show := matches(d, _search.text, cat, type, race, cost)
		_cells[int(d["id"])]["cell"].visible = show
		if show:
			n += 1
	_result_label.text = "%d of %d cards   ·   click a card to add it, right-click to inspect" % [n, CardDB.all().size()]
	_no_match.visible = n == 0


func _refresh_catalogue_counts() -> void:
	for id in _cells:
		_update_cell(id)


## One deck-grid tile (built once per card id): mini card, gold count badge, -/+ strip.
func _make_tile(id: int) -> Control:
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
	tile.set_meta("card_id", id)
	var w := CardWidget.new().setup(MatchView.summary_view(_summary(id)), "mini")
	w.position = Vector2(5, 6)
	w.show_tooltip = false
	w.tooltip_text = "Click to remove one copy · right-click to inspect"
	w.pressed.connect(func(_w): remove_card(id))
	w.right_pressed.connect(func(_w): inspect_card(id))
	w.mouse_entered.connect(func(): show_preview(id))
	tile.add_child(w)
	var badge := _count_badge()
	_pin(badge, "bc", 0, TILE_H - 141 + 8)
	tile.add_child(badge)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.position = Vector2(0, 144)
	strip.size = Vector2(TILE_W, 26)
	tile.add_child(strip)
	var minus := _icon_btn("minus", 24, "Remove one copy", true)
	minus.pressed.connect(func(): remove_card(id))
	strip.add_child(minus)
	var plus := _icon_btn("plus", 24, "Add one copy")
	plus.pressed.connect(func(): add_card(id))
	strip.add_child(plus)
	var rec := {"widget": w, "badge": badge}
	_deck_tiles[id] = tile
	tile.set_meta("rec", rec)
	return tile


func _section_header(text: String, total: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UIStyle.title_label(text.to_upper(), 15, UIStyle.GOLD)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	h.add_child(_chip(str(total), "cards"))
	h.add_child(Rule.new())
	return h


func _refresh_deck() -> void:
	# Detach the reusable tiles, drop the old section containers, drop tiles of cards that left the deck.
	for id in _deck_tiles.keys():
		var tile: Control = _deck_tiles[id]
		if tile.get_parent() != null:
			tile.get_parent().remove_child(tile)
		if not counts.has(id):
			tile.queue_free()
			_deck_tiles.erase(id)
	for c in _deck_box.get_children():
		_deck_box.remove_child(c)
		c.queue_free()
	var cards := counts_to_cards(counts)
	var sc := DeckStore.split_counts(cards)
	for c in _deck_chips.get_children():
		_deck_chips.remove_child(c)
		c.queue_free()
	_deck_chips.add_child(_chip(str(cards.size()), "cards"))
	_deck_chips.add_child(_chip(str(sc["main"]), "Main"))
	_deck_chips.add_child(_chip(str(sc["extra"]), "Extra"))
	_deck_chips.add_child(_chip(str(counts.size()), "unique"))
	if dirty:
		_deck_chips.add_child(_chip("Unsaved", "", UIStyle.TARGET))
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
		_deck_box.add_child(_section_header(group, total))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 2)
		_deck_box.add_child(flow)
		for id in ids:
			var tile: Control = _deck_tiles[id] if _deck_tiles.has(id) else _make_tile(id)
			flow.add_child(tile)
			var label := ((tile.get_meta("rec") as Dictionary)["badge"] as Control).get_node("Text") as Label
			label.text = "x%d" % int(counts[id])
	_update_preview_count()


## Rebuilds the saved-deck (or starter) tile list for the active tab.
func _refresh_saved() -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	var decks := DeckStore.list()
	_tab_saved.text = "Saved decks (%d)" % decks.size()
	_tab_starters.text = "Starter decks (%d)" % _starters.size()
	_tab_saved.set_pressed_no_signal(not _show_starters)
	_tab_starters.set_pressed_no_signal(_show_starters)
	if _show_starters:
		for s in _starters:
			_list_box.add_child(_deck_tile(String(s["name"]), s["main"] + s["extra"], false, true))
		return
	if decks.is_empty():
		_list_box.add_child(_empty_state("No saved decks yet", "Name your deck and press Save, or copy a starter deck."))
		return
	for dk in decks:
		_list_box.add_child(_deck_tile(String(dk["name"]), dk["cards"], String(dk["name"]) == _loaded_name, false))


## One deck tile: accent bar, name, Main/Extra counts, dominant Type icons, hover and loaded states, actions.
func _deck_tile(deck_name: String, cards: Array, loaded: bool, starter: bool) -> Control:
	var pc := PanelContainer.new()
	pc.set_meta("deck_name", deck_name)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.tooltip_text = ("Copy \"%s\" into the editor" if starter else "Load \"%s\"") % deck_name
	var styles := {}
	for k in ["normal", "hover", "loaded"]:
		var col := Color(0.05, 0.045, 0.04, 0.9)
		var rim := Color(UIStyle.BRONZE, 0.6)
		var width := 1
		if k == "hover":
			col = Color(0.13, 0.105, 0.075, 0.95)
			rim = UIStyle.GOLD
		elif k == "loaded":
			col = Color(0.16, 0.12, 0.06, 0.95)
			rim = UIStyle.GOLD_HI
			width = 2
		var sb := UIStyle.flat(col, rim, width, 7)
		sb.content_margin_left = 12
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if k != "normal":
			UIStyle.lift_style(sb, Color(UIStyle.GOLD, 0.28), 7, 0)
		styles[k] = sb
	var base: String = "loaded" if loaded else "normal"
	pc.add_theme_stylebox_override("panel", styles[base])
	pc.mouse_entered.connect(func(): pc.add_theme_stylebox_override("panel", styles["hover"]))
	pc.mouse_exited.connect(func(): pc.add_theme_stylebox_override("panel", styles[base]))
	pc.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if starter:
				_guard_unsaved(func(): _copy_starter_cards(deck_name, cards))
			else:
				_guard_unsaved(func(): _load_named(deck_name))
			pc.accept_event())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var bar := ColorRect.new()
	bar.color = UIStyle.GOLD_HI if loaded else Color(UIStyle.BRONZE, 0.8)
	bar.custom_minimum_size = Vector2(4, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var nm := UIStyle.label(deck_name, 16, UIStyle.GOLD_HI if loaded else UIStyle.TEXT)
	nm.add_theme_font_override("font", UIStyle.font_bold())
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 6)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	var c := DeckStore.split_counts(cards)
	sub.add_child(UIStyle.label("Main %d  ·  Extra %d" % [c["main"], c["extra"]], 12, UIStyle.TEXT_DIM))
	for t in dominant_types(cards):
		var tb := TypeIcons.TypeBadge.new(String(t), 17)
		tb.tooltip_text = String(t)
		sub.add_child(tb)
	if loaded:
		var tag := UIStyle.label("LOADED", 11, UIStyle.GOLD)
		tag.add_theme_font_override("font", UIStyle.font_bold())
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(tag)
	if starter:
		var cp := UIStyle.button("Copy", 13)
		cp.custom_minimum_size = Vector2(64, 28)
		cp.pressed.connect(func(): _guard_unsaved(func(): _copy_starter_cards(deck_name, cards)))
		h.add_child(cp)
	else:
		var ed := _icon_btn("pencil", 28, "Rename: load this deck and edit its name")
		ed.pressed.connect(func(): _guard_unsaved(func(): _begin_rename(deck_name)))
		h.add_child(ed)
		var del := _icon_btn("cross", 28, "Delete this saved deck", true)
		del.pressed.connect(func(): _ask_delete(deck_name))
		h.add_child(del)
	return pc


# ------------------------------------------------------------ actions

## Reports `text`. Problems with the name (save, rename, delete) show inline under the name field;
## everything else goes to the status pill at the bottom, which fades after a few seconds.
func _say(text: String, bad: bool = false) -> void:
	if bad:
		_show_name_error(text)
		return
	_status.text = text
	_status_panel.visible = true
	_status_panel.modulate.a = 1.0
	if _status_tw != null and _status_tw.is_valid():
		_status_tw.kill()
	if not UIStyle.reduce_motion and is_inside_tree():
		_status_tw = create_tween()
		_status_tw.tween_interval(6.0)
		_status_tw.tween_property(_status_panel, "modulate:a", 0.0, 0.8)


func _show_name_error(text: String) -> void:
	_name_err.text = text
	_name_err.visible = true
	_style_edit(deck_name_edit, true)
	if UIStyle.reduce_motion or not is_inside_tree():
		return
	if _name_shake != null and _name_shake.is_valid():
		_name_shake.kill()
	_name_shake = create_tween()
	for dx in [-7.0, 7.0, -5.0, 5.0, -2.0, 0.0]:
		_name_shake.tween_property(deck_name_edit, "position:x", dx, 0.035)
	_name_shake.finished.connect(func(): _name_box.queue_sort())


func _clear_name_error() -> void:
	if _name_err == null or not _name_err.visible:
		return
	_name_err.visible = false
	_name_err.text = ""
	_style_edit(deck_name_edit, false)


## Save button / Enter in the name field: asks before replacing a different saved deck of the same name.
func _on_save_pressed() -> void:
	var n := deck_name_edit.text.strip_edges()
	if n != "" and n != _loaded_name and _saved_exists(n):
		_confirm("Replace deck", "A saved deck named \"%s\" already exists. Replace it?" % n, "Replace", func(): save())
	else:
		save()


func _load_named(n: String) -> void:
	for dk in DeckStore.list():
		if dk["name"] == n:
			load_cards(n, dk["cards"])
			_say("Loaded \"%s\"." % n)
			return


## Pencil on a saved tile: loads that deck and puts the caret in the name field, ready to retype.
func _begin_rename(n: String) -> void:
	_load_named(n)
	deck_name_edit.grab_focus()
	deck_name_edit.select_all()
	_say("Type the new name for \"%s\", then press Rename." % n)


func _copy_starter_cards(starter_name: String, cards: Array) -> void:
	load_cards(starter_name + " (copy)", cards)
	dirty = true
	_loaded_name = ""
	_refresh_saved()
	_refresh_deck()
	_say("Copied starter deck \"%s\". Save to keep your edits." % starter_name)


## Runs `proceed` immediately, or after confirmation if there are unsaved edits.
func _guard_unsaved(proceed: Callable) -> void:
	if dirty and not counts.is_empty():
		_confirm("Unsaved changes", "You have unsaved changes to this deck. Discard them?", "Discard", proceed)
	else:
		proceed.call()


func _on_back() -> void:
	_guard_unsaved(func(): closed.emit())


## Deletes saved deck `which` (default: the name typed in the field) after confirmation.
func _ask_delete(which: String = "") -> void:
	var n := which if which != "" else deck_name_edit.text.strip_edges()
	if not _saved_exists(n):
		_say("No saved deck named \"%s\" to delete." % n, true)
		return
	_confirm("Delete deck", "Delete the saved deck \"%s\"? This cannot be undone." % n, "Delete", func():
		DeckStore.delete_deck(n)
		if _loaded_name == n:
			_loaded_name = ""
		dirty = true
		_refresh_saved()
		_refresh_deck()
		_say("Deleted \"%s\". The cards are still in the editor; Save to keep them under a name." % n))


## Asks `text` in the shared ConfirmDialog; `on_yes` runs when `yes_text` is pressed.
func _confirm(title: String, text: String, yes_text: String, on_yes: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = ConfirmDialog.open(self, title, text, yes_text, on_yes, "Cancel")
