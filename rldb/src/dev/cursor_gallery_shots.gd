extends "res://src/dev/f02_driver.gd"
## Development-only L22 cursor gallery. Launched with
##   godot --path rldb -s res://src/dev/cursor_gallery_boot.gd -- <absolute dir> --cursor-shots
## The OS draws the real cursor, so window captures never contain it. This driver poses the pointer
## (pushed motion events, as f02_driver) over each state through the real UI: the main menu, the
## Options > Settings form, the board, a hand card, sacrifice mode (L5) and an attack target pick. It
## then composites the image CursorSkin has applied for the shape the viewport chose
## (DisplayServer.cursor_get_shape) at the mouse position minus its hotspot. Each shot is saved at
## 1600x1000 with the live size (32 px at 100% DPI). A "4K" crop is saved too: the frame scaled 2.4x
## with the 4K-size art (CursorSkin.size_for_scale) at its native pixels. It asserts the mode and art of every pose and writes
## JPGs (q88) and `cursor_report.json`, then quits.

const K4 := 2.4

var _gallery: Array = []


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only
	await _frames(20)
	_check("L22 custom cursor installed and on", CursorSkin.is_enabled() and String(CursorSkin.applied().get(Input.CURSOR_ARROW, "")).begins_with("normal@"), str(CursorSkin.applied()))
	await _menu_steps()
	main._privacy = false
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	_stage()
	host.broadcast()
	_view_seat(a)
	await _wait(4.5)          # past the coin flip and the deal
	await _board_steps()
	_finish_gallery()


# ---------------------------------------------------------------- menus

func _menu_steps() -> void:
	await _move(Vector2(260, 860))
	await _wait(0.6)
	await _cshot("01_menu_arrow", Input.CURSOR_ARROW, &"normal")
	var items := _find_all(main.menu, func(n): return n is MenuItem and (n as Control).is_visible_in_tree())
	if not items.is_empty():
		var r := (items[1 if items.size() > 1 else 0] as Control).get_global_rect()
		await _move(r.get_center() + Vector2(-r.size.x * 0.2, 0))
		await _wait(0.5)
		await _cshot("02_menu_pointer", Input.CURSOR_POINTING_HAND, &"pointer")
	main.menu.pick("@options")
	await _wait(1.2)
	var forms := _find_all(main.menu, func(n): return n is SettingsForm)
	_check("L22 Options > Settings shows the Custom cursor row", not forms.is_empty() and (forms[0] as SettingsForm).controls.has("custom_cursor"))
	if not forms.is_empty():
		var cb: Control = (forms[0] as SettingsForm).controls["custom_cursor"]
		var r2 := cb.get_global_rect()
		await _move(Vector2(r2.position.x + 10, r2.get_center().y))
		await _wait(0.5)
		await _cshot("03_settings_custom_cursor_row", Input.CURSOR_POINTING_HAND, &"pointer")
	main.menu.step_back()
	await _wait(0.5)


# ---------------------------------------------------------------- the board

func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})      # turn 2, the other player active, Main 1
	a = m.active
	o = 1 - a
	uids["mine0"] = _put(a, 110, 0, "atk", 14)
	uids["mine1"] = _put(a, 1, 1, "atk", 12)
	uids["foe0"] = _put(o, 120, 0, "atk")
	uids["foe1"] = _put(o, 1, 1, "def")
	uids["foe_back"] = _put(o, 110, 4, "def")    # behind foe1: protected, not a target
	m.players[a]["ap"] = 4
	m.add_log("[dev] Board arranged for the L22 cursor gallery.")


