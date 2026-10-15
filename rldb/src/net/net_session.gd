class_name NetSession
extends Node
## Two-player network session over Godot's high-level multiplayer, independent of
## transport: ENet (LAN/dev) or SteamMultiplayerPeer (Steam lobbies/invites).
##
## Trust model: the host process is the authority. It owns the Series, validates
## every command and sends each peer only its redacted view. A malicious host can
## see and alter full state; this design does not defend against that (documented).
##
## Continuity: a client disconnect pauses the series (no commands accepted) and the
## host waits indefinitely (P-06). The client reconnects with its session token; the
## host rebinds the seat and resends the current view, including any pending choice.
## Commands carry a per-seat sequence number so a resent command is never applied twice.

signal lobbies_found(lobbies: Array)
signal session_status(text: String)

const HOST_SEAT := 0
const CLIENT_SEAT := 1
const RECONNECT_INTERVAL := 2.0

var is_host := false
var series: Series
var local_seat: NetSeat
var api: SceneMultiplayer
var transport := ""             # "enet" | "steam"
var remote_peer: int = 0        # host: the bound client peer id
var client_token := ""          # host: token the client seat is bound to
var paused := false
var opponent_ever_joined := false
var last_seq := [0, 0]          # host: last applied command seq per seat
var _log_sent := [0, 0]         # host: last log seq sent per seat
var _client_log: Array = []     # client: accumulated log for the current game
var _client_log_game := -1
var _seq := 0                   # client: outgoing command counter
var _token := ""                # client: our session token
var _enet_addr := ""
var _enet_port := 0
var _steam_host_id := 0
var lobby_id := 0
var _reconnect_timer: Timer
var _cfg: Dictionary = {}
var raw_received: Array = []    # client: decoded payloads, kept for redaction tests


func _enter_tree() -> void:
	name = "NetSession"
	add_to_group("net_session")
	api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	api.peer_connected.connect(_on_peer_connected)
	api.peer_disconnected.connect(_on_peer_disconnected)
	api.connected_to_server.connect(_on_connected)
	api.connection_failed.connect(_on_connection_failed)
	api.server_disconnected.connect(_on_server_disconnected)
	local_seat = NetSeat.new()
	local_seat.session = self
	add_child(local_seat)
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = RECONNECT_INTERVAL
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_try_reconnect)
	add_child(_reconnect_timer)


func _exit_tree() -> void:
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer.close()
	if lobby_id != 0 and SteamBridge.available():
		SteamBridge.steam().leaveLobby(lobby_id)


# ---------------------------------------------------------------- hosting

func _start_series(cfg: Dictionary) -> void:
	_cfg = cfg
	is_host = true
	local_seat.seat = HOST_SEAT
	series = Series.new()
	var c := cfg.duplicate(true)
	c["names"] = [cfg.get("host_name", "Host"), "Waiting for opponent"]
	series.setup(c)
	series.changed.connect(_broadcast)


func host_enet(port: int, cfg: Dictionary) -> String:
	transport = "enet"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)
	if err != OK:
		return "Could not host on port %d (error %d)." % [port, err]
	api.multiplayer_peer = peer
	_start_series(cfg)
	_status("Hosting LAN game on port %d. Waiting for an opponent…" % port)
	_broadcast()
	return ""


func host_steam(cfg: Dictionary) -> void:
	transport = "steam"
	var s := SteamBridge.steam()
	cfg["host_name"] = s.getPersonaName()
	_start_series(cfg)
	if not s.lobby_created.is_connected(_on_lobby_created):
		s.lobby_created.connect(_on_lobby_created)
	s.createLobby(SteamBridge.LOBBY_FRIENDS_ONLY, 2)
	_status("Creating a Steam lobby…")
	_broadcast()


func _on_lobby_created(connect: int, id: int) -> void:
	var s := SteamBridge.steam()
	if connect != 1:
		_status("Steam lobby creation failed (result %d)." % connect)
		return
	lobby_id = id
	s.setLobbyData(id, SteamBridge.LOBBY_GAME_KEY, SteamBridge.LOBBY_GAME_VALUE)
	s.setLobbyData(id, "host_name", s.getPersonaName())
	s.setLobbyJoinable(id, true)
	var peer := SteamMultiplayerPeer.new()
	var err := peer.create_host(0)
	if err != OK:
		_status("Could not open the Steam host socket (error %d)." % err)
		return
	api.multiplayer_peer = peer
	_status("Steam lobby ready. Invite a friend from the Steam overlay.")
	invite_friend()
	_broadcast()


func invite_friend() -> void:
	if transport == "steam" and lobby_id != 0 and SteamBridge.available():
		SteamBridge.steam().activateGameOverlayInviteDialog(lobby_id)


# ---------------------------------------------------------------- joining

func join_enet(host: String, port: int) -> String:
	transport = "enet"
	_enet_addr = host
	_enet_port = port
	is_host = false
	local_seat.seat = CLIENT_SEAT
	_token = _load_or_make_token()
	return _connect_enet()


