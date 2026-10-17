extends GdUnitTestSuite
## F26 coverage gate. Fails when any catalogue card id is missing from
## tests/cards/manifest.json, when a "covered" card maps to no test or to a test that does
## not exist / asserts nothing, when a pending card has no reason, or when a test_cNNN_
## function exists that the manifest does not list (regenerate with
## `python tools/card_test_manifest.py`).

const MANIFEST := "res://tests/cards/manifest.json"


func _manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST)
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}


## Body of `func name(` in `src`: the lines up to the next top-level declaration.
func _body(src: String, fname: String) -> String:
	var start := src.find("func %s(" % fname)
	if start == -1:
		return ""
	var nxt := src.find("\nfunc ", start + 5)
	return src.substr(start, (nxt - start) if nxt != -1 else -1)


func test_manifest_maps_every_catalogue_card() -> void:
	var cards: Dictionary = _manifest().get("cards", {})
	var missing := []
	for d in CardDB.all():
		if not cards.has(str(int(d["id"]))):
			missing.append(int(d["id"]))
	assert_array(missing).is_empty()
	assert_int(cards.size()).is_equal(CardDB.all().size())


func test_manifest_covered_cards_map_to_real_asserting_tests() -> void:
	var cards: Dictionary = _manifest().get("cards", {})
	var bad := []
	var sources := {}
	for id in cards:
		var e: Dictionary = cards[id]
		var status := String(e.get("status", ""))
		if status.begins_with("pending("):
			if status.length() <= "pending()".length():
				bad.append("%s: pending without a reason" % id)
			continue
		if status != "covered":
			bad.append("%s: unknown status %s" % [id, status])
			continue
		if e.get("tests", []).is_empty():
			bad.append("%s: covered but no tests" % id)
		for t in e.get("tests", []):
			var file := String(t["file"])
			if not sources.has(file):
				sources[file] = FileAccess.get_file_as_string(file)
			if t["tests"].is_empty():
				bad.append("%s: %s lists no test names" % [id, file])
			for fname in t["tests"]:
				var body := _body(sources[file], fname)
				if body == "":
					bad.append("%s: %s:%s does not exist" % [id, file, fname])
				elif not (body.contains("assert_") or body.contains("_expect_")):
					bad.append("%s: %s:%s asserts nothing" % [id, file, fname])
	assert_array(bad).is_empty()


func test_manifest_lists_every_card_test_function() -> void:
	var cards: Dictionary = _manifest().get("cards", {})
	var listed := {}
	for id in cards:
		for t in cards[id].get("tests", []):
			for fname in t["tests"]:
				listed["%s|%s" % [id, fname]] = true
	var re := RegEx.new()
	re.compile("(?m)^func (test_c(\\d{3})_\\w+)\\s*\\(")
	var unlisted := []
	for file in _gd_files("res://tests"):
		for mt in re.search_all(FileAccess.get_file_as_string(file)):
			var key := "%d|%s" % [int(mt.get_string(2)), mt.get_string(1)]
			if not listed.has(key):
				unlisted.append("%s (%s)" % [key, file])
	assert_array(unlisted).is_empty()


func _gd_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out += _gd_files(dir.path_join(sub))
	return out
