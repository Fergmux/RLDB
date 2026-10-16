class_name CardWidget
extends Control
## Procedurally drawn card (art bible section 4): layered frame, art window (card art or
## a placeholder), name plate, cost gem (shape per cost kind), ATK diamond / DEF shield,
## status chips and a face-down back. Everything is drawn from the redacted card view, so
## hidden cards can only ever show the back. Runtime stats are never baked into art.
##
## Every card face is exactly 2:3 (portrait) or 3:2 (when `rotated`, i.e. the same portrait
## card turned 90 degrees clockwise). If the widget rect has another ratio the card is
## letterboxed and centred inside it (see card_rect()); the widget rect stays the hit area.
## An EMPTY view draws a zone background that fills the whole widget rect instead.
##
## Kinds: "board" (85x128 compact field unit), "power" (85x128), "trap" (85x128, shown
## rotated on the board), "hand" (120x180), "mini" (90x135), "big" (224x336), "back" (60x90).
## Geometry is authored in base units and scaled by card width / base width.

signal pressed(widget: CardWidget)
signal right_pressed(widget: CardWidget)

## Portrait sizes, all exactly 2:3 width:height.
const SIZES := {
	"hand": Vector2(120, 180), "mini": Vector2(90, 135), "big": Vector2(224, 336), "back": Vector2(60, 90),
	"board": Vector2(85, 128), "power": Vector2(85, 128), "trap": Vector2(85, 128),
}
## Default sizes of EMPTY zone backgrounds (callers normally size these to the zone rect).
const EMPTY_SIZES := {"board": Vector2(128, 128), "trap": Vector2(128, 85), "power": Vector2(85, 128)}
const ART_DIR := "res://art/cards/"
const UNIT_CATS := ["basic_unit", "unit", "fusion", "ritual", "arcane"]
const BIG_KINDS := ["hand", "big", "mini", "back"]

static var _tex_cache := {}
static var _radial_cache := {}
## Shaped text paragraphs are expensive; share them across all widgets (bounded).
static var _para_shared := {}
## One reusable style box: StyleBoxFlat.draw emits its commands immediately, so sharing is safe
## and avoids allocating a StyleBoxFlat for every ring/plate on every redraw.
static var _sb := StyleBoxFlat.new()

var view: Dictionary = {}
var size_kind: String = "board"
## Draw the portrait card turned 90 degrees clockwise inside a landscape rect (defense units, backrow).
var rotated: bool = false
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
## Ordered multi-select badge: 1, 2, 3... drawn on the card while > 0.
var order_no: int = 0: set = _set_order

var _s: float = 1.0
var _self_hover := false
var _is_ready := false
var _pv_stat := ""
var _pv_value := 0
var _pv_bonus := 0
## Drawn card rect in widget space and the unrotated portrait size (valid inside _draw).
var _cr := Rect2()
var _ps := Vector2(85, 128)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func(): _self_hover = auto_hover; queue_redraw())
	mouse_exited.connect(func(): _self_hover = false; queue_redraw())
	# Godot turns processing on at ready because _process exists: only redraw per frame while animating.
	_update_process()


## `is_rotated` turns the portrait card 90 degrees clockwise (size becomes SIZES[kind] swapped).
func setup(v, kind: String = "board", empty_label: String = "", is_rotated: bool = false) -> CardWidget:
	view = v if v != null else {}
	size_kind = kind
	empty_text = empty_label
	rotated = is_rotated
	_apply_size()
	if view.is_empty() or view.get("hidden", false) or not show_tooltip:
		tooltip_text = ""
	else:
		tooltip_text = tooltip_for(view)
	queue_redraw()
	return self


## Switches the portrait/landscape orientation of a card widget (defense stance, backrow) and resizes it.
func set_rotated(on: bool) -> void:
	if rotated == on:
		return
	rotated = on
	_apply_size()
	queue_redraw()


## Card widgets get their 2:3 (or 3:2) size as both size and minimum. Empty zone backgrounds get the
## default zone rect (unit slot 128x128, trap zone 128x85, power zone 85x128) with NO minimum, so the
## caller can size them freely to the zone rect.
func _apply_size() -> void:
	if view.is_empty():
		custom_minimum_size = Vector2.ZERO
		size = EMPTY_SIZES.get(size_kind, Vector2(128, 128))
	else:
		var sz: Vector2 = SIZES[size_kind]
		if rotated:
			sz = Vector2(sz.y, sz.x)
		custom_minimum_size = sz
		size = sz
	pivot_offset = size / 2.0


## `is_dimmed` = hard dim (non-target while a target is being chosen, ~0.55);
## `soft_dim` = gentle dim for cards that cannot act right now.
func set_marks(is_target: bool, is_selected: bool, is_dimmed: bool = false, soft_dim: bool = false) -> void:
	highlighted = is_target
	selected = is_selected
	dimmed = is_dimmed
	if is_dimmed:
		self_modulate = Color(0.55, 0.55, 0.55, 1.0)
	elif soft_dim:
		self_modulate = Color(0.8, 0.8, 0.8, 1.0)
	else:
		self_modulate = Color.WHITE
	_update_process()
	queue_redraw()


## "This card can act now" highlight (F02-11). Static (no per-frame redraw); independent of hover/select/target.
func set_ready(on: bool) -> void:
	if _is_ready != on:
		_is_ready = on
		queue_redraw()


func is_ready_on() -> bool:
	return _is_ready


## Combat preview (F02-12): shows `value` on the ATK or DEF badge in a provisional style with a
## "+N"/"-N" tag when `bonus` != 0. Purely visual: `view` is never modified.
func set_preview(stat: String, value: int, bonus: int) -> void:
	var st := stat if stat in ["atk", "def"] else ""
	if st == _pv_stat and value == _pv_value and bonus == _pv_bonus:
		return
	_pv_stat = st
	_pv_value = value
	_pv_bonus = bonus
	queue_redraw()


