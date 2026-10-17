extends SceneTree
## Development-only live check of the guided tutorial (F03-15). Run windowed:
##   godot --path rldb -s res://src/tutorial/tutorial_driver.gd -- --tutorial-shots=<dir> [--size=1600x900]
## Opens the real main scene, enters Play > Tutorial from the menu, and plays every
## lesson by clicking (pushed mouse events) the rect the overlay highlights, so the highlights are
## proven to point at working controls. Also tries an off-script Esc (cancel), Restart lesson,
## the Arcane over-pay (F05-01), and finally Back to menu. Writes PNGs and tutorial_report.json into the directory, then quits.

var main: Control
## The whole run is abandoned (and the window closed) after this many seconds.
const WATCHDOG_SECS := 360.0
## A step that has not advanced after this many attempts fails the lesson instead of looping.
const MAX_STEP_TRIES := 4
var out: String = ""
var checks: Array = []
var _shot_no: int = 0


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tutorial-shots="):
			out = a.split("=", true, 1)[1]
		elif a.begins_with("--size="):
			var p := a.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	# Watchdog: a stuck step or a broken await must never leave the window open.
	create_timer(WATCHDOG_SECS).timeout.connect(func():
		_check("driver finished before the %d s watchdog" % int(WATCHDOG_SECS), false)
		_finish())
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	# Own saves folder (emptied first), so parallel scripted runs cannot change the save count under this one.
	SeriesStore.DIR = "user://dev_saves_tutorial"
	for f in DirAccess.get_files_at(SeriesStore.DIR):
		DirAccess.remove_absolute(SeriesStore.DIR.path_join(f))
	await _check_play_tutorial_entry()
	var saves_before := SeriesStore.list().size()
	var menu: MainMenu = main.menu
	menu.pick("@play")
	await _wait(0.4)
	_check("F05-02 Tutorial is listed directly under Play", not main.menu.find_children("*", "MenuItem", true, false).filter(func(m): return m.is_visible_in_tree() and m.label_text == "Tutorial").is_empty())
	menu.pick("tutorial")
	await _wait(0.6)
	await _shot("menu_tutorial_panel")
	var b := _find_button(main.menu, "Lesson 1")
	_check("menu offers the tutorial lessons", b != null)
	_check("F05-01 menu lists Ritual and Arcane lessons", _find_button(main.menu, "Lesson 6 · Extra Deck: Ritual") != null \
		and _find_button(main.menu, "Lesson 7 · Extra Deck: Arcane") != null)
	await _click(_rect(b).get_center())
	await _wait(1.6)
	for li in TutorialLessons.count():
		await _play_lesson(li)
		if li < TutorialLessons.count() - 1:
			var nb := _find_button(_overlay().complete_card, "Next:")
			_check("lesson %d offers the next lesson" % (li + 1), nb != null)
			await _click(_rect(nb).get_center())
			await _wait(1.0)
	var back := _find_button(_overlay().complete_card, "Back to menu")
	_check("final lesson offers Back to menu", back != null)
	await _click(_rect(back).get_center())
	await _wait(1.5)
	_check("back at the main menu", main.menu is MainMenu and main.screen == null and main.local_host == null)
	print("saves before/after: %d / %d (dir %s)" % [saves_before, SeriesStore.list().size(), SeriesStore.DIR])
	_check("tutorial wrote no save", SeriesStore.list().size() == saves_before)
	await _shot("back_to_menu")
	# Exit tutorial from inside a lesson.
	main.menu.tutorial_requested.emit(2)
	await _wait(1.6)
	_check("lesson 3 opens from the menu signal", _host() != null and _host().lesson_index == 2)
	await _click(_rect(_overlay().exit_btn).get_center())
	await _wait(1.5)
	_check("Exit tutorial returns to the menu", main.menu is MainMenu and main.local_host == null)
	_finish()


## F04-09: a fresh profile (no saves, no flag) is offered Play tutorial at the top of the root
## menu, it opens lesson 1, and afterwards the menu is back to normal.
func _check_play_tutorial_entry() -> void:
	var real_dir := SeriesStore.DIR
	SeriesStore.DIR = "user://dev_empty_f04"
	PlayerProgress.reset_cache()
	main._show_menu()
	await _wait(0.6)
	var first := _first_item(main.menu)
	_check("fresh profile: Play tutorial is the top menu item", first != null and first.label_text == "Play tutorial")
	await _shot("menu_play_tutorial")
	_check("scripted run does not persist the has-played flag", not PlayerProgress.persist)
	if first != null:
		await _click(_rect(first).get_center())
		await _wait(1.6)
		_check("Play tutorial opens lesson 1", _host() != null and _host().lesson_index == 0)
		_check("starting the tutorial marks the profile as played", PlayerProgress.has_played())
		await _click(_rect(_overlay().exit_btn).get_center())
		await _wait(1.5)
		var again := _first_item(main.menu)
		_check("after the tutorial the menu no longer offers Play tutorial", again == null or again.label_text != "Play tutorial")
	SeriesStore.DIR = real_dir
	PlayerProgress.reset_cache()
	main._show_menu()
	await _wait(0.5)


