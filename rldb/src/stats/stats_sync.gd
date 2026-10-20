class_name StatsSync
extends RefCounted
## Keeps PlayerStats in Firestore so a player sees the same statistics on another computer
## (owner feedback C1, 20 Oct 2026; docs/telemetry/README.md "Cloud statistics").
##
## Identity: an UNVERIFIED Steam link. The key is the salted one-way hash of the Steam ID that this
## client reports (Telemetry.hash_steam_id), never the raw Steam ID. A modified client could claim
## another player's hash and write there; the owner accepted that for statistics only. Nothing
## here is ever used for match authority or the competitive metrics.
##
## Paths (firebase/firestore.rules):
##   stats_links/{uid}        {steam_hash, linked_at}: this anonymous uid claims one hash.
##   player_stats/{hash}      {schema_version, steam_hash, uid, rev, enc, raw_len, updated_at, body}:
##                            readable and writable only by a uid whose link names `hash`.
## Protocol (one request at a time, ticked about once a second by the Telemetry node):
##   link (once per uid and hash) -> pull (GET; at start-up and when the dialog opens) -> merge into
##   the local record -> push (documents:commit with an updateTime / exists=false precondition)
##   whenever the shared part differs from what the cloud holds. A lost race (another computer
##   wrote first) is a precondition failure: pull, merge, push again. Merging is a CRDT
##   (PlayerStats.merge), so the result never depends on the order.
## Quota: about 2 reads per start-up and dialog refresh, and 1 write per changed record (a duel or
## series end, debounced). Offline, 429 and 5xx back off exponentially; a refusal stops the cloud
## copy for this run and the local file carries on. Never blocks and never shows an error.

const LINKS := "stats_links"
const DOCS := "player_stats"
const SCHEMA := 1
## Rules cap for the encoded body (base64 of gzip JSON).
const MAX_BODY := 200000
const MAX_RAW := 4194304
const ENC := "gzip64"

## Public state for the Statistics dialog: local | syncing | synced | pending | error.
static var status: Dictionary = {"state": "local", "reason": "", "at": 0}

var transport
var auth: TelemetryAuth
var base_url: String                 # ".../documents"
var steam_hash: String = ""
## Remembers which uid linked which hash and the last pushed signature (per target).
var cfg_path: String = ""
var timeout_s: float = 15.0
var debounce_ms: int = 4000
var refresh_after_ms: int = 60000
var backoff_base_s: float = 5.0
var backoff_cap_s: float = 900.0
var rng := RandomNumberGenerator.new()
var now_ms: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
## False while sharing is off or the kill switch is set: nothing is sent.
var enabled: bool = true

var busy := false
var linked := false
var pulled := false
var update_time := ""                # updateTime of the cloud document we last saw ("" = none)
var cloud_rev := 0
var cloud_sig := ""                  # signature of the shared part the cloud holds
var next_try_ms := 0
var failures := 0
var refusals := 0
var last_pull_ms := 0
var _seen_rev := -1
var _dirty_at := 0
## Counters for the developer tool and tests.
var stats := {"links": 0, "pulls": 0, "pushes": 0, "conflicts": 0, "transient": 0, "refused": 0}


func _init(p_transport, p_auth: TelemetryAuth, p_base_url: String, p_hash: String, p_cfg_path: String) -> void:
	transport = p_transport
	auth = p_auth
	base_url = p_base_url
	steam_hash = p_hash
	cfg_path = p_cfg_path
	var cf := ConfigFile.new()
	if cf.load(cfg_path) == OK:
		linked = String(cf.get_value("sync", "linked_hash", "")) == steam_hash and String(cf.get_value("sync", "linked_uid", "")) != "" \
			and String(cf.get_value("sync", "linked_uid", "")) == auth.uid
	PlayerStats.use_account(steam_hash)
	set_status("syncing")


## The Statistics dialog's line: {state, label, detail}.
static func describe() -> Dictionary:
	var st := String(status.get("state", "local"))
	var reason := String(status.get("reason", ""))
	match st:
		"synced":
			return {"state": st, "label": "Synced with your Steam account", "detail": _ago(int(status.get("at", 0)))}
		"syncing":
			return {"state": st, "label": "Syncing with your Steam account…", "detail": ""}
		"pending":
			return {"state": st, "label": "Saved on this computer", "detail": "will sync when online"}
		"error":
			return {"state": st, "label": "Saved on this computer", "detail": "cloud copy unavailable right now"}
	return {"state": "local", "label": "Kept on this computer only", "detail": reason}


static func set_status(state: String, reason: String = "") -> void:
	status = {"state": state, "reason": reason, "at": int(Time.get_unix_time_from_system())}


static func _ago(at: int) -> String:
	var s := maxi(0, int(Time.get_unix_time_from_system()) - at)
	if s < 60:
		return "just now"
	if s < 3600:
		return "%d min ago" % (s / 60)
	return "%d h ago" % (s / 3600)


## Sharing was turned back on: start over (link check, pull, push) with a clean backoff.
func reset() -> void:
	enabled = true
	busy = false
	pulled = false
	failures = 0
	refusals = 0
	next_try_ms = 0
	set_status("syncing")


