class_name TutorialLessons
extends RefCounted
## Lesson data of the guided tutorial (F03-15, design/playtest-feedback-03.md). Pure data: each
## lesson is a deterministic premade board (TutorialSetup), a list of guidance steps and the
## scripted opponent's fixed commands. Cards are referred to by stable card id and a lesson-local
## key, never by display name, so card-name changes cannot break a lesson.
##
## Lesson: {id, title, summary, learned, setup, steps, opponent}
##   Text (summary, learned lines, step text) uses TutorialMarkup tags: [kw] [stat] [card] [type] [zone] [btn] [b] [i].
##   learned: short bullet lines for the lesson-complete card.
##   setup: {first: seat that took game turn 1, turn: the player's turn number, hp: [p0, p1],
##     cards: [{key, id, p, zone: hand|draw|unit|backrow|extra|spent, slot, stance, runes}]}
##     Hand cards are put on top of Draw and drawn by the real start of the player's turn.
##   step: {kind: read|do|wait, title, text, expect: [command pattern], until: condition,
##     focus: [highlight spec]}
##     read: shown until the player clicks Next (every action is blocked meanwhile).
##     do:   only a command matching one `expect` pattern is accepted; the step ends when it
##           succeeds (and `until` holds, when given — e.g. "press the phase button until the turn ends").
##     wait: the scripted opponent acts; the step ends as soon as `until` holds.
##   command pattern: {t, card: key, stance, opt: {slot, zone, card: key, cards: [key], label}}
##     opt.cards: a multi-pick (Arcane materials) of exactly those options, in any order.
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
const BASIC_MONSTER_DARK := 129
const BASIC_MONSTER_FIRE := 114
const BASIC_WARRIOR_LIGHTNING := 132
const BASIC_MONSTER_LIGHTNING := 134
const FROST_WYVERN := 32
const STEADFAST_SOLDIER := 39
const WINGS_OF_AURENTHOR := 80
const FUSION_CEREMONY := 82
const SACRED_OFFERINGS := 83
const MAGIC_CYLINDER := 45
const BASTION_WYRM := 93
const RAGING_INFERNO := 98
const GRANDMOTHER_KAYA := 170
const ACCURSED_ZEALOT := 17
const THE_CREEPING_NULL := 65
const BASIC_WARRIOR_PHYSICAL := 117
const FLEDGLING_DRAKE := 33
const HYDRA := 27
const BOOM := 175
const BASIC_BEAST_LIGHTNING := 133


## All lessons in play order.
static func all() -> Array:
	return [_turn_flow(), _summoning(), _battle(), _spells_traps(), _extra_deck(), _ritual(), _arcane()]


