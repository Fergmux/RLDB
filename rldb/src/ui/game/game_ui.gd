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


## A sidebar panel: the F2 frame (FrameBox: a gilded bevel, rivets, leather and a vignette, design
## review #109) with the lg (16 px) inner padding.
static func side_panel(color: Color = Color(UIStyle.PANEL, 0.96)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FrameBox.make(color, "lg"))
	return p


## Section header size (T3, design review 1.4.1: 16-20 px with +1.5 px tracking).
const HEADER_PX := 16


## Gold section header (TitleText SECTION, D3): flat gold Cinzel with a hard drop shadow and the
## engraved double underline across the panel. The title Label is child 0.
static func header(text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var l := UIStyle.label(text, HEADER_PX, UIStyle.GOLD, false, true)
	l.clip_text = true
	v.add_child(l)
	TitleText.apply(l, TitleText.Tier.SECTION, HEADER_PX)
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
