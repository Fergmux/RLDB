extends GdUnitTestSuite
## Behaviour of the main-deck cards (Units, Spells, Traps, Powers) changed or added by the 3 November
## 2026 card database (design/card-database-update-2026-11-03.md, "Main deck"). Test names carry the
## card id (test_cNNN_...) for the support ledger; shared tests list their ids in an `# @cards`
## comment. Each new number is tested at its boundary, each new effect with its target rules and its
## no-target case, and each removed effect is shown not to run.

const MAGE_WATER := 1                # Basic Mage (Water) 8/8, cost 1
const DRAGON_WATER := 2              # Basic Dragon (Water)
const MAGE_FIRE := 110               # Basic Mage (Fire)
const DRAGON_FIRE := 111             # Basic Dragon (Fire)
const MONSTER_DARK := 129            # Basic Monster (Dark)
const TAG_TEAM_X := 12
const DA_MAGE := 15
const SHEN := 21
const AURIC := 23
const COSMIC_DRAGON := 31            # 24/16, cost 3; On Summon: 1 Pierce on itself
const SOLOMON := 37                  # 20/14
const MAGIC_CYLINDER := 45
const DAMAGE_CONVERSION := 47
const VOID_BASILISK := 67            # Dragon / Dark
const SEPPUKU := 68
const MAGENTRIC := 69
const KRAKESHIN := 70
const MYTH_WUKONG := 72
const SOUL_DEVOURER := 76
const RADABLAST := 77
const FUSION_CEREMONY := 82          # Spell: Fusion Summon using units you control
const ASSASSINATE := 84
const SHARED_FATE := 87
const ABYSSLORD := 59                # Fusion: Mage + Water (its materials do not change on 3 Nov)
const MIRRORFLESH := 94              # Fusion: a unit with a Type + a unit of the same Type
const NECROVAST := 64                # Ritual, 2 Runes
const DRAGON_RIDER := 135
const SYMBIOTE_SPAWN := 155
const SYMBIOTE_LARVA := 156
const SYMBIOTE_SIPHONOPHORE := 157
const SAVIOUR_DEFCON_1 := 165
const REINFORCEMENTS := 178
const TYRANTS_LANTERN := 179
const HYPNOTISE := 180
const SHIMMER_SERUM := 182
const DO_NOT_OPEN_BOX := 191
const SACRED_OFFERINGS := 83         # Spell, used as a plain set card
const SABOTEURS_GUILD := 166         # Power


func _opts(m: MatchEngine) -> Array:
	return m.pending.get("options", []).map(func(o): return int(o["v"]))


func _slots(m: MatchEngine) -> Array:
	return m.pending.get("options", []).map(func(o): return int(o.get("slot", -1)))


## Answers the remaining zone / stance prompts of a summon in progress.
func _place(m: MatchEngine, slot: int, stance: String = "Attack") -> void:
	if TB.pend_kind(m) == "slot":
		TB.choose(m, [TB.slot_label(slot)])
	if TB.pend_kind(m) == "stance":
		TB.choose(m, [stance])


# ---------------------------------------------------------------- 12 Tag Team - X

func test_c012_tag_team_x_revives_only_a_20_atk_or_less_unit_for_one_ap() -> void:
	var m := TB.make()
	var x := TB.unit(m, 0, TAG_TEAM_X, 0)
	var solomon := TB.card(m, 0, SOLOMON, "spent")            # 20 ATK: the boundary is included
	var cosmic := TB.card(m, 0, COSMIC_DRAGON, "spent")       # 24 ATK: too strong
	m.players[0]["ap"] = 3
	assert_str(m.submit(0, {"t": "ability", "uid": x, "idx": 0})).is_empty()
	assert_array(_opts(m)).contains_exactly([solomon])
	assert_bool(cosmic in _opts(m)).is_false()
	TB.choose_uids(m, [solomon])
	_place(m, 3)
	assert_int(m.cards[solomon]["slot"]).is_equal(3)
	assert_int(CF.ap(m, 0)).is_equal(2)                       # it costs 1 AP (was 2)


func test_c012_tag_team_x_ability_label_quotes_one_ap_and_20_atk() -> void:
	var ab: Dictionary = CardScripts.get_entry(TAG_TEAM_X)["abilities"][0]
	assert_int(int(ab["cost"]["ap"])).is_equal(1)
	assert_str(String(ab["label"])).contains("Lose 1 AP")
	assert_str(String(ab["label"])).contains("20 ATK or less")
	assert_str(CardScripts.short_label(String(ab["label"]))).is_equal("Revive (1 AP)")


func test_c012_tag_team_x_with_one_ap_and_no_small_unit_in_spent_cannot_revive() -> void:
	var m := TB.make()
	var x := TB.unit(m, 0, TAG_TEAM_X, 0)
	TB.card(m, 0, COSMIC_DRAGON, "spent")
	m.players[0]["ap"] = 1
	assert_str(m.validate(0, {"t": "ability", "uid": x, "idx": 0})).is_equal("No legal target.")


