extends SceneTree
## Development-only evidence driver for the 21 Oct 2026 PANELS batch (H1 deck tabs, H2 action
## buttons, H6 pile rows, H8 card tooltip, H9 trap prompt, H11 details panel and game log, H22 the
## go-first choice). Run windowed from rldb/:
##   godot --path . -s res://src/dev/h2_panels_shots.gd -- --no-steam --out=<abs dir> [--size=1600x900] [--calm]
## Stages one hot-seat series through the real engine and LocalHost and saves one JPG (q88) per
## state. Uses its own deck file (never the player's, nor another driver's) and restores the
## log-size preference it toggles.

const DECKS := "user://test_decks_h2_panels.json"

var main: Node
var host: LocalHost
var m: MatchEngine
var gs: GameScreen
var out_dir := ""
var tag := ""
var calm := false
var a := 0
var o := 1
var uids := {}
var want := Vector2i(1600, 900)


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=", true, 1)[1]
		elif arg.begins_with("--size="):
			var p := arg.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif arg == "--calm":
			calm = true
	want = size
	tag = "%dx%d%s" % [size.x, size.y, "_calm" if calm else ""]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DeckStore.PATH = DECKS
	DeckStore._write([])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	UIStyle.reduce_motion = calm
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(want)
	await _wait(0.4)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(1.2)
	host = main.local_host
	gs = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	_drop_coins()
	await _deck_tabs()
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	_drop_coins()
	_stage()
	_show(a)
	await _wait(0.8)
	await _action_rows()
	await _details_and_log()
	await _pile_rows()
	await _tooltip()
	await _trap_prompt()
	await _go_first()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DECKS))
	print("H2 PANELS DONE ", tag)
	quit()


func _drop_coins() -> void:
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()


# ---------------------------------------------------------------- H1
func _deck_tabs() -> void:
	_move(Vector2(4, 4))
	await _wait(0.6)
	await _snap("h1_01_deck_tabs_no_custom")
	for n in ["Ember Rush", "Tidal Control", "Stone Wall"]:
		DeckStore.save_deck(n, [112, 112, 36, 34, 70, 162, 29, 54, 51, 37, 28, 13, 102])
	# A fresh deck stage (a new series) picks its default tab again.
	var ov: GameSeriesOverlay = gs.overlays
	ov.decks = DeckSelectView.new(ov)
	ov.refresh()
	await _wait(0.6)
	await _snap("h1_02_deck_tabs_with_custom")
	DeckStore._write([])
	ov.decks = DeckSelectView.new(ov)
	ov.refresh()
	await _wait(0.2)


# ---------------------------------------------------------------- staging
func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	a = m.active
	o = 1 - a
	uids["water"] = TB.unit(m, a, 1, 0)
	uids["fire"] = TB.unit(m, a, 110, 1, "atk", 10)
	m.cards[uids["fire"]]["st"]["burn"] = 2
	uids["h_water"] = TB.card(m, a, 1)
	uids["h_dante"] = TB.card(m, a, 36)
	uids["h_loak"] = TB.card(m, a, 19)
	for id in [1, 110, 15, 19, 36, 49, 62]:
		TB.card(m, a, id, "spent")
	for id in [93, 56, 151, 62, 170]:
		TB.card(m, a, id, "extra")
	uids["o_fire"] = TB.unit(m, o, 110, 0, "atk", 10)
	m.players[a]["ap"] = 6
	host.broadcast()


# ---------------------------------------------------------------- H2
func _action_rows() -> void:
	_move(_neutral())
	await _wait(0.4)
	gs.selection.select(uids["h_water"])
	await _wait(0.6)
	await _snap("h2_01_action_row_hand")
	var st := gs.action_row.stack
	if st != null and is_instance_valid(st) and st.get_child_count() > 0:
		var bs := st.get_children()
		await _hover((bs[0] as Control).get_global_rect().get_center())
		await _wait(0.3)
		await _snap("h2_02_action_row_hover")
		await _crop("h2_02b_action_row_zoom", _grow_rect(st.get_global_rect(), Vector2(60, 50)))
	gs.selection.deselect()
	_move(_neutral())
	await _wait(0.3)
	gs.selection.select(uids["fire"])
	await _wait(0.6)
	await _snap("h2_03_action_row_field")
	st = gs.action_row.stack
	if st != null and is_instance_valid(st):
		await _crop("h2_03b_action_row_field_zoom", _grow_rect(st.get_global_rect(), Vector2(60, 50)))


# ---------------------------------------------------------------- H11
func _details_and_log() -> void:
	# The field unit stays selected: the details panel shows its ATK / DEF tiles and statuses.
	var side := Rect2(Vector2(want.x - gs.sidebar_w, 0), Vector2(gs.sidebar_w, want.y))
	await _snap("h11_01_details_default")
	await _crop("h11_01b_sidebar_default", side)
	var lg = gs.game_log
	if lg.has_method("set_expanded"):
		lg.set_expanded(true, false)
		await _wait(0.12)
		await _crop("h11_02a_sidebar_expanding", side)
		await _wait(0.6)
		await _crop("h11_02b_sidebar_expanded", side)
		lg.set_expanded(false, false)
		await _wait(0.6)
		await _crop("h11_03_sidebar_collapsed_again", side)
	gs.selection.deselect()
	await _wait(0.2)


