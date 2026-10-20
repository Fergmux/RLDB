class_name CardBrowser
extends VBoxContainer
## Shared card browsing component (F14, used by the Card catalogue screen and the deck builder):
## a search field and filter row over a responsive, smoothly scrolling grid of 2:3 cards.
## Browsing only: it never edits a deck. Owners listen to its signals and decorate cells through
## `footer(id)` / `set_marked(id, on)` (the deck builder puts its count tags there).
##
## Input (no drag and drop): hover highlights a card (and emits `card_hovered`), left-click selects it (`card_selected`),
## right-click asks for inspection (`card_inspected`); a mouse click also emits `card_clicked`. With no text field focused, the arrow keys
## move the selection through the visible cards and Enter emits `card_activated`.
##
##     var b := CardBrowser.new()
##     b.card_selected.connect(func(id): preview(id))
##     b.card_inspected.connect(func(id): CardInspector.open(self, view_of(id)))
##     parent.add_child(b)

## Left-click on a card (or keyboard move): `id` is now the selected card.
signal card_selected(id: int)
## Right-click on a card.
signal card_inspected(id: int)
## Enter on the selected card.
signal card_activated(id: int)
## Left mouse click on a card, emitted after `card_selected` (the deck builder adds a copy).
signal card_clicked(id: int)
## The pointer entered a card (no click). Nothing is emitted when it leaves.
signal card_hovered(id: int)
## The visible set changed (search, filter or sort).
signal filters_changed

## Off when the owner plays its own sound for a click (the deck builder's add sound).
var click_sound: bool = true

## Card ("hand" 120x180) and the room around it for the glow and selection brackets.
const CARD_W := 120
const CARD_H := 180
const CELL_PAD := 11
const CELL_W := CARD_W + CELL_PAD * 2
## Smallest gap between columns (the rest of the row width is shared out between them).
const GRID_MIN_GAP := 8
const ROW_GAP := 4
## Seconds a keyboard / programmatic scroll takes to glide a card into view.
const SCROLL_TIME := 0.22

const COST_OPTIONS := [
	["Any cost", ""], ["0 AP", "ap:0"], ["1 AP", "ap:1"], ["2 AP", "ap:2"], ["3 AP", "ap:3"],
	["4 AP", "ap:4"], ["5+ AP", "ap:5+"], ["Fusion", "kind:fusion"], ["Ritual", "kind:ritual"],
	["Arcane", "kind:arcane"],
]
const SORT_OPTIONS := [["Catalogue order", "index"], ["Name", "name"], ["Cost", "cost"], ["Highest ATK", "atk"], ["Highest DEF", "def"]]

## Height reserved under each card for the owner's footer content (0 = none).
var footer_h: int = 0
## Offer the sort selector (the catalogue screen; the deck builder keeps catalogue order).
var with_sort: bool = false
## Currently selected card id (-1 = none).
var selected_id: int = -1

var search: LineEdit
var cat_opt: OptionButton
var type_opt: OptionButton
var race_opt: OptionButton
var cost_opt: OptionButton
var sort_opt: OptionButton
var scroll: SmoothScroll
var grid: HFlowContainer

## card id -> {cell, widget, glow, footer}
var _cells: Dictionary = {}
var _summaries: Dictionary = {}
var _no_match: Control
var _empty_lib: Control
var _scroll_tw: Tween
var _built := false


func _init(sortable: bool = false, footer_px: int = 0) -> void:
	with_sort = sortable
	footer_h = footer_px
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	if not _built:
		build()


## Builds the filter row and one cell per catalogue card (once; filters only hide cells).
func build() -> void:
	if _built:
		return
	_built = true
	CardDB.ensure_loaded()
	_build_filters()
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(stack)
	scroll = SmoothScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(scroll)
	grid = HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", GRID_MIN_GAP)
	grid.add_theme_constant_override("v_separation", ROW_GAP)
	scroll.add_child(grid)
	grid.resized.connect(_spread_grid)
	for d in CardDB.all():
		grid.add_child(_make_cell(d))
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(cc)
	_no_match = empty_state("No cards match", "Try another search or loosen the filters.", "Clear filters", clear_filters)
	cc.add_child(_no_match)
	_empty_lib = empty_state("The card library is empty", "No card data could be loaded.", "", Callable())
	cc.add_child(_empty_lib)
	refresh()


# ------------------------------------------------------------ pure logic (testable)

