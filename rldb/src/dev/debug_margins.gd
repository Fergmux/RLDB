class_name DebugMargins
extends Control
## Development-only margin overlay (design review D5, WP-5): `-- --debug-margins` on the command line
## (Main adds it once). It draws, over everything, a translucent red band UIStyle.CONTENT_FLOOR
## (12 px) deep inside the edge of every visible PanelContainer, and outlines in bright red each
## visible Label, Button or LineEdit that sits inside one of those bands (content closer to a frame
## than the 12 px floor). Shots taken with it on show at a glance where content crowds a frame.
## Click-through; never added in normal runs.

## The command-line flag.
const FLAG := "--debug-margins"
const BAND := Color(1.0, 0.1, 0.1, 0.18)
const EDGE := Color(1.0, 0.15, 0.15, 0.55)
const HIT := Color(1.0, 0.2, 0.2, 0.95)

## Content controls found inside a band on the last draw (dev drivers read it).
var violations: Array = []


## True when the flag is on the command line.
static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args() or FLAG in OS.get_cmdline_args()


func _init() -> void:
	name = "DebugMargins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_level = true
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	violations.clear()
	var inv := get_global_transform().affine_inverse()
	var panels: Array = []
	_collect(get_tree().root, panels)
	var floor_px := float(UIStyle.CONTENT_FLOOR)
	for p in panels:
		var pc := p as Control
		var r: Rect2 = inv * (pc.get_global_transform() * Rect2(Vector2.ZERO, pc.size))
		if r.size.x < floor_px * 3.0 or r.size.y < floor_px * 3.0:
			continue
		var inner := r.grow(-floor_px)
		draw_rect(Rect2(r.position, Vector2(r.size.x, floor_px)), BAND)
		draw_rect(Rect2(Vector2(r.position.x, inner.end.y), Vector2(r.size.x, floor_px)), BAND)
		draw_rect(Rect2(Vector2(r.position.x, inner.position.y), Vector2(floor_px, inner.size.y)), BAND)
		draw_rect(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(floor_px, inner.size.y)), BAND)
		draw_rect(inner, EDGE, false, 1.0)
		for c in _content(pc):
			var cc := c as Control
			var cr: Rect2 = inv * (cc.get_global_transform() * Rect2(Vector2.ZERO, cc.size))
			if cr.has_area() and r.encloses(cr) and not inner.encloses(cr):
				draw_rect(cr, HIT, false, 2.0)
				violations.append(cc)
				_report(pc, cc, r, cr)


## Prints each violation once per run (node path, its text, the smallest gap to the frame in px), so
## a driver's log lists what the shots show.
func _report(panel: Control, c: Control, r: Rect2, cr: Rect2) -> void:
	var key := str(c.get_instance_id())
	if _reported.has(key):
		return
	_reported[key] = true
	var gap: float = minf(minf(cr.position.x - r.position.x, cr.position.y - r.position.y),
			minf(r.end.x - cr.end.x, r.end.y - cr.end.y))
	var txt := ""
	if c is Label or c is Button or c is LineEdit:
		txt = String(c.get("text")).left(32).replace("\n", " ")
	print("MARGIN gap=%d px  %s  \"%s\"  in %s" % [int(gap), str(c.get_path()).right(70), txt, panel.name])


var _reported := {}


func _collect(n: Node, out: Array) -> void:
	if n == self:
		return
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is PanelContainer:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _content(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		if c is PanelContainer:
			continue   # a nested panel is checked against its own frame
		if c is Label or c is Button or c is LineEdit or c is RichTextLabel:
			out.append(c)
		out.append_array(_content(c))
	return out
