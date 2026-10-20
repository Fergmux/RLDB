extends GdUnitTestSuite
## H1 WP-2 / D3 on the duel screens: the title tiers each site uses, the prompt title that steps down
## to stay within three lines (review #33), the card-details name that shrinks, then splits at its
## comma (review #44), and the coin flip's result drawn as a T1 title above its veil (review #72).

const LONG_PROMPT := "Choose a stance for Bastion Wyrm, the Eternal Guardian of the Obsidian Citadel."


func _overlay(l: Label) -> TitleText:
	return l.get_meta(&"title_text") if l.has_meta(&"title_text") else null


func test_long_prompt_title_steps_down_to_three_lines() -> void:
	var px := GamePromptBanner.headline_px(LONG_PROMPT, 170.0, GamePromptBanner.HEADLINE_PX)
	assert_int(px).is_less(GamePromptBanner.HEADLINE_PX)
	assert_int(px).is_greater_equal(GamePromptBanner.HEADLINE_MIN_PX)
	if px > GamePromptBanner.HEADLINE_MIN_PX:
		assert_int(GamePromptBanner.headline_lines(LONG_PROMPT, 170.0, px)).is_less_equal(GamePromptBanner.HEADLINE_MAX_LINES)


func test_short_prompt_title_keeps_its_size() -> void:
	assert_int(GamePromptBanner.headline_px("Choose a zone.", 200.0, 21)).is_equal(21)


func test_card_name_shrinks_before_it_wraps() -> void:
	var font := TitleText.tier_font(TitleText.Tier.SCREEN)
	var name := "Grandmother Kaya"
	var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 1.0   # fits at 18, not at 20
	var plan := CardDetailsPanel.name_fit(name, w, 20, 16)
	assert_int(int(plan["size"])).is_equal(18)
	assert_str(String(plan["text"])).is_equal(name)
	assert_bool(bool(plan["wrap"])).is_false()


func test_long_card_name_splits_after_its_comma() -> void:
	var plan := CardDetailsPanel.name_fit("Boom, Councillor of the Order", 240.0, 20, 16)
	assert_str(String(plan["text"])).is_equal("Boom,\nCouncillor of the Order")
	assert_int(int(plan["size"])).is_equal(16)


func test_name_without_comma_wraps_at_the_floor_size() -> void:
	var plan := CardDetailsPanel.name_fit("Bastion Wyrm the Eternal Guardian of the Obsidian Citadel", 200.0, 20, 16)
	assert_bool(bool(plan["wrap"])).is_true()
	assert_int(int(plan["size"])).is_equal(16)


func test_sidebar_header_is_a_section_title() -> void:
	var h: Control = auto_free(GameUi.header("Game log"))
	var t := _overlay(h.get_child(0) as Label)
	assert_object(t).is_not_null()
	assert_int(t.tier).is_equal(TitleText.Tier.SECTION)


func test_house_headline_tier_follows_its_size() -> void:
	var p: HousePanel = auto_free(HousePanel.new("x"))
	assert_int(_overlay(p.add_headline("Concede this game?", 26)).tier).is_equal(TitleText.Tier.SCREEN)
	assert_int(_overlay(p.add_headline("Interface settings", 19)).tier).is_equal(TitleText.Tier.SECTION)
	assert_int(_overlay(p.add_headline("Pick", 19, false, 8.0, true, TitleText.Tier.SCREEN)).tier).is_equal(TitleText.Tier.SCREEN)


func test_coin_flip_result_is_a_hero_title_child_above_the_veil() -> void:
	var c: CoinFlip = auto_free(CoinFlip.new())
	c.size = Vector2(800, 600)
	add_child(c)
	c.play("Ben", "Ana", false, 1)
	assert_object(c.result_title).is_not_null()
	assert_int(c.result_title.tier).is_equal(TitleText.Tier.HERO)
	assert_str(c.result_title.text).is_equal("Ben goes first")
	assert_object(c.result_title.get_parent()).is_same(c)   # a child draws over the parent's veil
	assert_float(c.result_title.position.y).is_greater(300.0)   # under the coin
