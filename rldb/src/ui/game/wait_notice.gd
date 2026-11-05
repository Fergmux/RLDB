class_name WaitNotice
extends Control
## "Ana is responding..." (L16, owner feedback 2026-11-05: much more obvious). A gilded cartouche with
## an hourglass medallion that appears in the MIDDLE of the board (on the centre line between the two
## front rows) with a scale-and-fade pop, a soft breathing gold glow, the turning hourglass and running
## dots (WaitingDots), and the opponent_responding cue. So it never hides the board for long, it
## settles after SETTLE_AFTER: it glides, smaller, to its dock under the opponent's plate (where it
## used to live, #38) and keeps waiting there. While the pointer is over it, it fades nearly away
## (it never takes a click). It leaves with a short fade and shrink.
##
## It appears only after APPEAR_DELAY, so a fast reply never flashes it. `anchors` (set by the owner)
## gives its centre and dock points every frame, so it follows any layout change; `wanted` (optional)
## is asked every frame and a false answer clears it, so it can never outlive its prompt (a game that
## ends or a screen change while it shows). Under reduced motion it fades only, and cross-fades to its
## dock instead of gliding.

## Delay before it shows (s): a quick reply never flashes it.
const APPEAR_DELAY := 0.25
## Seconds it stays in the middle before it settles in its dock.
const SETTLE_AFTER := 2.2
## Pop-in, glide, leave and hover-fade times (s), and the pop's starting scale.
const POP_TIME := 0.32
const GLIDE_TIME := 0.55
const LEAVE_TIME := 0.18
const POP_SCALE := 0.72
## Scale in the dock, and the opacity while the pointer is over it.
const DOCK_SCALE := 0.8
const HOVER_ALPHA := 0.18
## Plate height, the smallest width, the hourglass medallion's radius and the text sizes (px).
const PLATE_H := 70.0
const MIN_W := 330.0
const MEDALLION_R := 25.0
const TITLE_PX := 20
const SUB_PX := 14
## Glow breathing period (s) and its reach (px).
const GLOW_PERIOD := 1.6
const GLOW_PX := 18.0
## Body, its leather grain and the rim.
const BODY := Color("1b1712")
const GRAIN := 0.3
const RIM := Color(0.831, 0.651, 0.29, 0.95)
## Gap (px) between the opponent's plate and the docked notice.
const DOCK_GAP := 10.0
## Kept for drivers that measured the old docked notice (#38).
const NOTCH := 6.0

enum Phase { HIDDEN, DELAY, CENTRED, DOCKED, LEAVING }

## The animated title (its trailing dots run) and the explanation under it.
var label: WaitingDots
var sub: Label
## Returns [centre (local to the parent), dock top-right corner (local)]; set by the owner.
var anchors: Callable
## Asked every frame while shown; false clears the notice (optional).
var wanted: Callable
## Plays the appear cue (tests swap it).
var play_cue: Callable = func(): Sfx.play("opponent_responding")

var phase: Phase = Phase.HIDDEN
## 0 in the middle, 1 in the dock (the glide tweens it).
var dock_k: float = 0.0
## The pop / leave scale and opacity (tweened), and the hover fade (eased every frame).
var pop: float = 1.0
var show_a: float = 1.0
var _hover_k: float = 0.0
var _tw: Tween
var _since: float = 0.0
var _plate: StyleBox


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = UiLayers.WAIT
	visible = false
	var sb := UIStyle.flat(Color(BODY, 0.97), RIM, 2, 14)
	sb.anti_aliasing = true
	_plate = UiSurface.box(sb, UiSurface.LEATHER, GRAIN)
	label = WaitingDots.new("", TITLE_PX, UIStyle.GOLD_HI)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIStyle.font_display(700))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	sub = UIStyle.label("", SUB_PX, UIStyle.MUTED)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(sub)
	set_process(false)


## Shows `text` (its trailing ellipsis becomes the running dots) with the explanation `subline`;
## it appears after APPEAR_DELAY the first time. An empty `text` clears it (a short leave).
func show_text(text: String, subline: String = "") -> void:
	if text == "":
		leave()
		return
	label.base = base_text(text)
	label._n = -2
	label._refresh(3 if not UIStyle.reduce_motion else -1)
	sub.text = subline
	sub.visible = subline != ""
	_layout()
	if phase in [Phase.DELAY, Phase.CENTRED, Phase.DOCKED]:
		return
	# A new wait (or one that comes back while the old one was leaving) starts in the middle.
	_kill()
	phase = Phase.DELAY
	_since = 0.0
	dock_k = 0.0
	visible = true
	show_a = 0.0
	pop = POP_SCALE if not UIStyle.reduce_motion else 1.0
	_apply()
	set_process(true)
	_tw = create_tween()
	_tw.tween_interval(APPEAR_DELAY)
	_tw.tween_callback(_appear)


