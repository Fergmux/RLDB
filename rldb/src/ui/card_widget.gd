class_name CardWidget
extends Control
## Procedurally drawn card (art bible section 4): layered frame, art window (card art or
## a placeholder), name plate, cost gem (shape per cost kind), ATK/DEF shields, status
## chips and a face-down back. Everything is drawn from the redacted card view, so hidden
## cards can only ever show the back. Runtime stats are never baked into art.
##
## Kinds: "board" (128x128 unit), "power" (85x128), "trap" (128x85), "hand" (128x180),
## "mini" (96x135), "big" (240x336), "back" (64x90). Geometry is authored in base units and
## scaled by size/base, so a widget resized by a container still draws proportionally.

signal pressed(widget: CardWidget)
signal right_pressed(widget: CardWidget)

const SIZES := {
	"board": Vector2(128, 128), "power": Vector2(85, 128), "trap": Vector2(128, 85),
	"hand": Vector2(128, 180), "mini": Vector2(96, 135), "big": Vector2(240, 336), "back": Vector2(64, 90),
}
const ART_DIR := "res://art/cards/"
const UNIT_CATS := ["basic_unit", "unit", "fusion", "ritual", "arcane"]

static var _tex_cache := {}
static var _radial_cache := {}

var view: Dictionary = {}
var size_kind: String = "board"
var highlighted: bool = false
var selected: bool = false
var dimmed: bool = false
var empty_text: String = ""
## Show the slot label on an empty zone even when not a target (first-turn hint).
var show_label: bool = false
## Self-managed hover glow (deck builder lists). GameScreen turns this off and manages hover.
var auto_hover: bool = true
## Native tooltip with name and rules text (off on the match board, where details live in the sidebar).
var show_tooltip: bool = true
var hovered: bool = false: set = _set_hovered
var fx_flash: float = 0.0: set = _set_flash
var fx_glow: Color = Color(1, 1, 1, 0): set = _set_glow

var _s: float = 1.0
var _para_cache := {}
var _self_hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func(): _self_hover = auto_hover; queue_redraw())
	mouse_exited.connect(func(): _self_hover = false; queue_redraw())


func setup(v, kind: String = "board", empty_label: String = "") -> CardWidget:
	view = v if v != null else {}
	size_kind = kind
	empty_text = empty_label
	custom_minimum_size = SIZES[kind]
	size = SIZES[kind]
	pivot_offset = size / 2.0
	_para_cache.clear()
	if view.is_empty() or view.get("hidden", false) or not show_tooltip:
		tooltip_text = ""
	else:
		tooltip_text = "%s\n%s" % [view["name"], view.get("text", "")]
	queue_redraw()
	return self


func set_marks(is_target: bool, is_selected: bool, is_dimmed: bool = false) -> void:
	highlighted = is_target
	selected = is_selected
	dimmed = is_dimmed
	self_modulate = Color(1, 1, 1, 0.72) if dimmed else Color.WHITE
	set_process(highlighted and not UIStyle.reduce_motion)
	queue_redraw()


func _set_hovered(v: bool) -> void:
	hovered = v
	queue_redraw()


func _set_flash(v: float) -> void:
	fx_flash = v
	queue_redraw()


func _set_glow(v: Color) -> void:
	fx_glow = v
	queue_redraw()


func _process(_d: float) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		_para_cache.clear()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_pressed.emit(self)
			accept_event()


# ---------------------------------------------------------------- drawing helpers (scaled)

func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * _s, y * _s, w * _s, h * _s)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * _s, y * _s)


func _fs(n: float) -> int:
	return maxi(6, roundi(n * _s))


func _base() -> Vector2:
	return SIZES["hand"] if size_kind == "mini" else SIZES[size_kind]


func _text_at(font: Font, text: String, pos_top_left: Vector2, fs: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT, line_h: float = 0.0) -> void:
	var h := line_h if line_h > 0.0 else float(fs) * 1.1
	var base_y := pos_top_left.y + h / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_string(font, Vector2(pos_top_left.x, base_y), text, align, width, fs, col)


