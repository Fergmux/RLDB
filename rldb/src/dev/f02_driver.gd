extends Node
## Development-only interactive verification of playtest feedback 02. Launched with
##   godot --path rldb -- --f02-shots=<absolute dir>
## Plays a local match through the real UI using pointer and keyboard events pushed into the
## viewport (no debug hover hooks), asserts the observable behaviour of F02-01..F02-15 from
## both seats, writes screenshots and `f02_report.json` into the directory, then quits.

var main: Node
var out_dir: String
var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var a: int
var o: int
var checks: Array = []
var uids: Dictionary = {}


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	Sfx.set_muted(false)
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
	await _wait(0.5)
	var coin := gs.get_children().filter(func(n): return n is CoinFlip)
	_check("FB4-09 game 1 starts with a coin flip", not coin.is_empty())
	await _shot("00_coin_flip")
	await _wait(3.4)
	await _steps()
	_finish()


# ---------------------------------------------------------------- staging

func _new(p: int, id: int, zone: String) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = zone
	m.players[p][zone].append(uid)
	return uid


func _put(p: int, id: int, slot: int, stance: String, atk = null) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, stance)
	m.cards[uid]["summoned_turn"] = m.turn - 1
	if atk != null:
		m.cards[uid]["base_atk"] = atk
	return uid


func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})      # turn 2, Main 1, the other player active
	a = m.active
	o = 1 - a
	uids["water"] = _put(a, 1, 0, "atk")              # Basic Mage (Water) 8
	uids["fire"] = _put(a, 110, 1, "atk", 10)          # Basic Mage (Fire) 10
	uids["pierce"] = _put(a, 15, 4, "atk")             # ability: Apply 1 Pierce to a unit
	uids["h_water"] = _new(a, 1, "hand")
	uids["h_anduras"] = _new(a, 99, "hand")            # On Summon: move a unit from Spent to Draw
	uids["h_loak"] = _new(a, 19, "hand")               # On Summon: opponent unit in this column
	for i in 3:
		uids["spent%d" % i] = _new(a, 1, "spent")
	uids["tyde"] = _new(a, 172, "extra")               # Arcane, cost 2
	uids["o_fire"] = _put(o, 110, 0, "atk", 10)
	uids["o_water"] = _put(o, 1, 1, "def")
	var trap := m._create_instance(46, o)              # Mirror Force, face-down in column 3
	m.cards[trap]["zone"] = "backrow"
	m.cards[trap]["slot"] = 2
	m.cards[trap]["ctl"] = o
	m.cards[trap]["set_turn"] = m.turn - 1
	m.players[o]["backrow"][2] = trap
	uids["o_trap"] = trap
	m.add_log("[dev] Board arranged for the F02 verification run.")


# ---------------------------------------------------------------- the run

