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
## host waits indefinitely (P-06). The client reconnects with its session token
## (persisted, so a restarted client can reclaim its seat); the host rebinds the seat
## and resends the current view, including any pending choice. Commands carry a
## per-seat sequence number so a resent command is never applied twice.

##
## Spectators (A2): anyone who connects once seat 1 is taken (or reserved for its player) watches.
## The host keeps them in `spectators`, sends each a spectator view (MatchView.build_spectator) and
## refuses every game command they send. A player may allow a spectator to see their cards; the
## permission lives on the host only and ends when the spectator leaves.
##
## Chat (A1): one shared chat for players and spectators. Clients send plain text to the host,
## which cleans it (NetChat), rate-limits each sender and relays it to everyone. Chat is kept in
## memory only and never reaches telemetry, statistics, saves or the log.
##
## Cursor (A2): a player with an allowed spectator sends their mouse position ~18 Hz (unreliable,
## ordered, normalised board space); the host relays it only to the spectators that player allowed
## and that are watching them. Bandwidth: ~12 B payload + RPC/transport overhead, under 1 KB/s.

signal lobbies_found(lobbies: Array)
signal session_status(text: String)
## A chat entry arrived (or was sent here): {"from", "role": "player" | "spectator" | "system" |
## "notice", "seat", "text", "at": local unix time}.
signal chat_received(entry: Dictionary)
## A watched player's cursor moved (spectators only): seat and normalised board position.
signal cursor_received(seat: int, pos: Vector2)

const HOST_SEAT := 0
const CLIENT_SEAT := 1
## A2: most spectators at once. With the two players that is the Steam lobby size (owner brief:
## "2 players + 6 spectators").
const MAX_SPECTATORS := 6
const LOBBY_MAX_MEMBERS := 2 + MAX_SPECTATORS
## ENet slots: the client, a reconnecting client's second link, and the spectators.
const ENET_MAX_PEERS := 2 + MAX_SPECTATORS
## Player-facing refusal of a spectator's game command.
const SPECTATOR_REFUSED := "Spectators watch the game; they cannot take actions."
const SPECTATORS_FULL := "This game already has the most spectators it allows."
## Commands a player may send about spectators (handled by the session, never by the series).
const SPECTATOR_COMMANDS := ["spectator_allow", "spectator_revoke"]
const RECONNECT_INTERVAL := 2.0
const CONNECT_WATCHDOG := 10.0
const MAX_RECONNECT_ATTEMPTS := 150      # ~5 minutes of retries, then report the host as gone
const SESSION_FILE := "user://rldb_sessions.cfg"
const VIEW_SIZE_WARNING := 400000        # Steam reliable messages are limited to 512 KB
const MAX_LOG_RESEND := 400              # full log resends are capped to keep views small

var is_host := false
var series: Series
var local_seat: NetSeat
var api: SceneMultiplayer
var transport := ""             # "enet" | "steam"
var remote_peer: int = 0        # host: the bound client peer id
var client_token := ""          # host: token the client seat is bound to
var client_steam_id := 0        # host (Steam): SteamID the client seat is bound to
var paused := false
var opponent_ever_joined := false
var last_seq := [0, 0]          # host: last applied command seq per seat
var _log_sent := [0, 0]         # host: last log seq sent per seat
var _log_game_sent := [-1, -1]  # host: game number the log deltas refer to
var _client_log: Array = []     # client: accumulated log for the current game
var _client_log_game := -1
var _seq := 0                   # client: outgoing command counter
var _token := ""                # client: our session token
var _session_key := ""          # client: which host/lobby the token belongs to
var _awaiting_view := false     # client: connected but no fresh view yet (sends blocked)
var _reconnect_attempts := 0
var _requested_lobby := 0
var host_gone := false
var _enet_addr := ""
var _enet_port := 0
var _steam_host_id := 0
var lobby_id := 0
var _reconnect_timer: Timer
var _watchdog: Timer
var _claim_tick: Timer
var _cfg: Dictionary = {}
var raw_received: Array = []    # client: decoded payloads, kept for redaction tests
var _disconnected_at := 0       # host: when the client dropped (msec)
var claim_wait_seconds := 60    # P-02: host may claim the current game after this wait
var _resume_token := ""         # host: seat-1 token from a resumed save
## G01 Save and quit: the host left with the series saved (host: about to leave; client: told so).
var host_suspended := false
## G01: the client left with Save and quit (host side; cleared when the client rejoins).
var opponent_suspended := false
## Host: peer id -> {"id", "name", "token", "follow": watched seat, "log_sent", "log_game"}.
var spectators: Dictionary = {}
## Host: per player seat, the spectator ids that player allows to see their cards.
var spectator_allow: Array = [{}, {}]
var _next_spec_id := 1
## Client: this session watches (the host said so); it never sends game commands.
var is_spectator := false
## Client: the host's id for this spectator.
var spectator_id := 0
## Chat history of this session (memory only; NetChat.HISTORY entries).
var chat_log: Array = []
var _chat_guard := NetChat.Guard.new()   # host: per sender; client: its own sends
var _cursor_last := [0, 0]               # host: last relayed cursor per seat (msec)

