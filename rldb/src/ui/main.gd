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
	join_steam_lobby(lobby)


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
	for a in args:
		if a.begins_with("--net-shots="):
			_auto_started = true
			var nd: Node = load("res://src/dev/net_shot_driver.gd").new()
			add_child(nd)
			nd.call_deferred("run", self, a.split("=")[1])
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

func _show_menu() -> void:
	_clear_screens()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	box.add_child(UIStyle.label("RLDB", 54, UIStyle.ACCENT))
	box.add_child(UIStyle.label("A two-player roguelike deck builder", 16, UIStyle.MUTED))
	box.add_child(HSeparator.new())
	# Series options
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UIStyle.label("Series: best of", 14))
	var bo := OptionButton.new()
	for n in [1, 3, 5, 7]:
		bo.add_item(str(n), n)
	bo.select([1, 3, 5, 7].find(opts["best_of"]))
	bo.item_selected.connect(func(i): opts["best_of"] = bo.get_item_id(i))
	row.add_child(bo)
	row.add_child(UIStyle.label("   Decks:", 14))
	var dm := OptionButton.new()
	dm.add_item("Starter decks")
	dm.add_item("Draft")
	dm.select(0 if opts["deck_mode"] == "starter" else 1)
	dm.item_selected.connect(func(i): opts["deck_mode"] = "starter" if i == 0 else "draft")
	row.add_child(dm)
	box.add_child(UIStyle.label("Online (Steam)", 18, UIStyle.TEXT))
	var steam_row := HBoxContainer.new()
	box.add_child(steam_row)
	var host_b := UIStyle.button("Host Steam lobby & invite a friend", 15)
	host_b.pressed.connect(_start_steam_host)
	steam_row.add_child(host_b)
	var find_b := UIStyle.button("Find lobbies", 15)
	find_b.pressed.connect(_start_steam_browse)
	steam_row.add_child(find_b)
	status_label = UIStyle.label(SteamBridge.describe(), 12, UIStyle.MUTED, true)
	box.add_child(status_label)
	box.add_child(HSeparator.new())
	box.add_child(UIStyle.label("Development harness (not a substitute for Steam play)", 14, UIStyle.MUTED))
	var dev := HBoxContainer.new()
	box.add_child(dev)
	var local_b := UIStyle.button("Local hot-seat match", 14)
	local_b.pressed.connect(func(): _start_local(opts.duplicate(true)))
	dev.add_child(local_b)
	var priv := CheckBox.new()
	priv.text = "Privacy screen between seats"
	priv.button_pressed = _privacy
	priv.toggled.connect(func(on): _privacy = on)
	dev.add_child(priv)
	var lan := HBoxContainer.new()
	box.add_child(lan)
	var addr := LineEdit.new()
	addr.text = "127.0.0.1:24680"
	addr.custom_minimum_size = Vector2(200, 0)
	var lan_host := UIStyle.button("Host LAN (ENet)", 14)
	lan_host.pressed.connect(func(): _start_lan_host(int(addr.text.split(":")[-1]), opts.duplicate(true)))
	var lan_join := UIStyle.button("Join LAN", 14)
	lan_join.pressed.connect(func():
		var hp := addr.text.split(":")
		_start_lan_join(hp[0], int(hp[1])))
	lan.add_child(addr)
	lan.add_child(lan_host)
	lan.add_child(lan_join)
	box.add_child(HSeparator.new())
	var ledger := UIStyle.button("Card list & implementation ledger", 14)
	ledger.pressed.connect(_show_card_list)
	box.add_child(ledger)
	var quit := UIStyle.button("Quit", 14)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)


func _new_screen() -> GameScreen:
	screen = GameScreen.new()
	add_child(screen)
	screen.back_to_menu.connect(_show_menu)
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


## Hot-seat: when the other seat must act, hand the screen over (optionally behind
## a privacy screen so the next player does not see the previous player's hand).
func _check_hotseat() -> void:
	if local_host == null or screen == null:
		return
	var want := local_host.acting_seat()
	if want == _shown_seat:
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


func _start_steam_host() -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	net.host_steam(opts.duplicate(true))
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