func _steps() -> void:
	# F02-03 / F02-06 / F02-11 at rest.
	await _shot("01_board_start")
	_check_proportions("F02-03 proportions at start")
	var pv: Dictionary = gs.view["match"]["players"][a]
	_check("F02-06 two-AP start shows two slots", PlayerPlate.ApGems.capacity_for(int(pv["ap"]), int(pv["ap_start"]), int(pv["ap_peak"])) == 2,
		"ap %s start %s peak %s" % [pv["ap"], pv["ap_start"], pv["ap_peak"]])
	_check("F02-11 hand unit highlighted as ready", _w_hand(uids["h_water"]).is_ready_on())
	_check("F02-11 Defense unit not advertised in Main 1", not _w_slot(o, "unit", 1).is_ready_on())
	_check("F02-01 face-down opponent card shows no details", true)
	# F02-01 hover is inspection only and read-only.
	var sig0 := _state_sig()
	await _move(_hand_rect(uids["h_water"]).get_center())
	await _wait(0.5)
	_check("F02-01 hover shows details", gs.details.details_uid() == uids["h_water"], "details uid %d" % gs.details.details_uid())
	_check("F02-01 hover shows no action buttons", gs.action_row.stack == null)
	await _shot("02_hover_hand_details_no_actions")
	await _move(_slot_rect(a, "unit", 4).get_center())
	await _wait(0.4)
	_check("F02-01 hover field card: details, no actions", gs.details.details_uid() == uids["pierce"] and gs.action_row.stack == null)
	await _move(_slot_rect(o, "backrow", 2).get_center())
	await _wait(0.4)
	_check("F02-01 hidden card never inspected", gs.details.details_uid() != uids["o_trap"] and gs.hover.hv.is_empty())
	await _hover_sweep()
	_check("F02-01 hover sweep changed no state and sent nothing", _state_sig() == sig0)
	# F02-01 click-select and F02-02 summon buttons.
	await _click(_hand_rect(uids["h_water"]).get_center())
	await _wait(0.4)
	_check("F02-01 click selects", gs.selected_uid == uids["h_water"])
	_check("F02-02 Summon Attack + Summon Defense on the card", _row_labels() == ["Summon Attack", "Summon Defense"], str(_row_labels()))
	await _shot("03_click_selected_summon_actions")
	await _click(_hand_rect(uids["h_anduras"]).get_center())
	await _wait(0.4)
	_check("F02-01 changing selection updates the row", gs.selected_uid == uids["h_anduras"] and _row_labels().has("Summon Defense"))
	await _click(_hand_rect(uids["h_water"]).get_center())
	await _wait(0.3)
	var ap_before: int = m.players[a]["ap"]
	await _click_row("Summon Defense")
	await _wait(0.4)
	_check("F02-02 summon goes straight to zone choice (no stance menu)", m.pending.get("kind", "") == "slot")
	_check("F02-07 banner explains the choice", gs.prompt.ctx_banner.visible and gs.prompt.banner_title.text.contains("zone"), gs.prompt.banner_title.text)
	_check("F02-07 no sidebar list of zones", not ("prompt_box" in gs))
	await _shot("04_summon_zone_banner")
	await _click(_zone_rect(a, "unit", 3).get_center())
	await _wait(0.8)
	_check("F02-02 unit entered Defense", m.cards[uids["h_water"]]["zone"] == "unit" and m.cards[uids["h_water"]]["stance"] == "def")
	_check("F02-02 cost paid once", m.players[a]["ap"] == ap_before - m.current_cost(uids["h_water"]), "ap %d -> %d" % [ap_before, m.players[a]["ap"]])
	var dw := _w_slot(a, "unit", 3)
	_check("F02-03 Defense card rotated 3:2", dw.rotated and dw.size.x > dw.size.y, str(dw.size))
	pv = gs.view["match"]["players"][a]
	_check("F02-06 spend one: 1 filled + 1 spent of 2", PlayerPlate.ApGems.capacity_for(int(pv["ap"]), int(pv["ap_start"]), int(pv["ap_peak"])) == 2 and int(pv["ap"]) == 1)
	await _shot("05_defense_rotated_ap_spent")
	# Extra AP above the allowance (display expands, no cap).
	m.change_ap(a, 4, " (dev)")
	host.broadcast()
	await _wait(0.6)
	pv = gs.view["match"]["players"][a]
	_check("F02-06 AP above allowance expands slots", PlayerPlate.ApGems.capacity_for(int(pv["ap"]), int(pv["ap_start"]), int(pv["ap_peak"])) == 5, "ap %s peak %s" % [pv["ap"], pv["ap_peak"]])
	await _shot("05b_ap_above_allowance")
	# F02-04 short ability label + F02-07 direct board targeting.
	await _click(_slot_rect(a, "unit", 4).get_center())
	await _wait(0.4)
	_check("F02-04 ability button uses short label", _row_labels().has("Apply Pierce"), str(_row_labels()))
	_check("F02-04 full text in tooltip/details", _row_tooltip("Apply Pierce").contains("Apply 1 Pierce to a unit"))
	await _shot("06_field_selected_short_labels")
	await _click_row("Apply Pierce")
	await _wait(0.4)
	_check("F02-07 target banner names the effect", gs.prompt.ctx_banner.visible and m.pending.get("kind", "") == "select", gs.prompt.banner_title.text)
	await _shot("07_ability_target_banner")
	await _click(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.6)
	_check("F02-07 direct click applied Pierce", m.status_count(uids["water"], "pierce") == 1 and m.pending.is_empty())
	_check("F02-07 interaction state valid after completion", not gs.prompt.ctx_banner.visible)
	# F02-09 toast: Loak in column 3 (no opponent unit there).
	await _click(_hand_rect(uids["h_loak"]).get_center())
	await _wait(0.3)
	await _click_row("Summon Attack")
	await _wait(0.3)
	await _click(_zone_rect(a, "unit", 5).get_center())
	await _wait(0.5)
	_check("F02-09 toast explains missing target", gs.prompt.toast.text.contains("no legal target"), gs.prompt.toast.text)
	_check("F02-09 no fake choice / queue not stuck", m.pending.is_empty() and m.stack.is_empty())
	await _shot("08_no_target_toast")
	# F02-10 single pick from a pile tray (Anduras: unit from Spent to Draw).
	await _click(_hand_rect(uids["h_anduras"]).get_center())
	await _wait(0.3)
	await _click_row("Summon Attack")
	await _wait(0.3)
	await _click(_zone_rect(a, "unit", 2).get_center())
	await _wait(0.6)
	_check("F02-10 pile cards offered in the tray", gs.prompt.tray.visible and _tray_widgets().size() == 3, "tray %s n %d" % [gs.prompt.tray.visible, _tray_widgets().size()])
	_check("F02-10 no per-card Choose buttons", _tray_buttons() == 0)
	var tw0: CardWidget = _tray_widgets()[0]
	await _move(tw0.get_global_rect().get_center())
	await _wait(0.4)
	_check("F02-10 hovering a tray card shows its details", gs.details.details_uid() == int(tw0.view["uid"]))
	await _shot("09_pile_tray_single")
	var picked := int(tw0.view["uid"])
	await _click(tw0.get_global_rect().get_center())
	await _wait(0.6)
	_check("F02-10 clicking the card chose it", m.cards[picked]["zone"] == "draw" and m.pending.is_empty())
	# Sacrifice the Pierce unit to free a zone (also feeds Spent).
	await _click(_slot_rect(a, "unit", 4).get_center())
	await _wait(0.3)
	await _click_row("Sacrifice")
	await _wait(0.6)
	# Extra Deck: click-to-act inside the pile popup, then an ordered multi tray.
	_check("Extra pile stack shows the summon-ready ring", (gs.board.piles[1]["extra"] as PileStack).ready_mark)
	await _click((gs.board.piles[1]["extra"] as Control).get_global_rect().get_center())
	await _wait(0.4)
	_check("FB5-10 pile opens as a list in the details panel", gs.details.pile_scroll.visible and not gs.overlays.pile_popup.visible and gs.details.details_title.text.contains("Extra"), gs.details.details_title.text)
	for row in _pile_cells():
		if int((row as Node).get_meta("uid", -1)) == uids["tyde"]:
			gs.details.pile_scroll.ensure_control_visible(row)
			await _wait(0.2)
			await _click((row as Control).get_global_rect().get_center())
			await _wait(0.4)
			break
	await _shot("10_extra_pile_click_to_act")
	# F04 (2026-10-17): every Extra Deck row now shows its own legal summons, so look in Tyde's row.
	var tyde_row := gs.details.pile_row(uids["tyde"])
	var arc_btn := _find_button(tyde_row, "Summon Defense") if tyde_row != null else null
	_check("F02-02 Extra Deck card offers Summon Attack/Defense after click", arc_btn != null)
	if arc_btn != null:
		await _click(arc_btn.get_global_rect().get_center())
		await _wait(0.5)
		var trays := _tray_widgets()
		_check("F02-10 multi selection tray", gs.prompt.tray.visible and trays.size() >= 2)
		if trays.size() >= 2:
			await _click((trays[1] as Control).get_global_rect().get_center())
			await _wait(0.3)
			await _click((_tray_widgets()[0] as Control).get_global_rect().get_center())
			await _wait(0.3)
			var order := _tray_widgets().map(func(w): return (w as CardWidget).order_no)
			_check("F02-10 multi keeps click order (badges 2,1)", order[0] == 2 and order[1] == 1, str(order))
			_check("F02-10 multi not committed before Confirm", m.pending.get("kind", "") == "select")
			await _shot("11_tray_ordered_multi")
			await _click(_banner_button("Confirm").get_global_rect().get_center())
			await _wait(0.5)
			if m.pending.get("kind", "") == "slot":
				await _click(_zone_rect(a, "unit", 4).get_center())
				await _wait(0.8)
			_check("F02-02 Arcane summon entered Defense", m.cards[uids["tyde"]]["zone"] == "unit" and m.cards[uids["tyde"]]["stance"] == "def")
	await _shot("12_after_arcane")
	# F02-12 combat preview.
	await _click(gs.sidebar.phase_btn.get_global_rect().get_center())
	await _wait(1.2)
	_check("phase advanced to Battle by the real button", m.phase == "battle")
	_check("F02-11 attack-ready unit highlighted in Battle", _w_slot(a, "unit", 0).is_ready_on())
	_check("F02-11 Defense unit not advertised as attacker", not _w_slot(a, "unit", 3).is_ready_on())
	await _click(_slot_rect(a, "unit", 0).get_center())
	await _wait(0.3)
	await _click_row("Attack")
	await _wait(0.4)
	var sig1 := _state_sig()
	await _move(_slot_rect(o, "unit", 0).get_center())
	await _wait(0.5)
	_check("F02-12 Water 8 vs Fire 10 previews 14 vs 10", _w_slot(a, "unit", 0).has_preview() and gs.preview.text.contains("14") and gs.preview.text.contains("10"), gs.preview.text)
	_check("F02-12 favourable = green arrow", gs.preview.verdict == "good" and gs.arrow.col == GameScreen.VERDICT_COLORS["good"])
	_check("F02-12 hidden trap caveat", gs.preview.text.contains("face-down"))
	await _shot("13_preview_favourable")
	await _move(_slot_rect(o, "unit", 1).get_center())
	await _wait(0.5)
	_check("F02-12 Defense tie previews stalemate (neutral)", gs.preview.verdict == "neutral" and gs.preview.text.contains("nothing destroyed"), gs.preview.text)
	await _shot("14_preview_stalemate_neutral")
	await _move(Vector2(gs.play_area.position.x + 30, gs.play_area.get_center().y))
	await _wait(0.4)
	_check("F02-12 preview restored on hover exit", gs.preview.ws.is_empty() and not _w_slot(a, "unit", 0).has_preview() and gs.preview.text == "")
	_check("F02-12 previews mutated nothing and sent nothing", _state_sig() == sig1)
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	_check("F02-12 cancel leaves the attack unused", m.pending.is_empty() and m.cards[uids["water"]]["attacked_turn"] != m.turn)
	# Unfavourable preview and a committed attack into a Trap window.
	await _click(_slot_rect(a, "unit", 1).get_center())
	await _wait(0.3)
	await _click_row("Attack")
	await _wait(0.4)
	await _move(_slot_rect(o, "unit", 1).get_center())
	await _wait(0.5)
	_check("F02-12 Fire 10 vs defending Water 8+6 = 14 is unfavourable/red", gs.preview.verdict == "bad" and gs.preview.text.contains("14"), gs.preview.text)
	await _shot("15_preview_unfavourable")
	await _click(_slot_rect(o, "unit", 1).get_center())
	await _wait(0.8)
	if m.pending.get("kind", "") == "trap_response":
		await _click(_slot_rect(a, "unit", 0).get_center())
		await _wait(0.3)
		_check("F02-01 response lock: own card shows no actions", gs.action_row.stack == null)
		# Hot-seat hands the screen to the responder at once; look from the waiting seat explicitly.
		_view_seat(a)
		await _wait(0.4)
		_check("FB4-22 opponent-is-responding notice in the middle of the board", gs.prompt.wait_chip.visible and gs.prompt.wait_label.text.contains("responding"), gs.prompt.wait_label.text)
		await _shot("16_waiting_on_opponent_response")
		_view_seat(o)
		await _wait(0.5)
		_check("trap response prompt is shown in the banner", gs.prompt.ctx_banner.visible and gs.pending()["mine"] and gs.prompt.banner_list.visible and gs.prompt.mention_box.visible)
		await _shot("17_opponent_response_prompt")
		var pass_i := -1
		var labels := []
		for i in m.pending["options"].size():
			labels.append(String(m.pending["options"][i]["label"]))
			if not labels[-1].begins_with("Activate"):
				pass_i = i
		_check("trap response offers a decline option", pass_i != -1, str(labels))
		host.handle(o, {"t": "choose", "id": m.pending["id"], "indices": [maxi(pass_i, 0)]})
		await _wait(0.4)
		_view_seat(a)
	await _wait(1.5)
	await _shot("18_after_battle")
	# Opponent perspective: hidden information and no action rows off-turn.
	_view_seat(o)
	await _wait(0.6)
	await _click(_slot_rect(o, "unit", 0).get_center())
	await _wait(0.3)
	_check("opponent seat: own card selectable for details but no actions off-turn", gs.selected_uid == uids["o_fire"] and gs.action_row.stack == null)
	await _shot("19_opponent_view")
	_view_seat(a)
	await _wait(0.5)
	# Keyboard: Tab selects the next ready card and opens its row; Esc clears.
	await _click(gs.sidebar.phase_btn.get_global_rect().get_center())
	await _wait(1.0)
	await _key(KEY_TAB)
	await _wait(0.3)
	_check("keyboard Tab selects a ready card with its row", gs.selected_uid != -1 and gs.action_row.stack != null, str(_row_labels()))
	await _shot("20_keyboard_tab_selection")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	_check("Esc deselects", gs.selected_uid == -1 and gs.action_row.stack == null)
	# F02-05 / F02-08 details at the supported sizes (a typical effect unit from the Hand).
	var typical: int = -1
	for uid in gs.hand.order:
		if m.is_unit(uid) and String(m.d(uid)["on_summon"]) != "":
			typical = uid
			break
	if typical == -1:   # the structure decks may deal no On Summon unit: any unit (or card) will do
		for uid in gs.hand.order:
			if typical == -1 or m.is_unit(uid):
				typical = uid
				if m.is_unit(uid):
					break
	if typical != -1:
		await _click(_hand_rect(typical).get_center())
		await _wait(0.4)
	_check("details show the selected card", gs.details.details_uid() == typical and typical != -1, str(typical))
	await _shot("21_details_1600x1000")
	var vb := gs.details.details_scroll.get_v_scroll_bar()
	_check("F02-05 typical unit details fit without scrolling at 1600x1000", vb.max_value - vb.page <= 4.0, "overflow %.0f px" % (vb.max_value - vb.page))
	for sz in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(sz)
		await _wait(0.6)
		_check_proportions("F02-03 proportions at %dx%d" % [sz.x, sz.y])
		await _shot("22_details_%dx%d" % [sz.x, sz.y])
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	await _wait(0.5)
	# F02-13 sounds actually started during the run.
	var heard := {}
	for n in Sfx.debug_played:
		heard[n] = true
	for want in ["select", "confirm", "cancel", "summon", "attack", "notice", "card_draw"]:
		_check("F02-13 sound played: %s" % want, heard.has(want), str(heard.keys()))
	await _fusion_zone_steps()


