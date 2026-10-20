class_name DeckBuilder
extends Control
## Custom deck builder. The deck is a flat id list; Fusion/Ritual/Arcane cards land in the
## Extra Deck automatically (shown grouped here). Category mix and duplicates are free; size is
## capped by DeckStore (99 combined, 15 Extra, F16) with no visible limit labels: Add simply
## becomes unavailable. Presentation only: persists through DeckStore.
##
## Layout: catalogue (shared CardBrowser) | details of the shown card | the deck (name + inline
## errors, actions, Saved / Structure folder tabs over the deck tiles, Main/Extra grids in
## canonical catalogue order, F17).
##
## The middle pane shows the card last hovered or selected (2026-10-20, F2): it follows the pointer
## over catalogue cards and deck tiles, stays on the last one when the pointer leaves (so its text
## can be scrolled and read) and jumps to a card chosen by click or arrow keys. + / - / Enter edit
## the card shown there.
##
## Input (no drag and drop): left-click a catalogue card to add a copy, or a deck card to remove
## one; right-click inspects. Keyboard: arrows move the catalogue selection, Enter or + adds, -
## removes, Esc = Back (F21) unless an inspector or a confirmation is open. Edits update `counts` at once; the fly / pop animation and sound (F24)
## are presentation on top and never gate input.

signal closed

## Gap between the status toast and the bottom edge of the page (design review #83: 24 px).
const TOAST_GAP := 24
## Summary chip height and its number size (design review #81).
const CHIP_H := 28.0
const CHIP_VALUE_FONT := 15
## Deck grid tile: "mini" card 90x135 with its count tag just below it (F18).
const TILE_W := 100
const TILE_H := 168
const MINI_W := 90.0
## Count tag (x1..x99) size: fixed so a changing count never shifts anything (F16).
const TAG_W := 48
const TAG_H := 22
## Footer room under each catalogue card (for its count tag).
const CELL_FOOTER := 24
## Tallest the saved/starter deck list grows before it scrolls.
const LIST_MAX_H := 190.0
## Fly animation (F24): seconds, and how many ghost cards may be in flight at once.
const FLY_TIME := 0.34
const MAX_GHOSTS := 6

## card id -> copies in the working deck
var counts: Dictionary = {}
var deck_name_edit: LineEdit
var dirty: bool = false
## The shared catalogue browser (filters + grid).
var browser: CardBrowser
## The page header (title, divider, Back).
var header: PageHeader

var _loaded_name: String = ""
var _deck_box: VBoxContainer
var _deck_scroll: SmoothScroll
var _deck_chips: HFlowContainer
var _chip_vals: Dictionary = {}
var _unsaved_chip: Control
var _empty_note: Control
## "main" / "extra" -> {box, flow, value}
var _sections: Dictionary = {}
## card id -> its deck grid tile (reused between refreshes so hover and scroll survive a click).
var _deck_tiles: Dictionary = {}
var _cat_index: Dictionary = {}
var _main_n := 0
var _extra_n := 0
var _preview_holder: VBoxContainer
var _preview_card: CardWidget
var _details: CardDetailsPanel
var _facts: PreviewFacts
var _preview_note: Label
var _save_btn: Button
var _rename_btn: Button
var _delete_btn: Button
var _name_err: Label
var _name_box: VBoxContainer
var _name_shake: Tween
var _list_box: VBoxContainer
var _list_scroll: ScrollContainer
var _deck_tabs: FolderTabs
var _show_starters: bool = false
var _status: Label
var _status_panel: PanelContainer
var _status_tw: Tween
var _starters: Array = []
var _summaries: Dictionary = {}
var _preview_id: int = -1
## The card a hover is about to show (debounced so sweeping the pointer does not rebuild the pane).
var _hover_want: int = -1
var _overlay: ConfirmDialog
var _fx_layer: Control
var _ghosts: Array = []
var _deck_scroll_tw: Tween
var _leaving := false


func _ready() -> void:
	CardDB.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cat_index = CardBrowser.catalogue_index()
	_starters = Series.load_starters()
	_build()
	_refresh_saved()
	_refresh_deck()
	var ids := browser.visible_ids()
	if not ids.is_empty():
		_select(int(ids[0]))


# ------------------------------------------------------------ pure logic (testable)

## True if card def `d` passes the filters (see CardBrowser.matches).
static func matches(d: Dictionary, query: String, category: String, type: String, race: String, cost: String) -> bool:
	return CardBrowser.matches(d, query, category, type, race, cost)


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


## Deck card ids in canonical catalogue order (F17): CardDB order, matched by stable id, never
## by display name or insertion order. Unknown ids sort last by id.
static func catalogue_sorted(ids: Array, index_of: Dictionary) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a, b):
		var ia: int = index_of.get(int(a), 1 << 30)
		var ib: int = index_of.get(int(b), 1 << 30)
		if ia != ib:
			return ia < ib
		return int(a) < int(b))
	return out


## The up-to-`n` most common non-empty Types in a deck id list, most frequent first.
static func dominant_types(cards: Array, n: int = 3) -> Array:
	var tally := {}
	for id in cards:
		if not CardDB.has(int(id)):
			continue
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

## Why one more copy of `id` cannot be added right now ("" when it can).
func add_block_reason(id: int) -> String:
	return DeckStore.add_block_reason(_main_n, _extra_n, id)


