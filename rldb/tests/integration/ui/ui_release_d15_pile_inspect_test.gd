extends GdUnitTestSuite
## D15 (owner feedback 20 Oct 2026): the card lists in the right pane have no Inspect button; right-click
## opens the inspector, and the row tooltip says so.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()
	CardInspector.close_all()


func after_test() -> void:
	CardInspector.close_all()


func _open_spent() -> Control:
	var uid := TB.card(m, m.active, TB.WATER, "spent")
	host.broadcast()
	await await_idle_frame()
	gs.details.show_pile("spent")
	await await_idle_frame()
	return gs.details.pile_row(uid)


func _buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_buttons(c, out)


func test_pile_row_has_no_inspect_button_and_its_tooltip_names_right_click() -> void:
	var row := await _open_spent()
	assert_object(row).is_not_null()
	var texts := []
	_buttons(row, texts)
	assert_array(texts).not_contains(["Inspect"])
	assert_str(row.tooltip_text).contains("Right-click to inspect")


## Design review #91: a pile row is a compact summary (name, Type, "ATK / DEF"). J3 (owner, 22 Oct):
## its full details open on a click only (not on hover), and a second click closes them; hovering
## still highlights the row.
func test_pile_row_is_a_compact_summary_that_expands_on_click_only() -> void:
	var row := await _open_spent()
	var uid := int(row.get_meta("uid"))
	var summary := row.find_child("RowSummary", true, false) as Control
	var more := row.find_child("RowDetails", true, false) as Control
	assert_object(summary).is_not_null()
	assert_bool(more.visible).is_false()
	assert_bool(row.find_children("*", "CardDetailsPanel", true, false).is_empty()).is_true()
	var texts := summary.find_children("*", "Label", true, false).map(func(l): return String((l as Label).text))
	assert_array(texts).contains(["/"])
	# H6 (owner, 21 Oct): the row leads with the left input pane's small card face, not an art crop,
	# and names the card's kind before it expands.
	assert_bool(summary.get_child(0) is CardWidget).is_true()
	assert_object((summary.get_child(0) as CardWidget).custom_minimum_size).is_equal(GameDetails.PILE_CARD)
	assert_object(summary.find_child("RowChips", true, false)).is_not_null()
	# Hover: highlighted, not expanded.
	var rest := _border(row)
	row.mouse_entered.emit()
	assert_bool(more.visible).is_false()
	assert_bool(row.find_children("*", "CardDetailsPanel", true, false).is_empty()).is_true()
	assert_bool(_border(row).is_equal_approx(rest)).is_false()
	row.mouse_exited.emit()
	assert_bool(_border(row).is_equal_approx(rest)).is_true()
	# First click: expanded.
	_left_click(row)
	await await_idle_frame()
	row = gs.details.pile_row(uid)
	more = row.find_child("RowDetails", true, false) as Control
	assert_bool(more.visible).is_true()
	assert_int(row.find_children("*", "CardDetailsPanel", true, false).size()).is_equal(1)
	# Leaving the row keeps it open; a second click closes it.
	row.mouse_exited.emit()
	assert_bool(more.visible).is_true()
	_left_click(row)
	await await_idle_frame()
	row = gs.details.pile_row(uid)
	assert_bool((row.find_child("RowDetails", true, false) as Control).visible).is_false()


func _left_click(row: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	row.gui_input.emit(ev)


func _border(row: Control) -> Color:
	return (row.get_theme_stylebox("panel") as StyleBoxFlat).border_color


func test_right_click_on_a_pile_row_opens_the_inspector() -> void:
	var row := await _open_spent()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	row.gui_input.emit(ev)
	await await_idle_frame()
	assert_int(CardInspector.open_count()).is_equal(1)


func test_catalogue_preview_has_no_inspect_button() -> void:
	var s: CardListScreen = auto_free(CardListScreen.new())
	add_child(s)
	await await_idle_frame()
	var texts := []
	_buttons(s, texts)
	assert_array(texts).not_contains(["Inspect"])
