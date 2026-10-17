class_name DeckTile
extends PanelContainer
## One deck on the pre-game deck-select screen (starter or saved, identical format): crest, name,
## blurb, Type icons, Main / Extra count plates, a card-kind composition bar, signature-card art
## strips and the Choose button. Clicking the tile selects it (gold rim, full card list opens);
## hovering lifts the rim and glow smoothly.

## Emitted when the player presses Choose.
signal chosen
## Emitted when the tile body is clicked (select / deselect).
signal toggled

const KIND_ORDER := ["basic_unit", "unit", "fusion", "ritual", "arcane", "spell", "trap", "power"]
const DECK_SORT := ["basic_unit", "unit", "spell", "trap", "power", "fusion", "ritual", "arcane"]

## True while selected (rim, glow and the open list follow it).
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
var _hover := 0.0
## False until the first frame: the rim and glow then start at their resting state instead of
## easing in from nothing (G02: a re-rendered list never flashes its hover or selection glow).
var _primed := false
var _box: StyleBoxFlat
var _root: VBoxContainer
var _brow: HBoxContainer
var _tog: Button
var _main: Array = []
var _extra: Array = []
## The open card list (rule + Main / Extra sections) while the tile is open.
var _list_nodes: Array = []


## Builds the tile. `d`: title, theme, main (Array of card summaries), extra, btn_text, open (bool),
## blocked (why the deck cannot be used; empty when it can).
func _init(d: Dictionary = {}) -> void:
	_box = UIStyle.flat(Color(0, 0, 0, 0), UIStyle.BRONZE, 2, 10)
	_box.content_margin_left = 16
	_box.content_margin_right = 16
	_box.content_margin_top = 14
	_box.content_margin_bottom = 14
	_box.shadow_color = Color(0, 0, 0, 0.5)
	_box.shadow_size = 8
	_box.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", _box)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	selected = bool(d.get("open", false))
	_build(d)
	# A tile built open shows its gold rim from its first drawn frame (no fade-in flash).
	_hover = 1.0 if selected else 0.0
	_apply_rim()


func _build(d: Dictionary) -> void:
	var main: Array = d.get("main", [])
	var extra: Array = d.get("extra", [])
	_main = main
	_extra = extra
	var root := VBoxContainer.new()
	_root = root
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Header: crest | name + blurb + Type icons | count plates.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)
	var types := GameSeriesOverlay._dominant_types(main)
	var crest := DeckCrest.new()
	crest.types = types
	crest.custom_minimum_size = Vector2(58, 70)
	crest.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(crest)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(col)
	var nm := UIStyle.label(String(d.get("title", "")), 22, UIStyle.TEXT, false, true)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var blurb := UIStyle.label(String(d.get("theme", "")), 14, UIStyle.MUTED, true)
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(blurb)
	var ticons := HBoxContainer.new()
	ticons.add_theme_constant_override("separation", 6)
	ticons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ticons)
	for t in types:
		var tb := TypeIcons.TypeBadge.new(String(t), 26.0)
		tb.tooltip_text = "%s deck" % String(t)
		tb.mouse_filter = Control.MOUSE_FILTER_PASS
		ticons.add_child(tb)
		ticons.add_child(_type_word(String(t)))
	var plates := VBoxContainer.new()
	plates.add_theme_constant_override("separation", 5)
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(plates)
	plates.add_child(_count_plate("MAIN", main.size(), UIStyle.GOLD))
	plates.add_child(_count_plate("EXTRA", extra.size(), Color("9d7ae8")))
	# Composition bar (card kinds) under the header.
	var bar := CompBar.new(main + extra)
	root.add_child(bar)
	# Signature cards.
	var keys := GameSeriesOverlay._key_cards(main, extra)
	if not keys.is_empty():
		var sig := HBoxContainer.new()
		sig.add_theme_constant_override("separation", 5)
		sig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(sig)
		for c in keys:
			sig.add_child(CardThumb.new(c))
		for i in range(keys.size(), 5):   # keep every tile's strip the same height and rhythm
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(70, 66)
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sig.add_child(gap)
	# Buttons.
	var brow := HBoxContainer.new()
	_brow = brow
	brow.add_theme_constant_override("separation", 8)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brow)
	var tog := UIStyle.button("Hide full list" if selected else "View full list", 13)
	_tog = tog
	tog.pressed.connect(func(): toggled.emit())
	brow.add_child(tog)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp)
	var pick := UIStyle.primary_button(String(d.get("btn_text", "Choose")), 15)
	pick.custom_minimum_size = Vector2(150, 34)
	pick.pressed.connect(func(): chosen.emit())
	# An unusable deck (e.g. an oversized save from before the deck caps) cannot be chosen.
	var blocked := String(d.get("blocked", ""))
	if blocked != "":
		pick.disabled = true
		pick.tooltip_text = blocked
	brow.add_child(pick)
	if selected:
		_add_list()


## Opens or closes the full card list in place (G02): the tile keeps its node, hover state and
## focus, and the list around it keeps its scroll position, so nothing is rebuilt or flashes.
func set_open(v: bool) -> void:
	if v == selected and (_list_nodes.is_empty() != v):
		return
	selected = v
	_tog.text = "Hide full list" if v else "View full list"
	if v and _list_nodes.is_empty():
		_add_list()
	elif not v:
		for n in _list_nodes:
			_root.remove_child(n)
			n.queue_free()
		_list_nodes.clear()
	_apply_rim()


func _add_list() -> void:
	_list_nodes = [Ornate.Rule.new(Color(UIStyle.GOLD, 0.5), false, 8.0),
		_list_section("MAIN DECK", _main, UIStyle.GOLD),
		_list_section("EXTRA DECK", _extra, Color("9d7ae8"))]
	for n in _list_nodes:
		_root.add_child(n)
		_root.move_child(n, _brow.get_index())


