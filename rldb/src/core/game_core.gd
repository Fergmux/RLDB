class_name GameCore
extends RefCounted
## Deterministic game state plus low-level helpers (zones, stats, statuses, HP, log).
## No Godot nodes or UI. Card instances are plain Dictionaries so they can be
## snapshotted, redacted and sent over the network without custom serialisation.

const UNIT_SLOTS := 6
const BACKROW_SLOTS := 3
const POWER_SLOTS := 4
const START_HP := 60
const BASE_AP := 2
const BASE_DRAW := 4

const PHASE_MAIN1 := "main1"
const PHASE_BATTLE := "battle"
const PHASE_MAIN2 := "main2"
const PHASE_END := "end"
const PHASE_OVER := "over"

## Uid -> instance Dictionary.
var cards: Dictionary = {}
## 2 player Dictionaries.
var players: Array = []
## Global turn counter, 1-based.
var turn: int = 0
## Active player index.
var active: int = 0
## Current phase.
var phase: String = PHASE_MAIN1
## Winning seat, or -1.
var winner: int = -1
## Random source.
var rng := RandomNumberGenerator.new()
## {seq, pub, priv:{player:text}}.
var log_entries: Array = []
## J31 (performance): MatchView.log_for's per-viewer cache of the redacted rows of settled log entries
## (every entry but the last). Presentation only: never part of the rules state, a save or a clone.
var log_view_cache: Dictionary = {}
## Match configuration.
var config: Dictionary = {}
## Sneaky Snunday: turn during which reversals were played.
var reversal_turn: int = -1
## S-01: copies played that turn; an even count cancels out.
var reversal_count: int = 0
## Freaky Funday: turn during which it was played.
var swap_turn: int = -1
## Copies played that turn; an even count cancels out (also for card effects, see swap_active).
var swap_count: int = 0
## Units whose ATK/DEF are switched this turn (uid -> true). Their modifiers from before the
## switch carry "pre_swap"; later ones were already switched as they were applied.
var swapped: Dictionary = {}
var _next_log_seq: int = 1
## Optional telemetry observer (TelemetryCollector): it only reads, the rules never depend on it,
## and clone_for_sim() does not copy it, so look-ahead copies stay silent.
var observer: Object = null
## Optional local statistics observer (StatsObserver), same contract; clone_for_sim() skips it too.
var stats_observer: Object = null


## Reports a committed rules event to the telemetry observer, if any. No effect on play.
func note(kind: String, data: Dictionary) -> void:
	if observer != null:
		observer.on_core_event(self, kind, data)
	if stats_observer != null:
		stats_observer.on_core_event(self, kind, data)


# ---------------------------------------------------------------- setup

func _new_player(index: int) -> Dictionary:
	var units := []
	units.resize(UNIT_SLOTS)
	units.fill(-1)
	var backrow := []
	backrow.resize(BACKROW_SLOTS)
	backrow.fill(-1)
	var powers := []
	powers.resize(POWER_SLOTS)
	powers.fill(-1)
	return {
		"index": index, "hp": START_HP, "ap": 0, "ap_start": 0, "ap_peak": 0, "ap_next": [], "delayed": [],
		# D13: turn on which this player chose "Skip for the rest of this turn" for Traps (-1: none).
		"trap_pass_turn": -1,
		# J6 (owner feedback 2026-10-22): this seat's Trap response prompts (EffectEngine.TRAP_PROMPT_*).
		"trap_prompts": "eligible",
		# Player effects that last until the start of this player's next turn (Snow Tiger Paladin):
		# effect name -> the turn it was applied (see turn_effect_active).
		"turn_fx": {},
		"units": units, "backrow": backrow, "powers": powers,
		"hand": [], "draw": [], "spent": [], "exhaust": [], "extra": [],
		"name": "Player %d" % (index + 1),
	}


