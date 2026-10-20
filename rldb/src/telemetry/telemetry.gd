class_name Telemetry
extends Node
## Background gameplay statistics service (docs/telemetry/README.md). Started once by the main
## scene (Telemetry.boot); absent in GdUnit runs and every other process that does not boot it,
## where all static entry points are silent no-ops. Nothing here ever shows UI, raises an error to
## the player or waits on the network: records go to a durable outbox and a background uploader
## sends them when it can.
##
## Player control: Settings > "Share anonymous gameplay statistics" (on by default, stored in
## user://ui_settings.cfg [privacy] share_gameplay_stats). Off: nothing new is collected, the
## uploader stops and the local queue of not-yet-sent records is deleted. Records already sent
## stay in the database until the owner deletes them (firebase/tools: delete-uid).

## Storage roots; tests point these at a scratch folder so they never touch real player files.
static var DIR := "user://telemetry"
static var SETTINGS_PATH := "user://ui_settings.cfg"
const PRIVACY_NOTE := "Sends anonymous match statistics (draft picks, decks, cards played, game times and results) to help balance RLDB, and keeps your own statistics with a one-way code made from your Steam account so they follow you to other computers. No names, chat or Steam profile details are sent. Turning this off stops collection and syncing and deletes statistics not yet sent."

## The running service, or null.
static var instance: Telemetry = null
static var _share_loaded := false
static var _share := true
static var _share_path := ""
## The Steam ID used for the statistics key (0 without Steam). Tests inject their own.
static var steam_id_provider: Callable = func() -> int: return SteamBridge.my_id() if SteamBridge.available() else 0

var config: TelemetryConfig
var outbox: TelemetryOutbox
var auth: TelemetryAuth
var uploader: TelemetryUploader
var collector: TelemetryCollector
## Cloud copy of the player's own statistics (null without Steam or when inactive).
var stats_sync: StatsSync
var http: TelemetryHttp
var _transport
var content_hash: String = ""
var session_id: String = ""
var install_pid: String = ""
var steam_hash: String = ""
var _seq: int = 0
var _tick_accum := 0.0
## Bounded developer diagnostics (never shown to players; printed only by the dev tool).
var diagnostics: Array = []


# ------------------------------------------------------------------ static entry points

## Starts the service under `parent` (once per process). Safe to call when telemetry is off.
static func boot(parent: Node, cfg: TelemetryConfig = null, transport = null) -> Telemetry:
	if instance != null and is_instance_valid(instance):
		return instance
	var t := Telemetry.new()
	t.name = "Telemetry"
	t.setup(cfg if cfg != null else TelemetryConfig.resolve(), transport)
	parent.add_child(t)
	instance = t
	return t


## Observe a Series run in this process (hot-seat, bot or network host).
static func attach_series(s: Series, mode: String, role: String) -> void:
	if _live():
		instance.collector.attach(s, mode, role)


## A network client received a view (corroborating report).
static func client_view(v: Dictionary, transport: String) -> void:
	if _live():
		instance.collector.on_client_view(v, transport)


## The network host paused (true) or resumed (false) the duel for a disconnect.
static func net_pause(on: bool) -> void:
	if _live():
		instance.collector.set_paused(on)


static func _live() -> bool:
	return instance != null and is_instance_valid(instance) and instance.collecting()


## The player's choice (default on).
static func share_enabled() -> bool:
	if not _share_loaded or _share_path != SETTINGS_PATH:
		_share_path = SETTINGS_PATH
		_share_loaded = true
		_share = true
		var cf := ConfigFile.new()
		if cf.load(SETTINGS_PATH) == OK:
			_share = bool(cf.get_value("privacy", "share_gameplay_stats", true))
	return _share


## Sets and saves the player's choice; off deletes the unsent local queue.
static func set_share_enabled(on: bool) -> void:
	share_enabled()
	_share = on
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("privacy", "share_gameplay_stats", on)
	cf.save(SETTINGS_PATH)
	if instance != null and is_instance_valid(instance):
		instance._apply_share()


## The Settings row: the checkbox and its privacy note (main menu and in-game settings).
static func settings_control(font_size: int = 14) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var cb := CheckBox.new()
	cb.text = "Share anonymous gameplay statistics"
	cb.button_pressed = share_enabled()
	cb.add_theme_font_size_override("font_size", font_size)
	cb.toggled.connect(func(on): Telemetry.set_share_enabled(on))
	box.add_child(cb)
	var note := Label.new()
	note.text = PRIVACY_NOTE
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(320, 0)
	note.add_theme_font_size_override("font_size", maxi(font_size - 3, 10))
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)
	return box


# ------------------------------------------------------------------ service

