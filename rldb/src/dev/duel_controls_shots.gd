extends "res://src/dev/f02_driver.gd"
## Development-only windowed verification of the 22 Oct duel controls batch (J6, J11, J14, J25).
## Launched with
##   godot --path rldb -- --duelctl-shots=<absolute dir>
## Plays a local match through the real UI with pointer events (the F02 driver's helpers): the
## Sacrifice Unit and Trap Prompts controls under the plate (J11 / J6), the card row without
## Sacrifice, a Paralysed unit's row without a stance change (J25), the single Ritual Summon
## button and its card select tray (J14), no Trap prompt without a usable Trap (J6) and a full hand beside the
## controls. Writes PNG screenshots and `duel_controls_report.json`, then quits.

const CREEPING_NULL := 65
const MIMIC := 95
const BASIC_BEAST := 4
const FACE_DOWN_SPELL := 83


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	Sfx.set_muted(true)
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
	_stage_controls()
	host.broadcast()
	_view_seat(a)
	await _wait(4.0)          # past the coin flip and the deal
	await _controls_steps()
	_finish_controls()


func _stage_controls() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})      # turn 2, Setup Phase, the other player active
	a = m.active
	o = 1 - a
	uids["water"] = _put(a, 1, 0, "atk")                 # Basic Mage (Water)
	uids["fire"] = _put(a, 110, 1, "atk", 14)            # Basic Mage (Fire), the attacker later
	uids["beast"] = _put(a, BASIC_BEAST, 2, "atk")       # 3 Runes: Ritual Summon
	m.apply_status(uids["beast"], "rune", 3)
	uids["para"] = _put(a, 1, 4, "atk")                  # Paralysed
	m.apply_status(uids["para"], "paralyse", 2)
	uids["null"] = _new(a, CREEPING_NULL, "extra")
	uids["mimic"] = _new(a, MIMIC, "extra")
	uids["o_unit"] = _put(o, 1, 1, "atk")
	var sp := m._create_instance(FACE_DOWN_SPELL, o)    # the opponent's face-down Spell (no Trap)
	m.cards[sp]["zone"] = "backrow"
	m.cards[sp]["slot"] = 1
	m.cards[sp]["ctl"] = o
	m.cards[sp]["set_turn"] = m.turn - 1
	m.players[o]["backrow"][1] = sp
	uids["o_spell"] = sp
	m.players[a]["ap"] = 4
	m.add_log("[dev] Board arranged for the duel controls verification run.")


func _controls() -> Control:
	return gs.board.get("controls")


func _ctl_btn(i: int) -> Button:
	var c := _controls()
	return null if c == null else c.get_child(i)


## The "before" run (a build without the controls): the card rows the batch changes.
func _before_steps() -> void:
	await _move(Vector2(700, 470))
	await _wait(0.3)
	await _shot("before_01_board")
	for k in [["water", 0, "before_03_row_with_sacrifice"], ["para", 4, "before_04_paralysed_row_with_stance"], ["beast", 2, "before_05_ritual_button_names_the_unit"]]:
		await _click(_slot_rect(a, "unit", int(k[1])).get_center())
		await _wait(0.5)
		print("before row %s: %s" % [k[0], _row_labels()])
		await _shot(String(k[2]))


