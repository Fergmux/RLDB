extends GdUnitTestSuite
## Release batch H1 check: a hover tween kept in a node's metadata must start cleanly the first time.
## `get_meta(key, null)` is a missing default in Godot 4, so every first hover of a list card, a
## draft offer or a reward card logged "The object does not have any 'meta' values". The three
## copies now share UIStyle.restart_tween().

const _VIEW := {"uid": 1, "id": 1, "name": "Test Spell", "category": "spell", "cost_kind": "ap", "cost": 1,
	"printed_cost": 1, "zone": "hand", "face_up": true, "statuses": {}, "runes": 0, "text": "Do a thing."}

var _rm := false


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	UIStyle.reduce_motion = false


func after_test() -> void:
	UIStyle.reduce_motion = _rm


func _widget() -> CardWidget:
	var w: CardWidget = auto_free(CardWidget.new())
	w.auto_hover = false
	w.setup(_VIEW, "hand")
	add_child(w)
	return w


func test_first_ease_hover_logs_no_error() -> void:
	var w := _widget()
	await assert_error(func(): w.ease_hover(true)).is_success()


func test_restart_tween_first_call_logs_no_error() -> void:
	var n: Node = auto_free(Node.new())
	add_child(n)
	await assert_error(func(): UIStyle.restart_tween(n, "t_key")).is_success()


func test_restart_tween_kills_the_previous_tween() -> void:
	var n: Node = auto_free(Node.new())
	add_child(n)
	var a := UIStyle.restart_tween(n, "t_key")
	a.tween_interval(1.0)
	var b := UIStyle.restart_tween(n, "t_key")
	b.tween_interval(1.0)
	assert_bool(a.is_valid()).is_false()
	assert_bool(b.is_valid()).is_true()
	assert_object(n.get_meta("t_key")).is_same(b)