# ---------------------------------------------------------------- tribute benefits (15, 69, 77)

## Ritual-summons Necrovast by tributing `mat` (given 2 Runes); returns Necrovast's uid.
func _ritual_with(m: MatchEngine, mat: int) -> int:
	m.apply_status(mat, "rune", 2)
	var nec := TB.card(m, 0, NECROVAST, "extra")
	assert_str(m.submit(0, {"t": "ritual", "uid": nec, "stance": "atk"})).is_empty()
	TB.choose_uids(m, [mat])
	TB.choose(m, ["Front row, column 1"])
	if TB.pend_kind(m) == "stance":
		TB.choose(m, ["Attack"])
	assert_str(CF.zone(m, nec)).is_equal("unit")
	return nec


func test_c015_da_mage_tributed_gives_the_ritual_unit_one_pierce() -> void:
	var m := TB.make()
	var nec := _ritual_with(m, TB.unit(m, 0, DA_MAGE, 0))
	assert_int(m.status_count(nec, "pierce")).is_equal(1)


func test_c015_da_mage_tributed_for_a_fusion_gives_it_one_pierce() -> void:
	var m := TB.make()
	var da := TB.unit(m, 0, DA_MAGE, 0)                       # Mage
	var water := TB.unit(m, 0, MAGE_WATER, 1)                 # Water
	var lord := TB.card(m, 0, ABYSSLORD, "extra")
	TB.cast(m, 0, FUSION_CEREMONY)
	assert_str(CF.finish_fusion(m, lord, [da, water], "Front row, column 1")).is_empty()
	assert_str(CF.zone(m, lord)).is_equal("unit")
	assert_int(m.status_count(lord, "pierce")).is_equal(1)


func test_c069_magentric_tributed_gives_one_cleanse_and_no_pierce() -> void:
	var m := TB.make()
	var nec := _ritual_with(m, TB.unit(m, 0, MAGENTRIC, 0))
	assert_int(m.status_count(nec, "cleanse")).is_equal(1)
	assert_int(m.status_count(nec, "pierce")).is_equal(0)


func test_c069_magentric_on_summon_cleanse_on_an_adjacent_unit_is_optional() -> void:
	var m := TB.make()
	var friend := TB.unit(m, 0, MAGE_WATER, 1)
	TB.unit(m, 1, MAGE_WATER, 0)                              # an opposing unit is never adjacent
	TB.summon(m, 0, MAGENTRIC, 0)
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, friend])
	TB.choose_uids(m, [friend])
	assert_int(m.status_count(friend, "cleanse")).is_equal(1)
	assert_int(m.status_count(friend, "pierce")).is_equal(0)
	var m2 := TB.make()
	var friend2 := TB.unit(m2, 0, MAGE_WATER, 1)
	TB.summon(m2, 0, MAGENTRIC, 0)
	CF.decline(m2)
	assert_int(m2.status_count(friend2, "cleanse")).is_equal(0)


func test_c077_radablast_tributed_gives_the_ritual_unit_one_infiltrate() -> void:
	var m := TB.make()
	var nec := _ritual_with(m, TB.unit(m, 0, RADABLAST, 0))
	assert_int(m.status_count(nec, "infiltrate")).is_equal(1)


# ---------------------------------------------------------------- 21 Shen

func test_c021_shen_makes_each_unit_the_opponent_summons_lose_10_atk_for_good() -> void:
	var m := CF.p1_main()
	TB.unit(m, 0, SHEN, 1)
	var cosmic := TB.summon(m, 1, COSMIC_DRAGON, 0)           # 24 ATK
	assert_int(m.atk_of(cosmic)).is_equal(14)
	CF.end_turn(m)                                            # "Permanently": not until end of turn
	assert_int(m.atk_of(cosmic)).is_equal(14)


func test_c021_shen_also_weakens_an_opponents_fusion_summon() -> void:
	var m := CF.p1_main()
	TB.unit(m, 0, SHEN, 1)
	var mage := TB.unit(m, 1, MAGE_WATER, 0)
	var water := TB.unit(m, 1, MAGE_WATER, 1)
	var lord := TB.card(m, 1, ABYSSLORD, "extra")
	TB.cast(m, 1, FUSION_CEREMONY)
	assert_str(CF.finish_fusion(m, lord, [mage, water], "Front row, column 1")).is_empty()
	assert_int(m.atk_of(lord)).is_equal(int(CardDB.get_def(ABYSSLORD)["atk"]) - 10)


func test_c021_shen_spares_its_own_controllers_summons() -> void:
	var m := TB.make()
	TB.unit(m, 0, SHEN, 1)
	var cosmic := TB.summon(m, 0, COSMIC_DRAGON, 0)
	assert_int(m.atk_of(cosmic)).is_equal(24)