func _connect_enet() -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_enet_addr, _enet_port)
	if err != OK:
		return "Could not connect to %s:%d (error %d)." % [_enet_addr, _enet_port, err]
	api.multiplayer_peer = peer
	_status("Connecting to %s:%d…" % [_enet_addr, _enet_port])
	return ""


func browse_steam() -> void:
	var s := SteamBridge.steam()
	if not s.lobby_match_list.is_connected(_on_lobby_list):
		s.lobby_match_list.connect(_on_lobby_list)
	s.addRequestLobbyListStringFilter(SteamBridge.LOBBY_GAME_KEY, SteamBridge.LOBBY_GAME_VALUE, 0)
	s.addRequestLobbyListDistanceFilter(3)
	s.requestLobbyList()
	_status("Searching for RLDB lobbies…")


func _on_lobby_list(lobbies: Array) -> void:
	var s := SteamBridge.steam()
	var out := []
	for id in lobbies:
		out.append({"id": id, "host": s.getLobbyData(id, "host_name"), "members": s.getNumLobbyMembers(id)})
	lobbies_found.emit(out)
	_status("Found %d lobby(s)." % out.size() if not out.is_empty() else "No lobbies found. Ask a friend to host and invite you.")


func join_steam(id: int) -> void:
	transport = "steam"
	is_host = false
	local_seat.seat = CLIENT_SEAT
	_token = _load_or_make_token()
	var s := SteamBridge.steam()
	if not s.lobby_joined.is_connected(_on_lobby_joined):
		s.lobby_joined.connect(_on_lobby_joined)
	s.joinLobby(id)
	_status("Joining Steam lobby…")


func _on_lobby_joined(id: int, _perm: int, _locked: bool, response: int) -> void:
	if response != SteamBridge.LOBBY_ENTER_SUCCESS:
		_status("Could not join the lobby (response %d)." % response)
		return
	var s := SteamBridge.steam()
	lobby_id = id
	_steam_host_id = s.getLobbyOwner(id)
	if _steam_host_id == s.getSteamID():
		return
	_connect_steam()


func _connect_steam() -> void:
	var peer := SteamMultiplayerPeer.new()
	var err := peer.create_client(_steam_host_id, 0)
	if err != OK:
		_status("Could not connect to the host over Steam (error %d)." % err)
		_reconnect_timer.start()
		return
	api.multiplayer_peer = peer
	_status("Connecting to %s over Steam…" % SteamBridge.name_of(_steam_host_id))


func _load_or_make_token() -> String:
	if _token != "":
		return _token
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]


# ---------------------------------------------------------------- connection events

func _on_peer_connected(id: int) -> void:
	if is_host:
		_status("A player connected; waiting for their hello.")


func _on_peer_disconnected(id: int) -> void:
	if is_host and id == remote_peer:
		remote_peer = 0
		paused = true
		_status("Opponent disconnected. The match is paused until they reconnect.")
		series.game.add_log("Connection: %s disconnected; match paused." % series.names[CLIENT_SEAT]) if series.game != null else null
		_broadcast()


func _on_connected() -> void:
	_status("Connected. Identifying…")
	var player_name: String = SteamBridge.steam().getPersonaName() if transport == "steam" and SteamBridge.available() else "Guest"
	_c2s_hello.rpc_id(1, _token, player_name, _client_log_seq())


func _on_connection_failed() -> void:
	_status("Connection failed. Retrying…")
	_reconnect_timer.start()


func _on_server_disconnected() -> void:
	_status("Lost connection to the host. Reconnecting…")
	var v := local_seat.last_view.duplicate()
	if not v.is_empty():
		v["net"] = {"paused": true, "message": "Connection to the host was lost. Reconnecting…", "opponent_connected": false}
		local_seat.deliver(v)
	api.multiplayer_peer = null
	_reconnect_timer.start()


func _try_reconnect() -> void:
	if is_host:
		return
	if transport == "enet":
		var e := _connect_enet()
		if e != "":
			_reconnect_timer.start()
	elif transport == "steam":
		_connect_steam()


## Test hook: drop the client's connection as if the network failed.
func simulate_drop() -> void:
	if api.multiplayer_peer != null:
		api.multiplayer_peer.close()


func _client_log_seq() -> int:
	return 0 if _client_log.is_empty() else _client_log[-1]["seq"]


# ---------------------------------------------------------------- RPCs

@rpc("any_peer", "call_remote", "reliable")
func _c2s_hello(token: String, player_name: String, have_log_seq: int) -> void:
	if not is_host:
		return
	var sender := api.get_remote_sender_id()
	if remote_peer != 0 and remote_peer != sender:
		_s2c_error.rpc_id(sender, "This game already has two players.")
		return
	if client_token != "" and token != client_token:
		_s2c_error.rpc_id(sender, "This seat belongs to another player.")
		return
	var rejoin := client_token != ""
	client_token = token
	remote_peer = sender
	paused = false
	opponent_ever_joined = true
	if not rejoin:
		series.names[CLIENT_SEAT] = player_name.substr(0, 24)
		if series.game != null:
			series.game.players[CLIENT_SEAT]["name"] = series.names[CLIENT_SEAT]
	elif series.game != null:
		series.game.add_log("Connection: %s reconnected; match resumed." % series.names[CLIENT_SEAT])
	_log_sent[CLIENT_SEAT] = have_log_seq if rejoin else 0
	_s2c_welcome.rpc_id(sender, last_seq[CLIENT_SEAT])
	_status("%s %s." % [series.names[CLIENT_SEAT], "reconnected" if rejoin else "joined"])
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func _c2s_command(seq: int, cmd: Dictionary) -> void:
	if not is_host:
		return
	if api.get_remote_sender_id() != remote_peer:
		return
	_apply(CLIENT_SEAT, seq, cmd)