## Index of the lesson with id `id`, or -1.
static func index_of(id: String) -> int:
	var ls := all()
	for i in ls.size():
		if String(ls[i]["id"]) == id:
			return i
	return -1


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
	] + _fill("p_fill", BASIC_MAGE_WATER, PLAYER, 4) + _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 7)
	return {
		"id": "turn_flow",
		"title": "Lesson 1 · A turn of play",
		"summary": "Each turn: draw four, [stat]AP[/stat] back to 2, then [kw]Setup[/kw], [kw]Battle[/kw] and [kw]Recovery[/kw]. Unplayed cards go to [zone]Spent[/zone].",
		"learned": ["A turn runs [kw]Setup[/kw], [kw]Battle[/kw] and [kw]Recovery[/kw]", "You draw four cards and [stat]AP[/stat] resets to 2", "Unplayed cards are sent to [zone]Spent[/zone]"],
		"setup": {"first": PLAYER, "turn": 1, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Welcome to RLDB", "Two players race to bring the other from [stat]60 HP[/stat] to 0.\nThis lesson walks you through one full turn.\n\nClick [btn]Next[/btn] to continue.", [{"plate": "opp"}]),
			_read("Your Hand", "At the start of every turn you draw four fresh cards into your [zone]Hand[/zone].\n\nCards you do not play are sent to your [zone]Spent[/zone] pile when the turn ends.", [{"hand": true}]),
			_read("Action Points", "Cards cost [stat]AP[/stat], the number in a card's top-left corner.\n\nYour AP is reset to [stat]2 AP[/stat] at the start of each of your turns. Unspent AP does not carry over.", [{"plate": "me"}]),
			_read("Phases", "A turn runs [kw]Setup Phase[/kw], [kw]Battle Phase[/kw], [kw]Recovery Phase[/kw].\n\nSummon and set cards in Setup or Recovery; attack in Battle.\nWhoever goes first has no Battle Phase on turn 1.", [{"pips": true}]),
			_do("Move on", "This lesson is about the turn itself, so play nothing yet.\n\nClick [btn]Go to Recovery[/btn].", [{"t": "next_phase"}]),
			_do("End the turn", "In the [kw]Recovery Phase[/kw] you could still summon or set cards.\n\nClick [btn]End turn[/btn]: your remaining Hand goes to [zone]Spent[/zone].", [{"t": "next_phase"}], THEIR_TURN),
			_wait("Opponent's turn", "The Rival draws, summons a unit and ends their turn.\n\nWatch the board.", MY_TURN),
			_read("A fresh turn", "Your turn again: [stat]AP[/stat] is back to 2 and you drew four new cards.\n\nLast turn's Hand is in your [zone]Spent[/zone] pile, which is shuffled back into [zone]Draw[/zone] when Draw runs out.", [{"pile": ["me", "spent"]}, {"plate": "me"}]),
		],
		"opponent": [
			{"t": "summon", "card": "o_warrior"},
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
	] + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) + _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 8)
	return {
		"id": "summoning",
		"title": "Lesson 2 · Summoning and stances",
		"summary": "Summon units from your [zone]Hand[/zone] into a zone. On your turn they enter in [kw]Attack[/kw] stance, and you can switch them to [kw]Defense[/kw]. Back-row units are [kw]protected[/kw] by an occupied front zone.",
		"learned": ["Click [btn]Summon[/btn]: on your turn a unit enters in [kw]Attack stance[/kw]", "Back-row units are [kw]protected[/kw] by the front zone", "Switch stance with [btn]To Defense[/btn] in the [kw]Setup Phase[/kw]"],
		"setup": {"first": PLAYER, "turn": 1, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Reading a unit", "Units show their [stat]AP[/stat] cost (top left), [stat]ATK[/stat] (red, bottom left) and [stat]DEF[/stat] (blue, bottom right).\n\nThis [card]Basic Mage[/card] costs [stat]1 AP[/stat] and has [stat]8 ATK[/stat] and [stat]8 DEF[/stat].", [{"card": "p_mage"}]),
			_do("Summon a unit", "Click the [card]Basic Mage[/card] in your [zone]Hand[/zone], then click [btn]Summon[/btn].", [{"t": "summon", "card": "p_mage"}]),
			_do("Choose a zone", "You have six unit zones: three in the [zone]front row[/zone], three [zone]behind[/zone].\n\nClick the highlighted front-row zone.", [{"t": "choose", "opt": {"slot": 1}}]),
			_read("Attack stance", "Units you summon on your own turn enter in [kw]Attack stance[/kw], and units in Attack stance can attack.\n\nWhen an Attack-stance unit is attacked it compares [stat]ATK[/stat], and the losing side's controller takes the difference as [stat]Damage[/stat].", [{"slot": ["me", "unit", 1]}]),
			_do("Summon another unit", "Now click the [card]Basic Warrior[/card] in your Hand and click [btn]Summon[/btn].", [{"t": "summon", "card": "p_warrior"}]),
			_do("Behind the front line", "Put it in the [zone]back row[/zone], directly behind your Mage.", [{"t": "choose", "opt": {"slot": 4}}]),
			_do("Defense stance", "Switch it to [kw]Defense stance[/kw]: click your Warrior on the field and click [btn]To Defense[/btn].\n\nYou may change stance in the [kw]Setup Phase[/kw], and a unit summoned in the [kw]Recovery Phase[/kw] may change there too.", [{"t": "stance", "card": "p_warrior"}]),
			_read("Protection", "A back-row unit is [kw]protected[/kw] while the front-row zone of its column is occupied, so the Rival must deal with your Mage first.\n\nA [kw]Defense stance[/kw] unit compares its [stat]DEF[/stat] and costs you no [stat]HP[/stat] when it is beaten.", [{"slot": ["me", "unit", 4]}, {"slot": ["me", "unit", 1]}]),
			_read("Out of AP", "Both [stat]AP[/stat] are spent, so [card]Frost Wyvern[/card] ([stat]2 AP[/stat]) cannot be summoned this turn: it offers no actions.\n\nThat's summoning!", [{"card": "p_wyvern"}, {"plate": "me"}]),
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
		+ _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 8)
	for i in 4:
		cards[5 + i]["zone"] = "hand"
	return {
		"id": "battle",
		"title": "Lesson 3 · Battle",
		"summary": "Attack unprotected units or, once the Rival has no units, the Rival directly. Type advantage adds [stat]+6 ATK[/stat]; [kw]Defense[/kw] stance losses cost no [stat]HP[/stat].",
		"learned": ["Each Attack-stance unit attacks once per [kw]Battle Phase[/kw]", "Type advantage adds [stat]+6 ATK[/stat]", "With no enemy units left, attack the Rival [kw]directly[/kw]"],
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Battle basics", "In the [kw]Battle Phase[/kw] each of your Attack-stance units may attack once.\n\nThe Rival has a [type]Fire[/type] Warrior in front and an [type]Earth[/type] Beast in Defense stance behind it.", [{"slot": ["opp", "unit", 1]}]),
			_read("Protected units", "The Beast sits in the [zone]back row[/zone] behind an occupied zone, so it is [kw]protected[/kw] and cannot be attacked yet.", [{"slot": ["opp", "unit", 4]}]),
			_do("Enter the Battle Phase", "Click [btn]Go to Battle Phase[/btn].", [{"t": "next_phase"}]),
			_do("Declare an attack", "Click your [card]Basic Mage[/card] and click [btn]Attack[/btn].", [{"t": "attack", "card": "p_mage"}]),
			_do("Pick the target", "[type]Water[/type] is effective against [type]Fire[/type]: your Mage gets [stat]+6 ATK[/stat] for this battle (14 against 8).\n\nClick the Fire Warrior.", [{"t": "choose", "opt": {"card": "o_warrior"}}]),
			_read("Result", "The Fire Warrior was destroyed and the Rival took the difference as Damage: [stat]6 Damage[/stat].\n\nWith the front zone empty, the Beast is no longer [kw]protected[/kw].", [{"plate": "opp"}, {"slot": ["opp", "unit", 4]}]),
			_do("Attack the Beast", "Click [card]Steadfast Soldier[/card] ([stat]14 ATK[/stat]) and click [btn]Attack[/btn].", [{"t": "attack", "card": "p_soldier"}]),
			_do("Attack a defender", "The Beast defends with its [stat]DEF[/stat] of 8.\n\nClick it.", [{"t": "choose", "opt": {"card": "o_beast"}}]),
			_read("Defense results", "14 beats 8 [stat]DEF[/stat], so the Beast is destroyed.\n\nWhen a unit in [kw]Defense stance[/kw] loses, its controller takes no [stat]Damage[/stat].", [{"plate": "opp"}]),
			_do("Direct attack", "The Rival has no units left, so your [type]Lightning[/type] Monster can attack the Rival directly.\n\nClick it and click [btn]Attack Direct[/btn].", [{"t": "attack", "card": "p_monster"}]),
			_read("Lesson complete", "A [kw]direct attack[/kw] deals the attacker's [stat]ATK[/stat] as [stat]Damage[/stat]: 8.\n\nThe Rival is down to [stat]46 HP[/stat].", [{"plate": "opp"}]),
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
	] + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) + _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 8)
	return {
		"id": "spells_traps",
		"title": "Lesson 4 · Spells and Traps",
		"summary": "Cast [kw]Spells[/kw] on your turn; set [kw]Traps[/kw] face down and activate them on the Rival's turn when their condition is met.",
		"learned": ["[kw]Spells[/kw] are cast from your Hand on your turn", "[kw]Traps[/kw] are set face down and pay [stat]AP[/stat] when set", "A Trap springs on the Rival's turn, then goes to [zone]Spent[/zone]"],
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Spells and Traps", "[kw]Spells[/kw] are cast from your Hand in your Setup or Recovery Phase.\n\n[kw]Traps[/kw] are set face down and spring on the Rival's turn when their condition is met.", [{"card": "p_offer"}, {"card": "p_cyl"}]),
			_do("Cast a Spell", "Click [card]Sacred Offerings[/card] in your [zone]Hand[/zone] and click [btn]Cast[/btn].\n\nIt costs [stat]1 AP[/stat].", [{"t": "cast", "card": "p_offer"}]),
			_do("Choose its target", "Click your [type]Water[/type] Warrior to give it a [kw]Rune[/kw].\n\n(Runes are counters used for Ritual summons.)", [{"t": "choose", "opt": {"card": "p_warrior"}}]),
			_read("Into Spent", "The Spell resolved and went to your [zone]Spent[/zone] pile.\n\nYour Warrior now carries a [kw]Rune[/kw].", [{"pile": ["me", "spent"]}, {"slot": ["me", "unit", 1]}]),
			_do("Set a Trap", "Click [card]Magic Cylinder[/card] and click [btn]Set[/btn].\n\nYou pay its [stat]AP[/stat] now, not when it activates.", [{"t": "set", "card": "p_cyl"}]),
			_do("Same column", "[card]Magic Cylinder[/card] guards units in its column.\n\nSet it in the middle Trap/Spell zone, behind your Warrior.", [{"t": "choose", "opt": {"slot": 1}}]),
			_do("End your turn", "Click the phase button until your turn ends:\n[btn]Go to Battle Phase[/btn], [btn]Go to Recovery[/btn], then [btn]End turn[/btn].", [{"t": "next_phase"}], THEIR_TURN),
			_wait("The Rival attacks", "Watch: the Rival's [type]Fire[/type] Warrior attacks your Warrior.", {"pending_kind": "trap_response", "pending_player": PLAYER}),
			_do("Spring the Trap", "Your Trap's condition is met.\n\nClick [btn]Activate Magic Cylinder[/btn].", [{"t": "choose", "opt": {"card": "p_cyl"}}]),
			_wait("The battle goes on", "[card]Magic Cylinder[/card] makes the Rival take [stat]Damage[/stat] equal to the attacker's [stat]ATK[/stat] (8); then the attack continues.", MY_TURN),
			_read("Lesson complete", "Your Warrior defended with [stat]8 DEF[/stat] +6 ([type]Water[/type] is effective against [type]Fire[/type]) = 14.\nThe attacker's controller took the difference as Damage: [stat]6 more Damage[/stat].\n\nThe used Trap went to [zone]Spent[/zone].", [{"plate": "opp"}, {"pile": ["me", "spent"]}]),
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
		_c("p_poly", FUSION_CEREMONY, PLAYER, "hand"),
		_c("p_h0", BASIC_MAGE_FIRE, PLAYER, "hand"),
		_c("p_h1", BASIC_WARRIOR_WATER, PLAYER, "hand"),
		_c("p_h2", BASIC_BEAST_FIRE, PLAYER, "hand"),
		_c("p_wyrm", BASTION_WYRM, PLAYER, "extra"),
		_c("p_inferno", RAGING_INFERNO, PLAYER, "extra"),
		_c("p_kaya", GRANDMOTHER_KAYA, PLAYER, "extra"),
		_c("o_monster", BASIC_MONSTER_FIRE, OPPONENT, "unit", 1),
	] + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) + _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 8)
	return {
		"id": "extra_deck",
		"title": "Lesson 5 · Extra Deck: Fusion",
		"summary": "[kw]Fusion[/kw] units are summoned by tributing the listed materials with a Fusion effect such as [card]Fusion Ceremony[/card].",
		"learned": ["[kw]Fusion[/kw], [kw]Ritual[/kw] and [kw]Arcane[/kw] units wait in the [zone]Extra Deck[/zone]", "Fusion tributes its listed materials to [zone]Spent[/zone]", "Summoned units may attack at once"],
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("The Extra Deck", "[kw]Fusion[/kw], [kw]Ritual[/kw] and [kw]Arcane[/kw] units wait in your [zone]Extra Deck[/zone].\n\nThey are never drawn; each kind has its own way to be summoned.\nThis lesson is [kw]Fusion[/kw]; the next two cover Ritual and Arcane.", [{"pile": ["me", "extra"]}]),
			_read("Fusion materials", "[card]Bastion Wyrm[/card] needs a [kw]Beast[/kw] unit and a [kw]Dragon[/kw] unit.\n\nYour [type]Earth[/type] Beast and [type]Fire[/type] Dragon on the field fit.", [{"slot": ["me", "unit", 0]}, {"slot": ["me", "unit", 1]}]),
			_do("Cast Fusion Ceremony", "Click [card]Fusion Ceremony[/card] in your [zone]Hand[/zone] and click [btn]Cast[/btn].", [{"t": "cast", "card": "p_poly"}]),
			_do("Choose the Fusion unit", "Click [card]Bastion Wyrm[/card].", [{"t": "choose", "opt": {"card": "p_wyrm"}}]),
			_do("First material", "Pick the materials on the board.\n\nClick your [type]Earth[/type] Beast.", [{"t": "choose", "opt": {"card": "p_beast"}}]),
			_do("Second material", "Click your [type]Fire[/type] Dragon.", [{"t": "choose", "opt": {"card": "p_dragon"}}]),
			_do("Choose its zone", "The materials will be tributed to [zone]Spent[/zone], freeing their zones.\n\nThe zone is the last choice and it commits the summon. Until you pick it nothing has been paid or tributed: [btn]Cancel[/btn] would undo the whole cast.\n\nClick the highlighted zone.", [{"t": "choose", "opt": {"slot": 1}}]),
			_read("Tribute", "The Beast and Dragon were tributed to [zone]Spent[/zone]: tribute is neither destruction nor sacrifice and refunds no [stat]AP[/stat].\n\n[card]Bastion Wyrm[/card] ([stat]36 ATK[/stat] / [stat]40 DEF[/stat]) arrived in [kw]Attack stance[/kw] and gained [kw]Eternal[/kw].", [{"slot": ["me", "unit", 1]}, {"pile": ["me", "spent"]}]),
			_do("Enter the Battle Phase", "Newly summoned units may attack at once.\n\nClick [btn]Go to Battle Phase[/btn].", [{"t": "next_phase"}]),
			_do("Attack with the Wyrm", "Click [card]Bastion Wyrm[/card] and click [btn]Attack[/btn].", [{"t": "attack", "card": "p_wyrm"}]),
			_do("Pick the target", "Click the Rival's [type]Fire[/type] Monster.\n\nNo Type advantage either way: 36 against 8.", [{"t": "choose", "opt": {"card": "o_monster"}}]),
			_read("Lesson complete", "[stat]36 ATK[/stat] against 8: the Monster is destroyed and the Rival takes [stat]28 Damage[/stat].\n\nNext: [kw]Ritual[/kw] summoning, which tributes a unit carrying [kw]Runes[/kw].", [{"plate": "opp"}]),
		],
		"opponent": [],
	}


