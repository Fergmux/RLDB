class_name DeckStore
extends RefCounted
## Locally saved custom decks. Stored in user://decks.json as [{name, cards: [card ids]}].
## Main/Extra placement is decided by each card's category when a game starts, so a deck is
## one id list.
##
## Size caps (owner answers 2026-10-17 section 1, F16): the combined Main + Extra Deck holds at
## most MAX_CARDS cards, and at most MAX_EXTRA of those may be Extra Deck cards. Category mix and
## duplicates stay unrestricted. The caps are enforced the same way everywhere a custom deck is
## built or used: editing (`add_block_reason`), saving (`validate`) and the start-of-series
## check (Series `custom_deck` calls `validate`). Loading never trims a deck: an oversized save
## from before the cap is listed and opened intact, can only shrink, and saves again once legal.

## The player's saved decks. Automated runs (GdUnit, `-s` dev scripts and `--*-shots` drivers) use
## TEST_PATH instead, so a test can never overwrite or delete the player's real decks. Parallel
## test runs used to back up and restore the real file and could lose it.
static var PATH := _default_path()
const PLAYER_PATH := "user://decks.json"
const TEST_PATH := "user://test_decks.json"


static func _default_path() -> String:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "-s" or args[i] == "--script" or String(args[i]).contains("GdUnitCmdTool"):
			return TEST_PATH
	for a in OS.get_cmdline_user_args():
		if String(a).contains("shots"):
			return TEST_PATH
	return PLAYER_PATH
## Most cards in a deck, Main and Extra Deck combined.
const MAX_CARDS := 99
## Most Extra Deck (Fusion / Ritual / Arcane) cards, counted within MAX_CARDS.
const MAX_EXTRA := 15


static func list() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (d is Array):
		return []
	var out := []
	for e in d:
		out.append({"name": String(e.get("name", "Deck")), "cards": e.get("cards", []).map(func(i): return int(i))})
	return out


## Saves (or replaces by name) a deck.
static func save_deck(name: String, cards: Array) -> void:
	var decks := list().filter(func(e): return e["name"] != name)
	decks.append({"name": name, "cards": cards.map(func(i): return int(i))})
	_write(decks)


static func delete_deck(name: String) -> void:
	_write(list().filter(func(e): return e["name"] != name))


static func _write(decks: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(decks, " "))


## Counts for display: {main, extra} given a deck's card ids.
static func split_counts(cards: Array) -> Dictionary:
	var main := 0
	var extra := 0
	for id in cards:
		if CardDB.has(int(id)) and CardDB.is_extra_category(CardDB.get_def(int(id))["category"]):
			extra += 1
		else:
			main += 1
	return {"main": main, "extra": extra}


## True when card `id` belongs in the Extra Deck (unknown ids count as Main).
static func is_extra(id: int) -> bool:
	return CardDB.has(id) and CardDB.is_extra_category(CardDB.get_def(id)["category"])


## Why one more copy of card `id` cannot join a deck holding `main` + `extra` cards, or ""
## when it can. The editor uses this to disable its Add action (legal-action availability).
static func add_block_reason(main: int, extra: int, id: int) -> String:
	if main + extra >= MAX_CARDS:
		return "The deck is full."
	if is_extra(id) and extra >= MAX_EXTRA:
		return "The Extra Deck is full."
	return ""


## Why deck `cards` (id list) is not legal to save or play, or "" when it is.
static func validate(cards: Array) -> String:
	var c := split_counts(cards)
	var total: int = c["main"] + c["extra"]
	if total > MAX_CARDS:
		return "This deck has %d cards; a deck holds at most %d. Remove cards first." % [total, MAX_CARDS]
	if c["extra"] > MAX_EXTRA:
		return "This deck has %d Extra Deck cards; at most %d are allowed. Remove some first." % [c["extra"], MAX_EXTRA]
	return ""