func _text_c(font: Font, text: String, centre: Vector2, fs: int, col: Color, outline: float = 0.0) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(centre.x - sz.x / 2.0, centre.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	if outline > 0.0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(ceil(outline)), Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _para(text: String, font: Font, tag: String, fs: int, width: float, max_lines: int) -> TextParagraph:
	var key := "%s|%s|%d|%d|%d" % [text, tag, fs, int(width), max_lines]
	if _para_cache.has(key):
		return _para_cache[key]
	var tp := TextParagraph.new()
	tp.width = width
	tp.max_lines_visible = max_lines
	tp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tp.add_string(text, font, fs)
	_para_cache[key] = tp
	return tp


func _ring(col: Color, width: float, rect: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(maxi(1, roundi(width)))
	sb.set_corner_radius_all(maxi(1, roundi(radius)))
	draw_style_box(sb, rect)


func _round_rect(rect: Rect2, fill: Color, radius: float, border: Color = Color.TRANSPARENT, bw: float = 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	if bw > 0.0:
		sb.set_border_width_all(maxi(1, roundi(bw)))
	sb.set_corner_radius_all(maxi(1, roundi(radius)))
	draw_style_box(sb, rect)


func _vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


# ---------------------------------------------------------------- main draw

func _draw() -> void:
	var base := _base()
	_s = maxf(0.2, minf(size.x / base.x, size.y / base.y))
	if view.is_empty():
		_draw_empty()
	elif view.get("hidden", false):
		_draw_back()
	else:
		match size_kind:
			"power": _draw_power()
			"trap": _draw_trap()
			"back": _draw_back()
			"hand", "mini": _draw_tall(false)
			"big": _draw_tall(true)
			_: _draw_square()
	_draw_overlays()


func _accent() -> Color:
	return UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), UIStyle.BRONZE)


func _frame(radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1a18")
	sb.border_color = _accent()
	sb.set_border_width_all(maxi(2, roundi(3.0 * _s)))
	sb.set_corner_radius_all(roundi(radius * _s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi((14.0 if (hovered or _self_hover) else 7.0) * _s)
	sb.shadow_offset = Vector2(0, 3.0 * _s)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var inset := 3.0 * _s
	_vgrad(Rect2(inset, inset, size.x - 2 * inset, size.y - 2 * inset), Color(_accent().darkened(0.7), 0.45), Color(0, 0, 0, 0.45))
	draw_line(Vector2(radius * _s, 3.5 * _s), Vector2(size.x - radius * _s, 3.5 * _s), Color(UIStyle.GOLD_HI, 0.4), 1.0)


func _art_texture() -> Texture2D:
	var img: String = String(view.get("art", {}).get("image", ""))
	if img == "":
		return null
	var path := ART_DIR + img
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


func _radial_tex(col: Color) -> Texture2D:
	var key := col.to_html()
	if _radial_cache.has(key):
		return _radial_cache[key]
	var g := Gradient.new()
	g.set_color(0, col.lightened(0.05))
	g.set_color(1, col.darkened(0.72))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(1.0, 0.45)
	t.width = 64
	t.height = 64
	_radial_cache[key] = t
	return t


func _glyph_kind() -> String:
	match String(view.get("category", "")):
		"spell": return "star"
		"trap": return "eye"
		"power": return "crown"
	return "sword"


func _draw_art(rect: Rect2) -> void:
	var tex := _art_texture()
	if tex != null:
		var ts := tex.get_size()
		var ra := rect.size.x / rect.size.y
		var src: Rect2
		if ts.x / ts.y > ra:
			var w := ts.y * ra
			src = Rect2((ts.x - w) / 2.0, 0, w, ts.y)
		else:
			var h := ts.x / ra
			src = Rect2(0, (ts.y - h) / 2.0, ts.x, h)
		draw_texture_rect_region(tex, rect, src)
	else:
		var base: Color = UIStyle.type_color(view.get("type", "")) if view.has("type") and view.get("race") != null else UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), UIStyle.BRONZE)
		draw_texture_rect(_radial_tex(base), rect, false)
		_draw_glyph(_glyph_kind(), rect.get_center(), minf(rect.size.x, rect.size.y) * 0.34, Color(1, 1, 1, 0.25))
	# inner shadow strip + defence tint + bronze border
	var sh := 7.0 * _s
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + sh), Vector2(rect.position.x, rect.position.y + sh)]),
		PackedColorArray([Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	if view.get("zone", "") == "unit" and view.get("stance", "atk") == "def":
		draw_rect(rect, Color(0.3, 0.42, 0.62, 0.28))
	draw_rect(rect, Color(UIStyle.BRONZE, 0.95), false, maxf(1.0, 2.0 * _s))


func _draw_glyph(kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.5, 0.12 * r)
	match kind:
		"sword":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.55), col, w * 1.3)
			draw_line(c + Vector2(-r * 0.5, r * 0.05), c + Vector2(r * 0.5, r * 0.05), col, w)
			draw_circle(c + Vector2(0, r * 0.75), r * 0.14, col)
		"star":
			var pts := PackedVector2Array()
			for i in 16:
				var a := -PI / 2.0 + float(i) * TAU / 16.0
				var rr := r if i % 2 == 0 else r * 0.42
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)
		"eye":
			var top := PackedVector2Array()
			for i in 13:
				var x := lerpf(-1.0, 1.0, float(i) / 12.0)
				top.append(c + Vector2(x * r, -0.5 * r * (1.0 - x * x)))
			var lens := PackedVector2Array(top)
			for i in range(12, -1, -1):
				var x := lerpf(-1.0, 1.0, float(i) / 12.0)
				lens.append(c + Vector2(x * r, 0.5 * r * (1.0 - x * x)))
			draw_colored_polygon(lens, col)
			draw_circle(c, r * 0.26, Color(0, 0, 0, col.a * 1.2))
		"crown":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), col)
			draw_circle(c, r * 0.3, Color(0, 0, 0, col.a * 1.2))


