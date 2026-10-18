extends SceneTree
## Dev-only windowed evidence for the 18 October 2026 card database (design/card-database-update-
## 2026-10-18.md): the five new cards on the board and in the inspector, Light/Dark Type icons, the
## new ability buttons, the Counter Transmutation response and the Damage/Heal log. Run NOT headless:
##   godot --path rldb -s res://src/dev/db18_cards_shots.gd -- <absolute output dir> [WxH]

var out_dir: String = ""
var tag: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var me: int
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://db18"
	var sz := Vector2i(1600, 900)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _click(pos: Vector2, button: int) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.relative = Vector2(4, 0)
	root.push_input(mv, true)
	await _frames(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev, true)
		await _frames(1)
	await _frames(3)


func _inspect_slot(p: int, zone: String, slot: int, name: String) -> String:
	var w: CardWidget = gs.fx_slot_item(p, zone, slot)["widget"]
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	var text := _inspector_text()
	await _shot(name)
	CardInspector.close_topmost()
	await _frames(3)
	return text


## Every Label / RichTextLabel text inside the open inspector (for content checks).
func _inspector_text() -> String:
	var parts := []
	for n in root.find_children("*", "", true, false):
		if not n.is_inside_tree() or not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var top := n
		var inside := false
		while top != null:
			if top is CardInspector:
				inside = true
				break
			top = top.get_parent()
		if not inside:
			continue
		if n is Label:
			parts.append((n as Label).text)
		elif n is RichTextLabel:
			parts.append((n as RichTextLabel).get_parsed_text())
	return " | ".join(parts)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 9})          # Lone Warrior / Revealed
	host.handle(1, {"t": "pick_starter", "index": 2})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	me = m.active
	var foe := 1 - me
	main._shown_seat = me
	gs.attach(host.seats[me])
	await _frames(4)
	var extra: Array = m.players[0]["extra"].map(func(u): return int(m.cards[u]["id"]))   # seat 0 picked it
	_check("Lone Warrior structure deck brings Bronze Salaman to the Extra Deck", 186 in extra and extra.size() == 3)

	# Stage the new cards and the renamed Types.
	var necro := TB.unit(m, me, 188, 0)
	m.cards[necro]["st"]["poison"] = 2
	m.cards[necro]["st"]["burn"] = 1
	TB.unit(m, me, 185, 1)                                     # Drako
	TB.unit(m, me, 187, 2)                                     # Fence of the Marked Claw
	TB.unit(m, me, 13, 3)                                      # Chaos Witch: Dark by default
	TB.unit(m, me, 186, 4)                                     # Bronze Salaman: Light Dragon
	TB.power(m, me, 169, 0)                                    # Options
	TB.power(m, me, 178, 1)                                    # Reinforcements
	TB.unit(m, foe, 105, 0)                                    # Basic Mage, Light
	TB.unit(m, foe, 129, 1)                                    # Basic Monster, Dark
	TB.unit(m, foe, 10, 2)                                     # Tag Team - W, Dark
	TB.set_card(m, foe, 184, 0)                                # Counter Transmutation, face down
	var bait := TB.set_card(m, foe, 83, 1)                     # a set Spell to destroy
	TB.power(m, foe, 139, 0)
	TB.card(m, foe, 166, "spent")                              # a Power for Counter Transmutation
	TB.card(m, me, 184, "hand")
	TB.card(m, me, 182, "hand")
	m.players[me]["ap"] = 4
	host.broadcast()
	await create_timer(4.0).timeout                            # let the coin flip finish
	await _shot("00_board_new_cards")

	var t := await _inspect_slot(me, "unit", 0, "01_inspect_necro")
	_check("Necro inspector shows its Fusion materials", t.contains("Mage Unit + Debuffed Unit"))
	_check("Necro inspector shows its doubling ability", t.contains("double the Debuffs"))
	t = await _inspect_slot(me, "unit", 1, "02_inspect_drako")
	_check("Drako inspector shows its Arcane requirement and Power ability", t.contains("total exactly") and t.contains("Destroy a Power"))
	t = await _inspect_slot(me, "unit", 2, "03_inspect_fence")
	_check("Fence inspector shows the lower-case apply", t.contains("you can apply 1 Rune"))
	t = await _inspect_slot(me, "unit", 3, "04_inspect_chaos_witch_dark")
	_check("Chaos Witch is Dark", t.contains("Dark") and not t.contains("Necrotic"))
	t = await _inspect_slot(me, "unit", 4, "05_inspect_bronze_salaman")
	_check("Bronze Salaman reads Units you Control", t.contains("Units you Control"))
	t = await _inspect_slot(foe, "unit", 0, "06_inspect_light_basic")
	_check("A basic unit reads Light", t.contains("Light") and not t.contains("Heavenly"))
	t = await _inspect_slot(foe, "unit", 2, "07_inspect_tag_team_w")
	_check("Tag Team - W reads Spell/Trap", t.contains("Destroy all Spell/Trap cards in this Column"))
	t = await _inspect_slot(me, "power", 0, "08_inspect_options")
	_check("Options reads a start-of-turn draw", t.contains("At the start of your turn: draw a card"))

	# The action row of Necro and Drako carries the new short labels.
	var w: CardWidget = gs.fx_slot_item(me, "unit", 0)["widget"]
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	var labels := []
	if gs.action_row.stack != null:
		for b in gs.action_row.stack.get_children():
			labels.append((b as Button).text)
	_check("Necro offers Spread Debuffs", labels.has("Spread Debuffs"))
	await _shot("09_necro_action_row")
	await _click(Vector2(40, 470), MOUSE_BUTTON_LEFT)
	w = gs.fx_slot_item(me, "unit", 1)["widget"]
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	labels = []
	if gs.action_row.stack != null:
		for b in gs.action_row.stack.get_children():
			labels.append((b as Button).text)
	_check("Drako offers Break Power", labels.has("Break Power"))
	await _shot("10_drako_action_row")
	await _click(Vector2(40, 470), MOUSE_BUTTON_LEFT)

	# Counter Transmutation: the opponent's set Spell is destroyed during my turn.
	m.destroy(bait, "effect", -1, me)
	m.run()
	host.broadcast()
	await _frames(4)
	_check("Counter Transmutation opens a response for its owner", m.pending.get("kind", "") == "trap_response" and int(m.pending["player"]) == foe)
	main._shown_seat = foe
	gs.attach(host.seats[foe])
	await _frames(6)
	await _shot("11_counter_transmutation_response")
	var act := -1
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]).contains("Counter Transmutation"):
			act = i
	host.handle(foe, {"t": "choose", "id": m.pending["id"], "indices": [act]})
	await _frames(6)
	_check("Counter Transmutation offers the Power in Spent", m.pending.get("kind", "") == "select")
	await create_timer(2.5).timeout                            # past the Trap spotlight
	await _shot("12_counter_transmutation_pick_power")
	host.handle(foe, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _frames(4)
	if m.pending.get("kind", "") == "slot":
		await _shot("13_counter_transmutation_power_zone")
		host.handle(foe, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _frames(6)
	var placed := m.power_cards(foe).filter(func(u): return int(m.cards[u]["id"]) == 166)
	_check("Saboteurs Guild was played from Spent", placed.size() == 1)
	main._shown_seat = me
	gs.attach(host.seats[me])
	await _frames(4)

	# Damage and Heal in the log.
	m.change_hp(foe, -6, " (Burn on a test unit)")
	m.change_hp(me, 4, " (Medic on a test unit)")
	host.broadcast()
	await _frames(6)
	var log_text := TB.log_text(m)
	_check("the log speaks of Damage and Healing", log_text.contains("takes 6 Damage") and log_text.contains("heals 4 HP"))
	await _shot("14_log_damage_and_heal")
	print("DB18 SHOTS DONE fails=%d" % fails)
	quit(1 if fails else 0)
