extends GdUnitTestSuite
## FxPlayer.add_cleanup_on: a skip cleanup holds its target weakly, so a target freed before the
## effects are skipped is passed over silently (a lambda capturing the freed object made Godot log
## "Lambda capture at index 0 was freed" from finish_all()).


func _run_cleanups(player: FxPlayer) -> void:
	for c in player._cleanups:
		(c as Callable).call()


func test_cleanup_on_a_live_target_runs_with_it() -> void:
	var player: FxPlayer = auto_free(FxPlayer.new())
	var node: Control = auto_free(Control.new())
	player.add_cleanup_on(node, func(n: Control) -> void: n.position = Vector2(7, 3))
	_run_cleanups(player)
	assert_vector(node.position).is_equal(Vector2(7, 3))


func test_cleanup_on_a_freed_target_is_skipped() -> void:
	var player: FxPlayer = auto_free(FxPlayer.new())
	var node := Control.new()
	var calls := [0]
	player.add_cleanup_on(node, func(_n: Control) -> void: calls[0] += 1)
	node.free()
	_run_cleanups(player)
	assert_int(calls[0]).is_equal(0)


func test_cleanup_does_not_keep_its_target_alive() -> void:
	var player: FxPlayer = auto_free(FxPlayer.new())
	var obj := RefCounted.new()
	var ref: WeakRef = weakref(obj)
	player.add_cleanup_on(obj, func(_o: Object) -> void: pass)
	obj = null
	assert_object(ref.get_ref()).is_null()
