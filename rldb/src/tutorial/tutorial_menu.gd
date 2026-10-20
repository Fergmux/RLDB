class_name TutorialMenu
extends RefCounted
## Lesson list of the main menu's Play > Tutorial panel (F03-15, design review #97): one 52 px
## row per lesson with a numbered bronze medallion, the lesson's name and a one-line subtitle,
## and its state at the right (a gold tick once finished, a "Next" chip on the recommended
## lesson). Every row is the same secondary button, so none reads as "selected". A 12 px MUTED
## footer explains the order.

## Row height and the medallion size (px at 1600x900).
const ROW_H := 52.0
const MEDAL := 28.0
## Title and subtitle sizes.
const TITLE_PX := 15
const SUB_PX := 12
const FOOT_PX := 12
## Gap between rows.
const ROW_GAP := 8
const FOOTER := "Lessons run in order; each one ends with a summary and the next lesson. Replay any of them at any time."


## Adds one row per lesson (with its summary as the tooltip) to `box`; `on_pick(index)` starts it.
static func add_lessons(box: VBoxContainer, on_pick: Callable) -> void:
	var ls := TutorialLessons.all()
	var next := TutorialProgress.recommended(ls)
	var list := VBoxContainer.new()
	list.name = "Lessons"
	list.add_theme_constant_override("separation", ROW_GAP)
	box.add_child(list)
	for i in ls.size():
		var l: Dictionary = ls[i]
		var row := LessonRow.new(i, l, TutorialProgress.is_done(String(l.get("id", ""))), i == next)
		row.pressed.connect(on_pick.bind(i))
		list.add_child(row)
	var foot := UIStyle.label(FOOTER, FOOT_PX, UIStyle.MUTED, true)
	foot.name = "Footer"
	foot.add_theme_constant_override("line_spacing", 3)
	box.add_child(foot)


## The lesson's own name: "Lesson 2 · Summoning and stances" -> "Summoning and stances".
static func lesson_name(title: String) -> String:
	return title.get_slice("·", 1).strip_edges() if title.contains("·") else title


## The subtitle line of a lesson: its first "what you learned" line, as plain text.
static func subtitle(lesson: Dictionary) -> String:
	var learned: Array = lesson.get("learned", [])
	if learned.is_empty():
		return TutorialMarkup.plain(String(lesson.get("summary", "")))
	return TutorialMarkup.plain(String(learned[0]))


## One lesson row: a secondary button holding the medallion, the name and subtitle, and the state.
class LessonRow extends JuicyButton:
	## Lesson index (0-based).
	var index: int = 0
	## Finished on this profile.
	var done: bool = false
	## The recommended lesson (the first not finished).
	var recommended: bool = false
	var title_label: Label
	var sub_label: Label
	var medal: Medal

	func _init(i: int, lesson: Dictionary, is_done: bool, is_next: bool) -> void:
		index = i
		done = is_done
		recommended = is_next
		name = "Lesson%d" % (i + 1)
		UIStyle.style_button(self, "secondary")
		custom_minimum_size = Vector2(0, ROW_H)
		focus_mode = Control.FOCUS_ALL   # keyboard and gamepad reach every lesson
		tooltip_text = TutorialMarkup.plain(String(lesson.get("summary", "")))
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_left", UIStyle.sp("md"))
		m.add_theme_constant_override("margin_right", UIStyle.sp("lg"))
		add_child(m)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", UIStyle.sp("md"))
		m.add_child(h)
		medal = Medal.new(i + 1, done)
		medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(medal)
		var tv := VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tv.add_theme_constant_override("separation", 0)
		h.add_child(tv)
		title_label = UIStyle.label(TutorialMenu.lesson_name(String(lesson.get("title", ""))), TITLE_PX, UIStyle.TEXT)
		title_label.name = "Title"
		title_label.add_theme_font_override("font", UIStyle.font_bold())
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(title_label)
		sub_label = UIStyle.label(TutorialMenu.subtitle(lesson), SUB_PX, UIStyle.MUTED)
		sub_label.name = "Subtitle"
		sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_label.clip_text = true
		sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(sub_label)
		if recommended:
			var chip := UIStyle.chip("Next", UIStyle.GOLD, 12)
			chip.name = "NextChip"
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(chip)
		if done:
			var tick := Tick.new()
			tick.name = "DoneTick"
			tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tick.tooltip_text = "Finished"
			h.add_child(tick)
		mouse_entered.connect(_light.bind(true))
		mouse_exited.connect(_light.bind(false))
		focus_entered.connect(_light.bind(true))
		focus_exited.connect(_light.bind(false))

	func _light(on: bool) -> void:
		title_label.add_theme_color_override("font_color", UIStyle.GOLD_HI if on else UIStyle.TEXT)
		medal.lit = on

	## Numbered bronze coin (gold once the lesson is finished), with an embossed number.
	class Medal extends Control:
		var number := 1
		var gold := false
		var lit := false:
			set(v):
				lit = v
				queue_redraw()

		func _init(n: int, is_gold: bool) -> void:
			number = n
			gold = is_gold
			custom_minimum_size = Vector2(MEDAL, MEDAL)
			mouse_filter = Control.MOUSE_FILTER_IGNORE

		func _draw() -> void:
			var c := size / 2.0
			var r := minf(size.x, size.y) / 2.0 - 1.0
			var base := UIStyle.GOLD if gold else UIStyle.BRONZE
			draw_circle(c + Vector2(0, 1.5), r, Color(0, 0, 0, 0.55), true, -1.0, true)   # drop
			draw_circle(c, r, base.darkened(0.35), true, -1.0, true)
			draw_circle(c + Vector2(0, -r * 0.18), r * 0.82, base.lerp(UIStyle.GOLD_HI, 0.25 if gold else 0.1), true, -1.0, true)
			draw_circle(c, r * 0.74, base.darkened(0.15), true, -1.0, true)
			draw_arc(c, r, 0.0, TAU, 32, Color(UIStyle.GOLD_HI if lit else base.lightened(0.25), 0.95), 1.5, true)
			draw_arc(c, r * 0.74, PI * 1.05, PI * 1.95, 12, Color(1, 0.95, 0.8, 0.35), 1.0, true)   # top bevel
			var f := UIStyle.font_display(700)
			var fs := 15
			var t := str(number)
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var y := c.y + TitleText.cap_height(UIStyle.font_display(700), fs) / 2.0
			var p := Vector2(c.x - tw.x / 2.0, y)
			draw_string(f, p + Vector2(0, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
			draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.ON_GOLD if gold else UIStyle.GOLD_HI)

	## Gold tick of a finished lesson.
	class Tick extends Control:
		func _init() -> void:
			custom_minimum_size = Vector2(22, 22)
			mouse_filter = Control.MOUSE_FILTER_PASS

		func _draw() -> void:
			var s := minf(size.x, size.y)
			var o := (size - Vector2(s, s)) / 2.0
			var pts := PackedVector2Array([o + Vector2(0.16, 0.54) * s, o + Vector2(0.42, 0.78) * s, o + Vector2(0.86, 0.24) * s])
			var sh := PackedVector2Array()
			for q in pts:
				sh.append(q + Vector2(0, 1.5))
			draw_polyline(sh, Color(0, 0, 0, 0.6), 4.0, true)
			draw_polyline(pts, UIStyle.GOLD_HI, 3.0, true)
