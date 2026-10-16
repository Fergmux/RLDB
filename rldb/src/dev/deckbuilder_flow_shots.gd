extends SceneTree
## Dev-only windowed evidence + flow check for the deck builder (F03-24). Run NOT headless:
##   godot --path rldb -s res://src/dev/deckbuilder_flow_shots.gd -- <absolute output dir> [WxH]
## Drives the builder with real pointer / key events (add, inspect, name, save, new, load,
## rename, delete) and saves screenshots. Leaves the player's saved decks untouched.

const DECK_A := "Flow Test Deck"
const DECK_B := "Flow Test Renamed"

var out_dir: String = ""
var main: Node
var db: DeckBuilder
var tag: String = ""
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://deckbuilder"
	var sz := Vector2i(1600, 1000)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _move(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.relative = Vector2(4, 0)
	root.push_input(mv, true)
	await _frames(3)


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev, true)
		await _frames(1)
	await _frames(3)


func _click_node(c: Control, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _click(c.get_global_rect().get_center(), button)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev, false)
		await _frames(1)
	await _frames(3)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and not (node is OptionButton) and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null


func _scroll_into_view(w: Control) -> void:
	var n: Node = w
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(w)
	await _frames(3)


func _type_name(text: String) -> void:
	await _click_node(db.deck_name_edit)
	db.deck_name_edit.text = text
	db.deck_name_edit.text_changed.emit(text)
	await _frames(2)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main._show_deck_builder()
	await _frames(8)
	db = main.menu as DeckBuilder
	DeckStore.delete_deck(DECK_A)
	DeckStore.delete_deck(DECK_B)

	_check("one grid cell per catalogue card", db._grid.get_child_count() == CardDB.all().size())
	await _shot("01_empty")

	# Same-name basic variants: find two ids whose names share a stem but differ in Type.
	var stems := {}
	var pair := []
	for d in CardDB.all():
		if d["category"] != "basic_unit":
			continue
		var stem := String(d["name"]).split(" (")[0]
		if stems.has(stem) and pair.is_empty():
			pair = [stems[stem], int(d["id"])]
		stems[stem] = int(d["id"])
	_check("found same-name basic variants", pair.size() == 2)
	var a: int = pair[0]
	var b: int = pair[1]
	print("variants: ", CardDB.get_def(a)["name"], " type=", CardDB.get_def(a)["type"], " | ", CardDB.get_def(b)["name"], " type=", CardDB.get_def(b)["type"])

	# Hover highlight + left-click add (real events).
	var wa := db.cell_widget(a)
	await _scroll_into_view(wa)
	await _move(wa.get_global_rect().get_center())
	await _shot("02_hover")
	await _click_node(wa)
	await _click_node(wa)
	var wb := db.cell_widget(b)
	await _scroll_into_view(wb)
	await _click_node(wb)
	_check("left-click adds the clicked variant id", int(db.counts.get(a, 0)) == 2 and int(db.counts.get(b, 0)) == 1 and db.counts.size() == 2)

	# Right-click inspects without changing the deck.
	var before := db.counts.duplicate()
	await _click_node(wb, MOUSE_BUTTON_RIGHT)
	_check("right-click opens inspector", CardInspector.open_count() == 1)
	_check("right-click leaves deck unchanged", db.counts == before)
	await _shot("03_inspector")
	await _key(KEY_ESCAPE)
	_check("Esc closes inspector", CardInspector.open_count() == 0)

	# Add a spread of other cards through the grid (more than a screen of deck rows).
	for cat in ["fusion", "ritual", "arcane", "spell", "trap", "power", "unit"]:
		for d in CardDB.all():
			if d["category"] == cat:
				var w := db.cell_widget(int(d["id"]))
				await _scroll_into_view(w)
				await _click_node(w)
				break
	_check("extra-deck cards routed", DeckStore.split_counts(DeckBuilder.counts_to_cards(db.counts))["extra"] >= 3)

	# Remove via the cell "-" button.
	var minus: Button = db._cells[a]["remove"]
	await _scroll_into_view(wa)
	await _click_node(minus)
	_check("cell minus removes one copy", int(db.counts.get(a, 0)) == 1)

	# Deck grid: tiles exist for the deck, click removes one, right-click inspects, + adds.
	var dw := db.deck_widget(b)
	_check("deck grid has a tile for a deck card", dw != null)
	await _scroll_into_view(dw)
	await _shot("03b_deck_grid")
	await _click_node(dw, MOUSE_BUTTON_RIGHT)
	_check("deck tile right-click inspects", CardInspector.open_count() == 1)
	await _key(KEY_ESCAPE)
	var nb := int(db.counts.get(b, 0))
	await _click_node(db.deck_widget(b))
	_check("deck tile click removes one", int(db.counts.get(b, 0)) == nb - 1)
	await _scroll_into_view(wb)
	await _click_node(wb)
	_check("catalogue click re-adds", int(db.counts.get(b, 0)) == nb)

	# Unnamed save: inline error beside the name field, not at the bottom.
	await _click_node(_find_button(db, "Save"))
	_check("unnamed save shows inline error", db.name_error() != "" and not DeckStore.list().any(func(e): return e["name"] == ""))
	_check("error sits under the name field", db._name_err.get_global_rect().position.y >= db.deck_name_edit.get_global_rect().end.y - 2 and absf(db._name_err.get_global_rect().position.x - db.deck_name_edit.get_global_rect().position.x) < 4)
	await _shot("03c_name_error")

	# Name, save.
	await _type_name(DECK_A)
	_check("typing clears the inline error", db.name_error() == "")
	await _shot("04_named_unsaved")
	await _click_node(_find_button(db, "Save"))
	var saved := false
	for dk in DeckStore.list():
		if dk["name"] == DECK_A:
			saved = dk["cards"].size() == DeckBuilder.counts_to_cards(db.counts).size()
	_check("Save writes the deck", saved and not db.dirty)
	await _shot("05_saved")

	# New (clean, no prompt) then load back through the saved list.
	await _click_node(_find_button(db, "New"))
	_check("New empties the deck", db.counts.is_empty())
	var row := db.saved_row(DECK_A)
	_check("saved deck has a tile", row != null)
	await _shot("05b_saved_tiles")
	await _click_node(row)
	_check("Load restores the deck", int(db.counts.get(b, 0)) == 1 and int(db.counts.get(a, 0)) == 1 and db.deck_name_edit.text == DECK_A)

	# Filter + search in the grid.
	db.set_filters("dragon")
	await _frames(3)
	_check("search narrows the grid", db.visible_cell_count() < CardDB.all().size() and db.visible_cell_count() > 0)
	await _shot("06_search_dragon")
	db.set_filters("")

	# Rename then delete.
	await _type_name(DECK_B)
	await _shot("06b_rename_typed")
	await _click_node(_find_button(db, "Rename"))
	var names := DeckStore.list().map(func(e): return e["name"])
	_check("Rename replaces the saved name", names.has(DECK_B) and not names.has(DECK_A))
	await _click_node(_find_button(db, "Delete"))
	await _shot("07_delete_confirm")
	await _click_node(_find_button(db._overlay, "Delete"))
	names = DeckStore.list().map(func(e): return e["name"])
	_check("Delete (confirmed) removes the deck", not names.has(DECK_B))
	await _shot("08_after_delete")
	db._tab_starters.pressed.emit()
	await _frames(3)
	await _shot("09_starters")

	DeckStore.delete_deck(DECK_A)
	DeckStore.delete_deck(DECK_B)
	print("DONE fails=", fails)
	quit(fails)
