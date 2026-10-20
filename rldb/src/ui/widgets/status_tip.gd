class_name StatusTip
extends CanvasLayer
## Instant hover tooltip for the small status / Rune icons on cards: it appears the moment the
## pointer is over an icon (the native tooltip waits for its delay, too long for something this
## small) and names it, e.g. "Poison ×2", with its effect in a separate section below (2026-10-18;
## StatusHelp shows the same tip for a status name in text). One shared tip per scene tree, drawn
## above everything; it never takes the mouse.
##
##   StatusTip.show_for(owner, "Poison ×2", owner.get_global_transform_with_canvas() * icon_rect, effect)
##   StatusTip.hide_for(owner)     # only hides it while `owner` is the one showing it

## Canvas layer of the tip: above the card inspector and every modal.
const LAYER := 120
## Gap (px) between the icon and the tip.
const GAP := 6.0
const FONT_SIZE := 15
const DETAIL_FONT_SIZE := 14
## Width the effect section wraps at.
const DETAIL_W := 320.0
## F5 tooltip (design review 1.4.3 / #104): parchment-dark body with a light leather grain, a 4 px
## radius and a 6 px pointer notch toward the source.
const BODY := Color("1b1712")
const GRAIN := 0.3
const NOTCH := 6.0

static var _tip: StatusTip

var _panel: PanelContainer
var _label: Label
var _detail_box: PanelContainer
var _detail: Label
var _owner_id: int = 0
var _notch: Notch
var _motion: Tween


## Shows `text` next to `anchor` (a screen-space rect, normally the icon: a rect in the owner's local
## space times owner.get_global_transform_with_canvas()) for `owner`; `detail` (the effect) goes
## in its own section below, when given. An empty `text` shows only the effect.
static func show_for(owner: Control, text: String, anchor: Rect2, detail: String = "") -> void:
	if owner == null or not owner.is_inside_tree():
		return
	if _tip == null or not is_instance_valid(_tip) or not _tip.is_inside_tree():
		_tip = StatusTip.new()
		owner.get_tree().root.add_child(_tip)
	_tip._show(owner, text, anchor, detail)


## Hides the tip if `owner` is showing it.
static func hide_for(owner: Object) -> void:
	if _tip != null and is_instance_valid(_tip) and owner != null and _tip._owner_id == owner.get_instance_id():
		_tip._panel.visible = false
		_tip._owner_id = 0


## Hides the tip whoever shows it (J10: a full-screen modal such as the rewards screen opening over the
## board; the tip's canvas layer would otherwise draw over it).
static func hide_all() -> void:
	if _tip != null and is_instance_valid(_tip):
		_tip._panel.visible = false
		_tip._owner_id = 0


## The text shown, or "" while hidden (tests).
static func shown_text() -> String:
	if _tip == null or not is_instance_valid(_tip) or not _tip._panel.visible:
		return ""
	return _tip._label.text


## The effect section shown, or "" (tests).
static func shown_detail() -> String:
	if _tip == null or not is_instance_valid(_tip) or not _tip._panel.visible or not _tip._detail_box.visible:
		return ""
	return _tip._detail.text


func _init() -> void:
	layer = LAYER
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color(BODY, 0.98), Color(UIStyle.GOLD, 0.6), 1, 4)
	# D5: tooltip text keeps the 12 px content floor (it had 5 px above it).
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = UIStyle.CONTENT_FLOOR
	sb.content_margin_bottom = UIStyle.CONTENT_FLOOR
	UIStyle.lift(sb, UIStyle.DEPTH_FLOATING)
	_panel.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, GRAIN))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_label = UIStyle.label("", FONT_SIZE, UIStyle.TEXT)
	_label.add_theme_font_override("font", UIStyle.font_bold())
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_label)
	_detail_box = StatusHelp.section_box()
	_detail = StatusHelp.section_label("")
	_detail_box.add_child(_detail)
	v.add_child(_detail_box)
	_panel.visible = false
	add_child(_panel)
	_notch = Notch.new()
	_panel.add_child(_notch)


## The pointer notch: a small gold-edged triangle on the tip's edge, pointing at the source.
class Notch extends Control:
	## True: on the bottom edge pointing down (the tip is above its source); false: on top, pointing up.
	var down := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true   # the PanelContainer must not stretch it over the tip
		custom_minimum_size = Vector2.ZERO

	func _draw() -> void:
		var n := StatusTip.NOTCH
		var c := Vector2(size.x / 2.0, 0.0)
		var d := 1.0 if down else -1.0
		var pts := PackedVector2Array([c + Vector2(-n, 0), c + Vector2(n, 0), c + Vector2(0, n * d)])
		draw_colored_polygon(pts, StatusTip.BODY)
		draw_polyline(PackedVector2Array([pts[0], pts[2], pts[1]]), Color(UIStyle.GOLD, 0.6), 1.0, true)


func _show(owner: Control, text: String, anchor: Rect2, detail: String) -> void:
	var was_hidden := not _panel.visible
	_owner_id = owner.get_instance_id()
	_label.text = text
	_label.visible = text != ""
	_detail.text = detail
	_detail_box.visible = detail != ""
	_panel.visible = true
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	_panel.size = sz
	var a := anchor
	var vp := owner.get_viewport_rect().size
	var gap := GAP + NOTCH
	var pos := Vector2(a.get_center().x - sz.x / 2.0, a.position.y - sz.y - gap)
	var above := pos.y >= 4.0
	if not above:
		pos.y = a.end.y + gap     # no room above: below the icon
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	_panel.position = pos
	# The notch points at the source (its x follows the anchor even when the tip was clamped).
	var nx := clampf(a.get_center().x - pos.x, 10.0, sz.x - 10.0)
	_notch.down = above
	_notch.position = pos + Vector2(nx - NOTCH, sz.y - 1.0 if above else 1.0)
	_notch.size = Vector2(NOTCH * 2.0, 0.0)
	_notch.queue_redraw()
	# tooltip_in (140 ms, no overshoot; a 120 ms fade under reduce motion) for a fresh tip only.
	if was_hidden:
		if _motion != null and _motion.is_valid():
			_motion.kill()
		_motion = UIStyle.tween_in(_panel, "tooltip_in")
