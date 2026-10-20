extends SceneTree
## Dev-only windowed evidence for the 22 Oct menus items (owner feedback J1, J2, J24). Run NOT headless:
##   godot --path rldb -s res://src/dev/j_menus_shots.gd -- <abs out dir> [WxH] --no-steam
## Saves PNGs into the out dir and prints PASS / FAIL lines; quits with the number of failures.
##   J2  the main-menu background's rendered rect, sampled over many frames and over a full cycle
##       of every tween running on it, must never change (rock steady).
##   J1  the deck builder's saved-deck edit / delete icons are true circles (square boxes).
##   J24 Play vs Bot with Custom decks shows "Choose the bot's deck"; with it on, your pick opens
##       a second deck screen for the bot (title, Back), and the bot then plays the deck chosen.
## Scripted runs use the TEST stores (DeckStore / PlayerStats pick them for `-s` runs; the saves
## folder and the "has played" flag are redirected here), so the player's own data is never touched.

const DECK_A := "Ember Rush"
const DECK_B := "Tidecaller Control"
## Frames sampled for the background probe, and the tween step (s) / steps of the cycle probe.
const PROBE_FRAMES := 240
const CYCLE_STEP := 0.25
const CYCLE_STEPS := 200

var out_dir: String = ""
var main: Node
var sz := Vector2i(1600, 900)
var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://j_menus"
	for a in args.slice(1):
		if String(a).contains("x") and not String(a).begins_with("--"):
			var p := String(a).split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(300.0).timeout.connect(func(): print("FAIL watchdog"); quit(99))
	run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", what, "  ", detail)
	else:
		fails += 1
		print("FAIL ", what, "  ", detail)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String, wait: float = 0.8) -> Image:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)
	return img


## Saves an upscaled crop of `img` around `r` (layout px; evidence of small details such as icon
## shapes). The project stretches the canvas, so layout px map to window px by the stretch scale.
func _zoom(img: Image, r: Rect2, name: String, k: int = 4) -> void:
	var s := float(img.get_height()) / root.get_visible_rect().size.y
	var px := Rect2(r.position * s, r.size * s).grow(10.0)
	var ri := Rect2i(px).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if ri.size.x <= 0 or ri.size.y <= 0:
		return
	var c := img.get_region(ri)
	c.resize(ri.size.x * k, ri.size.y * k, Image.INTERPOLATE_NEAREST)
	c.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func run() -> void:
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	_check("deck store uses the TEST path", DeckStore.PATH == DeckStore.TEST_PATH, DeckStore.PATH)
	if DeckStore.PATH != DeckStore.TEST_PATH:
		quit(1)
		return
	_seed_decks()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(8)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	await create_timer(1.2).timeout
	var mm := main.menu as MainMenu
	_check("main menu shown", mm != null)
	if mm == null:
		quit(1)
		return
	await _shot("j2_01_main_menu", 1.5)
	await _probe_background(mm)
	await _j24_menu(mm)
	await _j1_builder()
	await _j24_flow()
	for n in [DECK_A, DECK_B]:
		DeckStore.delete_deck(n)
	print("J MENUS DONE fails=%d" % fails)
	quit(fails)


func _seed_decks() -> void:
	var units := []
	var spells := []
	for d in CardDB.all():
		if d["category"] == "unit" and units.size() < 14:
			units.append(int(d["id"]))
		elif d["category"] in ["spell", "trap"] and spells.size() < 8:
			spells.append(int(d["id"]))
	DeckStore.save_deck(DECK_A, units.slice(0, 10) + spells.slice(0, 4))
	DeckStore.save_deck(DECK_B, units.slice(4, 14) + spells.slice(4, 8))


# ---------------------------------------------------------------- J2

## The background's rendered rect: its global rect as the canvas draws it (a Control's translation
## is rounded to whole pixels while "snap controls to pixels" is on and it is not rotated).
static func rendered_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var o := xf.origin
	if c.get_viewport() != null and c.get_viewport().gui_snap_controls_to_pixels:
		o = (o + Vector2(0.5, 0.5)).floor()
	return Rect2(o, c.size * xf.get_scale())