# ---------------------------------------------------------------- lesson 6

## Ritual (F05-01, design/playtest-feedback-05.md; rules/01-GAME-RULES.md "Ritual", P-10): Runes
## on a unit, one more from a real Rune source, then tributing that unit for a Ritual unit.
## Accursed Zealot starts with 1 Rune and gains its own at the real start of the turn (2), and
## Sacred Offerings makes 3 = The Creeping Null's requirement.
static func _ritual() -> Dictionary:
	var cards := [
		_c("p_zealot", ACCURSED_ZEALOT, PLAYER, "unit", 1),
		_c("p_offer", SACRED_OFFERINGS, PLAYER, "hand"),
		_c("p_null", THE_CREEPING_NULL, PLAYER, "extra"),
		_c("o_warrior", BASIC_WARRIOR_PHYSICAL, OPPONENT, "unit", 1),
	] + _fill("p_hand", BASIC_MAGE_FIRE, PLAYER, 3, "hand") + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) \
		+ _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 8)
	cards[0]["runes"] = 1
	return {
		"id": "ritual",
		"title": "Lesson 6 · Extra Deck: Ritual",
		"summary": "[kw]Ritual[/kw] units are summoned by tributing one of your units that carries enough [kw]Runes[/kw]. The material goes to [zone]Spent[/zone] and loses its Runes.",
		"learned": ["[kw]Runes[/kw] are counters on a unit, added by cards such as [card]Sacred Offerings[/card]", "A Ritual summon tributes one unit with at least the required Runes", "The material goes to [zone]Spent[/zone]; Runes never leave the field with it"],
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("Runes", "[kw]Runes[/kw] are counters on a unit. They are not buffs, so Curse does not remove them.\n\n[card]Accursed Zealot[/card] came with 1 Rune and gains another at the start of each of your turns: it now has 2.", [{"slot": ["me", "unit", 1]}]),
			_read("A Ritual unit", "[card]The Creeping Null[/card] waits in your [zone]Extra Deck[/zone].\n\nIts [kw]Ritual[/kw] requirement is 3: tribute one of your units carrying at least [stat]3 Runes[/stat].", [{"pile": ["me", "extra"]}]),
			_do("Add a Rune", "Click [card]Sacred Offerings[/card] in your [zone]Hand[/zone] and click [btn]Cast[/btn].\n\nIt costs [stat]1 AP[/stat].", [{"t": "cast", "card": "p_offer"}]),
			_do("Choose its target", "Click your [card]Accursed Zealot[/card] to give it a third [kw]Rune[/kw].", [{"t": "choose", "opt": {"card": "p_zealot"}}]),
			_read("Enough Runes", "The Zealot now carries [stat]3 Runes[/stat]: enough for [card]The Creeping Null[/card].\n\nA Ritual summon costs no [stat]AP[/stat]; the Runes are its price.", [{"slot": ["me", "unit", 1]}]),
			_do("Open the Ritual summon", "Click your [zone]Extra Deck[/zone] pile, click [card]The Creeping Null[/card] in the list, then click [btn]Summon[/btn].", [{"t": "ritual", "card": "p_null"}]),
			_do("Choose the material", "Only units with at least 3 Runes are offered.\n\nClick the Zealot to tribute it.", [{"t": "choose", "opt": {"card": "p_zealot"}}]),
			_do("Choose its zone", "The material leaves the field first, so its zone is free for the Ritual unit.\n\nClick the highlighted zone.", [{"t": "choose", "opt": {"slot": 1}}]),
			_read("Where the material went", "The Zealot was tributed to your [zone]Spent[/zone] pile. Its Runes were removed as it left the field: Runes never travel with a card.\n\nOn Summon, [card]The Creeping Null[/card] [kw]Paralysed[/kw] the Rival's units: they cannot attack or move zones.", [{"pile": ["me", "spent"]}, {"slot": ["me", "unit", 1]}]),
			_do("Enter the Battle Phase", "Click [btn]Go to Battle Phase[/btn].", [{"t": "next_phase"}]),
			_do("Attack with the Null", "Click [card]The Creeping Null[/card] and click [btn]Attack[/btn].", [{"t": "attack", "card": "p_null"}]),
			_do("Pick the target", "Click the Rival's [type]Physical[/type] Warrior.\n\nNo Type advantage either way: [stat]40 ATK[/stat] against 8.", [{"t": "choose", "opt": {"card": "o_warrior"}}]),
			_read("Lesson complete", "The Warrior was in Attack stance, so the Rival took the difference as Damage: [stat]32 Damage[/stat].\n\nNext: [kw]Arcane[/kw] summoning, which pays with units from your [zone]Spent[/zone] pile.", [{"plate": "opp"}]),
		],
		"opponent": [],
	}


