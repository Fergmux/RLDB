extends GdUnitTestSuite
## F1 (owner feedback 20 Oct): the main menu shows "Logged in as <Persona>" and "Build version
## <version>" instead of "Steam ready as <persona> (App ID ...)". The version is stored once, in
## application/config/version.


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func test_build_version_reads_project_setting_expected_0_3_6() -> void:
	assert_str(SteamBridge.build_version()).is_equal("0.3.9")
	assert_str(String(ProjectSettings.get_setting("application/config/version"))).is_equal("0.3.9")


func test_display_name_capitalises_first_letter_only() -> void:
	assert_str(SteamBridge.display_name("fergmux")).is_equal("Fergmux")
	assert_str(SteamBridge.display_name("mcKay")).is_equal("McKay")
	assert_str(SteamBridge.display_name("")).is_equal("")


func test_identity_block_without_steam_shows_reason_and_version_no_app_id() -> void:
	# Arrange: tests run without Steam (no GodotSteam session).
	assert_bool(SteamBridge.available()).is_false()
	# Act
	var box: VBoxContainer = auto_free(MainMenu.identity_block())
	var texts := _labels(box, [])
	# Assert
	assert_array(texts).contains(["Build version 0.3.9"])
	var all := " ".join(texts)
	assert_str(all).not_contains("App ID")
	assert_str(all).not_contains("Steam ready")
	assert_object(box.find_child("SteamState", true, false)).is_not_null()
	assert_object(box.find_child("LoggedIn", true, false)).is_null()
