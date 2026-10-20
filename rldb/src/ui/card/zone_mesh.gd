class_name ZoneMesh
extends RefCounted
## J31 follow-up (perf review: ~30 empty board zones issued ~92 draw calls each, 2766 of ~4100 per
## frame). The static layers of an empty zone (recess, tint, 8-ring inner shadow, rim, lip and the
## engraved mark drawn three times) are recorded once by a MeshPen, with Godot's own tessellation, into
## one triangle list, and every redraw emits that list as a single draw call. The GPU blends the
## triangles of a draw call in order, so the zone is the same pixels as before at any size, scale or
## position; nothing has to be re-baked when it moves, and a modulate (the dims) applies as before.
## Only the animated zone pick is still drawn live, between the recess and the mark as before.
##
## Meshes are shared per (kind, size, oversampling, mark, self_modulate): on the board all zones of one
## kind and dim share one. (The modulate matters only to the anti-aliased lines; see MeshPen._prim.)

## Turn it off to draw every empty zone live (pixel comparisons: the old path).
static var enabled := true
## Meshes kept; the cache is dropped when it grows past this (sizes change only on a resize).
const CACHE_MAX := 64

## key -> MeshPen (null when the zone cannot be recorded exactly).
static var _cache: Dictionary = {}
## Meshes recorded since the last clear() (tests, perf probes).
static var builds := 0


## The recorded static layers of an empty zone of `kind` and `size` drawn at `oversampling` (the canvas
## item's viewport oversampling), with the engraved mark when `mark`, drawn under `modulate` (the
## item's self_modulate). null when ZoneMesh is off or the drawing cannot be recorded exactly (the
## caller then draws live).
static func for_zone(kind: String, size: Vector2, oversampling: float, mark: bool, modulate: Color = Color.WHITE) -> MeshPen:
	if not enabled or size.x < 1.0 or size.y < 1.0:
		return null
	var key := "%s|%.4f|%.4f|%.5f|%d|%s" % [kind, size.x, size.y, oversampling, int(mark), modulate.to_html()]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	var pen := MeshPen.new(oversampling, modulate)
	var pt := CardPainter.new(null)
	pt.pen = pen
	pt.size_kind = kind
	pt.s = CardLayouts.empty_scale(size)
	pt.cr = Rect2(Vector2.ZERO, size)
	CardLayouts.draw_empty_base(pt, size)
	if mark:
		CardLayouts.draw_empty_mark(pt, size, false)
	builds += 1
	var out: MeshPen = null if pen.unsupported else pen
	_cache[key] = out
	return out


## Drops every recorded mesh (and resets `builds`).
static func clear() -> void:
	_cache.clear()
	builds = 0
