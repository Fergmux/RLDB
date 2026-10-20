class_name SegmentedChoice
extends HBoxContainer
## A segmented choice (design review #60): two or more options joined into one bevelled F4 bar.
## The unchosen segments are dark iron with a bronze rim; the chosen one fills gold with a check
## mark, so the choice reads as one decision and not as several equal buttons. Each segment is a
## JuicyButton (hover, press, sound and focus come from the button family).
##
##     var seg := SegmentedChoice.new(["I go first", "My opponent goes first"], -1)
##     seg.chosen.connect(func(i): ...)

## Segment `index` was pressed.
signal chosen(index: int)

## Height and minimum width of one segment; the outer corner radius.
const SEGMENT_H := 46.0
const SEGMENT_MIN_W := 200.0
const RADIUS := 8
## Prefix of the chosen segment's label.
const CHECK := "✓  "

## The option labels and the chosen index (-1 = none yet).
var labels: Array = []
var selected: int = -1
## The segment buttons, in order.
var buttons: Array[Button] = []


func _init(p_labels: Array = [], p_selected: int = -1, font_size: int = 17) -> void:
	labels = p_labels
	selected = p_selected
	add_theme_constant_override("separation", 0)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for i in labels.size():
		var is_on := i == selected
		var b := UIStyle.button((CHECK if is_on else "") + String(labels[i]), font_size)
		UIStyle.style_button(b, "primary" if is_on else "secondary")
		_shape(b, i)
		b.custom_minimum_size = Vector2(SEGMENT_MIN_W, SEGMENT_H)
		b.set_meta(&"segment", i)
		var k := i
		b.pressed.connect(func(): chosen.emit(k))
		add_child(b)
		buttons.append(b)


## Rounds only the outer corners of segment `i` and joins the inner edges into one bar.
func _shape(b: Button, i: int) -> void:
	var first := i == 0
	var last := i == labels.size() - 1
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		if not b.has_theme_stylebox_override(st):
			continue
		var sb := UiSurface.restyled(b.get_theme_stylebox(st), func(f: StyleBoxFlat) -> void:
			f.corner_radius_top_left = RADIUS if first else 0
			f.corner_radius_bottom_left = RADIUS if first else 0
			f.corner_radius_top_right = RADIUS if last else 0
			f.corner_radius_bottom_right = RADIUS if last else 0
			if not first:
				f.border_width_left = 0)
		b.add_theme_stylebox_override(st, sb)


## Disables or enables every segment.
func set_disabled(on: bool) -> void:
	for b in buttons:
		b.disabled = on
