extends SceneTree
## Development-only driver for the end of a game (owner feedback 22 Oct, J9 J10 J12 J13 J15). Run windowed:
##   godot --path rldb -s res://src/dev/eog_shots.gd -- --no-steam --eog-shots=<abs dir> --mode=<mode> [--size=1600x1000]
## Modes:
##   kill      J9: a killing direct attack, then the player keeps clicking (another unit, a hand card, the
##             table) and pressing keys while the kill plays. Saves frames through the sequence and the
##             rewards screen, and prints PASS / FAIL for: the kill and the victory look both played, nothing
##             was sent, nothing is selected or lifted, and no card is left over the rewards screen.
##   selected  J10: a hand card selected (its action row open), a field card hovered and a status tip shown
##             when the opponent concedes; the rewards screen must cover all of them.
##   rewards   J12 / J15: the rewards screen (dim over the whole window, Menu above it, picks plate).
##   menu      J13: the in-game menu open.
## It stages the board through the real engine and drives LocalHost, like f03_fx_driver.gd.

var main: Node
var host: LocalHost
var m: MatchEngine
var out_dir := ""
var mode := ""
var _pass := 0
var _fail := 0


func _initialize() -> void:
	var size := Vector2i(1600, 1000)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--eog-shots="):
			out_dir = a.split("=", true, 1)[1]
		elif a.begins_with("--mode="):
			mode = a.split("=")[1]
		elif a.begins_with("--size="):
			var p := a.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
	SeriesStore.DIR = "user://dev_saves"   # scripted runs never touch the player's saves
	PlayerProgress.persist = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.5)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	main.screen._coin_shown[String(main.screen.view.get("save_id", "local"))] = true
	for n in main.screen.get_children():
		if n is CoinFlip:
			n.queue_free()
	await call("_mode_" + mode)
	print("EOG DONE mode=%s pass=%d fail=%d" % [mode, _pass, _fail])
	quit()


# ---------------------------------------------------------------- helpers

func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _gs() -> GameScreen:
	return main.screen


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [mode, name]))


