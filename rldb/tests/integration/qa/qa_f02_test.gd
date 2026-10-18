extends GdUnitTestSuite
## Adversarial QA of playtest-feedback-02 (design/playtest-feedback-02.md) on the rules side:
## stance-carrying summon commands (F02-02), the authoritative battle preview (F02-12),
## no-legal-target toasts (F02-09) and AP display bookkeeping (F02-06).
## Report: production/qa/qa-f02-adversarial-2026-10-15.md

const LONE_WARRIOR := 38       # Warrior, flag no_buffs
const STEADFAST := 39          # Warrior, battle_immune_30atk
const MBF := 73                # Man's Best Friend: warrior_guard
const ELEMENTAL_MASTERY := 88
const RAGING_INFERNO := 98     # Ritual, 1 Rune
const BAHATIA := 141           # type_summon_lock (Physical)
const MUMENS_BOUNTY := 150     # no_defense
const KAYA := 170              # Arcane, cost 1
const ILLUSIONIST := 177       # no_battle_damage, +20 ATK on own turn


func _battle() -> MatchEngine:
	var m := TB.make()
	TB.p1_battle(m)
	return m


func _state(m: MatchEngine) -> String:
	return var_to_str([m.cards, m.players, m.log_entries, m.pending, m.stack, m.rng.state,
		m.window_queue, m.trigger_queue, m.turn, m.phase, m.winner])


func _opt_preview(m: MatchEngine, target: int) -> Dictionary:
	for o in m.pending.get("options", []):
		if o["v"] == target:
			return o.get("preview", {})
	return {}


## Declares the attack, takes the preview shown on the target option, resolves the battle
## and returns [preview, actual] where actual mirrors the preview's outcome fields.
func _preview_then_battle(m: MatchEngine, a: int, t: int) -> Array:
	var p: int = m.cards[a]["ctl"]
	var q := 1 - p
	var hp_p: int = m.players[p]["hp"]
	var hp_q: int = m.players[q]["hp"]
	# A direct attack with no other target resolves without a prompt (Attack Direct): preview first.
	var pv := m.battle_preview(a, t) if t == -1 else {}
	assert_str(m.submit(p, {"t": "attack", "uid": a})).is_empty()
	if t != -1:
		pv = _opt_preview(m, t)
	assert_bool(pv.is_empty()).override_failure_message("no preview for target").is_false()
	if t != -1:
		TB.choose_uids(m, [t])
	assert_str(TB.pend_kind(m)).is_empty()
	var actual := {"dmg_opp": hp_q - m.players[q]["hp"], "dmg_you": hp_p - m.players[p]["hp"],
		"a_dies": m.cards[a]["zone"] != "unit", "t_dies": t != -1 and m.cards[t]["zone"] != "unit"}
	return [pv, actual]


func _assert_agrees(r: Array, label: String) -> void:
	var pv: Dictionary = r[0]
	var actual: Dictionary = r[1]
	for k in ["dmg_opp", "dmg_you", "a_dies", "t_dies"]:
		assert_that(pv[k]).override_failure_message("%s: preview %s=%s but battle gave %s" % [label, k, pv[k], actual[k]]).is_equal(actual[k])


# ---------------------------------------------------------------- F02-02 stance summons

func test_stance_probe_on_opponents_hidden_card_returns_generic_hand_error() -> void:
	# Arrange: the opponent holds a no_defense unit in their hidden Hand
	var m := TB.make()
	var mine := TB.card(m, 0, TB.WATER)
	var hidden := TB.card(m, 1, MUMENS_BOUNTY)
	var hidden_normal := TB.card(m, 1, TB.WATER)
	# Act: player 0 probes both hidden uids with a stance-carrying summon
	var e_hidden := m.submit(0, {"t": "summon", "uid": hidden, "stance": "def"})
	var e_normal := m.submit(0, {"t": "summon", "uid": hidden_normal, "stance": "def"})
	# Assert: the reply must not depend on the hidden card's identity
	assert_str(e_hidden).is_equal(e_normal)
	assert_str(e_hidden).is_equal("Card is not in your Hand.")
	assert_str(m.cards[mine]["zone"]).is_equal("hand")


