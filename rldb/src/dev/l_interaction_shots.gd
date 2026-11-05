extends "res://src/dev/f02_driver.gd"
## Development-only windowed verification of the L batch interaction items (owner feedback
## 2026-11-05: L5 sacrifice mode, L6 the prompt's Cancel button, L7 the targeting arrow hiding on a
## pick, L16 the opponent-is-responding notice, L21 one selection at a time). Launched with
##   godot --path rldb -- --linteract-shots=<absolute dir>
## Plays a hot-seat match through the real UI with pointer and key events (the F02 driver's helpers),
## seen from the active player's screen (pinned, as online). Runs on a build before the batch too
## (the sacrifice-mode steps then show the old pick-and-confirm flow). Writes JPG screenshots (q88)
## and `l_interaction_report.json`, then quits. The cursor gallery is src/dev/l_cursor_gallery.gd.

const PIERCE_UNIT := 15
const ASSASSINATE := 84
const DAMAGE_CONVERSION := 47

## True on a build with the L5 sacrifice mode (GameScreen.sacrifice).
var after := false


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
	after = gs.get("sacrifice") != null
	_stage_l()
	host.broadcast()
	_view_seat(a)
	await _wait(4.0)          # past the coin flip and the deal
	await _l_steps()
	_finish_l()


func _set_card(p: int, id: int, col: int) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "backrow"
	m.cards[uid]["slot"] = col
	m.cards[uid]["ctl"] = p
	m.cards[uid]["set_turn"] = m.turn - 1
	m.players[p]["backrow"][col] = uid
	return uid


func _stage_l() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})      # turn 2, Setup Phase, the other player active
	a = m.active
	o = 1 - a
	uids["water"] = _put(a, 1, 0, "atk")                 # Basic Mage (Water)
	uids["fire"] = _put(a, 110, 1, "atk", 14)            # Basic Mage (Fire), the attacker later
	uids["fresh"] = _put(a, 1, 2, "atk")                 # summoned this turn: cannot be sacrificed
	m.cards[uids["fresh"]]["summoned_turn"] = m.turn
	uids["pierce"] = _put(a, PIERCE_UNIT, 4, "atk")      # ability: Apply 1 Pierce to a unit
	uids["spare"] = _put(a, 1, 3, "def")
	uids["h_assassinate"] = _new(a, ASSASSINATE, "hand")
	uids["h_water"] = _new(a, 1, "hand")
	for i in 2:
		_new(a, 1, "spent")
	uids["o_unit"] = _put(o, 1, 1, "atk")
	uids["o_unit2"] = _put(o, 110, 0, "atk", 9)
	uids["conv"] = _set_card(o, DAMAGE_CONVERSION, 1)
	m.players[a]["ap"] = 6
	m.add_log("[dev] Board arranged for the L batch interaction verification run.")


## Keeps this screen on the seat it shows for `sec` seconds (hot-seat hands the screen over).
func _pin(sec: float) -> void:
	gs.fx_hold_until = maxi(gs.fx_hold_until, Time.get_ticks_msec() + int(sec * 1000.0))


func _sac_btn() -> Button:
	return gs.board.controls.sacrifice_btn


func _rest() -> void:
	await _move(Vector2(1000, 470))
	await _wait(0.3)


func _l_steps() -> void:
	await _rest()
	await _shot("01_board")
	await _sacrifice_steps()
	await _cancel_steps()
	await _pile_steps()
	await _arrow_steps()
	await _responding_steps()


# ---------------------------------------------------------------- L5 sacrifice mode

func _sacrifice_steps() -> void:
	var ap0: int = int(m.players[a]["ap"])
	await _click(_sac_btn().get_global_rect().get_center())
	await _wait(0.6)
	await _move(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.6)
	await _shot("02_sacrifice_engaged")
	if not after:
		# The old flow: pick, then a confirmation.
		await _click(_slot_rect(a, "unit", 0).get_center())
		await _wait(0.5)
		await _rest()
		await _shot("03_sacrifice_confirm_popup")
		var yes := _find_button(gs.prompt.ctx_banner, "Sacrifice")
		if yes != null:
			await _click(yes.get_global_rect().get_center())
		await _wait(1.6)
		return
	_check("L5 sacrifice mode on", gs.sacrifice.active)
	_check("L5 button lit", _sac_btn().get("latched") == true)
	_check("L5 nothing pending (no pick prompt)", m.pending.is_empty())
	await _click(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.25)
	await _shot("03_sacrifice_first_unit_burning")
	_check("L5 sacrificed at once, no confirmation", m.cards[uids["water"]]["zone"] == "spent" and m.pending.is_empty(),
		"zone %s pending %s" % [m.cards[uids["water"]]["zone"], m.pending.get("kind", "")])
	_check("L5 +1 AP", int(m.players[a]["ap"]) == ap0 + 1, "%d -> %d" % [ap0, int(m.players[a]["ap"])])
	await _wait(1.4)
	_check("L5 mode stays on after a sacrifice", gs.sacrifice.active)
	await _move(_slot_rect(a, "unit", 2).get_center())   # the fresh unit: not sacrificable
	await _wait(0.5)
	await _shot("04_sacrifice_mode_still_on")
	await _click(_slot_rect(a, "unit", 2).get_center())
	await _wait(0.4)
	_check("L5 a unit summoned this turn is not sacrificed", m.cards[uids["fresh"]]["zone"] == "unit")
	await _shot("05_sacrifice_refused_fresh_unit")
	# A hand card or the opponent's unit does nothing in the mode either.
	await _click(_slot_rect(o, "unit", 1).get_center())
	await _wait(0.3)
	_check("L5 the opponent's unit is not touched", m.cards[uids["o_unit"]]["zone"] == "unit" and gs.sacrifice.active)
	await _click(_sac_btn().get_global_rect().get_center())
	await _wait(0.5)
	_check("L5 the button again ends the mode", not gs.sacrifice.active)
	await _click(_slot_rect(a, "unit", 1).get_center())
	await _wait(0.4)
	_check("L5 outside the mode a click selects (no sacrifice)", m.cards[uids["fire"]]["zone"] == "unit" and gs.selected_uid == uids["fire"])
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	# Esc ends it too.
	await _click(_sac_btn().get_global_rect().get_center())
	await _wait(0.4)
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	_check("L5 Esc ends the mode", not gs.sacrifice.active)
	await _rest()
	await _shot("06_sacrifice_mode_off")


