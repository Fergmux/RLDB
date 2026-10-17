class_name TelemetryHttp
extends Node
## Asynchronous HTTPS transport for telemetry (one HTTPRequest per call, freed afterwards).
## Contract shared with test fakes:
##   send({method: "GET" | "POST", url, headers: PackedStringArray, body: String, timeout_s}, cb)
##   cb.call({network_ok: bool, status: int, body: String, error: String})
## network_ok is false for DNS / connect / TLS failures and timeouts (status 0). Never blocks:
## the request runs on Godot's HTTP client and the callback fires on a later frame.

## Requests still running (the developer tool waits for 0 before quitting).
var in_flight: int = 0


func send(req: Dictionary, cb: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = float(req.get("timeout_s", 15))
	h.use_threads = false
	add_child(h)
	in_flight += 1
	h.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		in_flight -= 1
		h.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS
		cb.call({"network_ok": ok, "status": code if ok else 0, "body": body.get_string_from_utf8(),
			"error": "" if ok else "http_result_%d" % result}))
	var method := HTTPClient.METHOD_POST if String(req.get("method", "GET")) == "POST" else HTTPClient.METHOD_GET
	var err := h.request(String(req["url"]), req.get("headers", PackedStringArray()), method, String(req.get("body", "")))
	if err != OK:
		in_flight -= 1
		h.queue_free()
		cb.call_deferred({"network_ok": false, "status": 0, "body": "", "error": "request_error_%d" % err})
