extends GdUnitTestSuite
## Behaviour of the Extra Deck cards (Fusion, Ritual, Arcane) changed or added by the 3 November
## 2026 card database (design/card-database-update-2026-11-03.md, "Extra Deck"). Test names carry
## the card id (test_cNNN_...) for the support ledger; shared tests list their ids in an `# @cards`
## comment. Each new effect is tested with its target rules and its no-target case, and each
## removed effect is shown not to run.

const MAGE_WATER := 1
const DRAGON_WATER := 2
const BEAST_WATER := 4
const MONSTER_WATER := 5
const MAGE_LIGHT := 105
const BEAST_LIGHT := 108
const MAGE_FIRE := 110
const DRAGON_FIRE := 111
const MAGE_PHYSICAL := 115
const BEAST_PHYSICAL := 118
const MAGE_EARTH := 120
const MAGE_DARK := 125
const MONSTER_DARK := 129
const MAGE_LIGHTNING := 130
const DRAGON_LIGHTNING := 131
const TAG_TEAM_L := 6                # ordinary unit, cost 1
const KRAKESHIN := 70                # ordinary unit, cost 3
const HYDRA := 27                    # Fire Dragon, cost 2
const FROST_WYVERN := 32             # Water Dragon, cost 2
const DIGGIE := 162                  # can attack directly
const FUSION_CEREMONY := 82
const SACRED_OFFERINGS := 83         # Spell
const MAGIC_CYLINDER := 45           # Trap, cost 1
const MIRROR_FORCE := 46             # Trap, cost 2
const RAZEON := 56
const GEOLOCK := 57
const INFERNOGATE := 58
const SANCTIFIED_BLADE := 61
const LAST_FOUNDATION := 63
const NECROVAST := 64
const CREEPING_NULL := 65
const BASTION_WYRM := 93
const ROMA := 96
const SWORDSMAN := 97
const BAHATIA := 141
const SIMORGH := 143
const AKIRAMARI := 146
const APPARITION := 147
const ULTIMATE_DRAGON := 151
const KAYA := 170
const THUNDERCLAP := 173
const CLIFF := 174
const BOOM := 175
const TRITU := 176
const ILLUSIONIST := 177
const YAMATA := 183
const NECRO := 188
const OWLBEAR := 189
const SNOW_TIGER := 190


func _opts(m: MatchEngine) -> Array:
	return m.pending.get("options", []).map(func(o): return int(o["v"]))


## Puts a unit on the Field as a summon after `fields` are written on its instance, and resolves
## its On Summon triggers (TB.special with a pre-set instance, e.g. Roma's Runes used).
func _special_with(m: MatchEngine, p: int, id: int, slot: int, fields: Dictionary) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	for k in fields:
		m.cards[uid][k] = fields[k]
	m.place_unit(uid, p, slot, "atk")
	m.emit("summoned", {"self": uid, "ctl": p, "player": p})
	m.run()
	return uid


## Fusion Summons `fusion_uid` with Fusion Ceremony from player 0's Field materials `mats`.
func _fuse(m: MatchEngine, fusion_uid: int, mats: Array, zone_label: String) -> String:
	TB.cast(m, 0, FUSION_CEREMONY)
	return CF.finish_fusion(m, fusion_uid, mats, zone_label)


## Adds a this-game ATK/DEF modifier to a unit (its current stats change, its base does not).
func _buff(m: MatchEngine, uid: int, atk: int, def: int) -> void:
	m.cards[uid]["mods"].append({"atk": atk, "def": def, "until": "field", "src": "test"})


## Ends turns until it is player p's turn again (the start-of-turn triggers have resolved).
func _to_turn_of(m: MatchEngine, p: int) -> void:
	CF.end_turn(m)
	if m.active != p:
		CF.end_turn(m)


# ---------------------------------------------------------------- "Unit with 20 or more ATK or DEF"

# @cards 56,57,58,61,93,143,147
func test_unit_with_20_or_more_atk_or_def_material_reads_either_current_stat() -> void:
	var partner_type := {RAZEON: MAGE_LIGHTNING, GEOLOCK: MAGE_EARTH, INFERNOGATE: MAGE_FIRE,
		SANCTIFIED_BLADE: MAGE_LIGHT, BASTION_WYRM: MAGE_PHYSICAL, SIMORGH: MAGE_WATER, APPARITION: MAGE_DARK}
	for fid in partner_type:
		var m := TB.make()
		var partner := TB.unit(m, 0, partner_type[fid], 0)                  # 8/8: never the stat material
		var other := MAGE_FIRE if partner_type[fid] != MAGE_FIRE else MAGE_WATER
		var def20 := TB.unit(m, 0, other, 1, "atk", 4, 20)
		var atk20 := TB.unit(m, 0, other, 2, "atk", 20, 0)
		var low := TB.unit(m, 0, other, 3, "atk", 19, 19)
		var buffed := TB.unit(m, 0, other, 4)                               # 8/8 printed ...
		_buff(m, buffed, 0, 12)                                             # ... 8/20 now
		var name: String = CardDB.get_def(fid)["name"]
		assert_bool(CF.fusion_mats_ok(m, fid, [def20, partner])).override_failure_message("%s DEF 20" % name).is_true()
		assert_bool(CF.fusion_mats_ok(m, fid, [atk20, partner])).override_failure_message("%s ATK 20" % name).is_true()
		assert_bool(CF.fusion_mats_ok(m, fid, [buffed, partner])).override_failure_message("%s current DEF" % name).is_true()
		assert_bool(CF.fusion_mats_ok(m, fid, [low, partner])).override_failure_message("%s 19/19" % name).is_false()
		assert_bool(CF.fusion_mats_ok(m, fid, [def20, atk20])).override_failure_message("%s no Type partner" % name).is_false()