func test_c021_debilitated_shen_does_not_weaken_summons() -> void:
	var m := CF.p1_main()
	var shen := TB.unit(m, 0, SHEN, 1)
	m.apply_status(shen, "debilitate", 1)
	var cosmic := TB.summon(m, 1, COSMIC_DRAGON, 0)
	assert_int(m.atk_of(cosmic)).is_equal(24)


# ---------------------------------------------------------------- 23 Auric

func test_c023_auric_takes_8_damage_to_gain_8_atk_permanently() -> void:
	var m := TB.make()
	var auric := TB.unit(m, 0, AURIC, 0)
	assert_str(TB.ability(m, auric)).is_empty()
	TB.choose(m, ["permanently gains +8 ATK"])
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP - 8)
	assert_int(m.atk_of(auric)).is_equal(30 + 8)
	CF.end_turn(m)
	assert_int(m.atk_of(auric)).is_equal(38)
	var ab: Dictionary = CardScripts.get_entry(AURIC)["abilities"][0]
	assert_str(String(ab["label"])).is_equal("Take 8 Damage: +8 ATK or destroy a Spell/Trap")
	assert_str(CardScripts.short_label(String(ab["label"]))).is_equal("Blood Price")


func test_c023_auric_takes_8_damage_to_destroy_a_spell_trap() -> void:
	var m := TB.make()
	var auric := TB.unit(m, 0, AURIC, 0)
	var foe_set := TB.set_card(m, 1, SACRED_OFFERINGS, 2)
	TB.ability(m, auric)
	TB.choose(m, ["Destroy a Spell/Trap"])
	TB.choose_uids(m, [foe_set])
	assert_str(CF.zone(m, foe_set)).is_equal("spent")
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP - 8)


# ---------------------------------------------------------------- 31 Cosmic Dragon

func test_c031_cosmic_dragon_destroyed_applies_6_medic() -> void:
	var m := TB.make()
	var cosmic := TB.unit(m, 0, COSMIC_DRAGON, 0)
	var ally := TB.unit(m, 0, MAGE_WATER, 1)
	TB.kill(m, cosmic)
	assert_str(String(m.pending["prompt"])).contains("6 Medic")
	TB.choose_uids(m, [ally])
	assert_int(m.status_count(ally, "medic")).is_equal(6)


# ---------------------------------------------------------------- 37 Solomon, the Captain

func test_c037_solomon_gains_8_atk_only_while_protecting_a_unit() -> void:
	var m := TB.make()
	var sol := TB.unit(m, 0, SOLOMON, 0)
	assert_int(m.atk_of(sol)).is_equal(20)                    # alone in front: protects nobody
	var behind := TB.unit(m, 0, MAGE_WATER, 3)
	assert_int(m.atk_of(sol)).is_equal(28)                    # shields the unit behind it
	TB.kill(m, behind)
	assert_int(m.atk_of(sol)).is_equal(20)
	var m2 := TB.make()
	var sol2 := TB.unit(m2, 0, SOLOMON, 3)
	TB.unit(m2, 0, MAGE_WATER, 0)                             # protected by a unit: no longer rewarded
	assert_int(m2.atk_of(sol2)).is_equal(20)


# ---------------------------------------------------------------- 45 / 47 column traps

## Player 1's Battle Phase with player 0's `trap_id` set in column `col`.
func _column_trap(trap_id: int, col: int) -> Array:
	var m := CF.p1_battle()
	var trap := TB.set_card(m, 0, trap_id, col)
	return [m, trap]


# @cards 45,47
func test_c045_c047_column_traps_answer_an_attacker_in_their_column_whatever_its_target() -> void:
	for id in [MAGIC_CYLINDER, DAMAGE_CONVERSION]:
		var mt := _column_trap(id, 0)
		var m: MatchEngine = mt[0]
		var a := TB.unit(m, 1, MAGE_WATER, 0, "atk", 12)      # attacker in column 1
		var far := TB.unit(m, 0, MAGE_WATER, 2)               # its target in column 3
		TB.attack(m, a, far)
		assert_bool(CF.labels(m).has("Activate " + CardDB.get_def(id)["name"])).override_failure_message(str(id)).is_true()


# @cards 45,47
func test_c045_c047_column_traps_answer_a_direct_attack_from_their_column() -> void:
	for id in [MAGIC_CYLINDER, DAMAGE_CONVERSION]:
		var mt := _column_trap(id, 1)
		var m: MatchEngine = mt[0]
		var a := TB.unit(m, 1, MAGE_WATER, 1, "atk", 12)      # no defenders: a direct attack
		TB.attack(m, a, -1)
		assert_bool(CF.labels(m).has("Activate " + CardDB.get_def(id)["name"])).override_failure_message(str(id)).is_true()