## Player-facing text for a host that saved and left (shown to the client).
const HOST_SAVED_MESSAGE := "The host saved this series and left. When they resume it, join their game again to continue. Use Menu to return to the main menu."
## Player-facing text for a client that saved and left (shown to the host).
const OPPONENT_SAVED_MESSAGE := "Your opponent saved the series and left. Wait for them to rejoin, or use Menu to save and leave; you can resume it later from Resume on the main menu."


## Seconds until the host may claim the current game (0 = available now).
func claim_seconds_left() -> int:
	if not paused:
		return claim_wait_seconds
	return maxi(0, claim_wait_seconds - (Time.get_ticks_msec() - _disconnected_at) / 1000)


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
	_watchdog = Timer.new()
	_watchdog.wait_time = CONNECT_WATCHDOG
	_watchdog.one_shot = true
	_watchdog.timeout.connect(_on_watchdog)
	add_child(_watchdog)
	# Refreshes the host's claim countdown once a second while the opponent is away.
	_claim_tick = Timer.new()
	_claim_tick.wait_time = 1.0
	_claim_tick.timeout.connect(func():
		if not paused:
			_claim_tick.stop()
			return
		_send_view(HOST_SEAT)
		if claim_seconds_left() == 0:
			_claim_tick.stop())
	add_child(_claim_tick)


func _exit_tree() -> void:
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer.close()
	if lobby_id != 0 and SteamBridge.available():
		SteamBridge.steam().leaveLobby(lobby_id)


## True while this session is part of a live series (used to confirm before leaving).
func is_active() -> bool:
	if is_host:
		return series != null and series.stage != Series.STAGE_OVER
	if is_spectator:
		return false   # a spectator leaves freely: nothing is forfeited
	return not local_seat.last_view.is_empty() and local_seat.last_view.get("stage", "") != "over" and not host_gone


# ---------------------------------------------------------------- hosting

func _start_series(cfg: Dictionary) -> void:
	_cfg = cfg
	is_host = true
	local_seat.seat = HOST_SEAT
	if cfg.has("resume"):
		# Resuming a saved series: the original opponent rejoins (any token on first bind;
		# on Steam the saved SteamID must match).
		series = cfg["resume"]
		client_steam_id = series.seat_ids[CLIENT_SEAT]
		_resume_token = series.client_token
		opponent_ever_joined = false
	else:
		series = Series.new()
		var c := cfg.duplicate(true)
		c["names"] = [cfg.get("host_name", "Host"), "Waiting for opponent"]
		series.setup(c)
	series.checkpoint.connect(func(): SeriesStore.save(series))
	Telemetry.attach_series(series, String(series.cfg.get("mode", "lan")), "host")
	StatsObserver.attach(series, String(series.cfg.get("mode", "lan")), "host")


func host_enet(port: int, cfg: Dictionary) -> String:
	transport = "enet"
	var peer := ENetMultiplayerPeer.new()
	# Slots for the client, its second link while reconnecting (before ENet times out the old one)
	# and the spectators (A2).
	var err := peer.create_server(port, ENET_MAX_PEERS)
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
	# Friends-only lobbies are invite-only and never appear in lobby searches.
	s.createLobby(SteamBridge.LOBBY_PUBLIC if cfg.get("public_lobby", false) else SteamBridge.LOBBY_FRIENDS_ONLY, LOBBY_MAX_MEMBERS)
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
	# Owner feedback 2026-10-18: hosting only opens the lobby; the deck choice screen's
	# "Invite a Steam friend" button opens the invite dialog.
	_status("Steam lobby ready. Invite a friend with the Invite button.")
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
	# One LAN identity per install: a resumed series must recognise the player even if
	# they type the host address differently (localhost vs 127.0.0.1, new port).
	_session_key = "enet"
	_token = _load_or_make_token()
	return _connect_enet()


func _connect_enet() -> String:
	if api.multiplayer_peer != null:
		api.multiplayer_peer.close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_enet_addr, _enet_port)
	if err != OK:
		return "Could not connect to %s:%d (error %d)." % [_enet_addr, _enet_port, err]
	api.multiplayer_peer = peer
	_watchdog.start()
	_status("Connecting to %s:%d…" % [_enet_addr, _enet_port])
	return ""


func browse_steam() -> void:
	var s := SteamBridge.steam()
	if not s.lobby_match_list.is_connected(_on_lobby_list):
		s.lobby_match_list.connect(_on_lobby_list)
	s.addRequestLobbyListStringFilter(SteamBridge.LOBBY_GAME_KEY, SteamBridge.LOBBY_GAME_VALUE, 0)
	s.addRequestLobbyListDistanceFilter(3)
	s.requestLobbyList()
	_status("Searching for public RLDB lobbies…")