func clear_preview() -> void:
	if _pv_stat != "":
		_pv_stat = ""
		_pv_value = 0
		_pv_bonus = 0
		queue_redraw()


func has_preview() -> bool:
	return _pv_stat != ""


## The rect (widget space) the card face occupies: exactly 2:3 (3:2 when rotated), centred and
## letterboxed inside the widget rect, never stretched.
func card_rect() -> Rect2:
	var aspect := 1.5 if rotated else (2.0 / 3.0)   # width / height
	var w := size.x
	var h := size.y
	# 85x128 is 2:3 to within half a pixel; treat that as exact so the face is not offset by half a pixel.
	if absf(w / maxf(h, 0.001) - aspect) < 0.006:
		return Rect2(Vector2.ZERO, size)
	if w / maxf(h, 0.001) > aspect:
		w = h * aspect
	else:
		h = w / aspect
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)


func _set_hovered(v: bool) -> void:
	hovered = v
	queue_redraw()


func _set_flash(v: float) -> void:
	fx_flash = v
	queue_redraw()


func _set_glow(v: Color) -> void:
	fx_glow = v
	queue_redraw()


func _set_order(v: int) -> void:
	if v != order_no:
		order_no = v
		queue_redraw()


## Per-frame redraw only while something animates: the pulsing target ring or the breathing
## selection brackets. Static under reduce_motion.
func _update_process() -> void:
	set_process((highlighted or selected) and not UIStyle.reduce_motion)


func _process(_d: float) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
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


## Shadow offset that points screen-down even when the card is rotated.
func _shadow_off(d: float) -> Vector2:
	return Vector2(d, 0) if rotated else Vector2(0, d)


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
	if _para_shared.has(key):
		return _para_shared[key]
	if _para_shared.size() > 600:
		_para_shared.clear()
	var tp := TextParagraph.new()
	tp.width = width
	tp.max_lines_visible = max_lines
	tp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tp.add_string(text, font, fs)
	_para_shared[key] = tp
	return tp


## Paragraph at the largest size (<= fs_max) at which ALL of `text` fits in width x height; at
## fs_min it is clipped with an ellipsis as a last resort. Shared cache like _para.
func _fit_para(text: String, font: Font, fs_max: int, fs_min: int, width: float, height: float) -> TextParagraph:
	var key := "fit|%s|%d|%d|%d|%d" % [text, fs_max, fs_min, int(width), int(height)]
	if _para_shared.has(key):
		return _para_shared[key]
	if _para_shared.size() > 600:
		_para_shared.clear()
	var tp: TextParagraph = null
	for fs in range(fs_max, fs_min - 1, -1):
		tp = TextParagraph.new()
		tp.width = width
		tp.add_string(text, font, fs)
		if tp.get_size().y <= height:
			break
		if fs == fs_min:
			tp.max_lines_visible = maxi(1, int(height / maxf(1.0, tp.get_size().y / maxf(1.0, float(tp.get_line_count())))))
			tp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_para_shared[key] = tp
	return tp


## Resets the shared style box to a plain fill/border (no shadow) and returns it.
func _sbox(fill: Color, border: Color, bw: int, radius: int, with_center: bool = true) -> StyleBoxFlat:
	var sb := _sb
	sb.bg_color = fill
	sb.draw_center = with_center
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	return sb


func _ring(col: Color, width: float, rect: Rect2, radius: float) -> void:
	draw_style_box(_sbox(Color.TRANSPARENT, col, maxi(1, roundi(width)), maxi(1, roundi(radius)), false), rect)


func _round_rect(rect: Rect2, fill: Color, radius: float, border: Color = Color.TRANSPARENT, bw: float = 0.0) -> void:
	draw_style_box(_sbox(fill, border, maxi(1, roundi(bw)) if bw > 0.0 else 0, maxi(1, roundi(radius))), rect)


func _vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


# ---------------------------------------------------------------- main draw

func _draw() -> void:
	if view.is_empty():
		_s = clampf(minf(size.x, size.y) / 85.0, 0.5, 1.3)
		_cr = Rect2(Vector2.ZERO, size)
		_draw_empty()
		_draw_overlays()
		return
	_cr = card_rect()
	_ps = Vector2(_cr.size.y, _cr.size.x) if rotated else _cr.size
	_s = maxf(0.2, _ps.x / _base().x)
	draw_set_transform_matrix(_face_xform())
	if view.get("hidden", false):
		_draw_back()
	elif _is_own_set_card():
		_draw_back()
		# The name reads upright even though the card lies turned in the Trap/Spell zone.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_set_name()
	else:
		match size_kind:
			"power", "trap": _draw_power()
			"back": _draw_back()
			"hand", "mini": _draw_tall(false)
			"big": _draw_tall(true)
			_: _draw_square()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlays()


## Card-face (portrait) space -> widget space: the face is turned 90 degrees clockwise when `rotated`.
func _face_xform() -> Transform2D:
	if rotated:
		return Transform2D(PI / 2.0, Vector2(_cr.end.x, _cr.position.y))
	return Transform2D(0.0, _cr.position)


## While a rotated face is drawn, the parts drawn next (centred on face point `c`) stay upright in
## screen space at the same spot on the card: ATK/DEF badges, cost gem, type pip. Pair with _upright_end().
func _upright_begin(c: Vector2) -> void:
	if rotated:
		draw_set_transform(_face_xform() * c - c, 0.0, Vector2.ONE)


func _upright_end() -> void:
	if rotated:
		draw_set_transform_matrix(_face_xform())