func _board_steps() -> void:
	await _move(gs.play_area.get_center() + Vector2(-420, 10))
	await _wait(0.5)
	await _cshot("04_board_arrow", Input.CURSOR_ARROW, &"normal")
	var huid: int = gs.hand.order[gs.hand.order.size() / 2] if not gs.hand.order.is_empty() else -1
	if huid != -1:
		await _move(_hand_rect(huid).get_center() + Vector2(0, -10))
		await _wait(0.6)
		await _cshot("05_board_pointer_on_hand_card", Input.CURSOR_POINTING_HAND, &"pointer")
	# L5 sacrifice mode: the knife; hot over my unit, barred over the opponent's card.
	await _move(gs.play_area.get_center() + Vector2(-420, 10))
	gs.sacrifice.start()
	await _wait(0.8)
	_check("L22 sacrifice mode started", gs.sacrifice.is_active())
	await _cshot("06_sacrifice_knife", Input.CURSOR_ARROW, &"knife")
	await _move(_slot_rect(a, "unit", 1).get_center())
	await _wait(0.6)
	await _cshot("07_sacrifice_knife_hot_over_my_unit", Input.CURSOR_ARROW, &"knife_hot")
	await _move(_slot_rect(o, "unit", 1).get_center())
	await _wait(0.6)
	await _cshot("08_sacrifice_barred_over_enemy_card", Input.CURSOR_ARROW, &"forbidden")
	var sb: Control = gs.board.controls.sacrifice_btn if gs.board.controls != null else null
	if sb != null:
		await _move(sb.get_global_rect().get_center())
		await _wait(0.5)
		await _cshot("09_sacrifice_button_keeps_the_gauntlet", Input.CURSOR_POINTING_HAND, &"pointer")
	gs.sacrifice.stop()
	await _wait(0.6)
	_check("L22 leaving sacrifice mode clears the knife", not CursorSkin.has_mode(&"knife") and not CursorSkin.has_mode(&"knife_hot"), str(CursorSkin.active_mode()))
	# Attack target pick: the reticle, locked over a legal target, barred over a card that is not one.
	m.submit(a, {"t": "next_phase"})              # Battle Phase
	host.broadcast()
	await _wait(0.8)
	host.handle(a, {"t": "attack", "uid": uids["mine0"]})
	await _wait(0.8)
	_check("L22 an attack target pick is open", String(m.pending.get("kind", "")) == "attack_target", str(m.pending.get("kind", "")))
	await _move(gs.play_area.get_center() + Vector2(-420, 10))
	await _wait(0.5)
	await _cshot("10_aim_reticle", Input.CURSOR_ARROW, &"target")
	await _move(_slot_rect(o, "unit", 0).get_center())
	await _wait(0.6)
	await _cshot("11_aim_locked_on_legal_target", Input.CURSOR_POINTING_HAND, &"target_lock", true)
	await _move(_slot_rect(o, "unit", 4).get_center())
	await _wait(0.6)
	await _cshot("12_aim_barred_over_protected_unit", Input.CURSOR_POINTING_HAND, &"target_no", true)
	await _move(_slot_rect(a, "unit", 1).get_center())
	await _wait(0.6)
	await _cshot("13_aim_barred_over_my_own_unit", Input.CURSOR_POINTING_HAND, &"target_no")
	# Turning the setting off restores the system cursor at once; on again re-applies.
	CursorSkin.set_enabled(false)
	_check("L22 off: every shape back to the system cursor", CursorSkin.applied().values().all(func(v): return String(v) == ""), str(CursorSkin.applied()))
	CursorSkin.set_enabled(true)
	_check("L22 on again: the reticle is back", String(CursorSkin.applied().get(Input.CURSOR_ARROW, "")).begins_with("target"), str(CursorSkin.applied()))


# ---------------------------------------------------------------- capture

## Saves the frame with the cursor composited, after checking the viewport's shape shows `want_art`.
func _cshot(name: String, _shape_hint: int, want_art: StringName, k4: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var shape := DisplayServer.cursor_get_shape()
	var art := CursorSkin.current_art(shape)
	_check("L22 %s shows %s" % [name, want_art], art == want_art, "shape %d art %s mode %s" % [shape, art, CursorSkin.active_mode()])
	var pos := _hold
	var n := CursorSkin.current_size()
	if art != &"":
		_stamp(img, art, n, pos, 1.0)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)
	_gallery.append({"shot": name, "shape": shape, "art": String(art), "size": n, "mode": String(CursorSkin.active_mode())})
	if k4 or name in ["04_board_arrow", "05_board_pointer_on_hand_card", "07_sacrifice_knife_hot_over_my_unit"]:
		var big := get_viewport().get_texture().get_image()
		big.convert(Image.FORMAT_RGBA8)
		big.resize(int(1600 * K4), int(1000 * K4), Image.INTERPOLATE_CUBIC)
		var p4 := pos * K4
		if art != &"":
			_stamp(big, art, CursorSkin.size_for_scale(K4), p4, 1.0)
		var crop := Rect2i(Vector2i(clampi(int(p4.x) - 400, 0, big.get_width() - 800), clampi(int(p4.y) - 250, 0, big.get_height() - 500)), Vector2i(800, 500))
		big.get_region(crop).save_jpg(out_dir.path_join(name + "_4k_crop.jpg"), 0.88)


func _stamp(img: Image, art: StringName, n: int, pos: Vector2, _a: float) -> void:
	var tex := CursorSkin.texture(art, n)
	if tex == null:
		return
	var ci := tex.get_image()
	ci.decompress()
	ci.convert(Image.FORMAT_RGBA8)
	var h := CursorSkin.hotspot_px(CursorSkin.hotspot_units(art), n)
	img.blend_rect(ci, Rect2i(0, 0, n, n), Vector2i(int(pos.x), int(pos.y)) - h)


func _find_all(n: Node, pred: Callable) -> Array:
	var out := []
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all(c, pred))
	return out


func _finish_gallery() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("cursor_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "shots": _gallery, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("CURSOR GALLERY DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