## Adds up to `n` copies of card `id`, stopping at the deck caps. Returns the copies added.
func add_card(id: int, n: int = 1) -> int:
	var added := 0
	for i in n:
		if add_block_reason(id) != "":
			break
		counts[id] = int(counts.get(id, 0)) + 1
		if DeckStore.is_extra(id):
			_extra_n += 1
		else:
			_main_n += 1
		added += 1
	if added > 0:
		dirty = true
		_refresh_deck()
		_update_cell(id)
	return added


## Removes one copy of card `id` (no-op when absent; never goes below zero).
func remove_card(id: int) -> bool:
	if int(counts.get(id, 0)) <= 0:
		return false
	counts[id] = int(counts[id]) - 1
	if int(counts[id]) <= 0:
		counts.erase(id)
	dirty = true
	_recount()
	_refresh_deck()
	_update_cell(id)
	return true


## Sets the search text and refreshes the catalogue.
func set_filters(query: String) -> void:
	browser.set_query(query)


## Starts an empty, unnamed deck.
func new_deck() -> void:
	counts = {}
	deck_name_edit.text = ""
	_loaded_name = ""
	dirty = false
	_clear_name_error()
	_say("Started a new empty deck.")
	_after_replace()


## Replaces the working deck with `cards` under `name` (not dirty). Never trims: a deck saved
## before the caps opens intact and can only shrink until it is legal again.
func load_cards(name: String, cards: Array) -> void:
	counts = {}
	for id in cards:
		if CardDB.has(int(id)):
			counts[int(id)] = int(counts.get(int(id), 0)) + 1
	deck_name_edit.text = name
	_loaded_name = name
	dirty = false
	_clear_name_error()
	_after_replace()


## Saves the working deck under its name; false (with an inline message by the name field) when
## unnamed or over the deck caps.
func save() -> bool:
	var n := deck_name_edit.text.strip_edges()
	if n == "":
		_say("Give the deck a name before saving.", true)
		return false
	var cards := counts_to_cards(counts)
	var err := DeckStore.validate(cards)
	if err != "":
		_say(err, true)
		return false
	DeckStore.save_deck(n, cards)
	dirty = false
	_loaded_name = n
	_clear_name_error()
	_refresh_saved()
	_refresh_deck()
	_say("Saved \"%s\" (%d cards). Pick it under \"Your saved decks\" when you set up a series." % [n, cards.size()])
	return true


## Renames the loaded saved deck to the text in the name field, keeping the working cards.
## False (with a message) when no saved deck is loaded, the name is empty/unchanged or taken.
func rename_loaded() -> bool:
	var n := deck_name_edit.text.strip_edges()
	if not has_saved_deck_loaded():
		_say("Load a saved deck first, then type a new name and press Rename.", true)
		return false
	if n == "" or n == _loaded_name:
		_say("Type a different name to rename \"%s\"." % _loaded_name, true)
		return false
	if _saved_exists(n):
		_say("A saved deck named \"%s\" already exists." % n, true)
		return false
	var err := DeckStore.validate(counts_to_cards(counts))
	if err != "":
		_say(err, true)
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


## True when the editor holds a deck that exists in the saved list (F23: Delete / Rename show).
func has_saved_deck_loaded() -> bool:
	return _loaded_name != "" and _saved_exists(_loaded_name)


func _saved_exists(n: String) -> bool:
	for dk in DeckStore.list():
		if dk["name"] == n:
			return true
	return false


## The catalogue card widget of card `id` (null when absent): emit its `pressed` / `right_pressed`.
func cell_widget(id: int) -> CardWidget:
	return browser.cell_widget(id)


## The deck-grid card widget of card `id` (null when it is not in the deck).
func deck_widget(id: int) -> CardWidget:
	return (_deck_tiles[id].get_meta("rec") as Dictionary)["widget"] if _deck_tiles.has(id) and counts.has(id) else null


## The count tag text under catalogue card `id` ("" when not in the deck).
func cell_count_text(id: int) -> String:
	var tag := _cell_tag(id)
	return (tag.get_node("Text") as Label).text if tag != null and tag.visible else ""


## The count tag under deck tile `id` (null when absent).
func deck_tag(id: int) -> Control:
	return (_deck_tiles[id].get_meta("rec") as Dictionary)["tag"] if _deck_tiles.has(id) else null


## Number of catalogue cells currently shown (passing the filters).
func visible_cell_count() -> int:
	return browser.visible_count()


## The selected (previewed) card id, -1 when none.
func preview_id() -> int:
	return _preview_id


## True when one more copy of the shown card can be added right now (false: deck full, or none shown).
func can_add_shown() -> bool:
	return _preview_id >= 0 and add_block_reason(_preview_id) == ""


## The Saved / Structure folder tabs.
func deck_tabs() -> FolderTabs:
	return _deck_tabs


func delete_button() -> Button:
	return _delete_btn


## Ghost cards currently flying (F24 presentation; dev/test helper).
func ghost_count() -> int:
	_ghosts = _ghosts.filter(func(g): return is_instance_valid(g))
	return _ghosts.size()


## The text of the inline error beside the name field ("" when none is shown).
func name_error() -> String:
	return _name_err.text if _name_err.visible else ""


## The saved-deck tile for deck `n` (null when absent): click it to load.
func saved_row(n: String) -> Control:
	for r in _list_box.get_children():
		if r.has_meta("deck_name") and r.get_meta("deck_name") == n:
			return r
	return null


## Opens the shared card inspector for card `id`; the working deck is untouched.
func inspect_card(id: int) -> CardInspector:
	# #87: the card flies out of its catalogue cell when that cell is on screen.
	var w := browser.cell_widget(id)
	var from := w.get_global_rect() if w != null and w.is_visible_in_tree() else Rect2()
	return CardInspector.open(self, MatchView.summary_view(_summary(id)), Callable(), from)


