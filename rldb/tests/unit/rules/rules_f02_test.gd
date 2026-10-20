extends GdUnitTestSuite
## Rules-side support for playtest feedback 02 (design/playtest-feedback-02.md): direct
## stance summons (F02-02), short action labels (F02-04), AP display numbers (F02-06),
## no-target explanations (F02-09) and the authoritative combat preview (F02-12).


func _battle() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	return m


func _actions(m: MatchEngine, p: int, uid: int) -> Array:
	return MatchView.actions_for(m, p).filter(func(a): return a.get("uid", -1) == uid)


func _opt_preview(m: MatchEngine, target: int) -> Dictionary:
	for o in m.pending["options"]:
		if o["v"] == target:
			return o.get("preview", {})
	return {}


# ---------------------------------------------------------------- F02-02

# B3 (owner feedback 2026-10-20) replaced F02-02's Summon Attack / Summon Defense pair with one
# Summon button: the unit enters in Attack stance and To Defense changes it afterwards.

func test_f02_02_hand_unit_offers_one_summon_button() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	var labels := _actions(m, 0, u).map(func(a): return a["label"])
	assert_array(labels).contains_exactly(["Summon"])


func test_f02_02_summon_then_to_defense_pays_once_and_ends_in_defense() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	var ap_before: int = m.players[0]["ap"]
	assert_str(m.submit(0, {"t": "summon", "uid": u})).is_empty()
	assert_str(m.pending["kind"]).is_equal("slot")
	TB.choose(m, [TB.slot_label(1)])
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[u]["stance"]).is_equal("atk")
	assert_str(m.submit(0, {"t": "stance", "uid": u})).is_empty()
	assert_str(m.cards[u]["stance"]).is_equal("def")
	assert_int(m.players[0]["units"][1]).is_equal(u)
	assert_int(m.players[0]["ap"]).is_equal(ap_before - m.current_cost(u))


func test_f02_02_summon_attack_pays_once() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	var ap_before: int = m.players[0]["ap"]
	m.submit(0, {"t": "summon", "uid": u, "stance": "atk"})
	TB.choose(m, [TB.slot_label(0)])
	assert_str(m.cards[u]["stance"]).is_equal("atk")
	assert_int(m.players[0]["ap"]).is_equal(ap_before - m.current_cost(u))
	assert_int(TB.log_text(m).count("pays")).is_equal(1)


func test_f02_02_no_defense_unit_cannot_change_to_defense_after_its_summon() -> void:
	var m := TB.make()
	var u := TB.summon(m, 0, 150, 0)                      # flag no_defense
	assert_str(m.cards[u]["stance"]).is_equal("atk")
	var to_def: Dictionary = _actions(m, 0, u).filter(func(a): return a["t"] == "stance")[0]
	assert_bool(to_def["ok"]).is_false()
	assert_str(to_def["reason"]).contains("Defense")
	assert_str(m.submit(0, {"t": "summon", "uid": TB.card(m, 0, 150), "stance": "def"})).is_equal(MatchEngine.SUMMON_ATTACK_ONLY)


func test_f02_02_cancel_at_zone_choice_refunds_nothing_was_paid() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	var ap_before: int = m.players[0]["ap"]
	m.submit(0, {"t": "summon", "uid": u})
	m.submit(0, {"t": "cancel", "id": m.pending["id"]})
	assert_str(m.cards[u]["zone"]).is_equal("hand")
	assert_int(m.players[0]["ap"]).is_equal(ap_before)


func test_f02_02_summon_stance_still_obeys_timing() -> void:
	var m := _battle()
	var u := TB.card(m, 1, TB.WATER)
	assert_str(m.submit(1, {"t": "summon", "uid": u, "stance": "atk"})).contains("Setup or Recovery Phase")


func test_f02_02_malformed_stance_rejected() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	assert_str(m.submit(0, {"t": "summon", "uid": u, "stance": "sideways"})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "summon", "uid": u, "stance": 5})).is_not_empty()
	assert_str(NetSession.sanitize_command({"t": "summon", "uid": u, "stance": "def"})).is_empty()


## Online regression (2026-10-18): a unit that may attack a unit or directly (Flying Sandworm) sends
## "mode"; the host rejected it as an unknown field, so the joining player could not attack with it.
func test_g07_attack_mode_from_a_remote_client_accepted_and_type_checked() -> void:
	assert_str(NetSession.sanitize_command({"t": "attack", "uid": 7, "mode": "direct"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "attack", "uid": 7, "mode": "unit"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "attack", "uid": 7, "mode": 1})).is_not_empty()


# ---------------------------------------------------------------- F02-04

