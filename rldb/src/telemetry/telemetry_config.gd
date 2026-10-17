class_name TelemetryConfig
extends RefCounted
## Resolved telemetry settings: the shipped file res://data/telemetry_config.json, then the
## executable name (an exported "<name>-dev.exe" records `dev`), then a developer override file (user://telemetry/dev.cfg), then command-line user args, then the
## RLDB_TELEMETRY environment variable. Players never see or edit any of this.
##
## environment: dev (editor, or an exported build whose executable name ends in "-dev"; the export
## plugin addons/rldb_export writes build/windows-dev/RLDB-dev.exe beside every export), playtest
## (exported builds), production (public release, only when
## the shipped file says so), test (GdUnit / dev driver runs / --telemetry-env=test).
## target: "live" (Firebase), "emulator" (local emulators) or "none" (collect nothing). Under
## `test` the target is "none" unless --telemetry-emulator or --telemetry-live is given, so
## automated runs never write to the real project by accident.

const PATH := "res://data/telemetry_config.json"
const DEV_OVERRIDE := "user://telemetry/dev.cfg"
const ENVIRONMENTS := ["dev", "playtest", "production", "test"]
const SCHEMA_VERSION := 1

var enabled: bool = true
var environment: String = "dev"
var target: String = "none"
var build: String = "0.0.0"
var project_id: String = ""
var api_key: String = ""
var database: String = "(default)"
var emulator_firestore: String = "127.0.0.1:8180"
var emulator_auth: String = "127.0.0.1:9199"
var steam_hash_salt: String = ""
var outbox: Dictionary = {"max_items": 400, "max_bytes": 8388608, "quarantine_max": 25, "abandon_after_hours": 12}
var upload: Dictionary = {"backoff_base_s": 5, "backoff_cap_s": 900, "idle_poll_s": 60, "http_timeout_s": 15}
var collect: Dictionary = {"max_events_per_game": 3000}
## Why telemetry is off ("" when active), for the developer tool only.
var off_reason: String = ""


## True when records are collected and uploaded (player consent is checked separately).
func active() -> bool:
	return enabled and target != "none"


## The resolved configuration for this process.
static func resolve(args: PackedStringArray = OS.get_cmdline_user_args(), all_args: PackedStringArray = OS.get_cmdline_args()) -> TelemetryConfig:
	var c := TelemetryConfig.new()
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if raw is Dictionary:
		c.apply_dict(raw)
	else:
		c.enabled = false
		c.off_reason = "config file missing"
	var env_req := String(raw.get("environment", "auto")) if raw is Dictionary else "auto"
	if not OS.has_feature("editor") and is_dev_executable(OS.get_executable_path()):
		env_req = "dev"
	var target_req := ""
	var dev := ConfigFile.new()
	if dev.load(DEV_OVERRIDE) == OK:
		c.enabled = bool(dev.get_value("dev", "enabled", c.enabled))
		env_req = String(dev.get_value("dev", "environment", env_req))
		target_req = String(dev.get_value("dev", "target", target_req))
	for a in args:
		if a == "--telemetry-off":
			c.enabled = false
			c.off_reason = "--telemetry-off"
		elif a.begins_with("--telemetry-env="):
			env_req = a.split("=", true, 1)[1]
		elif a == "--telemetry-emulator":
			target_req = "emulator"
		elif a == "--telemetry-live":
			target_req = "live"
	if OS.get_environment("RLDB_TELEMETRY").to_lower() in ["off", "0", "false"]:
		c.enabled = false
		c.off_reason = "RLDB_TELEMETRY"
	c.environment = resolve_environment(env_req, args, all_args, OS.has_feature("editor"))
	if target_req == "":
		target_req = "none" if c.environment == "test" else "live"
	c.target = target_req if target_req in ["live", "emulator", "none"] else "none"
	if not c.enabled and c.off_reason == "":
		c.off_reason = "disabled in config"
	return c


## True for an exported developer build: the executable is named "<name>-dev" (RLDB-dev.exe).
static func is_dev_executable(path: String) -> bool:
	return path.get_file().get_basename().to_lower().ends_with("-dev")


## Environment for a request ("auto" or a label) and the process' arguments.
static func resolve_environment(req: String, args: PackedStringArray, all_args: PackedStringArray, editor: bool) -> String:
	if req in ENVIRONMENTS:
		return req
	for a in all_args:
		if a.contains("GdUnitCmdTool") or a.contains("gdUnit4"):
			return "test"
	for a in args:
		if a.contains("shots") or a.contains("driver"):
			return "test"
	return "dev" if editor else "playtest"


## Copies known keys from a parsed config Dictionary.
func apply_dict(d: Dictionary) -> void:
	enabled = bool(d.get("enabled", true))
	build = String(d.get("build", build)).substr(0, 40)
	var fb: Dictionary = d.get("firebase", {})
	project_id = String(fb.get("project_id", ""))
	api_key = String(fb.get("api_key", ""))
	database = String(fb.get("database", "(default)"))
	var em: Dictionary = d.get("emulator", {})
	emulator_firestore = String(em.get("firestore", emulator_firestore))
	emulator_auth = String(em.get("auth", emulator_auth))
	steam_hash_salt = String(d.get("steam_hash_salt", ""))
	outbox.merge(d.get("outbox", {}), true)
	upload.merge(d.get("upload", {}), true)
	collect.merge(d.get("collect", {}), true)


## Build label stamped on every record ("-editor" for editor runs).
func build_label() -> String:
	return (build + ("-editor" if OS.has_feature("editor") else "")).substr(0, 48)


## Firestore REST base ".../documents" for the current target.
func firestore_base() -> String:
	var host := "https://firestore.googleapis.com" if target == "live" else "http://" + emulator_firestore
	return "%s/v1/projects/%s/databases/%s/documents" % [host, project_id, database]


## Firebase Auth anonymous sign-up URL.
func signup_url() -> String:
	var host := "https://identitytoolkit.googleapis.com" if target == "live" else "http://%s/identitytoolkit.googleapis.com" % emulator_auth
	return "%s/v1/accounts:signUp?key=%s" % [host, api_key]


## Secure Token refresh URL.
func refresh_url() -> String:
	var host := "https://securetoken.googleapis.com" if target == "live" else "http://%s/securetoken.googleapis.com" % emulator_auth
	return "%s/v1/token?key=%s" % [host, api_key]


## Credential file for the current target (emulator identities never mix with live ones).
func credential_path(dir: String) -> String:
	return dir.path_join("credential.cfg" if target == "live" else "credential_%s.cfg" % target)