func test_c056_razeon_material_prompt_names_the_new_requirement() -> void:
	var m := TB.make()
	var tall := TB.unit(m, 0, MAGE_WATER, 0, "atk", 2, 24)
	var bolt := TB.unit(m, 0, MAGE_LIGHTNING, 1)
	var razeon := TB.card(m, 0, RAZEON, "extra")
	TB.cast(m, 0, FUSION_CEREMONY)
	TB.choose_uids(m, [razeon])
	assert_str(String(m.pending["prompt"])).contains("a unit with 20 or more ATK or DEF")
	assert_array(CF.offered(m)).contains_exactly([tall])
	assert_str(CF.finish_fusion(m, razeon, [tall, bolt], "Front row, column 1")).is_empty()
	assert_str(CF.zone(m, razeon)).is_equal("unit")


# ---------------------------------------------------------------- Fusion effects

func test_c057_geolock_has_no_on_summon_and_its_new_ability_targets_one_unit() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var other := TB.unit(m, 0, MAGE_FIRE, 2)
	var geo := TB.special(m, 0, GEOLOCK, 0)
	assert_bool(m.pending.is_empty()).is_true()                          # the old optional On Summon is gone
	assert_int(m.status_count(ally, "infiltrate") + m.status_count(ally, "nimble")).is_equal(0)
	assert_str(TB.ability(m, geo, 1)).is_empty()
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "infiltrate")).is_equal(1)
	assert_int(m.status_count(ally, "nimble")).is_equal(1)
	assert_int(m.status_count(other, "nimble")).is_equal(0)
	assert_str(TB.ability(m, geo, 1)).is_equal("Already used this turn.")


func test_c058_infernogate_discards_a_card_then_draws_and_burns_nothing() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	var ig := TB.unit(m, 0, INFERNOGATE, 0)
	var hand: Array = m.players[0]["hand"].duplicate()
	var draw_n: int = m.players[0]["draw"].size()
	assert_str(TB.ability(m, ig)).is_empty()
	assert_array(CF.offered(m)).contains_exactly_in_any_order(hand)
	TB.choose_uids(m, [hand[0]])
	assert_str(CF.zone(m, hand[0])).is_equal("spent")
	assert_int(m.players[0]["hand"].size()).is_equal(hand.size())        # one out, one in
	assert_int(m.players[0]["draw"].size()).is_equal(draw_n - 1)
	assert_int(m.status_count(foe, "burn")).is_equal(0)


func test_c058_infernogate_ability_needs_a_card_in_hand() -> void:
	var m := TB.make()
	var ig := TB.unit(m, 0, INFERNOGATE, 0)
	for h in m.players[0]["hand"].duplicate():
		m.move_to_pile(h, "spent")
	assert_str(TB.ability(m, ig)).is_equal("No legal target.")


func test_c061_sanctified_blade_on_summon_offers_8_medic_to_an_adjacent_ally() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var far := TB.unit(m, 0, MAGE_FIRE, 2)
	TB.unit(m, 1, MAGE_WATER, 0)
	TB.special(m, 0, SANCTIFIED_BLADE, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, ally])      # optional, own adjacent only
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "medic")).is_equal(8)
	assert_int(m.status_count(far, "medic")).is_equal(0)


func test_c061_sanctified_blade_on_summon_can_be_declined() -> void:
	var m := TB.make()
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	TB.special(m, 0, SANCTIFIED_BLADE, 0)
	CF.decline(m)
	assert_int(m.status_count(ally, "medic")).is_equal(0)


func test_c061_sanctified_blade_discards_a_unit_for_one_ap() -> void:
	var m := TB.make()
	var sb := TB.unit(m, 0, SANCTIFIED_BLADE, 0)
	var spell := TB.card(m, 0, SACRED_OFFERINGS)
	var units: Array = m.players[0]["hand"].filter(func(u): return m.is_unit(u))
	assert_str(TB.ability(m, sb)).is_empty()
	var ap := CF.ap(m, 0)
	assert_array(CF.offered(m)).contains_exactly_in_any_order(units)       # the Spell is not offered
	TB.choose_uids(m, [units[0]])
	assert_str(CF.zone(m, units[0])).is_equal("spent")
	assert_str(CF.zone(m, spell)).is_equal("hand")
	assert_int(CF.ap(m, 0)).is_equal(ap + 1)


func test_c061_sanctified_blade_ability_needs_a_unit_in_hand() -> void:
	var m := TB.make()
	var sb := TB.unit(m, 0, SANCTIFIED_BLADE, 0)
	for h in m.players[0]["hand"].duplicate():
		m.move_to_pile(h, "spent")
	TB.card(m, 0, SACRED_OFFERINGS)
	assert_str(TB.ability(m, sb)).is_equal("No legal target.")


