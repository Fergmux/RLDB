class_name TutorialLessons
extends RefCounted
## Lesson data of the guided tutorial (F03-15, design/playtest-feedback-03.md). Pure data: each
## lesson is a deterministic premade board (TutorialSetup), a list of guidance steps and the
## scripted opponent's fixed commands. Cards are referred to by stable card id and a lesson-local
## key, never by display name, so card-name changes cannot break a lesson.
##
## Lesson: {id, title, summary, setup, steps, opponent}
##   setup: {first: seat that took game turn 1, turn: the player's turn number, hp: [p0, p1],
##     cards: [{key, id, p, zone: hand|draw|unit|backrow|extra|spent, slot, stance, runes}]}
##     Hand cards are put on top of Draw and drawn by the real start of the player's turn.
##   step: {kind: read|do|wait, title, text, expect: [command pattern], until: condition,
##     focus: [highlight spec]}
##     read: shown until the player clicks Next (every action is blocked meanwhile).
##     do:   only a command matching one `expect` pattern is accepted; the step ends when it
##           succeeds (and `until` holds, when given — e.g. "press the phase button until the turn ends").
##     wait: the scripted opponent acts; the step ends as soon as `until` holds.
##   command pattern: {t, card: key, stance, opt: {slot, zone, card: key, label}}
##   condition: {active, phase, pending_kind, pending_player}
##   focus: {plate: me|opp} {hand: true} {pips: true} {pile: [me|opp, zone]} {slot: [me|opp, zone, n]}
##     {card: key}. A `do` step without focus highlights its expected card, button or option.
##   opponent: command patterns run in order whenever the opponent must act.

## Seat of the learner and of the scripted opponent.
const PLAYER := 0
const OPPONENT := 1
const NAMES := ["You", "Rival"]
const START_HP := 60

# Card ids used by the lessons (rldb/data/cards.json).
const BASIC_MAGE_WATER := 1
const BASIC_WARRIOR_WATER := 3
const BASIC_MAGE_FIRE := 110
const BASIC_DRAGON_FIRE := 111
const BASIC_WARRIOR_FIRE := 112
const BASIC_BEAST_FIRE := 113
const BASIC_WARRIOR_EARTH := 122
const BASIC_BEAST_EARTH := 123
const BASIC_MONSTER_NECROTIC := 129
const BASIC_WARRIOR_LIGHTNING := 132
const BASIC_MONSTER_LIGHTNING := 134
const FROST_WYVERN := 32
const STEADFAST_SOLDIER := 39
const WINGS_OF_AURENTHOR := 80
const POLYMERIZATION := 82
const SACRED_OFFERINGS := 83
const MAGIC_CYLINDER := 45
const BASTION_WYRM := 93
const RAGING_INFERNO := 98
const GRANDMOTHER_KAYA := 170


## All lessons in play order.
static func all() -> Array:
	return [_turn_flow(), _summoning(), _battle(), _spells_traps(), _extra_deck()]


## Number of lessons.
static func count() -> int:
	return all().size()


## Lesson `i` (clamped to the valid range).
static func get_lesson(i: int) -> Dictionary:
	var ls := all()
	return ls[clampi(i, 0, ls.size() - 1)]


# ---------------------------------------------------------------- helpers

static func _c(key: String, id: int, p: int, zone: String, slot: int = -1, stance: String = "atk") -> Dictionary:
	return {"key": key, "id": id, "p": p, "zone": zone, "slot": slot, "stance": stance}


## `n` filler cards of `id` for player p (Draw by default: drawn on later turns).
static func _fill(prefix: String, id: int, p: int, n: int, zone: String = "draw") -> Array:
	var out := []
	for i in n:
		out.append(_c("%s%d" % [prefix, i], id, p, zone))
	return out


static func _read(title: String, text: String, focus: Array = []) -> Dictionary:
	return {"kind": "read", "title": title, "text": text, "focus": focus}


static func _do(title: String, text: String, expect: Array, until: Dictionary = {}, focus: Array = []) -> Dictionary:
	return {"kind": "do", "title": title, "text": text, "expect": expect, "until": until, "focus": focus}