func _probe_background(mm: MainMenu) -> void:
	var art: Control = mm.backdrop.get_child(0)
	var seen := {}
	var first := rendered_rect(art)
	var worst := 0.0
	for i in PROBE_FRAMES:
		await process_frame
		var r := rendered_rect(art)
		seen[str(r)] = true
		worst = maxf(worst, maxf((r.position - first.position).abs().length(), (r.size - first.size).abs().length()))
	_check("J2 background rect is constant over %d frames" % PROBE_FRAMES, seen.size() == 1, "distinct=%d worst=%.2fpx" % [seen.size(), worst])
	# A full cycle of every tween on the menu (the old Ken Burns drift took 40 s), stepped by hand.
	var tweens := get_processed_tweens()
	var cyc := {}
	var jumps := 0
	var prev := rendered_rect(art)
	for s in CYCLE_STEPS:
		for tw in tweens:
			if tw.is_valid():
				tw.custom_step(CYCLE_STEP)
		var r := rendered_rect(art)
		cyc[str(r)] = true
		if r.position != prev.position:
			jumps += 1
		prev = r
	_check("J2 background rect is constant over a %.0f s tween cycle" % (CYCLE_STEP * CYCLE_STEPS), cyc.size() == 1,
		"distinct=%d origin jumps=%d scale=%s" % [cyc.size(), jumps, str(mm.backdrop.scale)])


# ---------------------------------------------------------------- J24 (menu)

func _item(mm: MainMenu, text: String) -> MenuItem:
	for c in mm._menu_list.get_children():
		if c is MenuItem and (c as MenuItem).label_text == text:
			return c
	return null


func _j24_menu(mm: MainMenu) -> void:
	mm.pick("@play")
	await _frames(2)
	mm.pick("@local")
	await _frames(2)
	main.options.series["deck_mode"] = "starter"
	if main.options.has_method("set_choose_bot_deck"):
		main.options.call("set_choose_bot_deck", false)
	mm.pick("bot")
	await _shot("j24_01_bot_panel_off")
	var cb: CheckBox = mm.find_child("ChooseBotDeck", true, false)
	_check("J24 Play vs Bot shows the Choose the bot's deck box", cb != null and cb.is_visible_in_tree())
	if cb == null:
		return
	cb.button_pressed = true
	await _shot("j24_02_bot_panel_on", 0.5)
	_check("J24 the box is remembered", bool(main.options.call("load_choose_bot_deck")))
	var dm := _deck_mode_picker(mm)
	if dm != null:
		dm.select(1)
		dm.item_selected.emit(1)
		await _frames(2)
		_check("J24 the box hides with Draft", not cb.is_visible_in_tree())
		await _shot("j24_03_bot_panel_draft", 0.5)
		dm.select(0)
		dm.item_selected.emit(0)
		await _frames(2)
		_check("J24 the box shows again with Custom decks", cb.is_visible_in_tree())


func _deck_mode_picker(mm: MainMenu) -> OptionButton:
	for ob in mm.find_children("*", "OptionButton", true, false):
		if (ob as OptionButton).item_count == 2 and (ob as OptionButton).get_item_text(0) == "Custom decks":
			return ob
	return null


# ---------------------------------------------------------------- J1