## True if card def `d` passes the filters. Empty string means "any".
## cost is "", "ap:N", "ap:5+" or "kind:fusion|ritual|arcane". The search matches every word
## against the name, rules text, race, type and category name.
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
		var hay := " ".join([String(d["name"]), String(MatchView._rules_text(d)),
			String(d["race"] if d["race"] != null else ""), String(d["type"] if d["type"] != null else ""),
			String(UIStyle.CATEGORY_NAMES.get(d["category"], ""))]).to_lower()
		for word in q.split(" ", false):
			if not hay.contains(word):
				return false
	return true


## Sort key comparison for `mode` ("index", "name", "cost", "atk", "def"); ties fall back to
## catalogue order. Dynamic (null) stats and non-AP costs sort last.
static func sort_before(a: Dictionary, b: Dictionary, mode: String, index_of: Dictionary) -> bool:
	var ia: int = index_of.get(int(a["id"]), 0)
	var ib: int = index_of.get(int(b["id"]), 0)
	match mode:
		"name":
			var na := String(a["name"]).to_lower()
			var nb := String(b["name"]).to_lower()
			if na != nb:
				return na < nb
		"cost":
			var ca: float = float(a["cost"]) if a["cost_kind"] == "ap" and a["cost"] != null else 1000.0
			var cb: float = float(b["cost"]) if b["cost_kind"] == "ap" and b["cost"] != null else 1000.0
			if ca != cb:
				return ca < cb
		"atk", "def":
			var va: float = float(a[mode]) if a.get(mode) != null else -1.0
			var vb: float = float(b[mode]) if b.get(mode) != null else -1.0
			if va != vb:
				return va > vb
	return ia < ib


## Card id -> position in canonical catalogue order (CardDB.all()).
static func catalogue_index() -> Dictionary:
	var out := {}
	var i := 0
	for d in CardDB.all():
		out[int(d["id"])] = i
		i += 1
	return out


# ------------------------------------------------------------ public API

## Sets the search text and refreshes.
func set_query(text: String) -> void:
	search.text = text
	refresh()


## Resets the search, every filter and the sort.
func clear_filters() -> void:
	search.text = ""
	for o in [cat_opt, type_opt, race_opt, cost_opt, sort_opt]:
		if o != null:
			o.select(0)
	refresh()


## Number of cards currently shown.
func visible_count() -> int:
	var n := 0
	for c in _cells.values():
		if c["cell"].visible:
			n += 1
	return n


## Ids of the shown cards in on-screen order.
func visible_ids() -> Array:
	var out := []
	for cell in grid.get_children():
		if cell.visible:
			out.append(int(cell.get_meta("card_id")))
	return out


## The card widget of card `id` (null when absent).
func cell_widget(id: int) -> CardWidget:
	return _cells[id]["widget"] if _cells.has(id) else null


## The grid cell of card `id` (null when absent).
func cell(id: int) -> Control:
	return _cells[id]["cell"] if _cells.has(id) else null


## The footer slot under card `id` (empty Control of footer_h; null without footers).
func footer(id: int) -> Control:
	return _cells[id]["footer"] if _cells.has(id) else null


## Shows or hides the soft gold glow behind card `id` (e.g. "in the deck").
func set_marked(id: int, on: bool) -> void:
	if _cells.has(id):
		(_cells[id]["glow"] as Control).visible = on


## Selects card `id` (selection brackets on its card). `notify` emits card_selected.
func select(id: int, notify: bool = true) -> void:
	if _cells.has(selected_id):
		(_cells[selected_id]["widget"] as CardWidget).set_marks(false, false)
	selected_id = id
	if _cells.has(id):
		(_cells[id]["widget"] as CardWidget).set_marks(false, true)
	if notify:
		card_selected.emit(id)


