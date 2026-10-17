extends SceneTree
## Development-only visual driver for the F03 effects package (badges, ready glow, destroy / exhaust,
## special summons, game end). Run windowed:
##   godot --path rldb -s res://src/dev/f03_fx_driver.gd -- --no-steam --fx-shots=<abs dir> --mode=<mode> [--size=1600x900]
## Modes: ready, destroy, exhaust, fusion, ritual, arcane, win, lose, series, strike, final, fps, plus
## selfbuff (F02: overlapping self-buffs on a hovered unit; prints its drift), unitwin / unitwin_trap (F12:
## a game-winning attack on a unit, the second answered in a trap window), fpsunit and aa (F13: reports the
## renderer and MSAA actually in use, saves crops at Off / 4x / 8x and times frames at each). It stages a board through the
## real engine, drives commands through LocalHost and saves frame sequences of the running animation.

var main: Node
var host: LocalHost
var m: MatchEngine
var out_dir := ""
var mode := ""
var tag := ""


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fx-shots="):
			out_dir = a.split("=", true, 1)[1]
		elif a.begins_with("--mode="):
			mode = a.split("=")[1]
		elif a.begins_with("--size="):
			var p := a.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	tag = "%s_%dx%d" % [mode, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
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
	# Skip the coin flip of game 1 (the "coin" mode keeps it).
	if mode != "coin":
		main.screen._coin_shown[String(main.screen.view.get("save_id", "local"))] = true
		for n in main.screen.get_children():
			if n is CoinFlip:
				n.queue_free()
	call("_mode_" + mode)


# ---------------------------------------------------------------- helpers

func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [tag, name]))


## Saves `n` frames `step` seconds apart, named name_00 ...
func _seq(name: String, n: int, step: float) -> void:
	for i in n:
		await _snap("%s_%02d" % [name, i])
		await _wait(step)


func _done() -> void:
	print("FX DONE ", tag)
	quit()


func _turn2() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})


func _fresh_view(p: int) -> void:
	host.broadcast()
	_show(p)


# ---------------------------------------------------------------- modes

func _mode_ready() -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	TB.unit(m, a, 1, 0)
	TB.unit(m, a, 110, 1)
	TB.unit(m, a, 36, 4)
	TB.unit(m, a, 34, 2, "def")
	TB.unit(m, o, 70, 0, "def")
	TB.unit(m, o, 162, 2)
	TB.card(m, a, 1)
	TB.card(m, a, 36)
	TB.card(m, a, 101)
	TB.power(m, a, 54, 0)
	TB.card(m, a, 172, "extra")
	TB.card(m, a, 1, "spent")
	TB.card(m, a, 110, "spent")
	var big := TB.unit(m, o, 36, 4, "atk", 126, 130)
	m.players[a]["ap"] = 6
	_fresh_view(a)
	await _wait(0.6)
	await _seq("ready", 8, 0.22)
	_done()


## Answers every pending choice with its first legal picks (dev staging only).
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


func _mode_destroy() -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	var victim := TB.unit(m, o, 36, 0)
	TB.unit(m, o, 1, 2)
	_fresh_view(a)
	await _wait(0.5)
	m.destroy(victim, "effect", -1, a)
	host.broadcast()
	await _seq("destroy", 12, 0.09)
	_done()


func _mode_exhaust() -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	TB.unit(m, a, 1, 0)
	TB.unit(m, o, 110, 1)
	TB.card(m, o, 36, "spent")
	TB.card(m, o, 1, "spent")
	var viewer := a
	for x in OS.get_cmdline_user_args():
		if x == "--viewer=other":
			viewer = o
	_fresh_view(viewer)
	await _wait(0.5)
	TB.cast(m, a, 101)
	_auto_answer()
	host.broadcast()
	await _seq("exhaust", 28, 0.12)
	_done()


func _summon_scene(kind: String) -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	TB.unit(m, o, 110, 1)
	m.players[a]["ap"] = 6
	match kind:
		"fusion":
			var mag := TB.unit(m, a, 69, 0)
			TB.unit(m, a, 34, 1)
			TB.card(m, a, 142, "extra")
			_fresh_view(a)
			await _wait(0.5)
			m.submit(a, {"t": "ability", "uid": mag, "idx": 0})
		"ritual":
			var u := TB.unit(m, a, 1, 0)
			m.apply_status(u, "rune", 1)
			var r := TB.card(m, a, 98, "extra")
			_fresh_view(a)
			await _wait(0.5)
			m.submit(a, {"t": "ritual", "uid": r})
		"arcane":
			TB.card(m, a, 1, "spent")
			TB.card(m, a, 110, "spent")
			var ar := TB.card(m, a, 172, "extra")
			_fresh_view(a)
			await _wait(0.5)
			m.submit(a, {"t": "arcane", "uid": ar})
	_auto_answer()
	host.broadcast()
	await _seq(kind, 22, 0.1)
	_done()