## Creates a fresh instance for a definition id. Uids are drawn randomly so they
## carry no information about deck order.
func _create_instance(def_id: int, owner: int) -> int:
	var uid := rng.randi_range(1000, 999999)
	while cards.has(uid):
		uid = rng.randi_range(1000, 999999)
	cards[uid] = {
		"uid": uid, "id": def_id, "owner": owner, "ctl": owner,
		"zone": "draw", "slot": -1, "face_up": false, "stance": "atk",
		"st": {}, "runes": 0, "mods": [], "cost_p": 0, "cost_t": [],
		"summoned_turn": -1, "summoned_phase": "", "attacked_turn": -1, "moved_turn": -1, "opt": {},
		"type_o": null, "race_o": null, "base_atk": null, "base_def": null,
		"orig_slot": -1, "control_until": -1, "set_turn": -1,
	}
	return uid


# ---------------------------------------------------------------- lookups

## Instance dictionary of card uid.
func c(uid: int) -> Dictionary:
	return cards[uid]


## Definition of card uid.
func d(uid: int) -> Dictionary:
	return CardDB.get_def(cards[uid]["id"])


## The other player.
func opp(p: int) -> int:
	return 1 - p


## Name of card uid.
func name_of(uid: int) -> String:
	return d(uid)["name"]


## Category of card uid.
func category(uid: int) -> String:
	return d(uid)["category"]


## True if uid is a unit card.
func is_unit(uid: int) -> bool:
	return CardDB.is_unit_category(category(uid))


## True if uid is an Extra-pile card.
func is_extra(uid: int) -> bool:
	return CardDB.is_extra_category(category(uid))


## True if uid is on the field.
func on_field(uid: int) -> bool:
	return cards.has(uid) and cards[uid]["zone"] in ["unit", "backrow", "power"]


## True if uid is a unit on the field.
func unit_on_field(uid: int) -> bool:
	return cards.has(uid) and cards[uid]["zone"] == "unit"


## Player p's pile / zone list.
func pile(p: int, zone: String) -> Array:
	return players[p][zone]


## Unit uids on player p's field.
func field_units(p: int) -> Array:
	var out := []
	for uid in players[p]["units"]:
		if uid != -1:
			out.append(uid)
	return out


## All units on the field, active player first.
func all_field_units() -> Array:
	return field_units(active) + field_units(opp(active))


## Trap/Spell uids on player p's field.
func backrow_cards(p: int) -> Array:
	return players[p]["backrow"].filter(func(u): return u != -1)


## Power uids on player p's field.
func power_cards(p: int) -> Array:
	return players[p]["powers"].filter(func(u): return u != -1)


## All cards on player p's field.
func field_cards(p: int) -> Array:
	return field_units(p) + backrow_cards(p) + power_cards(p)


## Column of a unit slot.
static func slot_col(slot: int) -> int:
	return slot % 3


## Row of a unit slot.
static func slot_row(slot: int) -> int:
	return slot / 3   # 0 = front, 1 = back


## Slots touching `slot` (including diagonals).
static func adjacent_slots(slot: int) -> Array:
	var out := []
	for s in range(UNIT_SLOTS):
		if s != slot and absi(slot_col(s) - slot_col(slot)) <= 1 and absi(slot_row(s) - slot_row(slot)) <= 1:
			out.append(s)
	return out


## Column of the card uid.
func column_of(uid: int) -> int:
	return slot_col(cards[uid]["slot"])


## Back-row units are protected while the front-row zone in the same column is occupied.
func is_protected(uid: int) -> bool:
	var inst: Dictionary = cards[uid]
	if inst["zone"] != "unit" or slot_row(inst["slot"]) == 0:
		return false
	return players[inst["ctl"]]["units"][slot_col(inst["slot"])] != -1


## The front-row unit protecting this back-row unit, or -1.
func protector_of(uid: int) -> int:
	if not is_protected(uid):
		return -1
	return players[cards[uid]["ctl"]]["units"][column_of(uid)]


## The back-row unit this front-row unit protects, or -1.
func protected_by(uid: int) -> int:
	var inst: Dictionary = cards[uid]
	if inst["zone"] != "unit" or slot_row(inst["slot"]) != 0:
		return -1
	return players[inst["ctl"]]["units"][inst["slot"] + 3]


## Units adjacent to unit uid.
func adjacent_units(uid: int) -> Array:
	var inst: Dictionary = cards[uid]
	var out := []
	for s in adjacent_slots(inst["slot"]):
		var other: int = players[inst["ctl"]]["units"][s]
		if other != -1:
			out.append(other)
	return out