static func _wait(title: String, text: String, until: Dictionary, focus: Array = []) -> Dictionary:
	return {"kind": "wait", "title": title, "text": text, "until": until, "focus": focus}


const MY_TURN := {"active": PLAYER, "phase": "main1"}
const THEIR_TURN := {"active": OPPONENT}


# ---------------------------------------------------------------- lesson 1

static func _turn_flow() -> Dictionary:
	var cards := [
		_c("p_mage", BASIC_MAGE_WATER, PLAYER, "hand"),
		_c("p_warrior", BASIC_WARRIOR_EARTH, PLAYER, "hand"),
		_c("p_wings", WINGS_OF_AURENTHOR, PLAYER, "hand"),
		_c("p_fire", BASIC_MAGE_FIRE, PLAYER, "hand"),
		_c("p_next0", BASIC_WARRIOR_WATER, PLAYER, "draw"),
		_c("p_next1", BASIC_BEAST_FIRE, PLAYER, "draw"),
		_c("p_next2", SACRED_OFFERINGS, PLAYER, "draw"),
		_c("p_next3", BASIC_WARRIOR_LIGHTNING, PLAYER, "draw"),
		_c("o_warrior", BASIC_WARRIOR_FIRE, OPPONENT, "draw"),
	] + _fill("p_fill", BASIC_MAGE_WATER, PLAYER, 4) + _fill("o_fill", BASIC_MONSTER_NECROTIC, OPPONENT, 7)
	return {
		"id": "turn_flow",
		"title": "Lesson 1 · A turn of play",
		"summary": "Each turn: draw four, AP back to 2, then Setup, Battle and Recovery. Unplayed cards go to Spent.",
		"setup": {"first": PLAYER, "turn": 1, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Welcome to RLDB", "Two players race to bring the other from 60 HP to 0. This lesson walks you through one full turn.\nClick Next to continue.", [{"plate": "opp"}]),
			_read("Your Hand", "At the start of every turn you draw four fresh cards. Cards you do not play are sent to your Spent pile when the turn ends.", [{"hand": true}]),
			_read("Action Points", "Cards cost AP (the number in a card's top-left corner). Your AP is reset to 2 at the start of each of your turns; unspent AP does not carry over.", [{"plate": "me"}]),
			_read("Phases", "A turn runs Setup Phase, Battle Phase, Recovery Phase. Summon and set cards in Setup or Recovery; attack in Battle. Whoever goes first has no Battle Phase on turn 1.", [{"pips": true}]),
			_do("Move on", "This lesson is about the turn itself, so play nothing yet. Click Go to Recovery.", [{"t": "next_phase"}]),
			_do("End the turn", "In the Recovery Phase you could still summon or set cards. Click End turn: your remaining Hand goes to Spent.", [{"t": "next_phase"}], THEIR_TURN),
			_wait("Opponent's turn", "The Rival draws, summons a unit and ends their turn. Watch the board.", MY_TURN),
			_read("A fresh turn", "Your turn again: AP is back to 2 and you drew four new cards. Last turn's Hand is in your Spent pile, which is shuffled back into Draw when Draw runs out.", [{"pile": ["me", "spent"]}, {"plate": "me"}]),
		],
		"opponent": [
			{"t": "summon", "card": "o_warrior", "stance": "atk"},
			{"t": "choose", "opt": {"slot": 1}},
			{"t": "next_phase"}, {"t": "next_phase"}, {"t": "next_phase"},
		],
	}


# ---------------------------------------------------------------- lesson 2

