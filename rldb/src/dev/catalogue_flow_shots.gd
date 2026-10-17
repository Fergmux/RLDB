extends SceneTree
## Dev-only windowed evidence + flow check for the Card catalogue screen (F14). Run NOT headless:
##   godot --path rldb -s res://src/dev/catalogue_flow_shots.gd -- <absolute output dir> [WxH]
## Opens the catalogue from the main menu and drives it with real pointer / key events: hover,
## select, keyboard navigation, search, category filter, sort, no-results, inspect, Esc priority
## and Esc back. Saves screenshots and quits with the number of failed checks.

var out_dir: String = ""
var main: Node
var cl: CardListScreen
var tag: String = ""
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://catalogue"
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


func _wheel(pos: Vector2, down: bool, n: int) -> void:
	await _move(pos)
	for i in n:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = pos
			ev.global_position = pos
			ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
			ev.pressed = pressed
			ev.factor = 1.0
			root.push_input(ev, true)
		await _frames(2)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev, false)
		await _frames(1)
	await _frames(3)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main._show_card_list()
	await _frames(8)
	cl = main.menu as CardListScreen
	var b := cl.browser
	_check("every card shown", b.visible_count() == CardDB.all().size())
	_check("first card previewed", cl.shown_id() == int(CardDB.all()[0]["id"]))
	await _shot("01_catalogue")

	# Hover and select a unit card in the second row.
	var ids := b.visible_ids()
	var pick := int(ids[mini(b.columns() + 1, ids.size() - 1)])
	var w := b.cell_widget(pick)
	await _move(w.get_global_rect().get_center())
	await _click_node(w)
	_check("click selects into preview", cl.shown_id() == pick and w.selected)
	await _shot("02_selected")

	# Keyboard navigation.
	await _key(KEY_RIGHT)
	_check("Right arrow moves the selection", cl.shown_id() == int(ids[ids.find(pick) + 1]))
	await _key(KEY_DOWN)
	_check("Down arrow moves a row", cl.shown_id() == int(ids[ids.find(pick) + 1 + b.columns()]))

	# Smooth wheel scrolling.
	await _wheel(b.scroll.get_global_rect().get_center(), true, 6)
	await create_timer(0.5).timeout
	_check("wheel scrolls the grid", b.scroll.scroll_vertical > 0)
	await _shot("03_scrolled")
	await _wheel(b.scroll.get_global_rect().get_center(), false, 12)

	# Search, category filter, sort, no results.
	await _click_node(b.search)
	b.search.text = "dragon"
	b.search.text_changed.emit("dragon")
	await _frames(3)
	_check("search narrows the grid", b.visible_count() > 0 and b.visible_count() < CardDB.all().size())
	_check("preview follows the visible set", b.visible_ids().has(cl.shown_id()))
	await _shot("04_search_dragon")
	b.search.text = ""
	b.search.text_changed.emit("")
	b.search.release_focus()
	for i in b.cat_opt.item_count:
		if b.cat_opt.get_item_metadata(i) == "fusion":
			b.cat_opt.select(i)
	b.sort_opt.select(3)   # Highest ATK
	b.refresh()
	await _frames(3)
	var all_fusion := true
	for id in b.visible_ids():
		all_fusion = all_fusion and CardDB.get_def(int(id))["category"] == "fusion"
	_check("category filter shows only Fusion", all_fusion and b.visible_count() > 0)
	await _shot("05_fusion_by_atk")
	b.search.text = "zzzz-no-such-card"
	b.search.text_changed.emit(b.search.text)
	await _frames(3)
	_check("no-results state", b.visible_count() == 0 and b._no_match.visible and cl.preview_is_empty())
	await _shot("06_no_results")
	var clear := b._no_match.find_children("*", "Button", true, false)
	await _click_node(clear[0])
	_check("Clear filters restores everything", b.visible_count() == CardDB.all().size() and not cl.preview_is_empty())
	b.search.release_focus()

	# Inspect, Esc priority, Esc back.
	var w2 := b.cell_widget(int(b.visible_ids()[2]))
	await _click_node(w2, MOUSE_BUTTON_RIGHT)
	_check("right-click inspects", CardInspector.open_count() == 1)
	await _shot("07_inspector")
	await _key(KEY_ESCAPE)
	await _frames(4)
	_check("Esc closes only the inspector", CardInspector.open_count() == 0 and main.menu == cl)
	await _key(KEY_ESCAPE)
	await create_timer(1.4).timeout
	_check("Esc goes back to the main menu", main.menu is MainMenu)
	print("DONE fails=", fails)
	quit(fails)