## Empty unit slots of player p.
func free_unit_slots(p: int) -> Array:
	var out := []
	for s in range(UNIT_SLOTS):
		if players[p]["units"][s] == -1:
			out.append(s)
	return out


## Empty Trap/Spell slots of player p.
func free_backrow_slots(p: int) -> Array:
	var out := []
	for s in range(BACKROW_SLOTS):
		if players[p]["backrow"][s] == -1:
			out.append(s)
	return out


## Empty Power slots of player p.
func free_power_slots(p: int) -> Array:
	var out := []
	for s in range(POWER_SLOTS):
		if players[p]["powers"][s] == -1:
			out.append(s)
	return out


# ---------------------------------------------------------------- log

## Adds a log entry. `pub` is shown to both players; `priv` maps a player index to
## the text that player sees instead (used to keep hidden identities private).
func add_log(pub: String, priv: Dictionary = {}) -> void:
	log_entries.append({"seq": _next_log_seq, "turn": turn, "pub": pub, "priv": priv, "fx": []})
	_next_log_seq += 1


## Attaches a presentation event to the latest log entry. Effects only reference
## public information (players, board positions, amounts), never hidden identities,
## so clients may animate them; they never affect rules state.
func add_fx(fx: Dictionary) -> void:
	# Never attach a public effect to a private-only entry (that would reveal its timing).
	if log_entries.is_empty() or log_entries[-1]["pub"] == "":
		add_log(" ")
	log_entries[-1]["fx"].append(fx)


## Card identity for a presentation event: `id` is kept only for the seats in `seen_by`
## (MatchView.log_for strips both fields for every other viewer), so hidden cards stay hidden.
func fx_identity(uid: int, seen_by: Array) -> Dictionary:
	return {"id": d(uid)["id"], "seen_by": seen_by}


## Board position of a field card for presentation events, or {}.
func fx_pos(uid: int) -> Dictionary:
	if not cards.has(uid):
		return {}
	var inst: Dictionary = cards[uid]
	if not (inst["zone"] in ["unit", "backrow", "power"]):
		return {}
	return {"p": inst["ctl"], "zone": inst["zone"], "slot": inst["slot"]}


## Name of player p.
func pname(p: int) -> String:
	return players[p]["name"]


## Public label for a card: hidden set cards are never named in public text.
func public_label(uid: int) -> String:
	var inst: Dictionary = cards[uid]
	if inst["zone"] == "backrow" and not is_face_up(uid):
		return "a set Spell/Trap"
	if inst["zone"] in ["hand", "draw", "spent", "exhaust", "extra"]:
		return "a hidden card"
	return name_of(uid)


## Logs text about a card; "§" is replaced by its public label for everyone and by
## its real name for its owner when the card is hidden from the opponent.
func card_log(uid: int, template: String) -> void:
	var pub := template.replace("§", public_label(uid))
	var named := template.replace("§", name_of(uid))
	if pub == named:
		add_log(pub)
	else:
		add_log(pub, {cards[uid]["owner"]: named})


## Whether every player may see this card's identity right now (field, resolving, face-up set).
func is_public_card(uid: int) -> bool:
	if not cards.has(uid):
		return false
	var z: String = cards[uid]["zone"]
	return z in ["unit", "power", "limbo"] or (z == "backrow" and is_face_up(uid))


## True if card uid is face up.
func is_face_up(uid: int) -> bool:
	var inst: Dictionary = cards[uid]
	return inst["face_up"] or inst["st"].get("reveal", 0) > 0


# ---------------------------------------------------------------- abilities & suppression

## True if unit uid is debilitated.
func is_debilitated(uid: int) -> bool:
	return cards[uid]["st"].get("debilitate", 0) > 0


## Card scripts are looked up through here so suppression applies uniformly.
func script_of(uid: int) -> Dictionary:
	return CardScripts.get_entry(cards[uid]["id"])


## True if a passive flag is active for this unit (on Field and not suppressed).
func has_flag(uid: int, flag: String) -> bool:
	if not on_field(uid) or is_debilitated(uid):
		return false
	return script_of(uid).get("flags", []).has(flag)