# @cards 45,47
func test_c045_c047_column_traps_ignore_an_attacker_in_another_column() -> void:
	for id in [MAGIC_CYLINDER, DAMAGE_CONVERSION]:
		var mt := _column_trap(id, 0)
		var m: MatchEngine = mt[0]
		var a := TB.unit(m, 1, MAGE_WATER, 1, "atk", 12)      # attacker in column 2
		var near := TB.unit(m, 0, MAGE_WATER, 0)              # attacks the unit in the Trap's column
		TB.attack(m, a, near)
		assert_bool(CF.labels(m).has("Activate " + CardDB.get_def(id)["name"])).override_failure_message(str(id)).is_false()


func test_c045_magic_cylinder_on_a_direct_attack_deals_the_attackers_atk() -> void:
	var mt := _column_trap(MAGIC_CYLINDER, 2)
	var m: MatchEngine = mt[0]
	var a := TB.unit(m, 1, MAGE_WATER, 2, "atk", 12)
	TB.attack(m, a, -1)
	TB.choose(m, ["Activate Magic Cylinder"])
	assert_int(CF.hp(m, 1)).is_equal(GameCore.START_HP - 12)
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP - 12)  # the attack still goes through
	assert_int(m.current_cost(mt[1])).is_equal(2)


func test_c047_damage_conversion_costs_one_and_heals_by_the_attackers_atk() -> void:
	assert_int(int(CardDB.get_def(DAMAGE_CONVERSION)["cost"])).is_equal(1)
	var mt := _column_trap(DAMAGE_CONVERSION, 0)
	var m: MatchEngine = mt[0]
	var a := TB.unit(m, 1, MAGE_WATER, 0, "atk", 12)
	var far := TB.unit(m, 0, MAGE_WATER, 2, "def", 0, 40)
	TB.attack(m, a, far)
	TB.choose(m, ["Activate Damage Conversion"])
	assert_int(CF.hp(m, 0)).is_equal(GameCore.START_HP + 12)
	assert_int(m.current_cost(mt[1])).is_equal(2)             # 1, then +1 once activated


# ---------------------------------------------------------------- 67 / 68 Fusion first

func test_c067_void_basilisk_fuses_first_then_exhausts_itself() -> void:
	var m := TB.make()
	var vb := TB.unit(m, 0, VOID_BASILISK, 0)
	var mage := TB.card(m, 0, MAGE_WATER, "spent")
	var water := TB.card(m, 0, MAGE_WATER, "spent")
	var lord := TB.card(m, 0, ABYSSLORD, "extra")
	assert_str(TB.ability(m, vb)).is_empty()
	TB.choose_uids(m, [lord])
	TB.choose_uids(m, [mage])
	TB.choose_uids(m, [water])
	assert_bool(0 in _slots(m)).is_false()                    # its own zone is still taken
	TB.choose(m, ["Front row, column 2"])
	TB.choose(m, ["Attack"])
	assert_str(CF.zone(m, lord)).is_equal("unit")
	assert_str(CF.zone(m, vb)).is_equal("exhaust")
	assert_str(CF.zone(m, mage)).is_equal("exhaust")
	var i_sum := TB.log_index(m, "summons Abysslord")
	var i_exh := TB.log_index(m, "Void Basilisk moves from Unit to Exhaust")
	assert_bool(i_sum >= 0 and i_sum < i_exh).override_failure_message("summon %d exhaust %d" % [i_sum, i_exh]).is_true()


## Owner, 3 Nov: Void Basilisk may be one of its own materials; then it is not exhausted.
func test_c067_void_basilisk_can_be_its_own_material_and_then_is_not_exhausted() -> void:
	var m := TB.make()
	var vb := TB.unit(m, 0, VOID_BASILISK, 0)                 # Dark
	var mon := TB.unit(m, 0, MONSTER_DARK, 1)                 # the only other Dark unit
	var mf := TB.card(m, 0, MIRRORFLESH, "extra")             # takes Basilisk + the Monster
	assert_str(TB.ability(m, vb)).is_empty()
	TB.choose_uids(m, [mf])
	TB.choose_uids(m, [vb])
	TB.choose_uids(m, [mon])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_str(CF.zone(m, mf)).is_equal("unit")
	assert_str(CF.zone(m, vb)).is_equal("spent")              # tributed, and not exhausted afterwards
	assert_int(TB.log_index(m, "Void Basilisk moves from Unit to Exhaust")).is_equal(-1)


## Owner, 3 Nov: Seppuku may be one of its own materials; then the "then Destroy this Unit" does not happen.
func test_c068_seppuku_can_be_its_own_material_and_then_is_not_destroyed() -> void:
	var m := TB.make()
	var sp := TB.unit(m, 0, SEPPUKU, 0)                       # Warrior / Dark
	var mon := TB.unit(m, 0, MONSTER_DARK, 1)
	var mf := TB.card(m, 0, MIRRORFLESH, "extra")
	assert_str(TB.ability(m, sp)).is_empty()
	TB.choose_uids(m, [mf])
	TB.choose_uids(m, [sp])
	TB.choose_uids(m, [mon])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_str(CF.zone(m, mf)).is_equal("unit")
	assert_str(CF.zone(m, sp)).is_equal("spent")
	assert_int(TB.log_index(m, "Seppuku is destroyed")).is_equal(-1)


