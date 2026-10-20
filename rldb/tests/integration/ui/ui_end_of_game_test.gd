extends GdUnitTestSuite
## Owner feedback 22 Oct (design/owner-feedback-2026-10-22.md J9 J10 J13 J15), on the real GameScreen bound
## to a local host: the in-game menu order, the end of a game (no input once the kill is made, the kill plays
## out, nothing left over the rewards screen) and the rewards screen's full-window dim under the top strip.
## The windowed evidence run is src/dev/eog_shots.gd.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 3, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()


func after_test() -> void:
	StatusTip.hide_all()


## Visible in-game menu buttons, top to bottom, by key.
func _menu_order() -> Array:
	var out := []
	for c in (gs.menu.game_menu as HousePanel).body.get_children():
		if c is Button and (c as Button).visible:
			out.append(String(c.name).trim_prefix("Menu_"))
	return out


func test_j13_concede_game_comes_below_return_to_menu() -> void:
	# Arrange: a local player's menu (Settings, Return, Concede, Quit)
	gs.menu.refresh_items()
	# Act
	var order := _menu_order()
	# Assert
	assert_array(order).contains_exactly(["settings", "return", "concede", "quit"])
