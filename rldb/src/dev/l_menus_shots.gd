extends SceneTree
## Dev-only windowed evidence for the L batch menus items (owner feedback 5 Nov: L10 themed fonts,
## L25 / L28 table backgrounds and the Options screen). Run NOT headless, from rldb/:
##   godot --path . -s res://src/dev/l_menus_shots.gd -- <abs out dir> [WxH] [--steps=a,b,..]
##       [--table=<id>] [--prefix=<name>] --no-steam
## Steps (default: all but board): menu, options, popup, tooltip, builder, tutorial, gallery, board.
## `board` stages a hot-seat game through the real launcher on table `--table` (saved first through
## Customisation, so the game reads it like a player's choice). Saves JPG q88 (at most 1600 px wide)
## and prints PASS / FAIL lines; quits with the number of failures.
## Scripted runs use the TEST stores (decks, saves, the "has played" flag and the customisation file).

var out_dir := ""
var sz := Vector2i(1600, 900)
var steps: Array = ["menu", "options", "popup", "tooltip", "builder", "tutorial", "gallery"]
var table_id := ""
var prefix := ""
var main: Node
var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 and not String(args[0]).begins_with("--") else "user://l_menus"
	for a in args.slice(1):
		var s := String(a)
		if s.begins_with("--steps="):
			steps = Array(s.split("=", true, 1)[1].split(","))
		elif s.begins_with("--table="):
			table_id = s.split("=", true, 1)[1]
		elif s.begins_with("--prefix="):
			prefix = s.split("=", true, 1)[1]
		elif s.contains("x") and not s.begins_with("--"):
			var p := s.split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(240.0).timeout.connect(func(): print("FAIL watchdog"); quit(99))
	run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", what, "  ", detail)
	else:
		fails += 1
		print("FAIL ", what, "  ", detail)


func _wait(t: float) -> void:
	await create_timer(t).timeout


## Saves the window as `<prefix><name>.jpg` (q88; scaled down to 1600 px wide when larger).
func _shot(name: String, wait: float = 0.6) -> Image:
	await _wait(wait)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_save(img, name)
	return img


func _save(img: Image, name: String) -> void:
	var out := img
	if img.get_width() > 1600:
		out = img.duplicate()
		out.resize(1600, int(round(img.get_height() * 1600.0 / img.get_width())), Image.INTERPOLATE_LANCZOS)
	out.save_jpg(out_dir.path_join(prefix + name + ".jpg"), 0.88)
	print("SHOT ", prefix + name)


