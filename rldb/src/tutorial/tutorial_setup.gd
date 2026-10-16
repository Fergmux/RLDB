class_name TutorialSetup
extends RefCounted
## Builds a tutorial lesson's deterministic premade game (F03-15) directly into a real
## MatchEngine: fixed card instances in fixed zones, a fixed Draw order and no shuffle, then the
## learner's turn is started by the engine's own start-of-turn (reset AP, draw four), so every
## rule after that is the real rules engine. Never used by normal play.

## Fixed rng seed: uids and any engine randomness are the same on every (re)start.
const SEED := 20261016


## Builds lesson `lesson` (TutorialLessons format). Returns {"match": MatchEngine, "keys": {key: uid}}.
static func build(lesson: Dictionary) -> Dictionary:
	CardDB.ensure_loaded()
	var spec: Dictionary = lesson["setup"]
	var m := MatchEngine.new()
	m.config = {"names": TutorialLessons.NAMES.duplicate(), "start_hp": TutorialLessons.START_HP,
		"hidden_response_windows": false, "fatigue_damage": 2}
	m.rng.seed = SEED
	m.players = [m._new_player(0), m._new_player(1)]
	for p in 2:
		m.players[p]["name"] = TutorialLessons.NAMES[p]
		m.players[p]["hp"] = int(spec.get("hp", [TutorialLessons.START_HP, TutorialLessons.START_HP])[p])
	var me := TutorialLessons.PLAYER
	var turn: int = int(spec["turn"])
	var keys := {}
	var hand_top := [[], []]     # per player: drawn by the start of the learner's turn (in order)
	var draw_rest := [[], []]    # per player: drawn later (in order)
	for e in spec["cards"]:
		var p: int = int(e["p"])
		var uid := m._create_instance(int(e["id"]), p)
		keys[String(e["key"])] = uid
		var inst: Dictionary = m.cards[uid]
		match String(e["zone"]):
			"hand":
				hand_top[p].append(uid)
			"draw":
				draw_rest[p].append(uid)
			"unit":
				inst["zone"] = "limbo"
				m.place_unit(uid, p, int(e["slot"]), String(e.get("stance", "atk")))
				inst["summoned_turn"] = maxi(0, turn - 2)     # on the field since an earlier turn
				inst["orig_slot"] = int(e["slot"])
				inst["runes"] = int(e.get("runes", 0))
			"backrow":
				inst["zone"] = "backrow"
				inst["slot"] = int(e["slot"])
				inst["set_turn"] = maxi(0, turn - 2)
				m.players[p]["backrow"][int(e["slot"])] = uid
			"extra":
				inst["zone"] = "extra"
				m.players[p]["extra"].append(uid)
			"spent":
				inst["zone"] = "spent"
				inst["face_up"] = true
				m.players[p]["spent"].append(uid)
			_:
				push_error("TutorialSetup: unknown zone %s" % e["zone"])
	# Draw takes from the back: the last element is drawn first.
	for p in 2:
		var order: Array = hand_top[p] + draw_rest[p] if p == me else draw_rest[p].duplicate()
		order.reverse()
		m.players[p]["draw"] = order
	# The opponent does not draw before the learner's turn: its Hand cards start in its Hand.
	for uid in hand_top[1 - me]:
		m.cards[uid]["zone"] = "hand"
		m.players[1 - me]["hand"].append(uid)
	m.first_turn_player = int(spec.get("first", me))
	m.add_log("Tutorial: %s." % lesson["title"])
	# The turn before the learner's turn belongs to the opponent; the engine then starts the
	# learner's turn exactly as in a real game.
	m.turn = turn - 1
	m.active = 1 - me
	m._start_turn(me)
	return {"match": m, "keys": keys}