func test_c093_bastion_wyrm_fuses_from_a_tall_unit_and_a_physical_unit() -> void:
	var m := TB.make()
	var tall := TB.unit(m, 0, MAGE_WATER, 0, "atk", 20, 4)
	var phys := TB.unit(m, 0, MAGE_PHYSICAL, 1)
	var wyrm := TB.card(m, 0, BASTION_WYRM, "extra")
	assert_str(_fuse(m, wyrm, [tall, phys], "Front row, column 1")).is_empty()
	assert_str(CF.zone(m, wyrm)).is_equal("unit")
	assert_int(m.status_count(wyrm, "eternal")).is_equal(1)
	# The old Beast + Dragon pair no longer qualifies.
	var m2 := TB.make()
	assert_bool(CF.fusion_mats_ok(m2, BASTION_WYRM, [TB.unit(m2, 0, BEAST_WATER, 0), TB.unit(m2, 0, DRAGON_WATER, 1)])).is_false()


func test_c141_bahatia_destroyed_takes_12_atk_def_from_a_unit_of_its_type() -> void:
	var m := TB.make()
	var bah := TB.unit(m, 0, BAHATIA, 0)                                  # Physical
	var foe := TB.unit(m, 1, MAGE_PHYSICAL, 0, "atk", 20, 20)
	TB.kill(m, bah)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, foe])
	TB.choose_uids(m, [foe])
	assert_int(m.atk_of(foe)).is_equal(8)
	assert_int(m.def_of(foe)).is_equal(8)


func test_c143_simorgh_blinds_the_opponent_twice_on_summon() -> void:
	var m := TB.make()
	var foe_a := TB.unit(m, 1, MAGE_WATER, 0)
	var foe_b := TB.unit(m, 1, MAGE_FIRE, 1)
	var ally := TB.unit(m, 0, MAGE_FIRE, 1)
	TB.special(m, 0, SIMORGH, 0)
	assert_int(m.status_count(foe_a, "blind")).is_equal(2)
	assert_int(m.status_count(foe_b, "blind")).is_equal(2)
	assert_int(m.status_count(ally, "blind")).is_equal(0)


func test_c143_simorgh_second_ability_switches_atk_and_def_of_every_unit_this_turn() -> void:
	var m := TB.make()
	var sim := TB.unit(m, 0, SIMORGH, 0)                                  # 26/44
	var foe := TB.unit(m, 1, MAGE_WATER, 0, "atk", 4, 18)
	assert_str(TB.ability(m, sim, 1)).is_empty()
	assert_int(m.atk_of(sim)).is_equal(44)
	assert_int(m.def_of(sim)).is_equal(26)
	assert_int(m.atk_of(foe)).is_equal(18)
	assert_int(m.status_count(foe, "blind")).is_equal(0)                  # the old Blind ability is gone
	CF.end_turn(m)
	assert_int(m.atk_of(foe)).is_equal(4)                                 # until the end of this turn


# ---------------------------------------------------------------- Akiramari

func test_c146_akiramari_needs_three_basic_units() -> void:
	var m := TB.make()
	var b1 := TB.unit(m, 0, MAGE_WATER, 0)
	var b2 := TB.unit(m, 0, MAGE_FIRE, 1)
	var b3 := TB.unit(m, 0, MAGE_PHYSICAL, 2)
	var tt := TB.unit(m, 0, TAG_TEAM_L, 3)
	assert_bool(CF.fusion_mats_ok(m, AKIRAMARI, [b1, b2, b3])).is_true()
	assert_bool(CF.fusion_mats_ok(m, AKIRAMARI, [b1, b2, tt])).is_false()
	assert_bool(CF.fusion_mats_ok(m, AKIRAMARI, [b1, b3])).is_false()      # the old Basic + Physical pair


func test_c146_akiramari_on_summon_searches_any_card_at_one_ap_less_and_heals_no_one() -> void:
	var m := TB.make()
	var b1 := TB.unit(m, 0, MAGE_WATER, 0)
	var b2 := TB.unit(m, 0, MAGE_FIRE, 1)
	var b3 := TB.unit(m, 0, MAGE_PHYSICAL, 2)
	var spell := TB.card(m, 0, SACRED_OFFERINGS, "draw")
	var aki := TB.card(m, 0, AKIRAMARI, "extra")
	assert_str(_fuse(m, aki, [b1, b2, b3], "Front row, column 2")).is_not_equal("fusion flow did not finish")
	assert_str(CF.zone(m, aki)).is_equal("unit")
	assert_bool(-1 in _opts(m)).is_true()                                  # optional
	assert_bool(spell in CF.offered(m)).is_true()                          # any card, not only units
	TB.choose_uids(m, [spell])
	assert_str(CF.zone(m, spell)).is_equal("hand")
	assert_int(m.current_cost(spell)).is_equal(0)                          # printed 1, -1 this turn
	assert_int(m.status_count(aki, "medic")).is_equal(0)                   # the old 5 Medic is gone
	CF.end_turn(m)
	assert_int(m.current_cost(spell)).is_equal(1)


func test_c146_akiramari_summons_a_basic_unit_from_draw_beside_it() -> void:
	var m := TB.make()
	var aki := TB.unit(m, 0, AKIRAMARI, 1)
	TB.unit(m, 0, MAGE_FIRE, 0)
	var not_basic := TB.card(m, 0, KRAKESHIN, "draw")
	assert_str(TB.ability(m, aki)).is_empty()
	var offered := CF.offered(m)
	assert_bool(not_basic in offered).is_false()
	var pick: int = offered[0]
	TB.choose_uids(m, [pick])
	assert_str(String(m.pending.get("kind", ""))).is_equal("slot")
	var slots: Array = m.pending["options"].map(func(o): return int(o["slot"]))
	assert_array(slots).contains_exactly_in_any_order([2, 3, 4, 5])       # its free adjacent zones
	TB.choose(m, ["Back row, column 2"])
	assert_str(CF.zone(m, pick)).is_equal("unit")
	assert_int(int(m.cards[pick]["slot"])).is_equal(4)