## FB4-15/16: a Fusion summon through Tag Team - S into the Dragon material's own zone. The zone is
## outlined as a whole (the card in it is not the target) and the prompts name the Fusion unit.
func _fusion_zone_steps() -> void:
	main._start_local({"seed": 77, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	var p := m.active
	var beast := _put(p, 4, 3, "atk")                    # Basic Beast (Water), back row column 1
	var dragon := _put(p, 2, 1, "atk")                   # Basic Dragon (Water), front row column 2
	var wyrm := _new(p, 93, "extra")
	var tt := _new(p, 8, "hand")                         # Tag Team - S
	m.players[p]["ap"] = 5
	host.broadcast()
	_view_seat(p)
	await _wait(3.6)                                     # let the game-start coin flip finish
	host.handle(p, {"t": "summon", "uid": tt, "stance": "atk"})
	_answer(p, "Front row, column 1")
	await _wait(0.3)
	_answer(p, "Yes")
	await _wait(0.3)
	_answer(p, m.name_of(wyrm))
	await _wait(0.6)
	# F04-22: each Field material is picked on the board (no tray), source still on the Field.
	_check("F04-22 Field materials picked on the board, source on the Field", gs.selection.board_targeting() and gs.selection.tray_options(gs.pending()).is_empty() and int(m.pending.get("source", -1)) == tt and m.cards[tt]["zone"] == "unit", str(m.pending.get("prompt", "")))
	await _shot("22_fusion_material_pick")
	await _click(_zone_rect(p, "unit", 3).get_center())
	await _wait(0.4)
	await _click(_zone_rect(p, "unit", 1).get_center())
	await _wait(0.6)
	_check("FB4-15 zone prompt names the Fusion unit", String(m.pending.get("prompt", "")).contains(m.name_of(wyrm)), String(m.pending.get("prompt", "")))
	var it: Dictionary = gs.fx_slot_item(p, "unit", 1)
	_check("FB4-16 occupied material zone outlined as a whole zone", (it["ring"] as ZoneRing).visible and not (it["widget"] as CardWidget).highlighted)
	await _shot("23_fusion_zone_pick")
	await _click(_zone_rect(p, "unit", 1).get_center())
	await _wait(0.4)
	_check("FB4-15 stance prompt names the Fusion unit", String(m.pending.get("prompt", "")) == "Choose a stance for %s." % m.name_of(wyrm), String(m.pending.get("prompt", "")))
	await _shot("24_fusion_stance_banner")
	_answer(p, "Defense")
	await _wait(0.6)
	# F07 (2026-10-17): the stance choice is the final, committing step; no Confirm prompt follows.
	_check("F07 stance commits the Fusion with no extra Confirm", m.pending.get("kind", "") != "confirm", str(m.pending.get("prompt", "")))
	_check("FB4-15 Fusion unit summoned into the material's zone", m.cards[wyrm]["zone"] == "unit" and m.cards[wyrm]["slot"] == 1 and m.cards[dragon]["zone"] != "unit" and m.cards[beast]["zone"] != "unit")
	await _shot("25_after_fusion")
	# FB4-21: end of turn sends the hand to Spent with an animation.
	host.handle(p, {"t": "next_phase"})
	await _wait(0.2)
	gs.fx.finish_all()
	await _click(gs.sidebar.phase_btn.get_global_rect().get_center())
	await _wait(0.12)
	await _shot("26_end_turn_discard")
	await _wait(1.0)


## Answers the pending choice of player p with the first option whose label contains `text`.
func _answer(p: int, text: String) -> void:
	if m.pending.is_empty():
		_check("pending choice for '%s'" % text, false, "nothing pending")
		return
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]).contains(text):
			host.handle(p, {"t": "choose", "id": m.pending["id"], "indices": [i]})
			return
	_check("option '%s' offered" % text, false, str(m.pending["options"].map(func(o): return o["label"])))


