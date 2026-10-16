extends SceneTree
## Dev-only windowed evidence for F03 inspection (F03-01/02/03/12/22/23/26). Run NOT headless:
##   godot --path rldb -s res://src/dev/f03_inspect_shots.gd -- <absolute output dir> [WxH]
## Pushes real pointer events into the viewport for the right-clicks, then saves screenshots.

var out_dir: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var me: int
var checks: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://f03"
	var sz := Vector2i(1600, 1000)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _check(name: String, ok: bool) -> void:
	checks.append([name, ok])
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _click(pos: Vector2, button: int) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.relative = Vector2(4, 0)
	root.push_input(mv, true)
	await _frames(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev, true)
		await _frames(1)
	await _frames(3)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	me = m.active
	main._shown_seat = me
	gs.attach(host.seats[me])
	await _frames(4)
	# Stage: a protecting front unit with a buffed unit behind, a burning unit, spent / extra cards.
	var front := TB.unit(m, me, 1, 0)
	var rear := TB.unit(m, me, 110, 3)
	m.cards[front]["st"]["burn"] = 2
	m.cards[front]["runes"] = 2
	m.cards[rear]["mods"].append({"atk": 4, "def": 0, "until": "turn", "src": "Rally"})
	TB.unit(m, me, 120, 1)
	TB.unit(m, 1 - me, 115, 0)
	TB.set_card(m, 1 - me, 45, 1)
	for id in [1, 110, 120, 115, 99, 19, 15, 172]:
		TB.card(m, me, id, "spent")
	for id in [172]:
		TB.card(m, me, id, "extra")
	m.players[me]["ap"] = 4
	host.broadcast()
	await _frames(6)
	await _shot("00_board_no_empty_hand_text_default")

	# F03-01: right-click a field card.
	var w: CardWidget = gs.fx_slot_item(me, "unit", 0)["widget"]
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check("right-click field card opens inspector", CardInspector.open_count() == 1)
	_check("no selection / no command", gs.selected_uid == -1 and gs.debug_sent == 0)
	await _shot("01_inspect_field_unit_protecting")
	CardInspector.close_topmost()
	await _frames(3)
	w = gs.fx_slot_item(me, "unit", 3)["widget"]
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	await _shot("02_inspect_field_unit_protected_modifier")
	await _click(Vector2(20, 500), MOUSE_BUTTON_LEFT)       # click outside closes
	_check("click outside closes inspector", CardInspector.open_count() == 0)

	# Hand card.
	if not gs.hand.order.is_empty():
		var hw: CardWidget = gs.hand.items[gs.hand.order[0]]["widget"]
		await _click(hw.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
		_check("right-click hand card opens inspector", CardInspector.open_count() == 1)
		await _shot("03_inspect_hand_card")
		CardInspector.close_topmost()
		await _frames(3)

	# Hidden opposing set card: not inspectable.
	var hid: CardWidget = gs.fx_slot_item(1 - me, "backrow", 1)["widget"]
	await _click(hid.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check("hidden opposing card is not inspectable", CardInspector.open_count() == 0)

	# F03-02: right-click own Spent pile.
	var ps: PileStack = gs.board.piles[1]["spent"]
	await _click(ps.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check("right-click Spent opens browser", gs.inspect.browser != null and is_instance_valid(gs.inspect.browser))
	await _shot("04_spent_browser")
	var b: PileBrowser = gs.inspect.browser
	var c0: CardWidget = b.card_widgets()[2]
	await _click(c0.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check("right-click browser card opens inspector over it", CardInspector.open_count() == 1)
	await _shot("05_browser_card_inspected")
	await _click(Vector2(10, 10), MOUSE_BUTTON_LEFT)
	_check("closing card returns to browser", CardInspector.open_count() == 0 and is_instance_valid(b) and not b.is_queued_for_deletion())
	await _shot("06_back_in_browser")
	gs.inspect.close_top()
	await _frames(3)

	# Draw (random order) and empty Exhaust.
	await _click((gs.board.piles[1]["draw"] as Control).get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	await _shot("07_draw_browser_large_pile")
	gs.inspect.close_top()
	await _frames(3)
	await _click((gs.board.piles[1]["exhaust"] as Control).get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	await _shot("08_exhaust_browser_empty")
	gs.inspect.close_top()
	await _frames(3)

	# F03-26: left-click the Spent pile (sidebar list), then empty board space.
	await _click(ps.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check("left-click pile opens sidebar list", gs.details.pile_zone == "spent")
	await _shot("09_sidebar_pile_list")
	await _click(Vector2(60, 460), MOUSE_BUTTON_LEFT)
	_check("empty-space click closes the pile list", gs.details.pile_zone == "" and gs.debug_sent == 0)
	await _shot("10_after_empty_space_click")

	var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(checks, "  "))
	f.close()
	print("F03 SHOTS DONE: %d checks" % checks.size())
	quit()