# ---------------------------------------------------------------- lesson 7

## Arcane (F05-01; rules/01-GAME-RULES.md "Arcane" as superseded by F03-04 exact totals and F03-05
## zero-cost exclusion). Spent: a 0-cost Drake (not offered), a 1-cost Mage and two 2-cost Dragons,
## against Boom's requirement of 3: Mage + either Dragon is exact, both Dragons (4) over-pay and
## any single card under-pays.
static func _arcane() -> Dictionary:
	var cards := [
		_c("s_drake", FLEDGLING_DRAKE, PLAYER, "spent"),
		_c("s_mage", BASIC_MAGE_WATER, PLAYER, "spent"),
		_c("s_wyvern", FROST_WYVERN, PLAYER, "spent"),
		_c("s_hydra", HYDRA, PLAYER, "spent"),
		_c("p_boom", BOOM, PLAYER, "extra"),
		_c("o_beast", BASIC_BEAST_LIGHTNING, OPPONENT, "unit", 1, "def"),
	] + _fill("p_hand", BASIC_MAGE_FIRE, PLAYER, 4, "hand") + _fill("p_fill", BASIC_MAGE_FIRE, PLAYER, 8) \
		+ _fill("o_fill", BASIC_MONSTER_DARK, OPPONENT, 8)
	return {
		"id": "arcane",
		"title": "Lesson 7 · Extra Deck: Arcane",
		"summary": "[kw]Arcane[/kw] units are summoned by exhausting units from your [zone]Spent[/zone] whose current costs total [b]exactly[/b] the requirement. No AP is paid.",
		"learned": ["Arcane materials come from your [zone]Spent[/zone] pile, not the field", "Their current costs must total [b]exactly[/b] the requirement; 0-cost units are not offered", "The materials are [kw]exhausted[/kw] for the rest of the game"],
		"setup": {"first": OPPONENT, "turn": 2, "hp": [START_HP, START_HP], "cards": cards},
		"steps": [
			_read("An Arcane unit", "[card]Boom, Councillor of The Order[/card] is an [kw]Arcane[/kw] unit with a requirement of 3.\n\nIt is paid with units from your [zone]Spent[/zone] pile whose current costs total [b]exactly[/b] 3. You pay no [stat]AP[/stat].", [{"pile": ["me", "extra"]}]),
			_read("Your Spent pile", "Your [zone]Spent[/zone] holds [card]Fledgling Drake[/card] (cost 0), [card]Basic Mage[/card] (1), [card]Frost Wyvern[/card] (2) and [card]Hydra[/card] (2).\n\nA 0-cost unit adds nothing to the total, so the Drake is not offered.", [{"pile": ["me", "spent"]}]),
			_do("Open the Arcane summon", "Click your [zone]Extra Deck[/zone] pile, click [card]Boom, Councillor of The Order[/card] in the list, then click [btn]Summon[/btn].", [{"t": "arcane", "card": "p_boom"}]),
			_read("Exactly 3", "The panel asks you to [stat]pay exactly 3[/stat]. The three empty circles are the cost to pay; each material fills as many circles as its current cost.

Both Dragons would make 4, too much: once one is picked, the other is greyed out ([b]Cannot overpay[/b]). The Mage and one Dragon make exactly 3, and only then can you [btn]Confirm[/btn].", []),
			_do("Choose the materials", "Click the [card]Basic Mage[/card] and one Dragon, then click [btn]Confirm[/btn].", [{"t": "choose", "opt": {"cards": ["s_mage", "s_wyvern"]}}, {"t": "choose", "opt": {"cards": ["s_mage", "s_hydra"]}}]),
			_do("Choose its zone", "Arcane materials come from [zone]Spent[/zone], so they free no zone on the field.\n\nClick the highlighted zone.", [{"t": "choose", "opt": {"slot": 1}}]),
			_read("Exhausted", "The Mage and the Dragon were [kw]exhausted[/kw]: they are in your [zone]Exhaust[/zone] pile for the rest of this game, and their field effects did not trigger.\n\nOn Summon, Boom changed the stance of the Rival's units: the Beast is now in [kw]Attack stance[/kw].", [{"pile": ["me", "exhaust"]}, {"slot": ["me", "unit", 1]}]),
			_do("Enter the Battle Phase", "Click [btn]Go to Battle Phase[/btn].", [{"t": "next_phase"}]),
			_do("Attack with Boom", "Click [card]Boom, Councillor of The Order[/card] and click [btn]Attack[/btn].", [{"t": "attack", "card": "p_boom"}]),
			_do("Pick the target", "[type]Earth[/type] is effective against [type]Lightning[/type]: Boom gets [stat]+6 ATK[/stat] (32 against 8).\n\nClick the Rival's Beast.", [{"t": "choose", "opt": {"card": "o_beast"}}]),
			_read("Tutorial complete", "The Beast was in Attack stance, so the Rival took the difference as Damage: [stat]24 Damage[/stat].\n\nYou have finished the tutorial. Good luck in your first series!", [{"plate": "opp"}]),
		],
		"opponent": [],
	}
