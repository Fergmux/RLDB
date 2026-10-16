extends Control
## Entry scene: main menu, mode setup, and screen switching. Hosts the local
## hot-seat harness, LAN (ENet) dev sessions and Steam lobbies through the same
## SeatClient interface.

var menu: Control
var screen: GameScreen
var local_host: LocalHost
var net: NetSession
var privacy_overlay: PanelContainer
var _shown_seat: int = 0
var _privacy: bool = true
var opts := {"best_of": 3, "deck_mode": "starter", "names": ["Player 1", "Player 2"]}
var status_label: Label


func _ready() -> void:
	theme = UIStyle.make_theme()
	Music.start()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not ("--no-steam" in OS.get_cmdline_user_args()):
		var cfg := Series.load_mode_config()
		SteamBridge.init(int(cfg.get("steam_app_id", 480)))
		if SteamBridge.available():
			SteamBridge.steam().join_requested.connect(_on_steam_join_requested)
	_parse_cmdline()
	var launch_lobby := SteamBridge.launch_lobby()
	if launch_lobby != 0 and SteamBridge.available():
		_auto_started = true
		call_deferred("join_steam_lobby", launch_lobby)
	if not _auto_started:
		_show_menu()


## A friend's invite was accepted in the Steam overlay while the game is running.
func _on_steam_join_requested(lobby: int, _friend: int) -> void:
	if net != null and is_instance_valid(net) and net.is_active():
		if net.lobby_id == lobby:
			return
		_confirm_leave("Accepting this invite will leave your current series. Continue?", func(): join_steam_lobby(lobby))
		return
	join_steam_lobby(lobby)


func _confirm_leave(text: String, on_yes: Callable) -> void:
	var p := UIStyle.panel(Color(0.06, 0.07, 0.09, 0.97))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(520, 160)
	p.position = Vector2(540, 380)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UIStyle.label(text, 16, UIStyle.ACCENT, true))
	var row := HBoxContainer.new()
	v.add_child(row)
	var yes := UIStyle.button("Leave and continue", 14)
	yes.pressed.connect(func(): p.queue_free(); on_yes.call())
	row.add_child(yes)
	var no := UIStyle.button("Stay", 14)
	no.pressed.connect(func(): p.queue_free())
	row.add_child(no)


var _auto_started := false


## Command-line hooks for automated runs and screenshots:
##   -- --local [--seed=N] [--draft] [--bo=5]
##   -- --host=PORT / --join=HOST:PORT   (LAN dev transport)
func _parse_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var cfg := opts.duplicate(true)
	for a in args:
		if a.begins_with("--seed="):
			cfg["seed"] = int(a.split("=")[1])
		elif a == "--draft":
			cfg["deck_mode"] = "draft"
		elif a.begins_with("--bo="):
			cfg["best_of"] = int(a.split("=")[1])
		elif a == "--no-privacy":
			_privacy = false
		if a.ends_with("shots") or a.contains("shots="):
			# Scripted screenshot runs must never create or show the player's real saves.
			SeriesStore.DIR = "user://dev_saves"
	for a in args:
		if a.begins_with("--net-shots="):
			_auto_started = true
			var nd: Node = load("res://src/dev/net_shot_driver.gd").new()
			add_child(nd)
			nd.call_deferred("run", self, a.split("=")[1])
			return
		if a.begins_with("--deckbuilder-shots="):
			_auto_started = true
			call_deferred("_run_deckbuilder_shots", a.split("=", true, 1)[1])
			return
		if a.begins_with("--bot-shots="):
			_auto_started = true
			var bd: Node = load("res://src/dev/bot_driver.gd").new()
			add_child(bd)
			bd.call_deferred("run", self, a.split("=", true, 1)[1])
			return
		if a.begins_with("--f02-shots="):
			_auto_started = true
			var f2: Node = load("res://src/dev/f02_driver.gd").new()
			add_child(f2)
			f2.call_deferred("run", self, a.split("=", true, 1)[1])
			return
		if a.begins_with("--shots="):
			_auto_started = true
			var driver: Node = load("res://src/dev/shot_driver.gd").new()
			add_child(driver)
			driver.call_deferred("run", self, a.split("=")[1])
			return
		if a == "--local":
			_auto_started = true
			call_deferred("_start_local", cfg)
		elif a == "--bot":
			_auto_started = true
			call_deferred("_start_bot", cfg)
		elif a.begins_with("--host="):
			_auto_started = true
			call_deferred("_start_lan_host", int(a.split("=")[1]), cfg)
		elif a.begins_with("--join="):
			_auto_started = true
			var hp := a.split("=")[1].split(":")
			call_deferred("_start_lan_join", hp[0], int(hp[1]))