func _on_lobby_list(lobbies: Array) -> void:
	var s := SteamBridge.steam()
	var out := []
	for id in lobbies:
		out.append({"id": id, "host": s.getLobbyData(id, "host_name"), "members": s.getNumLobbyMembers(id)})
	lobbies_found.emit(out)
	_status("Found %d lobby(s)." % out.size() if not out.is_empty() else "No public lobbies found. Friends-only lobbies are joined through invites.")


func join_steam(id: int) -> void:
	transport = "steam"
	is_host = false
	local_seat.seat = CLIENT_SEAT
	_requested_lobby = id
	_session_key = "steam:%d" % id
	_token = _load_or_make_token()
	var s := SteamBridge.steam()
	if not s.lobby_joined.is_connected(_on_lobby_joined):
		s.lobby_joined.connect(_on_lobby_joined)
	s.joinLobby(id)
	_status("Joining Steam lobby…")


func _on_lobby_joined(id: int, _perm: int, _locked: bool, response: int) -> void:
	if is_host or id != _requested_lobby:
		return
	if response != SteamBridge.LOBBY_ENTER_SUCCESS:
		local_seat.status_changed.emit("Could not join the lobby (Steam response %d)." % response)
		return
	var s := SteamBridge.steam()
	lobby_id = id
	_steam_host_id = s.getLobbyOwner(id)
	if _steam_host_id == s.getSteamID():
		local_seat.status_changed.emit("Could not join: you are the host of this lobby.")
		return
	_connect_steam()


func _connect_steam() -> void:
	if api.multiplayer_peer != null:
		api.multiplayer_peer.close()
	var peer := SteamMultiplayerPeer.new()
	var err := peer.create_client(_steam_host_id, 0)
	if err != OK:
		_status("Could not connect to the host over Steam (error %d)." % err)
		_reconnect_timer.start()
		return
	api.multiplayer_peer = peer
	_watchdog.start()
	_status("Connecting to %s over Steam…" % SteamBridge.name_of(_steam_host_id))


## The session token (and last command sequence) survive a client restart, so a
## crashed or relaunched client can reclaim its seat.
func _load_or_make_token() -> String:
	if _token != "":
		return _token
	var cf := ConfigFile.new()
	cf.load(SESSION_FILE)
	var tok: String = cf.get_value(_session_key, "token", "")
	_seq = int(cf.get_value(_session_key, "seq", 0))
	if tok == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		tok = "%08x%08x%08x" % [rng.randi(), rng.randi(), rng.randi()]
		cf.set_value(_session_key, "token", tok)
		cf.save(SESSION_FILE)
	return tok


func _save_seq() -> void:
	if _session_key == "":
		return
	var cf := ConfigFile.new()
	cf.load(SESSION_FILE)
	cf.set_value(_session_key, "token", _token)
	cf.set_value(_session_key, "seq", _seq)
	cf.save(SESSION_FILE)


# ---------------------------------------------------------------- connection events

func _on_peer_connected(_id: int) -> void:
	if is_host:
		_status("A player connected; waiting for their hello.")


func _on_peer_disconnected(id: int) -> void:
	if is_host and spectators.has(id):
		_drop_spectator(id)
		_broadcast()
		return
	if is_host and id == remote_peer:
		remote_peer = 0
		paused = true
		_disconnected_at = Time.get_ticks_msec()
		_claim_tick.start()
		_status("Opponent disconnected. The match is paused until they reconnect.")
		if series.game != null:
			series.game.add_log("Connection: %s disconnected; match paused." % series.names[CLIENT_SEAT])
			Telemetry.net_pause(true)
		_broadcast()


func _on_connected() -> void:
	_watchdog.stop()
	_reconnect_attempts = 0
	_awaiting_view = true
	_status("Connected. Identifying…")
	var player_name: String = SteamBridge.steam().getPersonaName() if transport == "steam" and SteamBridge.available() else "Guest"
	_c2s_hello.rpc_id(1, _token, player_name, _client_log_seq())


func _on_connection_failed() -> void:
	_status("Connection failed. Retrying…")
	_reconnect_timer.start()


func _on_server_disconnected() -> void:
	if host_suspended:
		# G01: the host saved and left on purpose; there is nothing to reconnect to.
		host_gone = true
		_reconnect_timer.stop()
		_watchdog.stop()
		var sv := local_seat.last_view.duplicate()
		if not sv.is_empty():
			sv["net"] = {"paused": true, "opponent_connected": false, "host_gone": true, "suspended": true, "message": HOST_SAVED_MESSAGE}
			local_seat.deliver(sv)
		_status("The host saved the series and left.")
		return
	_status("Lost connection to the host. Reconnecting…")
	var v := local_seat.last_view.duplicate()
	if not v.is_empty():
		v["net"] = {"paused": true, "message": "Connection to the host was lost. Reconnecting…", "opponent_connected": false}
		local_seat.deliver(v)
	api.multiplayer_peer = null
	_reconnect_timer.start()


