extends GdUnitTestSuite
## Cloud statistics sync (C1) against a scripted transport (no network): link, pull, merge, push
## with optimistic concurrency, a lost race, offline backoff, refusals, the sharing switch, the
## body cap and the gzip/base64 encoding. Deterministic: injected clocks, no randomness that matters.

const ROOT := "user://test_telemetry/stats_sync"
const HASH := "0123456789abcdef0123456789abcdef"
const BASE := "http://127.0.0.1:8180/v1/projects/p/databases/(default)/documents"

var now: Array = [1_700_000_000_000]
var net: TelemetryFakeTransport
var auth: TelemetryAuth
var saved_dir: String
var saved_settings: String
var saved_provider: Callable


func before_test() -> void:
	PlayerStats.clear()
	_wipe(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)
	saved_dir = Telemetry.DIR
	saved_settings = Telemetry.SETTINGS_PATH
	saved_provider = Telemetry.steam_id_provider
	Telemetry.DIR = ROOT
	Telemetry.SETTINGS_PATH = ROOT.path_join("ui_settings.cfg")
	net = TelemetryFakeTransport.new()
	auth = TelemetryAuth.new(net, "http://a/signup", "http://a/token", ROOT.path_join("cred.cfg"))
	auth.now_ms = func() -> int: return now[0]


func after_test() -> void:
	Telemetry.DIR = saved_dir
	Telemetry.SETTINGS_PATH = saved_settings
	Telemetry.steam_id_provider = saved_provider
	Telemetry.instance = null
	PlayerStats.clear()
	_wipe(ROOT)
	StatsSync.set_status("local")


func _wipe(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for d in da.get_directories():
		_wipe(path.path_join(d))
	for f in da.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _sync() -> StatsSync:
	var s := StatsSync.new(net, auth, BASE, HASH, ROOT.path_join("stats_sync.cfg"))
	s.now_ms = func() -> int: return now[0]
	s.rng.seed = 1
	return s


## Runs ticks (advancing the clock a second each) until the transport is idle and nothing is due.
func _run(s: StatsSync, ticks: int = 12) -> void:
	for i in ticks:
		s.tick()
		now[0] += 1000


func _body(req: Dictionary) -> Dictionary:
	return JSON.parse_string(String(req.get("body", "{}")))


## A Firestore REST document holding `shared` (a PlayerStats record) at revision `rev`.
func _doc(shared: Dictionary, rev: int, update_time: String) -> Dictionary:
	var enc := StatsSync.encode_body(PlayerStats.shared(shared))
	return {"name": "x", "updateTime": update_time, "fields": {"schema_version": {"integerValue": "1"},
		"steam_hash": {"stringValue": HASH}, "uid": {"stringValue": "other"}, "rev": {"integerValue": str(rev)},
		"enc": {"stringValue": "gzip64"}, "raw_len": {"integerValue": str(enc[1])}, "body": {"stringValue": enc[0]}}}


func _cloud_record(ids: Array) -> Dictionary:
	var d := PlayerStats.empty()
	for i in ids.size():
		d["duels"].append({"id": ids[i], "t": 1760000000 + i, "s": i, "mode": "steam", "won": true, "turns": 8, "ms": 400000})
	d["devices"]["feedfeedfeedfeed"] = {"draft_picks": {"33": 3}, "drafts_completed": 1}
	return PlayerStats.sanitize(d)


func _commit_ok(update_time: String) -> Dictionary:
	return {"writeResults": [{"updateTime": update_time}], "commitTime": update_time}


func test_first_sync_links_reads_and_creates_the_cloud_copy() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6, "ms": 120000})
	net.reply_signup("uid_a")
	net.reply(200, {"writeResults": [{}]})           # link
	net.reply(404, {"error": {"status": "NOT_FOUND"}})  # no cloud copy yet
	net.reply(200, _commit_ok("2026-10-20T10:00:00.000001Z"))
	var s := _sync()
	_run(s)
	assert_int(net.requests.size()).is_equal(4)
	var link: Dictionary = _body(net.requests[1])["writes"][0]
	assert_str(String(link["update"]["name"])).ends_with("/stats_links/uid_a")
	assert_str(String(link["update"]["fields"]["steam_hash"]["stringValue"])).is_equal(HASH)
	assert_str(String(net.requests[2]["method"])).is_equal("GET")
	assert_str(String(net.requests[2]["url"])).ends_with("/player_stats/" + HASH)
	var push: Dictionary = _body(net.requests[3])["writes"][0]
	assert_dict(push["currentDocument"]).is_equal({"exists": false})
	var f: Dictionary = push["update"]["fields"]
	assert_str(String(f["rev"]["integerValue"])).is_equal("1")
	assert_str(String(f["uid"]["stringValue"])).is_equal("uid_a")
	assert_str(String(f["enc"]["stringValue"])).is_equal("gzip64")
	assert_array(f.keys()).contains_exactly_in_any_order(["schema_version", "steam_hash", "uid", "rev", "enc", "raw_len", "body"])
	var back = JSON.parse_string(StatsSync.decode_body("gzip64", String(f["body"]["stringValue"])))
	assert_int((back["duels"] as Array).size()).is_equal(1)
	assert_bool(back.has("device")).is_false()          # the shared part only
	assert_bool(back.has("account")).is_false()
	assert_str(String(StatsSync.status["state"])).is_equal("synced")
	assert_str(String(PlayerStats.load_data()["account"])).is_equal(HASH)