static func _type_word(t: String) -> Label:
	var l := UIStyle.label(t, 13, UIStyle.type_color(t).lightened(0.4))
	l.add_theme_font_override("font", UIStyle.font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Small plate: big number over a small-caps caption, tinted `col`.
static func _count_plate(caption: String, n: int, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(col.darkened(0.78), 0.95), Color(col, 0.75), 1, 7)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(76, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var num := UIStyle.label(str(n), 24, col.lightened(0.5), false, true)
	num.add_theme_font_override("font", UIStyle.font_display(700))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)
	var cap := UIStyle.label(caption, 11, Color(col, 0.95), false, true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	return p


## Captioned wrap of "Name ×2" chips for the open list, in card-kind order.
static func _list_section(caption: String, cards: Array, col: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := UIStyle.label("%s  ·  %d" % [caption, cards.size()], 13, col, false, true)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	if cards.is_empty():
		var none := UIStyle.label("None", 14, UIStyle.TEXT_DIM)
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(none)
		return v
	var counts := {}
	var order := []
	for c in cards:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	order.sort_custom(func(a, b):
		var ka := DECK_SORT.find(String(a["category"]))
		var kb := DECK_SORT.find(String(b["category"]))
		return ka < kb if ka != kb else String(a["name"]) < String(b["name"]))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(flow)
	for c in order:
		var n: int = counts[c["id"]]
		var pill := GameUi.pill(String(c["name"]) + (" ×%d" % n if n > 1 else ""), UIStyle.CATEGORY_COLORS.get(c["category"], UIStyle.BRONZE), 13)
		pill.tooltip_text = "%s (%s)\n%s" % [c["name"], UIStyle.CATEGORY_NAMES.get(c["category"], ""), c["text"]]
		flow.add_child(pill)
	return v


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit()
		accept_event()


func _process(delta: float) -> void:
	var h := get_viewport().gui_get_hovered_control() if is_inside_tree() else null
	var want := 1.0 if h != null and (h == self or is_ancestor_of(h)) else 0.0
	var tgt := 1.0 if selected else want
	var cur := _hover
	_hover = move_toward(_hover, tgt, delta * 8.0)
	if UIStyle.reduce_motion or not _primed:
		_hover = tgt
	if _hover != cur or not _primed:
		_primed = true
		_apply_rim()


## Rim, glow and shadow for the current hover / selection blend.
func _apply_rim() -> void:
	queue_redraw()
	_box.border_color = UIStyle.BRONZE.lerp(UIStyle.GOLD_HI if selected else UIStyle.GOLD, _hover)
	_box.shadow_color = Color(0, 0, 0, 0.5).lerp(Color(UIStyle.GOLD, 0.34), _hover)
	_box.shadow_size = int(lerpf(8.0, 16.0, _hover))
	_box.shadow_offset = Vector2(0, lerpf(3.0, 0.0, _hover))


func _draw() -> void:
	var hv := _hover
	var top := Color("2d2722").lerp(Color("3a3021"), hv)
	var bot := Color("1a1714").lerp(Color("231c11"), hv)
	var rad := 9.0
	var inset := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	Ornate.vgradient(self, Rect2(inset.position + Vector2(0, rad), inset.size - Vector2(0, rad * 2.0)), top, bot)
	draw_rect(Rect2(inset.position + Vector2(rad, 0), Vector2(inset.size.x - rad * 2.0, rad)), top)
	draw_rect(Rect2(inset.position + Vector2(rad, inset.size.y - rad), Vector2(inset.size.x - rad * 2.0, rad)), bot)
	Ornate.vgradient(self, Rect2(inset.position + Vector2(rad, 1), Vector2(inset.size.x - rad * 2.0, 26)), Color(1, 0.9, 0.6, 0.07 + 0.05 * hv), Color(1, 0.9, 0.6, 0))
	Ornate.corners(self, Rect2(Vector2.ZERO, size), Color(UIStyle.BRONZE.lerp(UIStyle.GOLD_HI, maxf(hv, 0.0)), 0.55 + 0.4 * hv), 13.0, 5.0, 1.5)
	if selected:
		draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color(UIStyle.GOLD, 0.35), false, 1.0)


## Card-kind composition: one coloured segment per kind, proportional to its card count.
class CompBar extends Control:
	var _counts := {}
	var _total := 0

	func _init(cards: Array) -> void:
		custom_minimum_size = Vector2(0, 8)
		mouse_filter = Control.MOUSE_FILTER_PASS
		for c in cards:
			var k: String = String(c.get("category", "unit"))
			_counts[k] = int(_counts.get(k, 0)) + 1
			_total += 1
		var parts := []
		for k in DeckTile.KIND_ORDER:
			if _counts.has(k):
				parts.append("%d %s" % [_counts[k], UIStyle.CATEGORY_NAMES.get(k, k)])
		tooltip_text = "  ·  ".join(parts)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		if _total == 0:
			return
		var x := 1.0
		var w := size.x - 2.0
		for k in DeckTile.KIND_ORDER:
			if not _counts.has(k):
				continue
			var sw: float = w * float(_counts[k]) / float(_total)
			var col: Color = UIStyle.CATEGORY_COLORS.get(k, UIStyle.BRONZE)
			Ornate.vgradient(self, Rect2(x, 1, maxf(sw - 1.0, 1.0), size.y - 2.0), col.lightened(0.18), col.darkened(0.2))
			x += sw
		draw_rect(Rect2(Vector2.ZERO, size), Color(UIStyle.BRONZE, 0.7), false, 1.0)
