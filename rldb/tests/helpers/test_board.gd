class_name TB
extends RefCounted
## Factory helpers for building deterministic board states in rules tests.

const FILLER := 1          # Basic Mage (Water) 8/8
const WATER := 1           # Basic Mage (Water)
const FIRE := 110          # Basic Mage (Fire)
const EARTH := 120         # Basic Mage (Earth)
const PHYSICAL := 115      # Basic Mage (Physical)


## A fresh match with filler decks. Player 0 starts. Turn 1 is in Main Phase 1.
static func make(seed_value: int = 7, deck_size: int = 20, hidden_windows: bool = false) -> MatchEngine:
	var m := MatchEngine.new()
	var deck := []
	for i in deck_size:
		deck.append(FILLER)
	# Rules tests open trap windows only when a Trap is eligible; the hidden-window
	# behaviour (prompt whenever a face-down card exists) has its own tests.
	m.setup([deck.duplicate(), deck.duplicate()], 0, seed_value, {"hidden_response_windows": hidden_windows})
	return m


## Advances to turn 2 (player 1 active, Main Phase 1), where battle is legal.
static func to_turn2(m: MatchEngine) -> void:
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})


static func to_battle(m: MatchEngine) -> void:
	if m.turn < 2:
		to_turn2(m)
	assert(m.submit(m.active, {"t": "next_phase"}) == "")


## Creates a card of `id` for player p in the given zone; returns its uid.
static func card(m: MatchEngine, p: int, id: int, zone: String = "hand") -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = zone
	m.players[p][zone].append(uid)
	return uid


## Places a unit directly on the field (summoned on an earlier turn by default).
static func unit(m: MatchEngine, p: int, id: int, slot: int, stance: String = "atk", atk = null, def = null, new_this_turn: bool = false) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, stance)
	m.cards[uid]["summoned_turn"] = m.turn if new_this_turn else m.turn - 1
	if atk != null:
		m.cards[uid]["base_atk"] = atk
	if def != null:
		m.cards[uid]["base_def"] = def
	return uid


static func set_card(m: MatchEngine, p: int, id: int, col: int) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "backrow"
	m.cards[uid]["slot"] = col
	m.cards[uid]["ctl"] = p
	m.cards[uid]["set_turn"] = m.turn - 1
	m.players[p]["backrow"][col] = uid
	return uid


static func power(m: MatchEngine, p: int, id: int, slot: int = 0) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "power"
	m.cards[uid]["slot"] = slot
	m.cards[uid]["face_up"] = true
	m.players[p]["powers"][slot] = uid
	return uid


## Answers the pending choice by picking options whose label contains each text.
static func choose(m: MatchEngine, texts: Array) -> String:
	var pd := m.pending
	if pd.is_empty():
		return "no pending choice"
	var idx := []
	for t in texts:
		var found := -1
		for i in pd["options"].size():
			if String(pd["options"][i]["label"]).contains(t) and not (i in idx):
				found = i
				break
		if found == -1:
			return "option not found: %s in %s" % [t, pd["options"].map(func(o): return o["label"])]
		idx.append(found)
	return m.submit(pd["player"], {"t": "choose", "id": pd["id"], "indices": idx})


## Answers the pending choice with specific uids (values).
static func choose_uids(m: MatchEngine, uids: Array) -> String:
	var pd := m.pending
	if pd.is_empty():
		return "no pending choice"
	return m.submit(pd["player"], {"t": "choose", "id": pd["id"], "values": uids})


static func attack(m: MatchEngine, attacker: int, target: int) -> String:
	var e := m.submit(m.cards[attacker]["ctl"], {"t": "attack", "uid": attacker})
	if e != "":
		return e
	if m.pending.get("kind", "") == "attack_target":
		return choose_uids(m, [target])
	return ""


static func slot_label(slot: int) -> String:
	return "%s row, column %d" % ["Front" if slot < 3 else "Back", slot % 3 + 1]


## Summons `id` from Hand through the real command flow (with plenty of AP).
static func summon(m: MatchEngine, p: int, id: int, slot: int, stance: String = "Attack") -> int:
	var uid := card(m, p, id)
	m.players[p]["ap"] = 20
	var e := m.submit(p, {"t": "summon", "uid": uid})
	assert(e == "", e)
	assert(choose(m, [slot_label(slot)]) == "")
	if m.pending.get("kind", "") == "stance":
		choose(m, [stance])
	return uid


## Casts a Spell from Hand through the real command flow (with plenty of AP).
static func cast(m: MatchEngine, p: int, id: int) -> int:
	var uid := card(m, p, id)
	m.players[p]["ap"] = 20
	var e := m.submit(p, {"t": "cast", "uid": uid})
	assert(e == "", e)
	return uid


static func ability(m: MatchEngine, uid: int, idx: int = 0) -> String:
	m.players[m.cards[uid]["ctl"]]["ap"] = maxi(m.players[m.cards[uid]["ctl"]]["ap"], 5)
	return m.submit(m.cards[uid]["ctl"], {"t": "ability", "uid": uid, "idx": idx})


## Destroys a field card by an effect from player `by` and resolves triggers.
static func kill(m: MatchEngine, uid: int, by: int = -1) -> void:
	m.destroy(uid, "effect", -1, by if by != -1 else 1 - m.cards[uid]["ctl"])
	m.run()


## Puts a unit (any category) onto the Field as a summon and resolves its On Summon triggers.
static func special(m: MatchEngine, p: int, id: int, slot: int, stance: String = "atk") -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, stance)
	m.emit("summoned", {"self": uid, "ctl": p, "player": p})
	m.run()
	return uid


## Makes it player 1's turn 2 in the Battle Phase.
static func p1_battle(m: MatchEngine) -> void:
	to_turn2(m)
	to_battle(m)


static func pend_kind(m: MatchEngine) -> String:
	return m.pending.get("kind", "")


static func log_text(m: MatchEngine) -> String:
	return "\n".join(m.log_entries.map(func(e): return e["pub"]))


static func log_index(m: MatchEngine, needle: String) -> int:
	for i in m.log_entries.size():
		if String(m.log_entries[i]["pub"]).contains(needle):
			return i
	return -1
