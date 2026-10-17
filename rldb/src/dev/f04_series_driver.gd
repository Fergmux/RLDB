extends Node
## Development-only visual driver for F04-02 / F04-03 / F04-13 (series screens and the input
## prompt). Launched with  godot --path rldb -- --f04-series-shots=<abs dir> --no-steam
## Saves screenshots of every deck-select state, every rewards state and every prompt kind, and
## checks that the input panel hugs its content in each. Prints PASS / FAIL lines.

var main: Node
var out_dir: String
var host: LocalHost
var _fail := 0
var _pass := 0
## F01: the deck modal's rect on the first (Structured) tab; every tab must keep it.
var _f01_rect := Rect2()


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	main._privacy = false
	var saved_file := ""
	if FileAccess.file_exists(DeckStore.PATH):
		saved_file = FileAccess.get_file_as_string(DeckStore.PATH)
	DeckStore._write([])
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	var gs: GameScreen = main.screen
	var ov: GameSeriesOverlay = gs.overlays
	await _shot("series_01_structured")
	_f01_rect = Rect2(ov.overlay.position, ov.overlay.size)
	ov.deck_open["s0"] = true
	ov.refresh()
	await _frames(8)
	await _shot("series_02_structured_selected")
	_check("F01 opening a deck tile keeps the modal's size", Rect2(ov.overlay.position, ov.overlay.size).is_equal_approx(_f01_rect), str(ov.overlay.get_global_rect()))
	ov.deck_open.clear()
	ov.decks.tab = "custom"
	ov.refresh()
	await _frames(8)
	await _shot("series_03_custom_empty")
	_check("F01 empty Custom tab keeps the modal's size and place", Rect2(ov.overlay.position, ov.overlay.size).is_equal_approx(_f01_rect), "%s vs %s" % [ov.overlay.get_global_rect(), _f01_rect])
	# F01: one saved deck (sparse tab) must not shrink the modal either.
	DeckStore.save_deck("Lone Deck", [112, 112, 36, 34])
	ov.refresh()
	await _frames(10)
	_check("F01 sparse Custom tab keeps the modal's size and place", Rect2(ov.overlay.position, ov.overlay.size).is_equal_approx(_f01_rect), str(ov.overlay.get_global_rect()))
	await _shot("series_03b_custom_sparse")
	DeckStore.delete_deck("Lone Deck")
	var ids := [112, 112, 36, 34, 70, 162, 29, 54, 51, 37, 28, 13, 102]
	for n in ["Ember Rush", "Tidal Control", "Stone Wall", "Storm Caller", "Grave Whisper", "Holy Light", "Blade Dance"]:
		DeckStore.save_deck(n, ids)
	ov.refresh()
	await _frames(10)
	await _shot("series_04_custom_list")
	# Scroll with real wheel events over a tile.
	var area := ov.decks.list_area
	_check("custom list scrolls (content taller than view)", area != null and area.scroll.get_v_scroll_bar().max_value - area.scroll.get_v_scroll_bar().page > 10.0)
	var pos := area.get_global_rect().get_center()
	for i in 4:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		get_viewport().push_input(ev)
		await _frames(2)
	await get_tree().create_timer(0.7).timeout
	_check("mouse wheel scrolls the list smoothly", area.scroll.scroll_vertical > 100, str(area.scroll.scroll_vertical))
	var r := ov.overlay.get_global_rect()
	_check("deck panel inside the window", get_viewport().get_visible_rect().grow(1).encloses(r), str(r))
	await _shot("series_05_custom_scrolled")
	ov.decks.tab = "structured"
	ov.deck_open["s2"] = true
	ov.refresh()
	await _frames(8)
	await _shot("series_06_structured_selected_2")
	for n in ["Ember Rush", "Tidal Control", "Stone Wall", "Storm Caller", "Grave Whisper", "Holy Light", "Blade Dance"]:
		DeckStore.delete_deck(n)
	ov.deck_open.clear()
	ov.decks.tab = "structured"
	# Locked-in waiting state for seat 0.
	host.handle(0, {"t": "pick_starter", "index": 1})
	_view_seat(0)
	await _frames(8)
	await _shot("series_07_waiting_locked")
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(6)
	var m: MatchEngine = host.series.game
	# --- prompts in game 1 ---
	await get_tree().create_timer(4.5).timeout   # the who-goes-first coin plays over the board first
	_stage_board(m)
	host.broadcast()
	_view_seat(m.active)
	await _frames(6)
	var a := m.active
	var hand_unit := -1
	for u in m.players[a]["hand"]:
		if m.is_unit(u) and m.validate(a, {"t": "summon", "uid": u}) == "":
			hand_unit = u
			break
	if hand_unit != -1:
		host.handle(a, {"t": "summon", "uid": hand_unit})
		await _frames(8)
		await _shot("prompt_01_zone")
		_fit("zone prompt", gs)
		_check("F05 zone prompt shows the summoned card", gs.prompt.subject_box.visible and int(gs.prompt.subject_card.view.get("uid", -1)) == hand_unit)
		# F06: a field card under the pointer does not lift while a zone is being chosen.
		var fit := gs.selection.item_for_uid(m.field_units(a)[0])
		var fat: Vector2 = (fit["holder"] as Control).get_global_rect().get_center()
		gs.hover.update(fat)
		await _frames(4)
		_check("F06 no field hover during the zone choice", gs.hover.hv.is_empty())
		await _shot("prompt_01b_zone_no_hover")
		host.handle(a, {"t": "cancel", "id": m.pending["id"]})
		await _frames(4)
		gs.hover.update(fat)
		await _frames(6)
		_check("F06 field hover returns after cancel", not gs.hover.hv.is_empty())
		gs.hover.clear()
		await _frames(2)
	await _extra_shots(gs, m, a)
	# Fake prompt kinds for a deterministic look at long text and many buttons.
	var base := {"id": 999, "mine": true, "player": a, "cancellable": true, "min": 1, "max": 1, "options": [], "kind": "mode"}
	await _fake(gs, "prompt_02_type", base.merged({"kind": "mode", "prompt": "Choose a Type for Waang until end of turn.", "options": [
		{"i": 0, "label": "Water"}, {"i": 1, "label": "Fire"}, {"i": 2, "label": "Earth"}, {"i": 3, "label": "Lightning"}, {"i": 4, "label": "Heavenly"}, {"i": 5, "label": "Necrotic"}, {"i": 6, "label": "Physical"}]}, true))
	await _fake(gs, "prompt_03_trap", base.merged({"kind": "trap_response", "prompt": "Rushed Recklessly can be activated in response to the attack on Dante.", "options": [
		{"i": 0, "label": "Activate Rushed Recklessly (Trap)"}, {"i": 1, "label": "Pass"}]}, true))
	await _fake(gs, "prompt_04_multi", base.merged({"kind": "select", "prompt": "Choose up to 3 cards in your Spent pile to return to your Draw pile in the order you want", "max": 3, "min": 2, "options": [
		{"i": 0, "label": "Dragon of the Cave"}, {"i": 1, "label": "Basic Warrior"}, {"i": 2, "label": "The Sweeper"}, {"i": 3, "label": "Krakeshin"}]}, true))
	await _fake(gs, "prompt_05_short", base.merged({"kind": "mode", "prompt": "Stance?", "options": [{"i": 0, "label": "Attack"}, {"i": 1, "label": "Defense"}]}, true))
	await _fake(gs, "prompt_06_long_title", base.merged({"kind": "mode", "prompt": "Choose a stance for Bastion Wyrm, the Eternal Guardian of the Obsidian Citadel.", "options": [{"i": 0, "label": "Attack"}, {"i": 1, "label": "Defense"}]}, true))
	# Waiting for the opponent: the centre notice.
	gs.mv["pending"] = {}
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	gs.prompt.show_wait("Ben is responding…")
	await _frames(6)
	await _shot("prompt_07_waiting")
	gs.prompt.show_wait("")
	# Real attack target + trap response.
	_view_seat(a)
	await _frames(4)
	# --- rewards ---
	await get_tree().create_timer(4.0).timeout   # let the coin flip finish
	host.handle(1 - a, {"t": "concede"})
	_view_seat(0)
	await _frames(8)
	await _shot("rewards_01_choose")
	var rr: GameRewardPanels = ov.rewards
	rr.mode = "add"
	ov.refresh()
	await _frames(8)
	await _shot("rewards_02_add_types")
	rr.mode = "remove"
	ov.refresh()
	await _frames(8)
	await _shot("rewards_03_remove")
	rr._remove_sel = 36
	ov.refresh()
	await _frames(8)
	await _shot("rewards_04_remove_selected")
	rr.mode = "basic"
	rr._remove_sel = -1
	ov.refresh()
	await _frames(8)
	rr._basic_race = "Warrior"
	rr._basic_type = "Fire"
	ov.refresh()
	await _frames(8)
	await _shot("rewards_05_basic")
	_check("rewards modal narrower than the old 1040", ov.overlay.size.x <= 760.0, str(ov.overlay.size))
	rr.mode = ""
	host.handle(0, {"t": "reward_type", "category": "spell"})
	await _frames(8)
	await _shot("rewards_06_offer")
	# F10: no Take card button; clicking the card takes it, a second click does nothing more.
	_check("F10 no Take card button", _find_button(ov.overlay_box, "Take card") == null)
	var offer_w: CardWidget = null
	for n in _nodes(ov.overlay_box):
		if n is CardWidget and n.has_meta("reward_offer") and int(n.get_meta("reward_offer")) == 0:
			offer_w = n
	var left_before := int(host.series.rewards[0]["left"])
	var taken_before: int = host.series.rewards[0]["taken"].size()
	if offer_w != null:
		offer_w.pressed.emit(offer_w)
		offer_w.pressed.emit(offer_w)
	await _frames(8)
	_check("F10 clicking the card takes exactly one card", host.series.rewards[0]["taken"].size() == taken_before + 1 and int(host.series.rewards[0]["left"]) == left_before, "%d %d" % [host.series.rewards[0]["taken"].size(), int(host.series.rewards[0]["left"])])
	await _shot("rewards_07_after_pick")
	host.handle(0, {"t": "reward_finish"})
	await _frames(8)
	await _shot("rewards_08_done_waiting")
	host.handle(1, {"t": "reward_finish"})
	var loser: int = host.series.last_loser
	_view_seat(loser)
	await _frames(8)
	await _shot("series_08_first_player")
	await _draft_phase()
	DeckStore._write([])
	if saved_file != "":
		var f := FileAccess.open(DeckStore.PATH, FileAccess.WRITE)
		f.store_string(saved_file)
		f.close()
	elif FileAccess.file_exists(DeckStore.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))
	print("F04 SERIES DONE pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit()


## F06-04..06: the Change basic units reward picker was shot above (rewards_05_basic); here a
## draft series: the setup (default, reordered by keyboard and by a real mouse drag, the Choose
## basic unit picker), the picks in the chosen order and the waiting state.
func _draft_phase() -> void:
	main._start_local({"seed": 777, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _frames(10)
	host = main.local_host
	var gs: GameScreen = main.screen
	var ov: GameSeriesOverlay = gs.overlays
	_view_seat(0)
	await _frames(10)
	var dv: DeckSelectView = ov.decks
	_check("F06-05 setup shown before the picks", not host.series.draft[0]["setup_done"] and dv._order == ["unit", "spell", "trap", "power", "extra"], str(dv._order))
	_check("F06-05 setup modal inside the window", get_viewport().get_visible_rect().grow(1).encloses(ov.overlay.get_global_rect()), str(ov.overlay.get_global_rect()))
	await _shot("draft_01_setup_default")
	# Keyboard / button reorder: Extra Deck up twice.
	dv._move("extra", -1)
	await _frames(4)
	dv._move("extra", -1)
	await _frames(8)
	_check("F06-05 arrows move a category", dv._order == ["unit", "spell", "extra", "trap", "power"], str(dv._order))
	var fo := gs.get_viewport().gui_get_focus_owner()
	_check("F06-05 focus stays on the moved row's arrow", fo is Button and fo.tooltip_text == "Move Extra Deck up", str(fo))
	# Owner answer 2026-10-17 §8: no drag-and-drop. The rows take no drag; Power goes to the top
	# with its Up arrow (pressed four times, as a player would, the list rebuilding each time).
	var rows := _find_rows(ov.overlay_box)
	_check("§8 draft rows are not draggable", not rows.is_empty() and rows.all(func(r): return not r.has_method("_get_drag_data")))
	for i in 4:
		var upb := _find_button(ov.overlay_box, "", "Move Power up")
		if upb != null and not upb.disabled:
			upb.pressed.emit()
		await _frames(4)
	await _frames(6)
	_check("F06-05 Up arrow moves Power to the top", dv._order == ["power", "unit", "spell", "extra", "trap"], str(dv._order))
	var upb2 := _find_button(ov.overlay_box, "", "Move Power up")
	_check("F06-05 top row's Up arrow is disabled", upb2 != null and upb2.disabled)
	await _shot("draft_03_reordered")
	# Choose basic unit.
	dv._open_picker(host.series.view_for(0)["draft"])
	await _frames(12)
	await _shot("draft_04_picker_open")
	var picker := _find_picker(gs)
	_check("F06-06 picker opens with the current basic", picker != null and picker.type == "Water" and picker.race == "Mage")
	if picker != null:
		picker.choose("Necrotic", "Dragon")
		await _frames(6)
		await _shot("draft_05_picker_chosen")
		var use := _find_button(dv._picker_dim, "Use ")
		if use != null:
			use.pressed.emit()
	await _frames(10)
	_check("F06-06 picker choice shown in the setup", dv._btype == "Necrotic" and dv._brace == "Dragon" and dv._picker_dim == null)
	await _shot("draft_06_setup_chosen")
	var go := _find_button(ov.overlay_box, "Start drafting")
	_check("F06-05 Start drafting button", go != null and not go.disabled)
	if go != null:
		go.pressed.emit()
	await _frames(10)
	var st: Dictionary = host.series.draft[0]
	_check("F06-05 seat 0 locked in its order", st["setup_done"] and st["cat_order"] == ["power", "unit", "spell", "extra", "trap"])
	_check("F06-06 three chosen basics", st["picked"].count(Series.basic_for("Necrotic", "Dragon")) == 3)
	_check("F06-05 first pick is Power", String(host.series.view_for(0)["draft"]["category"]) == "power")
	await _shot("draft_07_picking_power")
	# Seat 1: its own setup screen, independent of seat 0.
	_view_seat(1)
	await _frames(10)
	await _shot("draft_08_seat1_setup")
	host.handle(1, BotBrain.draft_setup_command(host.series))
	# Seat 0 finishes drafting; it then waits for seat 1.
	_view_seat(0)
	var guard := 0
	while not host.series.deck_ready[0] and guard < 60:
		host.handle(0, {"t": "draft_pick", "index": 0})
		guard += 1
	await _frames(10)
	_check("F06 seat 0 deck drafted", host.series.deck_ready[0] and host.series.decks[0].size() == 23, str(host.series.decks[0].size()))
	_view_seat(0)        # hot-seat follows the seat that still has to act; look at seat 0's wait
	await _frames(6)
	await _shot("draft_09_waiting")
	# Rewards: Change basic units after a game.
	while not host.series.deck_ready[1] and guard < 200:
		host.handle(1, {"t": "draft_pick", "index": 0})
		guard += 1
	await _frames(6)
	host.handle(host.series.game.active, {"t": "concede"})
	await _frames(6)
	_view_seat(0)
	await get_tree().create_timer(5.0).timeout     # the victory / defeat presentation plays first
	await _frames(6)
	ov.rewards.mode = "basic"
	ov.refresh()
	await _frames(10)
	await _shot("draft_10_reward_basic")
	_check("F06-04 rewards modal within 760 px", ov.overlay.size.x <= 760.0, str(ov.overlay.size))
	var ok := _find_button(ov.overlay_box, "Your basic units are already")
	_check("F06-04 no-op change cannot be confirmed", ok != null and ok.disabled)
	var pk := _find_picker(ov.overlay_box)
	if pk != null:
		pk.choose("Fire", "Beast")
	await _frames(6)
	var ch := _find_button(ov.overlay_box, "Change 3 basic units")
	_check("F06-04 confirm names the change", ch != null and not ch.disabled)
	await _shot("draft_11_reward_basic_chosen")
	if ch != null:
		ch.pressed.emit()
	await _frames(10)
	_check("F06-04 every basic changed", host.series.decks[0].count(Series.basic_for("Fire", "Beast")) == 3 and int(host.series.rewards[0]["left"]) == 3)
	await _shot("draft_12_reward_taken")


func _find_rows(n: Node) -> Array:
	var out := []
	if n is DeckSelectView.OrderRow:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_rows(c))
	return out


func _find_picker(n: Node) -> BasicUnitPicker:
	if n is BasicUnitPicker:
		return n
	for c in n.get_children():
		var f := _find_picker(c)
		if f != null:
			return f
	return null


func _find_button(n: Node, prefix: String, tip: String = "") -> Button:
	if n == null:
		return null
	if n is Button and (n as Button).text.begins_with(prefix) and (tip == "" or (n as Button).tooltip_text == tip):
		return n
	for c in n.get_children():
		var f := _find_button(c, prefix, tip)
		if f != null:
			return f
	return null


func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = at
	ev.global_position = at
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(ev, true)   # canvas coordinates: no window stretch applied
	await _frames(2)


## Mouse motion with the left button held; `rel` feeds the viewport's drag threshold.
func _motion(at: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.relative = rel
	ev.screen_relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(ev, true)   # canvas coordinates: no window stretch applied
	await _frames(2)


func _fake(gs: GameScreen, name: String, pd: Dictionary) -> void:
	gs.mv["pending"] = pd
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	await _frames(8)
	await _shot(name)
	_fit(name, gs)


## The input panel must hug its content: height equals its minimum height (within a pixel).
func _fit(label: String, gs: GameScreen) -> void:
	var b := gs.prompt.ctx_banner
	var need := b.get_combined_minimum_size().y
	_check("F04-13 %s fits content (h %.0f, needs %.0f)" % [label, b.size.y, need], b.visible and absf(b.size.y - need) <= 1.5)


func _check(label: String, ok: bool, extra: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", label, extra if not ok else ""])


func _view_seat(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return   # headless (dummy renderer): the checks still run, there is nothing to save
	img.save_png(out_dir.path_join(name + ".png"))


## Arranges a readable mid-game board (same as the shot driver).
## F04 / F08 / F05: the Extra Deck list with its Summon buttons, the Fusion-method picker, the
## method's next step, then the exact-cost Arcane material circles.
func _extra_shots(gs: GameScreen, m: MatchEngine, a: int) -> void:
	_put(m, a, 28, 2, "atk")                     # Beast (with the Dragon of the Cave: Bastion Wyrm)
	_put(m, a, 40, 5, "atk")                     # Aleister: a second Fusion method
	_add(m, a, 82, "hand")
	var wyrm := _add(m, a, 93, "extra")
	var kaya := _add(m, a, 175, "extra")         # Arcane, cost 3
	for id in [34, 27, 13, 162]:          # costs 1, 2, 3 and 0
		_add(m, a, id, "spent")
	m.players[a]["ap"] = 3
	host.broadcast()
	await _frames(6)
	gs.details.show_pile("extra")
	await _frames(10)
	var row := gs.details.pile_row(wyrm)
	var fb: Button = null
	if row != null:
		for n in _nodes(row):
			if n is Button and n.has_meta("summon_kind") and n.get_meta("summon_kind") == "fusion":
				fb = n
	_check("F04 Fusion Summon button on the Wyrm row without selecting it", fb != null and not fb.disabled)
	var krow := gs.details.pile_row(kaya)
	_check("F04 Arcane summon buttons on the Arcane row", krow != null and _nodes(krow).any(func(n): return n is Button and n.has_meta("summon_kind") and n.get_meta("summon_kind") == "arcane"))
	if row != null:
		gs.details.pile_scroll.ensure_control_visible(row)
	await _frames(6)
	await _shot("f04_01_extra_list")
	if fb != null:
		fb.pressed.emit()
	await _frames(12)
	_check("F04 two methods open the method picker", gs.details.method_picker_open())
	await _shot("f04_02_method_picker")
	var pm: Array = gs.details.fusion_methods_for(wyrm).filter(func(x): return String(x["t"]) == "cast")
	if not pm.is_empty():
		gs.details.run_fusion(wyrm, pm[0])
	await _frames(12)
	_check("F04 the chosen Fusion unit is answered for the player", not m.pending.is_empty() and not String(m.pending.get("prompt", "")).begins_with("Choose a Fusion unit"), str(m.pending.get("prompt", "")))
	await _shot("f04_03_fusion_next_step")
	_check("F05 Fusion step shows a card", gs.prompt.subject_box.visible)
	if not m.pending.is_empty():
		host.handle(a, {"t": "cancel", "id": m.pending["id"]})
	await _frames(6)
	# F08: Arcane Summon of the cost-3 Arcane unit; pay 1 then try to overpay.
	var acts: Array = gs.action_row.actions_for_card(kaya).filter(func(x): return x["t"] == "arcane")
	if not acts.is_empty():
		gs.action_row.run_action(kaya, acts[0])
	await _frames(12)
	_check("F08 material circles shown", gs.prompt.cost_pips.visible and gs.prompt.cost_pips.need == 3, str(m.pending.get("prompt", "")))
	await _shot("f08_01_materials_empty")
	var pd := gs.pending()
	var one := -1
	for o in pd.get("options", []):
		if GamePromptBanner.option_value(pd, int(o["i"])) == 1 and one == -1:
			one = int(o["i"])
	if one != -1:
		gs.selection.pick_option(one)
	await _frames(12)
	await _shot("f08_02_materials_partial")
	var bnr := gs.prompt.ctx_banner
	var tray_c := gs.prompt.tray
	_check("F05 the input panel does not cover the material tray", tray_c.visible and not Rect2(bnr.position, bnr.size).intersects(Rect2(tray_c.position, tray_c.size)), "%s %s" % [Rect2(bnr.position, bnr.size), Rect2(tray_c.position, tray_c.size)])
	var overs := 0
	for w in _nodes(gs.prompt.tray_box):
		if w is CardWidget and w.has_meta("overpay") and w.get_meta("overpay"):
			overs += 1
	_check("F08 overpaying materials disabled after a partial payment", overs > 0, str(overs))
	for o in pd.get("options", []):
		if GamePromptBanner.option_value(pd, int(o["i"])) == 2:
			gs.selection.pick_option(int(o["i"]))
			break
	await _frames(12)
	_check("F08 exact total enables Confirm", MatchView.multi_pick_error(gs.pending(), gs.multi) == "")
	await _shot("f08_03_materials_exact")
	gs.multi = []
	if not m.pending.is_empty():
		host.handle(a, {"t": "cancel", "id": m.pending["id"]})
	gs.details.close_pile()
	await _frames(6)


func _add(m: MatchEngine, p: int, id: int, zone: String) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = zone
	m.players[p][zone].append(uid)
	return uid


func _nodes(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_nodes(c))
	return out


func _stage_board(m: MatchEngine) -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	var a := m.active
	var o := 1 - a
	_put(m, a, 36, 0, "atk")
	_put(m, a, 34, 1, "def")
	_put(m, a, 112, 4, "atk")
	_put(m, o, 70, 0, "def")
	_put(m, o, 162, 2, "atk")
	_put(m, o, 29, 3, "atk")


func _put(m: MatchEngine, p: int, id: int, slot: int, stance: String) -> void:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, stance)
	m.cards[uid]["summoned_turn"] = m.turn - 1
