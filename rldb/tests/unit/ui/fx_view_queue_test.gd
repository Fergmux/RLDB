extends GdUnitTestSuite
## L4 (owner feedback 2026-11-05): the queue of views waiting for earlier effects to play out
## (FxViewQueue): first in first out, the catch-up speed rule, the overflow guard and clearing.


func _v(seq: int) -> Dictionary:
	return {"seq": seq}


func test_views_come_out_in_arrival_order() -> void:
	# Arrange
	var q := FxViewQueue.new()
	# Act
	for i in 4:
		q.push(_v(i))
	var out := []
	while not q.is_empty():
		out.append(int(q.pop()["seq"]))
	# Assert
	assert_array(out).is_equal([0, 1, 2, 3])


func test_nothing_is_dropped_up_to_the_waiting_limit() -> void:
	var q := FxViewQueue.new()
	for i in FxViewQueue.MAX_WAITING:
		q.push(_v(i))
	assert_array(q.take_overflow()).is_empty()
	assert_int(q.size()).is_equal(FxViewQueue.MAX_WAITING)


func test_overflow_hands_back_the_oldest_views_in_order() -> void:
	var q := FxViewQueue.new()
	for i in FxViewQueue.MAX_WAITING + 2:
		q.push(_v(i))
	var over := q.take_overflow()
	assert_array(over.map(func(v): return int(v["seq"]))).is_equal([0, 1])
	assert_int(q.size()).is_equal(FxViewQueue.MAX_WAITING)
	assert_int(int(q.pop()["seq"])).is_equal(2)


func test_playback_speeds_up_gently_with_the_backlog() -> void:
	assert_float(FxViewQueue.speed_for(0)).is_equal(1.0)
	assert_float(FxViewQueue.speed_for(1)).is_equal(1.25)
	assert_float(FxViewQueue.speed_for(2)).is_equal(1.5)
	assert_float(FxViewQueue.speed_for(4)).is_equal(FxViewQueue.MAX_SPEED)
	assert_float(FxViewQueue.speed_for(40)).is_equal(FxViewQueue.MAX_SPEED)
	assert_float(FxViewQueue.speed_for(-1)).is_equal(1.0)


func test_clear_drops_everything_and_pop_on_empty_is_safe() -> void:
	var q := FxViewQueue.new()
	q.push(_v(1))
	q.push(_v(2))
	q.clear()
	assert_bool(q.is_empty()).is_true()
	assert_dict(q.pop()).is_empty()
