extends GdUnitTestSuite
## Final L-batch review (design/review-final-2026-11-05.md): switching between the Options leaves
## (Settings, Customisation, Credits, L28) made the panel jump: Credits was about 150 px shorter and
## re-centred. Every Options leaf now has the same minimum height, and the Credits scroll fills it.


func test_every_options_leaf_has_the_shared_minimum_height() -> void:
	var mm: MainMenu = auto_free(MainMenu.new(SessionOptions.new()))
	for t in MainMenu.OPTIONS_LEAVES:
		var p: Control = auto_free(mm._leaf_panel(t))
		assert_float(p.custom_minimum_size.y).override_failure_message(t).is_equal(MainMenu.OPTIONS_MIN_H)


func test_credits_scroll_fills_the_panel() -> void:
	var mm: MainMenu = auto_free(MainMenu.new(SessionOptions.new()))
	var p: Control = auto_free(mm._leaf_panel("credits"))
	var sa := p.find_child("Credits", true, false) as Control
	assert_object(sa).is_not_null()
	assert_int(sa.size_flags_vertical).is_equal(Control.SIZE_EXPAND_FILL)
