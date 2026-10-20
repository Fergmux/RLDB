class_name MeshPen
extends RefCounted
## J31 follow-up: records 2D drawing into ONE indexed triangle list, emitted later as a single
## RenderingServer.canvas_item_add_triangle_array (one draw call instead of one per primitive).
##
## It has the CanvasItem drawing methods the painters use (draw_style_box with a StyleBoxFlat,
## draw_line, draw_polyline, draw_polyline_colors, draw_arc, draw_circle, draw_colored_polygon), and
## each tessellates exactly as Godot 4.6 does (ported from scene/resources/style_box_flat.cpp,
## scene/main/canvas_item.cpp and servers/rendering/renderer_canvas_cull.cpp, 4.6-stable): the same
## vertices, colours and triangle order. The GPU blends the triangles of one draw call in submission
## order, so the result is the same pixels as the separate draw calls, not an approximation of them.
## Primitive (draw_line) colours: the canvas renderer stores them as half(colour x the item's modulate)
## on the CPU, where polygon colours are multiplied by the modulate on the GPU; the pen stores
## half(colour x `modulate`) / `modulate`, so the GPU's product is the renderer's value again.
##
## What it cannot reproduce exactly (a StyleBoxFlat with a shadow, skew or expand margin; textures)
## sets `unsupported`: the caller then draws live.

## Canvas renderer feather width of anti-aliased lines, polylines and circles (FEATHER_SIZE).
const FEATHER := 1.25
## Segments of a circle (canvas_item_add_ellipse / draw_ellipse).
const CIRCLE_SEGMENTS := 64

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## The oversampling the recorded canvas item is drawn with (StyleBoxFlat scales its feather by it).
var oversampling := 1.0
## The modulate the recording will be drawn under (the canvas item's self_modulate; see _quad).
var modulate := Color.WHITE
## Something was drawn that this pen cannot reproduce exactly.
var unsupported := false


func _init(p_oversampling: float = 1.0, p_modulate: Color = Color.WHITE) -> void:
	oversampling = p_oversampling if p_oversampling > 0.0 else 1.0
	modulate = p_modulate


## Appends the recording to canvas item `ci` as one triangle array (nothing when empty).
func emit(ci: RID) -> void:
	if points.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci, indices, points, colors)


# ---------------------------------------------------------------- low level

func _tri_list(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array) -> void:
	var base := points.size()
	points.append_array(pts)
	colors.append_array(cols)
	for i in idx:
		indices.append(base + i)