## Wires the service. `transport`: a TelemetryHttp-compatible object (tests inject a fake).
func setup(cfg: TelemetryConfig, transport = null) -> void:
	config = cfg
	process_mode = Node.PROCESS_MODE_ALWAYS
	content_hash = FileAccess.get_sha256("res://data/cards.json")
	_load_state()
	session_id = Series.new_telemetry_id()
	steam_hash = _steam_hash()
	var root := DIR if config.target == "live" else DIR.path_join(config.target)
	outbox = TelemetryOutbox.new(root.path_join("outbox"), int(config.outbox["max_items"]), int(config.outbox["max_bytes"]), int(config.outbox["quarantine_max"]))
	if transport == null:
		http = TelemetryHttp.new()
		add_child(http)
		transport = http
	_transport = transport
	auth = TelemetryAuth.new(transport, config.signup_url(), config.refresh_url(), config.credential_path(DIR))
	auth.timeout_s = float(config.upload["http_timeout_s"])
	uploader = TelemetryUploader.new(outbox, auth, transport, config.firestore_base())
	uploader.timeout_s = float(config.upload["http_timeout_s"])
	uploader.backoff_base_s = float(config.upload["backoff_base_s"])
	uploader.backoff_cap_s = float(config.upload["backoff_cap_s"])
	uploader.idle_poll_s = float(config.upload["idle_poll_s"])
	uploader.rng.randomize()
	collector = TelemetryCollector.new()
	collector.emit_item = _emit_item
	collector.max_events = int(config.collect["max_events_per_game"])
	collector.profile_pid = install_pid
	collector.steam_hash = steam_hash
	if not config.active():
		_diag("inactive: target=%s enabled=%s %s" % [config.target, config.enabled, config.off_reason])
		StatsSync.set_status("local", "")
		return
	outbox.load_all()
	_recover_open_items()
	_apply_share()
	if collecting():
		_emit_item("session", "session_" + session_id, "ready", "none", {"kind": "session",
			"ids": {"session_id": session_id}, "session": {"session_id": session_id, "started_at": _now(),
				"participant_id": install_pid, "steam_hash": steam_hash, "steam_link": "unverified" if steam_hash != "" else "none",
				"platform": OS.get_name(), "end_tracked": false}})
		if not _profile_sent():
			_emit_item("profile", "profile_" + install_pid, "ready", "none", {"kind": "profile",
				"ids": {"participant_id": install_pid}, "profile": {"participant_id": install_pid, "created_at": _now(),
					"steam_hash": steam_hash, "steam_link": "unverified" if steam_hash != "" else "none"}})
			_mark_profile_sent()
	_maybe_start_sync()


## Starts the cloud statistics copy once Steam is known (C1). Without Steam, with sharing off or
## the kill switch set, statistics stay on this computer only.
func _maybe_start_sync() -> void:
	if stats_sync != null or config == null or not config.active() or not bool(config.stats_sync.get("enabled", true)):
		return
	if PlayerStats.PATH == PlayerStats.TEST_PATH:
		# Automated runs record into the test file: it must never reach anyone's cloud copy.
		StatsSync.set_status("local", "automated run")
		return
	if not share_enabled():
		StatsSync.set_status("local", "statistics sharing is off")
		return
	if steam_hash == "":
		steam_hash = _steam_hash()
		collector.steam_hash = steam_hash
	if steam_hash == "":
		StatsSync.set_status("local", "Steam is not running")
		return
	stats_sync = StatsSync.new(_transport, auth, config.firestore_base(), steam_hash,
		(DIR if config.target == "live" else DIR.path_join(config.target)).path_join("stats_sync.cfg"))
	stats_sync.timeout_s = float(config.upload["http_timeout_s"])
	stats_sync.backoff_base_s = float(config.upload["backoff_base_s"])
	stats_sync.backoff_cap_s = float(config.upload["backoff_cap_s"])
	stats_sync.debounce_ms = int(float(config.stats_sync.get("debounce_s", 4)) * 1000.0)
	stats_sync.rng.randomize()


## The Statistics dialog opened: fetch the cloud copy again if it is a minute old.
static func refresh_stats() -> void:
	if instance != null and is_instance_valid(instance) and instance.stats_sync != null:
		instance.stats_sync.refresh()


## True when records are collected now (configured, not killed, and the player agrees).
func collecting() -> bool:
	return config != null and config.active() and share_enabled()


func _process(delta: float) -> void:
	if uploader == null:
		return
	_tick_accum += delta
	if _tick_accum >= 1.0:
		_tick_accum = 0.0
		uploader.tick()
		if stats_sync != null:
			stats_sync.tick()
		elif collecting() and steam_hash == "":
			_maybe_start_sync()           # Steam came up after start-up


