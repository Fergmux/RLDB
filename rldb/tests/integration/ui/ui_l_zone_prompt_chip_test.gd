extends GdUnitTestSuite
## L batch follow-up (5 Nov): the turn panel's chip read "Choose a target" during every zone prompt
## (placing a summon, Hypnotise's L9 zone pick). A zone choice now reads "Choose a zone"; a board
## target pick keeps "Choose a target", and a plain choice keeps "Your choice".
## Story: design/owner-feedback-2026-11-05.md L9 (follow-up).

const PIERCE_UNIT := 15     # ability: Apply 1 Pierce to a unit (a board target pick)
const BASIC_UNIT := 1       # a 1-AP unit to summon from Hand
const HYPNOTISE := 180      # Spell: take an opponent's unit, then pick a zone for it (L9)

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var me: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"], "mode": "local"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	me = m.active
	m.players[me]["ap"] = 9
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[me])
	gs.skip_effects()
	await await_idle_frame()


func _refresh() -> void:
	host.broadcast()
	gs.skip_effects()
	await await_idle_frame()
	await await_idle_frame()


func _chip() -> String:
	return gs.sidebar.state_label.text if gs.sidebar.state_chip.visible else ""


func test_summon_zone_prompt_chip_reads_choose_a_zone() -> void:
	# Arrange
	var u := TB.card(m, me, BASIC_UNIT, "hand")
	# Act: summoning from Hand asks for a zone first.
	assert_str(m.submit(me, {"t": "summon", "uid": u})).is_empty()
	await _refresh()
	# Assert
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_str(_chip()).is_equal("Choose a zone")


func test_hypnotise_zone_pick_chip_reads_choose_a_zone() -> void:
	# Arrange: an opponent unit Hypnotise can take.
	TB.unit(m, 1 - me, TB.WATER, 1)
	var h := TB.card(m, me, HYPNOTISE, "hand")
	# Act: cast, take the unit, reach the zone pick.
	assert_str(m.submit(me, {"t": "cast", "uid": h})).is_empty()
	var guard := 0
	while TB.pend_kind(m) != "slot" and not m.pending.is_empty() and guard < 6:
		m.submit(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
		guard += 1
	await _refresh()
	# Assert
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_str(String(m.pending["prompt"])).contains("zone")
	assert_str(_chip()).is_equal("Choose a zone")


func test_board_target_pick_chip_still_reads_choose_a_target() -> void:
	# Arrange
	var u := TB.unit(m, me, PIERCE_UNIT, 0)
	TB.unit(m, 1 - me, TB.WATER, 1)
	await _refresh()
	var act := {}
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "ability" and int(a.get("uid", -1)) == u and a["ok"]:
			act = a
	assert_bool(act.is_empty()).override_failure_message("no Pierce ability offered").is_false()
	# Act
	gs.action_row.run_action(u, act)
	await _refresh()
	# Assert
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_str(_chip()).is_equal("Choose a target")
