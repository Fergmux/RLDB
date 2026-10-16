extends SceneTree
## Development-only live check of the guided tutorial (F03-15). Run windowed:
##   godot --path rldb -s res://src/tutorial/tutorial_driver.gd -- --tutorial-shots=<dir> [--size=1600x900]
## Opens the real main scene, enters Play > Play local > Tutorial from the menu, and plays every
## lesson by clicking (pushed mouse events) the rect the overlay highlights, so the highlights are
## proven to point at working controls. Also tries an off-script Esc (cancel), Restart lesson,
## and finally Back to menu. Writes PNGs and tutorial_report.json into the directory, then quits.

var main: Control
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
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	var saves_before := SeriesStore.list().size()
	var menu: MainMenu = main.menu
	menu.pick("@play")
	await _wait(0.4)
	menu.pick("@local")
	await _wait(0.5)
	menu.pick("tutorial")
	await _wait(0.6)
	await _shot("menu_tutorial_panel")
	var b := _find_button(main.menu, "Lesson 1")
	_check("menu offers the tutorial lessons", b != null)
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


func _play_lesson(li: int) -> void:
	var h := _host()
	_check("lesson %d loaded" % (li + 1), h != null and h.lesson_index == li)
	var guard := 0
	var restarted := false
	var esc_tried := false
	while not h.is_complete() and guard < 80:
		guard += 1
		var st := h.current_step()
		var si := h.step_index
		await _settle()
		await _shot("L%d_s%02d_%s" % [li + 1, si + 1, String(st["kind"])])
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
				var rs := _overlay().target_rects()
				_check("L%d step %d has a highlight" % [li + 1, si + 1], not rs.is_empty())
				if rs.is_empty():
					return
				await _click((rs[0] as Rect2).get_center())
				await _wait(0.35)
				if h.step_index == si and not h.is_complete() and String(st["expect"][0]["t"]) != "next_phase" \
						and String(st["expect"][0]["t"]) != "choose":
					# First click selected the card: the highlight moved to its action button.
					await _settle()
					await _shot("L%d_s%02d_button" % [li + 1, si + 1])
					var rs2 := _overlay().target_rects()
					if not rs2.is_empty():
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
