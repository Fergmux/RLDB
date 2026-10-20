class_name CardPainter
extends RefCounted
## Per-widget drawing context for a CardWidget: the canvas to draw on, a snapshot of the card state
## taken at the start of each _draw (view, kind, rotation, scale, card rect) and the scaled drawing
## primitives every card part uses. The part painters (CardArt, CardFaceParts, CardStatBadge,
## CardStatusIcons, CardBack, CardLayouts, CardOverlays) are static functions that take one of these.
##
## Geometry is authored in base units: r()/p()/fs() scale them by `s` (card width / base width).
## Card-face parts draw in portrait face space; set_face_transform() maps it onto the widget.

## Smallest font size (px) fs() returns.
const MIN_FS := 6
## draw_string's default justification flags (the parameter has to be given to reach `oversampling`).
const _JUST := TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND

## One reusable style box: StyleBoxFlat.draw emits its commands immediately, so sharing is safe
## and avoids allocating a StyleBoxFlat for every ring/plate on every redraw.
static var _sb := StyleBoxFlat.new()

## Canvas every part draws on (the owning CardWidget).
var ci: CanvasItem
## Redacted card view being drawn (shared with the widget; never modified while drawing).
var view: Dictionary = {}
## Card size kind ("board", "hand", "big" ...).
var size_kind: String = "board"
## Drawn turned sideways (Defense).
var rotated: bool = false
## Hover glow on (externally driven or self-managed hover).
var hover: bool = false
## Combat preview: "atk" / "def" / "" (none), the value to show and its +/- bonus tag.
var pv_stat: String = ""
## Preview value shown.
var pv_value: int = 0
## Preview bonus tag.
var pv_bonus: int = 0
## Scale of the base-unit geometry.
var s: float = 1.0
## Drawn card rect in widget space and the unrotated portrait size.
var cr := Rect2()
## Unrotated portrait size.
var ps := Vector2(85, 128)
## Draw scale (F05-03 hover lift): the face is laid out at its RESTING size (s, cr, ps and every font
## size come from it) and every command is drawn scaled by `k` about the widget origin, so a lifted
## card shows exactly its resting line breaks and proportions, only bigger.
var k: float = 1.0
## Raster oversampling for every text draw (0.0 = the viewport's own). Set by the widget to the
## viewport oversampling times the card's on-screen scale (lift and any `scale` above it), so the
## glyphs drawn under `k` are rasterised at their final pixel size and stay sharp.
var text_os: float = 0.0
## Status / Rune icons drawn by the last draw: {"rect": widget-space Rect2, "label": tooltip text}
## (CardStatusIcons fills it; the widget shows StatusTip over them).
var hits: Array = []
## Rules paragraphs drawn by the last redraw, so a status word in them can be hovered (2026-10-18):
## [{"para": TextParagraph, "pos": face-space origin, "text": String, "inv": widget -> face}].
var text_hits: Array = []
## Tests: when true every text draw appends a record of its layout (text, size, face-space position).
var tracing := false
## The records of the last draw while `tracing`.
var trace: Array = []


func _init(canvas: CanvasItem) -> void:
	ci = canvas


## Scaled rect from base units.
func r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * s, y * s, w * s, h * s)


## Scaled point from base units.
func p(x: float, y: float) -> Vector2:
	return Vector2(x * s, y * s)


## Scaled font size from base units, never below MIN_FS.
func fs(n: float) -> int:
	return maxi(MIN_FS, roundi(n * s))


## Shadow offset that points screen-down even when the card is rotated.
func shadow_off(d: float) -> Vector2:
	return Vector2(d, 0) if rotated else Vector2(0, d)


## Kind colour of the card (frame border, name-plate stripe).
func accent() -> Color:
	return UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), UIStyle.BRONZE)


## Resting-layout space -> widget space: the lift scale `k` about the widget origin.
func base_xform() -> Transform2D:
	return Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)


## Card-face (portrait) space -> widget space: the face is turned 90 degrees clockwise when `rotated`.
func face_xform() -> Transform2D:
	if rotated:
		return base_xform() * Transform2D(PI / 2.0, Vector2(cr.end.x, cr.position.y))
	return base_xform() * Transform2D(0.0, cr.position)


## Draw subsequent commands in card-face space.
func set_face_transform() -> void:
	ci.draw_set_transform_matrix(face_xform())