## Clears it: a short fade and shrink (instant if it had not appeared yet).
func leave() -> void:
	if phase == Phase.HIDDEN or phase == Phase.LEAVING:
		return
	_kill()
	if phase == Phase.DELAY or not is_inside_tree():
		_hide_now()
		return
	phase = Phase.LEAVING
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "show_a", 0.0, UIStyle.dur(LEAVE_TIME))
	if not UIStyle.reduce_motion:
		_tw.tween_property(self, "pop", 0.9, UIStyle.dur(LEAVE_TIME)).set_ease(Tween.EASE_IN)
	_tw.chain().tween_callback(_hide_now)


## True while it is shown or about to be (not hidden, not leaving).
func waiting() -> bool:
	return phase in [Phase.DELAY, Phase.CENTRED, Phase.DOCKED]


## `text` without its trailing dots or ellipsis (the dots are animated).
static func base_text(text: String) -> String:
	var t := text.strip_edges()
	while t.ends_with("…") or t.ends_with("."):
		t = t.substr(0, t.length() - 1)
	return t


## The top-left of a notice `sz` big at dock-blend `k` (0 centred on `centre`, 1 in the dock whose
## top-right corner is `dock`), drawn at `scale_k` around its centre.
static func place_at(centre: Vector2, dock: Vector2, sz: Vector2, k: float, scale_k: float) -> Vector2:
	var docked_c := dock + Vector2(-sz.x * scale_k / 2.0, sz.y * scale_k / 2.0)
	return centre.lerp(docked_c, k) - sz / 2.0


