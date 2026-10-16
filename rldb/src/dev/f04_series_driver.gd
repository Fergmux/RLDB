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
	rr._basic_sel = 112
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
	DeckStore._write([])
	if saved_file != "":
		var f := FileAccess.open(DeckStore.PATH, FileAccess.WRITE)
		f.store_string(saved_file)
		f.close()
	elif FileAccess.file_exists(DeckStore.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.PATH))
	print("F04 SERIES DONE pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit()


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
