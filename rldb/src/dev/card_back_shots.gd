extends SceneTree
## Dev-only windowed evidence for L31 (owner, 5 Nov: more card backs in Options > Customisation).
## Run NOT headless, from rldb/:
##   godot --path . -s res://src/dev/card_back_shots.gd -- <abs out dir> [WxH] [--steps=a,b,..]
##       [--prefix=<name>] [--backs=id,id,..] --no-steam
## Steps (default: all): picker (the Card back tab, a hovered tile, a pick), gallery (each back large
## beside the sizes the game draws it at), board (a hot-seat game with face-down cards in both
## Trap/Spell rows, the opponent's hand and the piles, once per back in --backs). Saves JPG q88 (at
## most 1600 px wide) and prints PASS / FAIL lines; quits with the number of failures.
## Scripted runs use the TEST stores (decks, saves and the customisation file); the default back is
## put back at the end.

const DAMAGE_CONVERSION := 47
const MIRROR_FORCE := 46
const SPELL := 41

var out_dir := ""
var sz := Vector2i(1600, 1000)
var steps: Array = ["picker", "gallery", "board"]
var board_backs: Array = ["violet", "wyrm", "tide", "sun", "runes", "grove", "stars"]
var prefix := ""
var main: Node
var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 and not String(args[0]).begins_with("--") else "user://card_back_shots"
	for a in args.slice(1):
		var s := String(a)
		if s.begins_with("--steps="):
			steps = Array(s.split("=", true, 1)[1].split(","))
		elif s.begins_with("--prefix="):
			prefix = s.split("=", true, 1)[1]
		elif s.begins_with("--backs="):
			board_backs = Array(s.split("=", true, 1)[1].split(","))
		elif s.contains("x") and not s.begins_with("--"):
			var p := s.split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(300.0).timeout.connect(func(): print("FAIL watchdog"); quit(99))
	run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", what, "  ", detail)
	else:
		fails += 1
		print("FAIL ", what, "  ", detail)


func _wait(t: float) -> void:
	await create_timer(t).timeout


## Saves the window as `<prefix><name>.jpg` (q88; scaled down to 1600 px wide when larger).
func _shot(name: String, wait: float = 0.6) -> Image:
	await _wait(wait)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_save(img, name)
	return img


func _save(img: Image, name: String) -> void:
	var out := img
	if img.get_width() > 1600:
		out = img.duplicate()
		out.resize(1600, int(round(img.get_height() * 1600.0 / img.get_width())), Image.INTERPOLATE_LANCZOS)
	out.save_jpg(out_dir.path_join(prefix + name + ".jpg"), 0.88)
	print("SHOT ", prefix + name)


## Saves a crop of `img` around `r` (layout px), at 1:1 window pixels (fine detail at 4K).
func _crop(img: Image, r: Rect2, name: String, pad: float = 8.0) -> void:
	var s := float(img.get_height()) / root.get_visible_rect().size.y
	var px := Rect2i(Rect2(r.position * s, r.size * s).grow(pad)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if px.size.x <= 0 or px.size.y <= 0:
		return
	_save(img.get_region(px), name)


func _move_mouse(p: Vector2) -> void:
	var wp := root.get_final_transform() * p
	Input.warp_mouse(wp)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)


func run() -> void:
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	_check("deck store uses the TEST path", DeckStore.PATH == DeckStore.TEST_PATH, DeckStore.PATH)
	_check("customisation uses the TEST path", Customisation.settings_path() == Customisation.TEST_PATH, Customisation.settings_path())
	if DeckStore.PATH != DeckStore.TEST_PATH or Customisation.settings_path() != Customisation.TEST_PATH:
		quit(1)
		return
	Customisation.set_card_back(Customisation.DEFAULT_CARD_BACK)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	if "gallery" in steps:
		await _gallery()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.2)
	DisplayServer.window_set_size(sz)
	await _wait(1.2)
	if "picker" in steps:
		await _picker()
	if "board" in steps:
		await _board()
	Customisation.set_card_back(Customisation.DEFAULT_CARD_BACK)
	print("CARD BACK SHOTS DONE fails=%d" % fails)
	quit(fails)


# ---------------------------------------------------------------- picker

## Puts the window back to `sz`, windowed (the settings file is shared with other runs, and the game
## applies its saved window mode when it starts).
func _force_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _wait(0.2)
	DisplayServer.window_set_size(sz)
	await _wait(0.6)