func _mode_fusion() -> void:
	_summon_scene("fusion")


func _mode_ritual() -> void:
	_summon_scene("ritual")


func _mode_arcane() -> void:
	_summon_scene("arcane")


func _end_scene(viewer_wins: bool, series: bool) -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	TB.unit(m, a, 36, 0)
	m.players[o]["hp"] = 5
	if series:
		host.series.scores[a] = 1
	host.handle(a, {"t": "next_phase"})
	_fresh_view(a if viewer_wins else o)
	await _wait(0.5)
	var uid: int = m.players[a]["units"][0]
	host.handle(a, {"t": "attack", "uid": uid})
	_auto_answer()
	await _seq("end", 60, 0.14)
	_done()


func _mode_win() -> void:
	_end_scene(true, false)


func _mode_lose() -> void:
	_end_scene(false, false)


func _mode_serieswin() -> void:
	_end_scene(true, true)


func _mode_serieslose() -> void:
	_end_scene(false, true)


## F04-01: the game-1 coin flip over the starting board (frames from the first draw to the fade-out).
func _mode_coin() -> void:
	await _seq("coin", 36, 0.1)
	_done()


## F04-07: a non-lethal direct attack.
func _mode_strike() -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	TB.unit(m, a, 36, 0)
	host.handle(a, {"t": "next_phase"})
	_fresh_view(a)
	await _wait(0.5)
	host.handle(a, {"t": "attack", "uid": m.players[a]["units"][0]})
	_auto_answer()
	await _seq("strike", 24, 0.04)
	_done()


## F04-07: lethal damage from an effect (no attack): the smaller final-blow flourish.
func _mode_final() -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	m.players[o]["hp"] = 5
	_fresh_view(a)
	await _wait(0.5)
	m.change_hp(o, -9, " (test)")
	host.broadcast()
	await _seq("final", 22, 0.1)
	_done()


## F04-07: frame rate through the lethal sequence (no screenshots, so nothing else slows the loop). Prints the
## frames per second of every half second from before the attack to the end of the victory look.
func _mode_fps() -> void:
	_fps_scene(false)


## F12: frame rate through the lethal sequence of a game-winning attack on a unit.
func _mode_fpsunit() -> void:
	_fps_scene(true)


func _fps_scene(on_unit: bool) -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	if on_unit:
		TB.unit(m, a, 36, 0, "atk", 30, 30)
		TB.unit(m, o, 1, 1)
	else:
		TB.unit(m, a, 36, 0)
	m.players[o]["hp"] = 5
	host.handle(a, {"t": "next_phase"})
	_fresh_view(a)
	await _wait(1.0)
	var counter := [0]
	var cb := func(): counter[0] += 1
	process_frame.connect(cb)
	var uid: int = m.players[a]["units"][0]
	host.handle(a, {"t": "attack", "uid": uid})
	_auto_answer()
	var line := []
	for i in 16:
		counter[0] = 0
		await _wait(0.5)
		line.append("%.0f" % (counter[0] / 0.5))
	process_frame.disconnect(cb)
	print("FPS per 0.5s from the attack: ", ", ".join(line), "  (Engine.time_scale=", Engine.time_scale, ", lethal=", main.screen.fx.last_lethal_mode, ")")
	_done()


## F13: what the running game really renders with, crops of the same board at MSAA Off / 4x / 8x, and
## the frame rate of the idle board (ready glow pulsing) at each, then the lethal sequence at 4x.
func _mode_aa() -> void:
	print("F13 renderer: method=%s driver=%s adapter=%s | project msaa_2d=%s | UIStyle.aa_level=%d explicit=%s | root.msaa_2d=%d | max_fps=%d vsync=%d" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d"),
		UIStyle.aa_level, UIStyle.aa_explicit, root.msaa_2d, Engine.max_fps, DisplayServer.window_get_vsync_mode()])
	_turn2()
	var a := m.active
	var att := TB.unit(m, a, 36, 0, "atk", 30, 30)
	TB.unit(m, a, 110, 1, "def")
	var tgt := TB.unit(m, 1 - a, 70, 2)
	m.players[a]["ap"] = 6
	_fresh_view(a)
	await _wait(0.8)
	var counter := [0]
	var cb := func(): counter[0] += 1
	for lv in [0, 4, 8]:
		root.msaa_2d = UIStyle.msaa_for(lv)
		await _wait(0.3)
		await _snap("msaa_%d" % lv)
		process_frame.connect(cb)
		counter[0] = 0
		var t0 := Time.get_ticks_usec()
		await _wait(2.0)
		var secs := (Time.get_ticks_usec() - t0) / 1.0e6
		process_frame.disconnect(cb)
		print("F13 msaa %dx: %.0f fps over %.1fs (root.msaa_2d=%d)" % [lv, counter[0] / secs, secs, root.msaa_2d])
	root.msaa_2d = UIStyle.msaa_for(4)
	# The game-winning attack on a unit at 4x: frames per half second through the whole sequence.
	m.players[1 - a]["hp"] = 5
	host.handle(a, {"t": "next_phase"})
	await _wait(0.6)
	host.handle(a, {"t": "attack", "uid": att})
	var pd := m.pending
	if not pd.is_empty() and pd.get("kind", "") == "attack_target":
		host.handle(a, {"t": "choose", "id": pd["id"], "values": [tgt]})
	_auto_answer()
	process_frame.connect(cb)
	var line := []
	for i in 14:
		counter[0] = 0
		await _wait(0.5)
		line.append("%.0f" % (counter[0] / 0.5))
	process_frame.disconnect(cb)
	print("F13 lethal-on-unit at 4x, fps per 0.5s: ", ", ".join(line), " lethal=", main.screen.fx.last_lethal_mode, " time_scale=", Engine.time_scale)
	_done()


