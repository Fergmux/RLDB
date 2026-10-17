class_name CardScripts
extends RefCounted
## Declarative behaviour for every card, keyed by stable card id.
## Each entry may contain:
##   flags:     passive keywords checked by the engine (e.g. "direct_attack")
##   on:        triggered abilities [{when, scope, text, filter, ops}]
##   abilities: manual abilities [{label, opt (once per turn), cost {ap, hp}, cond, ops}]
##   spell:     ops resolved when the Spell is cast/activated
##   trap:      {when, column, power_only, by_effect, by_opponent, cond, ops}
##   aura:      continuous stat modifiers [{to, atk, def, cond, filter}]
##   fusion:    material requirements, one dict per material
##   impl:      "full" | "partial"; notes: why partial
## Cards absent from the table (other than effectless Basic Units) are UNIMPLEMENTED
## and are shown as such in the UI and the support ledger.

static var _table: Dictionary = {}


static func get_entry(id: int) -> Dictionary:
	if _table.is_empty():
		_table = _build()
	return _table.get(id, {})


static func is_implemented(id: int) -> bool:
	var d := CardDB.get_def(id)
	if d["category"] == "basic_unit":
		return true
	return not get_entry(id).is_empty()


static func support_status(id: int) -> String:
	var d := CardDB.get_def(id)
	if d["category"] == "basic_unit":
		return "full"
	var e := get_entry(id)
	if e.is_empty():
		return "unimplemented"
	return e.get("impl", "full")


## Continuous stat modifiers currently applying to unit `uid`. Recomputed on every read.
static func auras_for(g, uid: int) -> Array:
	var out := []
	var p: int = g.cards[uid]["ctl"]
	for p2 in [0, 1]:
		for src in g.field_units(p2) + g.power_cards(p2):
			if g.is_debilitated(src):
				continue
			var entry := get_entry(g.cards[src]["id"])
			for a in entry.get("aura", []):
				if _aura_applies(g, src, uid, a):
					var f: Dictionary = g.make_frame(src, p2, [], "")
					out.append({"atk": g.eval_num(f, a.get("atk", 0)), "def": g.eval_num(f, a.get("def", 0)), "src": g.name_of(src)})
	return out


static func _aura_applies(g, src: int, uid: int, a: Dictionary) -> bool:
	var sp: int = g.cards[src]["ctl"]
	var f: Dictionary = g.make_frame(src, sp, [], "")
	if a.has("cond") and not g.eval_cond(f, a["cond"]):
		return false
	match a["to"]:
		"self":
			if uid != src: return false
		"adjacent":
			if g.cards[src]["zone"] != "unit" or not (uid in g.adjacent_units(src)): return false
		"protector":
			if g.protector_of(src) != uid: return false
		"protector_dragon":
			if g.protector_of(src) != uid or g.unit_race(uid) != "Dragon": return false
		"own_units":
			if g.cards[uid]["ctl"] != sp: return false
		"opp_units":
			if g.cards[uid]["ctl"] == sp: return false
	if a.has("filter") and not g._matches(f, uid, a["filter"]):
		return false
	return true


# ---------------------------------------------------------------- op helpers

static func ch(sel: Dictionary, as_name: String = "t", optional: bool = false, prompt: String = "") -> Dictionary:
	var op := {"op": "choose", "sel": sel, "as": as_name, "optional": optional}
	if prompt != "":
		op["prompt"] = prompt
	return op


static func st(target, s: String, n = 1) -> Dictionary:
	return {"op": "status", "target": target, "s": s, "n": n}


## Status on "the Unit that Destroyed it": skipped when the destroyer was not a unit on the Field.
static func by_unit_st(s: String, n) -> Dictionary:
	return {"op": "status", "target": "event.by", "s": s, "n": n, "unit_only": true}


static func all_(sel: Dictionary, as_name: String = "all") -> Dictionary:
	return {"op": "all", "sel": sel, "as": as_name}


static func yes(prompt: String) -> Dictionary:
	return {"op": "confirm", "prompt": prompt}


static func need(var_name: String) -> Dictionary:
	return {"op": "require", "var": var_name}


static func hp(who: String, n) -> Dictionary:
	return {"op": "hp", "who": who, "n": n}


static func trig(when: String, ops: Array, scope: String = "self", text: String = "") -> Dictionary:
	return {"when": when, "ops": ops, "scope": scope, "text": text if text != "" else when.replace("_", " ")}


static func abil(label: String, ops: Array, opt: bool = true, cost: Dictionary = {}) -> Dictionary:
	return {"label": label, "ops": ops, "opt": opt, "cost": cost}


static func tag_team(ops: Array) -> Array:
	return [{"op": "require", "cond": {"other_in_column": true}}] + ops


