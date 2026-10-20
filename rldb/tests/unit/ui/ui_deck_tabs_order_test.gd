extends GdUnitTestSuite
## H1 (owner feedback 21 Oct 2026): in the pre-game deck selector the Custom decks tab comes first
## and the Structure decks tab second; a fresh deck stage opens on Custom when the player has a saved
## deck, else on Structure.

const View := preload("res://src/ui/game/deck_select_view.gd")


func test_deck_tabs_custom_tab_comes_first() -> void:
	# Arrange
	var v: DeckSelectView = View.new(null)
	v.tab = "custom"
	# Act
	var ft: FolderTabs = auto_free(v.deck_tabs(true, 12, 3))
	# Assert
	assert_int(ft.tab("custom").get_index()).is_less(ft.tab("structured").get_index())


func test_deck_tabs_draft_has_only_structure() -> void:
	var v: DeckSelectView = View.new(null)
	v.tab = "structured"
	var ft: FolderTabs = auto_free(v.deck_tabs(false, 12, 0))
	assert_object(ft.tab("custom")).is_null()
	assert_object(ft.tab("structured")).is_not_null()


func test_default_tab_with_saved_decks_is_custom() -> void:
	assert_str(DeckSelectView.default_tab(true, 1)).is_equal("custom")


func test_default_tab_without_saved_decks_is_structure() -> void:
	assert_str(DeckSelectView.default_tab(true, 0)).is_equal("structured")


func test_default_tab_in_a_draft_is_structure() -> void:
	assert_str(DeckSelectView.default_tab(false, 4)).is_equal("structured")


func test_new_view_has_no_tab_until_it_renders() -> void:
	var v: DeckSelectView = View.new(null)
	assert_str(v.tab).is_empty()