## True if any non-suppressed card controlled by p has the flag (Powers, units).
func player_has_flag(p: int, flag: String) -> bool:
	return count_flag(p, flag) > 0


## Number of non-suppressed cards controlled by p with the flag (stacking effects).
func count_flag(p: int, flag: String) -> int:
	var n := 0
	for uid in field_units(p) + power_cards(p):
		if has_flag(uid, flag):
			n += 1
	return n


# ---------------------------------------------------------------- types and stats

## Current type of unit uid.
func unit_type(uid: int) -> String:
	var inst: Dictionary = cards[uid]
	if inst["type_o"] != null:
		return inst["type_o"]
	return d(uid)["type"]


## Current race of unit uid.
func unit_race(uid: int) -> String:
	var inst: Dictionary = cards[uid]
	if inst["race_o"] != null:
		return inst["race_o"]
	return d(uid)["race"]


## ATK before buffs and statuses.
func base_atk(uid: int) -> int:
	var inst: Dictionary = cards[uid]
	if inst["base_atk"] != null:
		return inst["base_atk"]
	var v = d(uid)["atk"]
	return 0 if v == null else v


## DEF before buffs and statuses.
func base_def(uid: int) -> int:
	var inst: Dictionary = cards[uid]
	if inst["base_def"] != null:
		return inst["base_def"]
	var v = d(uid)["def"]
	return 0 if v == null else v


## True while effects are reversed this turn.
func reversal_active() -> bool:
	return reversal_turn == turn and reversal_count % 2 == 1


## True while Freaky Funday switches ATK and DEF in card effects this turn.
func swap_active() -> bool:
	return swap_turn == turn and swap_count % 2 == 1


## Returns {"atk", "def", "parts": [explanations]} for a unit, recalculated live. A unit switched
## by Freaky Funday shows base + earlier modifiers switched; modifiers applied since were switched
## when applied and auras are switched while Funday lasts, so they are added as they are.
func stat_breakdown(uid: int) -> Dictionary:
	var inst: Dictionary = cards[uid]
	var atk := base_atk(uid)
	var def := base_def(uid)
	var parts := ["Base %d/%d" % [atk, def]]
	var no_gain := has_flag(uid, "no_gain")
	var sw: bool = swapped.has(uid) and inst["zone"] == "unit"
	var later_atk := 0
	var later_def := 0
	var later_parts := []
	for m in inst["mods"]:
		var ma: int = m["atk"]
		var md: int = m["def"]
		if no_gain:
			ma = mini(ma, 0)
			md = mini(md, 0)
		var part := "%s %+d/%+d%s" % [m.get("src", "effect"), ma, md, " (this turn)" if m["until"] == "turn" else ""]
		if sw and not m.get("pre_swap", false):
			later_atk += ma
			later_def += md
			if ma != 0 or md != 0:
				later_parts.append(part)
			continue
		atk += ma
		def += md
		if ma != 0 or md != 0:
			parts.append(part)
	if sw:
		var t := atk
		atk = def
		def = t
		parts.append("Freaky Funday: ATK/DEF switched")
	atk += later_atk
	def += later_def
	parts += later_parts
	if inst["zone"] == "unit":
		for aura in CardScripts.auras_for(self, uid):
			var aa: int = aura["atk"]
			var ad: int = aura["def"]
			if swap_active():
				var ta := aa
				aa = ad
				ad = ta
			if reversal_active():
				aa = -aa
				ad = -ad
			if no_gain:
				aa = mini(aa, 0)
				ad = mini(ad, 0)
			atk += aa
			def += ad
			if aa != 0 or ad != 0:
				parts.append("%s %+d/%+d%s" % [aura["src"], aa, ad, " (reversed)" if reversal_active() else ""])
	return {"atk": maxi(atk, 0), "def": maxi(def, 0), "parts": parts}


## Current ATK of unit uid.
func atk_of(uid: int) -> int:
	return stat_breakdown(uid)["atk"]


## Current DEF of unit uid.
func def_of(uid: int) -> int:
	return stat_breakdown(uid)["def"]


## Snow Tiger Paladin (190): player p's "until the start of your next turn" effects.
const TFX_TRAPS_COST_LESS := "traps_cost_less"
const TFX_TRAPS_INDESTRUCTIBLE := "traps_indestructible"


