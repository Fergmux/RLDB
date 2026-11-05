extends GdUnitTestSuite
## Owner feedback 2026-10-20 re-verification of the 18 Oct fixes.
## B1: Hot Stove answers only an actual Power effect activation (an ability or a triggered effect),
##     never the Power being played, a unit's ability or a summon.
## B2: Traps answering a summon (every Trap with "Summons" in its condition) are offered only after
##     the summoned unit's own On Summon effect has resolved, for every kind of summon.

const HOT_STOVE := 153
const RITUAL_SANCT := 91           # Power, start of your turn: you can apply 1 Rune to a unit
const OPTIONS := 169               # Power, start of your turn: draw a card
const FUSION_LAB := 89             # Power ability: lose 1 AP, Fusion Summon (Field)
const CHAINS := 90                 # Power ability: apply 1 Paralyse to a unit
const SWEEPER := 29                # unit ability: destroy a Trap with Reveal

const TRAP_HOLE := 49
const OVEREXTEND := 48
const ALEXANDERS_ARROW := 103
const DEFCON_2 := 52
const DEFCON_1 := 165
const SUMMON_TRAPS := [TRAP_HOLE, OVEREXTEND, ALEXANDERS_ARROW, DEFCON_2, DEFCON_1]

# Values as of the 3 Nov 2026 card sheet.
const COSMIC_DRAGON := 31          # unit 3 AP 24/16, On Summon: 1 Pierce to itself
const CHIDORI_MONK := 24           # unit 1 AP 16/14, On Summon: 1 Infiltrate to itself
const CREEPING_NULL := 65          # Ritual 3R 36/12, On Summon: you can apply 1 Rune to a unit
const BOOM := 175                  # Arcane 4, On Summon: change the opponent's units' stance
const BASTION_WYRM := 93           # Fusion 20+ ATK-or-DEF unit + Physical unit, On Summon: 1 Eternal to itself
const TAG_TEAM_X := 12             # ability: lose 1 AP, summon a 20-ATK-or-less unit from Spent in this column
const AMBUSH := 42
const BEAST := 4                   # Basic Beast (Water); the tall Bastion Wyrm material at 20 ATK
const DRAGON := 116                # Basic Dragon (Physical): Bastion Wyrm's Physical material
const SUMMONER := 1
const RESPONDER := 0


func _stove_offered(m: MatchEngine) -> bool:
	return TB.pend_kind(m) == "trap_response" and m.pending["options"].any(func(o): return String(o["label"]) == "Activate Hot Stove")


# ---------------------------------------------------------------- B1 Hot Stove

func test_b1_hot_stove_answers_a_start_of_turn_power_effect() -> void:
	for pw_id in [RITUAL_SANCT, OPTIONS]:
		var m := TB.make()                                   # turn 1: player 0
		TB.set_card(m, RESPONDER, HOT_STOVE, 0)
		var pw := TB.power(m, SUMMONER, pw_id, 0)
		TB.unit(m, SUMMONER, TB.WATER, 0)
		m.submit(0, {"t": "next_phase"})
		m.submit(0, {"t": "next_phase"})                     # player 1's start of turn 2
		assert_bool(_stove_offered(m)).override_failure_message("power %d: %s" % [pw_id, m.pending]).is_true()
		TB.choose(m, ["Activate Hot Stove"])
		assert_str(m.cards[pw]["zone"]).is_equal("spent")


func test_b1_hot_stove_answers_a_power_ability_but_not_its_play() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, RESPONDER, HOT_STOVE, 0)
	var foe := TB.unit(m, RESPONDER, TB.WATER, 1)
	var pw := TB.card(m, SUMMONER, CHAINS)
	m.players[SUMMONER]["ap"] = 5
	assert_str(m.submit(SUMMONER, {"t": "power", "uid": pw})).is_empty()
	TB.choose(m, ["Power zone 1"])
	assert_bool(_stove_offered(m)).is_false()                  # played: no window for Hot Stove
	assert_str(m.cards[pw]["zone"]).is_equal("power")
	assert_str(TB.ability(m, pw)).is_empty()
	TB.choose_uids(m, [foe])
	assert_bool(_stove_offered(m)).is_true()                   # its effect activated