func test_c067_void_basilisk_on_a_full_board_needs_a_field_material() -> void:
	var m := TB.make()
	var vb := TB.unit(m, 0, VOID_BASILISK, 0)
	for s in range(1, 6):
		TB.unit(m, 0, DRAGON_FIRE, s)                         # Fire Dragons: never Abysslord materials
	TB.card(m, 0, MAGE_WATER, "spent")
	TB.card(m, 0, MAGE_WATER, "spent")
	TB.card(m, 0, ABYSSLORD, "extra")
	# Basilisk leaves only after the summon, so Spent materials alone leave no zone for the Fusion unit.
	assert_str(m.validate(0, {"t": "ability", "uid": vb, "idx": 0})).is_equal("No Fusion unit can be summoned.")


func test_c068_seppuku_fuses_first_then_destroys_itself() -> void:
	var m := TB.make()
	var sp := TB.unit(m, 0, SEPPUKU, 0)
	var mage := TB.unit(m, 0, MAGE_WATER, 1)
	var water := TB.unit(m, 0, MAGE_WATER, 2)
	var lord := TB.card(m, 0, ABYSSLORD, "extra")
	assert_str(TB.ability(m, sp)).is_empty()
	TB.choose_uids(m, [lord])
	TB.choose_uids(m, [mage])
	TB.choose_uids(m, [water])
	assert_bool(0 in _slots(m)).is_false()                    # Seppuku is still in its zone
	TB.choose(m, ["Front row, column 2"])
	TB.choose(m, ["Attack"])
	assert_str(CF.zone(m, lord)).is_equal("unit")
	assert_str(CF.zone(m, sp)).is_equal("spent")
	var i_sum := TB.log_index(m, "summons Abysslord")
	var i_des := TB.log_index(m, "Seppuku is destroyed")
	assert_bool(i_sum >= 0 and i_sum < i_des).override_failure_message("summon %d destroy %d" % [i_sum, i_des]).is_true()


func test_c068_seppuku_saved_by_eternal_still_completes_the_fusion_summon() -> void:
	var m := TB.make()
	var sp := TB.unit(m, 0, SEPPUKU, 0)
	m.apply_status(sp, "eternal", 1)
	var mage := TB.unit(m, 0, MAGE_WATER, 1)
	var water := TB.unit(m, 0, MAGE_WATER, 2)
	var foe_set := TB.set_card(m, 1, SACRED_OFFERINGS, 0)
	var lord := TB.card(m, 0, ABYSSLORD, "extra")
	TB.ability(m, sp)
	TB.choose_uids(m, [lord])
	TB.choose_uids(m, [mage])
	TB.choose_uids(m, [water])
	TB.choose(m, ["Front row, column 2"])
	TB.choose(m, ["Attack"])
	assert_str(CF.zone(m, sp)).is_equal("unit")               # Eternal prevented the destruction
	assert_int(m.status_count(sp, "eternal")).is_equal(0)
	# Abysslord's own On Summon still resolves: it may destroy a Spell or Trap.
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, foe_set])
	TB.choose_uids(m, [foe_set])
	assert_str(CF.zone(m, foe_set)).is_equal("spent")


# ---------------------------------------------------------------- 70 / 72 / 76

func test_c070_krakeshin_gains_6_atk_when_it_moves_zone() -> void:
	var m := TB.make()
	var k := TB.unit(m, 0, KRAKESHIN, 0)
	m.apply_status(k, "nimble", 1)
	assert_str(m.submit(0, {"t": "move", "uid": k})).is_empty()
	TB.choose(m, [TB.slot_label(1)])
	assert_int(m.atk_of(k)).is_equal(12 + 6)


func test_c072_myth_wukong_gains_16_def_in_front_and_16_atk_behind() -> void:
	var m := TB.make()
	var front := TB.unit(m, 0, MYTH_WUKONG, 0)
	var back := TB.unit(m, 0, MYTH_WUKONG, 4)
	assert_int(m.def_of(front)).is_equal(16 + 16)
	assert_int(m.atk_of(front)).is_equal(16)
	assert_int(m.atk_of(back)).is_equal(16 + 16)
	assert_int(m.def_of(back)).is_equal(16)


func test_c076_soul_devourer_may_poison_a_unit_in_its_column_for_10() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, MAGE_WATER, 0)                   # same column, other side
	var own := TB.unit(m, 0, MAGE_WATER, 3)                   # same column, behind it
	TB.unit(m, 1, MAGE_WATER, 1)                              # another column: not offered
	var sd := TB.summon(m, 0, SOUL_DEVOURER, 0)
	# "a Unit in this Column" includes Soul Devourer itself, as with every other column choice.
	assert_array(_opts(m)).contains_exactly_in_any_order([-1, foe, own, sd])
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "poison")).is_equal(10)


