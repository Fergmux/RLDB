class_name CardListScreen
extends Control
## "Card list" screen of the Decks menu (F14): the full card catalogue for browsing. The shared
## CardBrowser (search, category / Type / Race / cost filters, sort, responsive smooth-scrolling
## grid, hover and selection feedback, no-results state) fills the left; the right pane shows
## the selected card large with its full details. Right-click (or Enter) opens the shared card
## inspector. Browsing only: nothing here edits a deck.
##
## Esc closes an open inspector first (it handles the key itself), otherwise it is the Back
## button. Emits `closed` once on Back.

## Emitted when the screen is closed.
signal closed

const MARGIN := 16
const PREVIEW_W := 380

## The shared browser (filters + grid).
var browser: CardBrowser

var _preview_holder: CenterContainer
var _preview_card: CardWidget
var _details: CardDetailsPanel
var _preview_title: Label
var _note: Label
var _preview_empty: Control
var _preview_body: Control
var _shown_id: int = -1
var _summaries: Dictionary = {}
var _leaving := false


func _ready() -> void:
	CardDB.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DeckBuilder.table_backdrop(self)
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
	tv.add_child(UIStyle.title_label("CARD CATALOGUE", 30, UIStyle.GOLD))
	tv.add_child(DeckBuilder.Rule.new())
	head.add_child(tv)
	var back := UIStyle.button("Back", 15)
	back.custom_minimum_size = Vector2(90, 36)
	back.pressed.connect(_on_back)
	head.add_child(back)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var left := DeckBuilder.plate()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	lv.add_child(DeckBuilder.heading("All cards"))
	browser = CardBrowser.new(true, 0)
	browser.card_selected.connect(show_card)
	browser.card_inspected.connect(func(id): inspect_card(id))
	browser.card_activated.connect(func(id): inspect_card(id))
	browser.filters_changed.connect(_on_filters_changed)
	lv.add_child(browser)
	browser.build()

	_build_preview(body)
	var ids := browser.visible_ids()
	if not ids.is_empty():
		browser.select(int(ids[0]))
	else:
		_show_empty_preview()


func _build_preview(body: HBoxContainer) -> void:
	var p := DeckBuilder.plate(UIStyle.PANEL_INK)
	p.custom_minimum_size = Vector2(PREVIEW_W, 0)
	body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(DeckBuilder.heading("Selected card"))
	_preview_empty = CardBrowser.empty_state("No card selected", "Click a card in the catalogue to read it here.", "", Callable())
	_preview_empty.visible = false
	v.add_child(_preview_empty)
	_preview_body = VBoxContainer.new()
	_preview_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_body.add_theme_constant_override("separation", 10)
	v.add_child(_preview_body)
	_preview_holder = CenterContainer.new()
	_preview_body.add_child(_preview_holder)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_body.add_child(row)
	var ins := UIStyle.button("Inspect", 14)
	ins.custom_minimum_size = Vector2(120, 32)
	ins.tooltip_text = "Open the large card view (right-click or Enter)"
	ins.pressed.connect(func(): if _shown_id >= 0: inspect_card(_shown_id))
	row.add_child(ins)
	var sc := ScrollArea.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_body.add_child(sc)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	_details = CardDetailsPanel.new()
	_details.construction = true
	inner.add_child(_details)
	_note = UIStyle.label("", 13, UIStyle.BAD, true)
	inner.add_child(_note)
	sc.set_content(inner)


func _summary(id: int) -> Dictionary:
	if not _summaries.has(id):
		_summaries[id] = Series.card_summary(id)
	return _summaries[id]


## Shows card `id` in the right-hand pane.
func show_card(id: int) -> void:
	if not CardDB.has(id):
		_show_empty_preview()
		return
	_preview_empty.visible = false
	_preview_body.visible = true
	if id == _shown_id:
		return
	_shown_id = id
	for c in _preview_holder.get_children():
		_preview_holder.remove_child(c)
		c.queue_free()
	var s := _summary(id)
	_preview_card = CardWidget.new().setup(MatchView.summary_view(s), "big")
	_preview_card.show_tooltip = false
	_preview_card.tooltip_text = ""
	_preview_card.right_pressed.connect(func(_w): inspect_card(id))
	_preview_card.pressed.connect(func(_w): inspect_card(id))
	_preview_holder.add_child(_preview_card)
	_details.show_card(MatchView.summary_view(s))
	_note.visible = s["support"] != "full"
	_note.text = "Implementation: %s" % s["support"]
	if not UIStyle.reduce_motion and is_inside_tree():
		_preview_card.modulate.a = 0.0
		_preview_card.pivot_offset = _preview_card.size / 2.0
		_preview_card.scale = Vector2(0.96, 0.96)
		var tw := _preview_card.create_tween().set_parallel(true)
		tw.tween_property(_preview_card, "modulate:a", 1.0, UIStyle.dur(0.14))
		tw.tween_property(_preview_card, "scale", Vector2.ONE, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The card shown in the preview pane (-1 when none).
func shown_id() -> int:
	return _shown_id


## True while the preview shows its "No card selected" state.
func preview_is_empty() -> bool:
	return _preview_empty.visible


## Opens the shared inspector for card `id`.
func inspect_card(id: int) -> CardInspector:
	return CardInspector.open(self, MatchView.summary_view(_summary(id)))


func _show_empty_preview() -> void:
	_shown_id = -1
	_preview_empty.visible = true
	_preview_body.visible = false


## Keeps the preview in step with the filters: a selection the filters hid gives way to the first
## visible card; no visible cards shows the empty preview.
func _on_filters_changed() -> void:
	if _preview_body == null:
		return
	var ids := browser.visible_ids()
	if ids.is_empty():
		_show_empty_preview()
	elif not ids.has(browser.selected_id):
		browser.select(int(ids[0]))
	else:
		show_card(browser.selected_id)


func _on_back() -> void:
	if _leaving:
		return
	Sfx.play("back")   # F22: Back button and Esc alike; one sound (coalesced with the button's)
	_leaving = true
	closed.emit()


func _input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo or ke.keycode != KEY_ESCAPE or not is_visible_in_tree():
		return
	if CardInspector.open_count() > 0:
		return   # the inspector closes itself on this key; nothing else happens
	get_viewport().set_input_as_handled()
	_on_back()


## Number of cards per CardScripts support status ("full", "partial", ...).
static func support_counts() -> Dictionary:
	var counts := {}
	for d in CardDB.all():
		var s := CardScripts.support_status(d["id"])
		counts[s] = counts.get(s, 0) + 1
	return counts