## True for a backrow card the viewer can see but that is still face down: it is drawn as a card
## back with only its name. Face up (view.face_up) or Revealed (statuses.reveal > 0) shows the face.
func _is_own_set_card() -> bool:
	if view.get("zone", "") != "backrow" or view.get("face_up", true):
		return false
	return int(view.get("statuses", {}).get("reveal", 0)) <= 0


## Name plate across the middle of an own face-down set card, in screen orientation (widget space).
func _draw_set_name() -> void:
	var h := 22.0 * _s
	var keep: Variant = view.get("category")
	view["category"] = ""   # the back stays identical for every kind: no kind-coloured stripe on the plate
	_name_plate(Rect2(_cr.position.x + 5.0 * _s, _cr.get_center().y - h / 2.0, _cr.size.x - 10.0 * _s, h), 10.5, 0.0, 0.0, 8.0)
	view["category"] = keep


func _accent() -> Color:
	return UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), UIStyle.BRONZE)


func _frame(radius: float) -> void:
	var sb := _sbox(Color("1d1a18"), _accent(), maxi(2, roundi(2.8 * _s)), roundi(radius * _s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi((14.0 if (hovered or _self_hover) else 7.0) * _s)
	sb.shadow_offset = _shadow_off(3.0 * _s)
	draw_style_box(sb, Rect2(Vector2.ZERO, _ps))
	var inset := 3.0 * _s
	_vgrad(Rect2(inset, inset, _ps.x - 2 * inset, _ps.y - 2 * inset), Color(_accent().darkened(0.7), 0.45), Color(0, 0, 0, 0.45))
	draw_line(Vector2(radius * _s, 3.5 * _s), Vector2(_ps.x - radius * _s, 3.5 * _s), Color(UIStyle.GOLD_HI, 0.4), maxf(1.0, _s), true)


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
	draw_rect(rect, Color(UIStyle.BRONZE, 0.95), false, maxf(1.0, 2.0 * _s), true)


func _draw_glyph(kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.5, 0.12 * r)
	match kind:
		"sword":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.55), col, w * 1.3, true)
			draw_line(c + Vector2(-r * 0.5, r * 0.05), c + Vector2(r * 0.5, r * 0.05), col, w, true)
			draw_circle(c + Vector2(0, r * 0.75), r * 0.14, col, true, -1.0, true)
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
			draw_circle(c, r * 0.26, Color(0, 0, 0, col.a * 1.2), true, -1.0, true)
		"crown":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), col)
			draw_circle(c, r * 0.3, Color(0, 0, 0, col.a * 1.2), true, -1.0, true)


# ---------------------------------------------------------------- shared card parts

func _fit_name(text: String, width: float, fs_max: float, fs_min: float, font: Font) -> int:
	var fs := roundi(fs_max * _s)
	var lo := maxi(6, roundi(fs_min * _s))
	while fs > lo and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


## Splits a long name for a two-line plate: before a trailing "(...)" if present, else at the space
## nearest the middle. Returns [name] when it cannot be split.
static func split_name(nm: String) -> PackedStringArray:
	var i := nm.rfind(" (")
	if i <= 0:
		var best := -1
		for j in nm.length():
			if nm[j] == " " and (best < 0 or absi(j - nm.length() / 2) < absi(best - nm.length() / 2)):
				best = j
		i = best
	if i <= 0:
		return PackedStringArray([nm])
	return PackedStringArray([nm.substr(0, i), nm.substr(i + 1)])


func _ellipsize(font: Font, text: String, fs: int, avail: float) -> String:
	var shown := text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		while shown.length() > 3 and font.get_string_size(shown + "\u2026", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
			shown = shown.substr(0, shown.length() - 1)
		shown += "\u2026"
	return shown


## Name plate. One line when the name fits at a legible size, otherwise two lines (split before a
## trailing "(Type)") so "Basic Mage (Water)" and "(Fire)" stay distinguishable (D9).
func _name_plate(rect: Rect2, fs_max: float, reserve_l: float, reserve_r: float, fs_min: float = 9.0) -> void:
	_round_rect(rect, Color(0.102, 0.086, 0.075, 0.94), 4.0 * _s, Color(UIStyle.GOLD, 0.65), maxf(1.0, _s))
	draw_rect(Rect2(rect.position.x + 3 * _s, rect.end.y - 3.0 * _s, rect.size.x - 6 * _s, 2.0 * _s), _accent())
	var font := UIStyle.font_display(600)
	var avail := rect.size.x - (reserve_l + reserve_r) * _s - 6.0 * _s
	var nm: String = view["name"]
	var x := rect.position.x + (reserve_l + 3.0) * _s
	var fs := _fit_name(nm, avail, fs_max, fs_min, font)
	# Names are centred on the plate (user feedback 2026-10-16).
	if font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= avail:
		_text_at(font, nm, Vector2(x, rect.position.y), fs, UIStyle.TEXT, avail, HORIZONTAL_ALIGNMENT_CENTER, rect.size.y - 3.0 * _s)
		return
	var parts := split_name(nm)
	var inner_h := rect.size.y - 3.0 * _s
	var fs2 := mini(roundi(fs_max * _s), floori(inner_h / 2.0 / 1.05))
	if parts.size() == 2 and fs2 >= 7:
		var longest := parts[0] if parts[0].length() >= parts[1].length() else parts[1]
		while fs2 > 7 and font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > avail:
			fs2 -= 1
		var lh := float(fs2) * 1.05
		var y0 := rect.position.y + (inner_h - 2.0 * lh) / 2.0
		for k in 2:
			_text_at(font, _ellipsize(font, parts[k], fs2, avail), Vector2(x, y0 + float(k) * lh), fs2, UIStyle.TEXT if k == 0 else UIStyle.MUTED, avail, HORIZONTAL_ALIGNMENT_CENTER, lh)
		return
	_text_at(font, _ellipsize(font, nm, fs, avail), Vector2(x, rect.position.y), fs, UIStyle.TEXT, avail, HORIZONTAL_ALIGNMENT_CENTER, inner_h)


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
	_upright_begin(c)
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
			draw_circle(c, r, dark, true, -1.0, true)
			draw_circle(c, r - bw, col, true, -1.0, true)
			draw_arc(c, r * 0.68, 0.0, TAU, 28, dark, maxf(1.0, 1.5 * _s), true)
			draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.25), true, -1.0, true)
		_:
			draw_circle(c, r, dark, true, -1.0, true)
			draw_circle(c, r - bw, col, true, -1.0, true)
			draw_circle(c + Vector2(-r * 0.22, -r * 0.3), r * 0.38, Color(1, 1, 1, 0.28), true, -1.0, true)
	var txt := _cost_text()
	var tc := _cost_color()
	_text_c(UIStyle.font_display(700), txt, c + Vector2(0, 0.5 * _s), fs, tc, 0.0 if tc == UIStyle.ON_GOLD else 1.5)
	_upright_end()


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