# ---------------------------------------------------------------- checks

func _check(name: String, ok: bool, detail: String = "") -> void:
	checks.append({"check": name, "ok": ok, "detail": detail})
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func _check_proportions(name: String) -> void:
	var bad := []
	for k in gs.board.slots.keys():
		var w: CardWidget = gs.board.slots[k]["widget"]
		if not w.visible:
			continue
		var r := w.card_rect()
		var ratio := r.size.x / r.size.y
		var want := 1.5 if w.rotated else 2.0 / 3.0
		if absf(ratio - want) > 0.02:
			bad.append("%s %.3f" % [k, ratio])
	for uid in gs.hand.items.keys():
		var hw: CardWidget = gs.hand.items[uid]["widget"]
		var hr := hw.card_rect()
		if absf(hr.size.x / hr.size.y - 2.0 / 3.0) > 0.02:
			bad.append("hand %d" % uid)
	_check(name, bad.is_empty(), str(bad))


func _state_sig() -> String:
	return str([m.log_entries.size(), m.pending.get("id", -1), m.players[0]["ap"], m.players[1]["ap"], m.players[0]["hp"],
		m.players[1]["hp"], gs.debug_sent, m.cards.keys().map(func(u): return [m.cards[u]["zone"], m.cards[u]["slot"], m.cards[u]["st"]])])


