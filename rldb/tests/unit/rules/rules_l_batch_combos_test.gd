extends GdUnitTestSuite
## L batch final QA (design/qa-final-2026-11-05.md): where the new systems meet. Evolve (L23) with
## Hypnotise (L9), Sneaky Snunday (L15), Cleanse batches (L20), Shapeshifter Loak's copied art (L11)
## and Fusion Ceremony's material timing (L19).

const SPAWN := 155
const LARVA := 156
const HYPNOTISE := 180
const SNUNDAY := 154
const LOAK := 19
const FROST_WYVERN := 32          # Once per turn: apply 1 Paralyse and 4 Burn to a Unit in this Column.
const FUSION_CEREMONY := 82
const ROTMAW := 60                # Fusion: Debuffed Unit + Buffed Unit; On Summon: Apply 3 Debilitate to a Unit.


func _end_turn(m: MatchEngine) -> void:
	var p := m.active
	for i in 6:
		if m.active != p or not m.pending.is_empty():
			return
		m.submit(p, {"t": "next_phase"})


func _hypnotise(m: MatchEngine, p: int, target: int, zone: String) -> void:
	TB.cast(m, p, HYPNOTISE)
	assert_str(TB.choose_uids(m, [target])).is_equal("")
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_str(TB.choose(m, [zone])).is_equal("")


# ---------------------------------------------------------------- Hypnotise (L9)

## Decision (qa-final): Hypnotise lasts "until the end of this turn" and is cast only in its caster's
## own turn, so a borrowed Symbiote is always home before any turn starts: the borrower is never asked,
## and its owner is asked as usual at the start of their next turn.
func test_hypnotised_spawn_is_home_and_offered_to_its_owner_at_their_turn_start() -> void:
	# Arrange: player 0's Spawn; player 1 takes it on turn 2.
	var m := TB.make()
	var spawn := TB.unit(m, 0, SPAWN, 1)
	TB.to_turn2(m)
	assert_bool(m.pending.is_empty()).is_true()
	_hypnotise(m, 1, spawn, "Front row, column 3")
	assert_int(int(m.cards[spawn]["ctl"])).is_equal(1)
	assert_bool(m.can_evolve(spawn)).is_true()          # a face-up unit; only the turn start asks
	# Act
	_end_turn(m)
	# Assert: back in its own zone, and player 0's turn 3 opens with its Evolve prompt.
	assert_int(m.turn).is_equal(3)
	assert_int(int(m.cards[spawn]["ctl"])).is_equal(0)
	assert_int(int(m.cards[spawn]["slot"])).is_equal(1)
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	assert_int(int(m.pending["player"])).is_equal(0)
	assert_int(int(m.pending["source"])).is_equal(spawn)
	assert_str(TB.choose(m, ["Evolve"])).is_equal("")
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)


func test_hypnotised_spawn_sent_to_spent_on_return_is_not_offered() -> void:
	var m := TB.make()
	var spawn := TB.unit(m, 0, SPAWN, 1)
	TB.to_turn2(m)
	_hypnotise(m, 1, spawn, "Front row, column 3")
	TB.unit(m, 0, TB.FILLER, 1)                          # its home zone is filled meanwhile
	_end_turn(m)
	assert_str(String(m.cards[spawn]["zone"])).is_equal("spent")
	assert_bool(m.pending.is_empty()).override_failure_message(str(m.pending)).is_true()


# ---------------------------------------------------------------- Sneaky Snunday (L15)

func test_snunday_mirrors_kept_changes_around_the_evolved_base() -> void:
	# Arrange: a Spawn with a permanent +6 ATK / -4 DEF evolves into Larva (base 0/0).
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 3)
	m.cards[spawn]["mods"].append({"atk": 6, "def": -4, "until": "perm", "src": "test"})
	TB.to_turn2(m)
	TB.choose(m, ["Evolve"])
	assert_int(m.atk_of(spawn)).is_equal(6)
	assert_int(m.def_of(spawn)).is_equal(0)
	# Act
	TB.cast(m, 1, SNUNDAY)
	# Assert: base - (raw - base): ATK 0 - 6 -> 0 (floored), DEF 0 + 4 = 4.
	assert_bool(m.reversal_active()).is_true()
	assert_int(m.atk_of(spawn)).is_equal(0)
	assert_int(m.def_of(spawn)).is_equal(4)


# ---------------------------------------------------------------- Cleanse batches (L20)

