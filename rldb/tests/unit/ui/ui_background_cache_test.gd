extends GdUnitTestSuite
## G10 hardening: screen backgrounds are loaded once and reused, so returning to the menu after a
## duel never depends on reloading the image.


func test_background_texture_is_loaded_once_and_reused() -> void:
	var a := UIStyle.background_texture(UIStyle.MENU_BACKGROUND)
	var b := UIStyle.background_texture(UIStyle.MENU_BACKGROUND)
	assert_object(a).is_not_null()
	assert_bool(a == b).is_true()


func test_every_menu_background_uses_the_cached_texture() -> void:
	var first: Control = auto_free(UIStyle.background(0.05, UIStyle.MENU_BACKGROUND))
	var second: Control = auto_free(UIStyle.background(0.05, UIStyle.MENU_BACKGROUND))
	var t1 := (first.get_child(0) as TextureRect).texture
	var t2 := (second.get_child(0) as TextureRect).texture
	assert_object(t1).is_not_null()
	assert_bool(t1 == t2).is_true()
	assert_bool(t1 == UIStyle.background_texture(UIStyle.MENU_BACKGROUND)).is_true()
