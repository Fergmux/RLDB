extends SceneTree
## Focused per-card runner (F26). Runs only the tests the coverage manifest maps to the given
## card id(s), through the normal GdUnit command-line tool, and exits with its exit code.
##
##   godot --headless --path . -s res://tests/cards/run_card.gd -- --id=36
##   godot --headless --path . -s res://tests/cards/run_card.gd -- --id=36,61
##   godot --headless --path . -s res://tests/cards/run_card.gd -- --all     (every card suite)
##
## Test files are added whole with -a and every other test function in them is excluded
## with -i <suite>:<test>, so only that card's tests execute. The whole project suite still
## runs with the usual GdUnitCmdTool -a res://tests command.

const MANIFEST := "res://tests/cards/manifest.json"
const CMD_TOOL := "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"


func _initialize() -> void:
	var ids := []
	var all := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			for s in a.substr(5).split(",", false):
				ids.append(str(int(s)))
		elif a == "--all":
			all = true
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CMD_TOOL, "--ignoreHeadlessMode", "-c"])
	if all:
		args.append_array(["-a", "res://tests/cards"])
	else:
		var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if not (data is Dictionary) or ids.is_empty():
			printerr("usage: -s res://tests/cards/run_card.gd -- --id=<card id>[,<id>...] | --all")
			quit(2)
			return
		var wanted := {}          # file -> {test: true}
		for id in ids:
			var e: Dictionary = data["cards"].get(id, {})
			if e.is_empty():
				printerr("card %s is not in the manifest" % id)
				quit(2)
				return
			print("card %s %s: %s" % [id, e["name"], e["status"]])
			for t in e["tests"]:
				for fname in t["tests"]:
					wanted.get_or_add(String(t["file"]), {})[fname] = true
		if wanted.is_empty():
			printerr("no tests mapped for %s" % [ids])
			quit(1)
			return
		var re := RegEx.new()
		re.compile("(?m)^func (test_\\w+)\\s*\\(")
		for file in wanted:
			args.append_array(["-a", file])
			var suite: String = file.get_file().get_basename()
			for mt in re.search_all(FileAccess.get_file_as_string(file)):
				if not wanted[file].has(mt.get_string(1)):
					args.append_array(["-i", "%s:%s" % [suite, mt.get_string(1)]])
	var out := []
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	for chunk in out:
		print(chunk)
	quit(code)
