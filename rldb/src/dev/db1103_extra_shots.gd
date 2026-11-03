extends SceneTree
## Dev-only windowed evidence for the Extra Deck cards of the 3 November 2026 card database
## (design/card-database-update-2026-11-03.md): Owlbear Druid, Snow Tiger Paladin, Ultimate Dragon
## (?/? off the Field, its tributes' total on it) and Akiramari (+8 per adjacent Basic Unit) on the
## board, in the inspector and in the action row. Saves JPG (q88). Run NOT headless:
##   godot --path rldb -s res://src/dev/db1103_extra_shots.gd -- <absolute output dir> [WxH]

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
	out_dir = args[0] if args.size() > 0 else "user://db1103"
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
	var img := root.get_texture().get_image()
	if img.get_width() > 1600:                                   # evidence stays at most 1600 px wide
		img.resize(1600, int(round(img.get_height() * 1600.0 / img.get_width())), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)


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


## The action-row button texts of my unit in `slot` (it is clicked, then deselected).
func _action_labels(slot: int, name: String) -> Array:
	var w: CardWidget = gs.fx_slot_item(me, "unit", slot)["widget"]
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	var labels := []
	if gs.action_row.stack != null:
		for b in gs.action_row.stack.get_children():
			labels.append((b as Button).text)
	await _shot(name)
	await _click(Vector2(40, 470), MOUSE_BUTTON_LEFT)
	return labels


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 9})
	host.handle(1, {"t": "pick_starter", "index": 2})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	me = m.active
	var foe := 1 - me
	main._shown_seat = me
	gs.attach(host.seats[me])
	await _frames(4)

	# Stage the four cards. Owlbear protects Snow Tiger (column 1); Akiramari has two Basic Units
	# beside it; Ultimate Dragon takes its stats from three tributed Dragons through the real op.
	TB.unit(m, me, 189, 0)                                     # Owlbear Druid
	TB.unit(m, me, 1, 1)                                       # Basic Mage: adjacent to Akiramari
	var aki := TB.unit(m, me, 146, 2)                          # Akiramari
	TB.unit(m, me, 190, 3)                                     # Snow Tiger Paladin, behind Owlbear
	var ud := TB.unit(m, me, 151, 4)                           # Ultimate Dragon
	TB.unit(m, me, 120, 5)                                     # Basic Mage (Earth): adjacent to Akiramari
	m.cards[ud]["fusion_mats"] = [{"atk": 18, "def": 8, "type": "Water", "race": "Dragon"},
		{"atk": 20, "def": 6, "type": "Fire", "race": "Dragon"}, {"atk": 8, "def": 8, "type": "Light", "race": "Dragon"}]
	m.push_frame(m.make_frame(ud, me, [{"op": "mirrorflesh", "keep_type": true}], "Ultimate Dragon"))
	m.run()
	var ud_extra := TB.card(m, me, 151, "extra")
	TB.unit(m, foe, 125, 0)                                    # Basic Mage, Dark: an opposing Mage
	TB.unit(m, foe, 108, 1)                                    # Basic Beast, Light
	TB.set_card(m, me, 45, 0)                                  # a set Trap of mine
	m.players[me]["ap"] = 4
	host.broadcast()
	await create_timer(4.0).timeout                            # let the coin flip finish
	await _shot("00_board_extra_deck_cards")
	_check("Akiramari is 40/40 with two adjacent Basic Units", m.atk_of(aki) == 40 and m.def_of(aki) == 40)
	_check("Ultimate Dragon is 46/22 from its tributes", m.atk_of(ud) == 46 and m.def_of(ud) == 22)

	var t := await _inspect_slot(me, "unit", 0, "01_inspect_owlbear_druid")
	_check("Owlbear inspector shows its materials and Race lock", t.contains("Beast Unit + Physical Unit") and t.contains("cannot attack"))
	t = await _inspect_slot(me, "unit", 3, "02_inspect_snow_tiger_paladin")
	_check("Snow Tiger inspector shows its materials and Trap text", t.contains("Beast Unit + Light Unit") and t.contains("your Traps cost -1 AP"))
	t = await _inspect_slot(me, "unit", 4, "03_inspect_ultimate_dragon_field")
	_check("Ultimate Dragon on the Field shows 46", t.contains("46"))
	t = await _inspect_slot(me, "unit", 2, "04_inspect_akiramari")
	_check("Akiramari inspector shows three Basic materials", t.contains("Basic Unit + Basic Unit + Basic Unit"))

	# Off the Field, Ultimate Dragon reads ?/? (its stats come from the tributes).
	CardInspector.open(gs, MatchView.card_view(m, ud_extra, me))
	await _frames(4)
	t = _inspector_text()
	await _shot("05_inspect_ultimate_dragon_extra_deck")
	_check("Ultimate Dragon in the Extra Deck reads ?", t.contains("?"))
	CardInspector.close_topmost()
	await _frames(3)

	var labels := await _action_labels(0, "06_owlbear_action_row")
	_check("Owlbear offers Change Race", labels.has("Change Race"))
	labels = await _action_labels(2, "07_akiramari_action_row")
	_check("Akiramari offers Call Basic Unit", labels.has("Call Basic Unit"))

	# The Race choice prompt (cancelled afterwards).
	host.handle(me, {"t": "ability", "uid": m.players[me]["units"][0], "idx": 0})
	await _frames(6)
	_check("Owlbear asks for a Race", String(m.pending.get("prompt", "")) == "Choose a Race.")
	await _shot("08_owlbear_race_prompt")
	host.handle(me, {"t": "cancel", "id": m.pending.get("id", -1)})
	await _frames(4)
	print("DB1103 EXTRA SHOTS DONE fails=%d" % fails)
	quit(1 if fails else 0)