func _check(label: String, ok: bool, extra: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", label, extra])


func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = button
		ev.pressed = down
		ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if down else 0
		root.push_input(ev, true)
		await process_frame


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		root.push_input(ev, true)
		await process_frame


## A board for the active seat `a`: two ready attackers, a unit and a spell in the hand; the opponent
## on 5 HP with an empty field (any attack kills).
func _stage_kill_board() -> int:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	var a := m.active
	var o := 1 - a
	for u in m.players[o]["units"].duplicate():
		if int(u) >= 0:
			TB.kill(m, int(u))
	TB.unit(m, a, 36, 0)
	TB.unit(m, a, 110, 1)
	TB.unit(m, a, 1, 3)
	TB.card(m, a, 1)
	TB.card(m, a, 101)
	m.players[o]["hp"] = 5
	m.players[a]["ap"] = 5
	var guard := 0
	while String(m.phase) != "battle" and guard < 4:
		guard += 1
		host.handle(a, {"t": "next_phase"})
	host.broadcast()
	_show(a)
	return a


func _auto_answer() -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 12:
		guard += 1
		var pd := m.pending
		var n: int = pd["options"].size()
		var want: int = n if int(pd.get("min_total", 0)) > 0 else maxi(int(pd["min"]), 1)
		var idx := []
		for i in mini(want, n):
			idx.append(i)
		host.handle(pd["player"], {"t": "choose", "id": pd["id"], "indices": idx})


func _slot_centre(p: int, slot: int) -> Vector2:
	return _gs().fx_slot_global_rect(p, "unit", slot).get_center()


func _hand_centre(i: int) -> Vector2:
	var gs := _gs()
	var uid: int = gs.hand.order[i]
	return (gs.hand.items[uid]["holder"] as Control).get_global_rect().get_center()


## Card holders drawn above the series modal: anything in the hand / board / hover layers whose
## effective z reaches the modal's (J10). Returns their names.
func _cards_over_modal() -> Array:
	var gs := _gs()
	var out := []
	var modal_z := _abs_z(gs.overlays.overlay)
	for n in gs.find_children("*", "CardWidget", true, false):
		var w := n as CardWidget
		if not w.is_visible_in_tree() or gs.overlays.overlay.is_ancestor_of(w) or gs.overlays.pile_popup.is_ancestor_of(w):
			continue
		if _abs_z(w) >= modal_z:
			out.append(String(w.view.get("name", "?")))
	return out


static func _abs_z(n: CanvasItem) -> int:
	var z := 0
	var c: Node = n
	while c != null and c is CanvasItem:
		var ci := c as CanvasItem
		z += ci.z_index
		if not ci.z_as_relative:
			break
		c = c.get_parent()
	return z


# ---------------------------------------------------------------- modes

## J9: the kill, then more clicks and keys while it plays.
func _mode_kill() -> void:
	var a := _stage_kill_board()
	var gs := _gs()
	await _wait(0.8)
	await _snap("00_board")
	var sent0 := gs.debug_sent
	var att: int = m.players[a]["units"][0]
	host.handle(a, {"t": "attack", "uid": att})
	_auto_answer()
	await _wait(0.35)
	await _snap("01_kill_windup")
	_check("the kill is the lethal direct strike", gs.fx.last_lethal_mode == "direct", gs.fx.last_lethal_mode)
	# The player keeps going: clicks the other attacker, a hand card, the bare table, presses Tab and Enter.
	await _click(_slot_centre(a, 1))
	await _snap("02_after_click_unit")
	await _click(_hand_centre(0))
	await _key(KEY_TAB)
	await _key(KEY_ENTER)
	await _click(gs.play_area.get_center() + Vector2(0, -60))
	await _click(_slot_centre(a, 3), MOUSE_BUTTON_RIGHT)
	await _snap("03_after_more_input")
	_check("J9 the kill keeps playing after the clicks", gs.fx.busy(), "busy=%s" % gs.fx.busy())
	_check("J9 nothing is selected", gs.selected_uid == -1, "selected=%d" % gs.selected_uid)
	_check("J9 no action row", gs.action_row.stack == null)
	_check("J9 no inspector opened", not gs.inspect.is_open())
	_check("J9 nothing sent", gs.debug_sent == sent0, "sent %d" % (gs.debug_sent - sent0))
	var saw_end := false
	for i in 14:
		await _wait(0.25)
		await _snap("04_seq_%02d" % i)
		if gs.fx._game_end.is_active():
			saw_end = true
	_check("J9 the victory look played", saw_end)
	await _wait(3.5)
	await _snap("05_rewards")
	_check("J9 / J10 the rewards screen is up", gs.overlays.overlay.visible)
	var over := _cards_over_modal()
	_check("J9 / J10 no card drawn over the rewards screen", over.is_empty(), str(over))
	_check("J9 no card left lifted", _lifted().is_empty(), str(_lifted()))


func _lifted() -> Array:
	var gs := _gs()
	var out := []
	for uid in gs.hand.items:
		var h: Control = gs.hand.items[uid]["holder"]
		if h.z_index != 0:
			out.append(uid)
	return out


## J10: selected hand card, hovered field card, status tip and arrow when the game ends.
func _mode_selected() -> void:
	var a := _stage_kill_board()
	var gs := _gs()
	await _wait(0.8)
	var huid: int = gs.hand.order[0]
	gs.selection.select(huid)
	await _wait(0.3)
	gs.hover.debug_hover_slot(a, "unit", 1)
	var w: CardWidget = gs.fx_slot_item(a, "unit", 1)["widget"]
	StatusTip.show_for(w, "Poison ×2", w.get_global_rect(), "Loses 2 HP at the end of each turn.")
	await _wait(0.3)
	await _snap("00_selected_before_end")
	host.handle(1 - a, {"t": "concede"})
	await _wait(5.5)
	await _snap("01_rewards")
	_check("J10 the rewards screen is up", gs.overlays.overlay.visible)
	var over := _cards_over_modal()
	_check("J10 no card drawn over the rewards screen", over.is_empty(), str(over))
	_check("J10 no status tip over the rewards screen", StatusTip.shown_text() == "", StatusTip.shown_text())
	_check("J10 the selection was cleared", gs.selected_uid == -1, str(gs.selected_uid))
	gs.hover.debug_clear()


## J12 / J15: the rewards screen.
func _mode_rewards() -> void:
	var a := _stage_kill_board()
	var gs := _gs()
	await _wait(0.6)
	host.handle(1 - a, {"t": "concede"})
	await _wait(5.5)
	_show(a)
	await _wait(1.2)
	await _snap("00_rewards")
	var dim := gs.overlays.overlay_dim
	_check("J15 the dim covers the whole window", dim.visible and dim.get_global_rect().encloses(gs.get_global_rect()), str(dim.get_global_rect()))
	var mb := gs.menu.menu_button
	_check("J15 Menu draws above the dim", _abs_z(mb) > _abs_z(dim), "%d vs %d" % [_abs_z(mb), _abs_z(dim)])
	_check("J15 Menu stays at the top", mb.get_global_rect().position.y < GameScreen.TOP_H)
	await _click(mb.get_global_rect().get_center())
	await _wait(0.5)
	await _snap("01_rewards_menu_open")
	_check("J15 Menu opens over the rewards screen", gs.menu.game_menu.visible and _abs_z(gs.menu.game_menu) > _abs_z(gs.overlays.overlay))
	gs.menu.toggle()
	gs.overlays.rewards.mode = "add"
	gs.overlays.refresh()
	await _wait(0.6)
	host.handle(a, {"t": "reward_type", "category": "spell"})
	await _wait(1.0)
	await _snap("02_rewards_offer")


## J13: the in-game menu.
func _mode_menu() -> void:
	_stage_kill_board()
	var gs := _gs()
	await _wait(0.6)
	gs.menu.toggle()
	await _wait(0.6)
	await _snap("00_menu")
	var keys := []
	for c in (gs.menu.game_menu as HousePanel).body.get_children():
		if c is Button and (c as Button).visible:
			keys.append(String(c.name))
	_check("J13 Concede game comes below Return to menu", keys.find("Menu_return") >= 0 and keys.find("Menu_concede") > keys.find("Menu_return"), str(keys))
