extends GdUnitTestSuite
## H1 WP-7 duel side (design/design-review-2026-10-20.md #42, #43, #45): the Card Details empty state,
## the art crop and the stat tiles.


func _unit_view() -> Dictionary:
	return {"uid": 3, "id": 1, "name": "Basic Mage", "category": "basic_unit", "cost_kind": "ap", "cost": 1, "printed_cost": 1,
		"zone": "unit", "slot": 0, "face_up": true, "statuses": {}, "runes": 0, "text": "", "support": "full",
		"race": "Mage", "type": "Water", "printed_atk": 8, "printed_def": 8, "atk": 8, "def": 8, "stance": "atk",
		"stat_parts": ["Base 8/8"]}


func test_empty_art_outline_fits_a_short_panel() -> void:
	# #42: the outline keeps its 140 x 196 size when there is room and shrinks (never overflows) when not.
	var big := DetailsEmptyArt.card_rect(Vector2(330, 500))
	assert_vector(big.size).is_equal(DetailsEmptyArt.CARD)
	var small := DetailsEmptyArt.card_rect(Vector2(330, 200))
	assert_float(small.size.y).is_less(DetailsEmptyArt.CARD.y)
	assert_float(small.position.y + small.size.y).is_less_equal(200.0)


func test_art_crop_is_shown_only_when_asked() -> void:
	# #43: the match sidebar opens with the art; the other panels (catalogue, deck builder) do not.
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.show_card(_unit_view())
	assert_bool(p.sections.has("art")).is_false()
	p.art_crop = true
	p.show_card(_unit_view())
	assert_str(p.sections[0]).is_equal("art")


func test_art_crop_region_keeps_the_upper_middle() -> void:
	var rg := CardDetailsPanel.ArtCrop.region(Vector2(512, 512), Vector2(330, 120))
	assert_float(rg.size.x).is_equal(512.0)
	assert_float(rg.size.y).is_equal_approx(512.0 * 120.0 / 330.0, 0.01)
	assert_float(rg.position.y).is_greater_equal(0.0)
	assert_float(rg.end.y).is_less_equal(512.0)


func test_art_crop_height_follows_the_scroll() -> void:
	assert_float(GameDetails.art_crop_height(1000.0)).is_equal(GameDetails.ART_MAX_H)
	assert_float(GameDetails.art_crop_height(100.0)).is_equal(GameDetails.ART_MIN_H)
	assert_float(GameDetails.art_crop_height(400.0)).is_equal(120.0)


func test_stat_tiles_edge_echoes_the_card_badges() -> void:
	# #45: ATK red, DEF blue, at 40%, and the base value stays readable under the number.
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.show_card(_unit_view())
	var tiles := []
	_find_tiles(p, tiles)
	assert_int(tiles.size()).is_equal(2)
	var atk := (tiles[0] as PanelContainer).get_theme_stylebox("panel") as DepthBox
	var def := (tiles[1] as PanelContainer).get_theme_stylebox("panel") as DepthBox
	assert_float(atk.base.border_color.r).is_greater(atk.base.border_color.b)
	assert_float(def.base.border_color.b).is_greater(def.base.border_color.r)
	assert_float(atk.base.border_color.a).is_equal_approx(CardDetailsPanel.STAT_EDGE_A, 0.001)
	assert_int(p.count_text("Base: 8")).is_equal(2)


func _find_tiles(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is PanelContainer and (ch as PanelContainer).get_theme_stylebox("panel") is DepthBox and (ch as PanelContainer).size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			out.append(ch)
		else:
			_find_tiles(ch, out)