func test_c146_akiramari_summon_ability_needs_a_free_adjacent_zone() -> void:
	var m := TB.make()
	var aki := TB.unit(m, 0, AKIRAMARI, 0)
	for s in [1, 3, 4]:
		TB.unit(m, 0, TAG_TEAM_L, s)
	assert_str(TB.ability(m, aki)).is_equal("No free zone in this column.")


func test_c146_akiramari_gains_8_atk_def_per_adjacent_basic_unit_of_yours() -> void:
	var m := TB.make()
	var aki := TB.unit(m, 0, AKIRAMARI, 1)                                # 24/24
	TB.unit(m, 0, MAGE_WATER, 0)
	TB.unit(m, 0, MAGE_FIRE, 5)
	TB.unit(m, 0, TAG_TEAM_L, 2)                                          # adjacent, not Basic
	TB.unit(m, 1, MAGE_WATER, 1)                                          # the opponent's
	assert_int(m.atk_of(aki)).is_equal(40)
	assert_int(m.def_of(aki)).is_equal(40)


# ---------------------------------------------------------------- Demented Apparition

func test_c147_apparition_restricts_unit_attacks_to_itself() -> void:
	var m := CF.p1_battle()
	var app := TB.unit(m, 0, APPARITION, 0)
	var other := TB.unit(m, 0, MAGE_WATER, 1)
	var att := TB.unit(m, 1, MAGE_WATER, 0)
	assert_array(m.attack_targets(att)).contains_exactly([app])
	assert_str(TB.attack(m, att, other)).is_not_empty()


func test_c147_apparition_does_not_restrict_a_direct_attack() -> void:
	var m := CF.p1_battle()
	var app := TB.unit(m, 0, APPARITION, 0)
	TB.unit(m, 0, MAGE_WATER, 1)
	var dig := TB.unit(m, 1, DIGGIE, 0)
	assert_array(m.attack_targets(dig)).contains_exactly_in_any_order([app, -1])
	assert_array(m.attack_modes(dig)).contains_exactly(["unit", "direct"])


func test_c147_protected_apparition_restricts_only_an_attacker_that_can_reach_it() -> void:
	var m := CF.p1_battle()
	var front := TB.unit(m, 0, MAGE_WATER, 0)
	var app := TB.unit(m, 0, APPARITION, 3)                               # protected by `front`
	var side := TB.unit(m, 0, MAGE_FIRE, 1)
	var plain := TB.unit(m, 1, MAGE_WATER, 0)
	var sneak := TB.unit(m, 1, MAGE_FIRE, 1)
	m.apply_status(sneak, "infiltrate", 1)
	assert_array(m.attack_targets(plain)).contains_exactly_in_any_order([front, side])
	assert_array(m.attack_targets(sneak)).contains_exactly([app])


# ---------------------------------------------------------------- Ultimate Dragon

func test_c151_ultimate_dragon_becomes_the_combined_atk_def_of_its_tributes() -> void:
	var m := TB.make()
	var d1 := TB.unit(m, 0, DRAGON_WATER, 0, "atk", 10, 12)
	var d2 := TB.unit(m, 0, DRAGON_FIRE, 1)                              # 8/8
	_buff(m, d2, 6, 0)                                                   # current 14/8 when tributed
	var d3 := TB.unit(m, 0, DRAGON_LIGHTNING, 2, "atk", 4, 20)
	var ud := TB.card(m, 0, ULTIMATE_DRAGON, "extra")
	assert_str(_fuse(m, ud, [d1, d2, d3], "Front row, column 1")).is_empty()
	assert_int(m.atk_of(ud)).is_equal(28)
	assert_int(m.def_of(ud)).is_equal(40)
	assert_str(m.unit_type(ud)).is_equal("")                               # only ATK/DEF are taken


func test_c151_ultimate_dragon_shows_unknown_stats_off_the_field() -> void:
	var m := TB.make()
	var ud := TB.card(m, 0, ULTIMATE_DRAGON, "extra")
	var v := MatchView.card_view(m, ud, 0)
	assert_bool(v["atk"] == null and v["def"] == null).is_true()          # the card shows ?/?
	assert_bool(MatchView.def_view(ULTIMATE_DRAGON)["atk"] == null).is_true()


func test_c151_ultimate_dragon_summoned_without_a_fusion_has_no_tributes_to_add() -> void:
	var m := TB.make()
	var ud := TB.special(m, 0, ULTIMATE_DRAGON, 0)
	assert_int(m.atk_of(ud)).is_equal(0)
	assert_int(m.def_of(ud)).is_equal(0)


# ---------------------------------------------------------------- Necro