## Ask for a fresh copy (the dialog opened); at most once a minute.
func refresh() -> void:
	if enabled and pulled and now_ms.call() - last_pull_ms >= refresh_after_ms and not busy:
		pulled = false
		if failures == 0:
			next_try_ms = 0


## One step of the protocol if one is due. Cheap when idle.
func tick() -> void:
	if not enabled:
		return
	if PlayerStats.revision != _seen_rev:
		_seen_rev = PlayerStats.revision
		_dirty_at = now_ms.call()
	if busy or now_ms.call() < next_try_ms:
		return
	if not linked:
		_start(_link)
	elif not pulled:
		_start(_pull)
	elif _dirty() and now_ms.call() - _dirty_at >= debounce_ms:
		_start(_push)


func _dirty() -> bool:
	return PlayerStats.signature(PlayerStats.load_data()) != cloud_sig


func _start(step: Callable) -> void:
	busy = true
	if status.get("state", "") != "synced" or step != _push:
		set_status("syncing")
	auth.ensure_token(func(kind: String):
		if kind != TelemetryAuth.OK_:
			_backoff(kind == TelemetryAuth.PERMANENT)
			return
		if not enabled:
			busy = false
			return
		step.call())


func _headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + auth.id_token()])


func _doc_root() -> String:
	var i := base_url.find("/v1/")
	return base_url.substr(i + 4) if i >= 0 else base_url


# ------------------------------------------------------------------ link

func _link() -> void:
	var body := {"writes": [{
		"update": {"name": "%s/%s/%s" % [_doc_root(), LINKS, auth.uid], "fields": {"steam_hash": {"stringValue": steam_hash}}},
		"updateTransforms": [{"fieldPath": "linked_at", "setToServerValue": "REQUEST_TIME"}]}]}
	transport.send({"method": "POST", "url": base_url + ":commit", "timeout_s": timeout_s, "headers": _headers(),
		"body": JSON.stringify(body)}, func(res: Dictionary):
			if _transient(res):
				return
			if int(res["status"]) == 200:
				stats["links"] += 1
				linked = true
				var cf := ConfigFile.new()
				cf.load(cfg_path)
				cf.set_value("sync", "linked_hash", steam_hash)
				cf.set_value("sync", "linked_uid", auth.uid)
				DirAccess.make_dir_recursive_absolute(cfg_path.get_base_dir())
				cf.save(cfg_path)
				_ok_step()
			else:
				_refused(res))


# ------------------------------------------------------------------ pull

func _pull() -> void:
	transport.send({"method": "GET", "url": "%s/%s/%s" % [base_url, DOCS, steam_hash], "timeout_s": timeout_s,
		"headers": _headers()}, func(res: Dictionary):
			if _transient(res):
				return
			var code := int(res["status"])
			if code == 404:
				update_time = ""
				cloud_rev = 0
				cloud_sig = PlayerStats.signature(PlayerStats.empty())
				_pulled()
			elif code == 200:
				var doc = JSON.parse_string(String(res.get("body", "")))
				var cloud := decode_doc(doc)
				if cloud.is_empty():
					_refused(res)   # unreadable copy: keep the local record, write nothing over it
					return
				update_time = String(doc.get("updateTime", ""))
				cloud_rev = int(cloud["_rev"])
				cloud.erase("_rev")
				cloud_sig = PlayerStats.signature(cloud)
				var merged := PlayerStats.merge(PlayerStats.load_data(), cloud)
				if PlayerStats.signature(merged) != PlayerStats.signature(PlayerStats.load_data()):
					PlayerStats.replace(merged)
				_pulled()
			elif code == 401:
				auth.invalidate()
				_backoff(false)
			elif code == 403:
				linked = false        # link missing or changed: claim again once
				_refused(res)
			else:
				_refused(res))


func _pulled() -> void:
	stats["pulls"] += 1
	pulled = true
	last_pull_ms = now_ms.call()
	_dirty_at = 0                     # merged changes are pushed at once, not debounced
	_seen_rev = PlayerStats.revision
	_ok_step()


## The shared record from a Firestore document (REST JSON), with "_rev"; {} when malformed.
static func decode_doc(doc) -> Dictionary:
	if not (doc is Dictionary) or not (doc.get("fields") is Dictionary):
		return {}
	var f: Dictionary = doc["fields"]
	var body := String(f.get("body", {}).get("stringValue", ""))
	var enc := String(f.get("enc", {}).get("stringValue", ""))
	var rev := int(String(f.get("rev", {}).get("integerValue", "0")))
	var text := decode_body(enc, body)
	var parsed = JSON.parse_string(text) if text != "" else null
	if not (parsed is Dictionary):
		return {}
	var out := PlayerStats.sanitize(parsed)
	out["_rev"] = rev
	return out


## Body text of an encoded payload ("" when it cannot be decoded within MAX_RAW).
static func decode_body(enc: String, body: String) -> String:
	if enc == "json":
		return body
	if enc != ENC or body == "":
		return ""
	var raw := Marshalls.base64_to_raw(body)
	if raw.is_empty():
		return ""
	var out := raw.decompress_dynamic(MAX_RAW, FileAccess.COMPRESSION_GZIP)
	return out.get_string_from_utf8() if not out.is_empty() else ""