## Short on-card button labels for activated abilities (F02-04). The full label stays in
## the card details. Unlisted labels fall back to a derived "Apply <Status>" / prefix form.
const SHORT_LABELS := {
	"Pay 2 AP: summon a unit from your Spent in this column": "Revive (2 AP)",
	"Change this unit's Type: all Mage units follow": "Change Type",
	"Apply 6 Burn to a unit": "Apply Burn",
	"Apply 1 Pierce to a unit": "Apply Pierce",
	"Lose 10 HP: +10 ATK or destroy a face-down card": "Blood Price",
	"Exhaust this unit: opponent loses 10 HP x Eternal": "Eternal Strike",
	"Pay 1 AP: destroy a Trap with Reveal": "Break Trap",
	"Apply 1 Paralyse and 4 Burn to a unit in this column": "Paralyse + Burn",
	"Apply 4 Burn to a unit in this column": "Apply Burn",
	"Apply 1 Pierce to this unit": "Gain Pierce",
	"Apply 1 Cleanse or 10 Burn to a unit": "Cleanse or Burn",
	"Exhaust this unit: Fusion Summon (Field and/or Spent)": "Fusion (Exhaust)",
	"Destroy this unit: Fusion Summon (Field)": "Fusion (Destroy)",
	"Fusion Summon (Field)": "Fusion Summon",
	"Pay 1 AP: Fusion Summon (Field)": "Fusion (1 AP)",
	"Destroy a unit with a Rune": "Break Rune",
	"Apply 4 Poison to a unit in this column": "Apply Poison",
	"Apply 1 Infiltrate to a unit": "Apply Infiltrate",
	"Change this unit's Type (Water/Fire/Earth/Lightning)": "Change Type",
	"Apply 1 Curse to a unit with the same Type": "Apply Curse",
	"Apply 1 Paralyse to a unit in this column": "Apply Paralyse",
	"Your opponent's units lose 4 ATK": "Weaken Foes",
	"Lose 2 HP: apply Reveal to a face-down card": "Reveal (2 HP)",
	"Apply 1 Paralyse to a unit": "Apply Paralyse",
	"Apply 1 Retain to a card in your Hand": "Apply Retain",
	"Exhaust a unit from your Field: destroy a unit": "Exhaust & Destroy",
	"Gain 4 HP or your opponent loses 4 HP": "Heal or Drain",
	"Send a card from Hand to Spent, draw 1": "Cycle a Card",
	"Change Stance of your opponent's unprotected units": "Topple Foes",
	"Apply 10 Burn to all units": "Burn All",
	"Apply 3 Poison to a unit": "Apply Poison",
	"Apply 3 Medic to an adjacent unit": "Apply Medic",
	"Change Type (Physical/Heavenly/Necrotic)": "Change Type",
	"Apply 1 Nimble to all your units": "Nimble All",
	"Apply 1 Blind to all opponent's units": "Blind Foes",
	"Pay 1 AP: gain 10 HP": "Heal 10 (1 AP)",
	"Exhaust the unit this protects: +1 Eternal and +1 AP": "Exhaust Ward",
	"Apply 10 Burn, 4 Poison or 1 Curse to a unit": "Afflict",
	"Apply Reveal to a face-down card": "Apply Reveal",
	"Apply 1 Debilitate to a unit in this column": "Apply Debilitate",
	"Draw a card, then send a card from Hand to Spent": "Draw & Discard",
	"Apply 1 Debilitate to a unit": "Apply Debilitate",
	"Apply 1 Infiltrate to this unit": "Gain Infiltrate",
	"Lose 10 HP: destroy a unit with lower ATK": "Execute (10 HP)",
	"Apply 2 Medic to adjacent units": "Medic Adjacent",
}


static func short_label(label: String) -> String:
	if SHORT_LABELS.has(label):
		return SHORT_LABELS[label]
	var re := RegEx.new()
	re.compile("^Apply [0-9]+ ([A-Za-z]+) to ")
	var m := re.search(label)
	if m != null:
		return "Apply " + m.get_string(1)
	if label.length() <= 18:
		return label
	var head := label.split(":")[0]
	return head if head.length() <= 18 else head.substr(0, 17) + "…"


const COL_OTHER := {"kind": "unit", "side": "self", "column": true, "not_self": true}
const GOD_SUMMON := [{"op": "status", "target": "self", "s": "eternal", "n": 1}, {"op": "status", "target": "self", "s": "cleanse", "n": 1}]
const GOD_DESTROY := [{"op": "cost_perm", "target": "self", "n": 1}]


