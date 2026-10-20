extends SceneTree
## Dev-only windowed evidence + flow check for the deck builder (F03-24, F15-F24). Run NOT headless:
##   godot --path rldb -s res://src/dev/deckbuilder_flow_shots.gd -- <absolute output dir> [WxH]
## Drives the builder with real pointer / key events (select, preview Add/Remove, rapid clicks,
## caps, inspect, Esc priority, name, save, new, load, rename, delete, Esc back with the unsaved
## question) and saves screenshots. Leaves the player's saved decks untouched.

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
	await _snap(name)


func _snap(name: String) -> void:
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


func _press(pos: Vector2, button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button
	ev.pressed = pressed
	root.push_input(ev, true)


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for pressed in [true, false]:
		_press(pos, button, pressed)
		await _frames(1)
	await _frames(3)


func _click_node(c: Control, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _click(c.get_global_rect().get_center(), button)


## `n` clicks one frame apart at `pos` (rapid input).
func _rapid(pos: Vector2, n: int) -> void:
	await _move(pos)
	for i in n:
		_press(pos, MOUSE_BUTTON_LEFT, true)
		await process_frame
		_press(pos, MOUSE_BUTTON_LEFT, false)
		await process_frame


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
	# Leave the field so the edit keys (+ / - / Esc) reach the builder, as after a click elsewhere.
	db.deck_name_edit.release_focus()


func _extra_n() -> int:
	return DeckStore.split_counts(DeckBuilder.counts_to_cards(db.counts))["extra"]


func _select_and_add(id: int, times: int = 1) -> void:
	var w := db.cell_widget(id)
	await _scroll_into_view(w)
	for i in times:
		await _click_node(w)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main._show_deck_builder()
	await _frames(8)
	db = main.menu as DeckBuilder
	DeckStore.delete_deck(DECK_A)
	DeckStore.delete_deck(DECK_B)

	_check("one grid cell per catalogue card", db.browser.grid.get_child_count() == CardDB.all().size())
	_check("F23 no Delete on a new deck", not db.delete_button().visible)
	_check("F20 tabs without counts", db.deck_tabs().tab("saved").title == "Saved Decks" and db.deck_tabs().tab("starters").title == "Structure Decks")
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

	# Hover, then a left-click selects into the preview and adds one copy.
	var wa := db.cell_widget(a)
	await _scroll_into_view(wa)
	await _move(wa.get_global_rect().get_center())
	await create_timer(0.15).timeout
	_check("F2 hovering a catalogue card shows it in the details pane", db.preview_id() == a)
	_check("F2 hovering does not edit the deck", db.counts.is_empty())
	await _shot("02_hover")
	_press(wa.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	await process_frame
	_press(wa.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, false)
	await create_timer(0.14).timeout
	await _snap("02a_click_add_in_flight")
	_check("click selects and adds one", db.preview_id() == a and int(db.counts.get(a, 0)) == 1 and db.counts.size() == 1)
	_check("ghost card in flight during click add", db.ghost_count() >= 1 or UIStyle.reduce_motion)
	await create_timer(0.5).timeout
	await _key(KEY_EQUAL)
	await create_timer(0.14).timeout
	await _snap("02b_add_in_flight")
	_check("ghost card in flight during add", db.ghost_count() >= 1 or UIStyle.reduce_motion)
	await create_timer(0.5).timeout
	_check("+ key adds the shown card", int(db.counts.get(a, 0)) == 2)
	await _select_and_add(b)
	_check("click adds the exact variant id", int(db.counts.get(a, 0)) == 2 and int(db.counts.get(b, 0)) == 1 and db.counts.size() == 2)
	var ctag: Control = db.browser.cell(a).get_meta("tag")
	_check("catalogue count tag below the card", db.cell_count_text(a) == "x2" and ctag.get_global_rect().position.y >= wa.get_global_rect().end.y - 1)
	await _shot("02c_added")

	# Right-click inspects; Esc closes only the inspector (F21).
	var before := db.counts.duplicate()
	await _click_node(db.cell_widget(b), MOUSE_BUTTON_RIGHT)
	_check("right-click opens inspector", CardInspector.open_count() == 1)
	_check("right-click leaves deck unchanged", db.counts == before)
	await _shot("03_inspector")
	await _key(KEY_ESCAPE)
	await _frames(4)
	_check("Esc closes inspector", CardInspector.open_count() == 0)
	_check("Esc with inspector open stays in the builder", main.menu == db and not db._modal_open())

	# A spread of categories (more than a screen of deck rows).
	for cat in ["fusion", "ritual", "arcane", "spell", "trap", "power", "unit"]:
		for d in CardDB.all():
			if d["category"] == cat:
				await _select_and_add(int(d["id"]))
				break
	_check("extra-deck cards routed", _extra_n() >= 3)

	# F17: deck tiles in canonical catalogue order.
	var idx := CardBrowser.catalogue_index()
	var ordered := true
	for key in ["main", "extra"]:
		var ids: Array = (db._sections[key]["flow"] as Node).get_children().map(func(t): return idx[int(t.get_meta("card_id"))])
		var sorted := ids.duplicate()
		sorted.sort()
		ordered = ordered and ids == sorted
	_check("F17 deck tiles in catalogue order", ordered)

	# Deck grid: a click selects and removes one copy; then preview Remove.
	var da := db.deck_widget(a)
	await _scroll_into_view(da)
	await _click_node(da)
	_check("deck tile click selects and removes one", db.preview_id() == a and int(db.counts.get(a, 0)) == 1)
	await _key(KEY_EQUAL)
	await _key(KEY_MINUS)
	_check("+ then - on the shown card nets zero", int(db.counts.get(a, 0)) == 1)

	# Deck grid: right-click inspects without editing.
	var dw := db.deck_widget(b)
	_check("deck grid has a tile for a deck card", dw != null)
	await _scroll_into_view(dw)
	await _shot("03b_deck_grid")
	await _click_node(dw, MOUSE_BUTTON_RIGHT)
	_check("deck tile right-click inspects", CardInspector.open_count() == 1)
	await _key(KEY_ESCAPE)
	db.show_preview(b)

	# F24: rapid clicking (one frame apart) never loses or duplicates an edit.
	var nb := int(db.counts.get(b, 0))
	await _scroll_into_view(db.cell_widget(b))
	await _rapid(db.cell_widget(b).get_global_rect().get_center(), 8)
	await _snap("03c_rapid_adds")
	_check("8 rapid Add clicks = 8 copies", int(db.counts.get(b, 0)) == nb + 8)
	for i in 14:
		await _key(KEY_MINUS)
	await create_timer(0.7).timeout
	_check("14 rapid Remove clicks stop at zero", not db.counts.has(b) and db.deck_widget(b) == null and db.ghost_count() == 0)
	await _move(db.cell_widget(b).get_global_rect().get_center())
	await create_timer(0.12).timeout
	await _key(KEY_EQUAL)
	_check("+ key adds the card under the pointer", int(db.counts.get(b, 0)) == 1)
	await _key(KEY_MINUS)
	_check("- key removes it", not db.counts.has(b))
	await _key(KEY_EQUAL)

	# F16 cap: fill the Extra Deck to 15; Add becomes unavailable for Extra cards.
	var ex := -1
	for d in CardDB.all():
		if d["category"] == "fusion":
			ex = int(d["id"])
			break
	db.add_card(ex, DeckStore.MAX_EXTRA - _extra_n() + 5)
	await _scroll_into_view(db.cell_widget(ex))
	await _click_node(db.cell_widget(ex))
	_check("F16 Extra Deck stops at 15", _extra_n() == DeckStore.MAX_EXTRA)
	_check("F16 Add unavailable for a full Extra Deck", not db.can_add_shown())
	await _key(KEY_EQUAL)
	_check("F16 a refused add does nothing", _extra_n() == DeckStore.MAX_EXTRA)
	await _shot("03d_extra_full")
	for i in 5:
		db.remove_card(ex)

	# Unnamed save: inline error beside the name field, not at the bottom.
	await _click_node(_find_button(db, "Save"))
	_check("unnamed save shows inline error", db.name_error() != "" and not DeckStore.list().any(func(e): return e["name"] == ""))
	await create_timer(0.4).timeout   # let the shake settle
	_check("error sits under the name field", db._name_err.get_global_rect().position.y >= db.deck_name_edit.get_global_rect().end.y - 2 and absf(db._name_err.get_global_rect().position.x - db.deck_name_edit.get_global_rect().position.x) < 4)

	# Name, save.
	await _type_name(DECK_A)
	_check("typing clears the inline error", db.name_error() == "")
	await _click_node(_find_button(db, "Save"))
	var saved := false
	for dk in DeckStore.list():
		if dk["name"] == DECK_A:
			saved = dk["cards"].size() == DeckBuilder.counts_to_cards(db.counts).size()
	_check("Save writes the deck", saved and not db.dirty)
	_check("F23 Delete shows for the saved deck", db.delete_button().is_visible_in_tree())
	await _shot("05_saved")

	# New (clean, no prompt) then load back through the saved list.
	await _click_node(_find_button(db, "New"))
	_check("New empties the deck", db.counts.is_empty())
	_check("F23 Delete hidden after New", not db.delete_button().visible)
	var row := db.saved_row(DECK_A)
	_check("saved deck has a tile", row != null)
	await _click_node(row)
	_check("Load restores the deck", int(db.counts.get(b, 0)) == 1 and int(db.counts.get(a, 0)) == 1 and db.deck_name_edit.text == DECK_A)

	# Search in the grid.
	db.set_filters("dragon")
	await _frames(3)
	_check("search narrows the grid", db.visible_cell_count() < CardDB.all().size() and db.visible_cell_count() > 0)
	await _shot("06_search_dragon")
	db.set_filters("zzzz-nothing")
	await _shot("06b_no_results")
	db.set_filters("")

	# Rename then delete.
	await _type_name(DECK_B)
	await _click_node(_find_button(db, "Rename"))
	var names := DeckStore.list().map(func(e): return e["name"])
	_check("Rename replaces the saved name", names.has(DECK_B) and not names.has(DECK_A))
	await _click_node(db.delete_button())
	await _shot("07_delete_confirm")
	await _click_node(_find_button(db._overlay, "Delete"))
	names = DeckStore.list().map(func(e): return e["name"])
	_check("Delete (confirmed) removes the deck", not names.has(DECK_B))
	_check("F23 Delete hidden after deleting", not db.delete_button().visible)
	await _click_node(db.deck_tabs().tab("starters"))
	await _frames(3)
	await _shot("09_starters")

	# F21: Esc with unsaved edits asks; Esc again cancels; Esc then Discard leaves once.
	await _click_node(db.cell_widget(a))
	await _key(KEY_ESCAPE)
	_check("Esc with unsaved edits asks first", db._modal_open() and main.menu == db)
	await _shot("10_esc_unsaved")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check("Esc again cancels the question", not db._modal_open() and main.menu == db)
	await _key(KEY_ESCAPE)
	await _click_node(_find_button(db._overlay, "Discard"))
	await create_timer(1.4).timeout
	_check("Discard returns to the main menu", main.menu is MainMenu)

	DeckStore.delete_deck(DECK_A)
	DeckStore.delete_deck(DECK_B)
	print("DONE fails=", fails)
	quit(fails)