# ---------------------------------------------------------------- H6
func _pile_rows() -> void:
	var side := Rect2(Vector2(want.x - gs.sidebar_w, 0), Vector2(gs.sidebar_w, want.y))
	gs.details.show_pile("spent")
	await _wait(0.5)
	_move(_neutral())
	await _wait(0.3)
	await _crop("h6_01_spent_rows", side)
	gs.details.show_pile("extra")
	await _wait(0.5)
	await _crop("h6_02_extra_rows", side)
	var rows := gs.details.pile_list.get_children()
	if rows.size() > 1:
		await _hover((rows[1] as Control).get_global_rect().position + Vector2(40, 30))
		await _wait(0.3)
		await _crop("h6_03_extra_row_expanded", side)
	gs.details.close_pile()
	_move(_neutral())
	await _wait(0.3)


# ---------------------------------------------------------------- H8
func _tooltip() -> void:
	var host_panel := PanelContainer.new()
	host_panel.add_theme_stylebox_override("panel", gs.get_theme_stylebox("panel", "TooltipPanel"))
	host_panel.z_index = 4000
	host_panel.z_as_relative = false
	gs.add_child(host_panel)
	var x := 380.0
	for id in [151, 62]:
		var cw := CardWidget.new().setup(MatchView.def_view(id), "hand")
		gs.add_child(cw)
		cw.visible = false
		var tip = cw._make_custom_tooltip(cw.tooltip_text)
		if tip == null:
			var l := Label.new()
			l.text = cw.tooltip_text
			tip = l
		var p := host_panel.duplicate() as PanelContainer
		gs.add_child(p)
		p.add_child(tip)
		p.position = Vector2(x, 140)
		x += 460.0
		cw.queue_free()
	host_panel.queue_free()
	await _wait(0.4)
	await _snap("h8_01_card_tooltips")
	for n in gs.get_children():
		if n is PanelContainer and n.z_index == 4000:
			n.queue_free()
	await _wait(0.2)


# ---------------------------------------------------------------- H9
func _trap_prompt() -> void:
	var real: Dictionary = gs.mv.get("pending", {})
	var pd := {"id": 999, "mine": true, "player": a, "cancellable": false, "min": 1, "max": 1, "kind": "trap_response",
		"prompt": "Rushed Recklessly can be activated in response to the attack on Dante.", "options": [
		{"i": 0, "label": "Activate Rushed Recklessly (Trap)"}, {"i": 1, "label": "Skip"}, {"i": 2, "label": EffectEngine.TRAP_PASS_TURN}]}
	gs.mv["pending"] = pd
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	await _wait(0.5)
	await _snap("h9_01_trap_prompt")
	gs.mv["pending"] = real
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	await _wait(0.2)


# ---------------------------------------------------------------- H22
func _go_first() -> void:
	m.submit(a, {"t": "next_phase"})
	for u in (m.players[o]["units"] as Array).duplicate():
		if u != null and int(u) >= 0:
			TB.kill(m, int(u))
	m.players[o]["hp"] = 4
	host.broadcast()
	await _wait(0.6)
	m.submit(a, {"t": "attack", "uid": uids["fire"]})
	host.broadcast()
	_auto_answer()
	await _wait(5.5)
	var t0 := Time.get_ticks_msec()
	while host.series.stage != Series.STAGE_REWARDS and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	print("stage ", host.series.stage)
	host.handle(0, {"t": "reward_finish"})
	host.handle(1, {"t": "reward_finish"})
	await _wait(0.4)
	var loser: int = host.series.last_loser
	_show(loser)
	await _wait(1.0)
	_move(Vector2(4, 4))
	await _wait(0.3)
	await _snap("h22_01_go_first")
	var seg := gs.find_child("FirstPlayerChoice", true, false) as Control
	if seg != null:
		await _crop("h22_01b_go_first_zoom", _grow_rect(seg.get_global_rect(), Vector2(120, 110)))
		await _hover((seg.get_child(1) as Control).get_global_rect().get_center())
		await _crop("h22_02_go_first_hover", _grow_rect(seg.get_global_rect(), Vector2(120, 110)))
		host.handle(loser, {"t": "first_player", "who": loser})
		await _wait(0.6)
		_move(Vector2(4, 4))
		await _wait(0.3)
		seg = gs.find_child("FirstPlayerChoice", true, false) as Control
		if seg != null:
			await _crop("h22_03_go_first_chosen", _grow_rect(seg.get_global_rect(), Vector2(120, 110)))


# ---------------------------------------------------------------- helpers

func _auto_answer() -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 12:
		guard += 1
		var pd := m.pending
		var picks := []
		for i in maxi(1, int(pd.get("min", 1))):
			picks.append(i)
		host.handle(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": picks})
		host.broadcast()


func _neutral() -> Vector2:
	return gs.get_global_transform() * Vector2(gs.board._ux - 320.0, gs.board._y0 + 520.0)


func _grow_rect(r: Rect2, by: Vector2) -> Rect2:
	return r.grow_individual(by.x, by.y, by.x, by.y)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_save(img, name)


## Saves the part `r` of the screen (zoomed x2 when small, so a review can read it).
func _crop(name: String, r: Rect2) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var ri := Rect2i(r.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size()))))
	if ri.size.x < 4 or ri.size.y < 4:
		return
	var c := img.get_region(ri)
	if c.get_width() < 800 and c.get_height() < 450:
		c.resize(c.get_width() * 2, c.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	_save(c, name)


func _save(img: Image, name: String) -> void:
	if img.get_width() > 1600 or img.get_height() > 1600:
		var k := 1600.0 / float(maxi(img.get_width(), img.get_height()))
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)
	print("shot ", name)


func _move(pos: Vector2) -> void:
	root.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(4, 0)
	root.push_input(ev, true)


func _hover(pos: Vector2) -> void:
	for i in 6:
		_move(pos + Vector2(i % 2, 0))
		await process_frame
	await _wait(0.6)
	_move(pos)
	await process_frame
