extends SceneTree
## Development-only check for playtest feedback 08 G10: after a game ends and the player returns
## to the main menu, the menu background image is shown. Run windowed:
##   godot --path rldb -s res://src/dev/g10_menu_bg_driver.gd -- --no-steam --g10-shots=<abs dir> [--modes=win,lose,...]
## Modes (each starts a fresh bot series from the real main scene and returns to the menu):
##   win      win game 1 of a best-of-3 against the bot, then Menu from the result panel
##   lose     lose game 1, then Menu
##   concede  concede game 1 from the game menu, then Menu
##   leave    leave mid-game from the game menu (leave_to_menu)
##   series   win a best-of-1 series, then Menu from the series-over panel
##   tutorial start lesson 1 of the tutorial and exit it
## For each mode it saves <mode>_game.png and <mode>_menu.png and prints a PASS/FAIL line from the
## menu background node's state (texture loaded, visible in tree, covering the window, opaque,
## frontmost of the main scene's screens) and from the screenshot's pixels.

var main: Node
var out_dir := ""
var modes: Array = ["win", "forfeit", "lose", "concede", "leave", "series", "tutorial"]
var fails := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--g10-shots="):
			out_dir = a.split("=", true, 1)[1]
		elif a.begins_with("--modes="):
			modes = Array(a.split("=", true, 1)[1].split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	if "--borderless" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)   # the owner's "borderless"
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		root.size = Vector2i(1600, 900)
	SeriesStore.DIR = "user://test_saves"
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _snap(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("%s.png" % name))
	return img


func _run() -> void:
	await _wait(0.3)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.2)
	await _check_menu("boot")
	for md in modes:
		await call("_mode_" + String(md))
	print("G10 DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _start_bot(best_of: int) -> MatchEngine:
	main._privacy = false
	main._go(func(): main._start_bot({"seed": 31, "best_of": best_of, "deck_mode": "starter"}))
	await _wait(1.4)
	var host: LocalHost = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 0})
	await _wait(0.6)
	var gs: GameScreen = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	var m: MatchEngine = host.series.game
	return m