func test_c188_necro_materials_are_a_monster_and_a_dark_unit() -> void:
	var m := TB.make()
	var monster := TB.unit(m, 0, MONSTER_WATER, 0)
	var dark := TB.unit(m, 0, MAGE_DARK, 1)
	var mage := TB.unit(m, 0, MAGE_WATER, 2)
	m.apply_status(mage, "burn", 1)
	assert_bool(CF.fusion_mats_ok(m, NECRO, [monster, dark])).is_true()
	assert_bool(CF.fusion_mats_ok(m, NECRO, [dark, mage])).is_false()       # the old Mage + Debuffed pair


# ---------------------------------------------------------------- new cards in the catalogue

# @cards 189,190
func test_new_cards_without_a_sheet_index_sort_last_by_id() -> void:
	var all := CardDB.all()
	var ids: Array = all.map(func(d): return int(d["id"]))
	var unindexed: Array = all.filter(func(d): return d["source"].get("index", null) == null).map(func(d): return int(d["id"]))
	assert_bool(OWLBEAR in unindexed and SNOW_TIGER in unindexed).is_true()
	assert_array(ids.slice(ids.size() - unindexed.size())).is_equal(unindexed)
	var sorted_tail := unindexed.duplicate()
	sorted_tail.sort()
	assert_array(unindexed).is_equal(sorted_tail)
	for i in range(1, all.size() - unindexed.size()):
		assert_bool(float(all[i - 1]["source"]["index"]) <= float(all[i]["source"]["index"])).is_true()


# ---------------------------------------------------------------- Owlbear Druid

func test_c189_owlbear_materials_are_a_beast_and_a_physical_unit() -> void:
	var m := TB.make()
	var beast := TB.unit(m, 0, BEAST_WATER, 0)
	var phys := TB.unit(m, 0, MAGE_PHYSICAL, 1)
	var other := TB.unit(m, 0, MAGE_FIRE, 2)
	var owl := TB.card(m, 0, OWLBEAR, "extra")
	assert_bool(CF.fusion_mats_ok(m, OWLBEAR, [beast, other])).is_false()
	assert_str(_fuse(m, owl, [beast, phys], "Front row, column 1")).is_empty()
	assert_str(CF.zone(m, owl)).is_equal("unit")


