class_name TelemetryFakeTransport
extends RefCounted
## Scripted stand-in for TelemetryHttp in tests: no network. Each send() takes the next queued
## response (a Dictionary, or a Callable(req) -> Dictionary) and answers synchronously; with no
## response queued the request is held unanswered (a hung server), so tests can prove nothing
## waits on it.

var requests: Array = []
var responses: Array = []
var held: Array = []


func send(req: Dictionary, cb: Callable) -> void:
	requests.append(req)
	if responses.is_empty():
		held.append([req, cb])
		return
	var r = responses.pop_front()
	cb.call(r.call(req) if r is Callable else r)


## Queues a plain HTTP response.
func reply(status: int, body = {}) -> void:
	responses.append({"network_ok": true, "status": status, "body": body if body is String else JSON.stringify(body), "error": ""})


## Queues a network failure (offline / timeout).
func offline() -> void:
	responses.append({"network_ok": false, "status": 0, "body": "", "error": "http_result_4"})


## A successful anonymous sign-up response.
func reply_signup(uid: String = "uid_test") -> void:
	reply(200, {"idToken": "idtok_" + uid, "refreshToken": "reftok_" + uid, "localId": uid, "expiresIn": "3600"})


## A successful token refresh response.
func reply_refresh(uid: String = "uid_test") -> void:
	reply(200, {"id_token": "idtok2_" + uid, "refresh_token": "reftok_" + uid, "user_id": uid, "expires_in": "3600"})


## URLs of the requests sent so far, shortened to their last path segment.
func paths() -> Array:
	return requests.map(func(r): return String(r["url"]).get_file().split("?")[0])