## Starts player p's effect `effect` now; it lasts until the start of p's next turn.
func start_turn_effect(p: int, effect: String) -> void:
	if not players[p].has("turn_fx"):
		players[p]["turn_fx"] = {}
	players[p]["turn_fx"][effect] = turn


## True while player p's effect `effect` lasts: from the turn it was applied until the start of
## p's next turn (turns alternate, so two turns later).
func turn_effect_active(p: int, effect: String) -> bool:
	var t: int = int(players[p].get("turn_fx", {}).get(effect, -1))
	return t != -1 and turn >= t and turn < t + 2


## Current ordinary AP cost (floored at zero). Extra-deck cards return -1 (no ordinary cost).
func current_cost(uid: int) -> int:
	var df := d(uid)
	if df["cost_kind"] != "ap":
		return -1
	var inst: Dictionary = cards[uid]
	var v: int = df["cost"] + inst["cost_p"]
	for m in inst["cost_t"]:
		if m["turn"] == turn:
			v += m["n"]
	var p: int = inst["owner"]
	var cat: String = df["category"]
	if cat == "spell" and player_has_flag(p, "spells_cost_less"):
		v -= 1
	if cat == "trap" and player_has_flag(p, "traps_cost_less"):
		v -= 1
	if cat == "trap" and turn_effect_active(p, TFX_TRAPS_COST_LESS):
		v -= 1                            # Snow Tiger Paladin, Protecting a Unit (stacks with the Guild)
	# Reinforcements (2026-10-18): -2 AP while only the opponent controls a unit.
	if CardDB.is_unit_category(cat) and player_has_flag(p, "units_cost_less_if_behind") \
			and field_units(p).is_empty() and not field_units(opp(p)).is_empty():
		v -= 2
	return maxi(v, 0)


## Current Ritual (Runes needed) or Arcane (exact Spent total) cost: the printed cost plus the
## card's permanent and this-turn cost changes, floored at zero. Owner rule 2026-10-18: cards that
## raise another card's cost (Shimmer Serum) raise these costs too. null for a "?" Ritual cost
## (any number of Runes); -1 for every other kind of card.
func extra_cost(uid: int) -> Variant:
	var df := d(uid)
	if not (df["cost_kind"] in ["ritual", "arcane"]):
		return -1
	if df["cost"] == null:
		return null
	var inst: Dictionary = cards[uid]
	var v: int = int(df["cost"]) + inst["cost_p"]
	for m in inst["cost_t"]:
		if m["turn"] == turn:
			v += m["n"]
	return maxi(v, 0)


## Printed cost label using the current cost where it applies.
func cost_text(uid: int) -> String:
	var kind: String = d(uid)["cost_kind"]
	return CardDB.cost_label(d(uid), extra_cost(uid) if kind in ["ritual", "arcane"] else current_cost(uid))


# ---------------------------------------------------------------- statuses

## True if uid has any buff.
func has_any_buff(uid: int) -> bool:
	for s in cards[uid]["st"]:
		if CardDB.is_buff(s) and cards[uid]["st"][s] > 0:
			return true
	return false


## True if uid has any debuff.
func has_any_debuff(uid: int) -> bool:
	for s in cards[uid]["st"]:
		if CardDB.is_debuff(s) and cards[uid]["st"][s] > 0:
			return true
	return false


## Stacks of status s on uid.
func status_count(uid: int, s: String) -> int:
	if s == "rune":
		return cards[uid]["runes"]
	return cards[uid]["st"].get(s, 0)


func _set_status(uid: int, s: String, n: int) -> void:
	if s == "rune":
		cards[uid]["runes"] = maxi(n, 0)
		return
	if n <= 0:
		cards[uid]["st"].erase(s)
	else:
		cards[uid]["st"][s] = n


func _clear_statuses_of_class(uid: int, buffs: bool) -> Array:
	var removed := []
	for s in cards[uid]["st"].keys():
		if (buffs and CardDB.is_buff(s)) or (not buffs and CardDB.is_debuff(s)):
			removed.append(s)
			cards[uid]["st"].erase(s)
	return removed