func test_c189_owlbear_changes_its_race_then_every_unit_of_yours() -> void:
	var m := TB.make()
	var owl := TB.unit(m, 0, OWLBEAR, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	assert_str(TB.ability(m, owl)).is_empty()
	assert_str(String(m.pending["prompt"])).is_equal("Choose a Race.")
	assert_array(CF.labels(m)).contains_exactly(CardDB.RACES)
	TB.choose(m, ["Dragon"])
	assert_str(m.unit_race(owl)).is_equal("Dragon")
	assert_str(m.unit_race(ally)).is_equal("Dragon")
	assert_str(m.unit_race(foe)).is_equal("Mage")
	# One-shot: a unit summoned later keeps its own Race; the changed ones keep the new Race.
	var later := TB.unit(m, 0, MAGE_FIRE, 2)
	assert_str(m.unit_race(later)).is_equal("Mage")
	TB.kill(m, owl)
	assert_str(m.unit_race(ally)).is_equal("Dragon")


func test_c189_owlbear_race_choice_can_be_cancelled() -> void:
	var m := TB.make()
	var owl := TB.unit(m, 0, OWLBEAR, 0)
	assert_str(TB.ability(m, owl)).is_empty()
	assert_bool(m.pending["cancellable"]).is_true()
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_str(m.unit_race(owl)).is_equal("Mage")
	assert_str(TB.ability(m, owl)).is_empty()                              # not used up


func test_c189_opponents_units_with_owlbears_race_cannot_attack() -> void:
	var m := CF.p1_battle()
	var owl := TB.unit(m, 0, OWLBEAR, 0)                                  # a Mage
	var mage := TB.unit(m, 1, MAGE_WATER, 0)
	var beast := TB.unit(m, 1, BEAST_WATER, 1)
	var own_mage := TB.unit(m, 0, MAGE_FIRE, 1)
	assert_str(m.validate(1, {"t": "attack", "uid": mage})).contains("prevents Mage units")
	assert_str(m.validate(1, {"t": "attack", "uid": beast})).is_empty()
	m.cards[owl]["race_o"] = "Beast"                                      # its current Race counts
	assert_str(m.validate(1, {"t": "attack", "uid": mage})).is_empty()
	assert_str(m.validate(1, {"t": "attack", "uid": beast})).contains("prevents Beast units")
	assert_str(m.attack_locked_reason(own_mage)).is_empty()                 # its own side is free


func test_c189_debilitated_owlbear_locks_no_attack() -> void:
	var m := CF.p1_battle()
	var owl := TB.unit(m, 0, OWLBEAR, 0)
	var mage := TB.unit(m, 1, MAGE_WATER, 0)
	m.apply_status(owl, "debilitate", 1)
	assert_str(m.validate(1, {"t": "attack", "uid": mage})).is_empty()


func test_c189_bot_values_no_attack_for_a_unit_owlbear_locks() -> void:
	var m := CF.p1_battle()
	TB.unit(m, 0, OWLBEAR, 0, "def", null, 2)                             # an easy kill otherwise
	var mage := TB.unit(m, 1, MAGE_WATER, 0)
	var off := BotStance.offense(m, mage)
	assert_float(float(off["value"])).is_equal(0.0)
	assert_str(String(off["why"])).contains("prevents")


# ---------------------------------------------------------------- Snow Tiger Paladin

func test_c190_snow_tiger_materials_are_a_beast_and_a_light_unit() -> void:
	var m := TB.make()
	var beast := TB.unit(m, 0, BEAST_WATER, 0)
	var light := TB.unit(m, 0, MAGE_LIGHT, 1)
	var other := TB.unit(m, 0, BEAST_PHYSICAL, 2)
	assert_bool(CF.fusion_mats_ok(m, SNOW_TIGER, [beast, light])).is_true()
	assert_bool(CF.fusion_mats_ok(m, SNOW_TIGER, [beast, other])).is_false()


func test_c190_snow_tiger_on_summon_calls_a_cheap_unit_from_draw_into_its_column() -> void:
	var m := TB.make()
	var dear := TB.card(m, 0, KRAKESHIN, "draw")                          # cost 3
	TB.special(m, 0, SNOW_TIGER, 0)
	var offered := CF.offered(m)
	assert_bool(-1 in _opts(m)).is_true()                                  # optional
	assert_bool(dear in offered).is_false()
	var pick: int = offered[0]
	TB.choose_uids(m, [pick])
	CF.place(m, "column 1")
	assert_str(CF.zone(m, pick)).is_equal("unit")
	assert_int(int(m.cards[pick]["slot"])).is_equal(3)                   # this column, back row


func test_c190_snow_tiger_protecting_makes_your_traps_cheaper_until_your_next_turn() -> void:
	var m := TB.make()
	TB.unit(m, 0, SNOW_TIGER, 0)
	var behind := TB.unit(m, 0, MAGE_WATER, 3)                            # Snow Tiger protects it
	var cyl := TB.card(m, 0, MAGIC_CYLINDER)
	var mf := TB.card(m, 0, MIRROR_FORCE)
	m.cards[cyl]["st"]["retain"] = 9                                      # keep them in Hand
	m.cards[mf]["st"]["retain"] = 9
	assert_int(m.current_cost(cyl)).is_equal(1)                            # nothing before its turn starts
	_to_turn_of(m, 0)
	assert_int(m.current_cost(cyl)).is_equal(0)
	assert_int(m.current_cost(mf)).is_equal(1)
	assert_str(TB.log_text(m)).contains("Traps cost 1 AP less until the start of their next turn")
	TB.kill(m, behind)                                                    # no longer Protecting
	CF.end_turn(m)
	assert_int(m.current_cost(mf)).is_equal(1)                            # lasts through the opponent's turn
	CF.end_turn(m)
	assert_int(m.current_cost(mf)).is_equal(2)                            # gone at the start of the next


func test_c190_snow_tiger_protected_makes_your_traps_indestructible_until_your_next_turn() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, MAGE_WATER, 0)
	TB.unit(m, 0, SNOW_TIGER, 3)                                          # protected by `front`
	var set_trap := TB.set_card(m, 0, MAGIC_CYLINDER, 0)
	var open_trap := TB.set_card(m, 0, MIRROR_FORCE, 1)
	m.cards[open_trap]["face_up"] = true
	var spell := TB.set_card(m, 0, SACRED_OFFERINGS, 2)
	_to_turn_of(m, 0)
	assert_bool(m.destroy(set_trap, "effect", -1, 1)).is_false()
	assert_bool(m.destroy(open_trap, "effect", -1, 0)).is_false()          # any cause, either player
	assert_str(CF.zone(m, set_trap)).is_equal("backrow")
	assert_str(CF.zone(m, open_trap)).is_equal("backrow")
	assert_bool(m.destroy(spell, "effect", -1, 1)).is_true()               # Traps only
	assert_int(m.current_cost(set_trap)).is_equal(1)                      # not Protecting: no discount
	TB.kill(m, front)                                                     # no longer Protected
	CF.end_turn(m)
	assert_bool(m.destroy(set_trap, "effect", -1, 0)).is_false()          # still the opponent's turn
	CF.end_turn(m)
	assert_bool(m.destroy(set_trap, "effect", -1, 1)).is_true()


func test_c190_snow_tiger_alone_does_not_trigger_at_turn_start() -> void:
	var m := TB.make()
	TB.unit(m, 0, SNOW_TIGER, 0)
	TB.unit(m, 0, MAGE_WATER, 1)                                          # beside it: neither condition
	var trap := TB.set_card(m, 0, MAGIC_CYLINDER, 0)
	_to_turn_of(m, 0)
	assert_str(TB.log_text(m)).not_contains("Snow Tiger Paladin (start of turn)")
	assert_int(m.current_cost(trap)).is_equal(1)
	assert_bool(m.destroy(trap, "effect", -1, 1)).is_true()


# ---------------------------------------------------------------- Ritual

func test_c063_last_foundation_reveal_is_optional() -> void:
	var m := TB.make()
	var trap := TB.set_card(m, 1, MAGIC_CYLINDER, 0)
	TB.special(m, 0, LAST_FOUNDATION, 0)
	assert_str(String(m.pending.get("kind", ""))).is_equal("confirm")
	CF.decline(m)
	assert_int(m.status_count(trap, "reveal")).is_equal(0)
	var m2 := TB.make()
	var trap2 := TB.set_card(m2, 1, MAGIC_CYLINDER, 0)
	TB.special(m2, 0, LAST_FOUNDATION, 0)
	TB.choose(m2, ["Yes"])
	assert_int(m2.status_count(trap2, "reveal")).is_equal(1)