func _first_item(n: Node) -> MenuItem:
	if n == null:
		return null
	if n is MenuItem:
		return n
	for ch in n.get_children():
		var f := _first_item(ch)
		if f != null:
			return f
	return null


func _play_lesson(li: int) -> void:
	var h := _host()
	_check("lesson %d loaded" % (li + 1), h != null and h.lesson_index == li)
	var guard := 0
	var restarted := false
	var esc_tried := false
	var overpay_tried := false
	var tries := {}
	while not h.is_complete() and guard < 80:
		guard += 1
		var st := h.current_step()
		var si := h.step_index
		tries[si] = int(tries.get(si, 0)) + 1
		if tries[si] > MAX_STEP_TRIES:
			_check("L%d step %d completes within %d tries" % [li + 1, si + 1, MAX_STEP_TRIES], false)
			return
		await _settle()
		await _shot("L%d_s%02d_%s" % [li + 1, si + 1, String(st["kind"])])
		if String(st["kind"]) == "read":
			_check_buttons_at_bottom("L%d s%d" % [li + 1, si + 1])
		if String(st["kind"]) == "do":
			await _check_arrow_stable("L%d s%d" % [li + 1, si + 1])
		if li == 1 and si == 1:
			await _check_ring_under_modals()
		match String(st["kind"]):
			"read":
				await _click(_rect(_overlay().next_btn).get_center())
			"wait":
				var end := Time.get_ticks_msec() + 15000
				while h.step_index == si and Time.get_ticks_msec() < end:
					await _frames(2)
				_check("L%d wait step %d settles" % [li + 1, si + 1], h.step_index != si)
			"do":
				if li == 1 and not esc_tried and h.game().pending.get("kind", "") == "slot":
					esc_tried = true
					var before := h.refused
					await _key(KEY_ESCAPE)
					await _wait(0.3)
					_check("Esc (cancel) during a forced zone pick is refused", h.refused == before + 1 and h.step_index == si)
					await _shot("L2_offscript_hint")
				if String(h.lesson["id"]) == "arcane" and h.game().pending.get("total_exact", false) and not overpay_tried:
					overpay_tried = true
					await _check_arcane_overpay(h)
				var rs := _overlay().target_rects()
				_check("L%d step %d has a highlight" % [li + 1, si + 1], not rs.is_empty())
				if rs.is_empty():
					return
				await _click((rs[0] as Rect2).get_center())
				await _wait(0.35)
				# Follow the moving highlight: a card then its action button; the Extra Deck pile,
				# then the unit's row, then its button; materials one by one, then Confirm.
				var follow := 0
				while h.step_index == si and not h.is_complete() and String(st["expect"][0]["t"]) != "next_phase" and follow < 4:
					follow += 1
					await _settle()
					await _shot("L%d_s%02d_click%d" % [li + 1, si + 1, follow + 1])
					var rs2 := _overlay().target_rects()
					if rs2.is_empty():
						break
					await _click((rs2[0] as Rect2).get_center())
					await _wait(0.4)
				if st.get("until", {}).is_empty():
					_check("L%d step %d advanced" % [li + 1, si + 1], h.step_index != si)
		if li == 0 and si == 2 and not restarted:
			restarted = true
			await _click(_rect(_overlay().restart_btn).get_center())
			await _wait(0.8)
			h = _host()
			_check("Restart lesson returns to step 1", h.step_index == 0 and h.game().turn == 1)
			await _shot("L1_restarted")
	await _wait(0.6)
	_check("lesson %d complete" % (li + 1), h.is_complete())
	await _shot("L%d_complete" % (li + 1))


