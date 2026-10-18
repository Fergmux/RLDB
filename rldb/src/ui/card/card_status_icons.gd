class_name CardStatusIcons
extends RefCounted
## Statuses and Rune counters as icons laid over the card art (2026-10-18 card redesign; they replace
## the text chips). Each icon is a glyph (game-icons.net, CC BY 3.0, see assets/CREDITS.md) on a dark
## token whose shape and rim say what it is, so it never relies on colour alone:
##   buff = round token, green rim;  debuff = rounded-square token, red rim;  Rune = hexagon, blue rim.
## Stacks above 1 (and every Rune count) show as a number badge on the token's lower right.
##
## Every drawn icon records its widget-space rect and label in the painter (CardPainter.hits) so the
## card can show the status name the moment the pointer is over it (StatusTip).

const ICON_DIR := "res://assets/icons/status/"
const BUFF_COLOR := Color("6fd38a")
const DEBUFF_COLOR := Color("e8605a")
const TOKEN := Color(0.05, 0.04, 0.035, 0.92)
const GLYPH := Color(0.97, 0.94, 0.86)
const BADGE := Color(0.06, 0.05, 0.04, 0.97)
## Gap between icons, as a fraction of the icon size.
const GAP_K := 0.12
## Corner radius of a debuff token, as a fraction of its half-size.
const SQUARE_ROUND_K := 0.34

const KIND_BUFF := 1
const KIND_DEBUFF := -1
const KIND_RUNE := 0

static var _tex := {}
## Shared style box for the debuff token and the count badge (draw_style_box emits at once).
static var _sb := StyleBoxFlat.new()


## Entries for the view, Runes first, then CardDB.STATUS_ORDER:
## {"key": status id ("rune" for Rune counters), "n": stacks, "k": kind, "label": tooltip text}.
static func entries(view: Dictionary) -> Array:
	var out := []
	var runes := int(view.get("runes", 0))
	if runes > 0:
		out.append({"key": "rune", "n": runes, "k": KIND_RUNE, "label": label_for("rune", runes)})
	var backrow: bool = view.get("zone", "") == "backrow"
	for s in CardDB.STATUS_ORDER:
		if backrow and s == "reveal":
			continue   # a backrow card shows face up or face down by itself; no Reveal icon there
		var n := int(view.get("statuses", {}).get(s, 0))
		if n > 0:
			out.append({"key": s, "n": n, "k": KIND_BUFF if CardDB.is_buff(s) else KIND_DEBUFF, "label": label_for(s, n)})
	return out


## Tooltip text for `n` stacks of `key`: "Poison ×2", "Rune ×3".
static func label_for(key: String, n: int) -> String:
	return "%s ×%d" % [key.capitalize(), n]


## Rim colour of a token of kind `k`.
static func rim_color(k: int) -> Color:
	match k:
		KIND_BUFF: return BUFF_COLOR
		KIND_DEBUFF: return DEBUFF_COLOR
	return UIStyle.RUNE_BLUE