static func _build() -> Dictionary:
	var t := {}

	# ------------------------------------------------------------ Units
	# 2026-10-17 database: the Tag Team searches moved between IDs; each is keyed by stable ID.
	# L (6): optional Trap search. B (7): optional Spell search (its Cleanse is gone).
	t[6] = {"on": [trig("summoned", tag_team([ch({"kind": "draw", "side": "self", "category": ["trap"]}, "c", true, "Add a Trap from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]))]}
	t[7] = {"on": [trig("summoned", tag_team([ch({"kind": "draw", "side": "self", "category": ["spell"]}, "c", true, "Add a Spell from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]))]}
	t[8] = {"on": [trig("summoned", tag_team([yes("Fusion Summon using units from your Field?"), {"op": "fusion", "sources": ["field"]}]))]}
	# F (9): optional same-Cost unit search, now with the -1 AP this turn.
	t[9] = {"on": [trig("summoned", tag_team([all_(COL_OTHER, "col"),
		ch({"kind": "draw", "side": "self", "unit_card": true, "cost_eq": {"cost_of": "$col"}}, "c", true, "Add a unit with the same Cost from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]))]}
	# W (10): mandatory ("add", no "you can") same-Race unit search with -1 AP this turn.
	t[10] = {"on": [trig("summoned", tag_team([all_(COL_OTHER, "col"),
		ch({"kind": "draw", "side": "self", "unit_card": true, "race_eq": "$col"}, "c", false, "Add a unit with the same Race from Draw to Hand. It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])),
		trig("destroyed", [all_({"kind": "facedown", "column": true}), {"op": "destroy", "target": "$all"}])]}
	# J (11): optional same-Type unit search with -1 AP this turn (a typeless partner matches nothing).
	t[11] = {"on": [trig("summoned", tag_team([all_(COL_OTHER, "col"),
		ch({"kind": "draw", "side": "self", "unit_card": true, "type_eq": "$col"}, "c", true, "Add a unit with the same Type from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])),
		trig("destroyed", [all_({"kind": "field_card", "column": true, "has_status": "reveal"}), {"op": "destroy", "target": "$all"}])]}
	t[12] = {"on": [trig("summoned", tag_team([yes("Draw a card and gain +1 AP?"), {"op": "draw", "n": 1}, {"op": "ap", "n": 1}]))],
		"abilities": [abil("Pay 2 AP: summon a unit from your Spent in this column", [
			ch({"kind": "spent", "side": "self", "unit_card": true}, "u", false, "Summon a unit from your Spent into this column."),
			{"op": "summon", "target": "$u", "place": "column", "stance": "choose"}], false, {"ap": 2})]}
	t[13] = {"flags": ["mage_type_aura"],
		"abilities": [abil("Change this unit's Type: all Mage units follow", [{"op": "declare_type", "types": CardDB.ELEMENTS, "as": "ty"}, {"op": "set_type", "target": "self", "var": "ty"}])],
		"on": [trig("destroyed", [yes("Change an opponent's unit to a Type of your choosing?"), ch({"kind": "unit", "side": "opp"}, "u"), need("u"),
			{"op": "declare_type", "types": CardDB.ELEMENTS, "as": "ty"}, {"op": "set_type", "target": "$u", "var": "ty"}])]}
	t[14] = {"on": [trig("summoned", [ch({"kind": "unit"}, "u", true, "Apply 1 Rune to a unit?"), st("$u", "rune")]),
		trig("destroyed", [hp("self", -6), hp("opp", -6)])],
		"abilities": [abil("Apply 6 Burn to a unit", [ch({"kind": "unit"}, "u"), st("$u", "burn", 6)])]}
	t[15] = {"abilities": [abil("Apply 1 Pierce to a unit", [ch({"kind": "unit"}, "u"), st("$u", "pierce")])],
		"on": [trig("destroyed", [ch({"kind": "unit", "race": "Mage", "column": true}, "u", true, "Apply 1 Eternal to a Mage unit in this column?"), st("$u", "eternal")])]}
	t[19] = {"on": [trig("summoned", [ch({"kind": "unit", "side": "opp", "unprotected": true, "column": true}, "u", false, "Choose an opponent's unprotected unit in this column."),
		need("u"), st("$u", "eternal"), {"op": "copy_stats", "from": "$u", "race": true}])]}
	t[20] = {"on": [trig("summoned", [{"op": "copy_all_buffs"}]), trig("destroyed", [ch({"kind": "unit"}, "u", true, "Apply 1 Pierce to a unit?"), st("$u", "pierce")])],
		"aura": [{"to": "self", "atk": {"count": {"kind": "unit", "side": "opp"}, "mul": 4}, "def": {"count": {"kind": "unit", "side": "opp"}, "mul": 4}}]}
	t[21] = {"on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY)],
		"aura": [{"to": "self", "atk": {"pile": "exhaust", "mul": 10}, "def": {"pile": "exhaust", "mul": 10}}]}
	t[22] = {"flags": ["adjacent_no_attack"], "on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY)]}
	t[23] = {"on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY)],
		"abilities": [abil("Lose 10 HP: +10 ATK or destroy a face-down card", [{"op": "mode", "options": [
			{"label": "This unit gains +10 ATK", "ops": [{"op": "stat", "target": "self", "atk": 10}]},
			{"label": "Destroy a face-down card", "ops": [ch({"kind": "facedown"}, "u"), {"op": "destroy", "target": "$u"}]}]}], true, {"hp": 10})]}
	t[161] = {"on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY), trig("start_turn", [st("self", "eternal")], "own_turn", "start of turn")],
		"abilities": [abil("Exhaust this unit: opponent loses 10 HP x Eternal", [{"op": "let", "as": "e", "n": {"status": "eternal", "of": "self"}},
			{"op": "move", "target": "self", "to": "exhaust"}, hp("opp", {"value": "$e", "mul": -10})])]}
	t[24] = {"on": [trig("summoned", [st("self", "infiltrate")])]}
	t[25] = {"on": [trig("summoned", [all_({"kind": "unit", "basic": true, "unprotected": true}), {"op": "destroy", "target": "$all"}])]}
	t[26] = {"on": [trig("summoned", tag_team([ch({"kind": "draw", "side": "self", "cost_eq": 0}, "c", false, "Add a 0-cost card from Draw to Hand."), {"op": "move", "target": "$c", "to": "hand"}])),
		trig("destroyed", [all_({"kind": "facedown", "side": "self"}), {"op": "destroy", "target": "$all"}])]}
	t[27] = {"on": [trig("destroyed", [ch({"kind": "spent", "side": "self", "race": "Dragon", "cost_max": 1, "not_self": true}, "u", true, "Summon a 1-cost or lower Dragon from Spent to this zone?"),
		need("u"), {"op": "summon", "target": "$u", "place": "orig", "stance": "choose"}])]}
	t[28] = {"on": [trig("summoned", [ch({"kind": "spent", "side": "self", "race": "Beast", "cost_max": 1}, "u", true, "Summon a 1-cost or lower Beast from Spent into this column?"),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "choose"}])]}
	t[29] = {"on": [trig("summoned", [ch({"kind": "backrow", "spell_trap": true, "column": true, "revealed": false}, "u", true, "Apply Reveal to a Spell or Trap in this column?"), st("$u", "reveal")])],
		"abilities": [abil("Pay 1 AP: destroy a Trap with Reveal", [ch({"kind": "backrow", "category": ["trap"], "has_status": "reveal"}, "u"), {"op": "destroy", "target": "$u"}], true, {"ap": 1})]}
	t[30] = {"on": [trig("summoned", [ch({"kind": "draw", "side": "self", "unit_card": true}, "u", true, "Send a unit from Draw to Spent, then apply 1 Retain to a unit in your Hand?"),
			need("u"), {"op": "move", "target": "$u", "to": "spent"},
			ch({"kind": "hand", "side": "self", "unit_card": true}, "h", false, "Apply 1 Retain to a unit in your Hand."), st("$h", "retain")]),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "unit_card": true, "not_self": true}, "u", true, "Move a unit from Spent to Draw?"), {"op": "move", "target": "$u", "to": "draw"}])]}
	t[31] = {"on": [trig("summoned", [st("self", "pierce")]), trig("destroyed", [ch({"kind": "unit"}, "u", true, "Apply 3 Medic to a unit?"), st("$u", "medic", 3)])]}
	t[32] = {"on": [trig("summoned", [ch({"kind": "power"}, "u", false, "Destroy a Power."), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Apply 1 Paralyse and 4 Burn to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "paralyse"), st("$u", "burn", 4)])]}
	t[33] = {"abilities": [abil("Apply 4 Burn to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "burn", 4)])]}
	t[34] = {"aura": [{"to": "adjacent", "def": 6}]}
	t[35] = {"abilities": [abil("Apply 1 Pierce to this unit", [st("self", "pierce")])]}
	t[36] = {"on": [trig("summoned", [all_({"kind": "unit"}), st("$all", "burn", 6)]),
		trig("destroyed", [yes("Lose 1 AP next turn to revive Dante at the start of your next turn?"),
			{"op": "ap", "n": -1, "next_turn": true, "payment": true}, {"op": "delay_revive"}])],
		"abilities": [abil("Apply 1 Cleanse or 10 Burn to a unit", [ch({"kind": "unit"}, "u"),
			{"op": "mode", "options": [{"label": "1 Cleanse", "ops": [st("$u", "cleanse")]}, {"label": "10 Burn", "ops": [st("$u", "burn", 10)]}]}])],
		"aura": [{"to": "self", "atk": {"status": "burn", "of": "self"}}]}
	t[37] = {"on": [trig("summoned", [st("self", "pierce", 2)]),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "race": "Warrior", "not_self": true}, "u", true, "Add a Warrior unit from Spent to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])],
		"aura": [{"to": "self", "atk": 10, "cond": {"protected": true}}]}
	t[38] = {"flags": ["no_gain", "no_buffs"], "on": [trig("summoned", [ch({"kind": "field_card", "has_status": "reveal"}, "u", true, "Destroy a card with Reveal?"), {"op": "destroy", "target": "$u"}])],
		"aura": [{"to": "self", "atk": {"count": {"kind": "unit", "side": "self", "adjacent": true}, "mul": -6}, "def": {"count": {"kind": "unit", "side": "self", "adjacent": true}, "mul": -6}}]}
	t[39] = {"flags": ["battle_immune_30atk"]}
	t[67] = {"on": [trig("summoned", [ch({"kind": "unit", "column": true}, "u", true, "Apply 2 Paralyse to a unit in this column?"), st("$u", "paralyse", 2)])],
		"abilities": [abil("Exhaust this unit: Fusion Summon (Field and/or Spent)", [{"op": "move", "target": "self", "to": "exhaust"}, {"op": "fusion", "sources": ["field", "spent"]}], false)]}
	t[68] = {"abilities": [abil("Destroy this unit: Fusion Summon (Field)", [{"op": "destroy", "target": "self"}, {"op": "fusion", "sources": ["field"]}], false)]}
	t[69] = {"tribute_bonus": {"s": "pierce", "n": 2}, "on": [trig("summoned", [ch({"kind": "unit", "side": "self", "adjacent": true}, "u", false, "Apply 2 Pierce to an adjacent unit."), st("$u", "pierce", 2)])],
		"abilities": [abil("Fusion Summon (Field)", [{"op": "fusion", "sources": ["field"]}], false)]}
	t[40] = {"abilities": [abil("Pay 1 AP: Fusion Summon (Field)", [{"op": "fusion", "sources": ["field"]}], false, {"ap": 1})]}
	t[70] = {"on": [trig("summoned", [st("self", "nimble", 3)]), trig("moved", [{"op": "stat", "target": "self", "atk": 8}])]}
	t[71] = {"on": [trig("moved", [st("self", "medic", 3)])], "abilities": [abil("Apply 1 Nimble to a unit", [ch({"kind": "unit"}, "u"), st("$u", "nimble")])]}
	t[72] = {"aura": [{"to": "self", "def": 20, "cond": {"self_front": true}}, {"to": "self", "atk": 20, "cond": {"self_front": false}}],
		"on": [trig("summoned", [st("self", "nimble")]), trig("end_turn", [{"op": "wukong_swap"}], "own_turn", "end of turn"),
			trig("destroyed", [ch({"kind": "unit", "side": "self"}, "u", true, "Move a unit to an adjacent zone?"), need("u"), {"op": "move_unit", "target": "$u", "to": "adjacent"}])]}
	t[73] = {"flags": ["warrior_guard"], "on": [trig("summoned", [ch({"kind": "draw", "side": "self", "race": "Warrior"}, "c", false, "Add a Warrior from Draw to Hand."), {"op": "move", "target": "$c", "to": "hand"}])]}
	t[74] = {"on": [trig("tribute_or_sacrifice", [ch({"kind": "unit"}, "u", false, "Apply 1 Infiltrate to a unit."), st("$u", "infiltrate")])]}
	t[16] = {"on": [trig("destroyed_opp_unit", [st("self", "rune")], "mine", "you destroyed an opponent's unit")]}
	t[17] = {"on": [trig("start_turn", [st("self", "rune")], "own_turn", "start of turn")]}
	t[18] = {"on": [trig("summoned", [ch({"kind": "unit", "column": true}, "u", true, "Apply 1 Paralyse to a unit in this column?"), st("$u", "paralyse")]),
		trig("battle_destroyed", [st("self", "rune")], "self", "destroyed a unit by battle")]}
	t[75] = {"on": [trig("own_unit_moved", [st("self", "rune")], "mine", "your unit moved")]}
	t[76] = {"on": [trig("any_sacrificed", [st("self", "rune")], "any", "a unit was sacrificed")]}
	t[77] = {"on": [trig("trap_activated", [st("self", "rune")], "any", "a Trap was activated")]}
	t[78] = {"on": [trig("summoned", [st("self", "cleanse")]),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "race": "Dragon", "not_self": true}, "u", true, "Add a Dragon unit from Spent to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])],
		"abilities": [abil("Apply 4 Poison to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "poison", 4)])]}
	t[79] = {"on": [trig("summoned", [ch({"kind": "unit", "type": "Water"}, "u", false, "Destroy a Water unit."), {"op": "destroy", "target": "$u"}]),
		trig("destroyed", [ch({"kind": "facedown"}, "u", true, "Apply Reveal to a face-down card?"), st("$u", "reveal")])],
		"abilities": [abil("Apply 1 Infiltrate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "infiltrate")])]}
	t[99] = {"on": [trig("summoned", [ch({"kind": "spent", "side": "self", "unit_card": true}, "u", false, "Move a unit from your Spent to Draw."), {"op": "move", "target": "$u", "to": "draw"}])]}
	t[100] = {"on": [trig("destroyed", [by_unit_st("paralyse", 2)])]}
	t[102] = {"abilities": [
		abil("Change this unit's Type (Water/Fire/Earth/Lightning)", [{"op": "declare_type", "types": ["Water", "Fire", "Earth", "Lightning"], "as": "ty"}, {"op": "set_type", "target": "self", "var": "ty"}]),
		abil("Apply 1 Curse to a unit with the same Type", [ch({"kind": "unit", "type": "$self_type"}, "u"), st("$u", "curse")])]}
	t[135] = {"flags": ["rider_no_attack"], "aura": [{"to": "protector_dragon", "atk": 14}]}
	t[150] = {"flags": ["no_defense"], "on": [trig("summoned", [ch({"kind": "spent", "side": "self"}, "u", false, "Move a card from Spent to the top of Draw."), {"op": "move", "target": "$u", "to": "draw_top"}]),
		trig("tribute_or_sacrifice", [{"op": "ap", "n": 1}])]}
	t[162] = {"flags": ["direct_attack"], "on": [trig("destroyed", [by_unit_st("blind", 1)]),
		trig("sacrificed", [{"op": "cost_perm", "target": "self", "n": 1}])]}
	t[155] = {"on": [trig("summoned", [st("self", "eternal")])], "aura": [{"to": "protector", "atk": 10}]}
	t[156] = {"on": [trig("summoned", [st("self", "eternal")]),
			trig("start_turn", [{"op": "draw", "n": 1}, ch({"kind": "hand", "side": "self"}, "h", false, "Discard a card: send it from Hand to Spent."),
				{"op": "move", "target": "$h", "to": "spent"}], "own_turn", "start of turn")],
		"aura": [{"to": "protector", "atk": 10}]}
	t[157] = {"on": [trig("summoned", [st("self", "eternal")]), trig("start_turn", [{"op": "draw", "n": 1}], "own_turn", "start of turn")],
		"aura": [{"to": "adjacent", "atk": 10, "cond": {"protected": true}}]}
	var serpent := trig("summoned", [{"op": "require", "cond": {"count": {"kind": "unit", "side": "self", "adjacent": true, "name_prefix": "Divine Serpent"}, "min": 2}}, hp("opp", -30)])
	t[158] = {"on": [serpent], "abilities": [abil("Apply 1 Paralyse to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "paralyse")])]}
	t[159] = {"on": [serpent], "aura": [{"to": "adjacent", "def": 10}]}
	t[160] = {"on": [serpent], "abilities": [abil("Your opponent's units lose 4 ATK", [all_({"kind": "unit", "side": "opp"}), {"op": "stat", "target": "$all", "atk": -4}])]}

	# ------------------------------------------------------------ Spells
	t[80] = {"spell": [all_({"kind": "unit"}), st("$all", "nimble")]}
	t[81] = {"spell": [all_({"kind": "unit"}), st("$all", "blind")]}
	t[82] = {"spell": [{"op": "fusion", "sources": ["field"]}]}
	t[41] = {"spell": [ch({"kind": "hand", "side": "self", "not_self": true}, "h", false, "Apply 1 Retain to a card in your Hand."), st("$h", "retain"), {"op": "ap", "n": 1, "next_turn": true}]}
	t[42] = {"spell": [{"op": "ambush"}]}
	t[43] = {"spell": [{"op": "swap_all"}]}
	t[154] = {"spell": [{"op": "reversal"}]}
	t[83] = {"spell": [ch({"kind": "unit"}, "u", false, "Apply 1 Rune to a unit."), st("$u", "rune")]}
	t[84] = {"spell": [ch({"kind": "unit", "def_max": 30}, "u", false, "Destroy a unit with 30 DEF or less."), {"op": "destroy", "target": "$u"}]}
	t[101] = {"flags": ["exhaust_on_spent"], "spell": [ch({"kind": "spent", "side": "opp"}, "u", false, "Exhaust a card from your opponent's Spent."), {"op": "move", "target": "$u", "to": "exhaust"}]}
	t[104] = {"spell": [all_({"kind": "unit", "side": "opp", "unprotected": true}), {"op": "stance", "target": "$all"}]}
	t[136] = {"flags": ["exhaust_on_spent"], "spell": [all_({"kind": "unit", "atk_min": 20}), {"op": "destroy", "target": "$all"}]}
	t[138] = {"spell": [ch({"kind": "unit", "has_buff": true}, "u", false, "Destroy a unit with a Buff."), {"op": "destroy", "target": "$u"}]}
	t[180] = {"spell": [ch({"kind": "unit", "side": "opp", "atk_max": 20}, "u", false, "Take control of an opponent's unit with 20 ATK or less."), {"op": "take_control", "target": "$u"}]}
	t[182] = {"flags": ["cost_up_on_activate"], "spell": [ch({"kind": "unit"}, "u", false, "Apply 1 Blind and +16 ATK until end of turn to a unit."), st("$u", "blind"),
		{"op": "stat", "target": "$u", "atk": 16, "until": "turn"}]}
	t[152] = {"spell": [ch({"kind": "power"}, "u", false, "Destroy a Power."), {"op": "destroy", "target": "$u"}]}

	# ------------------------------------------------------------ Traps
	t[85] = {"trap": {"when": "activate", "ops": [ch({"kind": "unit"}, "u", false, "Apply 1 Rune to a unit."), st("$u", "rune")]}}
	t[86] = {"trap": {"when": "destroyed", "by_opponent": true, "ops": [ch({"kind": "unit"}, "u", false, "Apply 4 Medic to a unit."), st("$u", "medic", 4)]}}
	t[87] = {"trap": {"when": "destroyed", "by_effect": true, "ops": [ch({"kind": "unit", "side": "opp"}, "u", false, "Destroy an opponent's unit."), {"op": "destroy", "target": "$u"}]}}
	t[45] = {"flags": ["cost_up_on_activate"], "trap": {"when": "attack", "column": true, "target_unit_only": true, "ops": [{"op": "cost_perm", "target": "self", "n": 1}, hp("opp", {"stat": "atk", "of": "event.attacker", "mul": -1})]}}
	t[46] = {"trap": {"when": "attack", "cond": {"count": {"kind": "field_card", "side": "opp"}, "min": 4}, "ops": [all_({"kind": "unit", "side": "opp", "stance": "atk"}), {"op": "destroy", "target": "$all"}]}}
	t[47] = {"flags": ["cost_up_on_activate"], "trap": {"when": "attack", "column": true, "target_unit_only": true, "ops": [{"op": "cost_perm", "target": "self", "n": 1}, hp("self", {"stat": "atk", "of": "event.attacker"})]}}
	# F03-19 (user-confirmed 2026-10-16): the controller chooses any opposing unit; no highest-ATK rule.
	t[48] = {"trap": {"when": "summon", "cond": {"count": {"kind": "unit", "side": "opp"}, "min": 3}, "ops": [ch({"kind": "unit", "side": "opp"}, "u", false, "Choose an opponent's unit; it loses 20 ATK."), {"op": "stat", "target": "$u", "atk": -20}]}}
	t[49] = {"trap": {"when": "summon", "cond": {"event_cost_min": 2}, "ops": [st("event.card", "paralyse", 3)]}}
	t[50] = {"trap": {"when": "attack", "ops": [ch({"kind": "unit", "side": "self", "column": true}, "u", false, "Apply 1 Eternal to a unit in this column."), st("$u", "eternal")]}}
	t[51] = {"trap": {"when": "attack", "ops": [all_({"kind": "unit", "side": "self", "column": true}), {"op": "stat", "target": "$all", "def": 8, "until": "turn"}]}}
	t[103] = {"trap": {"when": "summon", "ops": [{"op": "let", "as": "low", "n": {"min_atk": {"kind": "unit", "side": "self"}}}, {"op": "stat", "target": "event.card", "atk": {"value": "$low", "mul": -1}}]}}
	t[140] = {"flags": ["exhaust_on_spent"], "trap": {"when": "activate", "ops": [{"op": "negate"}]}}
	t[153] = {"trap": {"when": "activate", "power_only": true, "ops": [{"op": "destroy", "target": "event.card"}, hp("opp", -4)]}}
	t[163] = {"trap": {"when": ["activate", "attack"], "ops": [ch({"kind": "field_card", "side": "self", "not_self": true}, "u", false, "Destroy any number of your cards (+10 HP each)."),
		{"op": "plan_b"}]}}
	t[163]["trap"]["ops"][0]["n"] = "any"
	# User decision 2026-10-15: Plan B must destroy at least one card, and is only offered
	# when you control another card to destroy.
	t[163]["trap"]["ops"][0]["min"] = 1
	t[163]["trap"]["needs_target"] = true
	t[164] = {"trap": {"when": "attack", "cond": {"event_target_unit": true}, "ops": [st("event.target", "curse"), {"op": "no_loyalty"}]}}
	t[52] = {"trap": {"when": "summon", "cond": {"event_cost_min": 2}, "ops": [ch({"kind": "spent", "side": "self", "unit_card": true, "cost_max": 2}, "u", false, "Summon a 2-cost or lower unit from your Spent."),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "atk"}]}}
	t[165] = {"trap": {"when": "summon", "cond": {"event_atk_min": 24}, "ops": [ch({"kind": "spent", "side": "self", "unit_card": true, "atk_max": 24}, "u", false, "Summon a unit with 24 ATK or less from your Spent."),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "atk"}]}}

	# ------------------------------------------------------------ Powers
	t[88] = {"flags": ["elemental_mastery"]}
	t[53] = {"aura": [{"to": "own_units", "filter": {"basic": true}, "atk": 8}]}
	t[54] = {"aura": [{"to": "own_units", "atk": {"unique_races": "self", "mul": 4}, "def": {"unique_races": "self", "mul": 4}}]}
	t[89] = {"abilities": [abil("Pay 1 AP: Fusion Summon (Field)", [{"op": "fusion", "sources": ["field"]}], true, {"ap": 1})]}
	t[55] = {"abilities": [abil("Lose 2 HP: apply Reveal to a face-down card", [ch({"kind": "facedown"}, "u"), st("$u", "reveal")], true, {"hp": 2})]}
	t[90] = {"abilities": [abil("Apply 1 Paralyse to a unit", [ch({"kind": "unit"}, "u"), st("$u", "paralyse")])]}
	t[91] = {"on": [trig("start_turn", [ch({"kind": "unit"}, "u", true, "Apply 1 Rune to a unit?"), st("$u", "rune")], "own_turn", "start of turn")]}
	t[92] = {"abilities": [abil("Apply 1 Retain to a card in your Hand", [ch({"kind": "hand", "side": "self"}, "h"), st("$h", "retain")])]}
	t[137] = {"flags": ["hand_fusion"]}
	t[148] = {"abilities": [abil("Exhaust a unit from your Field: destroy a unit", [ch({"kind": "unit", "side": "self"}, "x", false, "Exhaust a unit from your Field."),
		{"op": "move", "target": "$x", "to": "exhaust"}, ch({"kind": "unit"}, "u", false, "Destroy a unit."), {"op": "destroy", "target": "$u"}])]}
	t[149] = {"flags": ["abyss_ap"]}
	t[139] = {"flags": ["spells_cost_less"]}
	t[166] = {"flags": ["traps_cost_less"]}
	t[167] = {"abilities": [abil("Gain 4 HP or your opponent loses 4 HP", [{"op": "mode", "options": [
		{"label": "Gain 4 HP", "ops": [hp("self", 4)]}, {"label": "Opponent loses 4 HP", "ops": [hp("opp", -4)]}]}])]}
	t[168] = {"abilities": [abil("Send a card from Hand to Spent, draw 1", [ch({"kind": "hand", "side": "self"}, "h"), {"op": "move", "target": "$h", "to": "spent"}, {"op": "draw", "n": 1}])]}
	t[169] = {"flags": ["draw_extra"]}
	t[178] = {"flags": ["units_cost_less_if_behind"]}
	t[179] = {"aura": [{"to": "own_units", "filter": {"type": "Fire"}, "atk": 12}],
		"on": [{"when": "unit_destroyed", "scope": "mine", "filter": {"event_type": "Fire"}, "text": "your Fire unit was destroyed", "ops": [hp("self", -6), hp("opp", -6)]}]}
	t[44] = {"flags": ["no_set"]}

	# ------------------------------------------------------------ Fusion
	t[56] = {"fusion": [{"atk_min": 20}, {"type": "Lightning"}], "on": [trig("summoned", [all_({"kind": "facedown"}), st("$all", "reveal")]),
		trig("destroyed", [all_({"kind": "unit"}), st("$all", "paralyse")])]}
	t[57] = {"fusion": [{"def_min": 20}, {"type": "Earth"}],
		"on": [trig("summoned", [yes("Apply 1 Infiltrate and 1 Nimble to your units?"), all_({"kind": "unit", "side": "self"}), st("$all", "infiltrate"), st("$all", "nimble")])],
		"abilities": [abil("Change Stance of your opponent's unprotected units", [all_({"kind": "unit", "side": "opp", "unprotected": true}), {"op": "stance", "target": "$all"}])]}
	t[57]["abilities"][0]["cond"] = {"count": {"kind": "unit", "side": "opp", "unprotected": true}, "min": 1}
	t[58] = {"fusion": [{"race": "Monster"}, {"type": "Fire"}], "on": [trig("summoned", [ch({"kind": "power"}, "u", true, "Destroy a Power?"), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Apply 10 Burn to all units", [all_({"kind": "unit"}), st("$all", "burn", 10)])]}
	t[59] = {"fusion": [{"race": "Mage"}, {"type": "Water"}], "on": [trig("summoned", [ch({"kind": "backrow", "spell_trap": true}, "u", true, "Destroy a Spell or Trap?"), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Apply 1 Paralyse to a unit", [ch({"kind": "unit"}, "u"), st("$u", "paralyse")]), abil("Apply 1 Infiltrate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "infiltrate")])]}
	t[60] = {"fusion": [{"has_debuff": true}, {"has_buff": true}], "on": [trig("summoned", [ch({"kind": "unit"}, "u", false, "Apply 3 Debilitate to a unit."), st("$u", "debilitate", 3)])],
		"abilities": [abil("Apply 3 Poison to a unit", [ch({"kind": "unit"}, "u"), st("$u", "poison", 3)])]}
	t[61] = {"fusion": [{"race": "Warrior"}, {"type": "Heavenly"}], "on": [trig("summoned", [ch({"kind": "spent", "side": "self", "type": "Heavenly", "cost_max": 1}, "u", true, "Summon a 1-cost or lower Heavenly unit from Spent into this column?"),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "choose"}])],
		"abilities": [abil("Apply 3 Medic to an adjacent unit", [ch({"kind": "unit", "side": "self", "adjacent": true}, "u"), st("$u", "medic", 3)])]}
	t[93] = {"fusion": [{"race": "Beast"}, {"race": "Dragon"}], "on": [trig("summoned", [st("self", "eternal")])]}
	t[94] = {"fusion": [{"has_type": true}, {"same_type_as": 0}], "on": [trig("summoned", [{"op": "mirrorflesh"}]),
		trig("destroyed", [ch({"kind": "unit", "type": "$snap_type"}, "u", false, "Destroy a unit with the same Type."), {"op": "destroy", "target": "$u"}])]}
	t[141] = {"fusion": [{"type": "Necrotic"}, {"type": "Heavenly"}], "flags": ["type_summon_lock"],
		"abilities": [abil("Change Type (Physical/Heavenly/Necrotic)", [{"op": "declare_type", "types": ["Physical", "Heavenly", "Necrotic"], "as": "ty"}, {"op": "set_type", "target": "self", "var": "ty"}])],
		"on": [trig("destroyed", [ch({"kind": "unit", "type": "$snap_type"}, "u", true, "Make a unit with the same Type lose 30 ATK/DEF?"), {"op": "stat", "target": "$u", "atk": -30, "def": -30}])]}
	t[142] = {"fusion": [{"race": "Dragon"}, {"type": "Lightning"}], "on": [trig("summoned", [st("self", "pierce")]),
		trig("start_turn", [{"op": "stat", "target": "self", "atk": 4, "def": -4}], "own_turn", "start of turn")]}
	t[143] = {"fusion": [{"type": "Water"}, {"type": "Lightning"}], "abilities": [
		abil("Apply 1 Nimble to all your units", [all_({"kind": "unit", "side": "self"}), st("$all", "nimble")]),
		abil("Apply 1 Blind to all opponent's units", [all_({"kind": "unit", "side": "opp"}), st("$all", "blind")])]}
	t[144] = {"fusion": [{"race": "Warrior"}, {"type": "Earth"}], "flags": ["battle_immune_lightning"],
		"on": [trig("summoned", [ch({"kind": "unit"}, "u", true, "Apply 1 Cleanse to a unit?"), st("$u", "cleanse")]),
			trig("destroyed", [ch({"kind": "spent_or_draw", "side": "self", "type": "Earth", "unit_card": true, "not_self": true}, "u", true, "Add an Earth unit from Spent or Draw to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])]}
	t[145] = {"fusion": [{"race": "Mage"}, {"type": "Fire"}], "on": [trig("summoned", [all_({"kind": "unit"}), st("$all", "burn", 10)])],
		"abilities": [abil("Pay 1 AP: gain 10 HP", [hp("self", 10)], true, {"ap": 1})]}
	t[146] = {"fusion": [{"category": ["basic_unit"]}, {"type": "Physical"}], "on": [trig("summoned", [all_({"kind": "unit", "basic": true}), st("$all", "medic", 5)]),
		trig("destroyed", [ch({"kind": "spent_or_draw", "side": "self", "basic": true}, "u", true, "Summon a Basic Unit from Spent or Draw to this zone?"), need("u"), {"op": "summon", "target": "$u", "place": "orig", "stance": "choose"}])]}
	t[147] = {"fusion": [{"race": "Monster"}, {"type": "Necrotic"}], "flags": ["taunt"],
		"on": [trig("summoned", [all_({"kind": "unit", "side": "opp", "unprotected": true}), st("$all", "paralyse", 2)]),
			trig("start_turn", [all_({"kind": "unit", "side": "opp"}), {"op": "stat", "target": "$all", "def": -8}], "own_turn", "start of turn"),
			trig("destroyed", [all_({"kind": "unit"}), {"op": "stance", "target": "$all"}])]}
	t[181] = {"fusion": [{"race": "Warrior"}, {"type": "Fire"}], "on": [trig("summoned", [st("self", "pierce", 2)]), trig("destroyed", [hp("self", -12)])],
		"abilities": [abil("Exhaust the unit this protects: +1 Eternal and +1 AP", [ch({"kind": "unit", "side": "self", "protected_by_src": true}, "u", false, "Exhaust the unit this unit is protecting."),
			{"op": "move", "target": "$u", "to": "exhaust"}, st("self", "eternal"), {"op": "ap", "n": 1}])]}
	t[181]["abilities"][0]["cond"] = {"protecting": true}
	t[151] = {"fusion": [{"race": "Dragon"}, {"race": "Dragon"}, {"race": "Dragon"}], "abilities": [abil("Apply 10 Burn, 4 Poison or 1 Curse to a unit", [ch({"kind": "unit"}, "u"),
		{"op": "mode", "options": [{"label": "10 Burn", "ops": [st("$u", "burn", 10)]}, {"label": "4 Poison", "ops": [st("$u", "poison", 4)]}, {"label": "1 Curse", "ops": [st("$u", "curse")]}]}])],
		"on": [trig("destroyed", [yes("Double all Debuffs on the Field?"), {"op": "double_debuffs", "side": "any"}])]}

	# ------------------------------------------------------------ Ritual
	t[98] = {"on": [trig("summoned", [st("self", "burn", 8)]), trig("destroyed", [by_unit_st("burn", 4)])],
		"abilities": [abil("Apply Reveal to a face-down card", [ch({"kind": "facedown"}, "u"), st("$u", "reveal")])]}
	t[62] = {"on": [trig("summoned", [st("self", "curse")]), trig("destroyed", [ch({"kind": "unit"}, "u", true, "Apply 1 Curse to a unit?"), st("$u", "curse")])],
		"abilities": [abil("Apply 1 Debilitate to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "debilitate")])]}
	t[63] = {"on": [trig("summoned", [all_({"kind": "backrow", "spell_trap": true}), st("$all", "reveal")]),
		trig("end_turn", [st("self", "eternal")], "own_turn", "end of turn"),
		trig("destroyed", [ch({"kind": "unit", "side": "opp", "min_atk": true}, "u", false, "Destroy the opponent's lowest-ATK unit."), {"op": "destroy", "target": "$u"}])]}
	t[64] = {"aura": [{"to": "self", "atk": {"pile": "exhaust", "mul": 6}, "def": {"pile": "exhaust", "mul": 6}}],
		"on": [trig("destroyed", [ch({"kind": "exhaust", "side": "self"}, "u", true, "Move a card from Exhaust to Draw?"), {"op": "move", "target": "$u", "to": "draw"}])]}
	t[66] = {"on": [trig("summoned", [ch({"kind": "unit", "side": "self", "adjacent": true}, "u", false, "Apply 1 Eternal to an adjacent unit."), st("$u", "eternal")])],
		"abilities": [abil("Draw a card, then send a card from Hand to Spent", [{"op": "draw", "n": 1}, ch({"kind": "hand", "side": "self"}, "h", false, "Send a card from Hand to Spent."), {"op": "move", "target": "$h", "to": "spent"}])]}
	t[95] = {"on": [trig("summoned", [ch({"kind": "unit", "side": "opp", "unprotected": true, "column": true}, "u", false, "Choose an opponent's unprotected unit in this column."),
		need("u"), st("$u", "paralyse", 2), {"op": "copy_stats", "from": "$u", "type": true}]),
		trig("destroyed", [{"op": "double_debuffs", "side": "opp"}])]}
	t[65] = {"on": [trig("summoned", [all_({"kind": "unit", "side": "opp"}), st("$all", "paralyse")])],
		"abilities": [abil("Apply 1 Debilitate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "debilitate")])]}
	t[97] = {"on": [trig("summoned", [st("self", "cleanse", 3)]), trig("destroyed", [ch({"kind": "unit", "race": "Warrior"}, "u", true, "Apply 2 Rune to a Warrior unit?"), st("$u", "rune", 2)])],
		"abilities": [abil("Apply 1 Infiltrate to this unit", [st("self", "infiltrate")])],
		"aura": [{"to": "self", "atk": 30, "cond": {"hp_lower": true}}]}
	t[183] = {"on": [trig("summoned", [st("self", "eternal", 8)]),
		trig("start_turn", [hp("opp", -6)], "own_turn", "start of turn"),
		trig("destroyed", [ch({"kind": "spent_or_draw", "side": "self", "category": ["power"]}, "u", true, "Add a Power from Spent or Draw to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])]}
	t[96] = {"on": [trig("summoned", [{"op": "roma"}])],
		"abilities": [abil("Lose 10 HP: destroy a unit with lower ATK", [ch({"kind": "unit", "atk_below_self": true}, "u"), {"op": "destroy", "target": "$u"}], true, {"hp": 10})]}

	# ------------------------------------------------------------ Arcane
	t[170] = {"on": [trig("summoned", [ch({"kind": "hand", "side": "self"}, "h", true, "Send a card from Hand to Spent to gain 1 AP?"), need("h"), {"op": "move", "target": "$h", "to": "spent"}, {"op": "ap", "n": 1}]),
		trig("destroyed", [{"op": "require", "cond": {"count": {"kind": "spent", "side": "self", "not_self": true}, "min": 1}},
			yes("Lose 10 HP to add a card from Spent to Hand?"), hp("self", -10), ch({"kind": "spent", "side": "self", "not_self": true}, "u", false, "Add a card from Spent to Hand."), {"op": "move", "target": "$u", "to": "hand"}])]}
	t[171] = {"flags": ["direct_attack", "exhaust_on_destroy"], "on": [trig("start_turn", [{"op": "stat", "target": "self", "atk": 6}], "own_turn", "start of turn")]}
	t[172] = {"on": [trig("summoned", [ch({"kind": "draw", "side": "self", "unit_card": true, "race": "Beast"}, "c", true, "Add a Beast unit from Draw to Hand? It costs 1 AP less this turn."),
			{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])],
		"abilities": [abil("Destroy a unit with a Rune", [ch({"kind": "unit", "has_status": "rune"}, "u"), {"op": "destroy", "target": "$u"}])]}
	t[173] = {"on": [trig("summoned", [hp("opp", {"count": {"kind": "unit", "side": "opp"}, "mul": -4})]), trig("destroyed", [all_({"kind": "unit"}), st("$all", "paralyse")])]}
	t[174] = {"on": [trig("tribute_or_sacrifice", [{"op": "ap", "n": 2}])]}
	t[175] = {"on": [trig("summoned", [all_({"kind": "unit", "side": "opp"}), {"op": "stance", "target": "$all"}]),
		trig("destroyed", [yes("Make your units gain +10 DEF?"), all_({"kind": "unit", "side": "self"}), {"op": "stat", "target": "$all", "def": 10}])],
		"abilities": [abil("Apply 1 Debilitate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "debilitate")])]}
	t[176] = {"on": [trig("summoned", [{"op": "set_base", "target": "self", "atk": {"sum_atk": {"kind": "unit", "type": "Water", "not_self": true}}}])],
		"abilities": [abil("Apply 2 Medic to adjacent units", [all_({"kind": "unit", "side": "self", "adjacent": true}), st("$all", "medic", 2)])]}
	# Card-specific Exhaust recovery (decisions.md): optional, your own Exhaust, current ordinary
	# cost 1 or lower (Extra Deck cards have no ordinary cost and never qualify).
	t[177] = {"flags": ["no_battle_damage"], "aura": [{"to": "self", "atk": 30, "cond": {"my_turn": true}}],
		"on": [trig("destroyed", [ch({"kind": "exhaust", "side": "self", "cost_max": 1}, "u", true, "Move a 1-cost or lower card from your Exhaust to Draw?"), {"op": "move", "target": "$u", "to": "draw"}])]}

	return t
