class_name PileBrowser
extends Control
## Near-full-screen modal listing the cards of a pile (F03-02): the pile name and count, a Close
## button and a responsive wrapped grid of large cards that fills the available space and scrolls
## when it must. It blocks all clicks to what is underneath. Browsing is read-only: left-clicking
## a card does nothing; right-clicking one opens the CardInspector over the browser, and closing
## that returns here with the same scroll position (the browser is never rebuilt for it).
##
## The caller decides WHAT may be listed (it only ever passes cards the viewer may see); this
## control never reads game state:
##   PileBrowser.open(game_screen, "Spent", cards, "Right-click a card to read it.")

## Emitted once when the browser closes.
signal closed

const MARGIN_X := 0.035
const MARGIN_Y := 0.045
const PAD := Vector2(24, 16)
const HEADER_H := 64.0
const GAP := 14.0
const SCROLLBAR_W := 16.0
const CARD_MIN_W := 170.0
const CARD_MAX_W := 300.0

var _title: String = ""
var _hint: String = ""
var _cards: Array = []
var _on_closed: Callable = Callable()
var _closing: bool = false
var _sig: int = 0
var _built: bool = false
var _panel: HousePanel
var _title_label: Label
var _hint_label: Label
var _scroll: ScrollContainer
var _center: CenterContainer
var _grid: GridContainer
var _empty: Label


## Opens a browser as a full-rect child of `parent` listing `cards` (visible card views).
## `title` should carry the pile name; the count is appended. `hint` is a muted line beside it.
static func open(parent: Node, title: String, cards: Array, hint: String = "", on_closed: Callable = Callable()) -> PileBrowser:
	if parent == null:
		return null
	var b := PileBrowser.new()
	b._title = title
	b._hint = hint
	b._on_closed = on_closed
	b._build()
	parent.add_child(b)
	b.set_cards(cards)
	b._relayout()
	b._panel.appear()
	return b


## Best grid for `n` cards of 2:3 shape in `avail` px: returns {"cols", "w", "scroll"}. Prefers the
## largest cards (up to `wmax`) that all fit without scrolling; when they cannot fit at `wmin` or
## larger, uses the most columns whose cards are still at least `wmin` wide and scrolls.
static func best_layout(n: int, avail: Vector2, wmin: float, wmax: float, gap: float) -> Dictionary:
	if n <= 0:
		return {"cols": 1, "w": wmin, "scroll": false}
	var last := {"cols": 1, "w": clampf(avail.x, 80.0, wmax), "scroll": true}
	for cols in range(1, n + 1):
		var w := minf((avail.x - gap * float(cols - 1)) / float(cols), wmax)
		if w < wmin and cols > 1:
			break
		var rows := ceili(float(n) / float(cols))
		var need := float(rows) * w * 1.5 + float(rows - 1) * gap
		last = {"cols": cols, "w": maxf(w, 80.0), "scroll": need > avail.y + 0.5}
		if need <= avail.y + 0.5:
			return last
	return last


## Replaces the listed cards (e.g. after a new view); keeps the scroll position.
func set_cards(cards: Array) -> void:
	var sig := hash(cards)
	if _built and sig == _sig:
		return
	_built = true
	_sig = sig
	_cards = cards
	var keep := _scroll.scroll_vertical
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	for c in cards:
		var w := CardWidget.new()
		w.show_tooltip = false
		w.setup(c, "big")
		w.mouse_default_cursor_shape = Control.CURSOR_ARROW
		w.right_pressed.connect(_on_card_right)
		_grid.add_child(w)
	_empty.visible = cards.is_empty()
	_update_title()
	_relayout()
	_scroll.set_deferred("scroll_vertical", keep)


## Updates the pile name shown in the title.
func set_title(t: String) -> void:
	_title = t
	_update_title()


## The listed card views.
func cards() -> Array:
	return _cards


## Current scroll offset (px).
func scroll_position() -> int:
	return _scroll.scroll_vertical


## Card widgets in list order (tests).
func card_widgets() -> Array:
	return _grid.get_children()


## Columns and card width of the current layout (tests / screenshots).
func current_layout() -> Dictionary:
	return {"cols": _grid.columns, "w": float(CardWidget.SIZES["big"].x) if _grid.get_child_count() == 0 else (_grid.get_child(0) as Control).size.x}


## Closes the browser (idempotent), then runs the on_closed callback.
func close() -> void:
	if _closing:
		return
	_closing = true
	visible = false
	closed.emit()
	if _on_closed.is_valid():
		_on_closed.call()
	queue_free()


func _update_title() -> void:
	_title_label.text = "%s (%d)" % [_title, _cards.size()]
	_hint_label.text = _hint if not _cards.is_empty() else ""


func _on_card_right(w: CardWidget) -> void:
	# Opens over the browser; the browser itself stays untouched underneath.
	CardInspector.open(self, w.view)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = UiLayers.PILE_BROWSER
	z_as_relative = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			close())
	add_child(dim)
	_panel = HousePanel.new("Card pile", "", Vector2(PAD.x - HousePanel.ACCENT_W, PAD.y), 10)
	_panel.arm = 22.0
	add_child(_panel)
	var v := _panel.body
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.custom_minimum_size.y = HEADER_H - 20.0
	v.add_child(head)
	# Design review #89: the hint sits under the title (13 px MUTED) and Close is a secondary, like
	# every other Close in the app.
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", UIStyle.sp("xs"))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	_title_label = UIStyle.label("", 30, UIStyle.GOLD, false, true)
	titles.add_child(_title_label)
	TitleText.apply(_title_label, TitleText.Tier.SCREEN, 30)   # D3: T2 screen title
	_hint_label = UIStyle.label("", 13, UIStyle.MUTED)
	titles.add_child(_hint_label)
	var x := UIStyle.size_button(UIStyle.secondary_button("Close", 15), "standard")
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(close)
	head.add_child(x)
	var rule := ColorRect.new()
	rule.color = Color(UIStyle.GOLD, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_center = CenterContainer.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_center)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_center.add_child(_grid)
	_empty = UIStyle.label("This pile is empty.", 20, UIStyle.MUTED, false, true)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.visible = false
	v.add_child(_empty)
	resized.connect(_relayout)


## Lays the panel out in the screen and sizes the grid cards to fill it.
func _relayout() -> void:
	if _panel == null:
		return
	var s := size if size.x > 100.0 else Vector2(1600, 1000)
	var mx := clampf(s.x * MARGIN_X, 24.0, 90.0)
	var my := clampf(s.y * MARGIN_Y, 20.0, 60.0)
	_panel.position = Vector2(mx, my)
	_panel.size = Vector2(s.x - 2.0 * mx, s.y - 2.0 * my)
	var chrome := _panel.chrome_size()
	var avail := Vector2(_panel.size.x - chrome.x - SCROLLBAR_W - 12.0, _panel.size.y - chrome.y - HEADER_H - 12.0)
	var k := clampf(s.y / 1000.0, 1.0, 2.0)
	var lay := best_layout(_cards.size(), avail, CARD_MIN_W * k, CARD_MAX_W * k, GAP)
	_grid.columns = int(lay["cols"])
	var w: float = lay["w"]
	for ch in _grid.get_children():
		GameUi.resize_card(ch as CardWidget, Vector2(w, w * 1.5))


func _unhandled_key_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE and CardInspector.open_count() == 0:
		get_viewport().set_input_as_handled()
		close()