func test_c063_last_foundation_asks_nothing_with_no_spell_or_trap() -> void:
	var m := TB.make()
	TB.special(m, 0, LAST_FOUNDATION, 0)
	assert_bool(m.pending.is_empty()).is_true()


func test_c063_last_foundation_switches_atk_def_of_all_units_once_per_turn() -> void:
	var m := TB.make()
	var lf := TB.unit(m, 0, LAST_FOUNDATION, 0)                            # 12/28
	var foe := TB.unit(m, 1, MAGE_WATER, 0, "atk", 2, 16)
	assert_str(TB.ability(m, lf)).is_empty()
	assert_int(m.atk_of(lf)).is_equal(28)
	assert_int(m.atk_of(foe)).is_equal(16)
	assert_str(TB.ability(m, lf)).is_equal("Already used this turn.")
	CF.end_turn(m)
	assert_int(m.atk_of(foe)).is_equal(2)


func test_c063_last_foundation_destroyed_exhausts_a_card_from_its_controllers_spent() -> void:
	var m := TB.make()
	var lf := TB.unit(m, 0, LAST_FOUNDATION, 0)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	var mine_a := TB.card(m, 0, MAGE_WATER, "spent")
	var mine_b := TB.card(m, 0, SACRED_OFFERINGS, "spent")
	var theirs := TB.card(m, 1, MAGE_WATER, "spent")
	TB.kill(m, lf)
	assert_array(_opts(m)).contains_exactly_in_any_order([mine_a, mine_b])   # mandatory, own Spent, not itself
	TB.choose_uids(m, [mine_b])
	assert_str(CF.zone(m, mine_b)).is_equal("exhaust")
	assert_str(CF.zone(m, theirs)).is_equal("spent")
	assert_str(CF.zone(m, foe)).is_equal("unit")                          # the old lowest-ATK kill is gone


func test_c063_last_foundation_destroyed_with_an_empty_spent_does_nothing() -> void:
	var m := TB.make()
	var lf := TB.unit(m, 0, LAST_FOUNDATION, 0)
	TB.card(m, 1, MAGE_WATER, "spent")
	TB.kill(m, lf)
	assert_bool(m.pending.is_empty()).is_true()
	assert_int(m.players[0]["exhaust"].size() + m.players[1]["exhaust"].size()).is_equal(0)


func test_c064_necrovast_gains_4_per_card_in_exhaust() -> void:
	var m := TB.make()
	var nv := TB.unit(m, 0, NECROVAST, 0)                                 # 22/12
	for i in 3:
		TB.card(m, 0, MAGE_WATER, "exhaust")
	assert_int(m.atk_of(nv)).is_equal(34)
	assert_int(m.def_of(nv)).is_equal(24)


func test_c065_creeping_null_on_summon_rune_is_optional() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	var null_u := TB.special(m, 0, CREEPING_NULL, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, foe, null_u])
	assert_int(m.status_count(foe, "paralyse")).is_equal(0)               # the old Paralyse is gone
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "rune")).is_equal(1)


func test_c065_creeping_null_destroyed_destroys_a_unit_with_a_rune() -> void:
	var m := TB.make()
	var null_u := TB.unit(m, 0, CREEPING_NULL, 0)
	var foe_r := TB.unit(m, 1, MAGE_WATER, 0)
	var own_r := TB.unit(m, 0, MAGE_FIRE, 1)
	var plain := TB.unit(m, 1, MAGE_FIRE, 1)
	m.apply_status(foe_r, "rune", 1)
	m.apply_status(own_r, "rune", 2)
	TB.kill(m, null_u)
	assert_array(_opts(m)).contains_exactly_in_any_order([foe_r, own_r])   # mandatory, either side
	TB.choose_uids(m, [foe_r])
	assert_str(CF.zone(m, foe_r)).is_equal("spent")
	assert_str(CF.zone(m, own_r)).is_equal("unit")
	assert_str(CF.zone(m, plain)).is_equal("unit")


func test_c065_creeping_null_destroyed_with_no_rune_on_the_field_does_nothing() -> void:
	var m := TB.make()
	var null_u := TB.unit(m, 0, CREEPING_NULL, 0)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	TB.kill(m, null_u)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(CF.zone(m, foe)).is_equal("unit")


func test_c096_roma_gains_10_per_rune_used() -> void:
	var m := TB.make()
	var roma := _special_with(m, 0, ROMA, 0, {"runes_used": 3})
	assert_int(m.atk_of(roma)).is_equal(30)
	assert_int(m.def_of(roma)).is_equal(30)


func test_c097_legendary_swordsman_gains_20_atk_while_behind_on_hp() -> void:
	var m := TB.make()
	var sw := TB.unit(m, 0, SWORDSMAN, 0)                                 # 30/30
	assert_int(m.atk_of(sw)).is_equal(30)
	m.players[0]["hp"] = 40
	assert_int(m.atk_of(sw)).is_equal(50)


func test_c183_yamata_poisons_a_unit_in_its_column_instead_of_burning_hp() -> void:
	var m := TB.make()
	var yam := TB.unit(m, 0, YAMATA, 0)
	var in_col := TB.unit(m, 1, MAGE_WATER, 3)
	var off_col := TB.unit(m, 1, MAGE_WATER, 1)
	assert_str(TB.ability(m, yam)).is_empty()
	assert_array(CF.offered(m)).contains_exactly_in_any_order([yam, in_col])
	TB.choose_uids(m, [in_col])
	assert_int(m.status_count(in_col, "poison")).is_equal(6)
	assert_int(m.status_count(off_col, "poison")).is_equal(0)
	var hp1 := CF.hp(m, 1)
	_to_turn_of(m, 0)
	assert_int(CF.hp(m, 1)).is_equal(hp1 - 6)                              # only the Poison's own 6, on their end turn