## Shows card `id` big in the preview column (deck-construction stats, F19) and selects it.
func show_preview(id: int) -> void:
	_select(id)


## The pointer is over card `id` (catalogue cell or deck tile): the details pane shows it, and + / -
## act on it. Nothing happens when the pointer leaves: the pane keeps the last card, so its text can
## be read and scrolled. Does not touch the catalogue selection.
func hover_card(id: int) -> void:
	_hover_want = id
	_show(id)


## Add (Enter / +, or a catalogue click) the shown card: adds one copy with sound and the fly
## animation (F24), flying from `from` (default: the preview card). Unavailable (deck full) gives
## the deny sound and a small shake instead.
func ui_add(from: Rect2 = Rect2()) -> bool:
	if _preview_id < 0:
		return false
	if add_block_reason(_preview_id) != "":
		Sfx.play("deny")
		_shake(_facts.gems())
		_say(add_block_reason(_preview_id))
		return false
	if from.size == Vector2.ZERO and _preview_card != null:
		from = _preview_card.get_global_rect()
	add_card(_preview_id)
	Sfx.play("deck_add", 0.0, 0.04)   # F24 / F25: replaces the Add button's own click
	_pop(_facts.gems(), UIStyle.GOOD)
	_pop(_cell_tag(_preview_id), UIStyle.GOOD)
	_queue_fly(_preview_id, from, true)
	return true


## Remove (- or a deck-card click) one copy of the shown card: removes one copy with sound and the return animation (F24).
func ui_remove() -> bool:
	if _preview_id < 0 or int(counts.get(_preview_id, 0)) <= 0:
		Sfx.play("deny")
		return false
	var id := _preview_id
	var tile: Control = _deck_tiles.get(id)
	var from := Rect2()
	if tile != null and _tile_on_screen(tile):
		from = ((tile.get_meta("rec") as Dictionary)["widget"] as Control).get_global_rect()
	remove_card(id)
	Sfx.play("deck_remove", 0.0, 0.04)
	_pop(_facts.gems(), UIStyle.BAD)
	if counts.has(id):
		_pop(deck_tag(id), UIStyle.BAD)
		_pop(_cell_tag(id), UIStyle.BAD)
	if from.size != Vector2.ZERO and _preview_card != null:
		_fly(id, from, _preview_card.get_global_rect(), false)
	return true


# ------------------------------------------------------------ small widgets

## Round-cornered icon button drawn from vectors (no font glyph needed): cross, pencil.
class IconBtn extends JuicyButton:
	var glyph: String = "cross"
	var tint: Color = UIStyle.TEXT

	func _draw() -> void:
		super._draw()
		var c := size / 2.0
		var col := UIStyle.DISABLED if disabled else (UIStyle.GOLD_HI if is_hovered() else tint)
		var r := minf(size.x, size.y) * 0.24
		var w := maxf(1.8, minf(size.x, size.y) * 0.1)
		match glyph:
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


## A bronze-trimmed, softly shaded plate for one of the columns.
static func plate(color: Color = UIStyle.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.panel_style(color, UIStyle.BRONZE, 8)
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	UIStyle.pad(sb, "lg")   # sidebar-panel padding (design review 1.4.2)
	p.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN))
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


## Section heading (design review D3, T3): a SECTION-tier title (TitleText: gold, letter-spaced,
## a hard shadow) with its engraved double underline across the column. Returns a VBoxContainer
## holding the title Label (its "Title" child).
static func heading(text: String, size: int = 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var l := UIStyle.label(text.to_upper(), size, UIStyle.GOLD)
	l.name = "Title"
	v.add_child(l)
	TitleText.apply(l, TitleText.Tier.SECTION, size)
	return v


## Wood table background (dark wood grain, UiSurface) with a soft radial vignette (shared with the
## catalogue screen).
static func table_backdrop(host: Control) -> void:
	host.add_child(UiSurface.Fill.new(UIStyle.TABLE_WOOD, UiSurface.WOOD, UIStyle.BACKDROP_GRAIN, UIStyle.BACKDROP_TILE))
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
	host.add_child(vignette)


## Summary pill (design review #81): an F4 bronze chip, 28 px high, whose number stands out (15 px
## Cinzel 700 in GOLD_HI, in a fixed-width slot with room for 99, F16) before an 11 px MUTED caption.
## Returns the pill; the value Label is its first HBox child ("Value").
static func count_chip(caption: String, accent: Color = UIStyle.GOLD_HI) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIStyle.chip_style(UIStyle.BRONZE.lightened(0.15), 8))
	pc.custom_minimum_size.y = CHIP_H
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var a := UIStyle.label("0", CHIP_VALUE_FONT, accent)
	a.name = "Value"
	a.add_theme_font_override("font", UIStyle.font_display(700))
	a.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	a.add_theme_constant_override("shadow_offset_y", 1)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.custom_minimum_size.x = ceilf(UIStyle.font_display(700).get_string_size("99", HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_VALUE_FONT).x) + 2.0
	h.add_child(a)
	if caption != "":
		var cl := UIStyle.label(caption, 11, UIStyle.MUTED)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.add_theme_font_override("font", UIStyle.font_bold())
		h.add_child(cl)
	return pc


