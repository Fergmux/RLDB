extends GdUnitTestSuite
## H11 (owner feedback 21 Oct 2026): the right details panel's ATK / DEF tiles are short (one row:
## caption over "Base: N", the value beside it), so more of the card fits in the panel.

## The tallest a match stat tile may be (px): the old two-row tile was about 80.
const MAX_TILE_H := 52.0


func _view() -> Dictionary:
	return {"uid": 3, "id": 1, "name": "Basic Mage", "category": "unit", "race": "Mage", "type": "Water",
		"cost_kind": "ap", "cost": 1, "printed_cost": 1, "atk": 10, "def": 8, "printed_atk": 8, "printed_def": 8,
		"text": "", "text_parts": [], "zone": "unit", "stance": "atk", "statuses": {}}


func _tiles(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is PanelContainer and (ch as PanelContainer).get_theme_stylebox("panel") is DepthBox and (ch as PanelContainer).size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			out.append(ch)
		else:
			_tiles(ch, out)


func test_match_stat_tiles_are_one_short_row() -> void:
	# Arrange
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.size = Vector2(320, 600)
	add_child(p)
	# Act
	p.show_card(_view())
	var tiles := []
	_tiles(p, tiles)
	# Assert: two tiles, each short, still showing the base value and the changed one
	assert_int(tiles.size()).is_equal(2)
	for t in tiles:
		assert_float((t as Control).get_combined_minimum_size().y).is_less_equal(MAX_TILE_H)
	assert_int(p.count_text("Base: 8")).is_equal(2)
	assert_int(p.count_text("10")).is_greater_equal(1)


func test_construction_tiles_keep_their_large_value() -> void:
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.construction = true
	p.show_card(_view())
	assert_int(p.count_text("Base: 8")).is_equal(0)