func _diamond_pts(rect: Rect2) -> PackedVector2Array:
	var c := rect.get_center()
	return PackedVector2Array([Vector2(c.x, rect.position.y), Vector2(rect.end.x, c.y), Vector2(c.x, rect.end.y), Vector2(rect.position.x, c.y)])


## Pushes every point away from `c` by `amount` (negative = inward).
func _grow_pts(pts: PackedVector2Array, c: Vector2, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * amount)
	return out


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := PackedVector2Array(pts)
	o.append(pts[0])
	return o


## Largest font size <= fs_max (base px) at which `txt` fits inside the badge's text area.
func _fit_stat_fs(font: Font, txt: String, fs_max: float, rect: Rect2, diamond: bool) -> int:
	var fs := maxi(6, roundi(fs_max * _s))
	while fs > 6:
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var th := float(fs) * 0.74
		if diamond:
			# Text box must sit inside the rhombus: tw/w + th/h <= 1 (with a margin for the outline).
			if tw / rect.size.x + th / rect.size.y <= 0.84:
				break
		elif tw <= rect.size.x * 0.76 and th <= rect.size.y * 0.52:
			break
		fs -= 1
	return fs


## ATK diamond (gold rim, red gradient) or DEF shield. Shows the live value, or the preview value
## in a provisional cyan style (dashed ring + "+N" tag) while set_preview() targets this stat.
func _stat_badge(rect: Rect2, is_atk: bool, fs_max: float) -> void:
	var value = view.get("atk" if is_atk else "def")
	var printed = view.get("printed_atk" if is_atk else "printed_def")
	var previewing := _pv_stat == ("atk" if is_atk else "def")
	var c := rect.get_center()
	_upright_begin(c)   # a Defense (rotated) card still shows its numbers the right way up
	var top := Color("c9453a") if is_atk else Color("3f7ab5")
	var bot := Color("4d1713") if is_atk else Color("1b3a5a")
	if is_atk:
		var pts := _diamond_pts(rect)
		# Perpendicular half-distance from centre to an edge, for an even rim.
		var hw := rect.size.x / 2.0
		var hh := rect.size.y / 2.0
		var edge_d := hw * hh / sqrt(hw * hw + hh * hh)
		var k := 1.0 - (2.4 * _s) / edge_d
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * k)
		draw_colored_polygon(pts, Color(UIStyle.GOLD, 0.98))
		draw_polygon(inner, PackedColorArray([top.lightened(0.15), top.lerp(bot, 0.45), bot, top.lerp(bot, 0.45)]))
		# Upper facet highlight + rim glint (reads as cut metal).
		draw_colored_polygon(PackedVector2Array([inner[0], inner[1], c + Vector2(0, hh * 0.02), inner[3]]), Color(1, 1, 1, 0.09))
		draw_polyline(PackedVector2Array([pts[3], pts[0], pts[1]]), Color(UIStyle.GOLD_HI, 0.9), maxf(1.0, 0.9 * _s), true)
		draw_polyline(_closed(inner), Color(0, 0, 0, 0.35), maxf(1.0, 0.8 * _s), true)
	else:
		draw_colored_polygon(_shield_pts(rect), Color(UIStyle.GOLD, 0.95))
		var ins := Rect2(rect.position + Vector2(1.8, 1.8) * _s, rect.size - Vector2(3.6, 3.6) * _s)
		var spts := _shield_pts(ins)
		var cols := PackedColorArray()
		for p in spts:
			cols.append(top.lerp(bot, clampf((p.y - ins.position.y) / ins.size.y, 0.0, 1.0)))
		draw_polygon(spts, cols)
	var tcol := Color.WHITE
	var mod := 0
	var shown_v = value
	if previewing:
		shown_v = _pv_value
		tcol = Color("eafcff")
	elif value != null and printed != null and view.get("zone", "") == "unit":
		if value > printed:
			tcol = UIStyle.GOOD
			mod = 1
		elif value < printed:
			tcol = Color("ff8a84")
			mod = -1
	var txt := "?" if shown_v == null else str(shown_v)
	var font := UIStyle.font_display(700)
	var fs := _fit_stat_fs(font, txt, fs_max, rect, is_atk)
	_text_c(font, txt, c + Vector2(0, -rect.size.y * (0.0 if is_atk else 0.04)), fs, tcol, maxf(1.5, 1.8 * _s))
	if mod != 0:
		var ac := Vector2(c.x, rect.position.y + rect.size.y * (0.15 if is_atk else 0.1))
		var a := 3.0 * _s
		if mod > 0:
			draw_colored_polygon(PackedVector2Array([ac + Vector2(0, -a), ac + Vector2(a, a * 0.8), ac + Vector2(-a, a * 0.8)]), UIStyle.GOOD)
		else:
			ac.y = rect.position.y + rect.size.y * (0.85 if is_atk else 0.92)
			draw_colored_polygon(PackedVector2Array([ac + Vector2(0, a), ac + Vector2(a, -a * 0.8), ac + Vector2(-a, -a * 0.8)]), Color("ff8a84"))
	if previewing:
		_preview_decor(rect, is_atk)
	_upright_end()