func test_stance_field_rejected_on_non_summon_commands_and_bad_values() -> void:
	# Arrange
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	var sp := TB.card(m, 0, 163)
	var before := _state(m)
	# Act / Assert
	for cmd in [{"t": "set", "uid": sp, "stance": "def"}, {"t": "summon", "uid": u, "stance": 1},
			{"t": "summon", "uid": u, "stance": "DEF"}, {"t": "summon", "uid": u, "stance": ""},
			{"t": "summon", "uid": u, "stance": null}, {"t": "summon", "uid": u, "stance": ["def"]}]:
		assert_str(m.submit(0, cmd)).override_failure_message("accepted %s" % str(cmd)).is_not_empty()
	assert_str(_state(m)).is_equal(before)
	for cmd in [{"t": "summon", "uid": u, "stance": ["def"]}, {"t": "summon", "uid": u, "stance": {"a": 1}},
			{"t": "summon", "uid": u, "stance": 0}, {"t": "summon", "uid": u, "stance": "d".repeat(65)}]:
		assert_str(NetSession.sanitize_command(cmd)).is_not_empty()


func test_stance_summon_still_obeys_ap_and_bahatia_type_lock() -> void:
	# Arrange
	var m := TB.make()
	var u := TB.card(m, 0, 115)                        # Basic Mage (Physical)
	TB.unit(m, 1, BAHATIA, 0)
	# Act / Assert: Bahatia locks Physical summons in either stance
	assert_str(m.submit(0, {"t": "summon", "uid": u, "stance": "def"})).contains("Bahatia")
	assert_str(m.submit(0, {"t": "summon", "uid": u, "stance": "atk"})).contains("Bahatia")
	var w := TB.card(m, 0, TB.WATER)
	m.players[0]["ap"] = 0
	assert_str(m.submit(0, {"t": "summon", "uid": w, "stance": "def"})).contains("AP")
	assert_str(m.cards[w]["zone"]).is_equal("hand")


func test_ritual_defense_needs_runes_and_places_in_defense_once() -> void:
	# Arrange
	var m := TB.make()
	var r := TB.card(m, 0, RAGING_INFERNO, "extra")
	# Act / Assert: no material
	assert_str(m.submit(0, {"t": "ritual", "uid": r, "stance": "def"})).contains("Rune")
	var mat := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(mat, "rune", 1)
	var ap0: int = m.players[0]["ap"]
	assert_str(m.submit(0, {"t": "ritual", "uid": r, "stance": "def"})).is_empty()
	TB.choose_uids(m, [mat])
	TB.choose(m, [TB.slot_label(0)])
	while TB.pend_kind(m) != "":
		var pd := m.pending
		assert_str(pd["kind"]).is_not_equal("stance")
		m.submit(pd["player"], {"t": "choose", "id": pd["id"], "indices": [0]})
	assert_str(m.cards[r]["zone"]).is_equal("unit")
	assert_str(m.cards[r]["stance"]).is_equal("def")
	assert_str(m.cards[mat]["zone"]).is_not_equal("unit")
	assert_int(m.players[0]["ap"]).is_equal(ap0)


func test_arcane_defense_exhausts_materials_and_cancel_keeps_everything() -> void:
	# Arrange
	var m := TB.make()
	var k := TB.card(m, 0, KAYA, "extra")
	var s := TB.card(m, 0, TB.WATER, "spent")
	var before := _state(m)
	# Act: cancel at the material choice changes nothing
	assert_str(m.submit(0, {"t": "arcane", "uid": k, "stance": "def"})).is_empty()
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_str(m.cards[k]["zone"]).is_equal("extra")
	assert_str(m.cards[s]["zone"]).is_equal("spent")
	assert_int(m.players[0]["ap"]).is_equal(str_to_var(before)[1][0]["ap"])
	# Act: full Arcane Defense
	assert_str(m.submit(0, {"t": "arcane", "uid": k, "stance": "def"})).is_empty()
	TB.choose_uids(m, [s])
	TB.choose(m, [TB.slot_label(1)])
	# Assert
	assert_str(m.cards[k]["stance"]).is_equal("def")
	assert_str(m.cards[s]["zone"]).is_equal("exhaust")


# ---------------------------------------------------------------- F02-12 battle preview

