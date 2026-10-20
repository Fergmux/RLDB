extends GdUnitTestSuite
## D7 (owner feedback 20 Oct 2026): the game-over log entry reads "<player> Wins" without the
## reason in brackets; the reason stays on the game_over event (end screen, telemetry).


class Spy:
	extends RefCounted
	var events: Array = []

	func on_core_event(_core, kind: String, data: Dictionary) -> void:
		if kind == "game_over":
			events.append(data)


func _game_over_text(m: MatchEngine) -> String:
	for e in m.log_entries:
		if String(e["pub"]).begins_with("GAME OVER"):
			return String(e["pub"])
	return ""


func test_zero_hp_game_over_log_has_no_reason() -> void:
	var m := TB.make()
	m.end_game(0, "%s reached 0 HP" % m.pname(1))
	assert_str(_game_over_text(m)).is_equal("GAME OVER: %s Wins" % m.pname(0))


func test_game_over_event_still_carries_the_reason() -> void:
	var m := TB.make()
	var spy := Spy.new()
	m.observer = spy
	m.end_game(0, "%s reached 0 HP" % m.pname(1))
	assert_int(spy.events.size()).is_equal(1)
	assert_str(String(spy.events[0]["reason"])).contains("reached 0 HP")