func _strip(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var base := points.size()
	points.append_array(pts)
	colors.append_array(cols)
	for k in pts.size() - 2:
		indices.append(base + k)
		indices.append(base + k + 1)
		indices.append(base + k + 2)


## A canvas "primitive" quad: triangles (0, 1, 2) and (0, 2, 3), colours as the renderer packs them.
func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri_list(PackedVector2Array([a, b, c, d]), PackedColorArray([_prim(ca), _prim(cb), _prim(cc), _prim(cd)]),
		PackedInt32Array([0, 1, 2, 0, 2, 3]))


static var _f32 := PackedFloat32Array([0.0])


## `v` rounded to a 32-bit float (the engine's real_t).
static func _f(v: float) -> float:
	_f32[0] = v
	return _f32[0]


## A primitive vertex colour: half(c x modulate), divided back by the modulate the GPU applies.
func _prim(c: Color) -> Color:
	var m := modulate
	return Color(_dm(_h(c.r * m.r), m.r), _dm(_h(c.g * m.g), m.g), _dm(_h(c.b * m.b), m.b), _dm(_h(c.a * m.a), m.a))


static func _dm(v: float, m: float) -> float:
	return v / m if m != 0.0 else 0.0


## `v` as Math::make_half_float stores it (core/math/math_funcs.h): from a 32-bit float, the mantissa
## truncated to 10 bits (toward zero, no rounding), and anything under 2^-14 flushed to zero.
static func _h(v: float) -> float:
	var f := _f(v)
	if f == 0.0 or is_nan(f) or is_inf(f):
		return f
	var a := absf(f)
	if a < pow(2.0, -14):
		return 0.0
	if a >= 65536.0:
		return signf(f) * INF
	var e := floori(log(a) / log(2.0))
	# log() can be off by one ulp at exact powers of two.
	if pow(2.0, e) > a:
		e -= 1
	elif pow(2.0, e + 1) <= a:
		e += 1
	var q := pow(2.0, e - 10)
	return signf(f) * floorf(a / q) * q


# ---------------------------------------------------------------- CanvasItem drawing API

## CanvasItem.draw_set_transform_matrix: only the identity can be recorded.
func draw_set_transform_matrix(xf: Transform2D) -> void:
	if not xf.is_equal_approx(Transform2D.IDENTITY):
		unsupported = true


## CanvasItem.draw_colored_polygon (no texture): triangulated as canvas_item_add_polygon does.
func draw_colored_polygon(pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	if tex != null:
		unsupported = true
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	_tri_list(pts, cols, idx)


## CanvasItem.draw_line (canvas_item_add_line).
func draw_line(from: Vector2, to: Vector2, col: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var diff := from - to
	var dir := diff.orthogonal().normalized()
	var t := dir * width * 0.5
	var bl: Vector2
	var br: Vector2
	var el: Vector2
	var er: Vector2
	if width >= 0.0:
		bl = from + t
		br = from - t
		el = to + t
		er = to - t
		_quad(bl, br, er, el, col, col, col, col)
	else:
		unsupported = true   # a 2-point line primitive
		return
	if not antialiased:
		return
	var bs := FEATHER
	if 0.0 <= width and width < 1.0:
		bs *= width
	var dir2 := diff.normalized()
	var border := dir * bs
	var border2 := dir2 * bs
	var tr := Color(col, 0.0)
	_quad(bl, bl + border, el + border, el, col, tr, tr, col)
	_quad(br, br - border, er - border, er, col, tr, tr, col)
	_quad(bl, bl + border2, br + border2, br, col, tr, tr, col)
	_quad(el, el - border2, er - border2, er, col, tr, tr, col)
	_quad(bl, bl + border2, bl + border + border2, bl + border, col, tr, tr, tr)
	_quad(br, br + border2, br - border + border2, br - border, col, tr, tr, tr)
	_quad(el, el - border2, el + border - border2, el + border, col, tr, tr, tr)
	_quad(er, er - border2, er - border - border2, er - border, col, tr, tr, tr)


## CanvasItem.draw_polyline.
func draw_polyline(pts: PackedVector2Array, col: Color, width: float = -1.0, antialiased: bool = false) -> void:
	_polyline(pts, PackedColorArray([col]), width, antialiased)


## CanvasItem.draw_polyline_colors.
func draw_polyline_colors(pts: PackedVector2Array, cols: PackedColorArray, width: float = -1.0, antialiased: bool = false) -> void:
	_polyline(pts, cols, width, antialiased)


## CanvasItem.draw_arc (draw_ellipse_arc -> draw_polyline).
func draw_arc(center: Vector2, radius: float, start: float, end: float, count: int, col: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var pts := PackedVector2Array()
	pts.resize(count)
	var delta := clampf(end - start, -TAU, TAU)
	for i in count:
		var theta := (float(i) / (count - 1.0)) * delta + start
		pts[i] = center + Vector2(radius * cos(theta), radius * sin(theta))
	draw_polyline(pts, col, width, antialiased)


## CanvasItem.draw_circle (draw_ellipse -> canvas_item_add_ellipse, or a 64-point polyline ring).
func draw_circle(pos: Vector2, radius: float, col: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false) -> void:
	if filled:
		_ellipse(pos, radius, radius, col, antialiased)
	elif width >= 2.0 * radius:
		_ellipse(pos, radius + 0.5 * width, radius + 0.5 * width, col, antialiased)
	else:
		var pts := PackedVector2Array()
		pts.resize(CIRCLE_SEGMENTS + 1)
		var step := TAU / CIRCLE_SEGMENTS
		for i in CIRCLE_SEGMENTS:
			var ang := float(i) * step
			pts[i] = Vector2(cos(ang) * radius, sin(ang) * radius) + pos
		pts[CIRCLE_SEGMENTS] = pts[0]
		draw_polyline(pts, col, width, antialiased)


func _ellipse(pos: Vector2, major: float, minor: float, col: Color, antialiased: bool) -> void:
	var n := CIRCLE_SEGMENTS
	var step := TAU / n
	var pts := PackedVector2Array()
	pts.resize(n + 2)
	pts[n + 1] = pos
	for i in n + 1:
		var ang := float(i) * step
		pts[i] = Vector2(cos(ang) * major, sin(ang) * minor) + pos
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array(PackedInt32Array([n + 1, i, i + 1]))
	var cols := PackedColorArray()
	cols.resize(n + 2)
	cols.fill(col)
	_tri_list(pts, cols, idx)
	if not antialiased:
		return
	var bs := FEATHER
	var max_axis := maxf(major, minor) * 2.0
	if 0.0 <= max_axis and max_axis < 1.0:
		bs *= max_axis * 0.5
	var tr := Color(col, 0.0)
	var fp := PackedVector2Array()
	var fc := PackedColorArray()
	fp.resize(2 * n + 2)
	fc.resize(2 * n + 2)
	for i in n + 1:
		var ang := float(i) * step
		var c := cos(ang)
		var s := sin(ang)
		fp[i * 2] = Vector2(c * major, s * minor) + pos
		fp[i * 2 + 1] = Vector2(c * (major + bs), s * (minor + bs)) + pos
		fc[i * 2] = col
		fc[i * 2 + 1] = tr
	_strip(fp, fc)


static func _seg_dir(pts: PackedVector2Array, i: int, prev: Vector2) -> Vector2:
	if i == pts.size() - 1:
		return prev
	var d := (pts[i + 1] - pts[i]).normalized()
	return prev if d.is_zero_approx() else d


static func _edge_offset(seg: Vector2, prev: Vector2) -> Vector2:
	var length := 1.0
	var bis := (prev * seg.length() - seg * prev.length()).normalized()
	var ang := atan2(bis.cross(prev), bis.dot(prev))
	var sa := sin(ang)
	if not is_zero_approx(sa) and not seg.is_equal_approx(prev):
		length = clampf(1.0 / sa, -3.0, 3.0)
	else:
		bis = seg.orthogonal()
	if bis.is_zero_approx():
		bis = seg.orthogonal()
	return bis * length


## canvas_item_add_polyline: the middle strip, then (anti-aliased) the left and right feather strips.
func _polyline(pts: PackedVector2Array, cols_in: PackedColorArray, width: float, aa: bool) -> void:
	var n := pts.size()
	if n < 2:
		return
	if width < 0.0:
		unsupported = true   # a line strip
		return
	var color := Color(1, 1, 1, 1)
	var ppc := n * 2
	var loop := pts[0].is_equal_approx(pts[n - 1])
	var first_dir := Vector2.ZERO
	var last_dir := Vector2.ZERO
	for i in range(1, n):
		first_dir = (pts[i] - pts[i - 1]).normalized()
		if not first_dir.is_zero_approx():
			break
	for i in range(n - 1, 0, -1):
		last_dir = (pts[i] - pts[i - 1]).normalized()
		if not last_dir.is_zero_approx():
			break
	var extra := 4 if (aa and not loop) else 0
	var mp := PackedVector2Array()
	var mc := PackedColorArray()
	mp.resize(ppc + extra)
	mc.resize(ppc + extra)
	if not aa:
		var prev := Vector2.ZERO
		for i in n:
			var seg := _seg_dir(pts, i, prev)
			if i == 0 and loop:
				prev = last_dir
			elif i == n - 1 and loop:
				prev = first_dir
			var beo: Vector2
			if i == 0 and not loop:
				beo = first_dir.orthogonal()
			elif i == n - 1 and not loop:
				beo = last_dir.orthogonal()
			else:
				beo = _edge_offset(seg, prev)
			var eo := beo * (width * 0.5)
			mp[i * 2] = pts[i] + eo
			mp[i * 2 + 1] = pts[i] - eo
			if i < cols_in.size():
				color = cols_in[i]
			mc[i * 2] = color
			mc[i * 2 + 1] = color
			prev = seg
		_strip(mp, mc)
		return
	var bs := FEATHER
	if width < 1.0:
		bs *= width
	var color2 := Color(1, 1, 1, 0)
	var side_extra := 0 if loop else 5
	var lp := PackedVector2Array()
	var lc := PackedColorArray()
	var rp := PackedVector2Array()
	var rc := PackedColorArray()
	lp.resize(ppc + side_extra)
	lc.resize(ppc + side_extra)
	rp.resize(ppc + side_extra)
	rc.resize(ppc + side_extra)
	var prev := Vector2.ZERO
	for i in n:
		var is_first := i == 0
		var is_last := i == n - 1
		var seg := _seg_dir(pts, i, prev)
		if is_first and loop:
			prev = last_dir
		elif is_last and loop:
			prev = first_dir
		var beo: Vector2
		if is_first and not loop:
			beo = first_dir.orthogonal()
		elif is_last and not loop:
			beo = last_dir.orthogonal()
		else:
			beo = _edge_offset(seg, prev)
		var eo := beo * (width * 0.5)
		var border := beo * bs
		var pos := pts[i]
		var j := i * 2 + (0 if loop else 2)
		mp[j] = pos + eo
		mp[j + 1] = pos - eo
		lp[j] = pos + eo
		lp[j + 1] = pos + eo + border
		rp[j] = pos - eo
		rp[j + 1] = pos - eo - border
		if i < cols_in.size():
			color = cols_in[i]
			color2 = Color(color.r, color.g, color.b, 0)
		mc[j] = color
		mc[j + 1] = color
		lc[j] = color
		lc[j + 1] = color2
		rc[j] = color
		rc[j + 1] = color2
		if is_first and not loop:
			var bb := -seg * bs
			mp[0] = pos + eo + bb
			mp[1] = pos - eo + bb
			mc[0] = color2
			mc[1] = color2
			lp[0] = pos + eo + bb
			lp[1] = pos + eo + bb + border
			lc[0] = color2
			lc[1] = color2
			rp[0] = pos - eo + bb
			rp[1] = pos - eo + bb - border
			rc[0] = color2
			rc[1] = color2
		if is_last and not loop:
			var eb := prev * bs
			var ei := ppc + 2
			mp[ei] = pos + eo + eb
			mp[ei + 1] = pos - eo + eb
			mc[ei] = color2
			mc[ei + 1] = color2
			lp[ei] = pos + eo
			lp[ei + 1] = pos + eo + eb + border
			lp[ei + 2] = pos + eo + eb
			lc[ei] = color
			lc[ei + 1] = color2
			lc[ei + 2] = color2
			rp[ei] = pos - eo
			rp[ei + 1] = pos - eo + eb - border
			rp[ei + 2] = pos - eo + eb
			rc[ei] = color
			rc[ei + 1] = color2
			rc[ei + 2] = color2
		prev = seg
	# Command order: the middle strip is allocated first, then the left and right feathers.
	_strip(mp, mc)
	_strip(lp, lc)
	_strip(rp, rc)


# ---------------------------------------------------------------- StyleBoxFlat

## CanvasItem.draw_style_box with a StyleBoxFlat (StyleBoxFlat::draw, no shadow / skew / expand margin).
func draw_style_box(sb: StyleBox, rect: Rect2) -> void:
	var f := sb as StyleBoxFlat
	if f == null or f.shadow_size > 0 or not f.skew.is_zero_approx() or f.expand_margin_left != 0.0 \
			or f.expand_margin_top != 0.0 or f.expand_margin_right != 0.0 or f.expand_margin_bottom != 0.0:
		unsupported = true
		return
	var bw: Array[float] = [float(f.border_width_left), float(f.border_width_top), float(f.border_width_right), float(f.border_width_bottom)]
	var cr: Array[float] = [float(f.corner_radius_top_left), float(f.corner_radius_top_right), float(f.corner_radius_bottom_right), float(f.corner_radius_bottom_left)]
	var draw_border := bw[0] > 0 or bw[1] > 0 or bw[2] > 0 or bw[3] > 0
	var draw_center := f.draw_center
	if not draw_border and not draw_center:
		return
	var style_rect := rect
	if is_zero_approx(style_rect.size.x) or is_zero_approx(style_rect.size.y):
		return
	var rounded := cr[0] > 0 or cr[1] > 0 or cr[2] > 0 or cr[3] > 0
	var aa_on := rounded and f.anti_aliasing
	var blend_on := f.border_blend and draw_border
	var bg := f.bg_color
	var bc := f.border_color
	var bc_alpha := Color(bc.r, bc.g, bc.b, 0)
	var bc_blend := bg if draw_center else bc_alpha
	var bc_inner := bc_blend if blend_on else bc
	var width := maxf(style_rect.size.x, 0)
	var height := maxf(style_rect.size.y, 0)
	var ab: Array[float] = [1000000.0, 1000000.0, 1000000.0, 1000000.0]
	_adapt(SIDE_TOP, SIDE_BOTTOM, ab, bw, height, height, height)
	_adapt(SIDE_LEFT, SIDE_RIGHT, ab, bw, width, width, width)
	var ac: Array[float] = [1000000.0, 1000000.0, 1000000.0, 1000000.0]
	_adapt(CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, ac, cr, height, height - ab[SIDE_BOTTOM], height - ab[SIDE_TOP])
	_adapt(CORNER_TOP_LEFT, CORNER_BOTTOM_LEFT, ac, cr, height, height - ab[SIDE_BOTTOM], height - ab[SIDE_TOP])
	_adapt(CORNER_TOP_LEFT, CORNER_TOP_RIGHT, ac, cr, width, width - ab[SIDE_RIGHT], width - ab[SIDE_LEFT])
	_adapt(CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT, ac, cr, width, width - ab[SIDE_RIGHT], width - ab[SIDE_LEFT])
	var infill := style_rect.grow_individual(-ab[SIDE_LEFT], -ab[SIDE_TOP], -ab[SIDE_RIGHT], -ab[SIDE_BOTTOM])
	var bsr := style_rect
	var aa := 1.0
	if aa_on:
		aa = f.anti_aliasing_size / oversampling
		for i in 4:
			if bw[i] > 0:
				bsr = bsr.grow_side(i, -aa)
	var detail := f.corner_detail
	if draw_border and not aa_on:
		_rrect(bsr, ac, bsr, infill, bc_inner, bc, detail, false)
	if draw_center and (not aa_on or blend_on):
		_rrect(bsr, ac, infill, infill, bg, bg, detail, true)
	if not aa_on:
		return
	var abw: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var abh: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var afw: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var afh: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		if draw_border and bw[i] > 0:
			abw[i] = aa
			abh[i] = aa * 0.5
		else:
			afw[i] = aa
			afh[i] = aa * 0.5
	if draw_center:
		var t_rect := infill.grow_individual(afh[SIDE_LEFT], afh[SIDE_TOP], afh[SIDE_RIGHT], afh[SIDE_BOTTOM])
		var c_rect := t_rect.grow_individual(-afw[SIDE_LEFT], -afw[SIDE_TOP], -afw[SIDE_RIGHT], -afw[SIDE_BOTTOM])
		if not blend_on:
			_rrect(bsr, ac, c_rect, c_rect, bg, bg, detail, true)
		if not blend_on or not draw_border:
			_rrect(bsr, ac, t_rect, c_rect, bg, Color(bg.r, bg.g, bg.b, 0), detail, false)
	if draw_border:
		var in_col := infill.grow_individual(abh[SIDE_LEFT], abh[SIDE_TOP], abh[SIDE_RIGHT], abh[SIDE_BOTTOM])
		var in_tr := in_col.grow_individual(-abw[SIDE_LEFT], -abw[SIDE_TOP], -abw[SIDE_RIGHT], -abw[SIDE_BOTTOM])
		var out_tr := style_rect.grow_individual(abh[SIDE_LEFT], abh[SIDE_TOP], abh[SIDE_RIGHT], abh[SIDE_BOTTOM])
		var out_col := bsr.grow_individual(abh[SIDE_LEFT], abh[SIDE_TOP], abh[SIDE_RIGHT], abh[SIDE_BOTTOM])
		_rrect(bsr, ac, out_col, infill if blend_on else in_col, bc_inner, bc, detail, false)
		if not blend_on:
			_rrect(bsr, ac, in_col, in_tr, bc_blend, bc, detail, false)
		_rrect(bsr, ac, out_tr, out_col, bc, bc_alpha, detail, false)


static func _adapt(ia: int, ib: int, adapted: Array[float], values: Array[float], w: float, max_a: float, max_b: float) -> void:
	var va := values[ia]
	var vb := values[ib]
	var factor := 1.0 if va + vb == 0.0 else minf(1.0, w / (va + vb))
	adapted[ia] = minf(minf(va * factor, max_a), adapted[ia])
	adapted[ib] = minf(minf(vb * factor, max_b), adapted[ib])


static func _inner_radius(style: Rect2, inner: Rect2, cr: Array[float]) -> Array[float]:
	var l := inner.position.x - style.position.x
	var t := inner.position.y - style.position.y
	var r := style.size.x - inner.size.x - l
	var b := style.size.y - inner.size.y - t
	return [maxf(cr[0] - minf(t, l), 0), maxf(cr[1] - minf(t, r), 0), maxf(cr[2] - minf(b, r), 0), maxf(cr[3] - minf(b, l), 0)]


static func _corner_scale(style: Rect2, inner: Rect2, cr: Array[float]) -> Array[Vector2]:
	var bl := inner.position.x - style.position.x
	var bt := inner.position.y - style.position.y
	var br := style.size.x - inner.size.x - bl
	var bb := style.size.y - inner.size.y - bt
	var over: Array[float] = [
		-minf(0, inner.size.y - cr[CORNER_TOP_LEFT] - cr[CORNER_BOTTOM_LEFT]),
		-minf(0, inner.size.x - cr[CORNER_TOP_LEFT] - cr[CORNER_TOP_RIGHT]),
		-minf(0, inner.size.y - cr[CORNER_TOP_RIGHT] - cr[CORNER_BOTTOM_RIGHT]),
		-minf(0, inner.size.x - cr[CORNER_BOTTOM_LEFT] - cr[CORNER_BOTTOM_RIGHT])]
	var hb := bl + br
	var vb := bt + bb
	var ratios: Array[float] = [bl / hb if hb > 0 else 0.0, bt / vb if vb > 0 else 0.0, br / hb if hb > 0 else 0.0, bb / vb if vb > 0 else 0.0]
	var red: Array[Vector2] = [
		Vector2(over[SIDE_TOP] * ratios[SIDE_LEFT], over[SIDE_LEFT] * ratios[SIDE_TOP]),
		Vector2(over[SIDE_TOP] * ratios[SIDE_RIGHT], over[SIDE_RIGHT] * ratios[SIDE_TOP]),
		Vector2(over[SIDE_BOTTOM] * ratios[SIDE_RIGHT], over[SIDE_RIGHT] * ratios[SIDE_BOTTOM]),
		Vector2(over[SIDE_BOTTOM] * ratios[SIDE_LEFT], over[SIDE_LEFT] * ratios[SIDE_BOTTOM])]
	var pcr: Array[Vector2] = [Vector2(cr[0], cr[0]), Vector2(cr[1], cr[1]), Vector2(cr[2], cr[2]), Vector2(cr[3], cr[3])]
	var left: Array[Vector2] = []
	for i in 4:
		left.append(-((pcr[i] - red[i]).min(Vector2.ZERO)))
	var dist: Array[Vector2] = [
		(pcr[0] - red[0] - left[3] - left[1]).max(Vector2.ZERO),
		(pcr[1] - red[1] - left[0] - left[2]).max(Vector2.ZERO),
		(pcr[2] - red[2] - left[1] - left[3]).max(Vector2.ZERO),
		(pcr[3] - red[3] - left[2] - left[0]).max(Vector2.ZERO)]
	var out: Array[Vector2] = []
	for i in 4:
		var unshrink := (left[(i + 1) % 4] + left[(i + 3) % 4] - dist[i]).max(Vector2.ZERO)
		var den := (pcr[i] - unshrink).max(Vector2(1.1920929e-07, 1.1920929e-07))
		out.append(dist[i] / den)
	return out


## draw_rounded_rectangle (style_box_flat.cpp): a ring between `ring` and `inner` (or, `filled`, the
## inner rounded rect itself as vertical stripes).
func _rrect(style: Rect2, cr: Array[float], ring: Rect2, inner: Rect2, inner_col: Color, outer_col: Color, detail: int, filled: bool) -> void:
	var off := points.size()
	var ad := detail if (cr[0] > 0 or cr[1] > 0 or cr[2] > 0 or cr[3] > 0) else 1
	var border := not filled
	var rcr := _inner_radius(style, ring, cr)
	var rsc := _corner_scale(style, ring, rcr)
	var outer_pts: Array[Vector2] = [
		ring.position + Vector2(rcr[0], rcr[0]) * rsc[0],
		Vector2(ring.position.x + ring.size.x - rcr[1] * rsc[1].x, ring.position.y + rcr[1] * rsc[1].y),
		ring.position + ring.size - Vector2(rcr[2], rcr[2]) * rsc[2],
		Vector2(ring.position.x + rcr[3] * rsc[3].x, ring.position.y + ring.size.y - rcr[3] * rsc[3].y)]
	var icr := _inner_radius(style, inner, cr)
	var isc := _corner_scale(style, inner, icr)
	var inner_pts: Array[Vector2] = [
		inner.position + Vector2(icr[0], icr[0]) * isc[0],
		Vector2(inner.position.x + inner.size.x - icr[1] * isc[1].x, inner.position.y + icr[1] * isc[1].y),
		inner.position + inner.size - Vector2(icr[2], icr[2]) * isc[2],
		Vector2(inner.position.x + icr[3] * isc[3].x, inner.position.y + inner.size.y - icr[3] * isc[3].y)]
	var count := (ad + 1) * (8 if border else 4)
	var vp := PackedVector2Array()
	var vc := PackedColorArray()
	vp.resize(count)
	vc.resize(count)
	for ci in 4:
		for d in ad + 1:
			var io := (ad + 1) * ci + d
			if border:
				io *= 2
			# real_t is a 32-bit float in the engine: round where the C++ stores one.
			var ang := _f((ci + d / float(ad)) * _f(PI / 2.0) + PI)
			var co := _f(cos(ang))
			var si := _f(sin(ang))
			vp[io] = Vector2(_f(_f(_f(icr[ci] * co) * isc[ci].x) + inner_pts[ci].x), _f(_f(_f(icr[ci] * si) * isc[ci].y) + inner_pts[ci].y))
			vc[io] = inner_col
			if border:
				vp[io + 1] = Vector2(_f(_f(_f(rcr[ci] * co) * rsc[ci].x) + outer_pts[ci].x), _f(_f(_f(rcr[ci] * si) * rsc[ci].y) + outer_pts[ci].y))
				vc[io + 1] = outer_col
	points.append_array(vp)
	colors.append_array(vc)
	if border:
		for i in count:
			indices.append(off + i % count)
			indices.append(off + (i + 2) % count)
			indices.append(off + (i + 1) % count)
	else:
		var stripes := count / 2 - 1
		var last := count - 1
		for i in stripes:
			indices.append_array(PackedInt32Array([off + i, off + last - i - 1, off + i + 1, off + i, off + last - i, off + last - i - 1]))