static func _summoning() -> Dictionary:
	var cards := [
		_c("p_mage", BASIC_MAGE_WATER, PLAYER, "hand"),
		_c("p_warrior", BASIC_WARRIOR_EARTH, PLAYER, "hand"),
		_c("p_wyvern", FROST_WYVERN, PLAYER, "hand"),
		_c("p_wings", WINGS_OF_AURENTHOR, PLAYER, "hand"),
	] + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) + _fill("o_fill", BASIC_MONSTER_NECROTIC, OPPONENT, 8)
	return {
		"id": "summoning",
		"title": "Lesson 2 · Summoning and stances",
		"summary": "Summon units from your Hand into a zone in Attack or Defense stance. Back-row units are protected by an occupied front zone.",
		"setup": {"first": PLAYER, "turn": 1, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Reading a unit", "Units show their AP cost (top left), ATK (red, bottom left) and DEF (blue, bottom right). This Basic Mage costs 1 AP and has 8 ATK and 8 DEF.", [{"card": "p_mage"}]),
			_do("Summon in Attack stance", "Click the Basic Mage in your Hand, then click Summon Attack.", [{"t": "summon", "card": "p_mage", "stance": "atk"}]),
			_do("Choose a zone", "You have six unit zones: three in the front row, three behind. Click the highlighted front-row zone.", [{"t": "choose", "opt": {"slot": 1}}]),
			_read("Attack stance", "Units in Attack stance can attack. When an Attack-stance unit is attacked it compares ATK, and the losing side's controller loses the difference in HP.", [{"slot": ["me", "unit", 1]}]),
			_do("Summon in Defense stance", "Now click the Basic Warrior in your Hand and click Summon Defense.", [{"t": "summon", "card": "p_warrior", "stance": "def"}]),
			_do("Behind the front line", "Put it in the back row, directly behind your Mage.", [{"t": "choose", "opt": {"slot": 4}}]),
			_read("Protection", "A back-row unit is protected while the front-row zone of its column is occupied, so the Rival must deal with your Mage first. A Defense-stance unit compares its DEF and costs you no HP when it is beaten.", [{"slot": ["me", "unit", 4]}, {"slot": ["me", "unit", 1]}]),
			_do("Changing stance", "You may switch stance during the Setup Phase only. Click your Mage on the field and click To Defense.", [{"t": "stance", "card": "p_mage"}]),
			_read("Out of AP", "Both AP are spent, so Frost Wyvern (2 AP) cannot be summoned this turn: it offers no actions. That's summoning!", [{"card": "p_wyvern"}, {"plate": "me"}]),
		],
		"opponent": [],
	}


# ---------------------------------------------------------------- lesson 3

static func _battle() -> Dictionary:
	var cards := [
		_c("p_mage", BASIC_MAGE_WATER, PLAYER, "unit", 0),
		_c("p_soldier", STEADFAST_SOLDIER, PLAYER, "unit", 1),
		_c("p_monster", BASIC_MONSTER_LIGHTNING, PLAYER, "unit", 2),
		_c("o_warrior", BASIC_WARRIOR_FIRE, OPPONENT, "unit", 1),
		_c("o_beast", BASIC_BEAST_EARTH, OPPONENT, "unit", 4, "def"),
	] + _fill("p_hand", BASIC_MAGE_FIRE, PLAYER, 4) + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 4) \
		+ _fill("o_fill", BASIC_MONSTER_NECROTIC, OPPONENT, 8)
	for i in 4:
		cards[5 + i]["zone"] = "hand"
	return {
		"id": "battle",
		"title": "Lesson 3 · Battle",
		"summary": "Attack unprotected units or, once the Rival has no units, the Rival directly. Type advantage adds +6; Defense-stance losses cost no HP.",
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Battle basics", "In the Battle Phase each of your Attack-stance units may attack once. The Rival has a Fire Warrior in front and an Earth Beast in Defense stance behind it.", [{"slot": ["opp", "unit", 1]}]),
			_read("Protected units", "The Beast sits in the back row behind an occupied zone, so it is protected and cannot be attacked yet.", [{"slot": ["opp", "unit", 4]}]),
			_do("Enter the Battle Phase", "Click Go to Battle Phase.", [{"t": "next_phase"}]),
			_do("Declare an attack", "Click your Basic Mage and click Attack.", [{"t": "attack", "card": "p_mage"}]),
			_do("Pick the target", "Water is effective against Fire: your Mage gets +6 ATK for this battle (14 against 8). Click the Fire Warrior.", [{"t": "choose", "opt": {"card": "o_warrior"}}]),
			_read("Result", "The Fire Warrior was destroyed and the Rival lost the difference: 6 HP. With the front zone empty, the Beast is no longer protected.", [{"plate": "opp"}, {"slot": ["opp", "unit", 4]}]),
			_do("Attack the Beast", "Click Steadfast Soldier (14 ATK) and click Attack.", [{"t": "attack", "card": "p_soldier"}]),
			_do("Attack a defender", "The Beast defends with its DEF of 8. Click it.", [{"t": "choose", "opt": {"card": "o_beast"}}]),
			_read("Defense results", "14 beats 8 DEF, so the Beast is destroyed. A unit in Defense stance never costs its controller HP when it loses.", [{"plate": "opp"}]),
			_do("Direct attack", "The Rival has no units left, so your Lightning Monster can attack the Rival directly. Click it and click Attack Direct.", [{"t": "attack", "card": "p_monster"}]),
			_read("Lesson complete", "A direct attack deals the attacker's ATK as damage: 8. The Rival is down to 46 HP.", [{"plate": "opp"}]),
		],
		"opponent": [],
	}