## Applies n stacks of a status, honouring Curse/Cleanse prevention and Cleanse
## clearing. Runes are counters and bypass both. Returns the stacks actually added.
func apply_status(uid: int, s: String, n: int) -> int:
	if n <= 0 or not cards.has(uid):
		return 0
	if s == "rune":
		_set_status(uid, "rune", status_count(uid, "rune") + n)
		card_log(uid, "§ gains %d Rune (now %d)." % [n, status_count(uid, "rune")])
		var rpos := fx_pos(uid)
		if not rpos.is_empty():
			add_fx({"k": "status", "at": rpos, "s": "rune", "n": n})
		return n
	if CardDB.is_buff(s) and has_flag(uid, "no_buffs"):
		card_log(uid, "§ cannot receive Buffs.")
		return 0
	if CardDB.is_buff(s) and status_count(uid, "curse") > 0 and s != "cleanse":
		_set_status(uid, "curse", status_count(uid, "curse") - 1)
		card_log(uid, "Curse on § prevents %s (Curse -1)." % s.capitalize())
		return 0
	if s == "cleanse" and status_count(uid, "curse") > 0:
		_set_status(uid, "curse", status_count(uid, "curse") - 1)
		card_log(uid, "Curse on § prevents Cleanse (Curse -1).")
		return 0
	if CardDB.is_debuff(s) and status_count(uid, "cleanse") > 0 and s != "curse":
		_set_status(uid, "cleanse", status_count(uid, "cleanse") - 1)
		card_log(uid, "Cleanse on § prevents %s (Cleanse -1)." % s.capitalize())
		return 0
	if s == "curse" and status_count(uid, "cleanse") > 0:
		_set_status(uid, "cleanse", status_count(uid, "cleanse") - 1)
		card_log(uid, "Cleanse on § prevents Curse (Cleanse -1).")
		return 0
	_set_status(uid, s, status_count(uid, s) + n)
	card_log(uid, "§ gains %d %s (now %d)." % [n, s.capitalize(), status_count(uid, s)])
	var pos := fx_pos(uid)
	if not pos.is_empty():
		add_fx({"k": "status", "at": pos, "s": s, "n": n})
	_after_status_gain(uid, s)
	return n


## Cleanse clears all existing debuffs when gained (consuming one stack);
## Curse clears all existing buffs when gained (consuming one stack).
func _after_status_gain(uid: int, s: String) -> void:
	if s == "cleanse" and has_any_debuff(uid):
		var removed := _clear_statuses_of_class(uid, false)
		_set_status(uid, "cleanse", status_count(uid, "cleanse") - 1)
		card_log(uid, "Cleanse removes %s from § (Cleanse -1)." % ", ".join(removed))
	elif s == "curse" and has_any_buff(uid):
		var removed := _clear_statuses_of_class(uid, true)
		_set_status(uid, "curse", status_count(uid, "curse") - 1)
		card_log(uid, "Curse removes %s from § (Curse -1)." % ", ".join(removed))


## True when player p's deck (every card they own, wherever it is) has a printed 0-cost card.
func _deck_has_zero_cost(p: int) -> bool:
	for u in cards:
		var inst: Dictionary = cards[u]
		if inst["owner"] == p and d(u)["cost_kind"] == "ap" and d(u)["cost"] == 0:
			return true
	return false


## Persistent (this game) cost change; floored so the card's cost never goes below zero.
## `private_log`: the card is hidden from the opponent (a set card destroyed face down), so only
## its owner reads which card it was.
func change_cost_perm(uid: int, n: int, private_log: bool = false) -> void:
	var df := d(uid)
	var printed: int = df["cost"] if df["cost"] != null else 0
	var before: int = cards[uid]["cost_p"]
	cards[uid]["cost_p"] = maxi(before + n, -printed)
	var text := "%s's cost changes by %+d for the rest of this game (now %d)." % [name_of(uid), cards[uid]["cost_p"] - before, maxi(printed + cards[uid]["cost_p"], 0)]
	if private_log:
		add_log("", {cards[uid]["owner"]: text})
	else:
		add_log(text)