## Quantity tag ("x3") shown just below a card (F18), fixed width with room for x99 (F16). Design
## review #82: a passive count badge, not a button: a dark F4 gold chip with a gold Cinzel number.
static func count_tag() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIStyle.chip_style(UIStyle.GOLD, 10)
	sb.base.content_margin_left = 4
	sb.base.content_margin_right = 4
	sb.base.content_margin_top = 0
	sb.base.content_margin_bottom = 1
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, sb.base.get_content_margin(side))
	UIStyle.lift(sb.base, UIStyle.DEPTH_PLATE)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(TAG_W, TAG_H)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIStyle.label("", 14, UIStyle.GOLD_HI)
	l.add_theme_font_override("font", UIStyle.font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "Text"
	pc.add_child(l)
	return pc


## A fixed vertical gap of `h` px.
static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## Centres `c` horizontally in a full-rect row inside `host` (host keeps its own size).
static func _centre_in(host: Control, c: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(row)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)


## Round pencil/cross button of `px` square; `danger` tints the rim red.
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


## Compact empty state for the deck-list pane (no nested box, design review #54): a small engraved
## tome beside a SCREEN-tier title and the hint, laid directly on the pane.
static func _empty_state(title: String, hint: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "EmptyState"
	UIStyle.pad(row, "md")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := EngravedIcon.new("tome", 44.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UIStyle.sp("xs"))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	var t := UIStyle.label(title, 18, UIStyle.GOLD_HI)
	v.add_child(t)
	TitleText.apply(t, TitleText.Tier.SCREEN, 18)
	var h := UIStyle.label(hint, 14, UIStyle.MUTED, true)
	v.add_child(h)
	return row


# ------------------------------------------------------------ construction

func _build() -> void:
	table_backdrop(self)
	var margin := UIStyle.full_rect_margin(UIStyle.SAFE_PAGE)
	add_child(margin)
	var root := VBoxContainer.new()
	UIStyle.pad(root, "lg")
	margin.add_child(root)

	# Page header (design review #73): the same component as the card catalogue.
	header = PageHeader.new("Deck Builder")
	header.back_pressed.connect(_on_back)
	root.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyle.pad(body, "lg")
	root.add_child(body)
	_build_catalogue(body)
	_build_preview(body)
	_build_deck(body)

	# Status toast: floats over the bottom edge so a message never pushes the columns around.
	_status_panel = PanelContainer.new()
	var ssb := UIStyle.flat(Color(0.075, 0.062, 0.048, 0.97), Color(UIStyle.GOLD, 0.6), 1, 6)
	UIStyle.pad(ssb, "lg", "sm")
	UIStyle.lift(ssb, UIStyle.DEPTH_FLOATING)
	_status_panel.add_theme_stylebox_override("panel", UiSurface.box(ssb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN * 0.3))
	_status_panel.visible = false
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.anchor_left = 0.5
	_status_panel.anchor_right = 0.5
	_status_panel.anchor_top = 1.0
	_status_panel.anchor_bottom = 1.0
	_status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_panel.offset_bottom = -UIStyle.SAFE_PAGE - TOAST_GAP
	_status_panel.offset_top = -UIStyle.SAFE_PAGE - TOAST_GAP
	_status_panel.z_index = 4
	_status = UIStyle.label("", 14, UIStyle.TEXT)
	_status_panel.add_child(_status)
	add_child(_status_panel)

	# Ghost cards fly on this layer; it never takes input.
	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 5
	add_child(_fx_layer)


func _build_catalogue(body: HBoxContainer) -> void:
	var p := plate()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 3.0
	body.add_child(p)
	var v := VBoxContainer.new()
	UIStyle.pad(v, "md")
	p.add_child(v)
	v.add_child(heading("Card catalogue"))
	browser = CardBrowser.new(false, CELL_FOOTER)
	browser.card_selected.connect(func(id): _select(id, false))
	browser.card_inspected.connect(func(id): inspect_card(id))
	browser.card_activated.connect(func(_id): ui_add())
	browser.click_sound = false
	browser.card_clicked.connect(_on_catalogue_clicked)
	browser.card_hovered.connect(_on_hover)
	v.add_child(browser)
	browser.build()
	for d in CardDB.all():
		var id := int(d["id"])
		var tag := count_tag()
		tag.visible = false
		_centre_in(browser.footer(id), tag)
		browser.cell(id).set_meta("tag", tag)


func _build_preview(body: HBoxContainer) -> void:
	var p := plate(UIStyle.PANEL_INK)
	p.custom_minimum_size = Vector2(320, 0)
	body.add_child(p)
	var v := VBoxContainer.new()
	UIStyle.pad(v, "md")
	p.add_child(v)
	v.add_child(heading("Card details"))
	_preview_holder = VBoxContainer.new()
	_preview_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_preview_holder)
	var sc := ScrollArea.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var inner := VBoxContainer.new()
	UIStyle.pad(inner, "md")
	sc.set_content(inner)
	_details = CardDetailsPanel.new()
	_details.construction = true
	_details.slim_stats = true   # H24: short ATK / DEF tiles, same text size
	inner.add_child(_details)
	# Always-shown facts (design review #80): the Rules placeholder of a vanilla card, the copies
	# in this deck as gem sockets that fill on add, the kind and cost line.
	_facts = PreviewFacts.new(true)
	inner.add_child(_facts)
	# H26 (21 Oct): the "In your deck: xN" tag under the card image is gone; the gems say it, and
	# carry the pane's help.
	_facts.gems().tooltip_text = "Copies of this card in the deck.\nThe pane shows the card under the pointer, or the last one you picked.\nClick a catalogue card to add a copy, a deck card to remove one.\nKeys: + or Enter adds, - removes. Right-click inspects."
	_preview_note = UIStyle.label("", 13, UIStyle.BAD)
	inner.add_child(_preview_note)


func _build_deck(body: HBoxContainer) -> void:
	var p := plate()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 2.2
	body.add_child(p)
	var v := VBoxContainer.new()
	UIStyle.pad(v, "md")
	p.add_child(v)
	v.add_child(heading("Your deck"))

	# Name field with its inline error line right under it (F04-20).
	_name_box = VBoxContainer.new()
	_name_box.add_theme_constant_override("separation", 3)
	v.add_child(_name_box)
	deck_name_edit = LineEdit.new()
	deck_name_edit.placeholder_text = "Deck name"
	deck_name_edit.max_length = 40
	CardBrowser.style_edit(deck_name_edit)
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
	UIStyle.pad(actions, "md", "sm")
	v.add_child(actions)
	_save_btn = UIStyle.primary_button("Save", 15)
	_save_btn.custom_minimum_size = Vector2(96, UIStyle.BUTTON_H["small"])
	_save_btn.pressed.connect(_on_save_pressed)
	actions.add_child(_save_btn)
	var new_b := UIStyle.button("New", 15)
	new_b.custom_minimum_size = Vector2(84, UIStyle.BUTTON_H["small"])
	new_b.tooltip_text = "Start a new empty deck"
	new_b.pressed.connect(func(): _guard_unsaved(new_deck))
	actions.add_child(new_b)
	_rename_btn = UIStyle.button("Rename", 15)
	_rename_btn.custom_minimum_size = Vector2(96, UIStyle.BUTTON_H["small"])
	_rename_btn.tooltip_text = "Rename the loaded saved deck to the name typed above"
	_rename_btn.pressed.connect(rename_loaded)
	actions.add_child(_rename_btn)
	_delete_btn = UIStyle.button("Delete", 15)
	_delete_btn.custom_minimum_size = Vector2(96, UIStyle.BUTTON_H["small"])
	_delete_btn.tooltip_text = "Delete the loaded saved deck"
	_delete_btn.pressed.connect(func(): _ask_delete())
	actions.add_child(_delete_btn)

	# Saved / Structure decks (F04-17, F20, F3): folder tabs joined to the pane that holds the tiles,
	# 24 px under the buttons (design review #84: field > 12 > buttons > 24 > tabs > 0 > list).
	v.add_child(_gap(UIStyle.sp("xl") - UIStyle.sp("md")))
	_deck_tabs = FolderTabs.new()
	_deck_tabs.tab_height = 38.0
	_deck_tabs.font_size = 15
	_deck_tabs.left_margin = 16.0
	_deck_tabs.set_pane_margins(UIStyle.sp("sm"), UIStyle.sp("md"), UIStyle.sp("md"), UIStyle.sp("md"))
	_deck_tabs.add_tab("saved", "Saved Decks", {"min_width": 130.0})
	_deck_tabs.add_tab("starters", "Structure Decks", {"min_width": 150.0})
	_deck_tabs.tab_selected.connect(func(key: String):
		_show_starters = key == "starters"
		_refresh_saved())
	v.add_child(_deck_tabs)
	var list_sc := SmoothScroll.new()
	_list_scroll = list_sc
	_deck_tabs.pane.add_child(list_sc)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 5)
	list_sc.add_child(_list_box)
	_list_box.minimum_size_changed.connect(_fit_list)

	# List > 24 > stats (design review #84).
	v.add_child(_gap(UIStyle.sp("xl") - UIStyle.sp("md")))
	# Summary pills: built once, values in fixed-width slots so nothing shifts (F16).
	_deck_chips = HFlowContainer.new()
	UIStyle.pad(_deck_chips, "sm")
	v.add_child(_deck_chips)
	for k in [["total", "cards"], ["main", "Main"], ["extra", "Extra"], ["unique", "unique"]]:
		var chip := count_chip(k[1])
		_chip_vals[k[0]] = chip.get_node("HBoxContainer/Value") if chip.has_node("HBoxContainer/Value") else chip.get_child(0).get_child(0)
		_deck_chips.add_child(chip)
	var uc := UIStyle.chip("Unsaved", UIStyle.TARGET, 13)
	uc.custom_minimum_size.y = CHIP_H
	_unsaved_chip = uc
	_deck_chips.add_child(uc)
	# Illustrated empty state (WP-7): an engraved deck emblem on the leather, no box.
	var en := CenterContainer.new()
	en.size_flags_vertical = Control.SIZE_EXPAND_FILL
	en.add_child(EngravedIcon.empty_state("deck", "Your deck is empty", "Hover a card to read it, click it to add a copy. Fusion, Ritual and Arcane cards go to the Extra Deck.", "", Callable(), 340.0))
	_empty_note = en
	v.add_child(_empty_note)
	_deck_scroll = SmoothScroll.new()
	_deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_scroll.size_flags_stretch_ratio = 1.6
	v.add_child(_deck_scroll)
	_deck_box = VBoxContainer.new()
	_deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.pad(_deck_box, "lg")
	_deck_scroll.add_child(_deck_box)
	for key in ["main", "extra"]:
		var box := VBoxContainer.new()
		UIStyle.pad(box, "sm")
		_deck_box.add_child(box)
		var h := HBoxContainer.new()
		UIStyle.pad(h, "md")
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# SECTION tier (D3): MAIN DECK / EXTRA DECK with the engraved underline across the row.
		var t := UIStyle.label("MAIN DECK" if key == "main" else "EXTRA DECK", 15, UIStyle.GOLD)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(t)
		TitleText.apply(t, TitleText.Tier.SECTION, 15)
		var chip := count_chip("cards")
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(chip)
		box.add_child(h)
		var flow := HFlowContainer.new()
		UIStyle.pad(flow, "xs")
		box.add_child(flow)
		_sections[key] = {"box": box, "flow": flow, "value": chip.get_child(0).get_child(0)}