## Draw subsequent commands in plain (resting-layout) widget space.
func reset_transform() -> void:
	ci.draw_set_transform_matrix(base_xform())


## While a rotated face is drawn, the parts drawn next (centred on face point `c`) stay upright in
## screen space at the same spot on the card: ATK/DEF badges, cost gem, type pip. Pair with upright_end().
func upright_begin(c: Vector2) -> void:
	if rotated:
		ci.draw_set_transform(face_xform() * c - c * k, 0.0, Vector2(k, k))


## Ends an upright-drawing section started by upright_begin().
func upright_end() -> void:
	if rotated:
		ci.draw_set_transform_matrix(face_xform())


## One line of text whose box (`line_h` tall, default 1.1 x fs) starts at `pos_top_left`, vertically centred.
func text_at(font: Font, text: String, pos_top_left: Vector2, fsz: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT, line_h: float = 0.0) -> void:
	var h := line_h if line_h > 0.0 else float(fsz) * 1.1
	var base_y := pos_top_left.y + h / 2.0 + (font.get_ascent(fsz) - font.get_descent(fsz)) / 2.0
	if tracing:
		trace.append(["line", text, fsz, Vector2(pos_top_left.x, base_y), width, align])
	ci.draw_string(font, Vector2(pos_top_left.x, base_y), text, align, width, fsz, col, _JUST, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, text_os)


## One line of text centred on `centre`, with an optional dark outline `outline` px wide.
func text_c(font: Font, text: String, centre: Vector2, fsz: int, col: Color, outline: float = 0.0) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
	var pos := Vector2(centre.x - sz.x / 2.0, centre.y + (font.get_ascent(fsz) - font.get_descent(fsz)) / 2.0)
	if tracing:
		trace.append(["centred", text, fsz, pos])
	if outline > 0.0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, int(ceil(outline)), Color(0, 0, 0, 0.7), _JUST, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, text_os)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col, _JUST, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, text_os)


## A shaped paragraph (CardTextLayout) with its top-left at `pos`, rasterised at `text_os`.
## Draws `tp` and records it for status-word hovering when `text` (its string) names a status.
func para_text(tp: TextParagraph, pos: Vector2, col: Color, text: String) -> void:
	if StatusHelp.spans(text).is_empty():
		para(tp, pos, col)
		return
	# D12: status words are drawn in the link colour and underlined so they read as hoverable.
	if tracing:
		para(tp, pos, col)
	else:
		StatusHelp.draw_marked(ci, tp, pos, col, text, UIStyle.STATUS_LINK, text_os)
	text_hits.append({"para": tp, "pos": pos, "text": text, "inv": face_xform().affine_inverse()})


func para(tp: TextParagraph, pos: Vector2, col: Color) -> void:
	if tracing:
		# Every line TextParagraph.draw paints (it ignores max_lines_visible) and their total height.
		var lines := []
		var drawn_h := 0.0
		for i in tp.get_line_count():
			lines.append(tp.get_line_range(i))
			drawn_h += tp.get_line_size(i).y
		trace.append(["para", tp.get_size(), pos, lines, drawn_h])
	tp.draw(ci.get_canvas_item(), pos, col, Color(1, 1, 1), text_os)


## Resets the shared style box to a plain fill/border (no shadow) and returns it.
func sbox(fill: Color, border: Color, bw: int, radius: int, with_center: bool = true) -> StyleBoxFlat:
	var sb := _sb
	sb.bg_color = fill
	sb.draw_center = with_center
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	return sb


## Unfilled rounded ring of width `width` on `rect`.
func ring(col: Color, width: float, rect: Rect2, radius: float) -> void:
	ci.draw_style_box(sbox(Color.TRANSPARENT, col, maxi(1, roundi(width)), maxi(1, roundi(radius)), false), rect)


## Filled rounded rect with an optional border `bw` px wide.
func round_rect(rect: Rect2, fill: Color, radius: float, border: Color = Color.TRANSPARENT, bw: float = 0.0) -> void:
	ci.draw_style_box(sbox(fill, border, maxi(1, roundi(bw)) if bw > 0.0 else 0, maxi(1, roundi(radius))), rect)


## Vertical gradient filling `rect` from `top` to `bottom`.
func vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