## A connection attempt that neither succeeds nor fails is abandoned and retried.
func _on_watchdog() -> void:
	if is_host or host_gone:
		return
	var peer := api.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		if peer != null:
			peer.close()
		api.multiplayer_peer = null
		_reconnect_timer.start()


func _try_reconnect() -> void:
	if is_host or host_gone:
		return
	_reconnect_attempts += 1
	var owner_now_me := false
	if transport == "steam" and SteamBridge.available() and lobby_id != 0:
		# If the host left, Steam hands lobby ownership to us: the series is gone.
		owner_now_me = SteamBridge.steam().getLobbyOwner(lobby_id) == SteamBridge.my_id()
	if owner_now_me or _reconnect_attempts > MAX_RECONNECT_ATTEMPTS:
		host_gone = true
		var v := local_seat.last_view.duplicate()
		v["net"] = {"paused": true, "opponent_connected": false, "host_gone": true,
			"message": "The host has left, so this series has ended. Use Menu to return to the main menu."}
		local_seat.deliver(v)
		local_seat.status_changed.emit("Lost connection to the host for good.")
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
	# Closing our own peer does not emit server_disconnected locally; run the same path.
	_on_server_disconnected()


func _client_log_seq() -> int:
	return 0 if _client_log.is_empty() else _client_log[-1]["seq"]


# ---------------------------------------------------------------- RPCs

@rpc("any_peer", "call_remote", "reliable")
func _c2s_hello(token: String, player_name: String, have_log_seq: int) -> void:
	if not is_host:
		return
	var sender := api.get_remote_sender_id()
	var steam_id := 0
	if transport == "steam" and api.multiplayer_peer is SteamMultiplayerPeer:
		steam_id = (api.multiplayer_peer as SteamMultiplayerPeer).get_steam_id_for_peer_id(sender)
	if token.length() < 16:
		_s2c_error.rpc_id(sender, "Invalid session token.")
		_kick_later(sender)
		return
	var same_player := token == client_token or (steam_id != 0 and steam_id == client_steam_id)
	if client_token == "":
		# First bind: anyone for a new series; a resumed series accepts only the saved
		# player (same SteamID, or the same persisted session token on LAN).
		if client_steam_id != 0:
			same_player = steam_id == client_steam_id
		elif _resume_token != "":
			same_player = token == _resume_token
		else:
			same_player = true
	if not same_player:
		# A2: seat 1 belongs to (or is reserved for) another player, so this person watches.
		_add_spectator(sender, token, player_name)
		return
	for pid in spectators.keys():
		if spectators[pid]["token"] == token:
			_drop_spectator(pid)   # cannot happen for a real player; never let one token hold both
	if remote_peer != 0 and remote_peer != sender:
		# The rightful player reconnected while the host still holds their old link.
		var old := remote_peer
		remote_peer = 0
		api.multiplayer_peer.disconnect_peer(old)
	var rejoin := client_token != ""
	client_token = token
	series.client_token = token
	if steam_id != 0:
		client_steam_id = steam_id
		series.seat_ids[CLIENT_SEAT] = steam_id
	remote_peer = sender
	paused = false
	opponent_ever_joined = true
	opponent_suspended = false
	if not rejoin and series.game_no == 0:
		series.names[CLIENT_SEAT] = player_name.substr(0, 24)
		if series.game != null:
			series.game.players[CLIENT_SEAT]["name"] = series.names[CLIENT_SEAT]
	elif series.game != null:
		series.game.add_log("Connection: %s reconnected; match resumed." % series.names[CLIENT_SEAT])
		Telemetry.net_pause(false)
	_log_sent[CLIENT_SEAT] = have_log_seq if rejoin else 0
	if not rejoin or have_log_seq == 0:
		_log_game_sent[CLIENT_SEAT] = -1
	_s2c_welcome.rpc_id(sender, last_seq[CLIENT_SEAT])
	_status("%s %s." % [series.names[CLIENT_SEAT], "reconnected" if rejoin else "joined"])
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func _c2s_command(seq: int, cmd: Dictionary) -> void:
	if not is_host:
		return
	var sender := api.get_remote_sender_id()
	if spectators.has(sender):
		_spectator_command(sender, cmd)
		return
	if sender != remote_peer:
		return
	if cmd.has("values"):
		# Remote clients answer choices by option index only; raw uids could be probed.
		_s2c_error.rpc_id(remote_peer, "Invalid choice format.")
		return
	var bad := sanitize_command(cmd)
	if bad != "":
		_s2c_error.rpc_id(remote_peer, bad)
		return
	_apply(CLIENT_SEAT, seq, cmd)