@rpc("authority", "call_remote", "reliable")
func _s2c_view(data: PackedByteArray, raw_size: int) -> void:
	var v: Dictionary = bytes_to_var(data.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	raw_received.append(v.duplicate(true))
	if raw_received.size() > 8:
		raw_received.pop_front()
	_merge_client_log(v)
	if paused:
		pass
	_status("")
	local_seat.deliver(v)


## Tells a (re)connecting client the last command sequence the host applied, so a
## restarted client never reuses a sequence number and resent commands stay idempotent.
@rpc("authority", "call_remote", "reliable")
func _s2c_welcome(host_last_seq: int) -> void:
	_seq = maxi(_seq, host_last_seq)


@rpc("authority", "call_remote", "reliable")
func _s2c_error(text: String) -> void:
	local_seat.status_changed.emit(text)


## Reassembles the full log from incremental deltas.
func _merge_client_log(v: Dictionary) -> void:
	if not v.has("match"):
		return
	var g: int = v["game_no"]
	if g != _client_log_game or v.get("log_reset", false):
		_client_log = []
		_client_log_game = g
	var last := _client_log_seq()
	for e in v["match"]["log"]:
		if e["seq"] > last:
			_client_log.append(e)
	v["match"]["log"] = _client_log.duplicate()


# ---------------------------------------------------------------- host command handling

func _apply(seat: int, seq: int, cmd: Dictionary) -> void:
	if seq <= last_seq[seat]:
		# Duplicate or replayed command (e.g. resent after reconnect): never re-apply.
		_send_view(seat)
		return
	last_seq[seat] = seq
	if paused or (remote_peer == 0 and series.stage == Series.STAGE_GAME):
		_error(seat, "The match is paused until your opponent reconnects.")
		return
	var err := series.submit(seat, cmd)
	if err != "":
		_error(seat, err)
	_broadcast()


func _error(seat: int, text: String) -> void:
	if seat == HOST_SEAT:
		local_seat.status_changed.emit(text)
	elif remote_peer != 0:
		_s2c_error.rpc_id(remote_peer, text)


func _broadcast() -> void:
	if not is_host:
		return
	_send_view(HOST_SEAT)
	_send_view(CLIENT_SEAT)


func _net_info(seat: int) -> Dictionary:
	var connected := remote_peer != 0
	var msg := ""
	if not connected:
		msg = "Opponent disconnected — match paused, waiting for them to reconnect." if opponent_ever_joined else "Waiting for an opponent to join…"
	return {"paused": not connected and opponent_ever_joined, "opponent_connected": connected, "message": msg if seat == HOST_SEAT else "",
		"transport": transport, "is_host": seat == HOST_SEAT, "lobby": lobby_id}


func _send_view(seat: int) -> void:
	var v := series.view_for(seat)
	v["net"] = _net_info(seat)
	if seat == HOST_SEAT:
		local_seat.deliver(v)
		return
	if remote_peer == 0:
		return
	if v.has("match"):
		var since: int = _log_sent[seat]
		var full: Array = v["match"]["log"]
		if not full.is_empty() and full[-1]["seq"] < since:
			since = 0   # new game: logs restart
			v["log_reset"] = true
		v["match"]["log"] = full.filter(func(e): return e["seq"] > since)
		if not full.is_empty():
			_log_sent[seat] = full[-1]["seq"]
	var raw := var_to_bytes(v)
	_s2c_view.rpc_id(remote_peer, raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size())


# ---------------------------------------------------------------- client sending

func send_from_local(cmd: Dictionary) -> void:
	if is_host:
		last_seq[HOST_SEAT] += 1
		_apply(HOST_SEAT, last_seq[HOST_SEAT], cmd)
		return
	if api.multiplayer_peer == null or api.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		local_seat.status_changed.emit("Not connected to the host.")
		return
	_seq += 1
	_c2s_command.rpc_id(1, _seq, cmd)


## Test hook: resend a command with an explicit (possibly duplicate) sequence number.
func send_raw(seq: int, cmd: Dictionary) -> void:
	_c2s_command.rpc_id(1, seq, cmd)


func _status(text: String) -> void:
	session_status.emit(text)
	if text != "":
		local_seat.status_changed.emit(text) if text.begins_with("Could not") or text.begins_with("Lost") else null


class NetSeat:
	extends SeatClient
	var session: NetSession

	func send(cmd: Dictionary) -> void:
		session.send_from_local(cmd)