# ------------------------------------------------------------ refresh

func _summary(id: int) -> Dictionary:
	if not _summaries.has(id):
		_summaries[id] = Series.card_summary(id)
	return _summaries[id]


func _recount() -> void:
	var sc := DeckStore.split_counts(counts_to_cards(counts))
	_main_n = sc["main"]
	_extra_n = sc["extra"]


## After the whole deck was replaced (new / load / copy).
func _after_replace() -> void:
	_recount()
	_refresh_saved()
	_refresh_deck()
	for id in browser._cells:
		_update_cell(id)


func _select(id: int, sync_browser: bool = true) -> void:
	if not CardDB.has(id):
		return
	if sync_browser and browser.selected_id != id:
		browser.select(id, false)
	_hover_want = id
	_show(id)


## Shows card `id` in the details pane (rebuilt only when it is a different card than the one shown).
func _show(id: int) -> void:
	if not CardDB.has(id):
		return
	var changed := id != _preview_id
	_preview_id = id
	if changed:
		for c in _preview_holder.get_children():
			_preview_holder.remove_child(c)
			c.queue_free()
		var s := _summary(id)
		_preview_card = CardWidget.new().setup(MatchView.summary_view(s), "big")
		_preview_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_preview_card.show_tooltip = false
		_preview_card.tooltip_text = ""
		_preview_card.right_pressed.connect(func(_w): inspect_card(id))
		_preview_holder.add_child(_preview_card)
		_details.show_card(MatchView.summary_view(s))
		_preview_note.visible = s["support"] != "full"
		_preview_note.text = "Implementation: %s" % s["support"]
	_mark_deck_selection()
	_update_facts()