func _controls_steps() -> void:
	var c := _controls()
	if c == null:
		await _before_steps()
		return
	_check("J6/J11 controls shown under the plate", c != null and c.visible)
	if c != null:
		var plate := gs.plate_of(a).get_global_rect()
		var r := c.get_global_rect()
		_check("J6/J11 controls below the plate, aligned left", r.position.y >= plate.end.y and absf(r.position.x - plate.position.x) < 1.0, "%s / %s" % [r, plate])
		_check("J6/J11 controls inside the window", r.end.y <= gs.size.y - 8.0, str(r))
		var clear := true
		for uid in gs.hand.order:
			if (gs.hand.items[uid]["holder"] as Control).get_global_rect().position.x <= r.end.x:
				clear = false
		_check("J6/J11 hand clear of the controls", clear)
	await _move(Vector2(700, 470))
	await _wait(0.3)
	await _shot("01_controls_rest")
	# J11: the Sacrifice Unit plate, hovered.
	await _move(_ctl_btn(0).get_global_rect().get_center())
	await _wait(0.5)
	_check("J11 Sacrifice Unit enabled with a legal sacrifice", not _ctl_btn(0).disabled)
	await _shot("02_sacrifice_hover")
	# J11: the card row no longer offers Sacrifice.
	await _click(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.4)
	_check("J11 card row has no Sacrifice", not _row_labels().has("Sacrifice") and not _row_labels().is_empty(), str(_row_labels()))
	await _shot("03_row_without_sacrifice")
	# J25: a Paralysed unit's row has no stance change.
	await _click(_slot_rect(a, "unit", 4).get_center())
	await _wait(0.4)
	var labs := _row_labels()
	_check("J25 Paralysed unit: no stance button", not labs.has("To Defense") and not labs.has("To Attack"), str(labs))
	await _move(Vector2(1000, 470))
	await _wait(0.3)
	await _shot("04_paralysed_row_no_stance")
	# J14: one Ritual Summon button, then the card select tray.
	await _click(_slot_rect(a, "unit", 2).get_center())
	await _wait(0.4)
	labs = _row_labels()
	_check("J14 one 'Ritual Summon' button", labs.count("Ritual Summon") == 1 and not labs.any(func(t): return String(t).begins_with("Ritual:")), str(labs))
	await _shot("05_ritual_summon_button")
	await _click_row("Ritual Summon")
	await _wait(0.6)
	_check("J14 tray asks which Ritual unit", m.pending.get("kind", "") == "select" and m.pending.get("options", []).size() == 2 and _tray_widgets().size() == 2,
		"%s %d" % [m.pending.get("kind", ""), _tray_widgets().size()])
	await _move(Vector2(700, 470))
	await _wait(0.3)
	await _shot("06_ritual_tray_two_targets")
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	_check("J14 Esc cancels the pick", m.pending.is_empty() and m.cards[uids["beast"]]["zone"] == "unit")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	# J11: Sacrifice Unit: pick, confirm.
	var ap0: int = m.players[a]["ap"]
	await _click(_ctl_btn(0).get_global_rect().get_center())
	await _wait(0.5)
	_check("J11 pick prompt opens", m.pending.get("kind", "") == "select" and gs.selection.board_targeting(), gs.prompt.banner_title.text)
	await _move(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.4)
	await _shot("07_sacrifice_pick")
	await _click(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.5)
	_check("J11 confirm prompt after the pick", m.pending.get("kind", "") == "confirm", str(m.pending.get("prompt", "")))
	await _move(Vector2(700, 470))
	await _wait(0.3)
	await _shot("08_sacrifice_confirm")
	var yes := _find_button(gs.prompt.ctx_banner, "Sacrifice")
	_check("J11 Sacrifice answer button shown", yes != null)
	if yes != null:
		await _click(yes.get_global_rect().get_center())
	await _wait(1.6)
	_check("J11 unit sacrificed for +1 AP", m.cards[uids["water"]]["zone"] == "spent" and int(m.players[a]["ap"]) == ap0 + 1,
		"zone %s ap %d -> %d" % [m.cards[uids["water"]]["zone"], ap0, m.players[a]["ap"]])
	await _shot("09_after_sacrifice")
	# J6: the Trap Prompts toggle.
	_check("J6 Usable by default, seat set to eligible", String(m.players[a].get("trap_prompts", "")) == "eligible" and _ctl_btn(1).text.ends_with("Usable"), String(m.players[a].get("trap_prompts", "")))
	await _click(_ctl_btn(1).get_global_rect().get_center())
	await _wait(0.4)
	_check("J6 click: Always sets the seat always", String(m.players[a].get("trap_prompts", "")) == "always" and _ctl_btn(1).text.ends_with("Always"), _ctl_btn(1).text)
	await _move(_ctl_btn(1).get_global_rect().get_center() + Vector2(0, 2))
	await _wait(1.2)
	await _shot("10a_prompts_always_hover")
	await _click(_ctl_btn(1).get_global_rect().get_center())
	await _wait(0.4)
	_check("J6 click: Off sets the seat off", String(m.players[a].get("trap_prompts", "")) == "off" and _ctl_btn(1).text.ends_with("Off"), _ctl_btn(1).text)
	await _move(_ctl_btn(1).get_global_rect().get_center() + Vector2(0, 2))
	await _wait(1.2)
	await _shot("10_prompts_off_hover")
	await _click(_ctl_btn(1).get_global_rect().get_center())
	await _wait(0.4)
	_check("J6 click: back to Usable", String(m.players[a].get("trap_prompts", "")) == "eligible" and _ctl_btn(1).text.ends_with("Usable"))
	# J11: disabled in the Battle Phase, with the reason as tooltip.
	host.handle(a, {"t": "next_phase"})
	await _wait(1.0)
	_check("J11 Sacrifice Unit disabled in the Battle Phase", _ctl_btn(0).disabled, _ctl_btn(0).tooltip_text)
	await _move(_ctl_btn(0).get_global_rect().get_center())
	await _wait(1.3)
	await _shot("11_sacrifice_disabled_battle")
	# J6: the opponent (prompts on) holds only a face-down Spell: no Trap can respond, so not asked
	# (owner, 22 Oct: prompts on ask only when a Trap can respond).
	host.handle(o, {"t": "trap_prompts", "mode": "eligible"})
	host.handle(a, {"t": "attack", "uid": uids["fire"]})
	if m.pending.get("kind", "") == "attack_target":
		_answer(a, m.name_of(uids["o_unit"]))
	await _wait(0.6)
	_check("J6 prompts on: no prompt without a usable Trap", not (m.pending.get("kind", "") == "trap_response" and int(m.pending.get("player", -1)) == o), str(m.pending.get("kind", "")))
	await _shot("12_no_prompt_without_usable_trap")
	# Skip this window and any later one of the same attack (the battle's destructions open more).
	var guard := 0
	while m.pending.get("kind", "") == "trap_response" and guard < 6:
		_answer(int(m.pending["player"]), "Skip")
		guard += 1
		await _wait(1.2)
	_view_seat(a)
	await _wait(1.5)
	# J6 / J11: a full hand keeps clear of the controls.
	for i in 6:
		_new(a, 1, "hand")
	host.broadcast()
	await _wait(1.0)
	var r2 := _controls().get_global_rect()
	var clear2 := true
	for uid in gs.hand.order:
		if (gs.hand.items[uid]["holder"] as Control).get_global_rect().position.x <= r2.end.x:
			clear2 = false
	_check("J6/J11 full hand clear of the controls", clear2, "%d cards" % gs.hand.order.size())
	await _move(Vector2(700, 470))
	await _wait(0.3)
	await _shot("13_full_hand")
	for sz in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(sz)
		await _wait(1.0)
		await _shot("14_controls_%dx%d" % [sz.x, sz.y])
	DisplayServer.window_set_size(Vector2i(1600, 1000))


func _finish_controls() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("duel_controls_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("DUEL CONTROLS DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