# ---------------------------------------------------------------- shared card parts

func _fit_name(text: String, width: float, fs_max: float, fs_min: float, font: Font) -> int:
	var fs := roundi(fs_max * _s)
	var lo := maxi(6, roundi(fs_min * _s))
	while fs > lo and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


func _name_plate(rect: Rect2, fs_max: float, reserve_l: float, reserve_r: float) -> void:
	_round_rect(rect, Color(0.102, 0.086, 0.075, 0.94), 4.0 * _s, Color(UIStyle.GOLD, 0.65), maxf(1.0, _s))
	var acc := _accent()
	draw_rect(Rect2(rect.position.x + 3 * _s, rect.end.y - 3.0 * _s, rect.size.x - 6 * _s, 2.0 * _s), acc)
	var font := UIStyle.font_display(600)
	var avail := rect.size.x - (reserve_l + reserve_r) * _s - 6.0 * _s
	var nm: String = view["name"]
	var fs := _fit_name(nm, avail, fs_max, 9.0, font)
	var shown := nm
	if font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		while shown.length() > 3 and font.get_string_size(shown + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
			shown = shown.substr(0, shown.length() - 1)
		shown += "…"
	_text_at(font, shown, Vector2(rect.position.x + (reserve_l + 3.0) * _s, rect.position.y), fs, UIStyle.TEXT, -1.0, HORIZONTAL_ALIGNMENT_LEFT, rect.size.y - 3.0 * _s)


func _cost_text() -> String:
	match String(view.get("cost_kind", "ap")):
		"fusion": return "F"
		"ritual", "arcane":
			var pc = view.get("printed_cost")
			return "?" if pc == null else str(pc)
	var c = view.get("cost")
	return "?" if c == null else str(c)


func _cost_color() -> Color:
	if String(view.get("cost_kind", "ap")) == "ap":
		var c = view.get("cost")
		var pc = view.get("printed_cost")
		if c != null and pc != null:
			if c < pc:
				return Color("0d5a24")
			if c > pc:
				return Color("8a1a14")
		return UIStyle.ON_GOLD
	return Color.WHITE


func _gem(c: Vector2, r: float, fs: int) -> void:
	var kind := String(view.get("cost_kind", "ap"))
	var col: Color = UIStyle.COST_COLORS.get(kind, UIStyle.COST_COLORS["ap"])
	var dark := col.darkened(0.7)
	var bw := maxf(1.5, 2.0 * _s)
	match kind:
		"ritual":
			var rr := r * 1.22
			draw_colored_polygon(_poly(c, rr, 4, PI / 4.0), dark)
			draw_colored_polygon(_poly(c, rr - bw * 1.3, 4, PI / 4.0), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -(rr - bw * 1.3)), c + Vector2(rr - bw * 1.3, 0), c + Vector2(0, 0), c + Vector2(-(rr - bw * 1.3), 0)]), col.lightened(0.25))
		"arcane":
			var rh := r * 1.08
			draw_colored_polygon(_poly(c, rh, 6, 0.0), dark)
			draw_colored_polygon(_poly(c, rh - bw, 6, 0.0), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-(rh - bw), 0), c + Vector2(-(rh - bw) / 2.0, -(rh - bw) * 0.866), c + Vector2((rh - bw) / 2.0, -(rh - bw) * 0.866), c + Vector2(rh - bw, 0)]), col.lightened(0.25))
		"fusion":
			draw_circle(c, r, dark)
			draw_circle(c, r - bw, col)
			draw_arc(c, r * 0.68, 0.0, TAU, 28, dark, maxf(1.0, 1.5 * _s))
			draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.25))
		_:
			draw_circle(c, r, dark)
			draw_circle(c, r - bw, col)
			draw_circle(c + Vector2(-r * 0.22, -r * 0.3), r * 0.38, Color(1, 1, 1, 0.28))
	var txt := _cost_text()
	var tc := _cost_color()
	_text_c(UIStyle.font_display(700), txt, c + Vector2(0, 0.5 * _s), fs, tc, 0.0 if tc == UIStyle.ON_GOLD else 1.5)