## [encoded body, raw length] of a shared record (gzip, then base64).
static func encode_body(shared: Dictionary) -> Array:
	var raw := JSON.stringify(shared).to_utf8_buffer()
	return [Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP)), raw.size()]


## The shared record to upload, trimmed (oldest duels, then series first) until it fits the cap.
static func fit(data: Dictionary) -> Dictionary:
	var sh := PlayerStats.shared(data).duplicate(true)
	var enc := encode_body(sh)
	while String(enc[0]).length() > MAX_BODY and (not sh["duels"].is_empty() or not sh["series"].is_empty()):
		var cut := maxi(1, sh["duels"].size() / 10)
		if sh["duels"].is_empty():
			sh["series"] = sh["series"].slice(maxi(1, sh["series"].size() / 10))
		else:
			sh["duels"] = sh["duels"].slice(cut)
		enc = encode_body(sh)
	return {"shared": sh, "body": enc[0], "raw_len": enc[1]}


# ------------------------------------------------------------------ push

func _push() -> void:
	var data := PlayerStats.load_data()
	var pack := fit(data)
	var rev := cloud_rev + 1
	var fields := {"schema_version": {"integerValue": str(SCHEMA)}, "steam_hash": {"stringValue": steam_hash},
		"uid": {"stringValue": auth.uid}, "rev": {"integerValue": str(rev)}, "enc": {"stringValue": ENC},
		"raw_len": {"integerValue": str(int(pack["raw_len"]))}, "body": {"stringValue": String(pack["body"])}}
	var write := {"update": {"name": "%s/%s/%s" % [_doc_root(), DOCS, steam_hash], "fields": fields},
		"updateTransforms": [{"fieldPath": "updated_at", "setToServerValue": "REQUEST_TIME"}],
		"currentDocument": {"updateTime": update_time} if update_time != "" else {"exists": false}}
	var sig := PlayerStats.signature(pack["shared"])
	transport.send({"method": "POST", "url": base_url + ":commit", "timeout_s": timeout_s, "headers": _headers(),
		"body": JSON.stringify({"writes": [write]})}, func(res: Dictionary):
			if _transient(res):
				return
			var code := int(res["status"])
			if code == 200:
				var d = JSON.parse_string(String(res.get("body", "")))
				var wr = d.get("writeResults", []) if d is Dictionary else []
				update_time = String(wr[0].get("updateTime", d.get("commitTime", ""))) if wr is Array and not wr.is_empty() and wr[0] is Dictionary else ""
				if update_time == "":
					pulled = false    # unknown version: read it back before the next write
				cloud_rev = rev
				cloud_sig = sig
				stats["pushes"] += 1
				_ok_step()
			elif code == 409 or (code == 400 and _precondition(res)):
				# Another computer wrote first: read, merge and write again.
				stats["conflicts"] += 1
				pulled = false
				busy = false
				next_try_ms = 0
			elif code == 401:
				auth.invalidate()
				_backoff(false)
			elif code == 403:
				linked = false
				pulled = false
				_refused(res)
			else:
				_refused(res))


static func _precondition(res: Dictionary) -> bool:
	var d = JSON.parse_string(String(res.get("body", "")))
	return d is Dictionary and d.get("error") is Dictionary and String(d["error"].get("status", "")) in ["FAILED_PRECONDITION", "ABORTED", "ALREADY_EXISTS"]


# ------------------------------------------------------------------ outcomes

## A step succeeded: the next one may run at once. The refusal and backoff counts are cleared
## only once the record is fully in sync, so a refused write can never loop link -> pull -> push.
func _ok_step() -> void:
	busy = false
	next_try_ms = 0
	if linked and pulled and not _dirty():
		failures = 0
		refusals = 0
		set_status("synced")


## Offline, timeout, 408, 429, 5xx: back off and report "pending". True when handled.
func _transient(res: Dictionary) -> bool:
	var code := int(res.get("status", 0))
	if not res.get("network_ok", false) or code == 408 or code == 429 or code >= 500:
		_backoff(false)
		return true
	return false


## A refusal (403 / other 4xx): try again later, and after three in a row stop for this run.
func _refused(_res: Dictionary) -> void:
	stats["refused"] += 1
	refusals += 1
	busy = false
	if refusals >= 3:
		enabled = false
		set_status("error")
		return
	failures += 1
	next_try_ms = now_ms.call() + int(minf(backoff_cap_s, backoff_base_s * pow(2.0, float(failures))) * 1000.0)
	set_status("pending")


func _backoff(permanent: bool) -> void:
	stats["transient"] += 1
	busy = false
	failures += 1
	var delay := minf(backoff_cap_s, backoff_base_s * pow(2.0, float(mini(failures - 1, 16))))
	if permanent:
		delay = backoff_cap_s
	next_try_ms = now_ms.call() + int(delay * rng.randf_range(0.5, 1.0) * 1000.0)
	set_status("pending")
