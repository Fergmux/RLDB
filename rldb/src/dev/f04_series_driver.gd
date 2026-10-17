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
	ov.deck_open["s0"] = true
	ov.refresh()
	await _frames(8)
	await _shot("series_02_structured_selected")
	ov.deck_open.clear()
	ov.decks.tab = "custom"
	ov.refresh()
	await _frames(8)
	await _shot("series_03_custom_empty")
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
		host.handle(a, {"t": "cancel", "id": m.pending["id"]})
		await _frames(4)
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
	host.handle(0, {"t": "reward_add", "index": 0})
	await _frames(8)
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
	# A real mouse drag: Power onto the top half of the Unit row.
	var rows := _find_rows(ov.overlay_box)
	var src: Control = rows[4]
	var dst: Control = rows[0]
	var from := src.get_global_rect().position + Vector2(60, src.size.y / 2.0)
	var to := dst.get_global_rect().position + Vector2(80, 6)
	await _mouse(from, true)
	var last := from
	for i in 12:
		var at := from.lerp(to, float(i + 1) / 12.0)
		await _motion(at, at - last)
		last = at
	await _shot("draft_02_dragging")
	await _mouse(to, false)
	await _frames(10)
	_check("F06-05 drag and drop reorders", dv._order == ["power", "unit", "spell", "extra", "trap"], str(dv._order))
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


func _find_button(n: Node, prefix: String) -> Button:
	if n == null:
		return null
	if n is Button and (n as Button).text.begins_with(prefix):
		return n
	for c in n.get_children():
		var f := _find_button(c, prefix)
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
