extends SceneTree
## Developer-only telemetry tool (no player UI). Run from rldb/ with the editor binary:
##   godot --headless --path . -s res://src/dev/telemetry_tool.gd -- <command> [target] [--telemetry-env=X]
## commands:
##   --inspect       print config, identity (uid shortened), queue and quarantine (no secrets)
##   --flush         upload the queue now (ignores backoff), then print the result
##   --test-upload   queue one synthetic probe report and upload it; exits 0 only when accepted
##   --purge         delete the local queue and quarantine (not the identity)
##   --sim-series    play one bot-vs-bot draft series (Bo3) through the real collector, then upload
## target: --telemetry-emulator (local emulators) or --telemetry-live (real project). The
## environment defaults to "test" for --test-upload, so probes never mix with real statistics.

const TIMEOUT_S := 40.0

var _t: Telemetry
var _cmd := ""
var _elapsed := 0.0
var _probe_id := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in ["--inspect", "--flush", "--test-upload", "--purge", "--sim-series"]:
			_cmd = a
	if _cmd == "":
		print("usage: -- --inspect | --flush | --test-upload | --purge  [--telemetry-emulator | --telemetry-live] [--telemetry-env=test]")
		quit(2)
		return
	var cfg := TelemetryConfig.resolve(args, OS.get_cmdline_args())
	if _cmd in ["--test-upload", "--sim-series"] and not " ".join(args).contains("--telemetry-env="):
		cfg.environment = "test"
	if cfg.environment == "test" and cfg.target == "none" and _cmd != "--inspect":
		print("No target: add --telemetry-emulator or --telemetry-live.")
		quit(2)
		return
	_t = Telemetry.boot(root, cfg)
	match _cmd:
		"--inspect":
			_inspect()
			quit(0)
		"--purge":
			_t.outbox.clear_all()
			print("Local queue and quarantine deleted.")
			quit(0)
		"--test-upload":
			_probe_id = "game_probe" + Series.new_telemetry_id().substr(0, 20)
			_t._emit_item("game", _probe_id, "ready", "none", {"kind": "game", "probe": true,
				"ids": {"game_id": _probe_id.substr(5)}, "note": "telemetry_tool connectivity probe; ignored by aggregation"})
			print("Queued probe %s (env=%s, target=%s)." % [_probe_id, cfg.environment, cfg.target])
			_t.uploader.reset_backoff()
		"--flush":
			_t.uploader.reset_backoff()
		"--sim-series":
			_sim_series()
			_t.uploader.reset_backoff()


func _process(delta: float) -> bool:
	if _t == null or _cmd in ["--inspect", "--purge"]:
		return false
	_elapsed += delta
	var up := _t.uploader
	if not up.busy and up.next_try_ms > 0 and up.failures == 0:
		up.next_try_ms = 0
	up.tick()
	var probe_done := _probe_id != "" and not _t.outbox.has(_probe_id)
	var drained := _t.outbox.next_ready().is_empty() and not up.busy
	if (_cmd == "--test-upload" and probe_done) or (_cmd in ["--flush", "--sim-series"] and drained) or _elapsed > TIMEOUT_S:
		_report()
		var ok := probe_done and int(up.stats["quarantined"]) == 0 and (int(up.stats["accepted"]) + int(up.stats["duplicate"])) > 0
		if _cmd == "--test-upload":
			print("PROBE %s" % ("ACCEPTED" if ok else "NOT ACCEPTED"))
			quit(0 if ok else 1)
		else:
			quit(0)
	return false


## Bot-vs-bot draft series in "bot" mode through the real Series, rules engine and collector.
func _sim_series() -> void:
	var s := Series.new()
	s.setup({"seed": 4242, "best_of": 3, "deck_mode": "draft", "names": ["Sim A", "Sim B"], "mode": "bot"})
	Telemetry.attach_series(s, "bot", "local")
	var bots := [BotBrain.new(0, 1), BotBrain.new(1, 2)]
	var steps := 0
	while s.stage != Series.STAGE_OVER and steps < 20000:
		steps += 1
		var acted := false
		for p in 2:
			var cmd: Dictionary = bots[p].decide(s.game) if s.stage == Series.STAGE_GAME else bots[p].series_command(s)
			if not cmd.is_empty() and s.submit(p, cmd) == "":
				acted = true
		if not acted and s.stage == Series.STAGE_GAME:
			s.submit(s.game.active, {"t": "next_phase"})
	print("Simulated series: stage=%s scores=%s games=%d steps=%d queued=%d" % [s.stage, s.scores, s.history.size(), steps, _t.outbox.size()])


func _report() -> void:
	var up := _t.uploader
	print("uploader: accepted=%d duplicate=%d quarantined=%d transient=%d requests=%d last_status=%d" % [
		up.stats["accepted"], up.stats["duplicate"], up.stats["quarantined"], up.stats["transient"], up.stats["requests"], up.last_status])
	print("auth: uid=%s signups=%d refreshes=%d" % [_short(_t.auth.uid), _t.auth.stats["signups"], _t.auth.stats["refreshes"]])
	print("queue: %d item(s), quarantine: %d" % [_t.outbox.size(), _t.outbox.quarantined().size()])
	for q in _t.outbox.quarantined():
		print("  quarantined %s: %s" % [q["id"], q["diagnostic"]])


func _inspect() -> void:
	var c := _t.config
	print("environment=%s target=%s enabled=%s active=%s share=%s %s" % [c.environment, c.target, c.enabled, c.active(), Telemetry.share_enabled(), c.off_reason])
	print("build=%s content_hash=%s" % [c.build_label(), _t.content_hash.substr(0, 12)])
	print("participant=%s steam_hash=%s" % [_t.install_pid, "yes (unverified)" if _t.steam_hash != "" else "none"])
	print("uid=%s account=%s" % [_short(_t.auth.uid), _t.auth.has_account()])
	print("queue: %d item(s), %d bytes" % [_t.outbox.size(), _t.outbox.bytes_used()])
	for id in _t.outbox.items:
		var it: Dictionary = _t.outbox.items[id]
		print("  %s kind=%s state=%s priority=%d attempts=%d env=%s" % [id, it["kind"], it["state"], it["priority"], it["attempts"], it["fields"].get("env", "?")])
	for q in _t.outbox.quarantined():
		print("  quarantined %s: %s" % [q["id"], q["diagnostic"]])


static func _short(uid: String) -> String:
	return (uid.substr(0, 6) + "…") if uid != "" else "(none)"