func test_raw_steam_id_is_never_sent() -> void:
	var steam_id := 76561198000000042
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6})
	net.reply_signup("uid_a")
	net.reply(200, {})
	net.reply(404, {})
	net.reply(200, _commit_ok("t1"))
	_run(_sync())
	for r in net.requests:
		assert_bool(String(r.get("body", "")).contains(str(steam_id))).is_false()
		assert_bool(String(r["url"]).contains(str(steam_id))).is_false()


func test_second_computer_reads_the_cloud_copy_and_merges_it_in() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": false, "turns": 4})
	net.reply_signup("uid_b")
	net.reply(200, {})
	net.reply(200, _doc(_cloud_record(["00000000000000c1", "00000000000000c2"]), 5, "2026-10-20T09:00:00Z"))
	net.reply(200, _commit_ok("2026-10-20T10:00:00Z"))
	_run(_sync())
	var d := PlayerStats.load_data()
	assert_int(d["duels"].size()).is_equal(3)
	assert_int(int(PlayerStats.draft_picks(d)["33"])).is_equal(3)
	# The merged record goes back with the version precondition and the next revision.
	var push: Dictionary = _body(net.requests[3])["writes"][0]
	assert_dict(push["currentDocument"]).is_equal({"updateTime": "2026-10-20T09:00:00Z"})
	assert_str(String(push["update"]["fields"]["rev"]["integerValue"])).is_equal("6")


func test_an_identical_cloud_copy_is_not_written_again() -> void:
	var cloud := _cloud_record(["00000000000000c1"])
	net.reply_signup("uid_b")
	net.reply(200, {})
	net.reply(200, _doc(cloud, 2, "t2"))
	PlayerStats.replace(cloud)
	var s := _sync()
	_run(s)
	assert_int(net.requests.size()).is_equal(3)          # sign-up, link, read: no write
	assert_str(String(StatsSync.status["state"])).is_equal("synced")