func _j1_builder() -> void:
	main._show_deck_builder()
	await _frames(6)
	var db := main.menu as DeckBuilder
	_check("J1 deck builder shown", db != null)
	if db == null:
		return
	var img := await _shot("j1_01_builder_saved_list", 1.0)
	var btns := db.find_children("*", "IconBtn", true, false)
	if btns.is_empty():
		for c in db.find_children("*", "Button", true, false):
			if c is DeckBuilder.IconBtn:
				btns.append(c)
	_check("J1 saved decks show edit / delete icons", btns.size() >= 4, "n=%d" % btns.size())
	var round_ok := true
	var sizes := []
	var box := Rect2()
	for b in btns:
		var bb := b as Control
		sizes.append(bb.size)
		if absf(bb.size.x - bb.size.y) > 0.5:
			round_ok = false
		var cx := bb.get_global_transform_with_canvas()   # screen pixels (the canvas is stretched)
		var sr := Rect2(cx.origin, bb.size * cx.get_scale())
		box = sr if box.size == Vector2.ZERO else box.merge(sr)
	_check("J1 every icon button is a square box (drawn as a circle)", round_ok, str(sizes))
	if not btns.is_empty():
		_zoom(img, box, "j1_02_icons_zoom")
		# Hovered state of the first delete icon.
		var del: Control = btns[1]
		del.mouse_entered.emit()
		del.notification(Control.NOTIFICATION_MOUSE_ENTER)
		var img2 := await _shot("j1_03_icons_hover", 0.4)
		_zoom(img2, box, "j1_04_icons_hover_zoom")
	main._show_menu()
	await _frames(4)


# ---------------------------------------------------------------- J24 (flow)

func _overlay_tiles() -> Array:
	var gs: GameScreen = main.screen
	return gs.overlays.overlay.find_children("*", "DeckTile", true, false) if gs != null else []


func _title_text() -> String:
	var gs: GameScreen = main.screen
	for l in gs.overlays.overlay_box.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Choose"):
			return (l as Label).text
	return ""


func _j24_flow() -> void:
	if not main.options.has_method("set_choose_bot_deck"):
		return
	main.options.call("set_choose_bot_deck", true)
	main.options.series["deck_mode"] = "starter"
	main.options.series["best_of"] = 3
	main._start_bot(main.options.series.duplicate(true))
	await create_timer(1.5).timeout
	var gs: GameScreen = main.screen
	_check("J24 bot series started", gs != null)
	if gs == null:
		return
	var ov = gs.overlays
	await _shot("j24_04_your_deck", 0.6)
	_check("J24 first screen: Choose your deck", _title_text() == "Choose your deck", _title_text())
	var tiles := _overlay_tiles()
	_check("J24 deck tiles shown", not tiles.is_empty(), "n=%d" % tiles.size())
	if tiles.is_empty():
		return
	(tiles[0] as DeckTile).chosen.emit()
	await _frames(3)
	_check("J24 your pick does not start the game", main.local_host.series.stage == Series.STAGE_DECKS and not main.local_host.series.deck_ready[0])
	await _shot("j24_05_bot_deck", 0.6)
	_check("J24 second screen: Choose the bot's deck", _title_text() == "Choose the bot's deck", _title_text())
	var back: Button = ov.overlay_box.find_child("BotDeckBack", true, false)
	_check("J24 the bot screen has a Back button", back != null)
	if back != null:
		back.pressed.emit()
		await _frames(3)
		_check("J24 Back returns to Choose your deck", _title_text() == "Choose your deck", _title_text())
		await _shot("j24_06_back", 0.5)
	# Pick your saved deck (Custom tab first) again, then a Structure deck for the bot.
	tiles = _overlay_tiles()
	(tiles[0] as DeckTile).chosen.emit()
	await _frames(3)
	var dv = ov.decks
	dv.tab = "structured"
	ov.refresh()
	await _frames(3)
	await _shot("j24_07_bot_structure_tab", 0.5)
	tiles = _overlay_tiles()
	var want: String = main.local_host.series.starters[1]["name"]
	(tiles[1] as DeckTile).chosen.emit()
	await create_timer(1.0).timeout
	var s: Series = main.local_host.series
	_check("J24 both decks locked and the duel started", s.deck_ready[0] and s.deck_ready[1] and s.stage == Series.STAGE_GAME, "stage=%s" % s.stage)
	_check("J24 you play your saved deck", String(s.deck_names[0]) == DECK_A, String(s.deck_names[0]))
	_check("J24 the bot plays the chosen Structure deck", String(s.deck_names[1]) == want, "%s vs %s" % [s.deck_names[1], want])
	await _shot("j24_08_game", 1.5)
	main._show_menu()
	await _frames(4)
