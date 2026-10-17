extends GdUnitTestSuite
## Telemetry review regressions (17 Oct 2026): an open record keeps its first environment label,
## and a token refresh refused for a reason other than a dead token keeps the install's identity.

const ROOT := "user://test_telemetry/identity_env"

var saved_dir: String
var saved_settings: String


func before_test() -> void:
	_wipe(ROOT)
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


# ------------------------------------------------------------------ environment label

func test_rewritten_open_record_keeps_its_first_environment() -> void:
	var c := TelemetryConfig.new()
	c.environment = "playtest"
	c.target = "emulator"
	c.project_id = "p"
	c.api_key = "k"
	var t: Telemetry = auto_free(Telemetry.new())
	t.setup(c, TelemetryFakeTransport.new())
	t._emit_item("draft", "draft_x", "open", "lan", {"kind": "draft", "v": 1})
	t.config.environment = "production"
	t._emit_item("draft", "draft_x", "ready", "lan", {"kind": "draft", "v": 2})
	var it := t.outbox.get_item("draft_x")
	assert_str(String(it["fields"]["env"])).is_equal("playtest")
	var body = JSON.parse_string(String(it["body"]))
	assert_str(String(body["meta"]["env"])).is_equal("playtest")
	assert_int(int(body["v"])).is_equal(2)


# ------------------------------------------------------------------ identity

func test_refresh_refused_for_a_config_reason_keeps_the_identity() -> void:
	var fake := TelemetryFakeTransport.new()
	var cred := ROOT.path_join("credential.cfg")
	var a := TelemetryAuth.new(fake, "https://auth.example/signUp", "https://token.example/token", cred)
	fake.reply_signup("u1")
	a.ensure_token(func(_k): pass)
	var again := TelemetryAuth.new(fake, "https://auth.example/signUp", "https://token.example/token", cred)
	fake.reply(400, {"error": {"code": 400, "message": "API key not valid. Please pass a valid API key.", "status": "INVALID_ARGUMENT"}})
	again.ensure_token(func(_k): pass)
	assert_bool(again.has_account()).is_true()
	assert_str(again.uid).is_equal("u1")
	var reread := TelemetryAuth.new(fake, "https://auth.example/signUp", "https://token.example/token", cred)
	assert_str(reread.uid).is_equal("u1")