func test_f02_04_ability_buttons_use_short_labels_full_text_kept() -> void:
	assert_str(CardScripts.short_label("Apply 1 Pierce to a unit")).is_equal("Apply Pierce")
	assert_str(CardScripts.short_label("Apply 7 Frobnicate to a unit")).is_equal("Apply Frobnicate")
	var m := TB.make()
	var found := 0
	var tbl: Dictionary = CardScripts._build()
	for id in tbl.keys():
		var abs: Array = tbl[id].get("abilities", [])
		var views: Array = MatchView.ability_views(abs)
		var shorts: Array = views.map(func(v): return v["short"])
		for v in views:
			assert_int(String(v["short"]).length()).is_less_equal(18)
			found += 1
		# Several abilities on one card stay distinguishable.
		for sh in shorts:
			assert_int(shorts.count(sh)).is_equal(1)
	assert_int(found).is_greater(30)


# ---------------------------------------------------------------- F02-06

func test_f02_06_ap_start_and_peak_tracked_for_display() -> void:
	var m := TB.make()
	var pv: Dictionary = MatchView.build(m, 0)["players"][0]
	assert_int(pv["ap_start"]).is_equal(m.players[0]["ap"])
	assert_int(pv["ap_peak"]).is_equal(m.players[0]["ap"])
	m.change_ap(0, 2, " (test)")
	pv = MatchView.build(m, 0)["players"][0]
	assert_int(pv["ap_peak"]).is_equal(pv["ap_start"] + 2)
	m.change_ap(0, -3, " (test)")
	pv = MatchView.build(m, 0)["players"][0]
	assert_int(pv["ap_peak"]).is_equal(pv["ap_start"] + 2)
	assert_int(pv["ap"]).is_equal(pv["ap_start"] - 1)


func test_f02_06_abyss_start_allowance_is_three() -> void:
	var m := TB.make()
	TB.power(m, 1, 149, 0)                                # Marked by the Abyss
	TB.card(m, 1, TB.WATER, "exhaust")
	TB.to_turn2(m)
	assert_int(m.players[1]["ap_start"]).is_equal(3)


# ---------------------------------------------------------------- F02-09

func test_f02_09_triggered_effect_without_target_logs_toast() -> void:
	var m := TB.make()
	TB.summon(m, 0, 19, 0)                                # On Summon: opponent unit in this column
	var hit := m.log_entries.filter(func(e): return e.get("toast", false))
	assert_int(hit.size()).is_equal(1)
	assert_str(String(hit[0]["pub"])).contains("no legal target")
	var seen := MatchView.log_for(m, 1).filter(func(e): return e.get("toast", false))
	assert_int(seen.size()).is_equal(1)                   # source is public: opponent sees it too


# ---------------------------------------------------------------- F02-12

func test_f02_12_preview_water_8_vs_fire_atk_10_shows_14_vs_10() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	var t := TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	m.submit(1, {"t": "attack", "uid": a})
	var pv := _opt_preview(m, t)
	assert_int(pv["av"]).is_equal(14)
	assert_int(pv["dv"]).is_equal(10)
	assert_str(pv["adv"]).is_equal("attacker")
	assert_str(pv["outcome"]).is_equal("win")
	assert_str(pv["verdict"]).is_equal("good")
	assert_int(pv["dmg_opp"]).is_equal(4)


func test_f02_12_reverse_attack_adjusts_defending_water() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.FIRE, 0, "atk", 10)
	var t := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	m.submit(1, {"t": "attack", "uid": a})
	var pv := _opt_preview(m, t)
	assert_int(pv["av"]).is_equal(10)
	assert_int(pv["dv"]).is_equal(14)
	assert_str(pv["adv"]).is_equal("defender")
	assert_str(pv["verdict"]).is_equal("bad")
	assert_int(pv["dmg_you"]).is_equal(4)