## Updates the preview's facts block (rules placeholder, copies in the deck, kind line).
func _update_facts() -> void:
	if _facts != null and _preview_id >= 0:
		_facts.show_card(_preview_id, _details.sections.has("rules"), int(counts.get(_preview_id, 0)))


## Pointer entered a card: show it once the pointer has rested a moment (a sweep over many cards
## builds the pane once, not for each).
func _on_hover(id: int) -> void:
	_hover_want = id
	if not is_inside_tree():
		hover_card(id)
		return
	await get_tree().create_timer(0.05).timeout
	if _hover_want == id and is_inside_tree():
		_show(id)


func _mark_deck_selection() -> void:
	for tid in _deck_tiles:
		var w: CardWidget = (_deck_tiles[tid].get_meta("rec") as Dictionary)["widget"]
		w.set_marks(false, int(tid) == _preview_id)


func _cell_tag(id: int) -> Control:
	var c := browser.cell(id) if browser != null else null
	return c.get_meta("tag") if c != null and c.has_meta("tag") else null


func _update_cell(id: int) -> void:
	var tag := _cell_tag(id)
	if tag == null:
		return
	var n := int(counts.get(id, 0))
	(tag.get_node("Text") as Label).text = "x%d" % n
	tag.visible = n > 0
	browser.set_marked(id, n > 0)


## One deck-grid tile (built once per card id): mini card with its count tag just below (F18).
func _make_tile(id: int) -> Control:
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
	tile.set_meta("card_id", id)
	var w := CardWidget.new().setup(MatchView.summary_view(_summary(id)), "mini")
	w.position = Vector2(5, 4)
	w.show_tooltip = false
	w.tooltip_text = "%s\nClick to remove a copy, right-click to inspect" % String(_summary(id)["name"])
	w.mouse_entered.connect(func(): _on_hover(id))
	w.hover_sound = true
	w.pressed.connect(func(_w): _on_tile_clicked(id))
	w.right_pressed.connect(func(_w): inspect_card(id))
	tile.add_child(w)
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(0, 4 + 135 + 4)
	slot.size = Vector2(TILE_W, TAG_H)
	tile.add_child(slot)
	var tag := count_tag()
	_centre_in(slot, tag)
	var rec := {"widget": w, "tag": tag}
	_deck_tiles[id] = tile
	tile.set_meta("rec", rec)
	return tile


## Deck-tile click: selects the card and removes one copy (the remove sound replaces the select).
func _on_tile_clicked(id: int) -> void:
	_select(id)
	browser.reveal(id)
	ui_remove()


## Catalogue click: the browser has already selected it; add one copy flying from the clicked card.
func _on_catalogue_clicked(id: int) -> void:
	var w := browser.cell_widget(id)
	ui_add(w.get_global_rect() if w != null and w.is_inside_tree() else Rect2())


