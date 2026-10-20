class_name PrivacyBackdrop
extends Control
## Opaque backdrop of the hot-seat hand-over (design review #68): the menu painting at 25%
## brightness under a heavy vignette, a large engraved sigil (two rune rings and a hexagram, 10%
## gold) turning slowly behind the panel, and a few drifting motes. It hides the board completely
## (no table is drawn) and stops every click. Reduce motion: the sigil rests and the motes hold.

## Brightness of the painting (the veil is 1 - this).
const ART_BRIGHTNESS := 0.25
## Sigil radius as a share of the shorter screen side, its alpha and one turn's period (s).
const SIGIL_SHARE := 0.42
const SIGIL_ALPHA := 0.10
const SIGIL_TURN := 90.0

## Seconds clock (tests inject one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0
var _sigil: Sigil


## Draw layer: above the board's coin flip, game-end and pile layers (they must never show through
## the hand-over), under the in-game menu and confirmations (Esc still opens the menu over it).
const LAYER := UiLayers.GAME_MENU - 1


func _init() -> void:
	name = "PrivacyBackdrop"
	z_index = LAYER
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.035, 0.03, 0.04, 1.0)   # opaque under everything
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	add_child(UIStyle.background(1.0 - ART_BRIGHTNESS, UIStyle.MENU_BACKGROUND))
	var vig := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.8)])
	g.offsets = PackedFloat32Array([0.35, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 256
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	_sigil = Sigil.new()
	_sigil.host = self
	add_child(_sigil)
	add_child(AmbientMotes.new(14, [AmbientMotes.GOLD], 4242))


## The sigil's rotation (radians) now; 0 under reduce motion.
func sigil_angle() -> float:
	if UIStyle.reduce_motion:
		return 0.0
	return fposmod(float(clock.call()) / SIGIL_TURN, 1.0) * TAU


## The engraved sigil, drawn centred.
class Sigil extends Control:
	var host: PrivacyBackdrop

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_d: float) -> void:
		if not UIStyle.reduce_motion and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * PrivacyBackdrop.SIGIL_SHARE
		var a := host.sigil_angle() if host != null else 0.0
		var col := Color(UIStyle.GOLD, PrivacyBackdrop.SIGIL_ALPHA)
		var dim := Color(UIStyle.GOLD, PrivacyBackdrop.SIGIL_ALPHA * 0.6)
		draw_arc(c, r, 0.0, TAU, 128, col, 2.0, true)
		draw_arc(c, r * 0.93, 0.0, TAU, 128, dim, 1.0, true)
		draw_arc(c, r * 0.62, 0.0, TAU, 96, col, 1.5, true)
		# Rune ticks between the outer rings, turning one way; the hexagram the other way.
		for i in 36:
			var t := a + TAU * float(i) / 36.0
			var p0 := c + Vector2(cos(t), sin(t)) * r * 0.945
			var p1 := c + Vector2(cos(t), sin(t)) * r * (0.985 if i % 3 == 0 else 0.965)
			draw_line(p0, p1, col, 1.5, true)
			if i % 6 == 0:
				Ornate.diamond(self, c + Vector2(cos(t), sin(t)) * r * 0.78, 5.0, col)
		for k in 2:
			var pts := PackedVector2Array()
			for j in 4:
				var t2 := -a * 0.6 + PI * 2.0 / 3.0 * float(j) + PI * float(k) / 3.0 - PI / 2.0
				pts.append(c + Vector2(cos(t2), sin(t2)) * r * 0.6)
			draw_polyline(pts, col, 1.5, true)
		draw_arc(c, r * 0.3, 0.0, TAU, 64, dim, 1.0, true)