func test_c076_soul_devourer_poison_is_optional() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, MAGE_WATER, 0)
	TB.summon(m, 0, SOUL_DEVOURER, 0)
	CF.decline(m)
	assert_int(m.status_count(foe, "poison")).is_equal(0)
	assert_bool(m.pending.is_empty()).is_true()


# ---------------------------------------------------------------- 84 / 87

func test_c084_assassinate_reaches_20_def_or_less() -> void:
	var m := TB.make()
	var at20 := TB.unit(m, 1, MAGE_WATER, 0, "atk", 8, 20)
	TB.unit(m, 1, MAGE_WATER, 1, "atk", 8, 22)                # 22 DEF: out of reach
	TB.cast(m, 0, ASSASSINATE)
	assert_array(_opts(m)).contains_exactly([at20])
	assert_str(String(m.pending["prompt"])).contains("20 DEF or less")


func test_c087_shared_fate_destroys_any_opponents_card() -> void:
	var m := CF.p1_main()
	TB.set_card(m, 0, SHARED_FATE, 0)
	var mine := TB.unit(m, 0, MAGE_WATER, 0)
	var foe_unit := TB.unit(m, 1, MAGE_WATER, 0)
	var foe_set := TB.set_card(m, 1, SACRED_OFFERINGS, 1)
	var foe_power := TB.power(m, 1, SABOTEURS_GUILD, 0)
	TB.kill(m, mine, 1)                                       # destroyed by an opponent's effect
	TB.choose(m, ["Activate Shared Fate"])
	assert_array(_opts(m)).contains_exactly_in_any_order([foe_unit, foe_set, foe_power])
	TB.choose_uids(m, [foe_power])
	assert_str(CF.zone(m, foe_power)).is_equal("spent")
	assert_str(CF.zone(m, foe_unit)).is_equal("unit")


# ---------------------------------------------------------------- 135 Dragon Rider

func test_c135_dragon_rider_summoned_behind_a_dragon_is_put_in_defense() -> void:
	var m := TB.make()
	var dragon := TB.unit(m, 0, DRAGON_WATER, 0)
	var rider := TB.summon(m, 0, DRAGON_RIDER, 3)
	assert_str(String(m.cards[rider]["stance"])).is_equal("def")
	assert_int(m.atk_of(dragon)).is_equal(8 + 14)
	assert_str(m.validate(0, {"t": "stance", "uid": rider})).contains("cannot be in Attack stance")


func test_c135_a_dragon_arriving_in_front_puts_the_rider_in_defense() -> void:
	var m := TB.make()
	var rider := TB.unit(m, 0, DRAGON_RIDER, 3)
	assert_str(String(m.cards[rider]["stance"])).is_equal("atk")
	TB.summon(m, 0, DRAGON_WATER, 0)
	assert_str(String(m.cards[rider]["stance"])).is_equal("def")


func test_c135_the_rider_may_attack_again_once_the_dragon_is_gone() -> void:
	var m := TB.make()
	var dragon := TB.unit(m, 0, DRAGON_WATER, 0)
	var rider := TB.summon(m, 0, DRAGON_RIDER, 3)
	TB.kill(m, dragon)
	assert_str(m.validate(0, {"t": "stance", "uid": rider})).is_empty()
	m.submit(0, {"t": "stance", "uid": rider})
	assert_str(String(m.cards[rider]["stance"])).is_equal("atk")


func test_c135_dragon_rider_behind_a_non_dragon_keeps_attack_stance() -> void:
	var m := TB.make()
	var guard := TB.unit(m, 0, MAGE_WATER, 0)
	var rider := TB.summon(m, 0, DRAGON_RIDER, 3)
	assert_str(String(m.cards[rider]["stance"])).is_equal("atk")
	assert_int(m.atk_of(guard)).is_equal(8)


func test_c135_effects_cannot_flip_a_protected_rider_to_attack() -> void:
	var m := TB.make()
	TB.unit(m, 0, DRAGON_WATER, 0)
	var rider := TB.unit(m, 0, DRAGON_RIDER, 3, "def")
	m._flip_stance(rider)                                     # e.g. an effect changing every stance
	assert_str(String(m.cards[rider]["stance"])).is_equal("def")
	assert_str(TB.log_text(m)).contains("cannot be in Attack stance")


# ---------------------------------------------------------------- 155-157 Symbiotes

# @cards 155,156
func test_c155_c156_symbiotes_give_their_protector_6_atk() -> void:
	for id in [SYMBIOTE_SPAWN, SYMBIOTE_LARVA]:
		var m := TB.make()
		var guard := TB.unit(m, 0, MAGE_WATER, 0)
		TB.unit(m, 0, id, 3)
		assert_int(m.atk_of(guard)).override_failure_message(str(id)).is_equal(8 + 6)


