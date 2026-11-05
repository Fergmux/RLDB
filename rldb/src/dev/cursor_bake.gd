extends SceneTree
## Development tool (L22): rasterises the layered cursor art in `res://assets/cursors/src/<name>.svg`
## to `res://assets/cursors/<name>_<size>.png` for every CursorSkin.ART entry at every CursorSkin.SIZES.
##
##     godot --headless --path rldb -s res://src/dev/cursor_bake.gd [-- --sheet=<dir>]
##
## Each size is drawn from the SVG at 4x and box-filtered down (premultiplied), so edges are smooth
## at 32 px and crisp at 64 px. The art is shifted so its hotspot lands on a pixel centre at every
## size (CursorSkin.snap_shift / hotspot_px are the one rule both sides use). A soft drop shadow
## (and, for "lit" cursors, a warm glow) is added from the shape's own alpha, so every cursor reads
## on the dark table, a gold panel and a light card face alike. `--sheet=<dir>` also writes a
## review sheet (each cursor at 1x on several backgrounds, and 64 px at 4x).

const SRC_DIR := "res://assets/cursors/src"
const OUT_DIR := "res://assets/cursors"
## Supersampling factor of the SVG render.
const SS := 4
## Drop shadow at 32 px (scaled with the size): blur sigma, offset and opacity.
const SHADOW_SIGMA := 0.85
const SHADOW_OFFSET := Vector2(0.7, 1.4)
const SHADOW_ALPHA := 0.6


func _init() -> void:
	var sheet_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			sheet_dir = a.split("=", true, 1)[1]
	var made := {}
	for key in CursorSkin.ART.keys():
		if not FileAccess.file_exists("%s/%s.svg" % [SRC_DIR, key]):
			print("cursor_bake: no source for %s (skipped)" % key)
			continue
		for n in CursorSkin.SIZES:
			var img := bake(StringName(key), int(n))
			if img == null:
				push_error("cursor_bake: could not bake %s at %d" % [key, n])
				quit(1)
				return
			var path := "%s/%s_%d.png" % [OUT_DIR, key, n]
			img.save_png(ProjectSettings.globalize_path(path))
			made["%s_%d" % [key, n]] = img
	print("cursor_bake: wrote %d images" % made.size())
	if sheet_dir != "":
		DirAccess.make_dir_recursive_absolute(sheet_dir)
		review_sheet(made).save_png(sheet_dir.path_join("cursor_sheet.png"))
		print("cursor_bake: sheet in ", sheet_dir)
	quit(0)


## The cursor `key` rasterised at `n` px (square), with its shadow and glow; null if the SVG is missing.
static func bake(key: StringName, n: int) -> Image:
	var path := "%s/%s.svg" % [SRC_DIR, key]
	if not FileAccess.file_exists(path):
		return null
	var svg := FileAccess.get_file_as_string(path)
	var shift := CursorSkin.snap_shift(CursorSkin.hotspot_units(key), n)
	svg = svg.replace('viewBox="0 0 64 64"', 'viewBox="%.4f %.4f 64 64"' % [-shift.x, -shift.y])
	var big := Image.new()
	if big.load_svg_from_string(svg, float(n * SS) / 64.0) != OK:
		return null
	if big.get_width() != n * SS:
		big.resize(n * SS, n * SS, Image.INTERPOLATE_BILINEAR)
	big.convert(Image.FORMAT_RGBA8)
	var body := _downsample(big, n)
	var k := float(n) / 32.0
	var layers: Array = []
	var glow: Color = CursorSkin.ART[key].get("glow", Color(0, 0, 0, 0))
	if glow.a > 0.0:
		layers.append(_shadow(body, n, 2.4 * k, Vector2.ZERO, glow))
	layers.append(_shadow(body, n, SHADOW_SIGMA * k, SHADOW_OFFSET * k, Color(0.02, 0.012, 0.0, SHADOW_ALPHA)))
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for l in layers:
		_over(out, l)
	_over(out, body)
	return out


## Premultiplied box filter from the SS-times render to n x n.
static func _downsample(big: Image, n: int) -> Image:
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var inv := 1.0 / float(SS * SS)
	for y in n:
		for x in n:
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var a := 0.0
			for sy in SS:
				for sx in SS:
					var c := big.get_pixel(x * SS + sx, y * SS + sy)
					r += c.r * c.a
					g += c.g * c.a
					b += c.b * c.a
					a += c.a
			if a <= 0.0001:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				out.set_pixel(x, y, Color(r / a, g / a, b / a, a * inv))
	return out


## A blurred copy of `src`'s alpha in colour `col` (its alpha scales the opacity), moved by `off` px.
static func _shadow(src: Image, n: int, sigma: float, off: Vector2, col: Color) -> Image:
	var a := PackedFloat32Array()
	a.resize(n * n)
	for y in n:
		for x in n:
			# Sample the source at the offset position (bilinear) so sub-pixel offsets stay smooth.
			var sx := float(x) - off.x
			var sy := float(y) - off.y
			a[y * n + x] = _alpha_at(src, n, sx, sy)
	a = _blur(a, n, sigma)
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			out.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a[y * n + x] * col.a, 0.0, 1.0)))
	return out


