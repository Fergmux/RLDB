extends GdUnitTestSuite
## L9 (owner feedback 2026-11-05): Hypnotise's control events glide the unit to its new zone with a
## violet swirl (FxControlMove) and play their own sound once; a unit sent to Spent on its return
## swirls in its old zone and flies to the pile.

func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _tags(plan: Array, prefix: String) -> Array:
	return plan.filter(func(s): return String(s["tag"]).begins_with(prefix))


func test_taking_control_glides_the_unit_with_one_steal_sound() -> void:
	# Arrange
	var gs := _screen()
	await await_idle_frame()
	var ev := [{"k": "control", "from": {"p": 1, "zone": "unit", "slot": 2}, "to": {"p": 0, "zone": "unit", "slot": 5},
		"p": 0, "id": 13, "back": false}]
	# Act
	gs.fx.play(ev, {})
	# Assert
	var plan: Array = gs.fx.last_plan
	assert_int(_tags(plan, "control").size()).is_equal(1)
	assert_int(_tags(plan, "sfx:control_steal").size()).is_equal(1)
	assert_array(_tags(plan, "sfx:destroy")).is_empty()
	gs.fx.finish_all()


func test_a_return_to_spent_swirls_and_flies_to_the_pile_without_a_destroy_sound() -> void:
	var gs := _screen()
	await await_idle_frame()
	var ev := [{"k": "control", "from": {"p": 0, "zone": "unit", "slot": 5}, "to": {}, "p": 1, "id": 13, "back": true, "dest": "spent"}]
	gs.fx.play(ev, {})
	var plan: Array = gs.fx.last_plan
	assert_int(_tags(plan, "control_swirl").size()).is_equal(1)
	assert_int(_tags(plan, "control_spent").size()).is_equal(1)
	assert_int(_tags(plan, "sfx:control_return").size()).is_equal(1)
	assert_array(_tags(plan, "sfx:destroy")).is_empty()
	gs.fx.finish_all()


func test_the_glide_path_starts_at_the_old_zone_and_ends_at_the_new_one() -> void:
	var d := Vector2(-300, 180)
	var c := d * 0.5 + Vector2(0, -90)
	assert_vector(FxControlMove._bezier(d, c, Vector2.ZERO, 0.0)).is_equal(d)
	assert_vector(FxControlMove._bezier(d, c, Vector2.ZERO, 1.0)).is_equal(Vector2.ZERO)
	# Mid-way the card is lifted above the straight line (an arc, not a slide).
	assert_float(FxControlMove._bezier(d, c, Vector2.ZERO, 0.5).y).is_less((d * 0.5).y)