func test_c157_symbiote_siphonophore_gives_adjacent_units_6_atk_while_protected() -> void:
	var m := TB.make()
	var guard := TB.unit(m, 0, MAGE_WATER, 0)
	var side := TB.unit(m, 0, MAGE_WATER, 4)
	TB.unit(m, 0, SYMBIOTE_SIPHONOPHORE, 3)
	assert_int(m.atk_of(guard)).is_equal(8 + 6)
	assert_int(m.atk_of(side)).is_equal(8 + 6)


# ---------------------------------------------------------------- 165 Saviour Appears: Defcon 1

func test_c165_saviour_answers_a_20_atk_summon_with_a_20_atk_or_less_unit() -> void:
	var m := CF.p1_main()
	TB.set_card(m, 0, SAVIOUR_DEFCON_1, 0)
	var ok := TB.card(m, 0, SOLOMON, "spent")                 # 20 ATK: allowed
	var strong := TB.card(m, 0, COSMIC_DRAGON, "spent")       # 24 ATK: too strong
	TB.summon(m, 1, SOLOMON, 0)                               # the opponent's 20-ATK unit
	TB.choose(m, ["Activate Saviour Appears"])
	assert_bool(ok in _opts(m)).is_true()
	assert_bool(strong in _opts(m)).is_false()
	TB.choose_uids(m, [ok])
	_place(m, 0)
	assert_str(CF.zone(m, ok)).is_equal("unit")


func test_c165_saviour_ignores_a_unit_with_less_than_20_atk() -> void:
	var m := CF.p1_main()
	TB.set_card(m, 0, SAVIOUR_DEFCON_1, 0)
	TB.card(m, 0, SOLOMON, "spent")
	TB.summon(m, 1, 16, 0)                                    # Edwin: 8 ATK
	assert_bool(CF.labels(m).has("Activate Saviour Appears: Defcon 1")).is_false()


# ---------------------------------------------------------------- 178 / 179 Powers

func test_c178_reinforcements_lowers_unit_costs_by_one() -> void:
	var m := TB.make()
	TB.power(m, 0, REINFORCEMENTS, 0)
	TB.unit(m, 1, MAGE_WATER, 0)                              # only the opponent controls a unit
	var cosmic := TB.card(m, 0, COSMIC_DRAGON)
	assert_int(m.current_cost(cosmic)).is_equal(3 - 1)
	TB.unit(m, 0, MAGE_WATER, 1)                              # now you control one too
	assert_int(m.current_cost(cosmic)).is_equal(3)


func test_c179_tyrants_lantern_gives_your_fire_units_8_atk() -> void:
	var m := TB.make()
	TB.power(m, 0, TYRANTS_LANTERN, 0)
	var fire := TB.unit(m, 0, MAGE_FIRE, 0)
	var water := TB.unit(m, 0, MAGE_WATER, 1)
	assert_int(m.atk_of(fire)).is_equal(8 + 8)
	assert_int(m.atk_of(water)).is_equal(8)


# ---------------------------------------------------------------- 180 / 182 Spells

func test_c180_hypnotise_takes_only_a_16_atk_or_less_unit() -> void:
	var m := TB.make()
	var at16 := TB.unit(m, 1, MAGE_WATER, 0, "atk", 16)
	TB.unit(m, 1, MAGE_WATER, 1, "atk", 18)
	TB.cast(m, 0, HYPNOTISE)
	assert_array(_opts(m)).contains_exactly([at16])
	assert_str(String(m.pending["prompt"])).contains("16 ATK or less")


func test_c182_shimmer_serum_gives_10_atk_until_end_of_turn() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, MAGE_WATER, 0)
	TB.cast(m, 0, SHIMMER_SERUM)
	assert_str(String(m.pending["prompt"])).contains("+10 ATK")
	TB.choose_uids(m, [u])
	assert_int(m.atk_of(u)).is_equal(8 + 10)
	CF.end_turn(m)
	assert_int(m.atk_of(u)).is_equal(8)


# ---------------------------------------------------------------- 191 Do Not Open Box

## Player 1's turn with player 0's Do Not Open Box set in column `col` and a Cosmic Dragon in
## player 0's Draw. Returns [match, box, dragon].
func _box(col: int) -> Array:
	var m := CF.p1_main()
	var box := TB.set_card(m, 0, DO_NOT_OPEN_BOX, col)
	var dragon := TB.card(m, 0, COSMIC_DRAGON, "draw")
	return [m, box, dragon]