func test_b1_hot_stove_ignores_unit_abilities_and_summons() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, RESPONDER, HOT_STOVE, 0)
	var other := TB.set_card(m, RESPONDER, 45, 1)
	m.cards[other]["st"]["reveal"] = 1
	var sw := TB.unit(m, SUMMONER, SWEEPER, 3)
	assert_str(TB.ability(m, sw)).is_empty()
	var seen := false
	for i in 6:
		if m.pending.is_empty():
			break
		seen = seen or _stove_offered(m)
		m.submit(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
	assert_bool(seen).is_false()
	TB.summon(m, SUMMONER, COSMIC_DRAGON, 0)
	assert_bool(_stove_offered(m)).is_false()


func test_b1_hot_stove_answers_fusion_laboratory_but_not_the_fusion_summon() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, RESPONDER, HOT_STOVE, 0)
	var lab := TB.power(m, SUMMONER, FUSION_LAB, 0)
	var b := TB.unit(m, SUMMONER, BEAST, 1, "atk", 20, 8)
	var d := TB.unit(m, SUMMONER, DRAGON, 2)
	var wyrm := TB.card(m, SUMMONER, BASTION_WYRM, "extra")
	assert_str(TB.ability(m, lab)).is_empty()
	for v in [wyrm, b, d, 1]:
		assert_str(m.submit(SUMMONER, {"t": "choose", "id": m.pending["id"], "values": [v]})).is_empty()
	assert_bool(_stove_offered(m)).is_true()                   # the Power's ability
	TB.choose(m, ["Skip"])
	var stove_again := false
	for i in 8:
		if m.pending.is_empty():
			break
		stove_again = stove_again or _stove_offered(m)
		m.submit(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
	assert_bool(stove_again).is_false()                        # the Wyrm's summon / On Summon: not Power effects
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")


# ---------------------------------------------------------------- B2 summon Traps

## A board where every summon Trap can answer player 1's summon: player 0 has a unit (Alexander's
## Arrow) and the Trap set in column 1, low-cost units in Spent (Defcon), and player 1 already has
## two units (Overextend: three or more after the summon).
func _board(trap_id: int) -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, RESPONDER, trap_id, 0)
	TB.unit(m, RESPONDER, TB.WATER, 1, "atk", 8, 8)
	TB.card(m, RESPONDER, TB.WATER, "spent")
	TB.unit(m, SUMMONER, TB.WATER, 4, "def")
	TB.unit(m, SUMMONER, TB.WATER, 5, "def")
	m.players[SUMMONER]["ap"] = 10
	return m


