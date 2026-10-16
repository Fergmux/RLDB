class_name TutorialMenu
extends RefCounted
## Lesson list of the main menu's Play local > Tutorial panel (F03-15).


## Adds one start button per lesson (with its summary) to `box`; `on_pick(index)` starts it.
static func add_lessons(box: VBoxContainer, on_pick: Callable) -> void:
	var ls := TutorialLessons.all()
	for i in ls.size():
		var l: Dictionary = ls[i]
		var b := UIStyle.primary_button(String(l["title"]), 17) if i == 0 else UIStyle.button(String(l["title"]), 16)
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = String(l["summary"])
		b.pressed.connect(on_pick.bind(i))
		box.add_child(b)
	box.add_child(UIStyle.label("Lessons run in order; each one ends with a summary and the next lesson.", 13, UIStyle.TEXT_DIM, true))