func test_c191_do_not_open_box_destroyed_by_the_opponent_summons_from_draw_into_its_column() -> void:
	var b := _box(2)
	var m: MatchEngine = b[0]
	TB.kill(m, b[1], 1)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_int(int(m.pending["player"])).is_equal(0)
	TB.choose(m, ["Activate Do Not Open Box"])
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_bool(m.pending.get("reveal_pile", false)).is_true()   # the Draw is shown to its owner only
	assert_bool(MatchView.build(m, 1)["pending"].has("options")).is_false()
	assert_bool(b[2] in _opts(m)).is_true()
	TB.choose_uids(m, [b[2]])
	assert_array(_slots(m)).contains_exactly_in_any_order([2, 5])   # the Trap's column only
	TB.choose(m, [TB.slot_label(5)])
	TB.choose(m, ["Defense"])                                 # on the opponent's turn: asked
	assert_str(CF.zone(m, b[2])).is_equal("unit")
	assert_int(int(m.cards[b[2]]["slot"])).is_equal(5)
	assert_str(String(m.cards[b[2]]["stance"])).is_equal("def")
	assert_str(CF.zone(m, b[1])).is_equal("spent")
	assert_bool(m.cards[b[1]]["face_up"]).is_false()          # no stray face-up flag in a pile


func test_c191_do_not_open_box_destroyed_by_its_owner_does_nothing() -> void:
	var b := _box(0)
	var m: MatchEngine = b[0]
	TB.kill(m, b[1], 0)                                       # e.g. Plan B: its owner's own effect
	assert_bool(CF.labels(m).has("Activate Do Not Open Box")).is_false()
	assert_str(CF.zone(m, b[2])).is_equal("draw")


func test_c191_do_not_open_box_is_not_offered_without_a_free_zone_in_its_column() -> void:
	var b := _box(1)
	var m: MatchEngine = b[0]
	TB.unit(m, 0, MAGE_WATER, 1)
	TB.unit(m, 0, MAGE_WATER, 4)
	TB.kill(m, b[1], 1)
	assert_bool(CF.labels(m).has("Activate Do Not Open Box")).is_false()


func test_c191_do_not_open_box_is_not_offered_with_no_unit_in_draw() -> void:
	var m := CF.p1_main()
	var box := TB.set_card(m, 0, DO_NOT_OPEN_BOX, 0)
	m.players[0]["draw"].clear()
	TB.card(m, 0, SACRED_OFFERINGS, "draw")                   # a Spell only
	TB.kill(m, box, 1)
	assert_bool(CF.labels(m).has("Activate Do Not Open Box")).is_false()


func test_c191_do_not_open_box_respects_trap_prompts_off() -> void:
	var b := _box(0)
	var m: MatchEngine = b[0]
	m.set_trap_prompts(0, EffectEngine.TRAP_PROMPT_OFF)
	TB.kill(m, b[1], 1)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(CF.zone(m, b[2])).is_equal("draw")


func test_c191_do_not_open_box_skipped_summons_nothing() -> void:
	var b := _box(0)
	var m: MatchEngine = b[0]
	TB.kill(m, b[1], 1)
	TB.choose(m, [EffectEngine.TRAP_SKIP])
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(CF.zone(m, b[2])).is_equal("draw")


func test_c191_do_not_open_box_destroyed_by_an_opponents_card_effect_in_play() -> void:
	# A real effect: the opponent's Auric pays 8 HP to destroy the set Box.
	var b := _box(1)
	var m: MatchEngine = b[0]
	var auric := TB.unit(m, 1, AURIC, 0)
	TB.ability(m, auric)
	TB.choose(m, ["Destroy a Spell/Trap"])
	TB.choose_uids(m, [b[1]])
	TB.choose(m, ["Activate Do Not Open Box"])
	TB.choose_uids(m, [b[2]])
	TB.choose(m, [TB.slot_label(1)])
	TB.choose(m, ["Attack"])
	assert_int(int(m.cards[b[2]]["slot"])).is_equal(1)
	assert_str(TB.log_text(m)).contains("activates Trap Do Not Open Box")


## Regression: the 3 Nov cards have no sheet index (null); CardDB.all() compared null with a number
## (a script error on every call, e.g. the game log's name tinting) and left the order undefined.
func test_c191_cards_without_a_sheet_index_sort_last_in_id_order() -> void:
	var all := CardDB.all()
	var ids := all.map(func(d): return int(d["id"]))
	assert_int(ids.size()).is_equal(CardDB._defs.size())
	var tail := ids.slice(ids.size() - 3)
	assert_array(tail).contains_exactly([189, 190, 191])
	for d in all.slice(0, all.size() - 3):
		assert_bool(d["source"].get("index") != null).is_true()


func test_c191_do_not_open_box_is_a_two_ap_trap() -> void:
	var df := CardDB.get_def(DO_NOT_OPEN_BOX)
	assert_str(String(df["category"])).is_equal("trap")
	assert_int(int(df["cost"])).is_equal(2)
	assert_str(CardScripts.support_status(DO_NOT_OPEN_BOX)).is_equal("full")