func test_a_lost_race_rereads_merges_and_writes_both_sides() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6})
	net.reply_signup("uid_a")
	net.reply(200, {})
	net.reply(200, _doc(_cloud_record(["00000000000000c1"]), 1, "v1"))
	net.reply(400, {"error": {"status": "FAILED_PRECONDITION", "message": "the stored version does not match"}})
	net.reply(200, _doc(_cloud_record(["00000000000000c1", "00000000000000c9"]), 2, "v2"))
	net.reply(200, _commit_ok("v3"))
	var s := _sync()
	_run(s, 20)
	assert_int(s.stats["conflicts"]).is_equal(1)
	var last: Dictionary = _body(net.requests[-1])["writes"][0]
	assert_dict(last["currentDocument"]).is_equal({"updateTime": "v2"})
	assert_str(String(last["update"]["fields"]["rev"]["integerValue"])).is_equal("3")
	var back = JSON.parse_string(StatsSync.decode_body("gzip64", String(last["update"]["fields"]["body"]["stringValue"])))
	assert_int((back["duels"] as Array).size()).is_equal(3)
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(3)


func test_offline_backs_off_and_keeps_the_local_record() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6})
	net.reply_signup("uid_a")
	net.offline()
	var s := _sync()
	_run(s, 3)
	assert_str(String(StatsSync.status["state"])).is_equal("pending")
	assert_int(s.next_try_ms).is_greater(now[0])
	var n := net.requests.size()
	_run(s, 1)
	assert_int(net.requests.size()).is_equal(n)          # backing off: nothing sent
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(1)
	assert_str(String(StatsSync.describe()["detail"])).is_equal("will sync when online")


func test_repeated_refusals_stop_the_cloud_copy_for_this_run() -> void:
	net.reply_signup("uid_a")
	for i in 3:
		net.reply(403, {"error": {"status": "PERMISSION_DENIED"}})
	var s := _sync()
	for i in 3:
		_run(s, 2)
		now[0] += 100_000      # past each backoff, well inside the ID token's hour
	_run(s, 4)
	assert_bool(s.enabled).is_false()
	assert_str(String(StatsSync.status["state"])).is_equal("error")
	assert_int(net.requests.size()).is_equal(4)          # sign-up and three link attempts, no loop


func test_a_refused_write_cannot_loop_link_pull_push() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6})
	net.reply_signup("uid_a")
	for i in 3:
		net.reply(200, {})                                # link
		net.reply(404, {})                                # pull
		net.reply(403, {"error": {"status": "PERMISSION_DENIED"}})   # push refused
	var s := _sync()
	for i in 6:
		_run(s, 3)
		now[0] += 100_000
	assert_bool(s.enabled).is_false()
	assert_int(net.requests.size()).is_equal(10)


func test_sharing_off_sends_nothing() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6})
	var s := _sync()
	s.enabled = false
	_run(s)
	assert_array(net.requests).is_empty()


func test_link_is_remembered_for_the_same_uid_and_hash() -> void:
	net.reply_signup("uid_a")
	net.reply(200, {})
	net.reply(404, {})
	_run(_sync())
	var before := net.requests.size()
	auth.invalidate()
	net.reply_refresh("uid_a")
	net.reply(404, {})
	_run(_sync())
	var urls: Array = net.requests.slice(before).map(func(r): return String(r["url"]))
	assert_int(urls.filter(func(u): return u.ends_with(":commit")).size()).is_equal(0)


func test_oversized_records_are_trimmed_oldest_first_to_fit_the_cap() -> void:
	var d := PlayerStats.empty()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in PlayerStats.MAX_DUELS:
		var cards := {}
		var plays := {}
		for j in 120:
			cards[str(rng.randi_range(1, 999999))] = rng.randi_range(1, 3)
			plays[str(rng.randi_range(1, 999999))] = rng.randi_range(1, 9)
		d["duels"].append({"id": "%016x" % i, "t": 1000 + i, "s": i, "mode": "bot", "won": true, "turns": 5, "cards": cards, "plays": plays})
	var pack := StatsSync.fit(PlayerStats.sanitize(d))
	assert_int(String(pack["body"]).length()).is_less_equal(StatsSync.MAX_BODY)
	var kept: Array = pack["shared"]["duels"]
	assert_int(kept.size()).is_less(PlayerStats.MAX_DUELS)
	assert_int(int(kept[-1]["t"])).is_equal(1000 + PlayerStats.MAX_DUELS - 1)   # the newest survive