func _picker() -> void:
	await _force_window()
	var mm := main.menu as MainMenu
	mm.pick("@options")
	await _wait(0.6)
	mm.pick("customisation")
	await _wait(0.8)
	var cp := mm.find_child("CustomisationPanel", true, false) as CustomisationPanel
	_check("customisation panel shown", cp != null)
	if cp == null:
		return
	cp.tabs.select("card_back")
	var tag := "%dx%d" % [sz.x, sz.y]
	print("screen ", DisplayServer.screen_get_size(), " window ", DisplayServer.window_get_size(), " visible ", root.get_visible_rect().size)
	var img := await _shot("01_picker_%s" % tag, 0.8)
	var page := cp.find_child("CardBackPage", true, false) as Control
	_crop(img, cp.get_global_rect(), "01b_picker_crop_%s" % tag, 12.0)
	_check("one tile per back", cp.back_tiles.size() == Customisation.CARD_BACKS.size(), str(cp.back_tiles.size()))
	_check("card back page fits the pane", page.get_global_rect().size.y <= cp.tabs.pane.get_global_rect().size.y + 1.0,
		"page %s pane %s" % [page.get_global_rect(), cp.tabs.pane.get_global_rect()])
	# Hover the Crimson Wyrm tile (real input): it lifts and previews in the showcase.
	var t := cp.back_tiles["wyrm"] as Control
	_move_mouse(t.get_global_rect().get_center())
	await _wait(0.1)
	_move_mouse(t.get_global_rect().get_center() + Vector2(1, 1))
	var hov := await _shot("02_picker_hover_%s" % tag, 0.5)
	_check("hovered tile lights up", float(t.get("hover")) > 0.9, "hover=%.2f" % float(t.get("hover")))
	_check("hovered back previews in the showcase", cp.back_preview.back_id == "wyrm", cp.back_preview.back_id)
	_crop(hov, cp.get_global_rect(), "02b_picker_hover_crop_%s" % tag, 12.0)
	# Pick Abyssal Tide (the tile's own click path), then move away.
	var tide := cp.back_tiles["tide"] as Control
	_move_mouse(tide.get_global_rect().get_center())
	await _wait(0.1)
	tide.emit_signal("pressed")
	_move_mouse(Vector2(5, 5))
	var picked := await _shot("03_picker_picked_%s" % tag, 0.6)
	_crop(picked, cp.get_global_rect(), "03b_picker_picked_crop_%s" % tag, 12.0)
	_check("pick saved", Customisation.card_back_id() == "tide", Customisation.card_back_id())
	(cp.back_tiles["violet"] as Control).emit_signal("pressed")
	mm.back_out()
	await _wait(0.6)


# ---------------------------------------------------------------- gallery

