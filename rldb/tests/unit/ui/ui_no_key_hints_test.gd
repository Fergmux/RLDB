extends GdUnitTestSuite
## L30 (owner, 2026-11-05): "I don't want keyboard shortcut prompts visible anywhere in the game."
## Scans every player-facing script (UI, tutorial) and data file for string literals that name a key as a
## hint: "(Esc)", "Esc to ...", "press Enter", a drawn "Esc" keycap, and so on. Comments are ignored, and the
## shortcuts themselves keep working; only their visible hints are banned.

const ROOTS := ["res://src/ui", "res://src/tutorial", "res://data"]
## A key named inside a string literal as a hint.
const HINT := "\"[^\"\\n]*(\\((Esc|Escape|Enter|Return|Space|Tab|Ctrl[^)]*|Shift[^)]*|Alt[^)]*|F[0-9]+)\\)|\\b(press|hit) (Esc|Escape|Enter|Return|Space|Tab)\\b|\\b(Esc|Escape) to \\w+|\\bkeycap\\b)[^\"\\n]*\""
## A bare "Esc" string drawn as a keycap label.
const BARE := "\"(Esc|Enter|Space|Tab)\""


func _files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".json"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_files(dir.path_join(sub), out)


func _offenders() -> Array[String]:
	var files: Array[String] = []
	for r in ROOTS:
		_files(r, files)
	var hint := RegEx.create_from_string(HINT)
	var bare := RegEx.create_from_string(BARE)
	var bad: Array[String] = []
	for p in files:
		var lines := FileAccess.get_file_as_string(p).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue   # comments and doc comments may describe the shortcuts
			if hint.search(line) != null or bare.search(line) != null:
				bad.append("%s:%d: %s" % [p, i + 1, code])
	return bad


func test_no_keyboard_shortcut_hints_are_shown_anywhere() -> void:
	var bad := _offenders()
	assert_array(bad).override_failure_message("Keyboard hints shown to players (L30):\n" + "\n".join(bad)).is_empty()


func test_the_prompt_cancel_button_has_no_keycap_hint() -> void:
	var b := auto_free(PromptPlate.CancelButton.new()) as PromptPlate.CancelButton
	assert_str(b.tooltip_text).not_contains("Esc")
	assert_str(b.text).is_equal("Cancel")
