class_name CardInspector
extends Control
## Large, centred, read-only card inspection (F03-01): a big 2:3 card beside the full card
## details (identity, tags, stats, Modifiers, rules, statuses, Rune counters), over a dimmed
## screen. It only displays the redacted card view it is given; it never reads or changes game
## state, so opening it can never select, target, play or cancel anything.
##
## Reusable anywhere a card view dictionary exists (match, pile browser, deck builder):
##   var ins := CardInspector.open(some_control, card_view, func(): print("closed"))
## `open` returns null for a view that must not be inspected (empty or hidden/face-down).
## Close with the button, Esc or a click outside the panel; `close()` does the same from code.
## A host that receives newer views can call `show_card(new_view)` or `refresh_open(finder)`.

## Emitted once when the inspector closes.
signal closed

const DETAILS_W := 520.0
## Details text is larger than in the sidebar: the inspector is read at a glance.
const DETAILS_TEXT_SCALE := 1.2
const PAD := 22.0

## Inspectors currently open, oldest first (the last one is on top).
static var _stack: Array = []

var _card: Dictionary = {}
var _on_closed: Callable = Callable()
var _closing: bool = false
var _panel: HousePanel
var _dim: ColorRect
var _card_box: Control
var _card_widget: CardWidget
var _details: CardDetailsPanel
## L23: the "Evolves into" section under the details.
var _evolve: EvolvePreview
var _scroll: ScrollContainer
var _sig: int = 0
## Where the card came from (global rect; empty: no fly) and the flying copy while it moves.
var _from: Rect2 = Rect2()
var _ghost: CardWidget
## The fly takes most of card_move (design review #87: about 300 ms).
const FLY_K := 0.8


## True when `card` may be shown: a visible card view (not empty, not a hidden/face-down
## placeholder, and carrying an identity).
static func is_inspectable(card: Dictionary) -> bool:
	return not card.is_empty() and not card.get("hidden", false) and (card.has("uid") or card.has("id"))


## Opens an inspector as a full-rect child of `parent` showing `card`. Returns it, or null when
## the card is not inspectable. `on_closed` is called once after it closes. `from` (a global rect,
## optional) is where the card was on screen: the big card flies out of it and back into it on close
## (design review #87).
static func open(parent: Node, card: Dictionary, on_closed: Callable = Callable(), from: Rect2 = Rect2()) -> CardInspector:
	if parent == null or not is_inspectable(card):
		return null
	var ins := CardInspector.new()
	ins._on_closed = on_closed
	ins._from = from
	ins._build()
	parent.add_child(ins)
	ins.show_card(card)
	ins._relayout()
	ins._appear()
	_stack.append(ins)
	return ins


## Number of inspectors open.
static func open_count() -> int:
	return _stack.size()


## The topmost open inspector, or null.
static func topmost() -> CardInspector:
	return null if _stack.is_empty() else _stack[_stack.size() - 1]


## Closes the topmost inspector; true when one was open.
static func close_topmost() -> bool:
	var t := topmost()
	if t == null:
		return false
	t.close()
	return true


## Re-reads every open inspector's card: `finder` takes the card uid and returns the current
## visible card view ({} when it is gone or no longer visible, which closes the inspector).
## Definition views (negative uid, e.g. from the game log) have no live instance and are kept.
static func refresh_open(finder: Callable) -> void:
	for ins in _stack.duplicate():
		var uid: int = ins.card_uid()
		if uid < 0:
			continue
		var v: Dictionary = finder.call(uid)
		if v.is_empty() or v.get("hidden", false):
			ins.close()
		else:
			ins.show_card(v)


## Closes every open inspector (screen teardown).
static func close_all() -> void:
	for ins in _stack.duplicate():
		ins.close()


## The card view currently shown.
func card() -> Dictionary:
	return _card


## Uid of the shown card (-1 when none).
func card_uid() -> int:
	return int(_card.get("uid", -1))


