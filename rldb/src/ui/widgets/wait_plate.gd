class_name WaitPlate
extends OrnatePanel
## Designed "waiting" state: a turning rune ring, a title, a line of explanation and one status
## chip per seat (done chips are green and ticked, pending ones breathe). Used for "deck locked in,
## waiting for the opponent" and "rewards done, waiting for the opponent".


## Turning ring of ticks around a diamond; static under reduced motion.
class Rune extends Control:
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not UIStyle.reduce_motion:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		draw_circle(c, r + 2.0, Color(0.05, 0.04, 0.03, 0.9))
		draw_arc(c, r, 0.0, TAU, 48, Color(UIStyle.BRONZE, 0.9), 2.0, true)
		for i in 12:
			var a := TAU * float(i) / 12.0 + _t * 0.9
			var bright := fposmod(float(i) / 12.0 - _t * 0.15, 1.0)
			var col := Color(UIStyle.GOLD_HI, 0.25 + 0.75 * bright)
			draw_line(c + Vector2(cos(a), sin(a)) * (r - 11.0), c + Vector2(cos(a), sin(a)) * (r - 3.0), col, 3.0, true)
		Ornate.diamond(self, c, 10.0, Color(UIStyle.GOLD, 0.9))
		Ornate.diamond(self, c, 5.0, Color(0.1, 0.08, 0.05, 0.95))


## `chips`: Array of {text, done}; `show_rune` false hides the ring (a finished wait).
func _init(title: String = "", sub: String = "", chips: Array = [], show_rune: bool = true) -> void:
	super(12, 18)
	arm = 16.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	if show_rune:
		var rune := Rune.new()
		rune.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(rune)
	var t := UIStyle.label(title, 24, UIStyle.GOLD, true, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.6), true, 12.0))
	if sub != "":
		var s := UIStyle.label(sub, 16, UIStyle.MUTED, true)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for c in chips:
		row.add_child(_status_chip(String(c["text"]), bool(c.get("done", false))))


func _status_chip(text: String, done: bool) -> Control:
	var col: Color = UIStyle.GOOD if done else UIStyle.MUTED
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.flat(Color(col.darkened(0.8), 0.95), Color(col, 0.8), 1, 14))
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 12
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 14
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 4
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 4
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var dot := StatusDot.new(done)
	h.add_child(dot)
	h.add_child(UIStyle.label(text, 15, col.lightened(0.3)))
	return p


## Tick (done) or breathing dot (pending).
class StatusDot extends Control:
	var done := false
	var _t := 0.0

	func _init(d: bool) -> void:
		done = d
		custom_minimum_size = Vector2(16, 16)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(not d)

	func _process(delta: float) -> void:
		if not UIStyle.reduce_motion:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		if done:
			draw_circle(c, 7.5, Color(UIStyle.GOOD.darkened(0.4), 1.0))
			draw_polyline(PackedVector2Array([c + Vector2(-3.6, 0.2), c + Vector2(-1, 2.8), c + Vector2(3.8, -2.8)]), Color(0.9, 1.0, 0.92), 2.0, true)
		else:
			var k := 0.5 + 0.5 * sin(_t * 3.0)
			draw_circle(c, 7.0, Color(UIStyle.MUTED, 0.15 + 0.2 * k))
			draw_circle(c, 3.0 + k, Color(UIStyle.MUTED, 0.9))