## F02: three overlapping self-buffs (trigger + status, as a unit buffing itself) on a hovered unit. Samples
## the card every frame and prints how far it strays from its lifted resting place, then unhovers.
func _mode_selfbuff() -> void:
	_turn2()
	var a := m.active
	var uid := TB.unit(m, a, 36, 1)
	TB.unit(m, 1 - a, 1, 1)
	_fresh_view(a)
	await _wait(0.6)
	var gs: GameScreen = main.screen
	var w: CardWidget = gs.board.slot_item(a, "unit", 1)["widget"]
	gs.hover.debug_hover_slot(a, "unit", 1)
	await _wait(0.3)
	var lifted := w.position
	var rect0 := w.get_global_rect()
	var at := {"p": a, "zone": "unit", "slot": 1}
	var worst := [0.0, 0.0]
	var sample := func():
		if is_instance_valid(w):
			worst[0] = maxf(worst[0], absf(w.position.y - lifted.y))
			worst[1] = maxf(worst[1], absf(w.position.x - w.fx_offset.x - lifted.x))
	process_frame.connect(sample)
	for i in 3:
		gs.fx.play([{"k": "trigger", "at": at}, {"k": "status", "at": at, "s": "pierce", "n": 1}], gs.mv)
		await _snap("selfbuff_%02d" % (i * 2))
		await _wait(0.08)
		await _snap("selfbuff_%02d" % (i * 2 + 1))
		await _wait(0.04)
	await _seq("selfbuff_tail", 6, 0.12)
	process_frame.disconnect(sample)
	var settled := w.position
	var rect1 := w.get_global_rect()
	gs.hover.debug_clear()
	await _wait(0.4)
	print("F02 selfbuff: max |dy|=%.3f max |dx-fx|=%.3f settled=%s lifted=%s rect0=%s rect1=%s after_unhover=%s fx_offset=%s size=%s rest=%s" % [
		worst[0], worst[1], settled, lifted, rect0, rect1, w.position, w.fx_offset, w.size, w.custom_minimum_size])
	await _snap("selfbuff_unhovered")
	_done()


## F12: a game-winning attack on a unit (30 ATK into an 8 ATK unit, opponent at 5 HP).
func _mode_unitwin() -> void:
	await _unit_win(false)


## F12: the same, with a set Trap so the defender gets a response window (declaration and resolution in
## separate batches) and passes.
func _mode_unitwin_trap() -> void:
	await _unit_win(true)


func _unit_win(trap: bool) -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	var att := TB.unit(m, a, 36, 0, "atk", 30, 30)
	var tgt := TB.unit(m, o, 1, 1)
	m.players[o]["hp"] = 5
	if trap:
		m.players[o]["backrow"] = [-1, -1, -1]
		TB.set_card(m, o, 163, 0)
	host.handle(a, {"t": "next_phase"})
	_fresh_view(a)
	await _wait(0.5)
	host.handle(a, {"t": "attack", "uid": att})
	var pd := m.pending
	if not pd.is_empty() and pd.get("kind", "") == "attack_target":
		host.handle(a, {"t": "choose", "id": pd["id"], "values": [tgt]})
	if trap:
		await _seq("unitwin_trap_window", 3, 0.25)
		print("F12 trap window pending: ", m.pending.get("kind", ""))
	_auto_answer()
	await _seq("unitwin" + ("_trap" if trap else ""), 44, 0.1)
	print("F12 %s: winner=%d lethal=%s time_scale=%s hold=%s" % [mode, m.winner, main.screen.fx.last_lethal_mode, Engine.time_scale, main.screen.fx.game_end_hold])
	_done()