func test_f02_12_preview_uses_stacked_elemental_mastery() -> void:
	var m := _battle()
	TB.power(m, 1, 88, 0)
	TB.power(m, 1, 88, 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	var t := TB.unit(m, 0, TB.FIRE, 0, "def", 10, 30)
	m.submit(1, {"t": "attack", "uid": a})
	var pv := _opt_preview(m, t)
	assert_int(pv["bonus"]).is_equal(18)                   # 6 + 6 per Elemental Mastery (2026-10-18)
	assert_int(pv["av"]).is_equal(26)
	assert_bool(pv["defending_atk"]).is_false()
	assert_int(pv["dv"]).is_equal(30)


func test_f02_12_equal_attack_is_trade_and_defense_tie_is_stalemate() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var t1 := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	var t2 := TB.unit(m, 0, TB.WATER, 1, "def", 0, 10)
	m.submit(1, {"t": "attack", "uid": a})
	assert_str(_opt_preview(m, t1)["outcome"]).is_equal("trade")
	assert_str(_opt_preview(m, t1)["verdict"]).is_equal("neutral")
	assert_str(_opt_preview(m, t2)["outcome"]).is_equal("stalemate")
	assert_str(_opt_preview(m, t2)["verdict"]).is_equal("neutral")


func test_f02_12_eternal_target_is_not_a_simple_win() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	var t := TB.unit(m, 0, TB.WATER, 0, "def", 0, 5)
	m.apply_status(t, "eternal", 1)
	m.submit(1, {"t": "attack", "uid": a})
	var pv := _opt_preview(m, t)
	assert_bool(pv["t_dies"]).is_false()
	assert_str(pv["verdict"]).is_equal("neutral")
	assert_str(" ".join(pv["notes"])).contains("Eternal")


func test_f02_12_preview_flags_hidden_traps_and_matches_real_battle() -> void:
	var m := _battle()
	TB.set_card(m, 0, 46, 2)                              # a face-down card the attacker cannot see
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	var t := TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	m.submit(1, {"t": "attack", "uid": a})
	var pv := _opt_preview(m, t)
	assert_bool(pv["hidden_risk"]).is_true()
	# Preview is presentation only: building it changed nothing.
	assert_int(m.atk_of(a)).is_equal(8)
	assert_int(m.atk_of(t)).is_equal(10)
	TB.choose_uids(m, [t])
	if TB.pend_kind(m) == "trap_response":
		TB.choose(m, ["Pass"])
	assert_int(m.players[0]["hp"]).is_equal(60 - pv["dmg_opp"])
	assert_str(m.cards[t]["zone"]).is_not_equal("unit")


func test_f02_12_preview_visible_only_to_chooser() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	m.submit(1, {"t": "attack", "uid": a})
	var mine: Dictionary = MatchView.build(m, 1)["pending"]
	var theirs: Dictionary = MatchView.build(m, 0)["pending"]
	assert_bool(mine["options"][0].has("preview")).is_true()
	assert_bool(theirs.has("options")).is_false()


# ---------------------------------------------------------------- No auto-pick / target-first (user decision 2026-10-15)

func test_mandatory_single_target_effect_still_prompts() -> void:
	var m := TB.make()
	var ch := TB.power(m, 0, 90)                         # Chains of Binding: paralyse a foe
	var foe := TB.unit(m, 1, TB.WATER, 0)
	assert_str(TB.ability(m, ch)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_int(m.pending["options"].size()).is_equal(1)
	assert_int(m.status_count(foe, "paralyse")).is_equal(0)   # nothing happens until the player picks
	assert_str(TB.choose_uids(m, [foe])).is_empty()
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)


func test_ability_cancelled_at_target_step_spends_and_logs_nothing() -> void:
	var m := TB.make()
	var dm := TB.unit(m, 0, 15, 0)                       # Da Mage: once-per-turn "apply Pierce to a unit"
	m.players[0]["ap"] = 5
	var ap_before: int = m.players[0]["ap"]
	var hp_before: int = m.players[0]["hp"]
	var log_before: int = m.log_entries.size()
	assert_str(m.submit(0, {"t": "ability", "uid": dm, "idx": 0})).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("select")       # target is asked before any cost
	assert_int(m.players[0]["ap"]).is_equal(ap_before)
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.players[0]["ap"]).is_equal(ap_before)
	assert_int(m.players[0]["hp"]).is_equal(hp_before)
	assert_bool(m.cards[dm]["opt"].has(0)).is_false()    # once-per-turn not consumed
	for e in m.log_entries.slice(log_before):
		assert_str(String(e["pub"])).is_empty()             # no public activation line (only the private "Cancelled")
	assert_int(m.status_count(dm, "pierce")).is_equal(0)
	assert_str(m.validate(0, {"t": "ability", "uid": dm, "idx": 0})).is_empty()


func test_only_direct_target_is_labelled_attack_direct_and_needs_no_prompt() -> void:
	var m := _battle()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)       # opponent has no units: direct is the only target
	var labels := _actions(m, 1, a).map(func(x): return x["label"])
	assert_bool("Attack Direct" in labels).is_true()
	assert_bool("Attack" in labels).is_false()
	assert_str(m.submit(1, {"t": "attack", "uid": a})).is_empty()
	assert_bool(m.pending.get("kind", "") == "attack_target").is_false()
	assert_int(m.players[0]["hp"]).is_equal(48)
