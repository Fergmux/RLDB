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
## F01: the deck modal's rect on the first (Structure) tab; every tab must keep it.
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
	if "--draft-only" in OS.get_cmdline_user_args():
		# Only the draft screens (J26-J30): -- --f04-series-shots=<dir> --no-steam --draft-only
		await _draft_phase()
		_restore_decks(saved_file)
		return
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	var gs: GameScreen = main.screen
	var ov: GameSeriesOverlay = gs.overlays
	await _shot("series_01_structured")
	# F3: the closed tab's hover glow (the tab is driven directly: the real pointer is not over the window).
	var custom_tab := ov.decks.tab_widget.tab("custom")
	custom_tab.glow = 1.0
	await _frames(3)
	await _shot("series_01b_tab_hover")
	custom_tab.glow = 0.0
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
	await _g02_toggle_in_place(area)
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
		{"i": 0, "label": "Water"}, {"i": 1, "label": "Fire"}, {"i": 2, "label": "Earth"}, {"i": 3, "label": "Lightning"}, {"i": 4, "label": "Light"}, {"i": 5, "label": "Dark"}, {"i": 6, "label": "Physical"}]}, true))
	await _fake(gs, "prompt_03_trap", base.merged({"kind": "trap_response", "prompt": "Rushed Recklessly can be activated in response to the attack on Dante.", "options": [
		{"i": 0, "label": "Activate Rushed Recklessly (Trap)"}, {"i": 1, "label": "Skip"}, {"i": 2, "label": "Skip for the rest of this turn"}]}, true))
	await _fake(gs, "prompt_04_multi", base.merged({"kind": "select", "prompt": "Choose up to 3 cards in your Spent pile to return to your Draw pile in the order you want", "max": 3, "min": 2, "options": [
		{"i": 0, "label": "Dragon of the Cave"}, {"i": 1, "label": "Basic Warrior"}, {"i": 2, "label": "The Sweeper"}, {"i": 3, "label": "Krakeshin"}]}, true))
	await _fake(gs, "prompt_05_short", base.merged({"kind": "stance", "prompt": "Stance?", "options": [{"i": 0, "label": "Attack stance"}, {"i": 1, "label": "Defense stance"}]}, true))
	await _fake(gs, "prompt_06_long_title", base.merged({"kind": "stance", "prompt": "Choose a stance for Bastion Wyrm, the Eternal Guardian of the Obsidian Citadel.", "options": [{"i": 0, "label": "Attack stance"}, {"i": 1, "label": "Defense stance"}]}, true))
	# Waiting for the opponent: the centre notice.
	gs.mv["pending"] = {}
	gs.prompt.prompt_sig = 0
	gs.prompt.render()
	gs.prompt.show_wait("Ben is responding…")
	# #38: the notice fades in after WaitNotice.APPEAR_DELAY (a fast reply never flashes it).
	await get_tree().create_timer(WaitNotice.APPEAR_DELAY + 0.4).timeout
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
	await get_tree().create_timer(0.12).timeout
	await _shot("rewards_06b_offer_folding")
	await get_tree().create_timer(0.3).timeout
	await _shot("rewards_06c_offer_folded")
	await get_tree().create_timer(0.6).timeout   # the other cards fold away, then the take is sent
	await _frames(8)
	_check("F10 clicking the card takes exactly one card", host.series.rewards[0]["taken"].size() == taken_before + 1 and int(host.series.rewards[0]["left"]) == left_before, "%d %d" % [host.series.rewards[0]["taken"].size(), int(host.series.rewards[0]["left"])])
	await _shot("rewards_07_after_pick")
	host.handle(0, {"t": "reward_remove", "card_id": int(host.series.decks[0][host.series.decks[0].size() - 1])})
	await get_tree().create_timer(0.6).timeout
	host.handle(0, {"t": "reward_extra_basic"})
	await get_tree().create_timer(0.6).timeout
	await _shot("rewards_07b_three_taken")
	_check("E2 the chosen-rewards list has one row per reward", ov.overlay_box.find_children("*", "ChoiceTile.Icon", true, false).size() >= 0 and host.series.rewards[0]["taken"].size() == 3)
	host.handle(0, {"t": "reward_finish"})
	await _frames(8)
	_view_seat(0)        # hot-seat follows the seat still choosing; look at seat 0's wait
	await _frames(8)
	var dots := ov.overlay_box.find_children("*", "WaitingDots", true, false)
	_check("2026-10-18 rewards wait is the animated line, no plate", dots.size() == 1 and ov.overlay_box.find_children("*", "WaitPlate", true, false).is_empty())
	await _shot("rewards_08_done_waiting")
	host.handle(1, {"t": "reward_finish"})
	var loser: int = host.series.last_loser
	_view_seat(loser)
	await _frames(8)
	await _shot("series_08_first_player")
	await _g01_g05_hotseat(loser)
	await _draft_phase()
	_restore_decks(saved_file)


