class_name GameUi
extends RefCounted
## Small stateless builders shared by the match screen's components.


## Frees every child of `node` (removed at once so layouts update this frame).
static func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


## Wraps `inner` in a margin so hover glow / scale of buttons near the edge of a scrolling panel
## is not clipped by the scroll area (user feedback).
static func glow_room(inner: Control, px: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(side, px)
	mc.add_child(inner)
	return mc


## A sidebar panel with the standard panel style.
static func side_panel(color: Color = Color(UIStyle.PANEL, 0.96)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSurface.box(UIStyle.panel_style(color), UiSurface.LEATHER, UIStyle.PANEL_GRAIN))
	return p


## Gold section title with a thin rule under it; the title Label is child 0.
static func header(text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(UIStyle.label(text, 15, UIStyle.GOLD, false, true))
	var rule := ColorRect.new()
	rule.color = Color(UIStyle.GOLD, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	return v


## Rounded tag in a dark shade of `col` with light text.
static func pill(text: String, col: Color, fs: int = 13) -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(col.darkened(0.7), 0.95), col, 1, 10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(UIStyle.label(text, fs, col.lightened(0.55)))
	return p


## Gives a card widget a fixed display size (pivot centred for hover scaling).
static func resize_card(w: CardWidget, sz: Vector2) -> void:
	w.custom_minimum_size = sz
	w.size = sz
	w.pivot_offset = sz / 2.0


## Makes a passive display subtree click-through (rows handle the click themselves).
static func ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		ignore_mouse(ch)