# ---------------------------------------------------------------- L6 Cancel

func _cancel_steps() -> void:
	await _click(_slot_rect(a, "unit", 4).get_center())
	await _wait(0.4)
	var labs := _row_labels()
	var ab := ""
	for t in labs:
		if String(t).begins_with("Apply"):
			ab = String(t)
	await _click_row(ab)
	await _wait(0.6)
	await _rest()
	await _shot("07_prompt_cancel")
	var btn := _find_named(gs.prompt.ctx_banner, "CancelButton")
	_check("L6 Cancel is a real button", btn != null and btn is Button and btn.is_visible_in_tree())
	if btn != null:
		await _move(btn.get_global_rect().get_center())
		await _wait(0.5)
		await _shot("08_prompt_cancel_hover")
		await _click(btn.get_global_rect().get_center())
		await _wait(0.4)
		_check("L6 Cancel cancels", m.pending.is_empty())
	else:
		await _key(KEY_ESCAPE)
		await _wait(0.4)


func _find_named(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for ch in n.get_children():
		var f := _find_named(ch, nm)
		if f != null:
			return f
	return null


# ---------------------------------------------------------------- L21 one selection

func _pile_steps() -> void:
	await _click(_slot_rect(a, "unit", 1).get_center())
	await _wait(0.4)
	var ps: Control = gs.board.piles[1]["spent"]
	await _click(ps.get_global_rect().get_center())
	await _wait(0.5)
	await _rest()
	await _shot("09_pile_after_field_select")
	_check("L21 the field card is deselected when a pile opens", gs.selected_uid == -1 and gs.details.pile_zone == "spent",
		"sel %d pile %s" % [gs.selected_uid, gs.details.pile_zone])
	await _click(ps.get_global_rect().get_center())
	await _wait(0.3)


# ---------------------------------------------------------------- L7 arrow

func _hand_rect(uid: int) -> Rect2:
	return (gs.hand.items[uid]["holder"] as Control).get_global_rect()


func _arrow_steps() -> void:
	await _click(_hand_rect(uids["h_assassinate"]).get_center())
	await _wait(0.5)
	await _click_row("Cast")
	await _wait(0.8)
	_pin(6.0)
	var tgt := _slot_rect(o, "unit", 1).get_center()
	await _move(tgt)
	await _wait(0.5)
	await _shot("10_arrow_aiming")
	_check("L7 arrow shown while aiming", gs.arrow.on)
	await _click(tgt)
	await _shot("11_arrow_frame_after_pick")
	_check("L7 arrow hidden the moment the target is picked", not gs.arrow.on)
	await _wait(0.25)
	await _shot("12_arrow_during_spotlight")
	_check("L7 arrow stays hidden during the animation", not gs.arrow.on)
	await _wait(2.5)


# ---------------------------------------------------------------- L16 responding

func _responding_steps() -> void:
	_view_seat(a)
	await _wait(0.6)
	host.handle(a, {"t": "next_phase"})       # Battle Phase
	await _wait(1.2)
	_pin(8.0)
	host.handle(a, {"t": "attack", "uid": uids["fire"]})
	if m.pending.get("kind", "") == "attack_target":
		_answer(a, m.name_of(uids["o_unit"]))
	await _rest()
	await _wait(0.5)
	_check("L16 the defender is asked", m.pending.get("kind", "") == "trap_response" and int(m.pending.get("player", -1)) == o, str(m.pending.get("kind", "")))
	await _shot("13_responding_appears")
	var wn: Control = gs.prompt.wait_chip
	_check("L16 notice visible", wn.visible and wn.modulate.a > 0.3)
	await _wait(3.2)
	await _shot("14_responding_settled")
	_answer(o, "Skip")
	await _wait(0.8)
	await _shot("15_responding_cleared")
	_check("L16 notice clears", not wn.visible or wn.modulate.a < 0.05, "vis %s a %.2f" % [wn.visible, wn.modulate.a])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)


func _finish_l() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("l_interaction_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("L INTERACTION DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