## Answers the summoner's own choices with `answers` (values), then any others with the first
## option, until the responder's summon Trap window opens. Returns true when it opened.
func _to_trap_window(m: MatchEngine, answers: Array) -> bool:
	for i in 20:
		if m.pending.is_empty():
			return false
		if int(m.pending["player"]) == RESPONDER and TB.pend_kind(m) == "trap_response" \
				and m.pending.get("event", {}).get("name", "") == "summon":
			return true
		var pd := m.pending
		if int(pd["player"]) == SUMMONER and not answers.is_empty():
			m.submit(SUMMONER, {"t": "choose", "id": pd["id"], "values": [answers.pop_front()]})
		else:
			m.submit(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": [0]})
	return false


## Starts summon `kind` for player 1; returns {"unit", "answers", "on_summon": Callable(m) -> bool}.
func _start(m: MatchEngine, kind: String) -> Dictionary:
	var foe: int = m.players[RESPONDER]["units"][1]
	match kind:
		"normal":
			var u := TB.card(m, SUMMONER, COSMIC_DRAGON)
			m.submit(SUMMONER, {"t": "summon", "uid": u})
			return {"unit": u, "answers": [0], "on_summon": func(mm): return mm.status_count(u, "pierce") == 1}
		"ritual":
			var mat := TB.unit(m, SUMMONER, BEAST, 0)
			m.apply_status(mat, "rune", 3)
			var r := TB.card(m, SUMMONER, CREEPING_NULL, "extra")
			# 2026-11-03: its On Summon is an optional Rune on a unit (it used to Paralyse); the stance is
			# given up front so the answers reach material, zone, then the Rune target.
			m.submit(SUMMONER, {"t": "ritual", "uid": r, "stance": "atk"})
			return {"unit": r, "answers": [mat, 0, foe], "on_summon": func(mm): return mm.status_count(foe, "rune") == 1}
		"arcane":
			var a := TB.card(m, SUMMONER, 28, "spent")           # cost 2
			var b := TB.card(m, SUMMONER, 32, "spent")           # cost 2: 2 + 2 = Boom's 4 (3 before 3 Nov)
			var boom := TB.card(m, SUMMONER, BOOM, "extra")
			m.submit(SUMMONER, {"t": "arcane", "uid": boom})
			m.submit(SUMMONER, {"t": "choose", "id": m.pending["id"], "values": [a, b]})
			return {"unit": boom, "answers": [0], "on_summon": func(mm): return String(mm.cards[foe]["stance"]) == "def"}
		"fusion":
			var lab := TB.power(m, SUMMONER, FUSION_LAB, 0)
			var bb := TB.unit(m, SUMMONER, BEAST, 0, "atk", 20, 8)
			var dd := TB.unit(m, SUMMONER, DRAGON, 2)
			var wyrm := TB.card(m, SUMMONER, BASTION_WYRM, "extra")
			TB.ability(m, lab)
			return {"unit": wyrm, "answers": [wyrm, bb, dd, 0], "on_summon": func(mm): return mm.status_count(wyrm, "eternal") == 1}
		"effect":
			var tt := TB.unit(m, SUMMONER, TAG_TEAM_X, 3)       # back row, column 1
			# 2026-11-03: Tag Team - X revives only a unit with 20 ATK or less (Cosmic Dragon is 24).
			var cm := TB.card(m, SUMMONER, CHIDORI_MONK, "spent")
			TB.ability(m, tt)
			return {"unit": cm, "answers": [cm, 0], "on_summon": func(mm): return mm.status_count(cm, "infiltrate") == 1}
	return {}


func test_b2_summon_traps_follow_the_on_summon_effect_for_every_summon_kind() -> void:
	var opened := {}
	for trap_id in SUMMON_TRAPS:
		for kind in ["normal", "ritual", "arcane", "fusion", "effect"]:
			var m := _board(trap_id)
			var s := _start(m, kind)
			var answers: Array = s["answers"]
			if not _to_trap_window(m, answers):
				continue
			opened["%d %s" % [trap_id, kind]] = true
			var why := "trap %d, %s summon" % [trap_id, kind]
			assert_str(m.cards[s["unit"]]["zone"]).override_failure_message(why).is_equal("unit")
			assert_bool((s["on_summon"] as Callable).call(m)).override_failure_message("%s: On Summon not resolved before the Trap" % why).is_true()
	# Trap Hole ("If your opponent Summons a Unit") answers every kind of summon.
	for kind in ["normal", "ritual", "arcane", "fusion", "effect"]:
		assert_bool(opened.has("%d %s" % [TRAP_HOLE, kind])).override_failure_message("Trap Hole not offered for a %s summon" % kind).is_true()
	# The cost / ATK / unit-count conditions still hold where they can.
	assert_bool(opened.has("%d normal" % DEFCON_2)).is_true()
	assert_bool(opened.has("%d normal" % DEFCON_1)).is_true()
	assert_bool(opened.has("%d normal" % OVEREXTEND)).is_true()
	assert_bool(opened.has("%d normal" % ALEXANDERS_ARROW)).is_true()


func test_b2_ambush_offers_trap_hole_after_each_unit_lands() -> void:
	var m := TB.make(7, 4)
	TB.to_turn2(m)
	for u in m.players[SUMMONER]["hand"].duplicate():
		m.move_to_pile(u, "spent")
	m.players[SUMMONER]["draw"].clear()
	var a := TB.card(m, SUMMONER, TB.WATER)
	var b := TB.card(m, SUMMONER, BEAST)
	TB.set_card(m, RESPONDER, TRAP_HOLE, 0)
	TB.cast(m, SUMMONER, AMBUSH)
	TB.choose(m, [TB.slot_label(0)])                          # first unit
	assert_str(TB.pend_kind(m)).is_equal("trap_response")    # Trap Hole answers it before the next
	assert_str(m.cards[b]["zone"]).is_equal("hand")
	TB.choose(m, ["Activate Trap Hole"])
	assert_int(m.status_count(a, "paralyse")).is_equal(3)
	assert_str(TB.pend_kind(m)).is_equal("slot")             # then the second unit's zone
	TB.choose(m, [TB.slot_label(1)])
	assert_str(m.cards[b]["zone"]).is_equal("unit")
