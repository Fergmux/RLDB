extends GdUnitTestSuite
## Telemetry uploader + auth against a scripted fake transport: accepted, duplicate, lost
## acknowledgement, expired token, permanent refusal, offline backoff without busy-looping, hung
## server never blocking, restart reusing the stored identity.

const ROOT := "user://test_telemetry/uploader"
const BASE := "https://firestore.example/v1/projects/p/databases/(default)/documents"

var clock: Array = [1_700_000_000_000]
var fake: TelemetryFakeTransport
var ob: TelemetryOutbox
var auth: TelemetryAuth
var up: TelemetryUploader


func before_test() -> void:
	_wipe(ROOT)
	clock = [1_700_000_000_000]
	_build()


func after_test() -> void:
	_wipe(ROOT)


func _build() -> void:
	fake = TelemetryFakeTransport.new()
	ob = TelemetryOutbox.new(ROOT.path_join("outbox"))
	ob.load_all()
	auth = TelemetryAuth.new(fake, "https://auth.example/v1/accounts:signUp?key=k", "https://token.example/v1/token?key=k", ROOT.path_join("credential.cfg"))
	auth.now_ms = func() -> int: return clock[0]
	up = TelemetryUploader.new(ob, auth, fake, BASE)
	up.now_ms = func() -> int: return clock[0]
	up.rng.seed = 5