## Glides the scroll view so card `id` is fully visible.
func reveal(id: int) -> void:
	if not _cells.has(id) or scroll == null:
		return
	var c: Control = _cells[id]["cell"]
	var top := c.position.y
	var bottom := top + c.size.y
	var view_h := scroll.size.y
	var cur := float(scroll.scroll_vertical)
	var to := cur
	if top < cur:
		to = top
	elif bottom > cur + view_h:
		to = bottom - view_h
	if is_equal_approx(to, cur):
		return
	if _scroll_tw != null and _scroll_tw.is_valid():
		_scroll_tw.kill()
	if UIStyle.reduce_motion or not is_inside_tree():
		scroll.scroll_vertical = int(to)
		return
	_scroll_tw = create_tween()
	_scroll_tw.tween_property(scroll, "scroll_vertical", int(to), UIStyle.dur(SCROLL_TIME)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Moves the selection `step` visible cards (keyboard navigation); returns the new id.
func move_selection(step: int) -> int:
	var ids := visible_ids()
	if ids.is_empty():
		return -1
	var at := ids.find(selected_id)
	var to := 0 if at < 0 else clampi(at + step, 0, ids.size() - 1)
	select(int(ids[to]))
	reveal(int(ids[to]))
	return int(ids[to])


## Number of grid columns at the current width.
func columns() -> int:
	return maxi(1, int(floor((grid.size.x + GRID_MIN_GAP) / float(CELL_W + GRID_MIN_GAP))))


## Re-applies search, filters and sort.
func refresh() -> void:
	var cat := _sel(cat_opt)
	var type := _sel(type_opt)
	var race := _sel(race_opt)
	var cost := _sel(cost_opt)
	var n := 0
	for d in CardDB.all():
		var show := matches(d, search.text, cat, type, race, cost)
		_cells[int(d["id"])]["cell"].visible = show
		if show:
			n += 1
	_apply_sort()
	_no_match.visible = n == 0 and not _cells.is_empty()
	_empty_lib.visible = _cells.is_empty()
	filters_changed.emit()


# ------------------------------------------------------------ construction

## Empty / no-results block: a soft slot with a title, a hint and an optional action button.
static func empty_state(title: String, hint: String, action: String, on_action: Callable) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.05, 0.04, 0.03, 0.85), Color(UIStyle.BRONZE, 0.7), 1, 10)
	sb.set_content_margin_all(22)
	UIStyle.lift_style(sb, Color(0, 0, 0, 0.5), 10, 2)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(320, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var t := UIStyle.title_label(title, 20, UIStyle.GOLD_HI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := UIStyle.label(hint, 14, UIStyle.TEXT_DIM, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	if action != "":
		var b := UIStyle.button(action, 14)
		b.custom_minimum_size = Vector2(140, 34)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(on_action)
		v.add_child(b)
	return pc


## Gives a LineEdit the house look (ink fill, bronze rim, gold when focused; red rim for errors).
static func style_edit(le: LineEdit, err: bool = false) -> void:
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


func _build_filters() -> void:
	search = LineEdit.new()
	search.placeholder_text = "Search name, rules, race or type..."
	search.clear_button_enabled = true
	style_edit(search)
	search.text_changed.connect(func(_t): refresh())
	add_child(search)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 6)
	add_child(filters)
	cat_opt = OptionButton.new()
	cat_opt.add_item("Any category")
	cat_opt.set_item_metadata(0, "")
	for k in UIStyle.CATEGORY_NAMES:
		cat_opt.add_item(UIStyle.CATEGORY_NAMES[k])
		cat_opt.set_item_metadata(cat_opt.item_count - 1, k)
	type_opt = _opt(CardDB.ELEMENTS, "Any Type")
	race_opt = _opt(CardDB.RACES, "Any Race")
	cost_opt = OptionButton.new()
	for c in COST_OPTIONS:
		cost_opt.add_item(c[0])
		cost_opt.set_item_metadata(cost_opt.item_count - 1, c[1])
	var opts := [cat_opt, type_opt, race_opt, cost_opt]
	if with_sort:
		sort_opt = OptionButton.new()
		for c in SORT_OPTIONS:
			sort_opt.add_item(c[0])
			sort_opt.set_item_metadata(sort_opt.item_count - 1, c[1])
		sort_opt.tooltip_text = "Sort order"
		opts.append(sort_opt)
	for o in opts:
		o.item_selected.connect(func(_i): refresh())
		o.focus_mode = Control.FOCUS_NONE
		filters.add_child(o)
	var reset := UIStyle.button("Clear filters", 13)
	reset.custom_minimum_size = Vector2(0, 30)
	reset.pressed.connect(clear_filters)
	filters.add_child(reset)


func _opt(items: Array, first: String) -> OptionButton:
	var o := OptionButton.new()
	o.add_item(first)
	o.set_item_metadata(0, "")
	for it in items:
		o.add_item(String(it))
		o.set_item_metadata(o.item_count - 1, String(it))
	return o


func _sel(o: OptionButton) -> String:
	return String(o.get_item_metadata(o.selected)) if o != null and o.selected >= 0 else ""


func _summary(id: int) -> Dictionary:
	if not _summaries.has(id):
		_summaries[id] = Series.card_summary(id)
	return _summaries[id]


## One cell: soft glow (marked), the card, an implementation-status chip and an optional footer.
func _make_cell(d: Dictionary) -> Control:
	var id := int(d["id"])
	var sm := _summary(id)
	var status := String(sm["support"])
	var c := Control.new()
	c.set_meta("card_id", id)
	c.custom_minimum_size = Vector2(CELL_W, CELL_PAD * 2 + CARD_H + footer_h)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var glow := Panel.new()
	var gs := UIStyle.flat(Color(UIStyle.GOLD, 0.0), UIStyle.GOLD_HI, 2, 8)
	gs.shadow_color = Color(UIStyle.GOLD, 0.55)
	gs.shadow_size = 9
	glow.add_theme_stylebox_override("panel", gs)
	glow.position = Vector2(CELL_PAD, CELL_PAD)
	glow.size = Vector2(CARD_W, CARD_H)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	c.add_child(glow)
	var w := CardWidget.new().setup(MatchView.summary_view(sm), "hand")
	w.position = Vector2(CELL_PAD, CELL_PAD)
	if status != "full":
		w.tooltip_text += "\n\nImplementation: %s" % status
	w.pressed.connect(func(_w): _on_click(id))
	w.right_pressed.connect(func(_w): card_inspected.emit(id))
	w.mouse_entered.connect(func(): card_hovered.emit(id))
	c.add_child(w)
	if status != "full":
		var warn := PanelContainer.new()
		var ws := UIStyle.flat(Color(0, 0, 0, 0.6), UIStyle.BAD, 1, 9)
		ws.content_margin_left = 6
		ws.content_margin_right = 6
		warn.add_theme_stylebox_override("panel", ws)
		var wl := UIStyle.label("!", 12, UIStyle.BAD)
		wl.add_theme_font_override("font", UIStyle.font_bold())
		warn.add_child(wl)
		warn.tooltip_text = "Implementation: %s" % status
		warn.position = Vector2(2, 2)
		c.add_child(warn)
	var foot: Control = null
	if footer_h > 0:
		foot = Control.new()
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.position = Vector2(0, CELL_PAD + CARD_H + 3)
		foot.size = Vector2(CELL_W, footer_h)
		c.add_child(foot)
	_cells[id] = {"cell": c, "widget": w, "glow": glow, "footer": foot}
	return c


func _on_click(id: int) -> void:
	if id != selected_id and click_sound:
		Sfx.play("select", -4.0, 0.03)
	select(id)
	_pulse(cell_widget(id))
	card_clicked.emit(id)


## Brief scale pulse on a clicked card (skipped under reduced motion).
func _pulse(w: Control) -> void:
	if w == null or UIStyle.reduce_motion or not w.is_inside_tree():
		return
	w.pivot_offset = w.size / 2.0
	w.scale = Vector2(0.95, 0.95)
	var tw := w.create_tween()
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_sort() -> void:
	var mode := _sel(sort_opt) if sort_opt != null else ""
	if mode == "":
		mode = "index"
	var idx := catalogue_index()
	var defs := CardDB.all()
	if mode != "index":
		defs.sort_custom(func(a, b): return sort_before(a, b, mode, idx))
	for i in defs.size():
		var c: Control = _cells[int(defs[i]["id"])]["cell"]
		if c.get_index() != i:
			grid.move_child(c, i)


## Spreads the columns across the full width: the leftover space becomes the gap between
## columns instead of a dead strip at the right edge.
func _spread_grid() -> void:
	var w := grid.size.x
	var cols := columns()
	var gap := GRID_MIN_GAP if cols == 1 else int(floor((w - cols * CELL_W) / float(cols - 1)))
	if grid.get_theme_constant("h_separation") != gap:
		grid.add_theme_constant_override("h_separation", gap)


## Arrow keys move the selection, Enter activates it (never while typing or under a modal).
func _unhandled_key_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or not is_visible_in_tree() or CardInspector.open_count() > 0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var step := 0
	match ke.keycode:
		KEY_LEFT: step = -1
		KEY_RIGHT: step = 1
		KEY_UP: step = -columns()
		KEY_DOWN: step = columns()
		KEY_ENTER, KEY_KP_ENTER:
			if selected_id >= 0 and not ke.echo:
				card_activated.emit(selected_id)
				get_viewport().set_input_as_handled()
			return
		_:
			return
	move_selection(step)
	get_viewport().set_input_as_handled()