## The details panel (tests read its text).
func details() -> CardDetailsPanel:
	return _details


## L23: the "Evolves into" section (visible only for a card that evolves).
func evolve_preview() -> EvolvePreview:
	return _evolve


## Shows `c` (rebuilds only when it changed). A non-inspectable view closes the inspector.
func show_card(c: Dictionary) -> void:
	if not is_inspectable(c):
		close()
		return
	var sig := hash(c)
	if sig == _sig:
		return
	_sig = sig
	var same_card: bool = card_uid() == int(c.get("uid", -1))
	_card = c
	var face := c.duplicate()
	face["face_up"] = true     # your own face-down Trap/Spell is read here, not drawn as a back
	_card_widget.setup(face, "big")
	_panel.set_tag(String(c.get("category", "")).replace("_", " "))
	_layout_card()
	var keep := _scroll.scroll_vertical
	# D14: a Spell / Trap / Power has no stats section, so its rules read larger and fill the column.
	_details.text_scale = DETAILS_TEXT_SCALE if CardDetailsPanel.is_unit_view(c) else DETAILS_TEXT_SCALE * 1.3
	_details.show_card(c)
	_evolve.show_for(c)
	_scroll.set_deferred("scroll_vertical", keep if same_card else 0)


## Closes the inspector (idempotent), then runs the on_closed callback. It counts as closed at once
## (open_count, closed); on screen it fades out with `panel_out` while the card flies back to where
## it came from, then frees itself. Hidden at once when not in the tree.
func close() -> void:
	if _closing:
		return
	_closing = true
	_stack.erase(self)
	closed.emit()
	if _on_closed.is_valid():
		_on_closed.call()
	if not is_inside_tree():
		visible = false
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in find_children("*", "Control", true, false):
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("panel_close")
	var tw := create_tween()
	tw.set_parallel(true)
	if UIStyle.reduce_motion:
		tw.tween_property(self, "modulate:a", 0.0, UIStyle.motion("reduced"))
	else:
		UIStyle.tween_token(tw, _panel, "modulate:a", 0.0, "panel_out")
		UIStyle.tween_token(tw, _dim, "modulate:a", 0.0, "panel_out")
		if _fly(_card_widget.get_global_rect(), _from, false) != null:
			tw.tween_interval(UIStyle.motion("card_move") * FLY_K)
	tw.chain().tween_callback(queue_free)


func _exit_tree() -> void:
	_stack.erase(self)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = UiLayers.CARD_INSPECTOR
	z_as_relative = false
	var dim := ColorRect.new()
	_dim = dim
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			close())
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_panel = HousePanel.new("Card details", "", Vector2(PAD - HousePanel.ACCENT_W, PAD), 10)
	_panel.arm = 20.0
	cc.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.body.add_child(row)
	_card_box = Control.new()
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_card_box)
	_card_widget = CardWidget.new()
	_card_widget.auto_hover = false
	_card_widget.show_tooltip = false
	# The card takes hover (its status icons name themselves) but is not a button.
	_card_widget.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_widget.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_card_box.add_child(_card_widget)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = DETAILS_W
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	# F04-16: no "Esc or click outside" hint; Esc and click-outside still close. The Close button sits
	# at the right with a gold hairline under the header so it reads as a deliberate title bar.
	var lead := Control.new()
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(lead)
	var x := UIStyle.button("Close", 15)
	x.custom_minimum_size = Vector2(100, 36)
	x.pressed.connect(close)
	head.add_child(x)
	var rule := ColorRect.new()
	rule.color = Color(UIStyle.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_details = CardDetailsPanel.new()
	_details.text_scale = DETAILS_TEXT_SCALE
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_details)
	# L23: "Evolves into" (hidden unless the card evolves). Its preview opens the next card's inspector
	# on top of this one, so the chain can be walked and each one closes back to the last.
	_evolve = EvolvePreview.new()
	_evolve.open_requested.connect(func(v: Dictionary, from: Rect2) -> void:
		if not _closing and is_inside_tree():
			CardInspector.open(get_parent(), v, Callable(), from))
	body.add_child(_evolve)
	resized.connect(_relayout)