## Saves a crop of `img` around `r` (layout px), at 1:1 window pixels (fine detail at 4K).
func _crop(img: Image, r: Rect2, name: String) -> void:
	var s := float(img.get_height()) / root.get_visible_rect().size.y
	var px := Rect2i(Rect2(r.position * s, r.size * s).grow(8.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if px.size.x <= 0 or px.size.y <= 0:
		return
	_save(img.get_region(px), name)


func run() -> void:
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	_check("deck store uses the TEST path", DeckStore.PATH == DeckStore.TEST_PATH, DeckStore.PATH)
	if DeckStore.PATH != DeckStore.TEST_PATH:
		quit(1)
		return
	print("screen size ", DisplayServer.screen_get_size(), " window ", sz)
	# Every run starts from the default table (the TEST file keeps the last run's pick).
	Customisation.set_table(table_id if table_id != "" else Customisation.DEFAULT_TABLE)
	if "gallery" in steps:
		await _gallery_bare()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.2)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	await _wait(1.2)
	if "menu" in steps:
		await _shot("01_main_menu", 1.0)
	if "options" in steps:
		await _options()
	if "popup" in steps:
		await _popup()
	if "tooltip" in steps:
		await _tooltip()
	if "gallery" in steps:
		await _gallery_themed()
	if "builder" in steps:
		await _builder()
	if "tutorial" in steps:
		await _tutorial()
	if "board" in steps:
		await _board()
	print("L MENUS DONE fails=%d" % fails)
	quit(fails)


func _menu() -> MainMenu:
	return main.menu as MainMenu


func _has_options() -> bool:
	return MainMenu.MENU.has("options")


## Options: every section (after), or the old Settings / Credits panels (before).
func _options() -> void:
	var mm := _menu()
	if not _has_options():
		mm.pick("settings")
		await _shot("02_settings", 0.9)
		mm.step_back()
		mm.pick("credits")
		await _shot("03_credits", 0.9)
		mm.step_back()
		return
	_check("root menu has Options and no Settings", _root_labels().has("Options") and not _root_labels().has("Settings"), str(_root_labels()))
	mm.pick("@options")
	await _shot("02_options_settings", 1.0)
	mm.pick("customisation")
	await _wait(0.8)
	var cp := mm.find_child("CustomisationPanel", true, false)
	_check("customisation panel shown", cp != null)
	var img := await _shot("03_customisation_table", 0.3)
	var picker := mm.find_child("TablePicker", true, false) as Control
	if picker != null:
		_crop(img, picker.get_global_rect(), "03b_table_picker_crop")
		# Hover the second tile (real input) and pick it.
		var tiles := picker.find_children("Tile_*", "Control", true, false)
		_check("four table tiles", tiles.size() == 4, str(tiles.size()))
		if tiles.size() >= 2:
			var t: Control = tiles[1]
			_move_mouse(t.get_global_rect().get_center())
			await _wait(0.1)
			_move_mouse(t.get_global_rect().get_center() + Vector2(2, 1))
			var hov := await _shot("04_table_hover", 0.5)
			_check("hovered tile lights up", float(t.get("hover")) > 0.9, "hover=%.2f is_hovered=%s under=%s rect=%s" % [float(t.get("hover")), (t as Button).is_hovered(), root.gui_get_hovered_control(), t.get_global_rect()])
			_crop(hov, picker.get_global_rect(), "04b_table_hover_crop")
			t.emit_signal("pressed")
			await _shot("05_table_picked", 0.5)
			# Put the default back.
			(tiles[0] as Control).emit_signal("pressed")
			_move_mouse(Vector2(5, 5))
	var cpanel := cp as CustomisationPanel
	if cpanel != null:
		cpanel.tabs.select("card_back")
		await _shot("06_customisation_card_back", 0.8)
		_check("card back section shown", cpanel.section == "card_back")
		cpanel.tabs.select("table")
	mm.pick("credits")
	await _shot("07_credits", 1.0)
	mm.step_back()
	mm.back_out()
	await _wait(0.6)


func _root_labels() -> Array:
	var out := []
	for e in MainMenu.MENU["root"]:
		out.append(String(e[0]))
	return out


func _move_mouse(p: Vector2) -> void:
	var s := root.get_final_transform()
	var wp := s * p
	Input.warp_mouse(wp)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)


## A dropdown's popup (PopupMenu) open over the Settings panel.
func _popup() -> void:
	var mm := _menu()
	mm.pick("@options" if _has_options() else "settings")
	if _has_options():
		mm.pick("settings")
	await _wait(0.9)
	var form := mm.find_child("SettingsForm", true, false) as SettingsForm
	if form == null:
		_check("settings form", false)
		return
	var ob := form.controls.get("window_mode") as OptionButton
	ob.show_popup()
	await _shot("08_dropdown_popup", 0.5)
	ob.get_popup().hide()
	await _wait(0.2)


## A tooltip (the engine's TooltipPanel) over the Settings panel's mute toggle.
func _tooltip() -> void:
	var mm := _menu()
	var form := mm.find_child("SettingsForm", true, false) as SettingsForm
	if form == null:
		mm.pick("@options" if _has_options() else "settings")
		if _has_options():
			mm.pick("settings")
		await _wait(0.9)
		form = mm.find_child("SettingsForm", true, false) as SettingsForm
	var sp := form.controls.get("music_mute") as Control
	_move_mouse(sp.get_global_rect().get_center() + Vector2(1, 0))
	await _wait(0.1)
	_move_mouse(sp.get_global_rect().get_center())
	var img := await _shot("09_tooltip", 1.4)
	_crop(img, Rect2(sp.get_global_rect().position - Vector2(80, 30), Vector2(300, 120)), "09b_tooltip_crop")
	_move_mouse(Vector2(5, 5))
	mm.step_back()
	if _has_options():
		mm.back_out()
	await _wait(0.5)


## Font samples with NO theme of our own (only the project-wide default): what any control outside
## the game's themed tree would show.
func _gallery_bare() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	var g := _gallery()
	root.add_child(g)
	await _shot("10_fonts_project_default", 1.0)
	g.queue_free()
	await _wait(0.2)


## The same samples under the game theme (UIStyle.make_theme, as every screen has).
func _gallery_themed() -> void:
	var g := _gallery()
	g.theme = UIStyle.make_theme()
	main.add_child(g)
	await _shot("11_fonts_game_theme", 1.0)
	g.queue_free()
	await _wait(0.2)


