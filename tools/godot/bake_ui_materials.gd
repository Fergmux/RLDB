extends SceneTree
## Bakes the UI surface detail textures (rldb/assets/art/materials/<name>.png) from CC0 PBR material
## scans (ambientCG, see rldb/assets/CREDITS.md). Each output is a seamless grayscale relief map
## averaging 0.5: the scan's fine colour variation (large blotches removed) plus its normal map lit
## from the upper left, so grain, creases and brush strokes read as raised. UiSurface tints it with a
## panel's own colour, which keeps the palette and adds only the texture.
##
##   godot --headless --path rldb -s ../tools/godot/bake_ui_materials.gd -- <folder with the unzipped
##       1K-JPG scans> <name>=<AssetId>[:<detail>:<relief>] ...
## e.g. leather=Leather030 wood=Wood066:1.0:0.6 metal=Metal009:1.4:0.2

## Output edge length (px).
const OUT_PX := 512
## Standard deviation of the baked relief around 0.5 (overall strength is set at draw time).
const TARGET_STD := 0.17
## Light direction in OpenGL normal-map space (x right, y up, z out): from the upper left.
const LIGHT := Vector3(-0.45, 0.55, 0.70)
## Size the relief is reduced to for its low-pass copy: features larger than ~1/HIGH_PASS_PX of the
## scan are removed, so a tiled surface shows grain and never repeating light and dark patches.
const HIGH_PASS_PX := 8
const DEST := "res://assets/art/materials/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	for spec in args.slice(1):
		var kv := String(spec).split("=")
		var parts := kv[1].split(":")
		var detail := float(parts[1]) if parts.size() > 1 else 1.0
		var relief := float(parts[2]) if parts.size() > 2 else 1.0
		_bake(src, parts[0], kv[0], detail, relief)
	quit()


func _bake(src: String, asset: String, name: String, detail: float, relief: float) -> void:
	var col := Image.load_from_file(src.path_join("%s_1K-JPG_Color.jpg" % asset))
	var nrm := Image.load_from_file(src.path_join("%s_1K-JPG_NormalGL.jpg" % asset))
	col.convert(Image.FORMAT_RGB8)
	nrm.convert(Image.FORMAT_RGB8)
	var w := col.get_width()
	var h := col.get_height()
	# Large-scale blotches: a heavily downsampled copy scaled back up (removed so tiling never shows).
	var blur := col.duplicate()
	_low_pass(blur, w, h)
	var light := LIGHT.normalized()
	var vals := PackedFloat32Array()
	vals.resize(w * h)
	var sum := 0.0
	for y in h:
		for x in w:
			var c := col.get_pixel(x, y)
			var b: Color = blur.get_pixel(x, y)
			var n := nrm.get_pixel(x, y)
			var nv := Vector3(n.r * 2.0 - 1.0, n.g * 2.0 - 1.0, n.b * 2.0 - 1.0).normalized()
			var v: float = detail * (c.get_luminance() - b.get_luminance()) + relief * nv.dot(light)
			vals[y * w + x] = v
			sum += v
	# High-pass the combined relief too (lighting gradients in the normal map are blotches as well).
	var field := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			field.set_pixel(x, y, Color(vals[y * w + x], 0, 0))
	var low := field.duplicate()
	_low_pass(low, w, h)
	sum = 0.0
	for y in h:
		for x in w:
			var hv: float = vals[y * w + x] - low.get_pixel(x, y).r
			vals[y * w + x] = hv
			sum += hv
	var mean := sum / float(w * h)
	var sq := 0.0
	for v in vals:
		sq += (v - mean) * (v - mean)
	var std := maxf(0.0001, sqrt(sq / float(w * h)))
	var out := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var g := clampf(0.5 + (vals[y * w + x] - mean) / std * TARGET_STD, 0.0, 1.0)
			out.set_pixel(x, y, Color(g, g, g))
	out.resize(OUT_PX, OUT_PX, Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path(DEST + name + ".png")
	out.save_png(path)
	print("baked %s from %s (std %.3f)" % [name, asset, std])


## Blurs `img` in place to its features larger than 1/HIGH_PASS_PX of the scan: halved step by step
## (each bilinear halving averages 2x2 texels, a true box filter) and scaled back up.
func _low_pass(img: Image, w: int, h: int) -> void:
	var sz := w
	while sz > HIGH_PASS_PX:
		sz /= 2
		img.resize(sz, sz, Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