## F05-01 / F08: the Arcane picker offers no 0-cost unit; after one Dragon (2 of 3) the other is
## disabled (it would over-pay); an over-pay command is still refused by the authority with the
## total hint; deselecting restores an empty pick.
func _check_arcane_overpay(h: TutorialHost) -> void:
	var gs: GameScreen = main.screen
	var o := _overlay()
	var pd := gs.pending()
	var offered := []
	for x in pd.get("options", []):
		offered.append(int(x.get("card", {}).get("uid", -1)))
	_check("Arcane picker does not offer the 0-cost Drake", not (int(h.keys["s_drake"]) in offered) and offered.size() == 3)
	_check("Arcane banner asks for exactly 3", gs.prompt._banner_how.contains("Pay exactly 3"))
	await _shot("L7_arcane_picker")
	# F08: after one Dragon (2 of 3) the other Dragon would over-pay, so it is disabled.
	await _click(o._card_rect(int(h.keys["s_wyvern"])).get_center())
	await _wait(0.3)
	await _click(o._card_rect(int(h.keys["s_hydra"])).get_center())
	await _wait(0.3)
	var confirm := _find_button(gs.prompt.banner_btns, "Confirm")
	_check("over-pay option is disabled (Cannot overpay); Confirm stays off", gs.multi.size() == 1 and confirm != null and confirm.disabled)
	_check("over-pay banner reads 2 of 3 paid", gs.prompt._banner_how.contains("2 of 3 paid"))
	await _shot("L7_arcane_overpay")
	var before := h.refused
	var both := []
	for x in gs.pending().get("options", []):
		if int(x.get("card", {}).get("uid", -1)) in [int(h.keys["s_wyvern"]), int(h.keys["s_hydra"])]:
			both.append(int(x["i"]))
	h.handle(TutorialLessons.PLAYER, {"t": "choose", "id": int(h.game().pending["id"]), "indices": both})
	await _wait(0.3)
	_check("an over-pay command is refused", h.refused == before + 1 and h.game().pending.get("total_exact", false))
	await _shot("L7_arcane_overpay_hint")
	await _click(o._card_rect(int(h.keys["s_wyvern"])).get_center())
	await _wait(0.3)
	_check("deselecting clears the pick", gs.multi.is_empty())


## F04-11: Restart / Exit / Next sit at the bottom of the guidance card.
func _check_buttons_at_bottom(tag: String) -> void:
	var o := _overlay()
	var pr := _rect(o.panel)
	var br := _rect(o.next_btn)
	_check("%s: buttons at the bottom of the card" % tag, pr.end.y - br.end.y < 24.0 and br.position.y > pr.position.y + pr.size.y * 0.4)


## F04-10: the arrow keeps one direction over a whole bob cycle.
func _check_arrow_stable(tag: String) -> void:
	var o := _overlay()
	var dirs := {}
	for i in 60:
		await _frames(1)
		dirs[o.ring.arrow_dir] = true
	_check("%s: arrow direction never flips" % tag, dirs.size() == 1 and not dirs.has(0))


## F04-08: the ring stays under the game menu and the pile browser.
func _check_ring_under_modals() -> void:
	var gs: GameScreen = main.screen
	var o := _overlay()
	gs.menu.toggle()
	await _wait(0.5)
	await _shot("ring_under_game_menu")
	_check("ring layer is under the game menu", o.ring.z_index < gs.menu.game_menu.z_index)
	gs.menu.toggle()
	await _wait(0.3)
	gs.inspect.open_pile("spent")
	await _wait(0.5)
	await _shot("ring_under_pile_browser")
	gs.inspect.close_all()
	await _wait(0.3)


func _host() -> TutorialHost:
	return main.local_host as TutorialHost


func _overlay() -> TutorialOverlay:
	if main.screen == null:
		return null
	for c in main.screen.get_children():
		if c is TutorialOverlay and not c.is_queued_for_deletion():
			return c
	return null


func _settle() -> void:
	await _wait(0.5)
	if main.screen != null:
		main.screen.skip_effects()
	await _frames(4)


static func _rect(c: Control) -> Rect2:
	if c == null:
		return Rect2()
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


func _find_button(n: Node, prefix: String) -> Button:
	if n == null:
		return null
	if n is Button and (n as Button).text.begins_with(prefix) and (n as Button).is_visible_in_tree():
		return n
	for ch in n.get_children():
		var f := _find_button(ch, prefix)
		if f != null:
			return f
	return null


func _click(pos: Vector2) -> void:
	root.warp_mouse(pos)
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.relative = Vector2(3, 0)
	root.push_input(mv, true)
	await _frames(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		root.push_input(ev, true)
		await _frames(1)
	await _frames(3)


func _key(k: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = pressed
		root.push_input(ev, true)
		await _frames(1)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_shot_no += 1
	root.get_texture().get_image().save_png(out.path_join("%03d_%s.png" % [_shot_no, name]))


func _check(name: String, ok: bool) -> void:
	checks.append({"name": name, "ok": ok})
	print(("PASS  " if ok else "FAIL  ") + name)


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out.path_join("tutorial_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("TUTORIAL DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	quit()