func test_preview_never_mutates_engine_state_for_any_pair() -> void:
	# Arrange: a busy board with statuses, auras, immunities and hidden cards
	var m := _battle()
	TB.power(m, 1, ELEMENTAL_MASTERY, 0)
	var atk := [TB.unit(m, 1, TB.WATER, 0, "atk", 8), TB.unit(m, 1, ILLUSIONIST, 1), TB.unit(m, 1, TB.FIRE, 2, "atk", 30)]
	m.apply_status(atk[0], "burn", 3)
	m.apply_status(atk[2], "pierce", 1)
	var tg := [TB.unit(m, 0, TB.FIRE, 0, "atk", 10), TB.unit(m, 0, STEADFAST, 1, "def"), TB.unit(m, 0, LONE_WARRIOR, 3, "def"),
		TB.unit(m, 0, MBF, 4)]
	m.apply_status(tg[0], "eternal", 1)
	m.apply_status(tg[1], "curse", 1)
	TB.set_card(m, 0, 163, 0)
	var before := _state(m)
	# Act
	for a in atk:
		for t in tg + [-1]:
			m.battle_preview(a, t)
	# Assert
	assert_str(_state(m)).is_equal(before)


func test_preview_agrees_with_battle_across_cases() -> void:
	var cases := {
		"advantage to attacker": func(m): return [TB.unit(m, 1, TB.WATER, 0, "atk", 8), TB.unit(m, 0, TB.FIRE, 0, "atk", 10)],
		"advantage to defender": func(m): return [TB.unit(m, 1, TB.FIRE, 0, "atk", 10), TB.unit(m, 0, TB.WATER, 0, "atk", 8)],
		"stacked mastery vs defense": func(m):
			TB.power(m, 1, ELEMENTAL_MASTERY, 0)
			TB.power(m, 1, ELEMENTAL_MASTERY, 1)
			return [TB.unit(m, 1, TB.WATER, 0, "atk", 8), TB.unit(m, 0, TB.FIRE, 0, "def", 10, 30)],
		"mastery on defender side": func(m):
			TB.power(m, 0, ELEMENTAL_MASTERY, 0)
			return [TB.unit(m, 1, TB.FIRE, 0, "atk", 20), TB.unit(m, 0, TB.WATER, 0, "atk", 10)],
		"pierce vs defense": func(m):
			var a = TB.unit(m, 1, TB.WATER, 0, "atk", 20)
			m.apply_status(a, "pierce", 1)
			return [a, TB.unit(m, 0, TB.WATER, 0, "def", 0, 5)],
		"no-battle-damage attacker": func(m): return [TB.unit(m, 1, ILLUSIONIST, 0), TB.unit(m, 0, TB.WATER, 0, "atk", 5)],
		"burn on a losing attacker": func(m):
			var a = TB.unit(m, 1, TB.WATER, 0, "atk", 5)
			m.apply_status(a, "burn", 3)
			return [a, TB.unit(m, 0, TB.WATER, 0, "atk", 30)],
		"equal attack trade with eternal attacker": func(m):
			var a = TB.unit(m, 1, TB.WATER, 0, "atk", 10)
			m.apply_status(a, "eternal", 1)
			return [a, TB.unit(m, 0, TB.WATER, 0, "atk", 10)],
		"30+ ATK immunity": func(m): return [TB.unit(m, 1, TB.WATER, 0, "atk", 30), TB.unit(m, 0, STEADFAST, 0, "def")],
		"defense stalemate": func(m): return [TB.unit(m, 1, TB.WATER, 0, "atk", 10), TB.unit(m, 0, TB.WATER, 0, "def", 0, 10)],
		"guarded plain warrior": func(m):
			var t = TB.unit(m, 0, STEADFAST, 0, "def", null, 2)
			TB.unit(m, 0, MBF, 3)
			return [TB.unit(m, 1, TB.WATER, 0, "atk", 20), t],
		"direct attack with burn": func(m):
			var a = TB.unit(m, 1, TB.WATER, 0, "atk", 9)
			m.apply_status(a, "burn", 2)
			return [a, -1],
	}
	for label in cases.keys():
		var m := _battle()
		var pair: Array = cases[label].call(m)
		_assert_agrees(_preview_then_battle(m, pair[0], pair[1]), label)


