class_name SessionLauncher
extends RefCounted
## Starts and owns the live play session under the Main scene: the LocalHost (hot-seat, bot) or
## NetSession (LAN, Steam), the GameScreen attached to the local seat, and the hot-seat privacy
## screen between turns. All nodes are added to `root` (Main) so they inherit its theme; Main
## clears the previous screens before calling a `start_*` method.

## The game screen asked to go back to the menu (may need a "leave online series?" confirm).
signal menu_requested
## The game screen already confirmed leaving; go straight back to the menu.
signal leave_requested

## Host of the local play session.
var local_host: LocalHost
## Network session.
var net: NetSession
## The game screen of the running match.
var screen: GameScreen
## Hot-seat hand-over cover.
var privacy_overlay: PanelContainer
## Seat currently shown on the hot-seat screen.
var shown_seat: int = 0
## Seconds between hot-seat hand-over checks while the game-end presentation runs.
const GAME_END_RECHECK := 0.25

var _root: Control
var _options: SessionOptions


func _init(root: Control, options: SessionOptions) -> void:
	_root = root
	_options = options


## Frees every session node (screen, host, privacy screen, network session) and forgets them.
func clear() -> void:
	for n in [screen, local_host, privacy_overlay, net]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	screen = null
	local_host = null
	privacy_overlay = null
	net = null


## True while an online (LAN/Steam) session is connected or connecting.
func has_active_net() -> bool:
	return net != null and is_instance_valid(net) and net.is_active()


# ---------------------------------------------------------------- local

## Hot-seat series: both seats on this screen, handed over between turns (see `_check_hotseat`).
func start_local(cfg: Dictionary) -> void:
	cfg["mode"] = "local"
	_start_local_host(cfg)
	for s in local_host.seats:
		s.view_changed.connect(func(_v): _check_hotseat.call_deferred())


## Series against the bot: you are seat 0, the BotPlayer drives seat 1 (random starter deck).
## The screen never switches seats.
func start_bot(cfg: Dictionary) -> void:
	cfg["names"] = ["Player", "Bot"]
	cfg["mode"] = "bot"
	_start_local_host(cfg)
	var bot := BotPlayer.new()
	local_host.add_child(bot)
	bot.start(local_host, 1, screen)


## Guided tutorial (F03-15): a TutorialHost runs the scripted lesson; the game screen and its
## TutorialOverlay are rebuilt for every lesson (start, restart, next lesson).
func start_tutorial(lesson: int = 0) -> void:
	var host := TutorialHost.new()
	local_host = host
	_root.add_child(host)
	host.lesson_loaded.connect(func(_i): _tutorial_screen(host))
	host.start({"lesson": lesson})


func _tutorial_screen(host: TutorialHost) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	_new_screen()
	shown_seat = 0
	TutorialOverlay.attach_to(screen, host)
	screen.attach(host.seats[0])


func _start_local_host(cfg: Dictionary) -> void:
	local_host = LocalHost.new()
	_root.add_child(local_host)
	local_host.start(cfg)
	_new_screen()
	shown_seat = 0
	screen.attach(local_host.seats[0])


## Shows seat `seat`'s view on the screen (hot-seat hand-over).
func switch_seat(seat: int) -> void:
	shown_seat = seat
	screen.attach(local_host.seats[seat])


## Hot-seat: when the other seat must act, hand the screen over (optionally behind a privacy
## screen so the next player does not see the previous player's hand).
func _check_hotseat() -> void:
	if local_host == null or screen == null:
		return
	var want := local_host.acting_seat()
	if want == shown_seat:
		return
	# Let the current seat's end-of-turn animation finish before handing the screen over.
	var wait_ms: int = screen.fx_hold_until - Time.get_ticks_msec()
	if wait_ms > 0:
		_root.get_tree().create_timer(float(wait_ms) / 1000.0).timeout.connect(_check_hotseat, CONNECT_ONE_SHOT)
		return
	# Likewise the victory / defeat presentation (a click skips it, which ends the hold).
	if screen.fx != null and screen.fx.game_end_hold:
		_root.get_tree().create_timer(GAME_END_RECHECK).timeout.connect(_check_hotseat, CONNECT_ONE_SHOT)
		return
	if _options.privacy:
		show_privacy(want)
	else:
		switch_seat(want)


## Covers the screen with "Pass to <name>" until that player confirms, then switches seat.
func show_privacy(seat: int) -> void:
	if privacy_overlay != null and is_instance_valid(privacy_overlay):
		privacy_overlay.queue_free()
	privacy_overlay = UIStyle.panel(Color(0.05, 0.05, 0.07, 1.0))
	privacy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(privacy_overlay)
	var c := CenterContainer.new()
	privacy_overlay.add_child(c)
	var v := VBoxContainer.new()
	c.add_child(v)
	var who: String = local_host.series.names[seat]
	v.add_child(UIStyle.label("Pass to %s" % who, 36, UIStyle.ACCENT))
	v.add_child(UIStyle.label("Hidden information is protected between seats.", 14, UIStyle.MUTED))
	var b := UIStyle.button("I am %s — continue" % who, 18)
	b.pressed.connect(func():
		privacy_overlay.queue_free()
		privacy_overlay = null
		switch_seat(seat))
	v.add_child(b)


# ---------------------------------------------------------------- network

## Hosts a LAN (ENet) series on `port`; a failure is shown as the seat's status.
func start_lan_host(port: int, cfg: Dictionary) -> void:
	cfg["mode"] = "lan"
	_new_net()
	_attach_net(net.host_enet(port, cfg))


## Joins a LAN (ENet) series at `host`:`port`; a failure is shown as the seat's status.
func start_lan_join(host: String, port: int) -> void:
	_new_net()
	_attach_net(net.join_enet(host, port))


## Hosts a Steam lobby with `cfg` (the menu options when empty). Steam must be available.
func start_steam_host(cfg: Dictionary) -> void:
	_new_net()
	var hc: Dictionary = cfg if not cfg.is_empty() else _options.series.duplicate(true)
	hc["mode"] = "steam"
	net.host_steam(hc)
	_attach_net()


## Searches public Steam lobbies; `on_lobbies(lobbies: Array)` receives the results. No game
## screen is made: the search runs behind the menu.
func start_steam_browse(on_lobbies: Callable) -> void:
	clear()
	_new_net()
	net.lobbies_found.connect(on_lobbies)
	net.browse_steam()


## Joins Steam lobby `lobby_id` (invite, launch argument or the lobby list).
func join_steam_lobby(lobby_id: int) -> void:
	_new_net()
	_attach_net()
	net.join_steam(lobby_id)


func _new_net() -> void:
	net = NetSession.new()
	_root.add_child(net)


func _attach_net(err: String = "") -> void:
	_new_screen()
	screen.attach(net.local_seat)
	if err != "":
		net.local_seat.status_changed.emit(err)


func _new_screen() -> void:
	screen = GameScreen.new()
	_root.add_child(screen)
	screen.back_to_menu.connect(menu_requested.emit)
	screen.leave_to_menu.connect(leave_requested.emit)