## Syncs the persistent Main / Extra sections with `counts`: tiles are reused and only
## reordered (canonical catalogue order, F17), so hover, focus and scroll survive every edit.
func _refresh_deck() -> void:
	for id in _deck_tiles.keys():
		if not counts.has(id):
			var gone: Control = _deck_tiles[id]
			_deck_tiles.erase(id)
			if gone.get_parent() != null:
				gone.get_parent().remove_child(gone)
			gone.queue_free()
	var groups := {"main": [], "extra": []}
	var totals := {"main": 0, "extra": 0}
	for id in counts.keys():
		var key := "extra" if DeckStore.is_extra(int(id)) else "main"
		groups[key].append(int(id))
		totals[key] += int(counts[id])
	for key in ["main", "extra"]:
		var sec: Dictionary = _sections[key]
		var flow: HFlowContainer = sec["flow"]
		var ids := catalogue_sorted(groups[key], _cat_index)
		for i in ids.size():
			var id: int = ids[i]
			var tile: Control = _deck_tiles[id] if _deck_tiles.has(id) else _make_tile(id)
			if tile.get_parent() != flow:
				if tile.get_parent() != null:
					tile.get_parent().remove_child(tile)
				flow.add_child(tile)
			if tile.get_index() != i:
				flow.move_child(tile, i)
			((tile.get_meta("rec") as Dictionary)["tag"].get_node("Text") as Label).text = "x%d" % int(counts[id])
		(sec["value"] as Label).text = str(totals[key])
		(sec["box"] as Control).visible = not ids.is_empty()
	var total: int = totals["main"] + totals["extra"]
	_set_chip("total", total)
	_set_chip("main", totals["main"])
	_set_chip("extra", totals["extra"])
	_set_chip("unique", counts.size())
	_unsaved_chip.modulate.a = 1.0 if dirty else 0.0
	_empty_note.visible = total == 0
	_deck_scroll.visible = total > 0
	_mark_deck_selection()
	_update_facts()
	_update_actions()


## F23: Delete (and Rename) only while an actual saved deck is loaded.
func _update_actions() -> void:
	if _delete_btn == null:
		return
	var has := has_saved_deck_loaded()
	_delete_btn.visible = has
	_rename_btn.visible = has


## Rebuilds the saved-deck (or starter) tile list for the active tab.
func _refresh_saved() -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	var decks := DeckStore.list()
	_deck_tabs.select("starters" if _show_starters else "saved", false)
	if _show_starters:
		for s in _starters:
			_list_box.add_child(_deck_tile(String(s["name"]), s["main"] + s["extra"], false, true))
	elif decks.is_empty():
		_list_box.add_child(_empty_state("No saved decks yet", "Name your deck and press Save, or copy a Structure deck."))
	else:
		for dk in decks:
			_list_box.add_child(_deck_tile(String(dk["name"]), dk["cards"], String(dk["name"]) == _loaded_name, false))
	_fit_list()
	_update_actions()


## Fits the saved/starter list to its content (tiles + gaps), scrolling only beyond LIST_MAX_H.
## Re-run whenever the content's minimum size settles (wrapped text measures tall until it has
## its real width).
func _fit_list() -> void:
	_list_scroll.custom_minimum_size.y = clampf(_list_box.get_combined_minimum_size().y + 4.0, 40.0, LIST_MAX_H)


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
		UIStyle.pad(sb, "md")   # D5: list-row padding, 12 px on every side (6-8 px before)
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


# ------------------------------------------------------------ edit feedback (F24)