func test_preview_guarded_lone_warrior_matches_real_battle() -> void:
	# Arrange: Lone Warrior cannot receive Buffs, so Man's Best Friend's Eternal fails
	var m := _battle()
	var t := TB.unit(m, 0, LONE_WARRIOR, 0, "def", null, 10)
	TB.unit(m, 0, MBF, 3)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 40)
	# Act
	var r := _preview_then_battle(m, a, t)
	# Assert: the preview promised protection; the battle must deliver it (or preview must not promise)
	_assert_agrees(r, "Lone Warrior + Man's Best Friend")


func test_preview_guarded_cursed_warrior_matches_real_battle() -> void:
	# Arrange: Curse blocks the Eternal Man's Best Friend applies
	var m := _battle()
	var t := TB.unit(m, 0, STEADFAST, 0, "def", null, 2)
	m.apply_status(t, "curse", 1)
	TB.unit(m, 0, MBF, 3)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	# Act
	var r := _preview_then_battle(m, a, t)
	# Assert
	_assert_agrees(r, "cursed Steadfast + Man's Best Friend")


func test_preview_reaches_only_the_chooser_and_hides_opponent_hand() -> void:
	# Arrange
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	var secret := TB.card(m, 0, LONE_WARRIOR)
	TB.set_card(m, 0, 163, 1)
	# Act
	m.submit(1, {"t": "attack", "uid": a})
	var mine := var_to_str(MatchView.build(m, 1))
	# Assert: neither the hand card nor the set Trap is identified in the attacker's view
	assert_str(mine).not_contains("Lone Warrior")
	assert_str(mine).not_contains("Plan B")
	assert_str(mine).not_contains(str(secret))


# ---------------------------------------------------------------- F02-09 toasts

func test_no_target_toast_from_hidden_source_is_private() -> void:
	# Arrange: an effect whose source is in its owner's Hand (hidden) finds no target
	var m := TB.make()
	var src := TB.card(m, 0, LONE_WARRIOR)
	var seq0: int = m.log_entries[-1]["seq"]
	# Act
	m.push_frame(m.make_frame(src, 0, [{"op": "choose", "sel": {"kind": "unit", "side": "opp"}, "as": "x"}], "Lone Warrior secret"))
	m.run()
	# Assert
	var mine := MatchView.log_for(m, 0, seq0).filter(func(e): return e.get("toast", false))
	var theirs := MatchView.log_for(m, 1, seq0)
	assert_int(mine.size()).is_equal(1)
	assert_int(theirs.size()).is_equal(0)


func test_validation_never_emits_toasts() -> void:
	# Arrange: an ability with no legal target is only checked, never run
	var m := TB.make()
	var n0 := m.log_entries.size()
	# Act
	for p in 2:
		MatchView.build(m, p)
	# Assert
	assert_int(m.log_entries.size()).is_equal(n0)


# ---------------------------------------------------------------- F02-06 AP bookkeeping

func test_ap_peak_tracks_gains_and_resets_on_next_own_turn() -> void:
	# Arrange
	var m := TB.make()
	m.change_ap(0, 3, " (test)")
	m.change_ap(0, -4, " (test)")
	assert_int(m.players[0]["ap_peak"]).is_equal(5)
	# Act: through player 1's turn back to player 0
	TB.to_turn2(m)
	for i in 3:
		m.submit(1, {"t": "next_phase"})
	# Assert
	assert_int(m.active).is_equal(0)
	assert_int(m.players[0]["ap_start"]).is_equal(m.players[0]["ap"])
	assert_int(m.players[0]["ap_peak"]).is_equal(m.players[0]["ap"])
	assert_int(m.players[0]["ap"]).is_equal(2)


func test_ap_sacrifice_refund_raises_peak_and_spend_never_lowers_it() -> void:
	# Arrange
	var m := TB.make()
	TB.to_turn2(m)
	var u := TB.unit(m, 1, TB.WATER, 0)
	var start: int = m.players[1]["ap"]
	# Act
	assert_str(m.submit(1, {"t": "sacrifice", "uid": u})).is_empty()
	var h := TB.card(m, 1, TB.WATER)
	m.submit(1, {"t": "summon", "uid": h, "stance": "atk"})
	TB.choose(m, [TB.slot_label(2)])
	# Assert
	assert_int(m.players[1]["ap_peak"]).is_equal(start + 1)
	assert_int(m.players[1]["ap"]).is_equal(start)
	assert_int(m.players[1]["ap_start"]).is_equal(start)