## Removes n stacks of status s from uid.
func decrement_status(uid: int, s: String, n: int = 1) -> void:
	_set_status(uid, s, status_count(uid, s) - n)


# ---------------------------------------------------------------- HP and AP

## Changes HP: a negative amount is Damage taken, a positive one is Healing (2026-10-18 wording).
## Returns true if the game ended. Immediate defeat at zero.
func change_hp(p: int, amount: int, reason: String) -> bool:
	if amount == 0 or winner != -1:
		return winner != -1
	players[p]["hp"] += amount
	if amount < 0:
		add_log("%s takes %d Damage%s (HP %d)." % [pname(p), -amount, reason, players[p]["hp"]])
	else:
		add_log("%s heals %d HP%s (HP %d)." % [pname(p), amount, reason, players[p]["hp"]])
	add_fx({"k": "hp", "p": p, "d": amount})
	note("hp", {"p": p, "d": amount})
	if players[p]["hp"] <= 0:
		players[p]["hp"] = 0
		end_game(opp(p), "%s reached 0 HP" % pname(p))
		return true
	return false


## Ends the game with winner win for the given reason.
func end_game(win: int, reason: String) -> void:
	if winner != -1:
		return
	winner = win
	phase = PHASE_OVER
	note("game_over", {"winner": win, "reason": reason})
	add_log("GAME OVER: %s Wins" % pname(win))   # D7: no reason in the log; the event keeps it
	add_fx({"k": "game_over", "winner": win})
	_on_game_over()


func _on_game_over() -> void:
	pass


## Changes player p's AP by amount and logs the reason.
func change_ap(p: int, amount: int, reason: String) -> void:
	if amount == 0:
		return
	players[p]["ap"] = maxi(players[p]["ap"] + amount, 0)
	players[p]["ap_peak"] = maxi(players[p].get("ap_peak", 0), players[p]["ap"])
	add_log("%s %s %d AP%s (AP %d)." % [pname(p), "gains" if amount > 0 else "loses", absi(amount), reason, players[p]["ap"]])
	add_fx({"k": "ap", "p": p, "d": amount})


# ---------------------------------------------------------------- zone movement

func _remove_from_zone(uid: int) -> void:
	var inst: Dictionary = cards[uid]
	var p: int = inst["ctl"] if inst["zone"] in ["unit", "backrow", "power"] else inst["owner"]
	match inst["zone"]:
		"unit":
			players[p]["units"][inst["slot"]] = -1
		"backrow":
			players[p]["backrow"][inst["slot"]] = -1
		"power":
			players[p]["powers"][inst["slot"]] = -1
		"hand", "draw", "spent", "exhaust", "extra":
			if inst["zone"] == "hand":
				note("hand_exit", {"uid": uid})
			players[inst["owner"]][inst["zone"]].erase(uid)
	inst["slot"] = -1


## Resets field-only state when a card leaves Field. Persistent cost changes survive.
func _reset_field_state(uid: int) -> void:
	var inst: Dictionary = cards[uid]
	swapped.erase(uid)                 # back on the Field later it is a new card
	inst["st"] = {}
	inst["runes"] = 0
	inst["mods"] = []
	inst["opt"] = {}
	inst["type_o"] = null
	inst["race_o"] = null
	inst["base_atk"] = null
	inst["base_def"] = null
	inst["stance"] = "atk"
	inst["face_up"] = false
	inst["ctl"] = inst["owner"]
	inst["control_until"] = -1
	inst.erase("control_slot")
	inst.erase("runes_used")
	# Mirrorflesh / Ultimate Dragon read the Units Tributed for *this* Fusion Summon only.
	inst.erase("fusion_mats")


