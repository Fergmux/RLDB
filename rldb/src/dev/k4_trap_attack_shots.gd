extends "res://src/dev/f02_driver.gd"
## Development-only windowed verification of the 23 Oct FX batch (K1, K4). Launched with
##   godot --path rldb -- --k4-shots=<absolute dir>
## Plays a hot-seat match through the real UI: attacks into a defender's Trap window, seen from the
## attacker's screen (pinned, as online) and the defender's. K4: the attack does not lunge while the Trap
## prompt is open (a declaring cue only); after Skip the strike plays, and the hand-over back to the
## attacker waits for it; after "Skip for the rest of this turn" the next attack strikes at once; a Trap
## that destroys the attacker (Mirror Force) leaves no strike at all. K1: each Spell / Trap spotlight asks
## for its cue once (recorded; sound muted in memory only) and stays on screen through the hand-over.
## Writes JPG screenshots (q88) and `k4_report.json`, then quits.

const DAMAGE_CONVERSION := 47
const MIRROR_FORCE := 46
const SPELL := 41
const STRIKES := ["attack", "direct", "lethal"]

var cues: Array = []


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
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})      # turn 2, the other player active
	a = m.active
	o = 1 - a
	uids["fire"] = _put(a, 110, 1, "atk", 14)
	uids["water"] = _put(a, 1, 0, "atk", 12)
	uids["earth"] = _put(a, 120, 2, "atk", 12)
	uids["wall"] = _put(o, 1, 1, "def")
	m.cards[uids["wall"]]["base_def"] = 16
	uids["conv"] = _set_card(o, DAMAGE_CONVERSION, 1)
	m.add_log("[dev] Board arranged for the K4 Trap-window attack verification run.")
	m.submit(a, {"t": "next_phase"})   # Battle Phase
	m.players[a]["ap"] = 6


func _set_card(p: int, id: int, col: int) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "backrow"
	m.cards[uid]["slot"] = col
	m.cards[uid]["ctl"] = p
	m.cards[uid]["set_turn"] = m.turn - 1
	m.players[p]["backrow"][col] = uid
	return uid


func _hook_cues() -> void:
	gs.fx._spotlight.play_sfx = func(n: String, db: float) -> void:
		cues.append(n)
		Sfx.play(n, db, 0.0)


func _strikes() -> int:
	return gs.fx.last_plan.filter(func(s): return String(s["tag"]) in STRIKES).size()


func _tags() -> Array:
	return gs.fx.last_plan.map(func(s): return String(s["tag"]))


func _declare(uid_key: String) -> void:
	host.handle(a, {"t": "attack", "uid": uids[uid_key]})
	if m.pending.get("kind", "") == "attack_target":
		_answer(a, m.name_of(uids["wall"]))


## Keeps this screen on the seat it shows for `sec` seconds: hot-seat play hands the screen to whoever
## must act next (SessionLauncher._check_hotseat), and waits while GameScreen.fx_hold_until is ahead.
## Pinning stands in for the attacker's own screen online, where nothing hands over.
func _pin(sec: float) -> void:
	gs.fx_hold_until = maxi(gs.fx_hold_until, Time.get_ticks_msec() + int(sec * 1000.0))


