extends GdUnitTestSuite
## F05-04: the window renders at most 30 FPS while in the background; focus restores the cap.

const MainScript := preload("res://src/ui/main.gd")


func test_focus_out_caps_at_30_and_focus_in_restores() -> void:
	var before := Engine.max_fps
	var m: Control = auto_free(MainScript.new())
	Engine.max_fps = 0
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(Engine.max_fps).is_equal(MainScript.BACKGROUND_FPS)
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)   # repeated focus-out keeps the saved cap
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_int(Engine.max_fps).is_equal(0)
	Engine.max_fps = before