const _INT_FIELDS := ["uid", "idx", "id", "index", "who", "card_id", "from_id", "target"]
const _STR_FIELDS := ["t", "to_type", "to_race", "category", "name", "stance", "basic_type", "basic_race", "mode"]
## Longest list of names a command may carry (a draft setup's category order, F06-05).
const _MAX_NAME_LIST := 16


## Rejects remote commands whose fields have the wrong types (never trust a client).
## Numbers are normalised to int in place. Returns "" when the command is well formed.
static func sanitize_command(cmd: Dictionary) -> String:
	if not (cmd.get("t") is String):
		return "Malformed command."
	for k in cmd.keys():
		var v = cmd[k]
		if k in _STR_FIELDS:
			if not (v is String) or (v as String).length() > 64:
				return "Malformed command."
		elif k in _INT_FIELDS:
			if not (v is int or v is float):
				return "Malformed command."
			cmd[k] = int(v)
		elif k == "indices":
			if not (v is Array) or v.size() > 64:
				return "Malformed command."
			for x in v:
				if not (x is int or x is float):
					return "Malformed command."
			cmd[k] = v.map(func(x): return int(x))
		elif k == "order":
			# F06-05 draft setup: a short list of category names (the authority checks the set).
			if not (v is Array) or v.size() > _MAX_NAME_LIST:
				return "Malformed command."
			for x in v:
				if not (x is String) or (x as String).length() > 32:
					return "Malformed command."
		elif k == "cards":
			if not (v is Array):
				return "Malformed command."
		else:
			return "Unknown command field."
	return ""


@rpc("authority", "call_remote", "reliable")
func _s2c_view(data: PackedByteArray, raw_size: int) -> void:
	var v: Dictionary = bytes_to_var(data.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	raw_received.append(v.duplicate(true))
	if raw_received.size() > 8:
		raw_received.pop_front()
	_merge_client_log(v)
	_awaiting_view = false
	if v.get("net", {}).get("suspended", false):
		host_suspended = true
	_status("")
	local_seat.deliver(v)
	if is_spectator or v.get("spectator", false):
		return   # a spectator's watching is never reported as a played game (telemetry, statistics)
	# After delivery, so the statistics observer can never delay or break the player's view.
	Telemetry.client_view(v, transport)
	StatsObserver.client_view(v, transport)


## A2: the host seated this connection as a spectator with id `id`.
@rpc("authority", "call_remote", "reliable")
func _s2c_spectator(id: int) -> void:
	is_spectator = true
	spectator_id = id
	_status("Spectating.")


## Disconnects a refused peer after its error message has been sent.
func _kick_later(peer_id: int) -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		if api.multiplayer_peer != null and peer_id != remote_peer:
			api.multiplayer_peer.disconnect_peer(peer_id))


## Tells a (re)connecting client the last command sequence the host applied, so a
## restarted client never reuses a sequence number and resent commands stay idempotent.
@rpc("authority", "call_remote", "reliable")
func _s2c_welcome(host_last_seq: int) -> void:
	_seq = maxi(_seq, host_last_seq)
	_save_seq()


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
	if seat == HOST_SEAT and cmd.get("t", "") == "claim_game":
		# P-02/P-06 (user): after the wait the host may claim the current game only.
		if not paused:
			_error(seat, "Your opponent is connected.")
			return
		if claim_seconds_left() > 0:
			_error(seat, "You can claim the game in %d s." % claim_seconds_left())
			return
		last_seq[seat] = seq
		var e := series.award_game(HOST_SEAT, "%s did not reconnect" % series.names[CLIENT_SEAT])
		if e != "":
			_error(seat, e)
		_broadcast()
		return
	if seq <= last_seq[seat]:
		# Duplicate or replayed command (e.g. resent after reconnect): never re-apply.
		_send_view(seat)
		return
	if String(cmd.get("t", "")) in SPECTATOR_COMMANDS:
		last_seq[seat] = seq
		var e := set_spectator_permission(seat, int(cmd.get("id", -1)), String(cmd["t"]) == "spectator_allow")
		if e != "":
			_error(seat, e)
		_broadcast()
		return
	if String(cmd.get("t", "")) == "suspend":
		_suspend(seat, seq)
		return
	# Forfeiting is always possible (the in-game menu's Return to menu / Quit while the opponent
	# is disconnected); everything else waits for the reconnection.
	var forfeit: bool = String(cmd.get("t", "")) == "forfeit_series"
	if not forfeit and (paused or (remote_peer == 0 and series.stage == Series.STAGE_GAME)):
		_error(seat, "The match is paused until your opponent reconnects.")
		return
	last_seq[seat] = seq
	var err := series.submit(seat, cmd)
	if err != "":
		_error(seat, err)
	_broadcast()