func _hover_sweep() -> void:
	for uid in gs.hand.order:
		await _move(_hand_rect(uid).get_center())
		await _wait(0.12)
	for k in gs.board.slots.keys():
		await _move((gs.board.slots[k]["zone_node"] as Control).get_global_rect().get_center())
		await _frames(3)


# ---------------------------------------------------------------- UI lookups

func _w_hand(uid: int) -> CardWidget:
	return gs.hand.items[uid]["widget"]


func _hand_rect(uid: int) -> Rect2:
	return (gs.hand.items[uid]["holder"] as Control).get_global_rect()


func _w_slot(p: int, zone: String, slot: int) -> CardWidget:
	return gs.fx_slot_item(p, zone, slot)["widget"]


func _slot_rect(p: int, zone: String, slot: int) -> Rect2:
	return (gs.fx_slot_item(p, zone, slot)["holder"] as Control).get_global_rect()


func _zone_rect(p: int, zone: String, slot: int) -> Rect2:
	return (gs.fx_slot_item(p, zone, slot)["zone_node"] as Control).get_global_rect()


func _row_labels() -> Array:
	if gs.action_row.stack == null or not is_instance_valid(gs.action_row.stack):
		return []
	return gs.action_row.stack.get_children().map(func(b): return (b as Button).text)