func _appear() -> void:
	phase = Phase.CENTRED
	_since = 0.0
	play_cue.call()
	_kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "show_a", 1.0, UIStyle.motion("reduced") if UIStyle.reduce_motion else UIStyle.dur(POP_TIME * 0.6))
	if not UIStyle.reduce_motion:
		_tw.tween_property(self, "pop", 1.0, UIStyle.dur(POP_TIME)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _settle() -> void:
	phase = Phase.DOCKED
	_kill()
	_tw = create_tween()
	if UIStyle.reduce_motion:
		# A cross-fade: out in the middle, in at the dock.
		_tw.tween_property(self, "show_a", 0.0, 0.12)
		_tw.tween_property(self, "dock_k", 1.0, 0.0)
		_tw.tween_property(self, "show_a", 1.0, 0.12)
	else:
		_tw.tween_property(self, "dock_k", 1.0, UIStyle.dur(GLIDE_TIME)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _hide_now() -> void:
	_kill()
	phase = Phase.HIDDEN
	visible = false
	show_a = 0.0
	dock_k = 0.0
	set_process(false)


func _kill() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


func _layout() -> void:
	var f := UIStyle.font_display(700)
	var tw := f.get_string_size(label.base + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX).x
	var sw := UIStyle.font_body().get_string_size(sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_PX).x if sub.visible else 0.0
	var text_x := PLATE_H + 6.0
	var w := maxf(MIN_W, text_x + maxf(tw, sw) + 34.0)
	size = Vector2(w, PLATE_H)
	pivot_offset = size / 2.0
	var lh := float(TITLE_PX) + 8.0
	var sh := float(SUB_PX) + 6.0 if sub.visible else 0.0
	var top := (PLATE_H - lh - sh) / 2.0
	label.position = Vector2(text_x, top)
	label.size = Vector2(w - text_x - 22.0, lh)
	sub.position = Vector2(text_x + 1.0, top + lh - 2.0)
	sub.size = Vector2(w - text_x - 22.0, sh)


func _process(delta: float) -> void:
	if phase == Phase.HIDDEN:
		set_process(false)
		return
	if wanted.is_valid() and waiting() and not bool(wanted.call()):
		leave()
	_since += delta
	if phase == Phase.CENTRED and _since >= SETTLE_AFTER:
		_settle()
	# The pointer over it: fade nearly away so the cards under it can be read.
	var over := get_global_rect().has_point(get_global_mouse_position()) and phase != Phase.DELAY
	_hover_k = move_toward(_hover_k, 1.0 if over else 0.0, delta / 0.15)
	_apply()
	queue_redraw()


## Places and fades it from its anchors, the dock blend, the pop and the hover fade.
func _apply() -> void:
	var sc := lerpf(1.0, DOCK_SCALE, dock_k) * pop
	scale = Vector2(sc, sc)
	modulate.a = show_a * lerpf(1.0, HOVER_ALPHA, _hover_k)
	if anchors.is_valid():
		var a: Array = anchors.call()
		if a.size() >= 2:
			position = place_at(a[0], a[1], size, dock_k, lerpf(1.0, DOCK_SCALE, dock_k)).round()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var t := float(Time.get_ticks_msec()) / 1000.0
	var breath := 0.5 if UIStyle.reduce_motion else 0.5 + 0.5 * sin(t * TAU / GLOW_PERIOD)
	# The soft gold glow: rounded rings fading outwards, breathing.
	var steps := 6
	for i in steps:
		var k := float(i + 1) / float(steps)
		var g := StyleBoxFlat.new()
		g.draw_center = false
		g.anti_aliasing = true
		g.set_corner_radius_all(int(14.0 + GLOW_PX * k))
		g.set_border_width_all(int(ceilf(GLOW_PX / float(steps))) + 1)
		g.border_color = Color(UIStyle.GOLD_HI, (1.0 - k) * (0.16 + 0.20 * breath))
		draw_style_box(g, r.grow(GLOW_PX * k))
	# Drop shadow, the leather plate and an engraved inner line.
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0.45)
	sh.set_corner_radius_all(16)
	sh.anti_aliasing = true
	draw_style_box(sh, Rect2(r.position + Vector2(0, 5), r.size).grow(2))
	draw_style_box(_plate, r)
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.anti_aliasing = true
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(11)
	inner.border_color = Color(UIStyle.GOLD, 0.28 + 0.12 * breath)
	draw_style_box(inner, r.grow(-5))
	# End diamonds on the rim.
	for x in [0.0, size.x]:
		Ornate.diamond(self, Vector2(x, size.y / 2.0), 6.0, Color(0, 0, 0, 0.7))
		Ornate.diamond(self, Vector2(x, size.y / 2.0), 4.5, UIStyle.GOLD)
	# The hourglass medallion: a dark socket, a gold ring with a breathing halo, the turning glass.
	var c := Vector2(PLATE_H / 2.0 + 4.0, size.y / 2.0)
	draw_circle(c, MEDALLION_R + 5.0, Color(UIStyle.GOLD_HI, 0.08 + 0.10 * breath), true, -1.0, true)
	draw_circle(c, MEDALLION_R + 1.5, Color(0, 0, 0, 0.6), true, -1.0, true)
	draw_circle(c, MEDALLION_R, Color("120e0a"), true, -1.0, true)
	draw_arc(c, MEDALLION_R, 0.0, TAU, 40, RIM, 2.0, true)
	draw_arc(c, MEDALLION_R - 4.0, 0.0, TAU, 40, Color(UIStyle.GOLD, 0.3), 1.0, true)
	Hourglass.paint(self, c, 1.75, t)


## The brass hourglass: its sand runs down and it turns over every PERIOD seconds (still under
## reduce motion). `paint` draws it at `c`, `k` times its 13x18 px base size, at time `t` (s).
class Hourglass:
	const PERIOD := 2.4
	const FLIP := 0.45

	static func paint(ci: CanvasItem, c: Vector2, k: float, t_sec: float) -> void:
		var t := 0.0 if UIStyle.reduce_motion else fmod(t_sec, PERIOD)
		var run := clampf(t / (PERIOD - FLIP), 0.0, 1.0)
		var turn := 0.0
		if t > PERIOD - FLIP:
			var q := (t - (PERIOD - FLIP)) / FLIP
			turn = PI * (q * q * (3.0 - 2.0 * q))
			run = 1.0
		ci.draw_set_transform(c, turn, Vector2(k, k))
		var w := 6.5
		var h := 9.0
		var glass := Color(1, 0.95, 0.85, 0.18)
		var sand := Color(UIStyle.GOLD_HI, 0.95)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(1.2, 0), Vector2(-1.2, 0)]), glass)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-1.2, 0), Vector2(1.2, 0), Vector2(w, h), Vector2(-w, h)]), glass)
		# Sand: the top cone shrinks while the bottom heap grows.
		var top_k := 1.0 - run
		if top_k > 0.02:
			var ty := -h * top_k
			var tw := lerpf(1.2, w, top_k)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-tw, ty), Vector2(tw, ty), Vector2(1.0, -0.5), Vector2(-1.0, -0.5)]), sand)
			ci.draw_line(Vector2(0, 0), Vector2(0, h - 1.0), Color(sand, 0.7), 0.8)
		if run > 0.02:
			var by := h - h * 0.8 * run
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-w + 0.6, h), Vector2(w - 0.6, h), Vector2(0, by)]), sand)
		var brass := UIStyle.GOLD
		ci.draw_line(Vector2(-w - 2.0, -h - 1.0), Vector2(w + 2.0, -h - 1.0), brass, 1.8, true)
		ci.draw_line(Vector2(-w - 2.0, h + 1.0), Vector2(w + 2.0, h + 1.0), brass, 1.8, true)
		ci.draw_polyline(PackedVector2Array([Vector2(-w, -h), Vector2(-1.2, 0), Vector2(-w, h)]), Color(brass, 0.85), 0.9, true)
		ci.draw_polyline(PackedVector2Array([Vector2(w, -h), Vector2(1.2, 0), Vector2(w, h)]), Color(brass, 0.85), 0.9, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