func _preview_decor(rect: Rect2, is_atk: bool) -> void:
	var c := rect.get_center()
	var base := _diamond_pts(rect) if is_atk else _shield_pts(rect)
	var glow := _grow_pts(base, c, 3.6 * _s)
	var ring := _grow_pts(base, c, 2.4 * _s)
	draw_polyline(_closed(glow), Color(UIStyle.PREVIEW, 0.45), maxf(4.0, 4.5 * _s), true)
	for i in ring.size():
		draw_dashed_line(ring[i], ring[(i + 1) % ring.size()], Color.WHITE, maxf(2.2, 2.4 * _s), 4.0 * _s, true, true)
	if _pv_bonus == 0:
		return
	var up := _pv_bonus > 0
	var font := UIStyle.font_bold()
	var fs := maxi(11, _fs(11.5))
	var minus := "−" if font.has_char(0x2212) else "-"
	var tag := "%s%d" % ["+" if up else minus, absi(_pv_bonus)]
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ph := maxf(15.0, 14.0 * _s)
	var pw := tw + ph * 1.0
	var pc := Vector2(c.x, rect.position.y - 2.0 * _s)
	var pr := Rect2(pc - Vector2(pw / 2.0, ph / 2.0), Vector2(pw, ph))
	_round_rect(pr, Color(0.03, 0.12, 0.16, 0.96), ph / 2.0, UIStyle.PREVIEW, maxf(1.0, _s))
	var m := Vector2(pr.position.x + ph * 0.55, pc.y)
	var a := ph * 0.2
	var tc := UIStyle.GOOD if up else Color("ff8a84")
	if up:
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -a), m + Vector2(a, a), m + Vector2(-a, a)]), tc)
	else:
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, a), m + Vector2(a, -a), m + Vector2(-a, -a)]), tc)
	_text_c(font, tag, Vector2(pr.position.x + pw / 2.0 + 3.0 * _s, pc.y), fs, tc)


func _status_list() -> Array:
	var out := []
	if view.get("runes", 0) > 0:
		out.append({"t": "Rune %d" % view["runes"], "c": UIStyle.RUNE_BLUE, "k": 0})
	var backrow: bool = view.get("zone", "") == "backrow"
	for s in CardDB.STATUS_ORDER:
		if backrow and s == "reveal":
			continue   # a backrow card shows face up or face down by itself; no Reveal chip there
		var n: int = view.get("statuses", {}).get(s, 0)
		if n > 0:
			out.append({"t": "%s %d" % [String(s).capitalize(), n], "c": Color("6fd38a") if CardDB.is_buff(s) else Color("e8605a"), "k": 1 if CardDB.is_buff(s) else -1})
	return out


## Full-name status chips laid out left to right over up to `rows` rows; whatever does not fit
## collapses into a "+N" chip at the end of the last row.
func _chips(x0: float, x1: float, y: float, h: float, fs_base: float, rows: int = 1) -> void:
	var list := _status_list()
	if list.is_empty():
		return
	var font := UIStyle.font_bold()
	var fs := _fs(fs_base)
	var left := x0 * _s
	var xmax := x1 * _s
	var x := left
	var row := 0
	var i := 0
	while i < list.size():
		var e: Dictionary = list[i]
		var w := font.get_string_size(e["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (h * _s * 0.67 + 6.0 * _s if int(e["k"]) != 2 else 8.0 * _s)
		var remaining := list.size() - i - 1
		var last_row := row >= rows - 1
		var reserve := (font.get_string_size("+%d" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * _s) if (remaining > 0 and last_row) else 0.0
		if x + w + reserve > xmax and x > left:
			if not last_row:
				row += 1
				x = left
				continue
			var more := list.size() - i
			_chip_draw(x, (y + float(row) * (h + 1.5)) * _s, font.get_string_size("+%d" % more, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * _s, h * _s, "+%d" % more, UIStyle.MUTED, font, fs)
			return
		_chip_draw(x, (y + float(row) * (h + 1.5)) * _s, w, h * _s, e["t"], e["c"], font, fs, int(e["k"]))
		x += w + 2.0 * _s
		i += 1


## `kind`: +1 buff (up triangle), -1 debuff (down triangle), 0 rune (diamond), 2 neutral (no mark).
## The mark means chips never rely on colour alone.
func _chip_draw(x: float, y: float, w: float, h: float, text: String, col: Color, font: Font, fs: int, kind: int = 2) -> void:
	_round_rect(Rect2(x, y, w, h), Color(col.darkened(0.7), 0.95), h / 2.0, col, maxf(1.0, _s))
	var tx := x + w / 2.0
	if kind != 2:
		var m := Vector2(x + h * 0.4 + 1.0 * _s, y + h / 2.0)
		var a := h * 0.17
		var lc := col.lightened(0.45)
		if kind > 0:
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -a), m + Vector2(a, a), m + Vector2(-a, a)]), lc)
		elif kind < 0:
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, a), m + Vector2(a, -a), m + Vector2(-a, -a)]), lc)
		else:
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -a * 1.2), m + Vector2(a, 0), m + Vector2(0, a * 1.2), m + Vector2(-a, 0)]), lc)
		tx = x + h * 0.67 + 2.0 * _s + (w - h * 0.67 - 2.0 * _s) / 2.0
	_text_c(font, text, Vector2(tx, y + h / 2.0), fs, col.lightened(0.45))


