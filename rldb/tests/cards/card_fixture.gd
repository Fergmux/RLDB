class_name CF
extends RefCounted
## Deterministic per-card fixtures (F26). Builds on TB (tests/helpers/test_board.gd): every
## match uses a fixed seed and filler decks, and boards are placed directly so no shuffle,
## draw or bot decision influences a card's assertions.
##
## Conventions used by tests/cards/*_test.gd:
##   - player 0 starts; turn 1 is player 0's Main Phase 1 (no battle on turn 1).
##   - `p1_main()` / `p1_battle()` give player 1 an active turn with player 0 as the responder,
##     which is how Trap tests get an opponent to trigger player 0's set Trap.
##   - a test name carries its card id(s): `test_cNNN_...`; a shared test lists its ids in a
##     `# @cards 1,2,3` comment on the line directly above `func`. tools/card_test_manifest.py
##     turns those into tests/cards/manifest.json.

const SEED := 7


## A fresh deterministic match (player 0 active, Main Phase 1, turn 1).
static func make() -> MatchEngine:
	return TB.make(SEED)


## Player 1's turn 2, Main Phase 1.
static func p1_main() -> MatchEngine:
	var m := TB.make(SEED)
	TB.to_turn2(m)
	return m


## Player 1's turn 2, Battle Phase.
static func p1_battle() -> MatchEngine:
	var m := p1_main()
	TB.to_battle(m)
	return m


static func zone(m: MatchEngine, uid: int) -> String:
	return String(m.cards[uid]["zone"])


static func hp(m: MatchEngine, p: int) -> int:
	return int(m.players[p]["hp"])


static func ap(m: MatchEngine, p: int) -> int:
	return int(m.players[p]["ap"])


## Declines an optional single-target choice ("Skip") or a Yes/No prompt ("No").
static func decline(m: MatchEngine) -> String:
	var pd := m.pending
	if pd.is_empty():
		return "no pending choice"
	for o in pd["options"]:
		if String(o["label"]) in ["Skip", "No", "Pass"] or String(o["label"]).begins_with("Pass"):
			return TB.choose(m, [String(o["label"])])
	return "no decline option in %s" % [pd["options"].map(func(o): return o["label"])]


## The uids offered by the pending choice (Skip/Pass entries excluded).
static func offered(m: MatchEngine) -> Array:
	if m.pending.is_empty():
		return []
	var out := []
	for o in m.pending["options"]:
		if o.has("uid") and int(o["uid"]) != -1:
			out.append(int(o["uid"]))
	return out


## The labels of the pending choice.
static func labels(m: MatchEngine) -> Array:
	if m.pending.is_empty():
		return []
	return m.pending["options"].map(func(o): return String(o["label"]))


## Ends the active player's turn (passing every phase) and resolves start-of-turn triggers.
static func end_turn(m: MatchEngine) -> void:
	var p := m.active
	var guard := 0
	while m.active == p and m.winner == -1 and guard < 10:
		if not m.pending.is_empty():
			return
		m.submit(p, {"t": "next_phase"})
		guard += 1


## True when the cards `mats` (uids) satisfy the Fusion unit `fusion_id`'s material list in
## some order -- the engine's own assignment rule, without starting a summon flow.
static func fusion_mats_ok(m: MatchEngine, fusion_id: int, mats: Array) -> bool:
	var reqs: Array = CardScripts.get_entry(fusion_id).get("fusion", [])
	return reqs.size() == mats.size() and m._assignable(reqs, mats, [])


## Card ids of every Basic Unit in the catalogue (35 at the time of writing).
static func basic_ids() -> Array:
	var out := []
	for d in CardDB.all():
		if d["category"] == "basic_unit":
			out.append(int(d["id"]))
	out.sort()
	return out
