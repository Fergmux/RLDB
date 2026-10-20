extends GdUnitTestSuite
## Owner feedback 22 Oct, J27: on the draft screen an open category tab keeps its colour and the
## whole pane takes it (FolderTabs.tint_pane); other tab strips keep the plain pane fill.
## Story: design/owner-feedback-2026-10-22.md J27.

const GREEN := Color("2e9e48")
const RED := Color("c8352e")


func _tabs(tint: bool) -> FolderTabs:
	var ft: FolderTabs = auto_free(FolderTabs.new())
	ft.tint_pane = tint
	ft.add_tab("spell", "Spell", {"accent": GREEN})
	ft.add_tab("trap", "Trap", {"accent": RED})
	ft.add_tab("plain", "Plain")
	return ft


func test_j27_tinted_pane_takes_the_open_tabs_colour() -> void:
	var ft := _tabs(true)
	ft.select("spell", false)
	var spell := ft.target_fill()
	assert_bool(spell.is_equal_approx(ft.pane_fill)).is_false()
	assert_float(spell.g).is_greater(spell.r)          # green leads
	ft.select("trap", false)
	var trap := ft.target_fill()
	assert_float(trap.r).is_greater(trap.g)            # red leads
	assert_bool(trap.is_equal_approx(spell)).is_false()


func test_j27_open_tab_keeps_its_closed_face_colour() -> void:
	var ft := _tabs(true)
	ft.select("spell", false)
	var closed_face := ft.tab("spell").face_color()     # its face while closed and not hovered
	var open_fill := ft.target_fill()
	for ch in ["r", "g", "b"]:
		assert_float(absf(open_fill[ch] - closed_face[ch])).is_less(0.02)


func test_j27_a_tab_without_accent_keeps_the_plain_pane() -> void:
	var ft := _tabs(true)
	ft.select("plain", false)
	assert_bool(ft.target_fill().is_equal_approx(ft.pane_fill)).is_true()


func test_j27_untinted_strips_keep_the_plain_pane() -> void:
	var ft := _tabs(false)
	ft.select("trap", false)
	assert_bool(ft.target_fill().is_equal_approx(ft.pane_fill)).is_true()


func test_j27_rebuilt_strip_starts_from_the_previous_colour() -> void:
	var ft := _tabs(true)
	var from := Color(0.2, 0.1, 0.1, 0.97)
	ft.tint_from = from
	ft.select("spell", false)
	var was := UIStyle.reduce_motion
	UIStyle.reduce_motion = false
	add_child(ft)
	assert_bool(ft.shown_fill().is_equal_approx(from)).is_true()
	await get_tree().create_timer(FolderTabs.TINT_FADE + 0.15).timeout
	assert_bool(ft.shown_fill().is_equal_approx(ft.target_fill())).is_true()
	UIStyle.reduce_motion = was
