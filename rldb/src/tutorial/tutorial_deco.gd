class_name TutorialDeco
extends Control
## Small drawn ornaments of the tutorial UI (F04): a flourish divider (rule - diamond - rule), a
## diamond bullet and a segmented step-progress bar. Presentation only; the progress fill eases
## to its value unless UIStyle.reduce_motion is set.

enum Kind { DIVIDER, BULLET, STEPS }

var kind: Kind = Kind.DIVIDER
var color: Color = UIStyle.GOLD
## STEPS: number of segments and the current one (segments before it are done).
var count: int = 1
## STEPS: mark the current segment (off for a summary bar of completed steps).
var highlight: bool = true
var current: int = 0
## STEPS: seconds a segment takes to fill when `current` moves (0 = the default quick ease). A
## segment filling this way glows as it fills (review #102: "fills with light").
var fill_time: float = 0.0
var _shown: float = 0.0
var _glow: float = 0.0


## Divider with a centred diamond, `height` px tall.
static func divider(col: Color = UIStyle.GOLD, height: float = 12.0) -> TutorialDeco:
	var d := TutorialDeco.new()
	d.kind = Kind.DIVIDER
	d.color = col
	d.custom_minimum_size = Vector2(0, height)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Diamond bullet for list lines.
static func bullet(col: Color = UIStyle.GOLD) -> TutorialDeco:
	var d := TutorialDeco.new()
	d.kind = Kind.BULLET
	d.color = col
	d.custom_minimum_size = Vector2(14, 14)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Segmented progress bar of `n` steps with step `cur` (0-based) in progress.
static func steps(n: int, cur: int, col: Color = UIStyle.GOLD) -> TutorialDeco:
	var d := TutorialDeco.new()
	d.kind = Kind.STEPS
	d.color = col
	d.count = n
	d.current = cur
	d._shown = float(cur)
	d.custom_minimum_size = Vector2(0, 5)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Moves a STEPS bar to `cur` (eased).
func set_current(n: int, cur: int) -> void:
	count = n
	current = cur
	if UIStyle.reduce_motion:
		_shown = float(cur)
	queue_redraw()


func _process(delta: float) -> void:
	if kind != Kind.STEPS:
		return
	if not is_equal_approx(_shown, float(current)):
		var rate := 1.0 / maxf(0.01, UIStyle.dur(fill_time)) if fill_time > 0.0 else 6.0
		_shown = move_toward(_shown, float(current), delta * rate)
		if fill_time > 0.0:
			_glow = 1.0
		queue_redraw()
	elif _glow > 0.0:
		_glow = maxf(0.0, _glow - delta * 2.0)
		queue_redraw()


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


func _draw() -> void:
	match kind:
		Kind.DIVIDER:
			var c := Vector2(size.x / 2.0, size.y / 2.0)
			var gap := 14.0
			# Rules fade out toward the edges: drawn as short segments of falling alpha.
			var segs := 14
			var len_l := maxf(c.x - gap, 0.0)
			for i in segs:
				var a0 := float(i) / segs
				var a1 := float(i + 1) / segs
				var col := Color(color, 0.15 + 0.6 * a1)
				draw_line(Vector2(lerpf(0.0, len_l, a0), c.y), Vector2(lerpf(0.0, len_l, a1), c.y), col, 1.5)
				draw_line(Vector2(size.x - lerpf(0.0, len_l, a0), c.y), Vector2(size.x - lerpf(0.0, len_l, a1), c.y), col, 1.5)
			_diamond(c, 5.0, color)
			_diamond(c, 2.5, UIStyle.ON_GOLD)
			_diamond(c + Vector2(-gap + 3.0, 0), 2.0, Color(color, 0.7))
			_diamond(c + Vector2(gap - 3.0, 0), 2.0, Color(color, 0.7))
		Kind.BULLET:
			var c2 := size / 2.0 + Vector2(0, 1)
			_diamond(c2, 5.0, Color(color, 0.35))
			_diamond(c2, 3.5, color)
		Kind.STEPS:
			var n := maxi(count, 1)
			var gap2 := 3.0
			var w := (size.x - gap2 * (n - 1)) / n
			for i in n:
				var r := Rect2(i * (w + gap2), 0, w, size.y)
				draw_rect(r, Color(1, 1, 1, 0.08))
				var fill := clampf(_shown - i + 0.0, 0.0, 1.0)
				if fill > 0.0:
					draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), Color(color, 0.85))
					# The segment being filled: a bright leading edge and a soft glow around it.
					if _glow > 0.0 and fill < 1.0 or (_glow > 0.0 and i == int(ceilf(_shown)) - 1):
						var lead := r.position.x + r.size.x * fill
						draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), Color(UIStyle.GOLD_HI, 0.5 * _glow))
						draw_rect(r.grow(2.0), Color(UIStyle.GOLD_HI, 0.25 * _glow), false, 2.0)
						draw_rect(Rect2(lead - 2.0, r.position.y - 2.0, 3.0, r.size.y + 4.0), Color(1, 0.97, 0.85, 0.9 * _glow))
				if highlight and i == current:
					draw_rect(r, Color(UIStyle.GOLD_HI, 0.9))
					draw_rect(r.grow(1.0), Color(UIStyle.GOLD_HI, 0.25), false, 1.0)