# ---------------------------------------------------------------- Arcane

func test_c170_kaya_offers_the_discard_only_while_the_opponent_controls_more_cards() -> void:
	var m := TB.make()
	TB.unit(m, 1, MAGE_WATER, 0)                                          # 1 against Kaya's 1
	TB.special(m, 0, KAYA, 0)
	assert_bool(m.pending.is_empty()).is_true()
	var m2 := TB.make()
	TB.unit(m2, 1, MAGE_WATER, 0)
	TB.set_card(m2, 1, MAGIC_CYLINDER, 0)                                 # 2 cards against 1
	TB.special(m2, 0, KAYA, 0)
	var hand: Array = m2.players[0]["hand"].duplicate()
	assert_bool(-1 in _opts(m2)).is_true()
	var ap := CF.ap(m2, 0)
	TB.choose_uids(m2, [hand[0]])
	assert_str(CF.zone(m2, hand[0])).is_equal("spent")
	assert_int(CF.ap(m2, 0)).is_equal(ap + 1)


func test_c173_thunderclap_destroyed_paralyses_everything_then_is_exhausted() -> void:
	var m := TB.make()
	var tc := TB.unit(m, 0, THUNDERCLAP, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	TB.kill(m, tc)
	assert_str(CF.zone(m, tc)).is_equal("exhaust")
	assert_int(m.status_count(ally, "paralyse")).is_equal(1)
	assert_int(m.status_count(foe, "paralyse")).is_equal(1)


func test_c174_cliff_sacrificed_gains_one_more_ap() -> void:
	var m := TB.make()
	var cliff := TB.unit(m, 0, CLIFF, 0)
	var ap := CF.ap(m, 0)
	assert_str(m.submit(0, {"t": "sacrifice", "uid": cliff})).is_empty()
	assert_int(CF.ap(m, 0)).is_equal(ap + 2)                              # +1 sacrifice, +1 Cliff (was +2)


func test_c175_boom_arcane_cost_4_is_paid_exactly() -> void:
	var m := TB.make()
	var boom := TB.card(m, 0, BOOM, "extra")
	assert_int(int(m.extra_cost(boom))).is_equal(4)
	TB.card(m, 0, MAGE_WATER, "spent")
	var hydra := TB.card(m, 0, HYDRA, "spent")
	assert_bool(m.arcane_payable(0, 4)).is_false()                          # 1 + 2 = 3
	assert_str(m.validate(0, {"t": "arcane", "uid": boom})).is_not_empty()
	var wyvern := TB.card(m, 0, FROST_WYVERN, "spent")
	assert_str(m.validate(0, {"t": "arcane", "uid": boom})).is_empty()       # 2 + 2 = 4
	assert_str(m.submit(0, {"t": "arcane", "uid": boom})).is_empty()
	assert_int(int(m.pending["total_required"])).is_equal(4)
	TB.choose_uids(m, [hydra, wyvern])
	TB.choose(m, ["Front row, column 1"])
	assert_str(CF.zone(m, boom)).is_equal("unit")
	assert_str(CF.zone(m, hydra)).is_equal("exhaust")


func test_c176_tritu_stops_adjacent_units_attacking() -> void:
	var m := CF.p1_battle()
	var tritu := TB.unit(m, 1, TRITU, 0, "atk", 10, 10)
	var beside := TB.unit(m, 1, MAGE_WATER, 1)
	var far := TB.unit(m, 1, MAGE_FIRE, 2)
	TB.unit(m, 0, MAGE_WATER, 0)
	assert_str(m.validate(1, {"t": "attack", "uid": beside})).contains("prevents adjacent units")
	assert_str(m.validate(1, {"t": "attack", "uid": far})).is_empty()
	assert_str(m.validate(1, {"t": "attack", "uid": tritu})).is_empty()


func test_c176_tritu_summons_a_water_unit_from_spent_into_its_column() -> void:
	var m := TB.make()
	var tritu := TB.unit(m, 0, TRITU, 1, "atk", 10, 10)
	var ally := TB.unit(m, 0, MAGE_FIRE, 0)
	var water := TB.card(m, 0, MAGE_WATER, "spent")
	TB.card(m, 0, MAGE_FIRE, "spent")
	assert_str(TB.ability(m, tritu)).is_empty()
	assert_array(CF.offered(m)).contains_exactly([water])
	TB.choose_uids(m, [water])
	CF.place(m, "column 2")
	assert_str(CF.zone(m, water)).is_equal("unit")
	assert_int(int(m.cards[water]["slot"])).is_equal(4)
	assert_int(m.status_count(ally, "medic")).is_equal(0)                 # the old Medic is gone


func test_c177_illusionist_gains_20_atk_on_its_turn() -> void:
	var m := TB.make()
	var ill := TB.unit(m, 0, ILLUSIONIST, 0)
	assert_int(m.atk_of(ill)).is_equal(50)
	CF.end_turn(m)
	assert_int(m.atk_of(ill)).is_equal(30)