# ---------------------------------------------------------------- lesson 4

static func _spells_traps() -> Dictionary:
	var cards := [
		_c("p_warrior", BASIC_WARRIOR_WATER, PLAYER, "unit", 1, "def"),
		_c("p_offer", SACRED_OFFERINGS, PLAYER, "hand"),
		_c("p_cyl", MAGIC_CYLINDER, PLAYER, "hand"),
		_c("p_h0", BASIC_MAGE_FIRE, PLAYER, "hand"),
		_c("p_h1", BASIC_BEAST_FIRE, PLAYER, "hand"),
		_c("o_warrior", BASIC_WARRIOR_FIRE, OPPONENT, "unit", 1),
	] + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) + _fill("o_fill", BASIC_MONSTER_NECROTIC, OPPONENT, 8)
	return {
		"id": "spells_traps",
		"title": "Lesson 4 · Spells and Traps",
		"summary": "Cast Spells on your turn; set Traps face down and activate them on the Rival's turn when their condition is met.",
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Spells and Traps", "Spells are cast from your Hand in your Setup or Recovery Phase. Traps are set face down and spring on the Rival's turn when their condition is met.", [{"card": "p_offer"}, {"card": "p_cyl"}]),
			_do("Cast a Spell", "Click Sacred Offerings in your Hand and click Cast. It costs 1 AP.", [{"t": "cast", "card": "p_offer"}]),
			_do("Choose its target", "Click your Water Warrior to give it a Rune (Runes are counters used for Ritual summons).", [{"t": "choose", "opt": {"card": "p_warrior"}}]),
			_read("Into Spent", "The Spell resolved and went to your Spent pile. Your Warrior now carries a Rune.", [{"pile": ["me", "spent"]}, {"slot": ["me", "unit", 1]}]),
			_do("Set a Trap", "Click Magic Cylinder and click Set. You pay its AP now, not when it activates.", [{"t": "set", "card": "p_cyl"}]),
			_do("Same column", "Magic Cylinder guards units in its column. Set it in the middle Trap/Spell zone, behind your Warrior.", [{"t": "choose", "opt": {"slot": 1}}]),
			_do("End your turn", "Click the phase button until your turn ends (Battle Phase, Recovery, End turn).", [{"t": "next_phase"}], THEIR_TURN),
			_wait("The Rival attacks", "Watch: the Rival's Fire Warrior attacks your Warrior.", {"pending_kind": "trap_response", "pending_player": PLAYER}),
			_do("Spring the Trap", "Your Trap's condition is met. Click Activate Magic Cylinder.", [{"t": "choose", "opt": {"card": "p_cyl"}}]),
			_wait("The battle goes on", "Magic Cylinder makes the Rival lose HP equal to the attacker's ATK (8); then the attack continues.", MY_TURN),
			_read("Lesson complete", "Your Warrior defended with 8 DEF +6 (Water is effective against Fire) = 14, so the attacker's controller lost the difference: 6 more HP. The used Trap went to Spent.", [{"plate": "opp"}, {"pile": ["me", "spent"]}]),
		],
		"opponent": [
			{"t": "next_phase"},
			{"t": "attack", "card": "o_warrior"},
			{"t": "choose", "opt": {"card": "p_warrior"}},
			{"t": "next_phase"}, {"t": "next_phase"},
		],
	}


