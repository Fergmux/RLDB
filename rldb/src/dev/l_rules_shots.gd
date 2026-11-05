extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for the L batch rules items (design/owner-feedback-2026-11-05.md):
## L9 Hypnotise's zone choice (the target, then the zone pick on the caster's side with the arrow from
## the unit taken, a real click on a zone, the unit in that zone, its return at end of turn) and L15
## Sneaky Snunday (the turn banner; a permanent +4 reads -4 and a permanent -6 reads +6 while it lasts). Launched through
## its boot script, NOT headless:
##   godot --path rldb -s res://src/dev/l_rules_shots_boot.gd -- <absolute dir> --l-rules-shots
## Writes JPG screenshots (q88, at most 1600 px wide) and `l_rules_report.json`, then quits.

const HYPNOTISE := 180
const SNUNDAY := 154


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only: the player's audio settings file is never written
	await _frames(5)
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
	await _wait(4.0)          # past the coin flip and the deal
	await _steps()
	_finish()


func _stage() -> void:
	a = m.active
	o = 1 - a
	uids["own"] = _put(a, TB_WATER, 0, "atk")
	m.cards[uids["own"]]["mods"].append({"atk": -6, "def": 0, "until": "field", "src": "Overextend"})
	uids["buffed"] = _put(a, TB_EARTH, 2, "atk")
	m.cards[uids["buffed"]]["mods"].append({"atk": 4, "def": 0, "until": "field", "src": "Krakeshin"})
	uids["victim"] = _put(o, TB_FIRE, 1, "atk", 10)
	uids["guard"] = _put(o, TB_WATER, 4, "def")
	uids["hyp"] = _new(a, HYPNOTISE, "hand")
	uids["snun"] = _new(a, SNUNDAY, "hand")
	m.players[a]["ap"] = 10
	m.add_log("[dev] Board arranged for the L9 / L15 rules evidence run.")


const TB_WATER := 1
const TB_FIRE := 110
const TB_EARTH := 120


func _steps() -> void:
	await _move(Vector2(1300, 120))
	await _shot("l9_00_board")
	# L9: target, then the zone on the caster's side.
	host.handle(a, {"t": "cast", "uid": uids["hyp"]})
	await _wait(0.8)
	await _shot("l9_01_target_pick")
	_answer(a, "front row col 2")
	await _wait(0.8)
	var pd := m.pending
	_check("L9 a zone prompt for the caster", pd.get("kind", "") == "slot" and int(pd.get("player", -1)) == a, str(pd.get("kind", "")))
	_check("L9 the prompt places the unit taken", int(pd.get("placing", -1)) == uids["victim"], str(pd.get("placing", -1)))
	await _shot("l9_02_zone_pick")
	var target := _zone_rect(a, "unit", 5).get_center()
	await _move(target)
	await _wait(0.5)
	await _shot("l9_03_zone_hover")
	await _click(target)
	await _wait(1.6)
	_check("L9 the unit is in the zone clicked", int(m.cards[uids["victim"]]["ctl"]) == a and int(m.cards[uids["victim"]]["slot"]) == 5,
		"ctl %d slot %d" % [int(m.cards[uids["victim"]]["ctl"]), int(m.cards[uids["victim"]]["slot"])])
	await _move(Vector2(1300, 120))
	await _shot("l9_04_after_steal")
	# L15: a permanent +10 reads -10 while Sneaky Snunday lasts.
	var before := m.atk_of(uids["buffed"])
	host.handle(a, {"t": "cast", "uid": uids["snun"]})
	await _wait(2.6)          # the Spell spotlight
	_check("L15 a permanent +4 reads -4", m.atk_of(uids["buffed"]) == before - 8, "%d -> %d" % [before, m.atk_of(uids["buffed"])])
	_check("L15 a permanent -6 reads +6", m.atk_of(uids["own"]) == 14, str(m.atk_of(uids["own"])))
	await _shot("l15_01_snunday_active")
	await _move(_slot_rect(a, "unit", 2).get_center())
	await _wait(1.2)
	await _shot("l15_02_snunday_card_hover")
	await _click(_slot_rect(a, "unit", 2).get_center())
	await _wait(0.8)
	await _shot("l15_03_snunday_card_details")
	await _key(KEY_ESCAPE)
	await _move(Vector2(1300, 120))
	# End of turn: the unit goes home and Snunday ends.
	var g := 0
	while m.active == a and g < 6:
		if not m.pending.is_empty():
			_answer(int(m.pending["player"]), String(m.pending["options"][0]["label"]))
		else:
			host.handle(a, {"t": "next_phase"})
		g += 1
		await _wait(0.6)
	await _wait(2.5)
	_check("L9 back in its own zone at end of turn", int(m.cards[uids["victim"]]["ctl"]) == o and int(m.cards[uids["victim"]]["slot"]) == 1, "")
	_check("L15 over at end of turn", not m.reversal_active() and m.atk_of(uids["buffed"]) == before, str(m.atk_of(uids["buffed"])))
	_view_seat(o)
	await _wait(1.0)
	await _shot("l9_05_returned_owner_view")
	_view_seat(a)
	await _wait(1.0)
	await _shot("l9_06_returned_caster_view")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("l_rules_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("L RULES DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