## G01 Save and quit from `seat`: allowed between duels only (the series is saved there). The
## save is written again now, nothing is forfeited, and the other seat is told why its opponent
## is leaving. Like forfeiting, it works while the opponent is away.
func _suspend(seat: int, seq: int) -> void:
	last_seq[seat] = seq
	if not series.at_checkpoint() or series.stage == Series.STAGE_OVER:
		_error(seat, "A series can only be saved between duels.")
		return
	SeriesStore.save(series)
	if seat == HOST_SEAT:
		host_suspended = true
	else:
		opponent_suspended = true
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
	for pid in spectators.keys():
		_send_spectator_view(pid)


func _net_info(seat: int) -> Dictionary:
	var connected := remote_peer != 0
	var msg := ""
	if not connected:
		msg = "Opponent disconnected — match paused, waiting for them to reconnect." if opponent_ever_joined else "Waiting for an opponent to join…"
		if opponent_suspended:
			msg = OPPONENT_SAVED_MESSAGE
	return {"paused": not connected and opponent_ever_joined, "opponent_connected": connected, "message": msg if seat == HOST_SEAT else "",
		"transport": transport, "is_host": seat == HOST_SEAT, "lobby": lobby_id,
		"claim_in": claim_seconds_left() if seat == HOST_SEAT and paused else -1,
		"suspended": host_suspended and seat == CLIENT_SEAT,
		"spectators": spectator_list(seat)}


## A2: the spectators as player `seat` sees them: [{"id", "name", "allowed"}] in joining order.
func spectator_list(seat: int) -> Array:
	var out := []
	for pid in spectators.keys():
		var sp: Dictionary = spectators[pid]
		out.append({"id": sp["id"], "name": sp["name"], "allowed": spectator_allow[seat].has(sp["id"])})
	out.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return out


func _send_view(seat: int) -> void:
	var v := series.view_for(seat)
	v["net"] = _net_info(seat)
	if seat == HOST_SEAT:
		local_seat.deliver(v)
		return
	if remote_peer == 0:
		return
	var st := _log_delta(v, _log_sent[seat], _log_game_sent[seat])
	_log_sent[seat] = st[0]
	_log_game_sent[seat] = st[1]
	_ship_view(remote_peer, v, "seat %d" % seat)


## Replaces the full match log in `v` by the entries after `since` (the whole log, with
## "log_reset", when the game changed since `game_sent`). Returns [new since, new game_sent].
func _log_delta(v: Dictionary, since: int, game_sent: int) -> Array:
	if not v.has("match"):
		return [since, game_sent]
	var full: Array = v["match"]["log"]
	if game_sent != series.game_no:
		since = 0   # new game (or first bind): send the whole log and tell the client to reset
		v["log_reset"] = true
		game_sent = series.game_no
	var from := since
	var delta: Array = full.filter(func(e): return e["seq"] > from)
	if delta.size() > MAX_LOG_RESEND:
		delta = delta.slice(delta.size() - MAX_LOG_RESEND)
	v["match"]["log"] = delta
	if not full.is_empty():
		since = full[-1]["seq"]
	return [since, game_sent]


func _ship_view(peer: int, v: Dictionary, who: String) -> void:
	var raw := var_to_bytes(v)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if packed.size() > VIEW_SIZE_WARNING:
		push_warning("NetSession: view for %s is %d bytes compressed (Steam limit 512 KB)." % [who, packed.size()])
	_s2c_view.rpc_id(peer, packed, raw.size())


# ---------------------------------------------------------------- spectators (A2, host)

## Seats `peer` as a spectator (or refuses: too many spectators).
func _add_spectator(peer: int, token: String, player_name: String) -> void:
	for pid in spectators.keys():
		if spectators[pid]["token"] == token and pid != peer:
			# The same person reconnected before the old link timed out.
			_drop_spectator(pid, false)
			api.multiplayer_peer.disconnect_peer(pid)
	if spectators.size() >= MAX_SPECTATORS:
		_s2c_error.rpc_id(peer, SPECTATORS_FULL)
		_kick_later(peer)
		return
	var nm := NetChat.clean_name(player_name)
	spectators[peer] = {"id": _next_spec_id, "name": nm, "token": token, "follow": HOST_SEAT,
		"log_sent": 0, "log_game": -1}
	_next_spec_id += 1
	_s2c_spectator.rpc_id(peer, int(spectators[peer]["id"]))
	_status("%s is spectating." % nm)
	system_chat("%s is now spectating." % nm)
	_broadcast()


## Forgets spectator `peer` and every permission given to them (a spectator who comes back starts
## from the default view again).
func _drop_spectator(peer: int, announce: bool = true) -> void:
	if not spectators.has(peer):
		return
	var sp: Dictionary = spectators[peer]
	spectators.erase(peer)
	for s in 2:
		spectator_allow[s].erase(sp["id"])
	_chat_guard.forget(peer)
	if announce:
		system_chat("%s stopped spectating." % sp["name"])