func _apply_share() -> void:
	var on := collecting()
	if uploader != null:
		uploader.enabled = on
	if stats_sync != null:
		stats_sync.enabled = on
		if on:
			stats_sync.reset()
	if not on and config != null and config.active():
		StatsSync.set_status("local", "statistics sharing is off")
	elif on and stats_sync == null and outbox != null:
		_maybe_start_sync()
	if not share_enabled() and outbox != null:
		if collector != null and collector.series != null:
			collector.series.observer = null
			collector.series = null
		outbox.clear_all()


func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


## Collector sink: stamps the header and writes the record to the outbox (open records are
## rewritten in place and keep their first created_at and seq).
func _emit_item(kind: String, doc_id: String, state: String, mode: String, body: Dictionary) -> void:
	if not collecting():
		return
	var prev := outbox.get_item(doc_id)
	if not prev.is_empty() and prev.get("state", "") == "ready":
		return                            # already final: duplicate completion signal
	var created: int = int(prev["fields"]["created_at"]) if not prev.is_empty() else _now()
	var seq: int = int(prev["fields"]["seq"]) if not prev.is_empty() else _next_seq()
	# An open record keeps the environment it was first queued under (owner answers section 7).
	var env: String = String(prev["fields"].get("env", config.environment)) if not prev.is_empty() else config.environment
	var meta := {"schema_version": TelemetryConfig.SCHEMA_VERSION, "env": env, "build": config.build_label(),
		"content_hash": content_hash, "session_id": session_id, "created_at": created, "seq": seq, "updated_at": _now()}
	var b := body.duplicate()
	b["meta"] = meta
	var text := JSON.stringify(b)
	if text.length() > 200000 and b.has("events"):
		var n: int = (b["events"] as Array).size()
		b["events"] = []
		b["completeness"]["events"] = false
		b["completeness"]["events_dropped"] = n
		text = JSON.stringify(b)
	if text.length() > 200000:
		_diag("record %s too large (%d)" % [doc_id, text.length()])
		return
	outbox.put({"id": doc_id, "kind": kind, "state": state, "created_at": created, "updated_at": _now(),
		"fields": {"schema_version": TelemetryConfig.SCHEMA_VERSION, "kind": kind, "env": env,
			"build": config.build_label(), "content_hash": content_hash, "mode": mode, "created_at": created, "seq": seq},
		"body": text})
	if state == "ready":
		uploader.poke()


## Open records from an earlier process older than abandon_after_hours become abandoned reports.
func _recover_open_items() -> void:
	var limit := _now() - int(float(config.outbox["abandon_after_hours"]) * 3600000.0)
	for id in outbox.items.keys():
		var it: Dictionary = outbox.items[id]
		if it.get("state", "") != "open" or int(it.get("updated_at", 0)) > limit:
			continue
		var body = JSON.parse_string(String(it.get("body", "")))
		if body is Dictionary:
			it["body"] = JSON.stringify(TelemetryCollector.abandon_body(String(it["kind"]), body))
		it["state"] = "ready"
		outbox.put(it)


func _state_path() -> String:
	return DIR.path_join("state.cfg")


func _next_seq() -> int:
	_seq += 1
	var cf := ConfigFile.new()
	cf.load(_state_path())
	cf.set_value("state", "seq", _seq)
	cf.set_value("state", "install_pid", install_pid)
	cf.save(_state_path())
	return _seq


func _load_state() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var cf := ConfigFile.new()
	cf.load(_state_path())
	_seq = int(cf.get_value("state", "seq", 0))
	install_pid = String(cf.get_value("state", "install_pid", ""))
	if install_pid == "":
		install_pid = "pp_" + Series.new_telemetry_id()
		cf.set_value("state", "install_pid", install_pid)
		cf.set_value("state", "seq", _seq)
		cf.save(_state_path())


func _profile_sent() -> bool:
	var cf := ConfigFile.new()
	cf.load(_state_path())
	return bool(cf.get_value("state", "profile_queued_" + config.target, false))


func _mark_profile_sent() -> void:
	var cf := ConfigFile.new()
	cf.load(_state_path())
	cf.set_value("state", "profile_queued_" + config.target, true)
	cf.save(_state_path())


## Salted one-way HMAC-SHA256 of the Steam ID (first 32 hex chars), "" without Steam. Pseudonymous
## grouping only: it is NOT verified (a client could send any value) and, because SteamIDs are
## enumerable, it is reversible by anyone holding both the salt and the data.
func _steam_hash() -> String:
	if config.steam_hash_salt == "":
		return ""
	var id: int = int(steam_id_provider.call())
	if id == 0:
		return ""
	return hash_steam_id(id, config.steam_hash_salt)


static func hash_steam_id(steam_id: int, salt: String) -> String:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, salt.to_utf8_buffer())
	ctx.update(("steam:%d" % steam_id).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 32)


func _diag(text: String) -> void:
	diagnostics.append("%d %s" % [_now(), TelemetryOutbox.redact(text)])
	if diagnostics.size() > 50:
		diagnostics.pop_front()
