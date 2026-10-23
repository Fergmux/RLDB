extends GdUnitTestSuite
## Owner feedback 23 Oct, K3: the coin flip's dark backdrop fills the whole window. The CoinFlip
## control covers the window; `focus_rect` (the play field) is where the coin and its title sit.
## Story: design/owner-feedback-2026-10-23.md K3.


func _coin(sz: Vector2) -> CoinFlip:
	var c: CoinFlip = auto_free(CoinFlip.new())
	add_child(c)
	c.size = sz
	return c


func test_k3_coin_centres_on_the_focus_rect_not_the_window() -> void:
	var c := _coin(Vector2(1600, 1000))
	var field := Rect2(0, 44, 1240, 766)
	c.focus_rect = field
	assert_bool(c.coin_area().is_equal_approx(field)).is_true()
	assert_bool(c.get_rect().is_equal_approx(Rect2(0, 0, 1600, 1000))).is_true()


func test_k3_without_a_focus_rect_the_coin_uses_the_whole_control() -> void:
	var c := _coin(Vector2(800, 600))
	assert_bool(c.coin_area().is_equal_approx(Rect2(0, 0, 800, 600))).is_true()


func test_k3_result_title_sits_under_the_coin_on_the_field() -> void:
	var c := _coin(Vector2(1600, 1000))
	c.focus_rect = Rect2(0, 44, 1240, 766)
	c.play("Ana", "Ben", true, 0)
	var t := c.result_title
	assert_float(t.position.x + t.size.x / 2.0).is_equal_approx(620.0, 1.0)
	assert_float(t.position.y).is_equal_approx(44.0 + 383.0 + CoinFlip.R + CoinFlip.RESULT_GAP, 1.0)