func _poly(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + float(i) * TAU / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _shield_pts(rect: Rect2) -> PackedVector2Array:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		Vector2(x + 0.08 * w, y), Vector2(x + 0.92 * w, y), Vector2(x + w, y + 0.12 * h), Vector2(x + w, y + 0.56 * h),
		Vector2(x + 0.5 * w, y + h), Vector2(x, y + 0.56 * h), Vector2(x, y + 0.12 * h)])


func _shield(rect: Rect2, is_atk: bool, value, printed, fs: int) -> void:
	var top := Color("a8392e") if is_atk else Color("3f7ab5")
	var bot := Color("5a1c17") if is_atk else Color("1b3a5a")
	draw_colored_polygon(_shield_pts(rect), Color(UIStyle.GOLD, 0.95))
	var inner := Rect2(rect.position + Vector2(1.8, 1.8) * _s, rect.size - Vector2(3.6, 3.6) * _s)
	var pts := _shield_pts(inner)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, clampf((p.y - inner.position.y) / inner.size.y, 0.0, 1.0)))
	draw_polygon(pts, cols)
	var col := Color.WHITE
	var mod := 0
	if value != null and printed != null and view.get("zone", "") == "unit":
		if value > printed:
			col = UIStyle.GOOD
			mod = 1
		elif value < printed:
			col = Color("ff8a84")
			mod = -1
	var txt := "?" if value == null else str(value)
	_text_c(UIStyle.font_display(700), txt, rect.get_center() + Vector2(0, -rect.size.y * 0.04), fs, col, maxf(1.5, 1.8 * _s))
	if mod != 0:
		var ac := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.1)
		var a := 3.2 * _s
		if mod > 0:
			draw_colored_polygon(PackedVector2Array([ac + Vector2(0, -a), ac + Vector2(a, a * 0.8), ac + Vector2(-a, a * 0.8)]), UIStyle.GOOD)
		else:
			ac.y += rect.size.y * 0.82
			draw_colored_polygon(PackedVector2Array([ac + Vector2(0, a), ac + Vector2(a, -a * 0.8), ac + Vector2(-a, -a * 0.8)]), Color("ff8a84"))


func _status_list() -> Array:
	var out := []
	if view.get("runes", 0) > 0:
		out.append({"t": "RN%d" % view["runes"], "c": UIStyle.RUNE_BLUE})
	for s in CardDB.STATUS_ORDER:
		var n: int = view.get("statuses", {}).get(s, 0)
		if n > 0:
			out.append({"t": "%s%d" % [UIStyle.STATUS_SHORT[s], n], "c": Color("6fd38a") if CardDB.is_buff(s) else Color("e8605a")})
	return out