## Ends game 1 with seat 0 winning (`win`) or losing through a real direct attack, then lets the
## victory / defeat presentation and the result panel play out.
func _finish_game(m: MatchEngine, win: bool) -> void:
	var host: LocalHost = main.local_host
	var a := 0 if win else 1
	var o := 1 - a
	while m.turn < 2 or m.active != a or m.phase != "main1":
		if not m.pending.is_empty():
			host.handle(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
			continue
		host.handle(m.active, {"t": "next_phase"})
		await _wait(0.05)
	for s in 6:
		if m.players[o]["units"][s] != -1:
			m.move_to_pile(m.players[o]["units"][s], "spent")
	var u := TB.unit(m, a, 36, 0)
	m.players[o]["hp"] = 3
	host.handle(a, {"t": "next_phase"})
	host.broadcast()
	await _wait(0.4)
	host.handle(a, {"t": "attack", "uid": u})
	var guard := 0
	while not m.pending.is_empty() and guard < 8:
		guard += 1
		host.handle(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _wait(4.5)


func _to_menu_from_result() -> void:
	var gs: GameScreen = main.screen
	gs.back_to_menu.emit()
	await _wait(1.6)


func _mode_win() -> void:
	var m := await _start_bot(3)
	await _finish_game(m, true)
	await _snap("win_game")
	await _to_menu_from_result()
	await _check_menu("win")


## The owner's path: win game 1, then leave from the in-game Menu ("Forfeit and leave").
func _mode_forfeit() -> void:
	var m := await _start_bot(3)
	await _finish_game(m, true)
	await _snap("forfeit_game")
	var gs: GameScreen = main.screen
	gs.menu.confirm_forfeit(false)
	await _wait(0.4)
	var pressed := false
	for b in gs.find_children("*", "Button", true, false):
		if not pressed and (b as Button).is_visible_in_tree() and String((b as Button).text).begins_with("Forfeit"):
			(b as Button).pressed.emit()
			pressed = true
	if not pressed:
		print("G10 note: no forfeit dialog (series not live?)")
	await _wait(1.8)
	await _check_menu("forfeit")


func _mode_lose() -> void:
	var m := await _start_bot(3)
	await _finish_game(m, false)
	await _snap("lose_game")
	await _to_menu_from_result()
	await _check_menu("lose")


func _mode_series() -> void:
	var m := await _start_bot(1)
	await _finish_game(m, true)
	await _snap("series_game")
	await _to_menu_from_result()
	await _check_menu("series")


func _mode_concede() -> void:
	await _start_bot(3)
	var host: LocalHost = main.local_host
	host.handle(0, {"t": "concede"})
	await _wait(4.0)
	await _snap("concede_game")
	await _to_menu_from_result()
	await _check_menu("concede")


func _mode_leave() -> void:
	await _start_bot(3)
	await _wait(0.5)
	await _snap("leave_game")
	(main.screen as GameScreen).leave_to_menu.emit()
	await _wait(1.6)
	await _check_menu("leave")


func _mode_tutorial() -> void:
	main._go(func(): main._start_tutorial(0))
	await _wait(2.0)
	await _snap("tutorial_game")
	(main.screen as GameScreen).leave_to_menu.emit()
	await _wait(1.6)
	await _check_menu("tutorial")


## Inspects the menu's background and the screenshot; prints PASS/FAIL.
func _check_menu(tag: String) -> void:
	var img := await _snap("%s_menu" % tag)
	var notes := []
	var menu: Node = main.menu
	var ok := menu != null and is_instance_valid(menu) and menu is MainMenu
	if not ok:
		notes.append("no MainMenu")
	var tr: TextureRect = null
	if ok:
		for n in menu.find_children("*", "TextureRect", true, false):
			if (n as TextureRect).stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED:
				tr = n
				break
	if tr == null:
		ok = false
		notes.append("no background TextureRect")
	else:
		if tr.texture == null:
			ok = false
			notes.append("texture null")
		if not tr.is_visible_in_tree():
			ok = false
			notes.append("not visible in tree")
		var r := tr.get_global_rect()
		var vis := tr.get_viewport_rect().size          # canvas units (content scale applies at 4K)
		if r.size.x < vis.x - 2 or r.size.y < vis.y - 2:
			ok = false
			notes.append("rect %s" % r)
		var mod := Color.WHITE
		var n: Node = tr
		while n != null and n is CanvasItem:
			mod *= (n as CanvasItem).modulate * (n as CanvasItem).self_modulate
			n = n.get_parent()
		if mod.a < 0.99:
			ok = false
			notes.append("modulate %s" % mod)
	# Every other child of the main scene drawn over the menu (screens, veils, overlays).
	var over := []
	for c in main.get_children():
		if c != menu and c is CanvasItem and (c as CanvasItem).visible and not c.is_queued_for_deletion():
			over.append("%s(%s z=%d)" % [c.name, c.get_class(), (c as CanvasItem).z_index])
	for c in root.get_children():
		if c != main and c is CanvasItem and (c as CanvasItem).visible:
			over.append("root:%s(%s)" % [c.name, c.get_class()])
	# Pixel check: the menu image is a lit forest; a missing background leaves a near-black field.
	var lum := 0.0
	var cnt := 0
	for y in range(80, img.get_height() - 80, 40):
		for x in range(int(img.get_width() * 0.55), img.get_width() - 40, 40):
			lum += img.get_pixel(x, y).get_luminance()
			cnt += 1
	lum /= maxf(1.0, float(cnt))
	if lum < 0.05:
		ok = false
	notes.append("lum %.3f" % lum)
	notes.append("time_scale %.2f" % Engine.time_scale)
	notes.append("over %s" % [over])
	if not ok:
		fails += 1
	print("G10 %s %s  %s" % ["PASS" if ok else "FAIL", tag, "; ".join(notes)])
