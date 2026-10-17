extends GdUnitTestSuite
## Telemetry security review regressions (17 Oct 2026): ids from a network peer never become
## file paths, malformed views are tolerated, the outbox rejects unsafe ids and malformed stored
## items and applies its budget on load, and opting out deletes the queue on disk.

const ROOT := "user://test_telemetry/security"

var emitted: Array = []
var saved_dir: String
var saved_settings: String


func before_test() -> void:
	_wipe(ROOT)
	emitted = []
	saved_dir = Telemetry.DIR
	saved_settings = Telemetry.SETTINGS_PATH
	Telemetry.DIR = ROOT.path_join("svc")
	Telemetry.SETTINGS_PATH = ROOT.path_join("svc/ui_settings.cfg")


func after_test() -> void:
	Telemetry.DIR = saved_dir
	Telemetry.SETTINGS_PATH = saved_settings
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


func _collector() -> TelemetryCollector:
	var c := TelemetryCollector.new()
	c.profile_pid = "pp_test"
	c.emit_item = func(kind: String, id: String, state: String, _mode: String, _body: Dictionary):
		emitted.append([kind, id, state])
	return c


func _item(id: String, created: int = 1000) -> Dictionary:
	return {"id": id, "kind": "game", "state": "ready", "created_at": created, "updated_at": created,
		"fields": {"kind": "game", "created_at": created, "seq": created}, "body": "{}"}


# ------------------------------------------------------------------ ids from the network

func test_host_game_id_with_path_segments_queues_nothing() -> void:
	var c := _collector()
	c.on_client_view({"stage": "game", "you": 1, "game_no": 1, "tel_ids": {"series": "s1", "game": "../../../../evil"},
		"match": {"turn": 1, "active": 0}, "history": []}, "enet")
	assert_int(emitted.size()).is_equal(0)


func test_host_series_id_with_unsafe_characters_queues_nothing() -> void:
	var c := _collector()
	c.on_client_view({"stage": "game", "you": 1, "game_no": 1, "tel_ids": {"series": "a/b?c", "game": "g1"},
		"match": {"turn": 1, "active": 0}, "history": []}, "enet")
	assert_int(emitted.size()).is_equal(0)


func test_malformed_view_fields_still_give_one_report() -> void:
	var c := _collector()
	var tel := {"series": "s1", "game": "g1"}
	c.on_client_view({"stage": "rewards", "you": 1, "tel_ids": {"series": "s1"}, "deck": [[1], "x", {"id": 3}]}, "enet")
	c.on_client_view({"stage": "game", "you": 1, "game_no": 1, "tel_ids": tel, "match": "x", "history": "x"}, "enet")
	c.on_client_view({"stage": "rewards", "you": 1, "game_no": 1, "tel_ids": tel,
		"history": [{"game": 1, "winner": 0, "turns": 3, "hp": "x"}]}, "enet")
	assert_int(emitted.filter(func(e): return e[2] == "ready").size()).is_equal(1)


# ------------------------------------------------------------------ outbox

func test_outbox_refuses_ids_that_are_not_plain_names() -> void:
	var ob := TelemetryOutbox.new(ROOT.path_join("outbox"))
	for bad in ["../escape", "gclient_../../x", "a\\b", "", "x".repeat(200)]:
		assert_bool(ob.put(_item(bad))).is_false()
	assert_int(ob.size()).is_equal(0)
	assert_bool(FileAccess.file_exists(ROOT.path_join("escape.json"))).is_false()
	assert_bool(ob.put(_item("game_ok-1"))).is_true()


func test_outbox_quarantines_stored_items_with_a_bad_shape() -> void:
	var dir := ROOT.path_join("outbox")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("game_x.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "game_x", "fields": {}}))
	f.close()
	f = FileAccess.open(dir.path_join("game_y.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "game_y", "kind": "game", "state": "ready", "created_at": "soon", "fields": [], "body": 5}))
	f.close()
	var ob := TelemetryOutbox.new(dir)
	ob.load_all()
	assert_int(ob.size()).is_equal(0)
	assert_bool(ob.next_ready().is_empty()).is_true()
	assert_int(ob.quarantined().size()).is_equal(2)


func test_outbox_load_applies_the_budget() -> void:
	var ob := TelemetryOutbox.new(ROOT.path_join("outbox"), 10)
	for i in 5:
		ob.put(_item("game_%d" % i, 1000 + i))
	var small := TelemetryOutbox.new(ROOT.path_join("outbox"), 2)
	small.load_all()
	assert_int(small.size()).is_equal(2)


func test_clear_all_deletes_queued_files_that_were_never_loaded() -> void:
	var ob := TelemetryOutbox.new(ROOT.path_join("outbox"))
	ob.put(_item("game_a"))
	ob.put(_item("game_b"))
	var fresh := TelemetryOutbox.new(ROOT.path_join("outbox"))
	fresh.clear_all()
	var again := TelemetryOutbox.new(ROOT.path_join("outbox"))
	again.load_all()
	assert_int(again.size()).is_equal(0)