func test_malformed_cloud_copy_is_never_merged_or_overwritten() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 6})
	net.reply_signup("uid_a")
	net.reply(200, {})
	net.reply(200, {"fields": {"enc": {"stringValue": "gzip64"}, "body": {"stringValue": "not base64 at all!"}}})
	var s := _sync()
	_run(s, 4)
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(1)
	assert_int(net.requests.filter(func(r): return String(r["url"]).ends_with(":commit")).size()).is_equal(1)   # the link only


func test_encoding_round_trips_and_decoding_is_bounded() -> void:
	var rec := _cloud_record(["00000000000000c1"])
	var enc := StatsSync.encode_body(PlayerStats.shared(rec))
	var back = JSON.parse_string(StatsSync.decode_body("gzip64", enc[0]))
	assert_str(PlayerStats.signature(PlayerStats.sanitize(back))).is_equal(PlayerStats.signature(rec))
	assert_str(StatsSync.decode_body("rot13", enc[0])).is_equal("")
	# A gzip bomb (far larger than MAX_RAW once inflated) is refused, not inflated.
	var bomb := PackedByteArray()
	bomb.resize(StatsSync.MAX_RAW + 1024)
	bomb.fill(32)
	var packed := Marshalls.raw_to_base64(bomb.compress(FileAccess.COMPRESSION_GZIP))
	assert_int(StatsSync.decode_body("gzip64", packed).length()).is_less_equal(StatsSync.MAX_RAW)


# ------------------------------------------------------------------ service wiring

func _config() -> TelemetryConfig:
	var c := TelemetryConfig.new()
	c.environment = "test"
	c.target = "emulator"
	c.project_id = "p"
	c.api_key = "k"
	c.steam_hash_salt = "salt"
	return c


func test_without_steam_statistics_stay_local_only() -> void:
	Telemetry.steam_id_provider = func() -> int: return 0
	var t: Telemetry = auto_free(Telemetry.new())
	t.setup(_config(), TelemetryFakeTransport.new())
	assert_object(t.stats_sync).is_null()
	assert_str(String(StatsSync.describe()["state"])).is_equal("local")
	assert_str(String(StatsSync.describe()["detail"])).is_equal("Steam is not running")


func test_steam_that_comes_up_after_start_up_still_starts_the_sync() -> void:
	# Regression (20 Oct 2026): Telemetry booted before SteamBridge.init(), so the Steam hash was
	# always empty and no record ever carried it. The service now picks Steam up when it appears.
	var steam := [0]
	Telemetry.steam_id_provider = func() -> int: return steam[0]
	var t: Telemetry = auto_free(Telemetry.new())
	t.setup(_config(), TelemetryFakeTransport.new())
	assert_object(t.stats_sync).is_null()
	steam[0] = 76561198000000042
	t._process(1.1)
	assert_object(t.stats_sync).is_not_null()
	assert_str(t.steam_hash).is_equal(Telemetry.hash_steam_id(76561198000000042, "salt"))
	assert_str(t.collector.steam_hash).is_equal(t.steam_hash)


func test_turning_sharing_off_stops_the_sync_and_says_local_only() -> void:
	Telemetry.steam_id_provider = func() -> int: return 76561198000000042
	var t: Telemetry = auto_free(Telemetry.new())
	t.setup(_config(), TelemetryFakeTransport.new())
	assert_object(t.stats_sync).is_not_null()
	Telemetry.instance = t
	Telemetry.set_share_enabled(false)
	assert_bool(t.stats_sync.enabled).is_false()
	assert_str(String(StatsSync.describe()["state"])).is_equal("local")
	assert_str(String(StatsSync.describe()["detail"])).is_equal("statistics sharing is off")
	Telemetry.set_share_enabled(true)
	assert_bool(t.stats_sync.enabled).is_true()
	Telemetry.instance = null