func test_evolved_unit_keeps_cleanse_and_it_blocks_the_whole_batch() -> void:
	# Arrange: player 1's Spawn with 1 Cleanse evolves on turn 2; player 0's Frost Wyvern shares its column.
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 0)
	m.apply_status(spawn, "cleanse", 1)
	var wyvern := TB.unit(m, 0, FROST_WYVERN, 0)
	TB.to_turn2(m)
	TB.choose(m, ["Evolve"])
	assert_int(m.status_count(spawn, "cleanse")).is_equal(1)
	_end_turn(m)
	assert_int(m.active).is_equal(0)
	# Act: Paralyse and Burn applied at the same time.
	assert_str(TB.ability(m, wyvern, 0)).is_equal("")
	if TB.pend_kind(m) == "select":
		TB.choose_uids(m, [spawn])
	# Assert: both prevented, one Cleanse stack used.
	assert_int(m.status_count(spawn, "paralyse")).is_equal(0)
	assert_int(m.status_count(spawn, "burn")).is_equal(0)
	assert_int(m.status_count(spawn, "cleanse")).is_equal(0)
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)


# ---------------------------------------------------------------- Loak / Mimic copied art (L11)

func test_loak_copying_an_evolved_unit_shows_the_evolved_art() -> void:
	# Arrange: player 1's evolved Larva (+6 ATK kept) in column 1; player 0's turn 3.
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 0)
	m.cards[spawn]["mods"].append({"atk": 6, "def": 2, "until": "perm", "src": "test"})
	TB.to_turn2(m)
	TB.choose(m, ["Evolve"])
	_end_turn(m)
	# Act
	var loak := TB.summon(m, 0, LOAK, 0)
	if TB.pend_kind(m) == "select":
		TB.choose_uids(m, [spawn])
	# Assert
	assert_int(m.art_id(loak)).is_equal(LARVA)
	assert_int(int(MatchView.card_view(m, loak, 1)["art_id"])).is_equal(LARVA)
	assert_int(m.atk_of(loak)).is_equal(6)
	assert_str(String(MatchView.card_view(m, loak, 1)["name"])).is_equal("Shapeshifter Loak")


## Decision (qa-final): the copy is a snapshot taken On Summon ("become the ATK/DEF/Race of that
## Unit"), so a copied Spawn that evolves later does not change Loak's stats or its art.
func test_loak_keeps_the_spawn_art_it_copied_when_that_spawn_evolves_later() -> void:
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 0)
	var loak := TB.summon(m, 0, LOAK, 0)
	if TB.pend_kind(m) == "select":
		TB.choose_uids(m, [spawn])
	assert_int(m.art_id(loak)).is_equal(SPAWN)
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	TB.choose(m, ["Evolve"])
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	assert_int(m.art_id(loak)).is_equal(SPAWN)
	assert_int(m.art_id(spawn)).is_equal(LARVA)


func test_evolving_a_unit_drops_a_copied_art_it_showed() -> void:
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 0)
	m.cards[spawn]["art_o"] = 1                          # as if it showed another unit's art
	TB.to_turn2(m)
	TB.choose(m, ["Evolve"])
	assert_int(m.art_id(spawn)).is_equal(LARVA)
	assert_bool(MatchView.card_view(m, spawn, 0).has("art_id")).is_false()


# ---------------------------------------------------------------- Fusion Ceremony (L19)

func test_evolved_material_is_in_spent_as_its_evolved_form_before_the_fusions_on_summon() -> void:
	# Arrange: player 1's Spawn with Eternal (Buffed) evolves; a Poisoned unit (Debuffed) beside it.
	var m := TB.make()
	var spawn := TB.unit(m, 1, SPAWN, 0)
	m.apply_status(spawn, "eternal", 1)
	var sick := TB.unit(m, 1, TB.FILLER, 1)
	m.apply_status(sick, "poison", 2)
	var rot := TB.card(m, 1, ROTMAW, "extra")
	var bystander := TB.unit(m, 0, TB.FILLER, 2)
	TB.to_turn2(m)
	TB.choose(m, ["Evolve"])
	# Act
	TB.cast(m, 1, FUSION_CEREMONY)
	var mats := [rot, spawn, sick]
	for i in 10:
		var pd := m.pending
		if pd.is_empty() or String(pd["prompt"]).contains("Debilitate"):
			break
		if String(pd["kind"]) == "slot":
			TB.choose(m, ["Front row, column 1"])
		elif String(pd["kind"]) == "stance":
			TB.choose(m, ["Attack"])
		else:
			var pick := CF.offered(m).filter(func(u): return u in mats)
			assert_bool(pick.is_empty()).override_failure_message(str(pd)).is_false()
			mats.erase(pick[0])
			TB.choose_uids(m, [pick[0]])
	# Assert: Rotmaw's forced On Summon target choice never offers a material.
	assert_str(String(m.pending.get("prompt", ""))).override_failure_message(TB.log_text(m)).contains("Debilitate")
	var offered := CF.offered(m)
	assert_bool(spawn in offered).is_false()
	assert_bool(sick in offered).is_false()
	assert_bool(bystander in offered).is_true()
	assert_str(String(m.cards[spawn]["zone"])).is_equal("spent")
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
