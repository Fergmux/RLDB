class_name TelemetryUploader
extends RefCounted
## Sends outbox items to Firestore, one document per commit, at most one request at a time.
## Driven by tick() (about once a second from the Telemetry node); never waits or loops, so it
## cannot stall gameplay. Documents are created with currentDocument.exists = false and a
## server REQUEST_TIME transform for `received_at`, so a resend can never overwrite anything.
##
## Response handling:
##   200            accepted -> ack (item deleted)
##   409            already exists (lost acknowledgement) -> ack as duplicate
##   401            ID token expired -> refresh once, resend; then backoff
##   403            refused: GET the document as its owner; present -> duplicate, else quarantine
##   400, other 4xx permanent -> quarantine with a redacted diagnostic, never retried
##   0 (offline / timeout), 408, 429, 5xx -> exponential backoff with jitter (whole uploader)
## Backoff: min(cap, base * 2^n) * uniform(0.5, 1.0) seconds after n consecutive failures.

var outbox: TelemetryOutbox
var auth: TelemetryAuth
var transport
var base_url: String                 # ".../documents"
var header: Dictionary = {}          # fields stamped on every document except uid/received_at
var timeout_s: float = 15.0
var backoff_base_s: float = 5.0
var backoff_cap_s: float = 900.0
var idle_poll_s: float = 60.0
var rng := RandomNumberGenerator.new()
var now_ms: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
## False while the player has sharing off or the kill switch is set.
var enabled: bool = true

var busy := false
var next_try_ms: int = 0
var failures: int = 0
## Counters for the developer tool and tests.
var stats := {"accepted": 0, "duplicate": 0, "quarantined": 0, "transient": 0, "auth_retry": 0, "requests": 0}
var last_status: int = -1


func _init(p_outbox: TelemetryOutbox, p_auth: TelemetryAuth, p_transport, p_base_url: String) -> void:
	outbox = p_outbox
	auth = p_auth
	transport = p_transport
	base_url = p_base_url


## Starts at most one upload step if one is due. Cheap when idle.
func tick() -> void:
	if busy or not enabled or now_ms.call() < next_try_ms:
		return
	var item := outbox.next_ready()
	if item.is_empty():
		next_try_ms = now_ms.call() + int(idle_poll_s * 1000.0)
		return
	busy = true
	auth.ensure_token(func(kind: String): _after_token(String(item["id"]), kind, 0))


## Upload as soon as possible (new item queued, connectivity back, developer flush).
func poke() -> void:
	if failures == 0:
		next_try_ms = 0


## Clears the backoff so the next tick tries at once (developer flush).
func reset_backoff() -> void:
	failures = 0
	next_try_ms = 0


func _after_token(id: String, kind: String, auth_retries: int) -> void:
	if kind != TelemetryAuth.OK_:
		_backoff(kind == TelemetryAuth.PERMANENT)
		return
	if not outbox.has(id) or not enabled:
		busy = false
		return
	var item := outbox.get_item(id)
	stats["requests"] += 1
	transport.send({"method": "POST", "url": base_url + ":commit", "timeout_s": timeout_s,
		"headers": PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + auth.id_token()]),
		"body": JSON.stringify(commit_body(item, auth.uid))}, func(res: Dictionary): _on_commit(id, res, auth_retries))


## The documents:commit request body for `item` owned by `uid`.
func commit_body(item: Dictionary, uid: String) -> Dictionary:
	var fields := {}
	var src: Dictionary = header.duplicate()
	src.merge(item["fields"], true)
	for k in src:
		var v = src[k]
		if v is int or (v is float and float(v) == floorf(float(v))):
			fields[k] = {"integerValue": str(int(v))}
		else:
			fields[k] = {"stringValue": String(v)}
	fields["uid"] = {"stringValue": uid}
	fields["body"] = {"stringValue": String(item.get("body", "{}"))}
	return {"writes": [{
		"update": {"name": "%s/users/%s/submissions/%s" % [_doc_root(), uid, String(item["id"])], "fields": fields},
		"updateTransforms": [{"fieldPath": "received_at", "setToServerValue": "REQUEST_TIME"}],
		"currentDocument": {"exists": false}}]}


## "projects/<p>/databases/<d>/documents" from the REST base URL.
func _doc_root() -> String:
	var i := base_url.find("/v1/")
	return base_url.substr(i + 4) if i >= 0 else base_url


func _on_commit(id: String, res: Dictionary, auth_retries: int) -> void:
	last_status = int(res.get("status", 0))
	if not res.get("network_ok", false):
		outbox.note_attempt(id)
		_backoff(false)
		return
	var s := int(res["status"])
	match s:
		200:
			_done(id, "accepted")
		409:
			_done(id, "duplicate")
		401:
			auth.invalidate()
			if auth_retries < 1:
				stats["auth_retry"] += 1
				auth.ensure_token(func(kind: String): _after_token(id, kind, auth_retries + 1))
			else:
				_backoff(false)
		403:
			_check_existing(id, res)
		_:
			if s == 408 or s == 429 or s >= 500:
				outbox.note_attempt(id)
				_backoff(false)
			else:
				_quarantine(id, res)


## A refusal may be a resend of a document that already exists: ask for it as its owner.
func _check_existing(id: String, refusal: Dictionary) -> void:
	stats["requests"] += 1
	transport.send({"method": "GET", "url": "%s/users/%s/submissions/%s" % [base_url, auth.uid, id], "timeout_s": timeout_s,
		"headers": PackedStringArray(["Authorization: Bearer " + auth.id_token()])}, func(res: Dictionary):
			if not res.get("network_ok", false) or int(res["status"]) == 429 or int(res["status"]) >= 500:
				_backoff(false)
			elif int(res["status"]) == 200:
				_done(id, "duplicate")
			elif int(res["status"]) == 401:
				auth.invalidate()
				_backoff(false)
			else:
				_quarantine(id, refusal))


func _done(id: String, how: String) -> void:
	outbox.ack(id)
	stats[how] += 1
	failures = 0
	busy = false
	next_try_ms = 0


func _quarantine(id: String, res: Dictionary) -> void:
	var msg := "HTTP %d" % int(res.get("status", 0))
	var d = JSON.parse_string(String(res.get("body", "")))
	if d is Dictionary and d.get("error") is Dictionary:
		msg += " %s: %s" % [String(d["error"].get("status", "")), String(d["error"].get("message", ""))]
	outbox.quarantine(id, msg)
	stats["quarantined"] += 1
	busy = false
	next_try_ms = 0


func _backoff(permanent: bool) -> void:
	busy = false
	stats["transient"] += 1
	failures += 1
	var delay := minf(backoff_cap_s, backoff_base_s * pow(2.0, float(mini(failures - 1, 16))))
	if permanent:
		delay = backoff_cap_s
	next_try_ms = now_ms.call() + int(delay * rng.randf_range(0.5, 1.0) * 1000.0)
