extends GdUnitTestSuite
## Trap activations must appear in the game log shown on screen for both seats.

func test_trap_activation_appears_in_both_logs() -> void:
	SeriesStore.DIR = "user://test_saves"
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var m: MatchEngine = host.series.game
	while m.turn < 2 or m.phase != "battle":
		m.submit(m.active, {"t": "next_phase"})
	var a := m.active
	var o := 1 - a
	TB.set_card(m, o, 46, 2)                              # Mirror Force
	var att := TB.unit(m, a, TB.WATER, 0, "atk", 8)
	for sl in [1, 2, 3]:
		TB.unit(m, a, TB.WATER, sl, "def")                # Mirror Force needs several attacker units
	TB.unit(m, o, TB.WATER, 0, "def")
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[a])
	host.handle(a, {"t": "attack", "uid": att})
	if m.pending.get("kind", "") == "attack_target":
		host.handle(a, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	assert_str(m.pending.get("kind", "")).is_equal("trap_response")
	await gs.attach(host.seats[o])
	var act := -1
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]).begins_with("Activate"):
			act = i
	host.handle(o, {"t": "choose", "id": m.pending["id"], "indices": [act]})
	await await_idle_frame()
	assert_str(gs.log_label.get_parsed_text()).contains("activates Trap Mirror Force")
	await gs.attach(host.seats[a])
	await await_idle_frame()
	assert_str(gs.log_label.get_parsed_text()).contains("activates Trap Mirror Force")
