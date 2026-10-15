class_name DeckStore
extends RefCounted
## Locally saved custom decks (P-03: unrestricted size, mix and duplicates for now).
## Stored in user://decks.json as [{name, cards: [card ids]}]. Main/Extra placement is
## decided by each card's category when a game starts, so a deck is one id list.

const PATH := "user://decks.json"


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
		if CardDB.is_extra_category(CardDB.get_def(int(id))["category"]):
			extra += 1
		else:
			main += 1
	return {"main": main, "extra": extra}
