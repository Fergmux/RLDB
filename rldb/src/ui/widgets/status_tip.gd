class_name StatusTip
extends CanvasLayer
## Instant hover tooltip for the small status / Rune icons on cards: it appears the moment the
## pointer is over an icon (the native tooltip waits for its delay, too long for something this
## small) and names it, e.g. "Poison ×2". One shared tip per scene tree, drawn above everything;
## it never takes the mouse.
##
##   StatusTip.show_for(owner, "Poison ×2", owner.get_global_transform_with_canvas() * icon_rect)
##   StatusTip.hide_for(owner)     # only hides it while `owner` is the one showing it

## Canvas layer of the tip: above the card inspector and every modal.
const LAYER := 120
## Gap (px) between the icon and the tip.
const GAP := 6.0
const FONT_SIZE := 15

static var _tip: StatusTip

var _panel: PanelContainer
var _label: Label
var _owner_id: int = 0


## Shows `text` next to `anchor` (a screen-space rect, normally the icon: a rect in the owner's local
## space times owner.get_global_transform_with_canvas()) for `owner`.
static func show_for(owner: Control, text: String, anchor: Rect2) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	if _tip == null or not is_instance_valid(_tip) or not _tip.is_inside_tree():
		_tip = StatusTip.new()
		owner.get_tree().root.add_child(_tip)
	_tip._show(owner, text, anchor)


## Hides the tip if `owner` is showing it.
static func hide_for(owner: Object) -> void:
	if _tip != null and is_instance_valid(_tip) and owner != null and _tip._owner_id == owner.get_instance_id():
		_tip._panel.visible = false
		_tip._owner_id = 0


## The text shown, or "" while hidden (tests).
static func shown_text() -> String:
	if _tip == null or not is_instance_valid(_tip) or not _tip._panel.visible:
		return ""
	return _tip._label.text


func _init() -> void:
	layer = LAYER
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color(0.035, 0.03, 0.025, 0.97), Color(UIStyle.GOLD, 0.6), 1, 6)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	_label = UIStyle.label("", FONT_SIZE, UIStyle.TEXT)
	_label.add_theme_font_override("font", UIStyle.font_bold())
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_panel.visible = false
	add_child(_panel)


func _show(owner: Control, text: String, anchor: Rect2) -> void:
	_owner_id = owner.get_instance_id()
	_label.text = text
	_panel.visible = true
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	_panel.size = sz
	var a := anchor
	var vp := owner.get_viewport_rect().size
	var pos := Vector2(a.get_center().x - sz.x / 2.0, a.position.y - sz.y - GAP)
	if pos.y < 4.0:
		pos.y = a.end.y + GAP     # no room above: below the icon
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	_panel.position = pos