## Sizes the card (2:3, never stretched) and the details column for the current screen size.
func _relayout() -> void:
	if _card_box == null:
		return
	_layout_card()


func _layout_card() -> void:
	var s := size if size.x > 100.0 else Vector2(1600, 1000)
	var card_h := clampf(s.y * 0.72, 340.0, 780.0)
	var card_w := card_h * 2.0 / 3.0
	var room := s.x * 0.96 - DETAILS_W - 24.0 - 2.0 * PAD
	if card_w > room:
		card_w = maxf(180.0, room)
		card_h = card_w * 1.5
	_card_box.custom_minimum_size = Vector2(card_w, card_h)
	_card_box.size = Vector2(card_w, card_h)
	GameUi.resize_card(_card_widget, Vector2(card_w, card_h))
	_card_widget.position = Vector2.ZERO
	_scroll.custom_minimum_size.y = card_h - 48.0
	_panel.reset_size()


func _appear() -> void:
	if not is_inside_tree():
		return
	# The panel's own appear plays panel_open and its motion (a 120 ms fade under reduce motion).
	_panel.appear()
	if UIStyle.reduce_motion:
		return
	_dim.modulate.a = 0.0
	UIStyle.tween_token(create_tween(), _dim, "modulate:a", 1.0, "hover")
	if _from.size.x < 4.0:
		return
	# The card flies from its place on the board once the panel is laid out (next frame; a one-shot
	# signal rather than an await, so nothing stays suspended if the inspector is freed first).
	_card_widget.modulate.a = 0.0
	get_tree().process_frame.connect(_fly_in, CONNECT_ONE_SHOT)


## The opening flight, one frame after the panel appeared.
func _fly_in() -> void:
	if _closing or not is_inside_tree():
		return
	var ps := _panel.scale
	_panel.scale = Vector2.ONE     # the card's resting rect, not the one inside the panel's pop
	var to := _card_widget.get_global_rect()
	_panel.scale = ps
	if _fly(_from, to, true) == null:
		_card_widget.modulate.a = 1.0


## A copy of the big card moving from global rect `a` to `b` along a short arc (`card_move`): on
## arrival (`landing`) the real card shows and the copy goes. Null when there is nothing to fly.
func _fly(a: Rect2, b: Rect2, landing: bool) -> CardWidget:
	if a.size.x < 4.0 or b.size.x < 4.0 or UIStyle.reduce_motion or not is_inside_tree():
		return null
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	var g := CardWidget.new()
	_ghost = g
	g.auto_hover = false
	g.show_tooltip = false
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := _card_widget.view.duplicate()
	g.setup(face, "big")
	add_child(g)
	var big := b if landing else a
	GameUi.resize_card(g, big.size)
	var inv := get_global_transform().affine_inverse()
	var k_a := a.size.x / big.size.x
	var k_b := b.size.x / big.size.x
	g.pivot_offset = Vector2.ZERO
	var p0 := inv * a.position
	var p1 := inv * b.position
	g.position = p0
	g.scale = Vector2(k_a, k_a)
	if not landing:
		_card_widget.modulate.a = 0.0
	var d := UIStyle.motion("card_move") * FLY_K
	var apex := (p0 + p1) / 2.0 + Vector2(0, -40.0)
	var tw := g.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(g):
			g.position = p0.lerp(apex, t).lerp(apex.lerp(p1, t), t), 0.0, 1.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(g, "scale", Vector2(k_b, k_b), d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func() -> void:
		if landing and is_instance_valid(_card_widget):
			_card_widget.modulate.a = 1.0
		if is_instance_valid(g):
			g.queue_free())
	return g


func _unhandled_key_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE and topmost() == self:
		get_viewport().set_input_as_handled()
		close()
