class_name BotCards
extends RefCounted
## L27: how the bot rates cards outside a game (draft picks, add-card rewards, removals). A rough,
## public rating from the card definition: a unit by its stats for its AP cost plus a bonus for
## having an effect; an Extra Deck unit by its stats, discounted because it needs materials; a
## Spell, Trap or Power by its cost. Only implemented cards are ever offered.

## Smallest main deck the bot thins its deck down to with "remove a card" rewards.
const MIN_MAIN := 12
## A card is only removed when it rates this far below the deck's average.
const REMOVE_GAP := 2.0


## Rating of card `id` (higher is better).
static func rating(id: int) -> float:
	var d := CardDB.get_def(id)
	var cat: String = d["category"]
	var effect := 0.0
	var entry := CardScripts.get_entry(id)
	if not entry.is_empty():
		effect = 3.0 if String(entry.get("impl", "full")) == "full" else 1.5
	if cat in ["basic_unit", "unit"]:
		var stats := float(d["atk"] if d["atk"] != null else 10) + 0.7 * float(d["def"] if d["def"] != null else 10)
		var cost := float(d["cost"] if d["cost"] != null else 1)
		return stats / (1.0 + 0.5 * cost) + effect
	if CardDB.is_extra_category(cat):
		var st2 := float(d["atk"] if d["atk"] != null else 20) + 0.7 * float(d["def"] if d["def"] != null else 20)
		return 0.45 * st2 + effect
	var c := float(d["cost"] if d["cost"] != null else 1)
	return 9.0 - 1.2 * c + effect


## Index of the best card id in `offer` (ties broken by a little seeded jitter). `deck`: the cards
## already held; an Extra Deck card is worth less when the deck already has several.
static func best_index(offer: Array, deck: Array, rng: RandomNumberGenerator) -> int:
	var extras := 0
	for id in deck:
		if CardDB.is_extra_category(CardDB.get_def(int(id))["category"]):
			extras += 1
	var best := 0
	var best_v := -INF
	for i in offer.size():
		var id := int(offer[i])
		var v := rating(id) + rng.randf() * 1.5
		if CardDB.is_extra_category(CardDB.get_def(id)["category"]):
			v -= 1.5 * maxf(0.0, float(extras) - 2.0)
		if v > best_v:
			best_v = v
			best = i
	return best


## The card id a "remove a card" reward should take out of `deck`, or -1 to keep the deck: the
## weakest main-deck card, when the main deck is larger than MIN_MAIN and that card rates well
## below the deck's average.
static func removal(deck: Array) -> int:
	var main := []
	for id in deck:
		if not CardDB.is_extra_category(CardDB.get_def(int(id))["category"]):
			main.append(int(id))
	if main.size() <= MIN_MAIN:
		return -1
	var total := 0.0
	var worst := -1
	var worst_v := INF
	for id in main:
		var v := rating(id)
		total += v
		if v < worst_v:
			worst_v = v
			worst = id
	if worst_v > total / float(main.size()) - REMOVE_GAP:
		return -1
	return worst


## Card type of an add-card reward: mostly Units (the board wins games), else Spells, Traps,
## Powers, or Extra Deck cards while the deck has few.
static func reward_category(deck: Array, rng: RandomNumberGenerator) -> String:
	var extras := 0
	for id in deck:
		if CardDB.is_extra_category(CardDB.get_def(int(id))["category"]):
			extras += 1
	var bag := ["unit", "unit", "unit", "unit", "spell", "trap", "power"]
	if extras < 4:
		bag.append("extra")
	return bag[rng.randi_range(0, bag.size() - 1)]