func _chips(x0: float, x1: float, y: float, h: float, fs_base: float) -> void:
	var list := _status_list()
	if list.is_empty():
		return
	var font := UIStyle.font_bold()
	var fs := _fs(fs_base)
	var x := x0 * _s
	var xmax := x1 * _s
	var shown := 0
	for i in list.size():
		var e: Dictionary = list[i]
		var w := font.get_string_size(e["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * _s
		var remaining := list.size() - i - 1
		var reserve := (font.get_string_size("+%d" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * _s) if remaining > 0 else 0.0
		if x + w + reserve > xmax and i > 0 or shown >= 3:
			var more := list.size() - i
			_chip_draw(x, y * _s, font.get_string_size("+%d" % more, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * _s, h * _s, "+%d" % more, UIStyle.MUTED, font, fs)
			return
		_chip_draw(x, y * _s, w, h * _s, e["t"], e["c"], font, fs)
		x += w + 2.0 * _s
		shown += 1


func _chip_draw(x: float, y: float, w: float, h: float, text: String, col: Color, font: Font, fs: int) -> void:
	_round_rect(Rect2(x, y, w, h), Color(col.darkened(0.7), 0.95), h / 2.0, col, maxf(1.0, _s))
	_text_c(font, text, Vector2(x + w / 2.0, y + h / 2.0), fs, col.lightened(0.45))


func _stance_tab(rect: Rect2) -> void:
	if view.get("zone", "") != "unit":
		return
	var atk: bool = view.get("stance", "atk") == "atk"
	var fill := Color("8a2f26") if atk else Color("2f5f8f")
	var edge := Color("e0a040") if atk else Color("b8c4d4")
	_round_rect(rect, fill, 3.0 * _s, edge, maxf(1.0, _s))
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.34
	if atk:
		draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color.WHITE, maxf(1.0, 1.3 * _s))
		draw_line(c + Vector2(r, -r), c + Vector2(-r, r), Color.WHITE, maxf(1.0, 1.3 * _s))
	else:
		draw_colored_polygon(_shield_pts(Rect2(c - Vector2(r * 0.9, r), Vector2(r * 1.8, r * 2.1))), Color("dfe7f2"))


func _protected_icon(c: Vector2, r: float) -> void:
	if view.get("zone", "") == "unit" and view.get("protected", false):
		draw_colored_polygon(_shield_pts(Rect2(c - Vector2(r * 0.8, r), Vector2(r * 1.6, r * 2.0))), Color(0.85, 0.92, 1.0, 0.92))
		draw_polyline(PackedVector2Array(_shield_pts(Rect2(c - Vector2(r * 0.8, r), Vector2(r * 1.6, r * 2.0)))), Color(0.1, 0.2, 0.4), maxf(1.0, _s))


func _type_pip(c: Vector2, r: float) -> void:
	if not view.has("type") or view.get("type", "") == "":
		return
	var col := UIStyle.type_color(view["type"])
	draw_colored_polygon(_poly(c, r * 1.25, 4, PI / 4.0), Color(0, 0, 0, 0.6))
	draw_colored_polygon(_poly(c, r, 4, PI / 4.0), col)


func _acted_marks(corner: Vector2) -> void:
	if view.get("zone", "") == "unit" and view.get("attacked", false):
		draw_circle(corner, 3.2 * _s, Color("9a9a9a"))
		draw_circle(corner, 3.2 * _s, Color(0, 0, 0, 0.6), false, maxf(1.0, _s))


func _set_ribbon(rect: Rect2) -> void:
	if view.get("zone", "") == "backrow" and not view.get("face_up", true):
		_round_rect(rect, Color(0.1, 0.08, 0.2, 0.92), rect.size.y / 2.0, Color("b9a7e6"), maxf(1.0, _s))
		_text_c(UIStyle.font_bold(), "SET", rect.get_center(), _fs(9), Color("d7c9ff"))


# ---------------------------------------------------------------- layouts

func _draw_square() -> void:
	_frame(6.0)
	_draw_art(_r(5, 5, 118, 66))
	_type_pip(_p(114, 14), 4.0 * _s)
	_protected_icon(_p(112, 30), 6.0 * _s)
	_name_plate(_r(5, 60, 118, 18), 12.0, 14.0 if String(view.get("category", "")) in UNIT_CATS and view.get("zone", "") == "unit" else 0.0, 20.0 if view.get("zone", "") == "unit" and view.has("stance") else 0.0)
	_stance_tab(_r(103, 62, 18, 14))
	var is_unit: bool = String(view.get("category", "")) in UNIT_CATS
	_chips(36, 92, 83, 13, 9.0)
	if is_unit:
		_shield(_r(2, 90, 31, 36), true, view.get("atk"), view.get("printed_atk"), _fs(18))
		_shield(_r(95, 90, 31, 36), false, view.get("def"), view.get("printed_def"), _fs(18))
	_gem(_p(14, 14), 11.0 * _s, _fs(14))
	_acted_marks(_p(120, 8))
	_set_ribbon(_r(40, 99, 48, 14))


func _draw_power() -> void:
	_frame(6.0)
	_draw_art(_r(4, 4, 77, 56))
	_name_plate(_r(4, 50, 77, 20), 11.0, 0.0, 0.0)
	_gem(_p(14, 14), 10.0 * _s, _fs(13))
	var font := UIStyle.font_body()
	var fs := _fs(9.5)
	var txt: String = view.get("text", "")
	if txt != "":
		var tp := _para(txt, font, "b", fs, 77.0 * _s, 3)
		tp.draw(get_canvas_item(), _p(4, 74), Color(UIStyle.TEXT, 0.9))
	_chips(4, 81, 111, 12, 9.0)


func _draw_trap() -> void:
	_frame(6.0)
	_draw_art(_r(4, 4, 54, 77))
	_gem(_p(14, 14), 10.0 * _s, _fs(13))
	var font := UIStyle.font_display(600)
	var nm: String = view["name"]
	var fs := _fs(11)
	var tp := _para(nm, font, "d6", fs, 62.0 * _s, 3)
	tp.draw_outline(get_canvas_item(), _p(62, 8), 2, Color(0, 0, 0, 0.5))
	tp.draw(get_canvas_item(), _p(62, 8), UIStyle.TEXT)
	var cat: String = UIStyle.CATEGORY_NAMES.get(view.get("category", "trap"), "")
	draw_rect(_r(62, 56, 62, 2), _accent())
	_text_at(UIStyle.font_italic(), cat, _p(62, 60), _fs(10), UIStyle.MUTED, 62.0 * _s, HORIZONTAL_ALIGNMENT_LEFT, 12.0 * _s)
	_chips(62, 124, 70, 11, 8.5)
	_set_ribbon(_r(8, 66, 46, 13))


func _draw_tall(big: bool) -> void:
	var is_unit: bool = String(view.get("category", "")) in UNIT_CATS
	var g := {}
	if big:
		g = {"art": [10, 10, 220, 140], "plate": [10, 128, 220, 34], "line": 166.0, "text": [12, 190, 216, 70 if is_unit else 128],
			"chip_y": 262.0, "chip_x": [66.0, 174.0], "atk": [6, 272, 52, 58], "def": [182, 272, 52, 58], "gem": [26, 26, 20],
			"f_name": 20.0, "f_line": 13.0, "f_text": 15.0, "f_chip": 12.0, "f_stat": 32.0, "f_gem": 24.0, "chip_h": 17.0, "chip_y_nu": 306.0}
	else:
		g = {"art": [6, 6, 116, 88], "plate": [6, 82, 116, 22], "line": 106.0, "text": [6, 119, 116, 28 if is_unit else 52],
			"chip_y": 148.0, "chip_x": [38.0, 90.0], "atk": [3, 142, 34, 38], "def": [91, 142, 34, 38], "gem": [15, 15, 14],
			"f_name": 13.0, "f_line": 10.0, "f_text": 11.0, "f_chip": 9.0, "f_stat": 20.0, "f_gem": 16.0, "chip_h": 14.0, "chip_y_nu": 162.0}
	_frame(8.0)
	var a: Array = g["art"]
	_draw_art(_r(a[0], a[1], a[2], a[3]))
	_type_pip(_p(a[0] + a[2] - 9, a[1] + 9), 4.0 * _s if not big else 6.0 * _s)
	_protected_icon(_p(a[0] + a[2] - 10, a[1] + 28), 7.0 * _s)
	var pl: Array = g["plate"]
	var has_tab: bool = view.get("zone", "") == "unit" and view.has("stance")
	_name_plate(_r(pl[0], pl[1], pl[2], pl[3]), g["f_name"], 20.0 if not big else 30.0, 24.0 if has_tab else 0.0)
	if has_tab:
		_stance_tab(_r(pl[0] + pl[2] - 22, pl[1] + 3, 18, pl[3] - 6))
	# Type / race line.
	var line_fs := _fs(g["f_line"])
	var ly: float = g["line"]
	var lx: float = float(pl[0]) + 4.0
	if is_unit:
		var race: String = view.get("race", "")
		var typ: String = view.get("type", "")
		var col := UIStyle.type_color(typ)
		draw_rect(_r(lx, ly + 3, 8 if not big else 11, 8 if not big else 11), col)
		_text_at(UIStyle.font_italic(), "%s · %s" % [race if race != "" else "No race", typ if typ != "" else "No type"], _p(lx + (11 if not big else 15), ly), line_fs, UIStyle.MUTED, -1.0, HORIZONTAL_ALIGNMENT_LEFT, float(g["f_line"] + 3) * _s)
	else:
		draw_rect(_r(lx, ly + 3, 8 if not big else 11, 8 if not big else 11), _accent())
		_text_at(UIStyle.font_italic(), UIStyle.CATEGORY_NAMES.get(view.get("category", ""), ""), _p(lx + (11 if not big else 15), ly), line_fs, UIStyle.MUTED, -1.0, HORIZONTAL_ALIGNMENT_LEFT, float(g["f_line"] + 3) * _s)
	# Rules text well.
	var t: Array = g["text"]
	var rules: String = view.get("text", "")
	if view.get("support", "full") == "unimplemented":
		rules = "[Effect not implemented] " + rules
	_round_rect(_r(t[0], t[1], t[2], t[3]), Color(0.847, 0.8, 0.69, 0.08), 3.0 * _s)
	var tfs := _fs(g["f_text"])
	var lines := maxi(1, int(float(t[3]) / (float(g["f_text"]) * 1.18)))
	if rules != "":
		var tp := _para(rules, UIStyle.font_body(), "b", tfs, (float(t[2]) - 8.0) * _s, lines)
		tp.draw(get_canvas_item(), _p(t[0] + 4, t[1] + 2), UIStyle.TEXT)
	# Chips + shields + gem.
	if is_unit:
		var at: Array = g["atk"]
		var df: Array = g["def"]
		_chips(g["chip_x"][0], g["chip_x"][1], g["chip_y"], g["chip_h"], g["f_chip"])
		_shield(_r(at[0], at[1], at[2], at[3]), true, view.get("atk"), view.get("printed_atk"), _fs(g["f_stat"]))
		_shield(_r(df[0], df[1], df[2], df[3]), false, view.get("def"), view.get("printed_def"), _fs(g["f_stat"]))
	else:
		_chips(8, 120 if not big else 230, g["chip_y_nu"], g["chip_h"], g["f_chip"])
	var gm: Array = g["gem"]
	_gem(_p(gm[0], gm[1]), float(gm[2]) * _s, _fs(g["f_gem"]))
	_set_ribbon(_r(pl[0] + pl[2] - 52, pl[1] - 18 if not big else pl[1] - 24, 44, 14))


func _draw_empty() -> void:
	var role := "unit"
	match size_kind:
		"trap": role = "trap"
		"power": role = "power"
	var tint: Color = UIStyle.ZONE_TINT[role]
	var r := Rect2(Vector2.ZERO, size)
	var rad := 8.0 * _s
	var fill := Color(tint, 0.62)
	if highlighted:
		fill = Color(tint.lightened(0.25), 0.85)
	_round_rect(r, fill, rad, Color(UIStyle.BRONZE, 0.55), maxf(1.0, _s))
	_vgrad(Rect2(2 * _s, 2 * _s, size.x - 4 * _s, 12 * _s), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	_draw_glyph({"unit": "sword", "trap": "eye", "power": "crown"}[role], r.get_center(), minf(size.x, size.y) * 0.22, Color(1, 1, 1, 0.09))
	if empty_text != "" and (highlighted or show_label):
		_text_c(UIStyle.font_body(), empty_text, Vector2(size.x / 2.0, size.y - 12.0 * _s), _fs(12), Color(UIStyle.TEXT, 0.55))


func _draw_back() -> void:
	var rad := 8.0 if size_kind in ["hand", "big", "mini", "back"] else 6.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1630")
	sb.border_color = UIStyle.GOLD
	sb.set_border_width_all(maxi(2, roundi(3.0 * _s)))
	sb.set_corner_radius_all(roundi(rad * _s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi(6.0 * _s)
	sb.shadow_offset = Vector2(0, 3.0 * _s)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var inset := 6.0 * _s
	var inner := Rect2(inset, inset, size.x - 2 * inset, size.y - 2 * inset)
	_vgrad(inner, Color("2a2050"), Color("120c22"))
	draw_rect(inner, Color(UIStyle.GOLD, 0.35), false, maxf(1.0, _s))
	var c := size / 2.0
	var r := minf(inner.size.x, inner.size.y) * 0.34
	var gold := Color(UIStyle.GOLD, 0.7)
	var w := maxf(1.0, 1.4 * _s)
	var sq0 := _poly(c, r * 1.2, 4, PI / 4.0)
	var sq1 := _poly(c, r * 1.2, 4, 0.0)
	sq0.append(sq0[0])
	sq1.append(sq1[0])
	draw_polyline(sq0, gold, w)
	draw_polyline(sq1, gold, w)
	draw_arc(c, r * 0.8, 0.0, TAU, 32, gold, w)
	draw_circle(c, r * 0.16, gold)
	for i in 24:
		var a := float(i) * TAU / 24.0
		var d := Vector2(cos(a), sin(a))
		var r0 := r * 1.55
		var p0 := c + d * r0
		if inner.has_point(p0) and inner.has_point(c + d * (r0 + 3.0 * _s)):
			draw_line(p0, c + d * (r0 + 3.0 * _s), Color(UIStyle.GOLD, 0.35), w)


func _draw_overlays() -> void:
	var rad := (8.0 if size_kind in ["hand", "big", "mini", "back"] else 6.0) * _s
	var rect := Rect2(Vector2.ZERO, size)
	if fx_flash > 0.001:
		_round_rect(rect, Color(1, 1, 1, clampf(fx_flash, 0.0, 1.0) * 0.75), rad)
	if fx_glow.a > 0.001:
		_round_rect(rect, Color(fx_glow, fx_glow.a * 0.28), rad)
		_ring(Color(fx_glow, fx_glow.a), 3.0 * _s, rect, rad)
		_ring(Color(fx_glow, fx_glow.a * 0.35), 3.0 * _s, rect.grow(2.5 * _s), rad + 2.0 * _s)
	if hovered or _self_hover:
		_ring(Color(UIStyle.HOVER, 0.9), 2.0 * _s, rect, rad)
		_ring(Color(UIStyle.HOVER, 0.28), 3.0 * _s, rect.grow(2.5 * _s), rad + 2.0 * _s)
	if selected:
		_ring(Color(UIStyle.SELECT, 0.35), 4.0 * _s, rect.grow(3.0 * _s), rad + 3.0 * _s)
		_ring(UIStyle.SELECT, 3.0 * _s, rect, rad)
	if highlighted:
		var a := 1.0
		if not UIStyle.reduce_motion:
			a = 0.55 + 0.45 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 900.0 * TAU))
		_ring(Color(UIStyle.TARGET, 0.3 * a), 4.0 * _s, rect.grow(3.0 * _s), rad + 3.0 * _s)
		_ring(Color(UIStyle.TARGET, a), 3.0 * _s, rect, rad)