## Hover tooltip: the name, then the card text wrapped to a comfortable reading width.
static func tooltip_for(v: Dictionary, width: int = 58) -> String:
	var out := PackedStringArray([String(v.get("name", ""))])
	for para in card_text(v).split("\n"):
		var line := ""
		for word in para.split(" ", false):
			if line != "" and line.length() + 1 + word.length() > width:
				out.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		if line != "":
			out.append(line)
	return "\n".join(out)


## Rules text as printed on the card face: timing captions kept ("On Summon: …") except the
## "On Field:" one, which is implied for a card on the field (user feedback 2026-10-16).
static func card_text(v: Dictionary) -> String:
	var parts: Array = v.get("text_parts", [])
	if parts.is_empty():
		return String(v.get("text", "")).replace("On Field: ", "")
	var lines := []
	for p in parts:
		var k := String(p.get("k", ""))
		lines.append(String(p.get("t", "")) if k == "On Field" or k == "" else "%s: %s" % [k, p.get("t", "")])
	return "\n".join(lines)


## Damage-type pip on the art. Reads view.type at draw time so type changes show immediately.
func _type_pip(c: Vector2, r: float) -> void:
	# Only a real damage Type gets a pip; Spells/Traps/Powers and typeless units show none (the
	# race/type line already says "No type").
	if not view.has("type") or view.get("type") == null or String(view.get("type")) == "":
		return
	var t = view.get("type")
	_upright_begin(c)
	TypeIcons.draw_pip(self, "" if t == null else str(t), c, r)
	_upright_end()


# ---------------------------------------------------------------- layouts

## Compact 85x128 field unit card (no rules-text well).
func _draw_square() -> void:
	var is_unit: bool = String(view.get("category", "")) in UNIT_CATS
	_frame(6.0)
	_draw_art(_r(4, 4, 77, 60))
	# Cost gem and type icon share one size (user feedback).
	_type_pip(_p(72, 13), 9.0 / TypeIcons.PIP_K * _s)
	_name_plate(_r(4, 52, 77, 20), 10.5, 0.0, 0.0, 8.0)
	_chips(4, 81, 73.0, 9.5, 7.5, 2)
	if is_unit:
		_stat_badge(_r(2, 93, 36, 33), true, 16.0)
		_stat_badge(_r(47, 94, 33, 32), false, 16.0)
	_gem(_p(13, 13), 9.0 * _s, _fs(12))


## Power / trap card: art, name, short rules text, chips. Same 85x128 portrait.
func _draw_power() -> void:
	_frame(6.0)
	_draw_art(_r(4, 4, 77, 56))
	_name_plate(_r(4, 48, 77, 20), 10.5, 0.0, 0.0, 8.0)
	_gem(_p(13, 13), 9.0 * _s, _fs(12))
	var txt := card_text(view)
	if txt != "":
		var tp := _para(txt, UIStyle.font_body(), "b", _fs(9.0), 77.0 * _s, 4)
		tp.draw(get_canvas_item(), _p(4, 70), Color(UIStyle.TEXT, 0.9))
	_chips(4, 81, 115.0, 10.0, 7.5, 1)


func _draw_tall(big: bool) -> void:
	var is_unit: bool = String(view.get("category", "")) in UNIT_CATS
	var g := {}
	if big:
		g = {"art": [10, 10, 204, 110], "plate": [10, 100, 204, 32], "line": 136.0, "text": [12, 156, 200, 98 if is_unit else 134],
			"chip_y": 258.0, "chip_x": [12.0, 212.0], "chip_rows": 1, "atk": [6, 279, 56, 53], "def": [162, 281, 52, 50], "gem": [27, 27, 17],
			"f_name": 19.0, "f_line": 13.0, "f_text": 13.0, "f_chip": 11.0, "f_stat": 30.0, "f_gem": 21.0, "chip_h": 15.0, "chip_y_nu": 298.0, "chip_rows_nu": 2, "pip": [197, 27]}
	else:
		g = {"art": [6, 6, 108, 58], "plate": [6, 52, 108, 22], "line": 76.0, "text": [6, 90, 108, 44 if is_unit else 72],
			"chip_y": 136.0, "chip_x": [6.0, 114.0], "chip_rows": 1, "atk": [3, 146, 34, 32], "def": [84, 147, 32, 31], "gem": [17, 17, 11.5],
			"f_name": 12.5, "f_line": 11.0, "f_text": 10.5, "f_chip": 8.5, "f_stat": 17.0, "f_gem": 14.0, "chip_h": 9.5, "chip_y_nu": 164.0, "chip_rows_nu": 1, "pip": [103, 17]}
	_frame(8.0)
	var a: Array = g["art"]
	_draw_art(_r(a[0], a[1], a[2], a[3]))
	var gm: Array = g["gem"]
	_type_pip(_p(g["pip"][0], g["pip"][1]), float(gm[2]) / TypeIcons.PIP_K * _s)   # same size as the cost gem
	var pl: Array = g["plate"]
	_name_plate(_r(pl[0], pl[1], pl[2], pl[3]), g["f_name"], 0.0, 0.0)
	# Type / race line.
	var line_fs := _fs(g["f_line"])
	var ly: float = g["line"]
	var lx: float = float(pl[0]) + 4.0
	var lh := float(g["f_line"] + 3) * _s
	if is_unit:
		var t_well: Array = g["text"]
		_race_type_line(Vector2(lx * _s, ly * _s), (float(t_well[0]) + float(t_well[2]) - 4.0 - lx) * _s, lh, line_fs)
	else:
		_round_rect(_r(lx, ly + 3, 8 if not big else 11, 8 if not big else 11), _accent(), 2.0 * _s)
		_text_at(UIStyle.font_italic(), UIStyle.CATEGORY_NAMES.get(view.get("category", ""), ""), _p(lx + (11 if not big else 15), ly), line_fs, UIStyle.MUTED, -1.0, HORIZONTAL_ALIGNMENT_LEFT, lh)
	# Rules text well.
	var t: Array = g["text"]
	var rules := card_text(view)
	if view.get("support", "full") == "unimplemented":
		rules = "[Effect not implemented] " + rules
	_round_rect(_r(t[0], t[1], t[2], t[3]), Color(0.847, 0.8, 0.69, 0.08), 3.0 * _s)
	if rules != "":
		# The whole rules text always fits: the size steps down until it does (user feedback).
		var tp := _fit_para(rules, UIStyle.font_body(), _fs(g["f_text"]), maxi(5, _fs(g["f_text"] * 0.55)), (float(t[2]) - 8.0) * _s, (float(t[3]) - 3.0) * _s)
		tp.draw(get_canvas_item(), _p(t[0] + 4, t[1] + 2), UIStyle.TEXT)
	# Chips + stat badges + gem.
	if is_unit:
		var at: Array = g["atk"]
		var df: Array = g["def"]
		_chips(g["chip_x"][0], g["chip_x"][1], g["chip_y"], g["chip_h"], g["f_chip"], g["chip_rows"])
		_stat_badge(_r(at[0], at[1], at[2], at[3]), true, g["f_stat"])
		_stat_badge(_r(df[0], df[1], df[2], df[3]), false, g["f_stat"])
	else:
		_chips(g["chip_x"][0], g["chip_x"][1], g["chip_y_nu"], g["chip_h"], g["f_chip"], g["chip_rows_nu"])
	_gem(_p(gm[0], gm[1]), float(gm[2]) * _s, _fs(g["f_gem"]))


