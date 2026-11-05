extends GdUnitTestSuite
## G08 (design/playtest-feedback-08.md): the zone-choice arrow of a summon always starts at the
## card being summoned, also after a unit was sacrificed for AP (the bug: it started at front
## zone 2, where the sacrificed unit had been).

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
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()


func _act(uid: int, t: String, stance: String = "") -> void:
	for a in gs.mv.get("actions", []):
		if int(a.get("uid", -1)) == uid and a["t"] == t and a["ok"] and String(a.get("stance", "")) == stance:
			gs.action_row.run_action(uid, a)
			return
	assert_bool(false).override_failure_message("no legal %s action for %d" % [t, uid]).is_true()


func _settle() -> void:
	for _i in 4:
		await await_idle_frame()
	gs.fx.finish_all()
	await await_idle_frame()


func _hand_rect(uid: int) -> Rect2:
	return (gs.hand.items[uid]["holder"] as Control).get_global_rect()


func test_summon_arrow_starts_at_the_hand_card_after_a_sacrifice() -> void:
	var p := m.active
	var sac := TB.unit(m, p, TB.WATER, 1)          # front zone 2
	var h := TB.card(m, p, TB.FIRE)
	m.players[p]["ap"] = 0
	host.broadcast()
	await _settle()
	_act(sac, "sacrifice")
	await _settle()
	assert_str(CF.zone(m, sac)).is_equal("spent")
	_act(h, "summon")
	await _settle()
	assert_str(String(gs.pending().get("kind", ""))).is_equal("slot")
	assert_int(gs.targeting.source_uid()).is_equal(h)
	assert_bool(gs.targeting._source_rect() == _hand_rect(h)).override_failure_message(
		"arrow source %s, hand card %s" % [gs.targeting._source_rect(), _hand_rect(h)]).is_true()


func _slot_rect(slot: int) -> Rect2:
	return gs.fx_slot_global_rect(m.active, "unit", slot)


## The owner's case: a unit in front zone 2 is sacrificed for AP, then an ability summons it
## back from Spent. The arrow used to start at the ability's card (F03-18 source) and, for a
## card that had been on the Field, at the hidden widget still holding its view in zone 2.
func test_summon_from_spent_arrow_starts_at_the_summoned_card_not_the_ability_or_old_zone() -> void:
	var p := m.active
	var sac := TB.unit(m, p, TB.WATER, 1)          # front zone 2
	var ab := TB.unit(m, p, 12, 4)                 # back zone 2: "Pay 2 AP: summon a unit from your Spent in this column"
	m.players[p]["ap"] = 1
	host.broadcast()
	await _settle()
	_act(sac, "sacrifice")
	await _settle()
	assert_int(CF.ap(m, p)).is_equal(2)
	for a in gs.mv.get("actions", []):
		if int(a.get("uid", -1)) == ab and a["t"] == "ability" and a["ok"]:
			gs.action_row.run_action(ab, a)
	await _settle()
	assert_str(TB.pend_kind(m)).is_equal("select")
	TB.choose_uids(m, [sac])
	host.broadcast()
	await _settle()
	assert_str(String(gs.pending().get("kind", ""))).is_equal("slot")
	assert_int(gs.targeting.source_uid()).is_equal(sac)
	var src: Rect2 = gs.targeting._source_rect()
	assert_bool(src.size != Vector2.ZERO).override_failure_message("no arrow source").is_true()
	assert_bool(src == _slot_rect(1)).override_failure_message("arrow starts at the zone the unit left").is_false()
	assert_bool(src == _slot_rect(4)).override_failure_message("arrow starts at the ability's card").is_false()
	var sc: CardWidget = gs.prompt.subject_card
	if sc.is_visible_in_tree():
		assert_int(int(sc.view.get("uid", -1))).is_equal(sac)
		assert_bool(src == sc.get_global_rect()).is_true()
	else:
		assert_bool(src == gs.board.piles[1]["spent"].get_global_rect()).is_true()


## A Fusion summoned by a unit's ability (Aleister in front zone 2): the arrow starts at the
## Fusion unit being placed, not at Aleister.
func test_fusion_by_ability_arrow_starts_at_the_fusion_unit() -> void:
	var p := m.active
	# 2026-11-03 Bastion Wyrm: a unit with 20 or more ATK or DEF + a Physical unit.
	var hydra := TB.unit(m, p, 116, 0)              # Basic Dragon (Physical)
	var guard := TB.unit(m, p, 28, 2)               # Guardian of the Forest, 22 DEF
	var al := TB.unit(m, p, 40, 1)                  # Aleister: Pay 1 AP: Fusion Summon (Field)
	var wyrm := TB.card(m, p, 93, "extra")          # Bastion Wyrm
	m.players[p]["ap"] = 1
	host.broadcast()
	await _settle()
	assert_str(m.submit(p, {"t": "ability", "uid": al, "idx": 0})).is_empty()
	var guard_n := 0
	while TB.pend_kind(m) != "slot" and not m.pending.is_empty() and guard_n < 6:
		guard_n += 1
		var picked := false
		for o in m.pending["options"]:
			if int(o.get("v", -1)) in [wyrm, hydra, guard]:
				TB.choose_uids(m, [int(o["v"])])
				picked = true
				break
		if not picked:
			TB.choose(m, ["Confirm"])
	host.broadcast()
	await _settle()
	assert_str(String(gs.pending().get("kind", ""))).is_equal("slot")
	assert_int(gs.targeting.source_uid()).is_equal(wyrm)
	var src: Rect2 = gs.targeting._source_rect()
	assert_bool(src.size != Vector2.ZERO).is_true()
	assert_bool(src == _slot_rect(1)).override_failure_message("arrow starts at Aleister").is_false()


## Owner feedback 2026-10-18: while Fusion materials are picked, the arrow starts at the Fusion
## unit being summoned (the prompt's card), never at a material, even when the summoning card is
## itself the first material (Tag Team - S).
func test_fusion_material_arrow_starts_at_the_fusion_unit_not_a_material() -> void:
	var p := m.active
	# 2026-11-03 Bastion Wyrm: a unit with 20 or more ATK or DEF + a Physical unit.
	var guard := TB.unit(m, p, 28, 0)               # Guardian of the Forest (22 DEF), front zone 1
	var hydra := TB.unit(m, p, 116, 1)              # Basic Dragon (Physical), front zone 2
	var tt := TB.card(m, p, 8, "hand")              # Tag Team - S: On Summon Fusion (Field)
	var wyrm := TB.card(m, p, 93, "extra")          # Bastion Wyrm
	m.players[p]["ap"] = 3
	host.broadcast()
	await _settle()
	_act(tt, "summon")
	await _settle()
	TB.choose(m, ["Back row, column 1"])
	TB.choose(m, ["Yes"])
	TB.choose_uids(m, [wyrm])
	host.broadcast()
	await _settle()
	for mat in [guard, hydra]:
		assert_str(String(gs.pending().get("prompt", ""))).contains("for the summon of Bastion Wyrm")
		assert_int(gs.targeting.source_uid()).is_equal(wyrm)
		var src: Rect2 = gs.targeting._source_rect()
		assert_bool(src.size != Vector2.ZERO).override_failure_message("no arrow source").is_true()
		for s in [0, 1, 3]:
			assert_bool(src == _slot_rect(s)).override_failure_message("arrow starts at zone %d" % s).is_false()
		TB.choose_uids(m, [mat])
		host.broadcast()
		await _settle()
	assert_str(String(gs.pending().get("kind", ""))).is_equal("slot")
