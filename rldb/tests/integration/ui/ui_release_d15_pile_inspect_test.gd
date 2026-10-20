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