## The peer id of spectator `id`, or 0.
func _spectator_peer(id: int) -> int:
	for pid in spectators.keys():
		if int(spectators[pid]["id"]) == id:
			return pid
	return 0


## Player `seat` allows (`on`) or stops spectator `id` seeing their cards. Allowing also turns the
## spectator to that player's side, so they see what they were let in to see; stopping reverts them
## to the default (redacted) view at once. Returns "" or a player-facing error.
func set_spectator_permission(seat: int, id: int, on: bool) -> String:
	var pid := _spectator_peer(id)
	if pid == 0:
		return "That spectator has left."
	var sp: Dictionary = spectators[pid]
	var had: bool = spectator_allow[seat].has(id)
	if on == had:
		return ""
	if on:
		spectator_allow[seat][id] = true
		sp["follow"] = seat
		system_chat("%s lets %s see their cards." % [series.names[seat], sp["name"]])
	else:
		spectator_allow[seat].erase(id)
		system_chat("%s no longer lets %s see their cards." % [series.names[seat], sp["name"]])
	sp["log_game"] = -1   # private log lines differ between views: resend the whole log
	return ""


## A spectator's command: only choosing whose side to watch; everything else is refused.
func _spectator_command(peer: int, cmd: Dictionary) -> void:
	var bad := sanitize_command(cmd)
	if bad == "" and String(cmd["t"]) == "spectate_follow" and int(cmd.get("who", -1)) in [0, 1]:
		var sp: Dictionary = spectators[peer]
		if int(sp["follow"]) != int(cmd["who"]):
			sp["follow"] = int(cmd["who"])
			sp["log_game"] = -1
		_send_spectator_view(peer)
		return
	_s2c_error.rpc_id(peer, SPECTATOR_REFUSED)


func _send_spectator_view(peer: int) -> void:
	if not spectators.has(peer) or series == null:
		return
	var sp: Dictionary = spectators[peer]
	var seat: int = sp["follow"]
	var allowed: bool = spectator_allow[seat].has(sp["id"])
	var v := series.spectator_view(seat, seat if allowed else -1)
	var away := remote_peer == 0 and opponent_ever_joined
	v["net"] = {"spectator": true, "spec_id": sp["id"], "follow": seat, "allowed": allowed,
		"allowed_by": [spectator_allow[0].has(sp["id"]), spectator_allow[1].has(sp["id"])],
		"paused": away, "opponent_connected": remote_peer != 0, "transport": transport, "is_host": false,
		"lobby": lobby_id, "claim_in": -1, "suspended": host_suspended, "spectator_count": spectators.size(),
		"message": ("%s disconnected. The match is paused until they reconnect." % series.names[CLIENT_SEAT]) if away else ""}
	var st := _log_delta(v, int(sp["log_sent"]), int(sp["log_game"]))
	sp["log_sent"] = st[0]
	sp["log_game"] = st[1]
	_ship_view(peer, v, "spectator %d" % int(sp["id"]))


# ---------------------------------------------------------------- chat (A1)

## Sends a chat message from this session's user. Returns "" or why it was not sent.
func send_chat(text: String) -> String:
	var clean := NetChat.sanitize(text)
	if clean == "":
		return "empty"
	if is_host:
		return _host_chat(0, String(series.names[HOST_SEAT]), "player", HOST_SEAT, clean)
	if api.multiplayer_peer == null or api.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return "Not connected to the host."
	if not _chat_guard.allow(0, Time.get_ticks_msec()):
		_on_chat({"from": "", "role": "notice", "seat": -1, "text": NetChat.SLOW_DOWN})
		return NetChat.SLOW_DOWN
	_c2s_chat.rpc_id(1, clean)
	return ""


## A system line for everyone (someone started or stopped watching, a permission changed).
func system_chat(text: String) -> void:
	if is_host:
		_relay_chat({"from": "", "role": "system", "seat": -1, "text": NetChat.sanitize(text)})


@rpc("any_peer", "call_remote", "reliable")
func _c2s_chat(text: String) -> void:
	if not is_host:
		return
	var sender := api.get_remote_sender_id()
	if sender == remote_peer and remote_peer != 0:
		_host_chat(sender, String(series.names[CLIENT_SEAT]), "player", CLIENT_SEAT, text)
	elif spectators.has(sender):
		_host_chat(sender, String(spectators[sender]["name"]), "spectator", -1, text)


## Host: cleans, rate-limits and relays one message from `key` (0 = the host itself, else a peer).
func _host_chat(key: int, from: String, role: String, seat: int, text: String) -> String:
	var clean := NetChat.sanitize(String(text))
	if clean == "":
		return "empty"
	if not _chat_guard.allow(key, Time.get_ticks_msec()):
		_notice(key, NetChat.SLOW_DOWN)
		return NetChat.SLOW_DOWN
	_relay_chat({"from": NetChat.clean_name(from), "role": role, "seat": seat, "text": clean})
	return ""