func _steps() -> void:
	_hook_cues()
	await _move(Vector2(700, 470))
	await _shot("00_board_battle_phase")
	# 1. The attacker's screen: the declaration opens the defender's Trap window; no strike yet.
	_pin(1.5)
	_declare("fire")
	await _wait(0.15)
	await _shot("01_attacker_declaring_cue")
	_check("K4 Trap window open for the defender", m.pending.get("kind", "") == "trap_response" and int(m.pending["player"]) == o, str(m.pending.get("kind", "")))
	_check("K4 attacker's screen: no strike while the prompt is open", main._shown_seat == a and _strikes() == 0 and _tags().has("declare"), "seat %d %s" % [main._shown_seat, _tags()])
	await _wait(1.0)
	var w := _w_slot(a, "unit", 1)
	_check("K4 attacker rests in its slot while waiting", w != null and w.fx_offset == Vector2.ZERO, str(w.fx_offset if w != null else "none"))
	await _shot("02_attacker_waiting_for_trap")
	# 2. The defender's screen: the prompt, then Skip; the strike plays there, and the hot-seat hand-over
	# back to the attacker waits for it.
	_view_seat(o)
	await _wait(0.8)
	await _shot("03_defender_trap_prompt")
	_answer(o, "Skip")
	await _wait(0.2)
	await _shot("04_defender_strike_after_skip")
	_check("K4 defender's screen: the strike plays after Skip", main._shown_seat == o and _strikes() == 1, "seat %d %s" % [main._shown_seat, _tags()])
	await _wait(2.0)
	_check("K4 hot seat: the screen goes back to the attacker once the strike has played", main._shown_seat == a, "seat %d" % main._shown_seat)
	# 3. "Skip for the rest of this turn": the strike plays when the window closes, and the next attack
	# strikes at once.
	_declare("water")
	await _wait(0.4)
	_check("K4 second window open", m.pending.get("kind", "") == "trap_response", str(m.pending.get("kind", "")))
	_check("K4 hot seat: the defender's prompt is on screen", main._shown_seat == o, "seat %d" % main._shown_seat)
	_answer(o, "Skip for the rest of this turn")
	await _wait(0.2)
	_check("K4 the strike plays when the window closes", _strikes() == 1, str(_tags()))
	await _shot("05_defender_strike_after_skip_rest")
	await _wait(2.0)
	_declare("earth")
	await _wait(0.2)
	_check("K4 no window after Skip for the rest of the turn", m.pending.is_empty(), str(m.pending.get("kind", "")))
	_check("K4 that attack strikes at once, no declaring cue", main._shown_seat == a and _strikes() == 1 and not _tags().has("declare"), "seat %d %s" % [main._shown_seat, _tags()])
	await _shot("06_attacker_strike_no_window")
	await _wait(1.6)
	# 4. A Trap that destroys the attacker: the next turn's attack into Mirror Force.
	await _restage_mirror_force()
	_pin(0.7)
	_declare("fire2")
	await _wait(0.4)
	_check("K4 Mirror Force window open", m.pending.get("kind", "") == "trap_response", str(m.pending.get("kind", "")))
	_check("K4 no strike before Mirror Force", _strikes() == 0, str(_tags()))
	await _shot("07_attacker_waiting_mirror_force")
	_view_seat(o)
	await _wait(0.6)
	var n0 := cues.size()
	_answer(o, "Activate")
	await _wait(0.6)
	_check("K1 the Trap spotlight stays on screen through the hot-seat hand-over", main._shown_seat == o and gs.fx._spotlight.is_active(), "seat %d %s" % [main._shown_seat, _tags()])
	await _shot("08_defender_trap_spotlight")
	var guard := 0
	while m.pending.get("kind", "") == "trap_response" and guard < 6:
		_answer(int(m.pending["player"]), "Skip")
		guard += 1
		await _wait(0.4)
	await _wait(1.4)   # the spotlight has gone; the four destructions play
	await _shot("09_mirror_force_destroys")
	await _wait(2.4)
	_check("K4 Mirror Force destroyed the attacker", String(m.cards[uids["fire2"]]["zone"]) != "unit", String(m.cards[uids["fire2"]]["zone"]))
	_check("K4 no strike after the Trap stopped the attack", not gs.fx.last_plan.any(func(s): return String(s["tag"]) in STRIKES), str(_tags()))
	_check("K1 the Trap spotlight asked for its snap once", cues.slice(n0) == ["trap_spring"], str(cues.slice(n0)))
	await _shot("10_attacker_after_mirror_force")
	# 5. K1: a Spell cast from the hand: its spotlight and its one arcane cue.
	_view_seat(a)
	host.handle(a, {"t": "next_phase"})   # Main Phase 2: Spells can be cast
	_check("K1 the attacker is in Main Phase 2", m.active == a and m.phase == "main2", "%d %s" % [m.active, m.phase])
	await _wait(0.8)
	var sp := _new(a, SPELL, "hand")
	m.players[a]["ap"] = 10
	host.broadcast()
	await _wait(0.8)
	var n1 := cues.size()
	host.handle(a, {"t": "cast", "uid": sp})
	await _wait(0.4)
	# Delayed Gratification picks its card in the Hand first; the Spell is shown once the cast commits.
	if m.pending.get("kind", "") != "" and m.pending.get("kind", "") != "trap_response":
		_answer(a, String(m.pending["options"][0]["label"]))
	await _wait(0.55)
	await _shot("11_spell_spotlight")
	await _wait(2.0)
	while not m.pending.is_empty() and guard < 12:
		_answer(int(m.pending["player"]), "Skip" if m.pending.get("kind", "") == "trap_response" else String(m.pending["options"][0]["label"]))
		guard += 1
		await _wait(0.5)
	_check("K1 the Spell spotlight asked for its cast cue once", cues.slice(n1) == ["spell_cast"], str(cues.slice(n1)))
	await _shot("12_after_spell")


## Ends the turn, then makes it the attacker's next turn with four attacking-side field cards (Mirror
## Force's condition) and a fresh attacker.
func _restage_mirror_force() -> void:
	# "Skip for the rest of this turn" holds until this turn ends: go on to the attacker's next turn.
	var next_turn := m.turn + 2
	var g := 0
	while (m.turn < next_turn or m.active != a or m.phase != "battle") and g < 30:
		if not m.pending.is_empty():
			_answer(int(m.pending["player"]), "Skip" if m.pending.get("kind", "") == "trap_response" else String(m.pending["options"][0]["label"]))
		else:
			host.handle(m.active, {"t": "next_phase"})
		g += 1
		await _wait(0.3)
	_check("K4 restaged on the attacker's next Battle Phase", m.turn == next_turn and m.active == a and m.phase == "battle", "turn %d active %d %s" % [m.turn, m.active, m.phase])
	uids["fire2"] = _put(a, 110, 3, "atk", 14)
	for k in ["water", "earth", "fire"]:
		if String(m.cards[uids[k]]["zone"]) == "unit":
			m.cards[uids[k]]["stance"] = "atk"
	if String(m.cards[uids["conv"]]["zone"]) == "backrow":
		m.move_to_pile(uids["conv"], "spent")   # only Mirror Force can answer this attack
	uids["mirror"] = _set_card(o, MIRROR_FORCE, 2)
	host.broadcast()
	_view_seat(a)
	await _wait(1.5)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("k4_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("K4 DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
