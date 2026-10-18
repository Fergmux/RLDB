extends SceneTree
## Dev-only windowed evidence for the 2026-10-18 card redesign (design/card-redesign-2026-10-18.md):
## card art on every card kind, statuses as icons over the art with the instant name tip, the field /
## hand / inspector / catalogue / deck builder versions, and the material surfaces on menus and
## panels. Run NOT headless:
##   godot --path rldb -s res://src/dev/card_redesign_shots.gd -- <absolute output dir> [WxH]

var out_dir: String = ""
var tag: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var me: int
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://card_redesign"
	var sz := Vector2i(1600, 1000)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	root.size = sz
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.5).timeout
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
	mv.relative = Vector2(2, 0)
	root.push_input(mv, true)
	await _frames(3)


func _click(pos: Vector2, button: int) -> void:
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


## Every visible Label text on screen.
func _visible_text() -> String:
	var parts := []
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).is_visible_in_tree():
			parts.append((n as Label).text)
	return " | ".join(parts)


func _widget(p: int, zone: String, slot: int) -> CardWidget:
	return gs.fx_slot_item(p, zone, slot)["widget"]


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	await _shot("00_main_menu")
	main.menu.pick("credits")
	await create_timer(0.6).timeout
	_check("the Credits panel lists the icon and texture licences", _visible_text().contains("CC BY 3.0") and _visible_text().contains("CC0"))
	await _shot("00b_credits")
	main.menu.pick("settings")
	await create_timer(0.6).timeout
	await _shot("00c_settings_surfaces")
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 9})
	host.handle(1, {"t": "pick_starter", "index": 2})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	me = m.active
	var foe := 1 - me
	main._shown_seat = me
	gs.attach(host.seats[me])
	await _frames(4)

	# Stage: every card kind with art, and units carrying buffs, debuffs and Runes.
	var witch := TB.unit(m, me, 13, 0)
	for st in ["eternal", "pierce", "medic"]:
		m.cards[witch]["st"][st] = 1
	m.cards[witch]["st"]["poison"] = 3
	var necro := TB.unit(m, me, 188, 1)
	m.cards[necro]["st"]["burn"] = 2
	m.cards[necro]["st"]["blind"] = 1
	m.cards[necro]["runes"] = 2
	var guard := TB.unit(m, me, 186, 2, "def")                 # Bronze Salaman in Defense, with statuses
	m.cards[guard]["st"]["paralyse"] = 1
	m.cards[guard]["st"]["cleanse"] = 2
	var crowd := TB.unit(m, me, 185, 3)                        # Drako: more statuses than fit
	for st in ["retain", "eternal", "pierce", "cleanse", "medic", "infiltrate", "nimble", "burn", "paralyse", "curse", "poison", "blind", "debilitate"]:
		m.cards[crowd]["st"][st] = 1
	TB.unit(m, me, 187, 4)
	TB.power(m, me, 169, 0)
	TB.unit(m, foe, 105, 0)
	TB.unit(m, foe, 102, 1)
	TB.unit(m, foe, 10, 2, "def")
	TB.power(m, foe, 139, 0)
	var trap := TB.set_card(m, foe, 184, 0)
	m.cards[trap]["face_up"] = true
	TB.set_card(m, me, 83, 1)
	for id in [182, 13, 140, 104, 56]:
		TB.card(m, me, id, "hand")
	m.players[me]["ap"] = 4
	host.broadcast()
	await create_timer(4.0).timeout                            # coin flip
	await _shot("01_board")

	# Art on every visible card.
	var arts := 0
	var faces := 0
	for n in root.find_children("*", "CardWidget", true, false):
		var w := n as CardWidget
		if w.is_visible_in_tree() and not w.view.is_empty() and not w.view.get("hidden", false) and w.view.has("id"):
			faces += 1
			if CardArt.texture_for(w.view) != null:
				arts += 1
	_check("every face-up card on screen has its art (%d/%d)" % [arts, faces], faces > 0 and arts == faces)

	# Status icons: drawn over the art, named at once on hover.
	var ww := _widget(me, "unit", 0)
	var hits := ww.status_hits()
	_check("Chaos Witch shows 4 status icons", hits.size() == 4)
	var art_rect: Rect2 = Rect2(ww.card_rect().position + Vector2(3, 3) * (ww.card_rect().size.x / 85.0), Vector2(79, 79) * (ww.card_rect().size.x / 85.0))
	_check("the icons sit over the art", hits.all(func(h): return art_rect.encloses((h["rect"] as Rect2).grow(-2.0))))
	var gp: Vector2 = ww.get_global_transform_with_canvas() * (hits[3]["rect"] as Rect2).get_center()
	await _move(gp)
	_check("hovering the Poison icon names it at once: '%s'" % StatusTip.shown_text(), StatusTip.shown_text() == "Poison ×3")
	await _shot("02_status_tip_poison")
	var gw := _widget(me, "unit", 2)
	var gh := gw.status_hits()
	_check("a Defense unit shows its statuses (%d)" % gh.size(), gh.size() == 2)
	await _move(gw.get_global_transform_with_canvas() * (gh[0]["rect"] as Rect2).get_center())
	_check("the Defense unit's icon tip: '%s'" % StatusTip.shown_text(), StatusTip.shown_text() == "Cleanse ×2")
	await _shot("03_status_tip_defense")
	var cw := _widget(me, "unit", 3)
	var ch := cw.status_hits()
	var last: Dictionary = ch[ch.size() - 1]
	_check("13 statuses collapse into a +N token (%d icons)" % ch.size(), ch.size() < 13 and String(last["label"]).contains("\n"))
	await _move(cw.get_global_transform_with_canvas() * (last["rect"] as Rect2).get_center())
	await _shot("04_status_tip_overflow")
	var nw := _widget(me, "unit", 1)
	var nh := nw.status_hits()
	_check("Runes come first: '%s'" % nh[0]["label"], nh.size() == 3 and nh[0]["label"] == "Rune ×2")
	await _move(Vector2(40, 470))
	_check("leaving the icon hides the tip", StatusTip.shown_text() == "")

	# Inspector: the big card.
	await _click(nw.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	await _shot("05_inspect_unit_statuses")
	var big: CardWidget = null
	for n in root.find_children("*", "CardWidget", true, false):
		if (n as CardWidget).size_kind == "big" and (n as CardWidget).is_visible_in_tree():
			big = n
	_check("the inspector's big card has its art and status icons", big != null and CardArt.texture_for(big.view) != null and big.status_hits().size() == 3)
	if big != null and not big.status_hits().is_empty():
		await _move(big.get_global_transform_with_canvas() * (big.status_hits()[1]["rect"] as Rect2).get_center())
		_check("inspector icon tip: '%s'" % StatusTip.shown_text(), StatusTip.shown_text() == "Burn ×2")
		await _shot("06_inspect_status_tip")
	CardInspector.close_topmost()
	await _frames(4)
	await _click(_widget(me, "power", 0).get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	await _shot("07_inspect_power")
	CardInspector.close_topmost()
	await _frames(4)

	# Hand (2026-10-18): a hovered card grows to 1.75x, entirely on screen, with no tooltip.
	gs.hover.debug_hover_hand(4)                                # Shimmer Serum: a long rules text
	await create_timer(0.5).timeout
	var hv: Dictionary = gs.hover.hv
	var hw: CardWidget = hv.get("w")
	_check("the hovered hand card has no tooltip", hw != null and hw.tooltip_text == "")
	var tr: Rect2 = gs.hover.target_rect(hv)
	_check("the hovered hand card is 1.75x and on screen (%s)" % tr, absf(tr.size.x / (hv["holder"] as Control).get_global_rect().size.x - 1.75) < 0.01 and root.get_visible_rect().encloses(tr))
	await _shot("08_hand_hover")
	gs.hover.debug_clear()
	await _frames(4)
	await _move(Vector2(40, 470))

	# Catalogue and deck builder.
	main._show_card_list()
	await _frames(10)
	await create_timer(1.0).timeout
	await _shot("09_catalogue")
	main._show_deck_builder()
	await _frames(10)
	await create_timer(1.0).timeout
	await _shot("10_deck_builder")
	print("CARD REDESIGN SHOTS DONE fails=%d" % fails)
	quit(1 if fails else 0)