## Moves a card to a pile ("hand", "draw", "draw_top", "spent", "exhaust", "extra").
## Extra-deck cards sent to Hand/Draw go back to the Extra Deck instead (P-17 style).
func move_to_pile(uid: int, dest: String) -> void:
	var inst: Dictionary = cards[uid]
	var was_field := on_field(uid)
	var from_zone: String = inst["zone"]
	if inst["zone"] == "hand" and dest != "hand":
		inst["st"] = {}
	# Energy Dispel (2026-10-18): "If this Trap is sent from Field to Spent, this Trap Permanently
	# costs +1AP" (used or destroyed alike).
	if was_field and dest == "spent" and CardScripts.get_entry(inst["id"]).get("flags", []).has("cost_up_on_spent"):
		change_cost_perm(uid, 1, inst["zone"] == "backrow" and not is_face_up(uid))
	if was_field and inst["zone"] == "unit":
		inst["orig_slot"] = inst["slot"]
	_remove_from_zone(uid)
	if was_field:
		_reset_field_state(uid)
	var owner: int = inst["owner"]
	if dest in ["hand", "draw", "draw_top"] and is_extra(uid):
		dest = "extra"
	match dest:
		"draw_top":
			players[owner]["draw"].append(uid)  # top of Draw = end of array
			inst["zone"] = "draw"
		"draw":
			var pos := rng.randi_range(0, players[owner]["draw"].size())
			players[owner]["draw"].insert(pos, uid)
			inst["zone"] = "draw"
		_:
			players[owner][dest].append(uid)
			inst["zone"] = dest
	if dest == "hand" and from_zone != "hand":
		note("to_hand", {"uid": uid, "from": from_zone})
	inst["face_up"] = false
	inst["slot"] = -1


## Puts unit uid in slot for player p with the given stance.
func place_unit(uid: int, p: int, slot: int, stance: String) -> void:
	_remove_from_zone(uid)
	var inst: Dictionary = cards[uid]
	inst["zone"] = "unit"
	inst["slot"] = slot
	inst["ctl"] = p
	inst["stance"] = stance
	inst["face_up"] = true
	inst["summoned_turn"] = turn
	# B3 (owner feedback 2026-10-20): a unit summoned in its controller's Recovery Phase may still
	# change stance in that phase (it entered in Attack stance without a choice).
	inst["summoned_phase"] = phase
	players[p]["units"][slot] = uid


## Moves unit uid to another slot.
func move_unit_slot(uid: int, slot: int) -> void:
	var inst: Dictionary = cards[uid]
	players[inst["ctl"]]["units"][inst["slot"]] = -1
	players[inst["ctl"]]["units"][slot] = uid
	inst["slot"] = slot


## Shuffles arr in place with the game rng.
func shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## Draws up to n cards; recycles Spent when Draw is empty. Missing draws are skipped.
func draw_cards(p: int, n: int) -> Array:
	var drawn := []
	for i in range(n):
		if players[p]["draw"].is_empty():
			recycle_spent(p)
		if players[p]["draw"].is_empty():
			# C-04 (user): each draw that cannot be made costs fatigue HP (configurable).
			var missing := n - i
			var per: int = int(config.get("fatigue_damage", 2))
			add_log("%s has no cards to draw (%d draw%s missed)." % [pname(p), missing, "" if missing == 1 else "s"])
			if per > 0:
				change_hp(p, -per * missing, " (fatigue)")
			break
		var uid: int = players[p]["draw"].pop_back()
		cards[uid]["zone"] = "hand"
		players[p]["hand"].append(uid)
		drawn.append(uid)
		note("draw", {"p": p, "uid": uid})
	if not drawn.is_empty():
		var names := ", ".join(drawn.map(func(u): return name_of(u)))
		add_log("%s draws %d card%s." % [pname(p), drawn.size(), "" if drawn.size() == 1 else "s"],
			{p: "You draw %d: %s." % [drawn.size(), names]})
		add_fx({"k": "draw", "p": p, "n": drawn.size()})
	return drawn


## Shuffles Spent into Draw; Fusion/Ritual/Arcane cards return to the Extra Deck.
func recycle_spent(p: int) -> void:
	var spent: Array = players[p]["spent"].duplicate()
	if spent.is_empty():
		return
	var to_extra := 0
	for uid in spent:
		players[p]["spent"].erase(uid)
		if is_extra(uid):
			players[p]["extra"].append(uid)
			cards[uid]["zone"] = "extra"
			to_extra += 1
		else:
			players[p]["draw"].append(uid)
			cards[uid]["zone"] = "draw"
	shuffle_array(players[p]["draw"])
	add_log("%s recycles Spent: %d into Draw, %d to Extra Deck." % [pname(p), spent.size() - to_extra, to_extra])
