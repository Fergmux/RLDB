extends GdUnitTestSuite
## H6 (owner feedback 21 Oct 2026): a pile row, before it expands, shows the card's kind (units:
## Unit / Fusion / Ritual / Arcane), its cost (a Fusion's material cost) and, for units, race and type.


func test_row_kind_names_units_by_how_they_are_summoned() -> void:
	assert_str(GameDetails.row_kind({"category": "unit"})).is_equal("Unit")
	assert_str(GameDetails.row_kind({"category": "basic_unit"})).is_equal("Unit")
	assert_str(GameDetails.row_kind({"category": "fusion"})).is_equal("Fusion")
	assert_str(GameDetails.row_kind({"category": "ritual"})).is_equal("Ritual")
	assert_str(GameDetails.row_kind({"category": "arcane"})).is_equal("Arcane")
	assert_str(GameDetails.row_kind({"category": "trap"})).is_equal("Trap")


func test_row_cost_of_a_fusion_is_its_materials() -> void:
	# Arrange
	var c := MatchView.def_view(93)   # Bastion Wyrm (2026-11-03 materials)
	# Act
	var cost := GameDetails.row_cost(c)
	# Assert
	assert_str(String(cost["kind"])).is_equal("fusion")
	assert_str(String(cost["text"])).is_equal("Unit with 20 or more ATK or DEF + Physical Unit")


func test_row_cost_of_ap_ritual_and_arcane_cards() -> void:
	assert_str(String(GameDetails.row_cost(MatchView.def_view(1))["text"])).ends_with("AP")
	assert_str(String(GameDetails.row_cost(MatchView.def_view(62))["text"])).is_equal("2 Rune")
	assert_str(String(GameDetails.row_cost(MatchView.def_view(170))["text"])).is_equal("2 Arcane")   # Kaya 2A since 2026-11-03