## One shot per back: the back large (the picker's showcase art at 2x) beside the sizes the game
## draws it at (inspect "big", hand, field card, the opponent's mini hand card, a deck pile), on the
## table, plus one shot of every back side by side.
func _gallery() -> void:
	var bg := TextureRect.new()
	bg.texture = load(Customisation.table_path())
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, Customisation.table_veil())
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(veil)
	root.add_child(bg)
	var stage := Control.new()
	stage.theme = UIStyle.make_theme()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(stage)
	for b in Customisation.CARD_BACKS:
		var id := String(b["id"])
		Customisation.set_card_back(id)
		for c in stage.get_children():
			c.queue_free()
		await _wait(0.05)
		var big := CustomisationPanel.CardBackPreview.new(Vector2(400, 600))
		big.back_id = id
		big.chosen = false
		big.position = Vector2(60, 60)
		stage.add_child(big)
		var title := UIStyle.label(String(b["name"]), 34, UIStyle.GOLD_HI, false, true)
		title.position = Vector2(520, 60)
		stage.add_child(title)
		var blurb := UIStyle.label(String(b["blurb"]), 18, UIStyle.TEXT)
		blurb.position = Vector2(522, 112)
		stage.add_child(blurb)
		var x := 520.0
		for kind in [["big", Vector2(224, 336)], ["hand", Vector2(120, 180)], ["board", Vector2(85, 128)], ["mini", Vector2(60, 90)]]:
			var w := CardWidget.new()
			w.setup({"hidden": true, "zone": "hand"}, String(kind[0]))
			w.size = kind[1]
			w.custom_minimum_size = kind[1]
			w.position = Vector2(x, 180)
			stage.add_child(w)
			x += (kind[1] as Vector2).x + 36.0
		var pile := PileStack.new()
		pile.title = "Deck"
		pile.size = Vector2(80, 120)
		pile.position = Vector2(520, 560)
		pile.set_pile(18, false)
		stage.add_child(pile)
		var pile2 := PileStack.new()
		pile2.title = "Extra"
		pile2.size = Vector2(80, 120)
		pile2.position = Vector2(636, 560)
		pile2.set_pile(4, false)
		stage.add_child(pile2)
		await _shot("10_back_%s" % id, 0.5)
	# Every back side by side at the hand size and the opponent's mini size.
	for c in stage.get_children():
		c.queue_free()
	await _wait(0.05)
	var x := 50.0
	for b in Customisation.CARD_BACKS:
		var id := String(b["id"])
		var big := CustomisationPanel.CardBackPreview.new(Vector2(200, 300))
		big.back_id = id
		big.chosen = false
		big.position = Vector2(x, 80)
		stage.add_child(big)
		var nm := UIStyle.label(String(b["name"]), 16, UIStyle.GOLD_HI, false, true)
		nm.position = Vector2(x, 395)
		stage.add_child(nm)
		x += 220.0
	await _shot("11_all_backs", 0.5)
	Customisation.set_card_back(Customisation.DEFAULT_CARD_BACK)
	bg.queue_free()
	await _wait(0.2)


# ---------------------------------------------------------------- board

func _board() -> void:
	await _force_window()
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.6)
	var host: LocalHost = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.5)
	var gs: GameScreen = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	await _wait(3.0)
	# Face-down cards in both Trap/Spell rows (one of yours shows its name over the back).
	var m: MatchEngine = host.series.game
	var a := m.active
	var o := 1 - a
	_set_card(m, o, MIRROR_FORCE, 0)
	_set_card(m, o, DAMAGE_CONVERSION, 2)
	_set_card(m, a, SPELL, 1)
	for i in 5:   # the opponent's hand, face down on this screen
		var uid := m._create_instance(1 + i, o)
		m.cards[uid]["zone"] = "hand"
		m.players[o]["hand"].append(uid)
	host.broadcast()
	main._shown_seat = a
	gs.attach(host.seats[a])
	await _wait(1.0)
	for id in board_backs:
		Customisation.set_card_back(String(id))
		_redraw_backs(gs)
		var img := await _shot("20_board_%s" % id, 0.6)
		_crop(img, _union(_nodes_of(gs, "PileStack")), "21_piles_%s" % id, 16.0)
		_crop(img, _opp_hand_rect(gs), "22_opp_hand_%s" % id, 16.0)
	Customisation.set_card_back(Customisation.DEFAULT_CARD_BACK)
	_redraw_backs(gs)


func _set_card(m: MatchEngine, p: int, id: int, col: int) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "backrow"
	m.cards[uid]["slot"] = col
	m.cards[uid]["ctl"] = p
	m.cards[uid]["set_turn"] = m.turn - 1
	m.players[p]["backrow"][col] = uid
	return uid


func _redraw_backs(n: Node) -> void:
	for c in n.find_children("*", "Control", true, false):
		if c is CardWidget or c is PileStack:
			(c as Control).queue_redraw()


func _nodes_of(n: Node, cls: String) -> Array:
	var out := []
	for c in n.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree() and ((cls == "PileStack" and c is PileStack) or (cls == "CardWidget" and c is CardWidget)):
			out.append(c)
	return out


func _union(nodes: Array) -> Rect2:
	var r := Rect2()
	for c in nodes:
		var g := (c as Control).get_global_rect()
		r = g if r.size == Vector2.ZERO else r.merge(g)
	return r


## The opponent's hand: the face-down widgets in the top quarter of the screen.
func _opp_hand_rect(gs: GameScreen) -> Rect2:
	var top := []
	var h := root.get_visible_rect().size.y
	for w in _nodes_of(gs, "CardWidget"):
		var cw := w as CardWidget
		if cw.view.get("hidden", false) and cw.get_global_rect().position.y < h * 0.2:
			top.append(cw)
	return _union(top)