func _wipe(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for d in da.get_directories():
		_wipe(path.path_join(d))
	for f in da.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _queue(id: String = "game_g1") -> void:
	ob.put({"id": id, "kind": "game", "state": "ready", "created_at": clock[0], "updated_at": clock[0],
		"fields": {"schema_version": 1, "kind": "game", "env": "test", "build": "t", "content_hash": "a".repeat(64),
			"mode": "bot", "created_at": clock[0], "seq": 3}, "body": "{\"kind\":\"game\"}"})


func _advance(ms: int) -> void:
	clock[0] += ms


func test_first_upload_signs_up_once_and_commits_an_immutable_create() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(200, {"writeResults": [{}]})
	up.tick()
	assert_array(fake.paths()).is_equal(["accounts:signUp", "documents:commit"])
	var body = JSON.parse_string(String(fake.requests[1]["body"]))
	var w: Dictionary = body["writes"][0]
	assert_str(String(w["update"]["name"])).is_equal("projects/p/databases/(default)/documents/users/u1/submissions/game_g1")
	assert_bool(w["currentDocument"]["exists"]).is_false()
	assert_str(String(w["updateTransforms"][0]["setToServerValue"])).is_equal("REQUEST_TIME")
	assert_str(String(w["update"]["fields"]["uid"]["stringValue"])).is_equal("u1")
	assert_str(String(w["update"]["fields"]["seq"]["integerValue"])).is_equal("3")
	assert_bool(ob.has("game_g1")).is_false()
	assert_int(int(up.stats["accepted"])).is_equal(1)


func test_refresh_token_is_stored_but_never_sent_in_documents() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(200)
	up.tick()
	var cf := ConfigFile.new()
	assert_int(cf.load(ROOT.path_join("credential.cfg"))).is_equal(OK)
	assert_str(String(cf.get_value("auth", "refresh_token", ""))).is_equal("reftok_u1")
	assert_str(String(fake.requests[1]["body"])).not_contains("reftok_u1")


func test_lost_acknowledgement_is_retried_once_and_acked_as_duplicate() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.offline()              # the server stored it, but the reply was lost
	up.tick()
	assert_bool(ob.has("game_g1")).is_true()
	# No busy loop: repeated ticks before the backoff expires send nothing.
	var sent := fake.requests.size()
	for i in 20:
		up.tick()
	assert_int(fake.requests.size()).is_equal(sent)
	_advance(10 * 60 * 1000)
	fake.reply(409, {"error": {"status": "ALREADY_EXISTS"}})
	up.tick()
	assert_bool(ob.has("game_g1")).is_false()
	assert_int(int(up.stats["duplicate"])).is_equal(1)
	assert_int(int(up.stats["accepted"])).is_equal(0)


func test_expired_token_refreshes_and_resends_silently() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(401, {"error": {"status": "UNAUTHENTICATED"}})
	fake.reply_refresh("u1")
	fake.reply(200)
	up.tick()
	assert_array(fake.paths()).is_equal(["accounts:signUp", "documents:commit", "token", "documents:commit"])
	assert_str(String(fake.requests[2]["body"])).contains("grant_type=refresh_token")
	assert_bool(ob.has("game_g1")).is_false()


func test_token_older_than_an_hour_is_refreshed_before_upload() -> void:
	_queue("game_a")
	fake.reply_signup("u1")
	fake.reply(200)
	up.tick()
	_advance(2 * 3600 * 1000)
	_queue("game_b")
	fake.reply_refresh("u1")
	fake.reply(200)
	up.tick()
	assert_array(fake.paths()).is_equal(["accounts:signUp", "documents:commit", "token", "documents:commit"])
	assert_int(ob.size()).is_equal(0)


func test_permanent_validation_error_is_quarantined_and_not_retried() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(400, {"error": {"status": "INVALID_ARGUMENT", "message": "bad field"}})
	up.tick()
	assert_bool(ob.has("game_g1")).is_false()
	assert_int(ob.quarantined().size()).is_equal(1)
	var sent := fake.requests.size()
	for i in 5:
		_advance(3600 * 1000)
		up.tick()
	assert_int(fake.requests.size()).is_equal(sent)


func test_forbidden_resend_of_an_existing_document_counts_as_duplicate() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(403, {"error": {"status": "PERMISSION_DENIED"}})
	fake.reply(200, {"name": "x"})
	up.tick()
	assert_array(fake.paths()).is_equal(["accounts:signUp", "documents:commit", "game_g1"])
	assert_bool(ob.has("game_g1")).is_false()
	assert_int(ob.quarantined().size()).is_equal(0)


func test_forbidden_new_document_is_quarantined() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(403, {"error": {"status": "PERMISSION_DENIED"}})
	fake.reply(404, {"error": {"status": "NOT_FOUND"}})
	up.tick()
	assert_int(ob.quarantined().size()).is_equal(1)
	assert_str(String(ob.quarantined()[0]["diagnostic"])).contains("PERMISSION_DENIED")


func test_offline_sign_up_backs_off_exponentially_with_jitter() -> void:
	_queue()
	var delays := []
	for i in 4:
		fake.offline()
		up.tick()
		delays.append(up.next_try_ms - clock[0])
		clock[0] = up.next_try_ms
	assert_array(fake.paths()).is_equal(["accounts:signUp", "accounts:signUp", "accounts:signUp", "accounts:signUp"])
	for i in 4:
		var full := 5000.0 * pow(2.0, i)
		assert_float(float(delays[i])).is_between(full * 0.5 - 1.0, full)
	assert_bool(ob.has("game_g1")).is_true()


func test_server_errors_and_rate_limits_are_retried_later() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.reply(503)
	up.tick()
	assert_bool(ob.has("game_g1")).is_true()
	_advance(60 * 1000)
	fake.reply(429)
	up.tick()
	assert_bool(ob.has("game_g1")).is_true()
	_advance(60 * 1000)
	fake.reply(200)
	up.tick()
	assert_bool(ob.has("game_g1")).is_false()


func test_hung_server_never_blocks_and_sends_one_request_at_a_time() -> void:
	_queue("game_a")
	_queue("game_b")
	up.tick()                    # sign-up request is held unanswered
	for i in 50:
		_advance(1000)
		up.tick()
	assert_int(fake.requests.size()).is_equal(1)
	assert_bool(up.busy).is_true()


func test_restart_reuses_stored_identity_and_uploads_queued_items() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.offline()
	up.tick()
	# The app quits; a new process loads the same outbox and credential.
	_build()
	assert_bool(ob.has("game_g1")).is_true()
	fake.reply_refresh("u1")
	fake.reply(200)
	up.tick()
	assert_array(fake.paths()).is_equal(["token", "documents:commit"])
	assert_bool(ob.has("game_g1")).is_false()


func test_revoked_refresh_token_falls_back_to_a_new_anonymous_account() -> void:
	_queue()
	fake.reply_signup("u1")
	fake.offline()
	up.tick()
	_build()
	fake.reply(400, {"error": {"message": "INVALID_REFRESH_TOKEN"}})
	up.tick()
	assert_bool(auth.has_account()).is_false()
	_advance(60 * 1000)
	fake.reply_signup("u2")
	fake.reply(200)
	up.tick()
	assert_str(auth.uid).is_equal("u2")
	assert_bool(ob.has("game_g1")).is_false()


func test_disabled_uploader_sends_nothing() -> void:
	_queue()
	up.enabled = false
	up.tick()
	assert_int(fake.requests.size()).is_equal(0)
