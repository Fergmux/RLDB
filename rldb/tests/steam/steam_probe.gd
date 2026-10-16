extends SceneTree
## Real-environment Steam probe (single account). Not part of the automated suite.
##   godot --path rldb -s res://tests/steam/steam_probe.gd -- <evidence dir>
## Verifies: init with App ID 480 (at engine startup, so the overlay is injected), friends-only lobby creation + lobby data, host socket,
## invite overlay call, public lobby creation and discovery through the lobby search,
## lobby membership/ownership, and leaving. Writes a JSON report next to a screenshot.

var s: Object
var out_dir := ""
var report := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else "user://steam_probe"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait_signal(sig: Signal, seconds: float) -> Array:
	var got := []
	var cb := func(a = null, b = null, c = null, d = null):
		got.append([a, b, c, d])
	sig.connect(cb)
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while got.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	sig.disconnect(cb)
	return got[0] if not got.is_empty() else []


func _run() -> void:
	SteamBridge.init()
	report["init_ok"] = SteamBridge.available()
	await create_timer(1.0).timeout
	report["overlay_enabled"] = SteamBridge.steam().isOverlayEnabled() if SteamBridge.available() else false
	report["init_message"] = SteamBridge.describe()
	if not SteamBridge.available():
		_finish()
		return
	s = SteamBridge.steam()
	report["persona"] = s.getPersonaName()
	report["app_id"] = s.getAppID()
	report["steam_id_nonzero"] = s.getSteamID() != 0

	# 1. Friends-only lobby, as the game's "Host Steam lobby" does.
	s.createLobby(SteamBridge.LOBBY_FRIENDS_ONLY, 2)
	var r: Array = await _wait_signal(s.lobby_created, 15.0)
	report["friends_lobby_created"] = not r.is_empty() and r[0] == 1
	var lobby: int = r[1] if not r.is_empty() else 0
	if lobby != 0:
		s.setLobbyData(lobby, SteamBridge.LOBBY_GAME_KEY, SteamBridge.LOBBY_GAME_VALUE)
		s.setLobbyData(lobby, "host_name", s.getPersonaName())
		report["lobby_data_roundtrip"] = s.getLobbyData(lobby, SteamBridge.LOBBY_GAME_KEY) == SteamBridge.LOBBY_GAME_VALUE
		report["lobby_owner_is_me"] = s.getLobbyOwner(lobby) == s.getSteamID()
		report["lobby_members"] = s.getNumLobbyMembers(lobby)
		var peer := SteamMultiplayerPeer.new()
		report["host_socket_ok"] = peer.create_host(0) == OK
		s.activateGameOverlayInviteDialog(lobby)
		report["invite_overlay_called"] = true
		for i in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("steam_invite_overlay.png"))
		peer.close()
		s.leaveLobby(lobby)

	# 2. Public lobby discoverable through the lobby search used by "Find lobbies".
	s.createLobby(SteamBridge.LOBBY_PUBLIC, 2)
	r = await _wait_signal(s.lobby_created, 15.0)
	report["public_lobby_created"] = not r.is_empty() and r[0] == 1
	var pub: int = r[1] if not r.is_empty() else 0
	if pub != 0:
		var tag := "probe-%d" % Time.get_ticks_msec()
		s.setLobbyData(pub, SteamBridge.LOBBY_GAME_KEY, SteamBridge.LOBBY_GAME_VALUE)
		s.setLobbyData(pub, "probe", tag)
		await create_timer(2.0).timeout
		s.addRequestLobbyListStringFilter("probe", tag, 0)
		s.requestLobbyList()
		var lr: Array = await _wait_signal(s.lobby_match_list, 15.0)
		var found: Array = lr[0] if not lr.is_empty() and lr[0] != null else []
		report["public_lobby_found_by_search"] = pub in found
		report["search_result_count"] = found.size()
		s.leaveLobby(pub)
	_finish()


func _finish() -> void:
	var f := FileAccess.open(out_dir.path_join("steam_probe_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("STEAM PROBE ", JSON.stringify(report))
	quit()