## Race left-aligned and damage Type right-aligned on one line `width` wide (no icon: the type pip
## on the art already shows it). Read from view.race / view.type at draw time.
func _race_type_line(pos: Vector2, width: float, line_h: float, fs: int) -> void:
	var font := UIStyle.font_italic()
	var rv = view.get("race")
	var tv = view.get("type")
	var race: String = "No race" if (rv == null or str(rv) == "") else str(rv)
	var typ: String = "No type" if (tv == null or str(tv) == "") else str(tv)
	var col := UIStyle.MUTED
	var tw := minf(font.get_string_size(typ, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, width * 0.5)
	typ = _ellipsize(font, typ, fs, tw + 0.5)
	var race_w := width - tw - 6.0 * _s
	_text_at(font, _ellipsize(font, race, fs, race_w), pos, fs, col, race_w, HORIZONTAL_ALIGNMENT_LEFT, line_h)
	_text_at(font, typ, pos, fs, col, width, HORIZONTAL_ALIGNMENT_RIGHT, line_h)


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
	# Zones never show a text label ("Front 1", "Trap / Spell 2", ...) — user feedback 2026-10-16.


func _draw_back() -> void:
	var rad := 8.0 if size_kind in BIG_KINDS else 6.0
	var sb := _sbox(Color("1d1630"), Color("6e5a9a"), maxi(2, roundi(2.8 * _s)), roundi(rad * _s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi(6.0 * _s)
	sb.shadow_offset = _shadow_off(3.0 * _s)
	draw_style_box(sb, Rect2(Vector2.ZERO, _ps))
	draw_back_art(self, Rect2(Vector2.ZERO, _ps), _s)


## The one card-back design (every kind, both players, piles): inner gradient, gold frame, emblem.
static func draw_back_art(ci: CanvasItem, card: Rect2, s: float) -> void:
	var inner := card.grow(-5.0 * s)
	var steps := 12
	for i in steps:
		var t := float(i) / float(steps - 1)
		var band := Rect2(inner.position.x, inner.position.y + inner.size.y * float(i) / steps, inner.size.x, inner.size.y / steps + 1.0).intersection(inner)
		ci.draw_rect(band, Color("2a2050").lerp(Color("120c22"), t))
	ci.draw_rect(inner, Color(UIStyle.GOLD, 0.35), false, maxf(1.0, s), true)
	var c := card.get_center()
	var r := minf(inner.size.x, inner.size.y) * 0.34
	var gold := Color(UIStyle.GOLD, 0.7)
	var w := maxf(1.0, 1.4 * s)
	for rot in [PI / 4.0, 0.0]:
		var sq := PackedVector2Array()
		for k in 5:
			var a: float = rot + float(k) * TAU / 4.0
			sq.append(c + Vector2(cos(a), sin(a)) * r * 1.2)
		ci.draw_polyline(sq, gold, w, true)
	ci.draw_arc(c, r * 0.8, 0.0, TAU, 32, gold, w, true)
	ci.draw_circle(c, r * 0.16, gold, true, -1.0, true)
	for i in 24:
		var a := float(i) * TAU / 24.0
		var d := Vector2(cos(a), sin(a))
		var r0 := r * 1.55
		var p0 := c + d * r0
		if inner.has_point(p0) and inner.has_point(c + d * (r0 + 3.0 * s)):
			ci.draw_line(p0, c + d * (r0 + 3.0 * s), Color(UIStyle.GOLD, 0.35), w, true)


# ---------------------------------------------------------------- overlays (screen space, follow the drawn card rect)

func _draw_overlays() -> void:
	var rect := _cr
	var rad := (8.0 if size_kind in BIG_KINDS else 6.0) * _s
	if fx_flash > 0.001:
		_round_rect(rect, Color(1, 1, 1, clampf(fx_flash, 0.0, 1.0) * 0.75), rad)
	if fx_glow.a > 0.001:
		_round_rect(rect, Color(fx_glow, fx_glow.a * 0.28), rad)
		_ring(Color(fx_glow, fx_glow.a), 3.0 * _s, rect, rad)
		_ring(Color(fx_glow, fx_glow.a * 0.35), 3.0 * _s, rect.grow(2.5 * _s), rad + 2.0 * _s)
	if _is_ready:
		# Steady warm-yellow glow OUTSIDE the card (its own frame colour stays visible) plus the chevron
		# badge. TARGET differs by behaviour: it pulses and fills/rings the card itself.
		_ready_glow(rect, rad)
	if hovered or _self_hover:
		# Soft ivory glow entirely OUTSIDE the card, no ring on it: the kind-coloured frame stays visible.
		_outer_glow(rect, rad, UIStyle.HOVER_GLOW, 1.0)
	if selected:
		# No ring or fill on the card: a slight blue glow outside it plus corner brackets that breathe
		# slowly in and out (~1.6 s period).
		var ph := 0.0
		if not UIStyle.reduce_motion:
			ph = sin(float(Time.get_ticks_msec()) / 1600.0 * TAU)
		_outer_glow(rect, rad, UIStyle.SELECT, 0.9 + 0.15 * ph)
		_corner_brackets(rect.grow((6.0 + 2.2 * ph) * _s), maxf(8.0, 9.0 * _s), UIStyle.SELECT.lightened(0.3), maxf(2.2, 2.4 * _s))
	if highlighted:
		var a := 1.0
		if not UIStyle.reduce_motion:
			a = 0.55 + 0.45 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 900.0 * TAU))
		_round_rect(rect, Color(UIStyle.TARGET, 0.07 + 0.12 * a), rad)
		_ring(Color(UIStyle.TARGET, 0.35 * a), 5.0 * _s, rect.grow(3.5 * _s), rad + 3.0 * _s)
		_ring(Color(UIStyle.TARGET, a), 3.5 * _s, rect, rad)
	# Badges last so combined states (ready + selected, etc.) stay legible.
	if _is_ready:
		_ready_badge(rect)
	if order_no > 0:
		_order_badge(rect)


## Soft glow in three bands just outside `rect` (never over the card frame). `k` scales the alpha.
func _outer_glow(rect: Rect2, rad: float, col: Color, k: float) -> void:
	_ring(Color(col, 0.34 * k), maxf(1.5, 2.0 * _s), rect.grow(2.0 * _s), rad + 2.0 * _s)
	_ring(Color(col, 0.16 * k), 3.5 * _s, rect.grow(5.5 * _s), rad + 5.5 * _s)
	_ring(Color(col, 0.06 * k), 4.0 * _s, rect.grow(9.5 * _s), rad + 9.5 * _s)


## "Can act now" glow: a crisp thin READY ring just outside the card, then three fading bands
## beyond it. Static (no per-frame redraw). Wider than the hover glow so both read when combined.
func _ready_glow(rect: Rect2, rad: float) -> void:
	_ring(Color(UIStyle.READY, 0.30), 3.5 * _s, rect.grow(6.0 * _s), rad + 6.0 * _s)
	_ring(Color(UIStyle.READY, 0.15), 4.0 * _s, rect.grow(9.5 * _s), rad + 9.5 * _s)
	_ring(Color(UIStyle.READY, 0.06), 4.5 * _s, rect.grow(13.5 * _s), rad + 13.5 * _s)
	_ring(Color(UIStyle.READY, 0.9), maxf(1.5, 1.7 * _s), rect.grow(3.0 * _s), rad + 3.0 * _s)


## Yellow circle with a bold dark double up-chevron on the top edge: "can act now" by shape, not
## colour alone.
func _ready_badge(rect: Rect2) -> void:
	var rr := maxf(10.0, 10.5 * _s)
	var c := Vector2(rect.get_center().x, rect.position.y - 5.0 * _s)
	draw_circle(c, rr + 1.8 * _s, Color(0.09, 0.06, 0.02, 0.95), true, -1.0, true)
	draw_circle(c, rr, UIStyle.READY, true, -1.0, true)
	draw_arc(c, rr, 0.0, TAU, 24, Color(1.0, 0.97, 0.86), maxf(1.2, 1.3 * _s), true)
	var w := rr * 0.52
	var dark := Color(0.17, 0.10, 0.02)
	for y in [c.y + rr * 0.42, c.y - rr * 0.12]:
		draw_polyline(PackedVector2Array([Vector2(c.x - w, y), Vector2(c.x, y - w * 0.9), Vector2(c.x + w, y)]), dark, maxf(2.2, 2.4 * _s), true)


func _corner_brackets(r: Rect2, len_px: float, col: Color, w: float) -> void:
	var xs := [r.position.x, r.end.x]
	var ys := [r.position.y, r.end.y]
	for i in 2:
		for j in 2:
			var p := Vector2(xs[i], ys[j])
			var dx := len_px if i == 0 else -len_px
			var dy := len_px if j == 0 else -len_px
			draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), col, w, true)


func _order_badge(rect: Rect2) -> void:
	var rr := maxf(9.5, 10.5 * _s)
	var c := Vector2(rect.end.x - 3.0 * _s, rect.position.y + 3.0 * _s)
	draw_circle(c, rr + 1.8 * _s, Color(0.04, 0.03, 0.03, 0.95), true, -1.0, true)
	draw_circle(c, rr, UIStyle.SELECT.darkened(0.1), true, -1.0, true)
	draw_arc(c, rr, 0.0, TAU, 24, Color.WHITE, maxf(1.3, 1.5 * _s), true)
	_text_c(UIStyle.font_display(700), str(order_no), c, maxi(10 if order_no < 10 else 8, roundi(rr * (1.1 if order_no < 10 else 0.85))), Color.WHITE, 1.0)
