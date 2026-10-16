class_name PromptPlate
extends PanelContainer
## Plate of the input-required prompt (F04-13): a vertical gradient body with a faint diagonal
## weave, a header strip behind the actor tag, a gold accent bar down the left edge and corner
## flourishes. The rim and glow are the panel's StyleBoxFlat (animated by GamePromptBanner).
## `fit()` sizes the plate to exactly its content for a given width, measured after layout.

## Height of the header strip (the tag row sits on it).
const HEAD_H := 30.0

var _gen := 0


func _draw() -> void:
	var inset := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	var rad := 9.0
	var top := Color(0.17, 0.125, 0.06)
	var bot := Color(0.075, 0.055, 0.032)
	Ornate.vgradient(self, Rect2(inset.position + Vector2(0, rad), inset.size - Vector2(0, rad * 2.0)), top.lerp(bot, 0.1), bot.lerp(top, 0.1))
	draw_rect(Rect2(inset.position + Vector2(rad, 0), Vector2(inset.size.x - rad * 2.0, rad)), top)
	draw_rect(Rect2(inset.position + Vector2(rad, inset.size.y - rad), Vector2(inset.size.x - rad * 2.0, rad)), bot)
	# Faint diagonal weave over the body.
	var wc := Color(UIStyle.GOLD, 0.035)
	var y := inset.position.y + HEAD_H
	var step := 9.0
	var x0 := inset.position.x + 10.0
	var x1 := inset.end.x - 4.0
	var yb := inset.end.y - 4.0
	var n := int((x1 - x0 + yb - y) / step)
	for i in n:
		var sx := x0 + i * step
		var sy := y
		if sx > x1:
			sy += sx - x1
			sx = x1
		var ln := minf(sx - x0, yb - sy)
		if ln > 2.0:
			draw_line(Vector2(sx, sy), Vector2(sx - ln, sy + ln), wc, 1.0)
	# Header strip.
	var hs := Rect2(inset.position + Vector2(rad * 0.4, 0), Vector2(inset.size.x - rad * 0.8, HEAD_H))
	Ornate.hgradient(self, hs, Color(UIStyle.GOLD.darkened(0.45), 0.95), Color(UIStyle.GOLD.darkened(0.72), 0.95))
	Ornate.vgradient(self, Rect2(hs.position, Vector2(hs.size.x, 12)), Color(1, 0.9, 0.6, 0.14), Color(1, 0.9, 0.6, 0.0))
	draw_line(Vector2(hs.position.x, hs.end.y), Vector2(hs.end.x, hs.end.y), Color(UIStyle.GOLD, 0.85), 1.5)
	draw_line(Vector2(hs.position.x, hs.end.y + 2.5), Vector2(hs.end.x, hs.end.y + 2.5), Color(UIStyle.GOLD, 0.25), 1.0)
	# Accent bar on the left edge.
	Ornate.vgradient(self, Rect2(3, 14, 4, size.y - 28.0), Color(UIStyle.GOLD_HI, 0.95), Color(UIStyle.GOLD.darkened(0.3), 0.8))
	Ornate.corners(self, Rect2(Vector2.ZERO, size), Color(UIStyle.GOLD_HI, 0.85), 14.0, 6.0, 1.5)


## Sizes the plate to its content at width `w`. Wrapped labels report a minimum height measured at
## whatever width they had when last laid out, so the plate is resized in passes, one frame apart,
## until the measured height stops changing (usually two passes). `on_done` runs after the last.
func fit(w: float) -> void:
	_gen += 1
	var gen := _gen
	custom_minimum_size.x = w
	size = Vector2(w, 0)
	size = Vector2(w, get_combined_minimum_size().y)
	if not is_inside_tree():
		return
	_settle(w, gen)


func _settle(w: float, gen: int) -> void:
	var last := -1.0
	for i in 4:
		await get_tree().process_frame
		if gen != _gen or not is_instance_valid(self):
			return
		size = Vector2(w, 0)
		var h := get_combined_minimum_size().y
		size = Vector2(w, h)
		pivot_offset = size / 2.0
		if is_equal_approx(h, last):
			return
		last = h


## Glowing diamond that leads the actor tag in the header strip.
class Pip extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(14, PromptPlate.HEAD_H - 4.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		Ornate.diamond(self, c, 7.0, Color(UIStyle.GOLD_HI, 0.3))
		Ornate.diamond(self, c, 5.0, UIStyle.GOLD_HI)
		Ornate.diamond(self, c, 2.0, Color(0.2, 0.13, 0.04))