# ---------------------------------------------------------------- lesson 5

static func _extra_deck() -> Dictionary:
	var cards := [
		_c("p_beast", BASIC_BEAST_EARTH, PLAYER, "unit", 0),
		_c("p_dragon", BASIC_DRAGON_FIRE, PLAYER, "unit", 1),
		_c("p_poly", POLYMERIZATION, PLAYER, "hand"),
		_c("p_h0", BASIC_MAGE_FIRE, PLAYER, "hand"),
		_c("p_h1", BASIC_WARRIOR_WATER, PLAYER, "hand"),
		_c("p_h2", BASIC_BEAST_FIRE, PLAYER, "hand"),
		_c("p_wyrm", BASTION_WYRM, PLAYER, "extra"),
		_c("p_inferno", RAGING_INFERNO, PLAYER, "extra"),
		_c("p_kaya", GRANDMOTHER_KAYA, PLAYER, "extra"),
		_c("o_monster", BASIC_MONSTER_NECROTIC, OPPONENT, "unit", 1),
	] + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) + _fill("o_fill", BASIC_MONSTER_NECROTIC, OPPONENT, 8)
	return {
		"id": "extra_deck",
		"title": "Lesson 5 · Extra Deck: Fusion",
		"summary": "Fusion units are summoned by tributing the listed materials with a Fusion effect such as Polymerization.",
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("The Extra Deck", "Fusion, Ritual and Arcane units wait in your Extra Deck. They are never drawn; each kind has its own way to be summoned.", [{"pile": ["me", "extra"]}]),
			_read("Fusion materials", "Bastion Wyrm needs a Beast unit and a Dragon unit. Your Earth Beast and Fire Dragon on the field fit.", [{"slot": ["me", "unit", 0]}, {"slot": ["me", "unit", 1]}]),
			_do("Cast Polymerization", "Click Polymerization in your Hand and click Cast.", [{"t": "cast", "card": "p_poly"}]),
			_do("Choose the Fusion unit", "Click Bastion Wyrm.", [{"t": "choose", "opt": {"card": "p_wyrm"}}]),
			_do("Choose its zone", "The materials will be tributed to Spent, freeing their zones. Click the highlighted zone.", [{"t": "choose", "opt": {"slot": 1}}]),
			_do("Choose its stance", "Click Attack stance.", [{"t": "choose", "opt": {"label": "Attack"}}]),
			_read("Tribute", "Beast and Dragon were tributed to Spent: tribute is neither destruction nor sacrifice and refunds no AP. Bastion Wyrm (36 ATK / 40 DEF) arrived and gained Eternal.", [{"slot": ["me", "unit", 1]}, {"pile": ["me", "spent"]}]),
			_read("Ritual and Arcane", "Ritual units (like Raging Inferno) tribute one unit carrying enough Runes. Arcane units (like Grandmother Kaya) exhaust units from your Spent whose costs add up to their requirement.", [{"pile": ["me", "extra"]}]),
			_do("Enter the Battle Phase", "Newly summoned units may attack at once. Click Go to Battle Phase.", [{"t": "next_phase"}]),
			_do("Attack with the Wyrm", "Click Bastion Wyrm and click Attack.", [{"t": "attack", "card": "p_wyrm"}]),
			_do("Pick the target", "Click the Rival's Necrotic Monster.", [{"t": "choose", "opt": {"card": "o_monster"}}]),
			_read("Tutorial complete", "36 ATK against 8: the Monster is destroyed and the Rival loses 28 HP. You have finished the tutorial. Good luck in your first series!", [{"plate": "opp"}]),
		],
		"opponent": [],
	}