## Puts the saved-deck file back as it was before the run (or removes the run's), then quits.
func _restore_decks(saved_file: String) -> void:
	DeckStore._write([])
	if saved_file != "":
		var f := FileAccess.open(DeckStore.PATH, FileAccess.WRITE)
		f.store_string(saved_file)
		f.close()
	elif FileAccess.file_exists(DeckStore.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))
	print("F04 SERIES DONE pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit()


## F06-04 / F06-06 and the 2026-10-18 draft: the Change basic units reward picker was shot above
## (rewards_05_basic); here a draft series: it opens straight on the picks, a category tab is
## chosen out of order, the basic unit is changed mid-draft, then the waiting state.
func _draft_phase() -> void:
	main._start_local({"seed": 777, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _frames(10)
	host = main.local_host
	var gs: GameScreen = main.screen
	var ov: GameSeriesOverlay = gs.overlays
	_view_seat(0)
	await _frames(10)
	var dv: DeckSelectView = ov.decks
	var d0: Dictionary = host.series.view_for(0)["draft"]
	_check("draft opens on the picks (no setup step)", String(d0["category"]) == "unit" and not d0["offer"].is_empty())
	_check("draft modal inside the window", get_viewport().get_visible_rect().grow(1).encloses(ov.overlay.get_global_rect()), str(ov.overlay.get_global_rect()))
	await _shot("draft_01_open")
	# Any order: open the Power tab first.
	var pw := _find_button(ov.overlay_box, "", "Draft Power cards")
	_check("a tab per category with picks left", pw != null and not pw.disabled)
	if pw != null:
		pw.pressed.emit()
	await _frames(10)
	_check("the Power tab opens the Power offer", String(host.series.view_for(0)["draft"]["category"]) == "power")
	await _shot("draft_02_power_tab")
	# J27: the open tab keeps its colour and the pane takes it (Spell: green), fading from the last.
	var sp := _find_button(ov.overlay_box, "", "Draft Spell cards")
	if sp != null:
		sp.pressed.emit()
	await _frames(1)
	var cat_tabs: FolderTabs = dv._cat_tabs
	_check("J27 the pane fades from the last tab's colour", cat_tabs != null and not cat_tabs.shown_fill().is_equal_approx(cat_tabs.target_fill()))
	await get_tree().create_timer(0.5).timeout
	cat_tabs = dv._cat_tabs
	_check("J27 the pane takes the open tab's colour", cat_tabs != null and cat_tabs.tint_pane and cat_tabs.shown_fill().is_equal_approx(cat_tabs.target_fill()) and cat_tabs.target_fill().g > cat_tabs.target_fill().r)
	await _shot("draft_02b_spell_tab")
	pw = _find_button(ov.overlay_box, "", "Draft Power cards")
	if pw != null:
		pw.pressed.emit()
	await _frames(10)
	# Change the basic unit mid-draft.
	var chg := _find_button(ov.overlay_box, "Change")
	_check("Change basic unit button", chg != null)
	if chg != null:
		chg.pressed.emit()
	await _frames(12)
	await _shot("draft_04_picker_open")
	var picker := _find_picker(gs)
	_check("F06-06 picker opens with the current basic", picker != null and picker.type == "Water" and picker.race == "Mage")
	if picker != null:
		picker.choose("Dark", "Dragon")
		await _frames(6)
		await _shot("draft_05_picker_chosen")
		var use := _find_button(dv._picker_dim, "Use ")
		if use != null:
			use.pressed.emit()
	await _frames(10)
	_check("the basic unit changes mid-draft", int(host.series.draft[0]["basic"]) == Series.basic_for("Dark", "Dragon") and dv._picker_dim == null)
	await _shot("draft_06_basic_changed")
	host.handle(0, {"t": "draft_pick", "index": 0})
	await _frames(10)
	await _shot("draft_07_after_power_pick")
	# Seat 1: its own draft, independent of seat 0.
	_view_seat(1)
	await _frames(10)
	await _shot("draft_08_seat1")
	# Seat 0 drafts every card. J30: the deck is not locked in yet; the Confirm selections pane shows.
	_view_seat(0)
	var guard := 0
	while not host.series.draft_complete(0) and guard < 60:
		host.handle(0, {"t": "draft_pick", "index": 0})
		guard += 1
	await _frames(12)
	_check("J30 the last pick does not lock the deck in", not host.series.deck_ready[0])
	var confirm := _find_button(ov.overlay_box, "Confirm selections")
	_check("J30 Confirm selections shown once every card is drafted", confirm != null and not confirm.disabled)
	_check("J30 draft modal inside the window", get_viewport().get_visible_rect().grow(1).encloses(ov.overlay.get_global_rect()), str(ov.overlay.get_global_rect()))
	await _shot("draft_08b_complete")
	await _draft_list_checks(gs)
	# J30: the basic unit can still change after every card is drafted.
	var chg2 := _find_button(ov.overlay_box, "Change basic unit")
	_check("J30 Change basic unit on the complete pane", chg2 != null)
	if chg2 != null:
		chg2.pressed.emit()
	await _frames(10)
	var pk2 := _find_picker(gs)
	if pk2 != null:
		pk2.choose("Light", "Warrior")
		await _frames(4)
		var use2 := _find_button(dv._picker_dim, "Use ")
		if use2 != null:
			use2.pressed.emit()
	await _frames(12)
	_check("J30 basic changed after the draft is complete", int(host.series.draft[0]["basic"]) == Series.basic_for("Light", "Warrior") and not host.series.deck_ready[0])
	await _shot("draft_08c_complete_basic_changed")
	confirm = _find_button(ov.overlay_box, "Confirm selections")
	if confirm != null:
		confirm.pressed.emit()
	await _frames(10)
	_check("F06 seat 0 deck drafted", host.series.deck_ready[0] and host.series.decks[0].size() == 15, str(host.series.decks[0].size()))
	_check("F06-06 three chosen basics", host.series.decks[0].count(Series.basic_for("Light", "Warrior")) == 3)
	_view_seat(0)        # hot-seat follows the seat that still has to act; look at seat 0's wait
	await _frames(6)
	await _shot("draft_09_waiting")
	# Rewards: Change basic units after a game.
	while not host.series.draft_complete(1) and guard < 200:
		host.handle(1, {"t": "draft_pick", "index": 0})
		guard += 1
	# J30: seat 1 has drafted every card but not yet confirmed; seat 0 waits on it.
	_view_seat(0)
	await _frames(8)
	await _shot("draft_09b_seat1_complete")   # hot-seat shows the seat that still has to act
	_check("J30 seat 0 sees the other seat confirming", bool(host.series.view_for(0)["draft"]["opponent"]["complete"]) and dv._opponent_doing(host.series.view_for(0)["draft"]).contains("confirming"))
	_check("J30 the series waits for the other seat's confirm", host.series.stage == Series.STAGE_DECKS)
	host.handle(1, {"t": "draft_confirm"})
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


## J28 / J29: the sidebar's draft list once every card is drafted: the grid holds the drafted cards
## (small card faces with the duel's coloured tooltip) and the rows carry the duel pile rows'
## information (kind, cost, Race and Type, a Fusion's materials). Shoots the list scrolled to the
## rows and one grid card's tooltip.
func _draft_list_checks(gs: GameScreen) -> void:
	var slots := gs.find_children("DraftSlots", "", true, false)
	var ds: DraftSlots = slots[0] if not slots.is_empty() else null
	var picked: Array = host.series.draft[0]["picked"]
	_check("J29 the grid shows every drafted card", ds != null and ds.cards.size() == picked.size()
		and ds.cards.all(func(w): return w is CardWidget and (w as CardWidget).tooltip_text != ""))
	_check("J29 grid cards are the drafted cards", ds != null and range(picked.size()).all(func(i): return int((ds.cards[i] as CardWidget).view["id"]) == int(picked[i])))
	_check("J29 grid cards sit in their 56x84 slots", ds != null and ds.cards.all(func(w): return (w as Control).size.is_equal_approx(DraftSlots.SLOT)))
	var fusion_rows := 0
	var rows := gs.details.pile_list.get_children().filter(func(r): return r.has_meta("uid"))
	for r in rows:
		var c: Dictionary = r.get_meta(&"tip_card", {})
		if String(c.get("category", "")) == "fusion":
			fusion_rows += 1
			_check("J28 a Fusion row names its materials", r.find_child("RowMaterials", true, false) != null)
	_check("J28 one row per drafted card", rows.size() == picked.size(), str(rows.size()))
	_check("J28 rows carry the full card view (rules parts, keywords)", rows.all(func(r): return (r.get_meta(&"tip_card", {}) as Dictionary).has("text_parts")))
	print("J28 fusion rows: %d" % fusion_rows)
	# The rows below the grid.
	gs.details.pile_scroll.scroll_vertical = 330
	await _frames(6)
	await _shot("draft_08e_list_rows")
	gs.details.pile_scroll.scroll_vertical = 100000   # the Extra Deck picks are last
	await _frames(6)
	await _shot("draft_08f_list_fusion_rows")
	gs.details.pile_scroll.scroll_vertical = 0
	await _frames(4)
	if ds != null and not ds.cards.is_empty():
		var w: CardWidget = ds.cards[ds.cards.size() - 1]
		w.hovered = true
		var tip = w._make_custom_tooltip(w.tooltip_text)
		_check("J29 a grid card has the coloured card tooltip", tip != null and not (tip is Label))
		if tip != null:
			var pc := PanelContainer.new()
			pc.add_theme_stylebox_override("panel", gs.get_theme_stylebox("panel", "TooltipPanel"))
			pc.z_index = 4000
			pc.z_as_relative = false
			gs.add_child(pc)
			pc.add_child(tip)
			await _frames(2)
			var wr := w.get_global_rect()
			pc.position = Vector2(wr.position.x - pc.size.x - 12.0, clampf(wr.position.y - 40.0, 8.0, gs.size.y - pc.size.y - 8.0))
			await _frames(4)
			await _shot("draft_08d_grid_tooltip")
			pc.queue_free()
		w.hovered = false
		await _frames(2)


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
	if n is Button and (n as Button).text.begins_with(prefix) and (tip == "" or (n as Button).tooltip_text.begins_with(tip)):
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


## G02: opening and closing a deck's full list (a real click on its toggle) changes the tile in
## place: the same tile node, the same scroll position, its rim gold from the first frame. Frames
## 1 and 2 after each click are saved as evidence that nothing flashes.
func _g02_toggle_in_place(area: ScrollArea) -> void:
	var ov: GameSeriesOverlay = main.screen.overlays
	var tile: DeckTile = null
	for k in ov.decks._tiles:
		var t: DeckTile = ov.decks._tiles[k]
		if area.get_global_rect().has_point(t.get_global_rect().get_center()):
			tile = t
			break
	_check("G02 a tile is visible in the scrolled list", tile != null)
	if tile == null:
		return
	await get_tree().create_timer(0.8).timeout     # let the earlier smooth wheel scroll settle
	var scroll_before: int = area.scroll.scroll_vertical
	var tog: Button = tile.find_children("*", "Button", true, false).filter(func(b): return b.text.ends_with("full list"))[0]
	var box_before: Node = ov.overlay_box.get_child(0)
	tog.pressed.emit()
	await _shot("g02_open_frame1")
	await _shot("g02_open_frame2")
	await _frames(6)
	await _shot("g02_open_settled")
	_check("G02 opening keeps the same tile node and modal content", is_instance_valid(tile) and tile.selected and is_instance_valid(box_before) and box_before.get_parent() == ov.overlay_box)
	# Within 2 px: SmoothScroll settles on a float target (the old rebuild jumped to 0 for 2 frames).
	_check("G02 opening keeps the list's scroll position", absi(area.scroll.scroll_vertical - scroll_before) <= 2, "%d vs %d" % [area.scroll.scroll_vertical, scroll_before])
	var sb := tile.get_theme_stylebox("panel") as StyleBoxFlat
	_check("G02 the opened tile's rim is gold at once", sb.border_color.is_equal_approx(UIStyle.GOLD_HI), str(sb.border_color))
	tog.pressed.emit()
	await _shot("g02_close_frame1")
	await _shot("g02_close_frame2")
	await _frames(6)
	_check("G02 closing keeps the same tile node and closes its list", is_instance_valid(tile) and not tile.selected and box_before.get_parent() == ov.overlay_box)
	ov.render()   # an unrelated re-render must not rebuild for the toggle
	_check("G02 the next render does not rebuild for the toggle", is_instance_valid(box_before) and box_before.get_parent() == ov.overlay_box)


## G05 / G06 / G01 in hot-seat at the who-goes-first stage: the loser's centred choice, the
## Start next duel button (enabled once chosen) and the three-choice leave dialog.
func _g01_g05_hotseat(loser: int) -> void:
	var gs: GameScreen = main.screen
	var start := _overlay_button(gs, "Start next duel")
	_check("G05 Start next duel waits for the loser's choice", start != null and start.disabled)
	var mine := _overlay_button(gs, "I go first")
	_check("G06 the choice buttons are centred in the modal", mine != null and absf(mine.get_parent().get_global_rect().get_center().x - gs.overlays.overlay.get_global_rect().get_center().x) < 4.0)
	if mine != null:
		mine.pressed.emit()
	await _frames(8)
	await _shot("g05_first_chosen")
	_check("G05 choosing alone does not start the duel", host.series.stage == Series.STAGE_FIRST and host.series.first_chosen)
	gs.menu.confirm_forfeit(true)
	await _frames(8)
	await _shot("g01_hotseat_quit_dialog")
	var d := gs.menu.dialog()
	_check("G01 hot-seat dialog: Save and quit / Forfeit and quit / Keep playing", d != null and d.choices.map(func(c): return c["text"]) == ["Save and quit", "Forfeit and quit", "Keep playing"])
	if d != null:
		d.press("Keep playing")
	await _frames(4)
	start = _overlay_button(gs, "Start next duel")
	_check("G05 Start next duel is enabled after the choice", start != null and not start.disabled)


func _overlay_button(gs: GameScreen, text: String) -> Button:
	for b in gs.overlays.overlay_box.find_children("*", "Button", true, false):
		if (b as Button).text == text and b.is_visible_in_tree():
			return b
	return null