## A notice for one sender only (host: 0 is the host itself).
func _notice(key: int, text: String) -> void:
	var e := {"from": "", "role": "notice", "seat": -1, "text": text}
	if key == 0:
		_on_chat(e)
	else:
		_s2c_chat.rpc_id(key, e)


## Host: delivers `e` to the client player, every spectator and the host's own chat.
func _relay_chat(e: Dictionary) -> void:
	for pid in _chat_peers():
		_s2c_chat.rpc_id(pid, e)
	_on_chat(e)


func _chat_peers() -> Array:
	var out := spectators.keys()
	if remote_peer != 0:
		out.append(remote_peer)
	return out


@rpc("authority", "call_remote", "reliable")
func _s2c_chat(e: Dictionary) -> void:
	# Even from the host, only the known fields of the right types are kept, as plain text.
	var role := String(e.get("role", "")) if e.get("role") is String else ""
	if not role in ["player", "spectator", "system", "notice"]:
		return
	var seat: int = int(e.get("seat", -1)) if (e.get("seat") is int or e.get("seat") is float) else -1
	_on_chat({"from": NetChat.clean_name(String(e.get("from", ""))) if role in ["player", "spectator"] else "",
		"role": role, "seat": clampi(seat, -1, 1), "text": NetChat.sanitize(String(e.get("text", "")))})


func _on_chat(e: Dictionary) -> void:
	if String(e.get("text", "")) == "":
		return
	e["at"] = int(Time.get_unix_time_from_system())
	chat_log.append(e)
	if chat_log.size() > NetChat.HISTORY:
		chat_log.pop_front()
	chat_received.emit(e)


# ---------------------------------------------------------------- cursor (A2)

## True when this session's player has a spectator allowed to see their cards (only then is the
## cursor sent).
func cursor_wanted() -> bool:
	if is_spectator:
		return false
	if is_host:
		return not spectator_allow[HOST_SEAT].is_empty()
	for sp in local_seat.last_view.get("net", {}).get("spectators", []):
		if sp.get("allowed", false):
			return true
	return false


## Sends this player's cursor (normalised board space; see CursorTrack). The caller throttles.
func send_cursor(pos: Vector2) -> void:
	if is_spectator or not CursorTrack.valid(pos):
		return
	if is_host:
		_relay_cursor(HOST_SEAT, pos)
	elif api.multiplayer_peer != null and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_c2s_cursor.rpc_id(1, pos.x, pos.y)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _c2s_cursor(x: float, y: float) -> void:
	if is_host and api.get_remote_sender_id() == remote_peer and remote_peer != 0:
		_relay_cursor(CLIENT_SEAT, Vector2(x, y))


## Host: forwards seat `seat`'s cursor to the spectators it allowed who are watching it, at most
## CursorTrack.MAX_RELAY_HZ times a second.
func _relay_cursor(seat: int, pos: Vector2) -> void:
	if not CursorTrack.valid(pos):
		return
	var now := Time.get_ticks_msec()
	if now - int(_cursor_last[seat]) < int(1000.0 / CursorTrack.MAX_RELAY_HZ):
		return
	_cursor_last[seat] = now
	for pid in spectators.keys():
		var sp: Dictionary = spectators[pid]
		if int(sp["follow"]) == seat and spectator_allow[seat].has(sp["id"]):
			_s2c_cursor.rpc_id(pid, seat, pos.x, pos.y)


@rpc("authority", "call_remote", "unreliable_ordered")
func _s2c_cursor(seat: int, x: float, y: float) -> void:
	if is_spectator and seat in [0, 1]:
		cursor_received.emit(seat, Vector2(x, y))


# ---------------------------------------------------------------- client sending

## Sends a local command: applied directly on the host, forwarded over RPC on a client.
func send_from_local(cmd: Dictionary) -> void:
	if is_host:
		_apply(HOST_SEAT, last_seq[HOST_SEAT] + 1, cmd)
		return
	if is_spectator and String(cmd.get("t", "")) != "spectate_follow":
		local_seat.status_changed.emit(SPECTATOR_REFUSED)   # the host refuses them too
		return
	if api.multiplayer_peer == null or api.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		local_seat.status_changed.emit("Not connected to the host.")
		return
	if _awaiting_view:
		# Just reconnected: the screen may be stale until the host's fresh view arrives.
		local_seat.status_changed.emit("Reconnecting — please wait for the board to refresh.")
		return
	_seq += 1
	if not is_spectator:
		_save_seq()
	_c2s_command.rpc_id(1, _seq, cmd)


## Test hook: resend a command with an explicit (possibly duplicate) sequence number.
func send_raw(seq: int, cmd: Dictionary) -> void:
	_c2s_command.rpc_id(1, seq, cmd)


func _status(text: String) -> void:
	session_status.emit(text)
	if text.begins_with("Could not") or text.begins_with("Lost"):
		local_seat.status_changed.emit(text)
