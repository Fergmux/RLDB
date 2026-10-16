extends Node
## Dev: `-- --deckbuilder-shots=<dir>` drives the deck builder from the main menu, saves a deck,
## captures four screenshots into `dir`, deletes the deck again and quits.

const SETTLE_FRAMES := 4
const SHOT_DECK := "Screenshot Deck"


## Runs the capture sequence on `main` (the Main scene root).
func run(main: Control, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _frames(5)
	main._show_menu()
	await _frames(SETTLE_FRAMES)
	await _shot_to(dir, "01_main_menu")
	main._show_deck_builder()
	await _frames(SETTLE_FRAMES)
	var db: DeckBuilder = main.menu as DeckBuilder
	await _shot_to(dir, "02_builder_empty")
	db.set_filters("dragon")
	db.deck_name_edit.text = SHOT_DECK
	var added := 0
	for d in CardDB.all():
		if added >= 10:
			break
		if DeckBuilder.matches(d, "dragon", "", "", "", ""):
			db.add_card(int(d["id"]), 2 if added < 2 else 1)
			added += 1
	for cost in ["kind:fusion", "kind:ritual", "kind:arcane"]:
		for d in CardDB.all():
			if DeckBuilder.matches(d, "", "", "", "", cost):
				db.add_card(int(d["id"]))
				break
	for d in CardDB.all():
		if d["category"] in ["spell", "trap", "power"]:
			db.add_card(int(d["id"]))
			if db.counts.size() > 18:
				break
	for d in CardDB.all():
		if d["category"] == "fusion":
			db.show_preview(int(d["id"]))
			break
	await _frames(3)
	await _shot_to(dir, "03_builder_search_dragon")
	db.set_filters("")
	db._cat_opt.select(db._cat_opt.item_count - 1)
	db._refresh_catalogue()
	db.save()
	await _frames(3)
	await _shot_to(dir, "04_builder_saved_filter_arcane")
	DeckStore.delete_deck(SHOT_DECK)  # leave the player's decks untouched
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot_to(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