## Scale pop with a colour flash on `c` (a count tag or chip). Static under reduced motion.
func _pop(c: Control, flash: Color) -> void:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree() or UIStyle.reduce_motion:
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	c.scale = Vector2(1.28, 1.28)
	c.modulate = flash.lightened(0.35)
	tw.tween_property(c, "scale", Vector2.ONE, UIStyle.dur(0.26)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate", Color.WHITE, UIStyle.dur(0.3))


## Sets summary chip `key` to `n`; a changed count pops its chip (#85: the deck's counts react to an
## edit, not only the card's own tag). The first fill of an empty builder stays still.
func _set_chip(key: String, n: int) -> void:
	var l := _chip_vals[key] as Label
	var was := l.text
	l.text = str(n)
	if was != "" and was != l.text:
		var chip: Node = l
		while chip.get_parent() != null and chip.get_parent() != _deck_chips:
			chip = chip.get_parent()
		_pop(chip as Control, UIStyle.GOLD_HI)


func _shake(c: Control) -> void:
	if c == null or UIStyle.reduce_motion or not c.is_inside_tree():
		return
	var x0 := c.position.x
	var tw := c.create_tween()
	for dx in [-5.0, 5.0, -3.0, 3.0, 0.0]:
		tw.tween_property(c, "position:x", x0 + dx, 0.035)
	tw.finished.connect(func(): if is_instance_valid(c) and c.get_parent() is Container: (c.get_parent() as Container).queue_sort())


func _tile_on_screen(tile: Control) -> bool:
	return tile.is_visible_in_tree() and _deck_scroll.get_global_rect().intersects(tile.get_global_rect())


## Waits one frame (the new / moved tile gets its layout), then flies a ghost from `from`.
func _queue_fly(id: int, from: Rect2, adding: bool) -> void:
	if UIStyle.reduce_motion or from.size == Vector2.ZERO or not is_inside_tree():
		_reveal_tile(id)
		return
	get_tree().process_frame.connect(_fly_to_tile.bind(id, from, adding), CONNECT_ONE_SHOT)


func _fly_to_tile(id: int, from: Rect2, adding: bool) -> void:
	if not is_inside_tree() or not _deck_tiles.has(id):
		return
	var tile: Control = _deck_tiles[id]
	var shift := _reveal_tile(id)
	var w: Control = (tile.get_meta("rec") as Dictionary)["widget"]
	var to := w.get_global_rect()
	to.position.y -= shift
	var clip := _deck_scroll.get_global_rect()
	to.position.y = clampf(to.position.y, clip.position.y - to.size.y * 0.5, clip.end.y - to.size.y * 0.5)
	_fly(id, from, to, adding)


## Glides the deck list so tile `id` is in view; returns how far the view will move (px).
func _reveal_tile(id: int) -> float:
	if not _deck_tiles.has(id):
		return 0.0
	var tile: Control = _deck_tiles[id]
	var top := tile.get_global_rect().position.y - _deck_box.get_global_rect().position.y
	var bottom := top + tile.size.y
	var cur := float(_deck_scroll.scroll_vertical)
	var view_h := _deck_scroll.size.y
	var target := cur
	if top < cur:
		target = top
	elif bottom > cur + view_h:
		target = bottom - view_h
	target = clampf(target, 0.0, maxf(0.0, _deck_box.size.y - view_h))
	if is_equal_approx(target, cur):
		return 0.0
	if _deck_scroll_tw != null and _deck_scroll_tw.is_valid():
		_deck_scroll_tw.kill()
	if UIStyle.reduce_motion or not is_inside_tree():
		_deck_scroll.scroll_vertical = int(target)
	else:
		_deck_scroll_tw = create_tween()
		_deck_scroll_tw.tween_property(_deck_scroll, "scroll_vertical", int(target), UIStyle.dur(0.24)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return target - cur


## A non-interactive mini card flying from `from` to `to` (global rects). Adding lands with a
## tag pop on the tile; removing shrinks and fades into the preview card.
func _fly(id: int, from: Rect2, to: Rect2, adding: bool) -> void:
	if UIStyle.reduce_motion or not is_inside_tree():
		return
	ghost_count()
	while _ghosts.size() >= MAX_GHOSTS:
		var old: Control = _ghosts.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var g := CardWidget.new().setup(MatchView.summary_view(_summary(id)), "mini")
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_tooltip = false
	g.auto_hover = false
	_fx_layer.add_child(g)
	_ghosts.append(g)
	var origin := _fx_layer.get_global_rect().position
	g.pivot_offset = Vector2.ZERO
	g.position = from.position - origin
	g.scale = Vector2.ONE * (from.size.x / MINI_W)
	g.modulate = Color(1, 1, 1, 0.95)
	var end_scale := Vector2.ONE * (to.size.x / MINI_W) * (1.0 if adding else 0.55)
	var end_pos := to.position - origin
	if not adding:
		end_pos += to.size * 0.225
	var t := UIStyle.dur(FLY_TIME)
	var tw := g.create_tween()
	tw.set_parallel(true)
	tw.tween_property(g, "position", end_pos, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(g, "scale", end_scale, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(g, "rotation", deg_to_rad(-6.0 if adding else 6.0), t * 0.5).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(g, "modulate:a", 0.0, UIStyle.dur(0.1))
	tw.finished.connect(func():
		if adding:
			_pop(deck_tag(id), UIStyle.GOOD)
			_pulse_tile(id)
		g.queue_free())


func _pulse_tile(id: int) -> void:
	var w := deck_widget(id)
	if w == null or UIStyle.reduce_motion:
		return
	w.pivot_offset = w.size / 2.0
	w.scale = Vector2(1.08, 1.08)
	w.fx_glow = Color(UIStyle.GOLD_HI, 0.8)
	var tw := w.create_tween()
	tw.set_parallel(true)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "fx_glow", Color(UIStyle.GOLD_HI, 0.0), UIStyle.dur(0.4))


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
	CardBrowser.style_edit(deck_name_edit, true)
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
	CardBrowser.style_edit(deck_name_edit, false)


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


## Structure (starter) decks are read-only: picking one copies it into the editor as a new unsaved deck.
func _copy_starter_cards(starter_name: String, cards: Array) -> void:
	load_cards(starter_name + " (copy)", cards)
	dirty = true
	_loaded_name = ""
	_refresh_saved()
	_refresh_deck()
	_say("Copied Structure deck \"%s\". Save to keep your edits." % starter_name)


## Runs `proceed` immediately, or after confirmation if there are unsaved edits.
func _guard_unsaved(proceed: Callable) -> void:
	if dirty and not counts.is_empty():
		_confirm("Unsaved changes", "You have unsaved changes to this deck. Discard them?", "Discard", proceed)
	else:
		proceed.call()


## Back button and Esc (F21): one flow, including the unsaved-changes question; emits `closed`
## at most once.
func _on_back() -> void:
	if _leaving:
		return
	Sfx.play("back")   # F22: Back button and Esc alike; one sound (coalesced with the button's)
	_guard_unsaved(func():
		if _leaving:
			return
		_leaving = true
		closed.emit())


## Esc: an open inspector closes itself first (it handles the key); an open confirmation is
## cancelled; otherwise Esc is the Back button. + / - / Enter edit the selected card.
func _input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or not is_visible_in_tree():
		return
	if ke.keycode == KEY_ESCAPE:
		if ke.echo or CardInspector.open_count() > 0:
			return   # the inspector's own Esc handler closes it; nothing else happens
		get_viewport().set_input_as_handled()
		if _overlay != null and is_instance_valid(_overlay) and not _overlay.is_queued_for_deletion():
			_overlay.close()
			return
		_on_back()


func _unhandled_key_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or CardInspector.open_count() > 0 or _modal_open():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match ke.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			ui_add()
		KEY_MINUS, KEY_KP_SUBTRACT:
			ui_remove()
		_:
			return
	get_viewport().set_input_as_handled()


func _modal_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay) and not _overlay.is_queued_for_deletion()


## Deletes saved deck `which` (default: the loaded saved deck) after confirmation.
func _ask_delete(which: String = "") -> void:
	var n := which if which != "" else _loaded_name
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


## Asks `text` in the shared ConfirmDialog; `on_yes` runs when `yes_text` is pressed. Every
## question asked here (replace, discard, delete) loses work if confirmed, so the confirm is the
## danger family and Cancel holds the focus (design review #70).
func _confirm(title: String, text: String, yes_text: String, on_yes: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = ConfirmDialog.open(self, title, text, yes_text, on_yes, "Cancel", "Deck builder", "danger")