func _clear_screens() -> void:
	for n in [menu, screen, local_host, privacy_overlay, net]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	menu = null
	screen = null
	local_host = null
	privacy_overlay = null
	net = null


# ---------------------------------------------------------------- menu

const FONT_TITLE := preload("res://assets/fonts/Cinzel-Variable.ttf")
const M_WOOD := Color("2a211a")
const M_DEEP := Color("0e0d0c")
const M_SLATE := Color("1f1c1a")
const M_BRONZE := Color("7a5a30")
const M_GOLD := Color("d4a64a")
const M_PARCH := Color("ece4d2")
const M_DIM := Color("a79c88")


func _title_label(text: String, size: int, color: Color = M_GOLD) -> Label:
	var l := UIStyle.label(text, size, color)
	l.add_theme_font_override("font", FONT_TITLE)
	return l


## A bronze-trimmed slate plate with a heading; returns the VBox to fill.
func _section(parent: Control, heading: String, note: String = "") -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(M_SLATE, M_BRONZE, 1, 6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_title_label(heading, 20, M_GOLD))
	if note != "":
		v.add_child(UIStyle.label(note, 14, M_DIM, true))
	return v


func _hero_button(text: String, primary: bool, tip: String = "") -> Button:
	var b := UIStyle.primary_button(text, 22) if primary else UIStyle.button(text, 21)
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = tip
	return b


