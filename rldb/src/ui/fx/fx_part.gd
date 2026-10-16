class_name FxPart
extends RefCounted
## Base of the FxPlayer components (spotlight, banners, effect handlers). A part keeps a
## back-reference to its FxPlayer and creates every tween, node and cleanup through it, so
## FxPlayer.finish_all() kills and frees everything a part started.

## Outline colour of the pill titles (spotlight caption, turn banner).
const TITLE_OUTLINE := Color(0, 0, 0, 0.8)
## Shadow colour of the pills.
const PILL_SHADOW := Color(0, 0, 0, 0.5)
## Dark fill of the pills (before the per-pill alpha).
const PILL_FILL := Color(0.05, 0.04, 0.035)

var _fx: FxPlayer


func _init(fx: FxPlayer) -> void:
	_fx = fx


## Dark rounded pill style with a border, a soft shadow and the given horizontal / vertical padding.
func _pill_style(fill_alpha: float, border: Color, corner: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var sb := UIStyle.flat(Color(PILL_FILL, fill_alpha), border, 2, corner)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = PILL_SHADOW
	sb.shadow_size = 6
	return sb


## Outlined display-font title label used inside the pills (click-through).
func _title_label(text: String, size: int, col: Color, outline: int) -> Label:
	var lbl := UIStyle.label(text, size, col, false, true)
	lbl.add_theme_font_override("font", UIStyle.font_display(700))
	lbl.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	lbl.add_theme_constant_override("outline_size", outline)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Soft radial dark vignette behind the card.
func _make_backdrop(centre: Vector2, area: Rect2) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.62))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var bd := TextureRect.new()
	bd.texture = gt
	bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bd.stretch_mode = TextureRect.STRETCH_SCALE
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsz := Vector2(area.size.x * 1.1, area.size.y * 1.2)
	bd.size = bsz
	bd.position = centre - bsz / 2.0
	bd.modulate.a = 0.0
	bd.z_index = UiLayers.SPOTLIGHT_DIM   # above lifted board cards, status glows and floating effect text
	return bd
