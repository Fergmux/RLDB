extends Node
## Development-only visual verification driver. Launched with
##   godot --path rldb -- --shots=<absolute dir> [--no-steam]
## It plays a scripted local series through the real UI and saves screenshots of the
## board, details, target selection, trap response prompt, pile inspection, log,
## rewards, first-player choice and series end.

var main: Node
var out_dir: String
var host: LocalHost


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	main._privacy = false
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(6)
	host = main.local_host
	await _shot("01_deck_select")
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	var m: MatchEngine = host.series.game
	_stage_board(m)
	host.broadcast()
	await _frames(4)
	_view_seat(m.active)
	await _shot("02_board")
	# I-02: hover actions on a hand card and on a field card (hover API; no mouse needed).
	var hs: GameScreen = main.screen
	hs.debug_hover_hand(0)
	await _frames(25)
	await _shot("02b_hover_hand_card")
	hs.debug_hover_hand(2)
	await _frames(25)
	await _shot("02b2_hover_hand_spell")
	hs.debug_hover_slot(m.active, "unit", 0)
	await _frames(25)
	await _shot("02c_hover_field_card")
	hs.debug_clear_hover()
	await _frames(5)
	# Details for a unit with statuses and an aura-modified stat.
	var screen: GameScreen = main.screen
	screen.selected_uid = m.players[m.active]["units"][1]
	screen._render_all()
	await _shot("03_card_details")
	# Summon flow: zone selection prompt.
	var hand_unit := -1
	for u in m.players[m.active]["hand"]:
		if m.is_unit(u) and m.validate(m.active, {"t": "summon", "uid": u}) == "":
			hand_unit = u
			break
	if hand_unit != -1:
		screen.selected_uid = hand_unit
		host.handle(m.active, {"t": "summon", "uid": hand_unit})
		await _frames(3)
		await _shot("04_summon_zone_prompt")
		host.handle(m.active, {"t": "cancel", "id": m.pending["id"]})
	# Go to battle and declare an attack into the trapped column.
	var attacker_side := m.active
	host.handle(attacker_side, {"t": "next_phase"})
	await _frames(3)
	var attacker: int = m.players[attacker_side]["units"][0]
	host.handle(attacker_side, {"t": "attack", "uid": attacker})
	await _frames(3)
	await _shot("05_attack_target_selection")
	var target_opt := -1
	for o in m.pending["options"]:
		if o["v"] == m.players[1 - attacker_side]["units"][0]:
			target_opt = m.pending["options"].find(o)
	host.handle(attacker_side, {"t": "choose", "id": m.pending["id"], "indices": [maxi(target_opt, 0)]})
	await get_tree().create_timer(0.17).timeout
	await _shot("05b_attack_animation_in_progress")
	await get_tree().create_timer(1.2).timeout
	await _frames(3)
	if not m.pending.is_empty() and m.pending["kind"] == "trap_response":
		_view_seat(m.pending["player"])
		await _frames(3)
		await _shot("06_trap_response_prompt")
		_view_seat(attacker_side)
		await _frames(3)
		await _shot("06b_attacker_waiting_on_trap")
		host.handle(1 - attacker_side, {"t": "choose", "id": m.pending["id"], "indices": [1]})
		await _frames(3)
	_view_seat(attacker_side)
	await _frames(3)
	await _shot("07_after_battle_log")
	screen._show_pile("draw")
	await _frames(3)
	await _shot("08_draw_inspection")
	screen.pile_popup.visible = false
	# Finish game 1 by concession, then rewards and first-player choice.
	host.handle(1 - attacker_side, {"t": "concede"})
	_view_seat(0)
	await _frames(4)
	await _shot("09_rewards")
	host.handle(0, {"t": "reward_add", "index": 0})
	host.handle(0, {"t": "reward_basic", "from_id": 112, "to_type": "Lightning"})
	await _frames(3)
	await _shot("10_rewards_in_progress")
	host.handle(0, {"t": "reward_finish"})
	host.handle(1, {"t": "reward_finish"})
	var loser: int = host.series.last_loser
	_view_seat(loser)
	await _frames(4)
	await _shot("11_loser_chooses_first_player")
	host.handle(loser, {"t": "first_player", "who": loser})
	await _frames(3)
	_view_seat(host.series.game.active)
	await _frames(3)
	await _shot("12_game_two_start")
	host.handle(host.series.game.active, {"t": "concede_series"})
	if host.series.stage != Series.STAGE_OVER:
		host.handle(0, {"t": "reward_finish"})
		host.handle(1, {"t": "reward_finish"})
		host.handle(host.series.last_loser, {"t": "first_player", "who": 0})
		host.handle(host.series.game.active, {"t": "concede_series"})
	_view_seat(0)
	await _frames(4)
	await _shot("13_series_over")
	print("SHOTS DONE: ", out_dir)
	get_tree().quit()


func _view_seat(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


## Arranges a readable mid-game board for screenshots (dev only).
func _stage_board(m: MatchEngine) -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	var a := m.active
	var o := 1 - a
	_put(m, a, 36, 0, "atk")         # Dante
	_put(m, a, 34, 1, "def")         # Dragon of the Cave (adjacent +6 DEF aura)
	_put(m, a, 112, 4, "atk")        # Basic Warrior (Fire)
	_put(m, o, 70, 0, "def")         # Krakeshin
	_put(m, o, 162, 2, "atk")        # Diggie
	_put(m, o, 29, 3, "atk")         # The Sweeper (protected)
	m.apply_status(m.players[a]["units"][0], "burn", 2)
	m.apply_status(m.players[a]["units"][1], "eternal", 1)
	m.apply_status(m.players[o]["units"][0], "nimble", 2)
	m.apply_status(m.players[o]["units"][0], "rune", 1)
	m.apply_status(m.players[o]["units"][2], "poison", 3)
	var trap := m._create_instance(51, o)                # Rushed Recklessly set in column 1
	m.cards[trap]["zone"] = "backrow"
	m.cards[trap]["slot"] = 0
	m.cards[trap]["ctl"] = o
	m.cards[trap]["set_turn"] = m.turn - 1
	m.players[o]["backrow"][0] = trap
	var pw := m._create_instance(54, o)
	m.cards[pw]["zone"] = "power"
	m.cards[pw]["slot"] = 0
	m.cards[pw]["face_up"] = true
	m.players[o]["powers"][0] = pw
	m.add_log("[dev] Board arranged for screenshots.")


func _put(m: MatchEngine, p: int, id: int, slot: int, stance: String) -> void:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, stance)
	m.cards[uid]["summoned_turn"] = m.turn - 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)