func _show_menu() -> void:
	_clear_screens()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = M_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var table := ColorRect.new()
	table.color = M_WOOD
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table.anchor_left = 0.12
	table.anchor_right = 0.88
	table.offset_left = 0
	table.offset_right = 0
	menu.add_child(table)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(780, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	# Title treatment
	var title := _title_label("RLDB", 84, M_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _title_label("A TWO-PLAYER ROGUELIKE DECK BATTLER", 17, M_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var rule := ColorRect.new()
	rule.color = M_BRONZE
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	# Hero: the play actions
	var saves := SeriesStore.list()
	var row_a := HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 12)
	box.add_child(row_a)
	var host_b := _hero_button("Host Steam lobby", true, "Host a lobby and invite a friend through Steam.")
	host_b.pressed.connect(_start_steam_host)
	row_a.add_child(host_b)
	var find_b := _hero_button("Find lobbies", false, "Browse public RLDB lobbies.")
	find_b.pressed.connect(_start_steam_browse)
	row_a.add_child(find_b)
	var row_b := HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 12)
	box.add_child(row_b)
	var bot_b := _hero_button("Play vs Bot", true, "Play a series against the computer.")
	bot_b.pressed.connect(func(): _start_bot(opts.duplicate(true)))
	row_b.add_child(bot_b)
	var local_b := _hero_button("Hot-seat match", false, "Two players, one screen.")
	local_b.pressed.connect(func(): _start_local(opts.duplicate(true)))
	row_b.add_child(local_b)
	var resume_b := _hero_button("Resume saved series", false, ("%d saved series. " % saves.size() if not saves.is_empty() else "") + "Continue an unfinished series.")
	resume_b.disabled = saves.is_empty()
	row_b.add_child(resume_b)
	status_label = UIStyle.label(SteamBridge.describe(), 14, M_DIM, true)
	box.add_child(status_label)
	var saved_holder := VBoxContainer.new()
	saved_holder.visible = false
	box.add_child(saved_holder)
	if not saves.is_empty():
		_add_saved_series(saved_holder, saves)
		resume_b.pressed.connect(func(): saved_holder.visible = not saved_holder.visible)

	# Match options
	var cfg_box := _section(box, "Match options")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	cfg_box.add_child(row)
	row.add_child(UIStyle.label("Best of", 16, M_PARCH))
	var bo := OptionButton.new()
	for n in [1, 3, 5, 7]:
		bo.add_item(str(n), n)
	bo.select([1, 3, 5, 7].find(opts["best_of"]))
	bo.item_selected.connect(func(i): opts["best_of"] = bo.get_item_id(i))
	row.add_child(bo)
	row.add_child(UIStyle.label("   Decks", 16, M_PARCH))
	var dm := OptionButton.new()
	dm.add_item("Starter decks")
	dm.add_item("Draft")
	dm.select(0 if opts["deck_mode"] == "starter" else 1)
	dm.item_selected.connect(func(i): opts["deck_mode"] = "starter" if i == 0 else "draft")
	row.add_child(dm)
	var opts_row := HBoxContainer.new()
	opts_row.add_theme_constant_override("separation", 18)
	cfg_box.add_child(opts_row)
	var pub := CheckBox.new()
	pub.text = "List my lobby publicly"
	pub.add_theme_font_size_override("font_size", 15)
	pub.tooltip_text = "Off: friends-only, joined by invite. On: also visible under Find lobbies."
	pub.button_pressed = opts.get("public_lobby", false)
	pub.toggled.connect(func(on): opts["public_lobby"] = on)
	opts_row.add_child(pub)
	var priv := CheckBox.new()
	priv.text = "Privacy screen between seats (hot-seat)"
	priv.add_theme_font_size_override("font_size", 15)
	priv.button_pressed = _privacy
	priv.toggled.connect(func(on): _privacy = on)
	opts_row.add_child(priv)
	cfg_box.add_child(UIStyle.label("Starter-deck series can also use your saved custom decks (pick one on the deck screen).", 14, M_DIM, true))
	cfg_box.add_child(GameScreen.audio_controls(15))

	# Collection
	var coll := _section(box, "Collection")
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	coll.add_child(crow)
	var builder := UIStyle.button("Deck builder", 17)
	builder.custom_minimum_size = Vector2(0, 44)
	builder.pressed.connect(_show_deck_builder)
	crow.add_child(builder)
	var ledger := UIStyle.button("Card list & implementation ledger", 17)
	ledger.custom_minimum_size = Vector2(0, 44)
	ledger.pressed.connect(_show_card_list)
	crow.add_child(ledger)

	# Advanced / LAN (dev): collapsed by default
	var adv_toggle := UIStyle.button("Advanced / LAN (dev)  +", 15)
	adv_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(adv_toggle)
	var dev_box := _section(box, "Development harness", "Not a substitute for Steam play.")
	dev_box.get_parent().visible = false
	var lan := HBoxContainer.new()
	lan.add_theme_constant_override("separation", 8)
	dev_box.add_child(lan)
	var addr := LineEdit.new()
	addr.text = "127.0.0.1:24680"
	addr.custom_minimum_size = Vector2(220, 0)
	var lan_host := UIStyle.button("Host LAN (ENet)", 15)
	lan_host.pressed.connect(func(): _start_lan_host(int(addr.text.split(":")[-1]), opts.duplicate(true)))
	var lan_join := UIStyle.button("Join LAN", 15)
	lan_join.pressed.connect(func():
		var hp := addr.text.split(":")
		_start_lan_join(hp[0], int(hp[1])))
	lan.add_child(addr)
	lan.add_child(lan_host)
	lan.add_child(lan_join)
	adv_toggle.pressed.connect(func():
		dev_box.get_parent().visible = not dev_box.get_parent().visible
		adv_toggle.text = "Advanced / LAN (dev)  −" if dev_box.get_parent().visible else "Advanced / LAN (dev)  +")
	var quit := UIStyle.button("Quit", 16)
	quit.custom_minimum_size = Vector2(120, 40)
	quit.pressed.connect(func(): get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(quit)


func _new_screen() -> GameScreen:
	screen = GameScreen.new()
	add_child(screen)
	screen.back_to_menu.connect(_on_menu_requested)
	return screen


# ---------------------------------------------------------------- local hot-seat

func _start_local(cfg: Dictionary) -> void:
	_clear_screens()
	local_host = LocalHost.new()
	add_child(local_host)
	local_host.start(cfg)
	_new_screen()
	_shown_seat = 0
	screen.attach(local_host.seats[0])
	for s in local_host.seats:
		s.view_changed.connect(func(_v): call_deferred("_check_hotseat"))


## Series against the bot: you are seat 0, the BotPlayer drives seat 1 (random starter deck).
## The screen never switches seats.
func _start_bot(cfg: Dictionary) -> void:
	_clear_screens()
	cfg["names"] = ["Player", "Bot"]
	local_host = LocalHost.new()
	add_child(local_host)
	local_host.start(cfg)
	_new_screen()
	_shown_seat = 0
	screen.attach(local_host.seats[0])
	var bot := BotPlayer.new()
	local_host.add_child(bot)
	bot.start(local_host, 1, screen)


## Hot-seat: when the other seat must act, hand the screen over (optionally behind
## a privacy screen so the next player does not see the previous player's hand).
func _check_hotseat() -> void:
	if local_host == null or screen == null:
		return
	var want := local_host.acting_seat()
	if want == _shown_seat:
		return
	# Let the current seat's end-of-turn animation finish before handing the screen over.
	var wait_ms: int = screen.fx_hold_until - Time.get_ticks_msec()
	if wait_ms > 0:
		get_tree().create_timer(float(wait_ms) / 1000.0).timeout.connect(_check_hotseat, CONNECT_ONE_SHOT)
		return
	if _privacy:
		_show_privacy(want)
	else:
		_switch_seat(want)


func _switch_seat(seat: int) -> void:
	_shown_seat = seat
	screen.attach(local_host.seats[seat])


func _show_privacy(seat: int) -> void:
	if privacy_overlay != null and is_instance_valid(privacy_overlay):
		privacy_overlay.queue_free()
	privacy_overlay = UIStyle.panel(Color(0.05, 0.05, 0.07, 1.0))
	privacy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(privacy_overlay)
	var c := CenterContainer.new()
	privacy_overlay.add_child(c)
	var v := VBoxContainer.new()
	c.add_child(v)
	v.add_child(UIStyle.label("Pass to %s" % local_host.series.names[seat], 36, UIStyle.ACCENT))
	v.add_child(UIStyle.label("Hidden information is protected between seats.", 14, UIStyle.MUTED))
	var b := UIStyle.button("I am %s — continue" % local_host.series.names[seat], 18)
	b.pressed.connect(func():
		privacy_overlay.queue_free()
		privacy_overlay = null
		_switch_seat(seat))
	v.add_child(b)


# ---------------------------------------------------------------- network sessions

func _start_lan_host(port: int, cfg: Dictionary) -> void:
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	var err := net.host_enet(port, cfg)
	_new_screen()
	screen.attach(net.local_seat)
	if err != "":
		net.local_seat.status_changed.emit(err)


func _start_lan_join(host: String, port: int) -> void:
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	var err := net.join_enet(host, port)
	_new_screen()
	screen.attach(net.local_seat)
	if err != "":
		net.local_seat.status_changed.emit(err)


func _start_steam_host(cfg: Dictionary = {}) -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	net.host_steam(cfg if not cfg.is_empty() else opts.duplicate(true))
	_new_screen()
	screen.attach(net.local_seat)


func _start_steam_browse() -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	_new_screen()
	screen.attach(net.local_seat)
	net.lobbies_found.connect(_show_lobbies)
	net.browse_steam()


func _show_lobbies(lobbies: Array) -> void:
	var panel := UIStyle.panel(Color(0.06, 0.07, 0.09, 0.97))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 300)
	panel.position = Vector2(540, 300)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UIStyle.label("RLDB lobbies", 20, UIStyle.ACCENT))
	if lobbies.is_empty():
		v.add_child(UIStyle.label("No lobbies found. Ask a friend to host and invite you through Steam.", 14, UIStyle.MUTED, true))
	for l in lobbies:
		var b := UIStyle.button("Join %s's lobby (%d/2)" % [l["host"], l["members"]], 14)
		b.pressed.connect(func(): panel.queue_free(); join_steam_lobby(l["id"]))
		v.add_child(b)
	var back := UIStyle.button("Back to menu", 13)
	back.pressed.connect(func(): panel.queue_free(); _show_menu())
	v.add_child(back)