func _row_tooltip(label: String) -> String:
	if gs.action_row.stack == null:
		return ""
	for b in gs.action_row.stack.get_children():
		if (b as Button).text == label:
			return (b as Button).tooltip_text
	return ""


func _click_row(label: String) -> void:
	if gs.action_row.stack == null or not is_instance_valid(gs.action_row.stack):
		_check("row has '%s'" % label, false, "no action row")
		return
	for b in gs.action_row.stack.get_children():
		if (b as Button).text == label:
			await _click((b as Control).get_global_rect().get_center())
			return
	_check("row has '%s'" % label, false, str(_row_labels()))


func _tray_widgets() -> Array:
	var out := []
	for ch in gs.prompt.tray_box.get_children():
		if ch is GridContainer:
			for w in ch.get_children():
				if w is CardWidget:
					out.append(w)
	return out


func _tray_buttons() -> int:
	var n := 0
	for ch in gs.prompt.tray_box.get_children():
		if ch is GridContainer:
			for w in ch.get_children():
				if w is Button:
					n += 1
	return n


func _banner_button(prefix: String) -> Button:
	for b in gs.prompt.banner_btns.get_children():
		if (b as Button).text.begins_with(prefix):
			return b
	return Button.new()


func _pile_cells() -> Array:
	return gs.details.pile_list.get_children().filter(func(n): return (n as Node).has_meta("uid"))


func _pile_button(label: String) -> Button:
	for cell in _pile_cells():
		var found := _find_button(cell, label)
		if found != null:
			return found
	return null


func _find_button(n: Node, label: String) -> Button:
	if n is Button and (n as Button).text == label:
		return n
	for ch in n.get_children():
		var f := _find_button(ch, label)
		if f != null:
			return f
	return null


# ---------------------------------------------------------------- input + capture

var _hold := Vector2(-1, -1)


func _push_motion(pos: Vector2) -> void:
	get_viewport().warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(1, 0)
	get_viewport().push_input(ev, true)


## Moves the pointer and keeps it resting there (re-asserted every frame while waiting).
func _move(pos: Vector2) -> void:
	_hold = pos
	get_viewport().warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(4, 0)
	get_viewport().push_input(ev, true)
	await _frames(2)


func _click(pos: Vector2) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
		await _frames(1)
	await _frames(3)


func _key(k: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
		await _frames(1)
	await _frames(2)


func _view_seat(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if _hold.x >= 0.0:
			_push_motion(_hold)
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("f02_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("F02 DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
