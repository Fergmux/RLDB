extends SceneTree
## Windowed check of owner feedback C1 and C2 (20 Oct 2026): the duel clock in the turn panel
## (running, a long turn, paused, final) and the Statistics dialog in each sync state (synced,
## syncing, local only), on the test stats file (never the player's). Run from rldb/:
##   godot --path . -s res://src/dev/stats_clock_shots.gd -- <out_dir> [1600x900]

var out_dir: String = ""
var tag: String = ""
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://stats_clock_shots"
	var sz := Vector2i(1600, 900)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	run.call_deferred()


func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _snap(name: String, region: Rect2i = Rect2i()) -> void:
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if region.size != Vector2i.ZERO:
		# Regions are in window units; the image may be larger (content scale / HiDPI).
		var k := float(img.get_width()) / root.get_visible_rect().size.x
		img = img.get_region(Rect2i(Vector2i(Vector2(region.position) * k), Vector2i(Vector2(region.size) * k)))
	img.save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _seed() -> void:
	var ids := CardDB.all().map(func(c): return int(c["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 37:
		var cards := {}
		for j in 12:
			var id: int = ids[rng.randi_range(20, 80)]
			cards[str(id)] = int(cards.get(str(id), 0)) + 1
		var tn := rng.randi_range(3, 9)
		PlayerStats.record_duel({"mode": ["steam", "steam", "bot", "lan", "local"][i % 5],
			"won": null if i % 5 == 4 else rng.randf() < 0.6, "turns": tn * 2,
			"ms": rng.randi_range(240000, 900000), "tms": tn * rng.randi_range(25000, 70000), "tn": tn,
			"deck": ["Moving Ocean", "Rotmaw's Doom", "Draft deck"][i % 3],
			"cards": cards, "plays": {str(ids[33]): rng.randi_range(1, 4)}, "summons": rng.randi_range(2, 7),
			"spells": rng.randi_range(0, 4), "damage": rng.randi_range(20, 60), "best_hit": rng.randi_range(4, 23)})
	for i in 9:
		PlayerStats.record_series("steam", i % 3 != 0, [2, 1])


func _dialog() -> StatsDialog:
	var d := root.find_children("*", "StatsDialog", true, false).filter(func(x): return not x.is_queued_for_deletion())
	return d[0] if not d.is_empty() else null


func run() -> void:
	PlayerStats.forget()
	PlayerStats.clear()
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	# ---- Statistics dialog in its three sync states.
	_seed()
	var menu: MainMenu = main.menu
	menu.pick("@decks")
	await create_timer(0.5).timeout
	StatsSync.status = {"state": "synced", "reason": "", "at": int(Time.get_unix_time_from_system()) - 120}
	menu.pick("stats")
	await create_timer(0.3).timeout
	var d := _dialog()
	_check("Statistics opens", d != null)
	_check("Synced plate tag", d != null and d._panel.tag_label.text.to_lower().contains("synced"))
	_check("Synced line", d != null and d._sync_label.text.begins_with("Synced with your Steam account"))
	_check("Average turn fact listed", PlayerStats.facts().any(func(f): return f["label"] == "Average turn"))
	await _snap("01_stats_synced")
	StatsSync.set_status("syncing")
	await create_timer(0.8).timeout
	await _snap("02_stats_syncing")
	StatsSync.set_status("local", "Steam is not running")
	await create_timer(0.8).timeout
	_check("Local line", d._sync_label.text == "Kept on this computer only · Steam is not running")
	_check("Local plate tag", d._panel.tag_label.text.to_lower().contains("this computer"))
	await _snap("03_stats_local_only")
	# A cloud merge while the dialog is open refreshes the list in place.
	var before: String = PlayerStats.facts().filter(func(f): return f["label"] == "Duels played")[0]["value"]
	PlayerStats.record_duel({"mode": "steam", "won": true, "turns": 8, "ms": 420000, "tms": 200000, "tn": 4})
	await create_timer(0.8).timeout
	var texts: Array = d.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	_check("List refreshes after a merge", texts.has(str(int(before) + 1)))
	d.close()
	await create_timer(0.3).timeout
	# ---- Duel clock in the turn panel (hot-seat starter duel).
	main._privacy = false
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	for i in 8:
		await process_frame
	var host: LocalHost = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await create_timer(3.5).timeout       # the coin flip and the deal
	var gs: GameScreen = main.screen
	gs.skip_effects()
	var clk: DuelClock = gs.sidebar.clock_view.clock
	_check("Clock shown in a duel", clk != null and gs.sidebar.clock_view.visible)
	if clk == null:
		print("DONE fails=%d" % fails)
		quit(1)
		return
	clk.started -= 754_000
	clk.turn_started -= 42_000
	await create_timer(0.6).timeout
	var tp: Control = gs.sidebar.clock_view.get_parent().get_parent().get_parent()
	var panel := Rect2i(tp.get_global_rect().grow(10.0))
	await _snap("10_hud_full")
	await _snap("11_hud_clock_detail", panel)
	clk.turn_started -= 100_000
	await create_timer(0.6).timeout
	_check("Long turn shows over two minutes", clk.turn_ms() >= DuelClockView.LONG_TURN_MS)
	await _snap("12_hud_clock_long_turn", panel)
	clk.paused_since = clk.now_ms.call()
	await create_timer(0.6).timeout
	await _snap("13_hud_clock_paused", panel)
	clk.paused_since = -1
	PlayerStats.clear()
	print("DONE fails=%d" % fails)
	quit(1 if fails else 0)
