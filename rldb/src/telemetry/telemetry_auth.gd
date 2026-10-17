class_name TelemetryAuth
extends RefCounted
## Firebase anonymous identity for telemetry, over REST (no SDK).
##
## The first upload signs up once (identitytoolkit accounts:signUp); the refresh token and uid are
## stored in a local credential file (user://telemetry/credential.cfg for the live project) and
## reused on every later launch, so one install keeps one Firebase uid. ID tokens (1 hour) live
## only in memory and are renewed through securetoken.googleapis.com. Tokens are never logged or
## written anywhere else. A refresh token the server rejects for good (revoked / user deleted) is
## discarded and the next attempt signs up again, which yields a new uid (documented limitation).

## Outcome kinds passed to callbacks.
const OK_ := ""
const TRANSIENT := "transient"      # offline, timeout, 429, 5xx: retry later with backoff
const PERMANENT := "permanent"      # e.g. anonymous sign-in disabled: long backoff, never a loop

var transport                        # TelemetryHttp or a test fake (send(req, cb))
var signup_url: String
var refresh_url: String
var cred_path: String
var timeout_s: float = 15.0
var now_ms: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)

var uid: String = ""
var _refresh_token: String = ""
var _id_token: String = ""
var _expires_at: int = 0
var _busy := false
var _waiters: Array = []
## Counters for the developer tool and tests.
var stats := {"signups": 0, "refreshes": 0, "failures": 0}


func _init(p_transport, p_signup_url: String, p_refresh_url: String, p_cred_path: String) -> void:
	transport = p_transport
	signup_url = p_signup_url
	refresh_url = p_refresh_url
	cred_path = p_cred_path
	_load()


## True once an account exists on this install (a refresh token is stored).
func has_account() -> bool:
	return _refresh_token != ""


## Current ID token ("" when none is valid).
func id_token() -> String:
	return _id_token if _id_token != "" and now_ms.call() < _expires_at - 60000 else ""


## Forgets the in-memory ID token (after a 401) so the next call refreshes.
func invalidate() -> void:
	_id_token = ""
	_expires_at = 0


## Calls cb.call(kind) once a valid ID token is available (kind == "") or it failed.
func ensure_token(cb: Callable) -> void:
	if id_token() != "":
		cb.call(OK_)
		return
	_waiters.append(cb)
	if _busy:
		return
	_busy = true
	if _refresh_token != "":
		_refresh()
	else:
		_signup()


func _signup() -> void:
	transport.send({"method": "POST", "url": signup_url, "timeout_s": timeout_s,
		"headers": PackedStringArray(["Content-Type: application/json"]),
		"body": JSON.stringify({"returnSecureToken": true})}, _on_signup)


func _on_signup(res: Dictionary) -> void:
	var d = JSON.parse_string(String(res.get("body", ""))) if res.get("network_ok", false) else null
	if res.get("network_ok", false) and int(res["status"]) == 200 and d is Dictionary and d.has("refreshToken"):
		stats["signups"] += 1
		uid = String(d.get("localId", ""))
		_refresh_token = String(d["refreshToken"])
		_id_token = String(d.get("idToken", ""))
		_expires_at = now_ms.call() + int(d.get("expiresIn", "3600")) * 1000
		_save()
		_finish(OK_)
	else:
		_finish(_classify(res))


func _refresh() -> void:
	transport.send({"method": "POST", "url": refresh_url, "timeout_s": timeout_s,
		"headers": PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]),
		"body": "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode()}, _on_refresh)


func _on_refresh(res: Dictionary) -> void:
	var d = JSON.parse_string(String(res.get("body", ""))) if res.get("network_ok", false) else null
	if res.get("network_ok", false) and int(res["status"]) == 200 and d is Dictionary and d.has("id_token"):
		stats["refreshes"] += 1
		_id_token = String(d["id_token"])
		_refresh_token = String(d.get("refresh_token", _refresh_token))
		uid = String(d.get("user_id", uid))
		_expires_at = now_ms.call() + int(d.get("expires_in", "3600")) * 1000
		_save()
		_finish(OK_)
		return
	var kind := _classify(res)
	if res.get("network_ok", false) and int(res["status"]) == 400:
		# Revoked / expired / deleted refresh token: start over with a new anonymous account.
		_refresh_token = ""
		uid = ""
		_save()
		kind = TRANSIENT
	_finish(kind)


func _finish(kind: String) -> void:
	_busy = false
	if kind != OK_:
		stats["failures"] += 1
	var ws := _waiters
	_waiters = []
	for w in ws:
		w.call(kind)


static func _classify(res: Dictionary) -> String:
	if not res.get("network_ok", false):
		return TRANSIENT
	var s := int(res.get("status", 0))
	if s == 429 or s >= 500 or s == 408:
		return TRANSIENT
	return PERMANENT


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(cred_path) == OK:
		uid = String(cf.get_value("auth", "uid", ""))
		_refresh_token = String(cf.get_value("auth", "refresh_token", ""))


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(cred_path.get_base_dir())
	var cf := ConfigFile.new()
	cf.set_value("auth", "uid", uid)
	cf.set_value("auth", "refresh_token", _refresh_token)
	cf.set_value("auth", "note", "RLDB anonymous statistics identity. Do not share this file.")
	var tmp := cred_path + ".tmp"
	if cf.save(tmp) == OK:
		if FileAccess.file_exists(cred_path):
			DirAccess.remove_absolute(cred_path)
		DirAccess.rename_absolute(tmp, cred_path)
