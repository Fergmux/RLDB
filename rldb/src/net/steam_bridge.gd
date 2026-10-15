class_name SteamBridge
extends RefCounted
## Thin, optional wrapper around the GodotSteam singleton. The game runs without
## Steam (LAN/dev harness); every Steam call goes through here so a missing
## GDExtension, a closed Steam client or a failed init degrades to a clear message
## instead of a crash. Signatures verified against GodotSteam 4.23 (GDExtension).

const INIT_OK := 0
const LOBBY_FRIENDS_ONLY := 1
const LOBBY_PUBLIC := 2
const LOBBY_ENTER_SUCCESS := 1
const LOBBY_GAME_KEY := "rldb_game"
const LOBBY_GAME_VALUE := "RLDB-v1"

static var _tried := false
static var _ok := false
static var _message := "Steam not initialised yet."
static var app_id: int = 480


static func steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


## Initialises Steam once. Callbacks are embedded (GodotSteam runs them per frame).
static func init(id: int) -> void:
	if _tried:
		return
	_tried = true
	app_id = id
	var s := steam()
	if s == null:
		_message = "Steam integration unavailable: the GodotSteam extension is not loaded on this platform."
		return
	var r: Dictionary = s.steamInitEx(id, true)
	_ok = int(r.get("status", -1)) == INIT_OK
	if _ok:
		_message = "Steam ready as %s (App ID %d%s)." % [s.getPersonaName(), s.getAppID(), " — Spacewar dev ID" if id == 480 else ""]
	else:
		_message = "Steam unavailable (%s). Start the Steam client and log in, then restart the game. LAN/hot-seat modes still work." % r.get("verbal", "unknown error")


static func available() -> bool:
	return _ok


static func describe() -> String:
	return _message


static func my_id() -> int:
	return steam().getSteamID() if _ok else 0


static func name_of(steam_id: int) -> String:
	return steam().getFriendPersonaName(steam_id) if _ok else "Player"


## Lobby id from a "+connect_lobby <id>" launch argument (Steam invite while not running).
static func launch_lobby() -> int:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			return int(args[i + 1])
	return 0
