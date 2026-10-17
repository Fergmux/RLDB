extends GdUnitTestSuite
## Telemetry service: environment stamping, the player's sharing setting (off stops collection
## and deletes the unsent queue), kill switch, environment resolution and the Steam ID hash.

const ROOT := "user://test_telemetry/service"

var saved_dir: String
var saved_settings: String


func before_test() -> void:
	saved_dir = Telemetry.DIR
	saved_settings = Telemetry.SETTINGS_PATH
	_wipe(ROOT)
	Telemetry.DIR = ROOT
	Telemetry.SETTINGS_PATH = ROOT.path_join("ui_settings.cfg")


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


func _config(enabled: bool = true) -> TelemetryConfig:
	var c := TelemetryConfig.new()
	c.enabled = enabled
	c.environment = "test"
	c.target = "emulator"
	c.project_id = "p"
	c.api_key = "k"
	return c


func _service(enabled: bool = true) -> Telemetry:
	var t: Telemetry = auto_free(Telemetry.new())
	t.setup(_config(enabled), TelemetryFakeTransport.new())
	return t


func test_startup_queues_a_session_and_profile_stamped_with_the_environment() -> void:
	var t := _service()
	var kinds := t.outbox.items.values().map(func(i): return String(i["kind"]))
	assert_array(kinds).contains(["session", "profile"])
	for it in t.outbox.items.values():
		assert_str(String(it["fields"]["env"])).is_equal("test")
		assert_str(String(it["fields"]["content_hash"])).has_length(64)
		var body = JSON.parse_string(String(it["body"]))
		assert_str(String(body["meta"]["env"])).is_equal("test")


func test_profile_record_is_queued_only_once_per_install() -> void:
	_service()
	var t2 := _service()
	var kinds := t2.outbox.items.values().map(func(i): return String(i["kind"]))
	assert_int(kinds.count("profile")).is_equal(1)
	assert_int(kinds.count("session")).is_equal(2)


func test_turning_sharing_off_stops_collection_and_deletes_the_unsent_queue() -> void:
	var t := _service()
	Telemetry.instance = t
	assert_int(t.outbox.size()).is_greater(0)
	Telemetry.set_share_enabled(false)
	assert_bool(Telemetry.share_enabled()).is_false()
	assert_int(t.outbox.size()).is_equal(0)
	assert_bool(t.uploader.enabled).is_false()
	var s := Series.new()
	s.setup({"seed": 3})
	Telemetry.attach_series(s, "bot", "local")
	assert_object(s.observer).is_null()
	Telemetry.set_share_enabled(true)
	Telemetry.instance = null


func test_kill_switch_collects_nothing() -> void:
	var t := _service(false)
	assert_bool(t.collecting()).is_false()
	assert_int(t.outbox.size()).is_equal(0)


func test_environment_resolution_defaults() -> void:
	var none := PackedStringArray()
	assert_str(TelemetryConfig.resolve_environment("auto", none, none, true)).is_equal("dev")
	assert_str(TelemetryConfig.resolve_environment("auto", none, none, false)).is_equal("playtest")
	assert_str(TelemetryConfig.resolve_environment("auto", none, PackedStringArray(["res://addons/gdUnit4/bin/GdUnitCmdTool.gd"]), false)).is_equal("test")
	assert_str(TelemetryConfig.resolve_environment("auto", PackedStringArray(["--bot-shots=x"]), none, true)).is_equal("test")
	assert_str(TelemetryConfig.resolve_environment("production", none, none, true)).is_equal("production")


func test_test_environment_never_targets_the_live_project_by_default() -> void:
	var c := TelemetryConfig.resolve(PackedStringArray(["--telemetry-env=test"]), PackedStringArray())
	assert_str(c.target).is_equal("none")
	assert_bool(c.active()).is_false()


func test_steam_hash_is_salted_one_way_and_stable() -> void:
	var a := Telemetry.hash_steam_id(76561197960287930, "salt1")
	assert_str(a).is_equal(Telemetry.hash_steam_id(76561197960287930, "salt1"))
	assert_str(a).is_not_equal(Telemetry.hash_steam_id(76561197960287930, "salt2"))
	assert_str(a).has_length(32)
	assert_str(a).not_contains("76561197960287930")


func test_completed_record_is_not_overwritten_by_a_later_signal() -> void:
	var t := _service()
	t._emit_item("game", "game_x", "ready", "bot", {"kind": "game", "v": 1})
	t._emit_item("game", "game_x", "open", "bot", {"kind": "game", "v": 2})
	var body = JSON.parse_string(String(t.outbox.get_item("game_x")["body"]))
	assert_int(int(body["v"])).is_equal(1)
	assert_str(String(t.outbox.get_item("game_x")["state"])).is_equal("ready")