## The glyph texture of status `key` (null if the icon file is missing).
static func texture(key: String) -> Texture2D:
	if not _tex.has(key):
		var path := ICON_DIR + key + ".svg"
		_tex[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[key]


## Lays the view's icons out in rows of `size`-px icons (base units) from x0 to x1, the first row's
## bottom at `y_bottom`, further rows stacking upward, at most `rows` rows; whatever does not fit
## collapses into a "+N" token at the end of the last row. `align` centres the rows when 0.5.
static func draw_rows(pt: CardPainter, x0: float, x1: float, y_bottom: float, size: float, rows: int, align: float = 0.0) -> void:
	var list := entries(pt.view)
	if list.is_empty():
		return
	var s := pt.s
	var d := size * s
	var gap := d * GAP_K
	var per_row := maxi(1, int(floor(((x1 - x0) * s + gap) / (d + gap))))
	var cap := per_row * rows
	var shown := list
	var more := 0
	if list.size() > cap:
		shown = list.slice(0, cap - 1)
		more = list.size() - shown.size()
	var n_tokens := shown.size() + (1 if more > 0 else 0)
	var i := 0
	var row := 0
	while i < n_tokens:
		var count := mini(per_row, n_tokens - i)
		var row_w := float(count) * d + float(count - 1) * gap
		var x := x0 * s + ((x1 - x0) * s - row_w) * align
		var cy := y_bottom * s - d / 2.0 - float(row) * (d + gap)
		for j in count:
			var c := Vector2(x + d / 2.0 + float(j) * (d + gap), cy)
			if i < shown.size():
				draw_icon(pt, c, d / 2.0, shown[i])
			else:
				_more_token(pt, c, d / 2.0, more, list.slice(shown.size()))
			i += 1
		row += 1


## One status token centred on `c` (face space) with half-size `r`. Records its hit rect.
static func draw_icon(pt: CardPainter, c: Vector2, r: float, e: Dictionary) -> void:
	pt.upright_begin(c)
	draw_token(pt.ci, c, r, String(e["key"]), int(e["n"]), int(e["k"]), true, pt.text_os)
	pt.upright_end()
	_hit(pt, c, r, String(e["label"]), StatusHelp.describe(String(e["key"])))


## The token for `n` stacks of status `key` (kind `k`) on any CanvasItem, centred on `c`, half-size
## `r`; `count` shows the stack badge (above 1, and always for Runes). `text_os` is the text raster
## oversampling (0 = the viewport's own).
static func draw_token(ci: CanvasItem, c: Vector2, r: float, key: String, n: int, k: int, count: bool = true, text_os: float = 0.0) -> void:
	var rim := rim_color(k)
	var bw := maxf(1.0, r * 0.13)
	ci.draw_circle(c + Vector2(0, r * 0.12), r * 1.04, Color(0, 0, 0, 0.45), true, -1.0, true)   # drop shadow
	match k:
		KIND_DEBUFF:
			var sb := _sb
			sb.bg_color = TOKEN
			sb.border_color = rim
			sb.set_border_width_all(maxi(1, roundi(bw)))
			sb.set_corner_radius_all(maxi(1, roundi(r * SQUARE_ROUND_K)))
			sb.anti_aliasing = true
			ci.draw_style_box(sb, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
		KIND_RUNE:
			ci.draw_colored_polygon(CardGeometry.poly(c, r * 1.08, 6, PI / 6.0), rim)
			ci.draw_colored_polygon(CardGeometry.poly(c, r * 1.08 - bw * 1.15, 6, PI / 6.0), TOKEN)
		_:
			ci.draw_circle(c, r, rim, true, -1.0, true)
			ci.draw_circle(c, r - bw, TOKEN, true, -1.0, true)
	var tex := texture(key)
	var g := r * 0.62
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(g, g), Vector2(g, g) * 2.0), false, GLYPH)
	if count and (n > 1 or k == KIND_RUNE):
		_count_badge(ci, c + Vector2(r * 0.74, r * 0.72), r * 0.6, str(n), rim, text_os)


## "+N" token for statuses that did not fit; its tooltip lists them.
static func _more_token(pt: CardPainter, c: Vector2, r: float, more: int, rest: Array) -> void:
	pt.upright_begin(c)
	pt.ci.draw_circle(c, r, UIStyle.MUTED, true, -1.0, true)
	pt.ci.draw_circle(c, r - maxf(1.0, r * 0.13), TOKEN, true, -1.0, true)
	pt.text_c(UIStyle.font_bold(), "+%d" % more, c, maxi(CardPainter.MIN_FS, roundi(r * 1.05)), UIStyle.TEXT)
	pt.upright_end()
	_hit(pt, c, r, "\n".join(rest.map(func(e): return e["label"])), "\n".join(rest.map(func(e): return StatusHelp.describe(String(e["key"])))))


static func _count_badge(ci: CanvasItem, c: Vector2, r: float, txt: String, rim: Color, text_os: float) -> void:
	var font := UIStyle.font_bold()
	var fs := maxi(CardPainter.MIN_FS, roundi(r * 1.6))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := maxf(r * 2.0, tw + r * 0.9)
	var sb := _sb
	sb.bg_color = BADGE
	sb.border_color = rim
	sb.set_border_width_all(maxi(1, roundi(r * 0.18)))
	sb.set_corner_radius_all(maxi(1, roundi(r)))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(c.x - w / 2.0, c.y - r, w, r * 2.0))
	var pos := Vector2(c.x - tw / 2.0, c.y + r * 0.04 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE, TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, text_os)


## Records the widget-space rect of an icon centred on face point `c` (plus a small margin), its
## name and its effect (the tip's second section).
static func _hit(pt: CardPainter, c: Vector2, r: float, label: String, detail: String = "") -> void:
	var face := Rect2(c - Vector2(r, r) * 1.1, Vector2(r, r) * 2.2)
	pt.hits.append({"rect": pt.face_xform() * face, "label": label, "detail": detail})


## A status token as a Control (the card details panel's status rows): `key`, `k` as in entries().
class Token extends Control:
	var key: String
	var kind: int

	func _init(status_key: String, status_kind: int, px: float = 20.0) -> void:
		key = status_key
		kind = status_kind
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		CardStatusIcons.draw_token(self, size / 2.0, minf(size.x, size.y) / 2.0 - 1.0, key, 1, kind, false)