func _gallery() -> Control:
	var bg := ColorRect.new()
	bg.color = Color("17130f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 32)
	bg.add_child(m)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	m.add_child(cols)
	var a := VBoxContainer.new()
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_constant_override("separation", 10)
	cols.add_child(a)
	var b := VBoxContainer.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_constant_override("separation", 10)
	cols.add_child(b)
	var plain := Label.new()
	plain.text = "Label (no override): The quick brown fox jumps over the lazy dog 0123456789"
	a.add_child(plain)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.text = "RichTextLabel: normal, [b]bold[/b], [i]italic[/i], [b][i]bold italic[/i][/b], [code]mono 0123[/code]\nGlyphs: · × – — … ‹ ← → − ——— ● ☰ ✓ “quotes” ū §"
	a.add_child(rtl)
	var le := LineEdit.new()
	le.text = "LineEdit: My deck name"
	a.add_child(le)
	var le2 := LineEdit.new()
	le2.placeholder_text = "LineEdit placeholder: type a message"
	a.add_child(le2)
	var te := TextEdit.new()
	te.text = "TextEdit: chat history line\nsecond line 42"
	te.custom_minimum_size = Vector2(0, 70)
	a.add_child(te)
	var btn := Button.new()
	btn.text = "Button (plain)"
	a.add_child(btn)
	var cb := CheckBox.new()
	cb.text = "CheckBox (plain)"
	a.add_child(cb)
	var ob := OptionButton.new()
	ob.add_item("OptionButton item")
	a.add_child(ob)
	var il := ItemList.new()
	il.add_item("ItemList row one")
	il.add_item("ItemList row two × 3")
	il.custom_minimum_size = Vector2(0, 70)
	b.add_child(il)
	var tr := Tree.new()
	var r := tr.create_item()
	r.set_text(0, "Tree root")
	tr.create_item(r).set_text(0, "Tree child")
	tr.custom_minimum_size = Vector2(0, 70)
	b.add_child(tr)
	var sb := SpinBox.new()
	sb.value = 7
	b.add_child(sb)
	var tc := TabContainer.new()
	var t1 := Label.new()
	t1.name = "Tab one"
	t1.text = "TabContainer page"
	tc.add_child(t1)
	var t2 := Label.new()
	t2.name = "Tab two"
	tc.add_child(t2)
	tc.custom_minimum_size = Vector2(0, 80)
	b.add_child(tc)
	var lk := LinkButton.new()
	lk.text = "LinkButton"
	b.add_child(lk)
	var pb := ProgressBar.new()
	pb.value = 40
	b.add_child(pb)
	var title := Label.new()
	title.text = "Cinzel title · Ritual → Arcane ← ‹ Back"
	title.add_theme_font_override("font", UIStyle.font_title())
	title.add_theme_font_size_override("font_size", 26)
	b.add_child(title)
	var title2 := Label.new()
	title2.text = "Cinzel 600 ✓ ● ☰ — – × ·"
	title2.add_theme_font_override("font", UIStyle.font_display(600))
	title2.add_theme_font_size_override("font_size", 22)
	b.add_child(title2)
	var tip := Label.new()
	tip.text = "(tooltip sample: see 09_tooltip)"
	b.add_child(tip)
	return bg


func _builder() -> void:
	var mm := _menu()
	mm.deck_builder_requested.emit()
	await _shot("12_deck_builder", 2.2)
	main._go(main._show_menu)
	await _wait(1.0)


func _tutorial() -> void:
	var mm := _menu()
	if mm == null:
		return
	# Straight to Main (a request through the fader is ignored while a fade still runs).
	main._start_tutorial(0)
	await _shot("13_tutorial", 3.0)
	main._go(main._show_menu)
	await _wait(1.0)


## A hot-seat game on table `table_id` (saved through Customisation first when it exists).
func _board() -> void:
	if table_id != "":
		_check("customisation uses the TEST path", Customisation.settings_path() == Customisation.TEST_PATH, Customisation.settings_path())
		Customisation.set_table(table_id)
		_check("table saved", Customisation.table_id() == table_id, Customisation.table_id())
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.6)
	var host: LocalHost = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.5)
	var gs: GameScreen = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	await _shot("20_board_%s" % (table_id if table_id != "" else "current"), 3.0)
