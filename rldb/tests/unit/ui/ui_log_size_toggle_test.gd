extends GdUnitTestSuite
## H11 (owner feedback 21 Oct 2026): the game log is short by default, a header toggle switches it
## to a tall size (a little more than the old one), and the viewer's choice is remembered.

var _was: bool


func before_test() -> void:
	_was = GameLog.expanded()


func after_test() -> void:
	GameLog.store_expanded(_was)


func test_automated_runs_keep_the_choice_in_the_test_file() -> void:
	assert_str(GameLog.settings_path()).is_equal(GameLog.TEST_SETTINGS_PATH)
	assert_str(GameLog.settings_path()).is_not_equal(UIStyle.SETTINGS_PATH)


func test_store_expanded_is_saved_and_read_back() -> void:
	# Arrange
	GameLog.store_expanded(true)
	# Act: forget the cached value and read the file again
	GameLog._expanded_loaded = false
	GameLog._expanded = false
	# Assert
	assert_bool(GameLog.expanded()).is_true()
	GameLog.store_expanded(false)
	GameLog._expanded_loaded = false
	assert_bool(GameLog.expanded()).is_false()


func test_store_expanded_keeps_the_other_settings_sections() -> void:
	var cf := ConfigFile.new()
	cf.load(GameLog.settings_path())
	cf.set_value("ui", "probe", 7)
	cf.save(GameLog.settings_path())
	GameLog.store_expanded(true)
	var back := ConfigFile.new()
	back.load(GameLog.settings_path())
	assert_int(int(back.get_value("ui", "probe", 0))).is_equal(7)
	assert_bool(bool(back.get_value(GameLog.SIZE_SECTION, GameLog.SIZE_KEY, false))).is_true()


func test_toggle_chevron_and_tooltip_follow_the_state() -> void:
	# Arrange
	var t: GameLog.LogToggle = auto_free(GameLog.LogToggle.new(false))
	assert_float(t.turn).is_equal(0.0)
	assert_str(t.tooltip_text).contains("more")
	# Act (not in the tree: the chevron turns at once)
	t.set_open(true)
	# Assert
	assert_float(t.turn).is_equal(1.0)
	assert_str(t.tooltip_text).contains("less")
	assert_str(Sfx.button_sound(t)).is_empty()   # set_expanded plays toggle_on / toggle_off