static func _alpha_at(src: Image, n: int, x: float, y: float) -> float:
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var s := 0.0
	for j in 2:
		for i in 2:
			var px := x0 + i
			var py := y0 + j
			if px < 0 or py < 0 or px >= n or py >= n:
				continue
			var w := (fx if i == 1 else 1.0 - fx) * (fy if j == 1 else 1.0 - fy)
			s += src.get_pixel(px, py).a * w
	return s


## Separable Gaussian blur of an n x n field.
static func _blur(f: PackedFloat32Array, n: int, sigma: float) -> PackedFloat32Array:
	var r := int(ceil(sigma * 3.0))
	var ker := PackedFloat32Array()
	var tot := 0.0
	for i in range(-r, r + 1):
		var w := exp(-float(i * i) / (2.0 * sigma * sigma))
		ker.append(w)
		tot += w
	for i in ker.size():
		ker[i] /= tot
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	for y in n:
		for x in n:
			var s := 0.0
			for i in range(-r, r + 1):
				var xx := x + i
				if xx >= 0 and xx < n:
					s += f[y * n + xx] * ker[i + r]
			tmp[y * n + x] = s
	var out := PackedFloat32Array()
	out.resize(n * n)
	for y in n:
		for x in n:
			var s := 0.0
			for i in range(-r, r + 1):
				var yy := y + i
				if yy >= 0 and yy < n:
					s += tmp[yy * n + x] * ker[i + r]
			out[y * n + x] = s
	return out


## Composites `top` over `dst` in place (straight alpha).
static func _over(dst: Image, top: Image) -> void:
	for y in dst.get_height():
		for x in dst.get_width():
			var t := top.get_pixel(x, y)
			if t.a <= 0.0:
				continue
			var d := dst.get_pixel(x, y)
			var a := t.a + d.a * (1.0 - t.a)
			if a <= 0.0:
				continue
			var c := Color(
				(t.r * t.a + d.r * d.a * (1.0 - t.a)) / a,
				(t.g * t.a + d.g * d.a * (1.0 - t.a)) / a,
				(t.b * t.a + d.b * d.a * (1.0 - t.a)) / a, a)
			dst.set_pixel(x, y, c)


## Review sheet: one row per cursor; each size at 1x on the table, a gold panel, a light card face
## and mid grey, then the 64 px image at 4x and the 32 px image at 8x (nearest), hotspots marked.
static func review_sheet(made: Dictionary) -> Image:
	var bgs := [Color("2a1d14"), Color("d4a64a"), Color("ece4d2"), Color("6a6a6a")]
	var table := Image.new()
	var tex := load("res://assets/art/tables/table_ruins.jpg") as Texture2D
	if tex != null:
		table = tex.get_image()
		table.convert(Image.FORMAT_RGBA8)
	var keys := CursorSkin.ART.keys().filter(func(k): return made.has("%s_32" % k))
	var cell := 96
	var zoom := 4
	var w := 16 + (bgs.size() + 1) * (cell * CursorSkin.SIZES.size() + 8) + (64 * zoom + 16) * 2
	var row_h := maxi(64 * zoom, cell) + 16
	var sheet := Image.create(w, 16 + keys.size() * row_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("141110"))
	for r in keys.size():
		var key: String = keys[r]
		var y0 := 16 + r * row_h
		var x := 16
		for bi in bgs.size() + 1:
			for si in CursorSkin.SIZES.size():
				var n: int = CursorSkin.SIZES[si]
				var rect := Rect2i(x + si * cell, y0, cell, cell)
				if bi == 0 and not table.is_empty():
					var src := Rect2i(1200 + r * 60 + si * 100, 900, cell, cell)
					sheet.blit_rect(table, src, rect.position)
				else:
					sheet.fill_rect(rect, bgs[bi - 1 if bi > 0 else 0])
				var img: Image = made["%s_%d" % [key, n]]
				sheet.blend_rect(img, Rect2i(0, 0, n, n), rect.position + Vector2i((cell - n) / 2, (cell - n) / 2))
			x += cell * CursorSkin.SIZES.size() + 8
		# Pixel views: 64 px at 4x and 32 px at 8x, the hotspot pixel marked in cyan.
		for n in [64, 32]:
			var z: int = 64 * zoom / int(n)
			var big: Image = (made["%s_%d" % [key, n]] as Image).duplicate()
			big.resize(64 * zoom, 64 * zoom, Image.INTERPOLATE_NEAREST)
			var zr := Rect2i(x, y0, 64 * zoom, 64 * zoom)
			sheet.fill_rect(zr, Color("3a3430"))
			sheet.blend_rect(big, Rect2i(0, 0, 64 * zoom, 64 * zoom), zr.position)
			var h := CursorSkin.hotspot_px(CursorSkin.hotspot_units(StringName(key)), n)
			sheet.fill_rect(Rect2i(zr.position + h * z, Vector2i(z, z) / 2), Color(0, 1, 1, 0.9))
			x += 64 * zoom + 16
	return sheet
