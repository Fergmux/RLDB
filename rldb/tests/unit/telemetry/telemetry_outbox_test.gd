extends GdUnitTestSuite
## Telemetry outbox: durable across restarts, atomic, bounded with documented eviction order,
## bounded quarantine with redacted diagnostics.

const ROOT := "user://test_telemetry/outbox"


func before_test() -> void:
	_wipe(ROOT)


func after_test() -> void:
	_wipe(ROOT)


func _wipe(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for d in da.get_directories():
		_wipe(path.path_join(d))
	for f in da.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _item(id: String, kind: String, created: int, body: String = "{}", state: String = "ready") -> Dictionary:
	return {"id": id, "kind": kind, "state": state, "created_at": created, "updated_at": created,
		"fields": {"kind": kind, "created_at": created, "seq": created}, "body": body}


func test_items_survive_restart_with_original_ids_and_timestamps() -> void:
	var ob := TelemetryOutbox.new(ROOT)
	ob.put(_item("game_a", "game", 1000))
	ob.put(_item("draft_b", "draft", 2000))
	var again := TelemetryOutbox.new(ROOT)
	again.load_all()
	assert_int(again.size()).is_equal(2)
	assert_int(int(again.get_item("game_a")["created_at"])).is_equal(1000)
	assert_str(String(again.get_item("draft_b")["kind"])).is_equal("draft")


func test_ack_deletes_only_that_item() -> void:
	var ob := TelemetryOutbox.new(ROOT)
	ob.put(_item("game_a", "game", 1000))
	ob.put(_item("game_b", "game", 1001))
	ob.ack("game_a")
	var again := TelemetryOutbox.new(ROOT)
	again.load_all()
	assert_bool(again.has("game_a")).is_false()
	assert_bool(again.has("game_b")).is_true()


func test_next_ready_prefers_priority_then_age_and_skips_open_items() -> void:
	var ob := TelemetryOutbox.new(ROOT)
	ob.put(_item("session_s", "session", 1))
	ob.put(_item("game_open", "game", 2, "{}", "open"))
	ob.put(_item("draft_d", "draft", 3))
	ob.put(_item("game_late", "game", 9))
	ob.put(_item("game_early", "game", 5))
	assert_str(String(ob.next_ready()["id"])).is_equal("game_early")
	ob.ack("game_early")
	ob.ack("game_late")
	assert_str(String(ob.next_ready()["id"])).is_equal("draft_d")


func test_rewriting_an_open_item_replaces_it_atomically() -> void:
	var ob := TelemetryOutbox.new(ROOT)
	ob.put(_item("game_g", "game", 10, "{\"v\":1}", "open"))
	ob.put(_item("game_g", "game", 10, "{\"v\":2}", "open"))
	var again := TelemetryOutbox.new(ROOT)
	again.load_all()
	assert_int(again.size()).is_equal(1)
	assert_str(String(again.get_item("game_g")["body"])).is_equal("{\"v\":2}")
	assert_bool(FileAccess.file_exists(ROOT.path_join("game_g.json.bak"))).is_false()


func test_interrupted_writes_are_recovered_on_load() -> void:
	var ob := TelemetryOutbox.new(ROOT)
	ob.put(_item("game_keep", "game", 10))
	# A crash after "old -> .bak" but before "tmp -> new": only the .bak and a temp file remain.
	DirAccess.rename_absolute(ROOT.path_join("game_keep.json"), ROOT.path_join("game_keep.json.bak"))
	var f := FileAccess.open(ROOT.path_join("game_keep.json.tmp"), FileAccess.WRITE)
	f.store_string("{half")
	f.close()
	var again := TelemetryOutbox.new(ROOT)
	again.load_all()
	assert_bool(again.has("game_keep")).is_true()
	assert_bool(FileAccess.file_exists(ROOT.path_join("game_keep.json.tmp"))).is_false()


func test_corrupt_files_are_quarantined_not_loaded() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var f := FileAccess.open(ROOT.path_join("game_bad.json"), FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	var ob := TelemetryOutbox.new(ROOT)
	ob.load_all()
	assert_int(ob.size()).is_equal(0)
	assert_int(ob.quarantined().size()).is_equal(1)


func test_item_budget_evicts_low_priority_before_game_reports() -> void:
	var ob := TelemetryOutbox.new(ROOT, 3)
	ob.put(_item("game_1", "game", 1))
	ob.put(_item("session_2", "session", 2))
	ob.put(_item("draft_3", "draft", 3))
	ob.put(_item("game_4", "game", 4))
	assert_int(ob.size()).is_equal(3)
	assert_bool(ob.has("session_2")).is_false()
	ob.put(_item("game_5", "game", 5))
	assert_bool(ob.has("draft_3")).is_false()
	assert_bool(ob.has("game_1")).is_true()


func test_byte_budget_drops_event_detail_before_whole_game_reports() -> void:
	var events := []
	for i in 400:
		events.append([i, 1, "draw", 0, 1, 1000 + i])
	var body := JSON.stringify({"kind": "game", "events": events, "counters": [{"1": {"draws": 400}}], "completeness": {"events": true}})
	var ob := TelemetryOutbox.new(ROOT, 100, body.length() + 1200)
	ob.put(_item("game_old", "game", 1, body))
	ob.put(_item("game_new", "game", 2, body))
	assert_bool(ob.has("game_old")).is_true()
	assert_bool(ob.has("game_new")).is_true()
	var old = JSON.parse_string(String(ob.get_item("game_old")["body"]))
	assert_int((old["events"] as Array).size()).is_equal(0)
	assert_int(int(old["completeness"]["events_dropped"])).is_equal(400)
	assert_bool(old["completeness"]["events"]).is_false()
	assert_int(int(old["counters"][0]["1"]["draws"])).is_equal(400)


func test_quarantine_is_bounded_and_redacts_tokens() -> void:
	var ob := TelemetryOutbox.new(ROOT, 100, 8388608, 2)
	for i in 4:
		ob.put(_item("game_q%d" % i, "game", i))
		ob.quarantine("game_q%d" % i, "HTTP 400 token eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMzQ1Njc4OTAiLCJ0eXAiOiJKV1QifQ")
	var q := ob.quarantined()
	assert_int(q.size()).is_equal(2)
	assert_str(String(q[0]["diagnostic"])).not_contains("eyJhbGci")
	assert_str(String(q[0]["diagnostic"])).contains("<redacted>")
	assert_int(ob.size()).is_equal(0)


func test_clear_all_removes_queue_and_quarantine() -> void:
	var ob := TelemetryOutbox.new(ROOT)
	ob.put(_item("game_a", "game", 1))
	ob.put(_item("game_b", "game", 2))
	ob.quarantine("game_b", "HTTP 400")
	ob.clear_all()
	var again := TelemetryOutbox.new(ROOT)
	again.load_all()
	assert_int(again.size()).is_equal(0)
	assert_int(again.quarantined().size()).is_equal(0)