func join_steam_lobby(lobby_id: int) -> void:
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	_new_screen()
	screen.attach(net.local_seat)
	net.join_steam(lobby_id)


# ---------------------------------------------------------------- card list

func _show_card_list() -> void:
	_clear_screens()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	menu.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var counts := {}
	for d in CardDB.all():
		var s := CardScripts.support_status(d["id"])
		counts[s] = counts.get(s, 0) + 1
	var t := UIStyle.label("All %d cards · support: %s" % [CardDB.all().size(), str(counts)], 18, UIStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := UIStyle.button("Back", 14)
	back.pressed.connect(_show_menu)
	head.add_child(back)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	sc.add_child(flow)
	var gs := GameScreen.new()
	for d in CardDB.all():
		var summary := Series._card_summary(d["id"])
		var w := CardWidget.new().setup(gs._summary_view(summary), "big")
		flow.add_child(w)
	gs.free()


func _on_menu_requested() -> void:
	if net != null and is_instance_valid(net) and net.is_active():
		_confirm_leave("Leave this online series? Your opponent will be left waiting.", _show_menu)
		return
	_show_menu()



# ---------------------------------------------------------------- saved series (P-02)

## Lists unfinished series saved at between-game checkpoints, each resumable as
## hot-seat, LAN host or Steam host (the opponent rejoins as before).
func _add_saved_series(box: VBoxContainer, saves: Array) -> void:
	var sec := _section(box, "Resume a saved series")
	for sv in saves.slice(0, 4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		sec.add_child(row)
		var info := UIStyle.label("%s vs %s · %d–%d · best of %d · %s" % [sv["names"][0], sv["names"][1], sv["scores"][0], sv["scores"][1],
			sv["best_of"], String(sv["saved_at"]).replace("T", " ")], 14, M_DIM)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var id: String = sv["id"]
		var hs := UIStyle.button("Hot-seat", 14)
		hs.pressed.connect(func(): _resume(id, "local"))
		row.add_child(hs)
		var lan := UIStyle.button("Host LAN", 14)
		lan.pressed.connect(func(): _resume(id, "lan"))
		row.add_child(lan)
		var st := UIStyle.button("Host Steam", 14)
		st.disabled = not SteamBridge.available()
		st.pressed.connect(func(): _resume(id, "steam"))
		row.add_child(st)
		var del := UIStyle.button("Delete", 14)
		del.pressed.connect(func(): _confirm_leave("Delete this saved series?", func(): SeriesStore.delete(id); _show_menu()))
		row.add_child(del)


func _resume(id: String, how: String) -> void:
	var s := SeriesStore.load_series(id)
	if s == null:
		status_label.text = "That save could not be read."
		return
	var cfg := {"resume": s}
	match how:
		"local": _start_local(cfg)
		"lan": _start_lan_host(24680, cfg)
		"steam": _start_steam_host(cfg)


func _show_deck_builder() -> void:
	_clear_screens()
	var db: Control = load("res://src/ui/deck_builder.gd").new()
	menu = db
	add_child(db)
	db.connect("closed", _show_menu)


# ---------------------------------------------------------------- dev: deck builder screenshots

func _shot_to(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## `-- --deckbuilder-shots=<dir>`: drives the builder, saves a deck, captures, quits.
func _run_deckbuilder_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 5:
		await get_tree().process_frame
	_show_menu()
	for i in 4:
		await get_tree().process_frame
	await _shot_to(dir, "01_main_menu")
	_show_deck_builder()
	for i in 4:
		await get_tree().process_frame
	var db: DeckBuilder = menu as DeckBuilder
	await _shot_to(dir, "02_builder_empty")
	db.set_filters("dragon")
	db.deck_name_edit.text = "Screenshot Deck"
	var added := 0
	for d in CardDB.all():
		if added >= 10:
			break
		if DeckBuilder.matches(d, "dragon", "", "", "", ""):
			db.add_card(int(d["id"]), 2 if added < 2 else 1)
			added += 1
	for cost in ["kind:fusion", "kind:ritual", "kind:arcane"]:
		for d in CardDB.all():
			if DeckBuilder.matches(d, "", "", "", "", cost):
				db.add_card(int(d["id"]))
				break
	for d in CardDB.all():
		if d["category"] in ["spell", "trap", "power"]:
			db.add_card(int(d["id"]))
			if db.counts.size() > 18:
				break
	for d in CardDB.all():
		if d["category"] == "fusion":
			db.show_preview(int(d["id"]))
			break
	for i in 3:
		await get_tree().process_frame
	await _shot_to(dir, "03_builder_search_dragon")
	db.set_filters("")
	db._cat_opt.select(db._cat_opt.item_count - 1)
	db._refresh_catalogue()
	db.save()
	for i in 3:
		await get_tree().process_frame
	await _shot_to(dir, "04_builder_saved_filter_arcane")
	DeckStore.delete_deck("Screenshot Deck")  # leave the player's decks untouched
	get_tree().quit()
