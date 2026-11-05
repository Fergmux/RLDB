class_name CardStatusIcons
extends RefCounted
## Statuses and Rune counters as icons laid over the card art (2026-10-18 card redesign; they replace
## the text chips). L8 (owner feedback 2026-11-05): each icon is an enamelled badge in the gold-trim
## style, coloured and textured after its effect (Poison dark green with goo, Burn red with flames,
## Paralyse electric yellow with a bolt...), generated as layered SVG by tools/gen_status_badges.py
## (`badge_<key>.svg`; glyphs from game-icons.net, CC BY 3.0, see assets/CREDITS.md). The frame shape
## still says what kind it is, so it never relies on colour alone:
##   buff = round badge;  debuff = rounded-square badge;  Rune = hexagon.
## Stacks above 1 (and every Rune count) show as a gold-rimmed number pill on the badge's lower right.
## The pill's inner ring keeps the kind colour (green buff / red debuff / blue Rune).
##
## Every drawn icon records its widget-space rect and label in the painter (CardPainter.hits) so the
## card can show the status name the moment the pointer is over it (StatusTip).

const ICON_DIR := "res://assets/icons/status/"
## File prefix of the enamelled badges (L8) in ICON_DIR.
const BADGE_PREFIX := "badge_"
## Badge drawn size relative to the token's half-size, per kind (the hexagon's points need room).
const BADGE_K := 1.0
const BADGE_K_RUNE := 1.06
## Count pill colours (gold trim, dark enamel).
const PILL_FILL := Color(0.07, 0.05, 0.03, 0.97)
const PILL_RIM := Color("e0b45a")
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

## L8: the bright accent of each badge's enamel (tooltip names, application effects, floating text).
## One source for every place a status is shown in its own colour.
const ACCENT := {
	"poison": Color("8fe04a"), "burn": Color("ff8a3a"), "paralyse": Color("ffe14a"), "curse": Color("c58af0"),
	"blind": Color("b4b4cc"), "debilitate": Color("d8ccb2"), "reveal": Color("ff8ac8"), "eternal": Color("ffd86a"),
	"cleanse": Color("c4e8ff"), "medic": Color("6fe89a"), "nimble": Color("6ff0e0"), "pierce": Color("dfe8f2"),
	"infiltrate": Color("a8a8ff"), "retain": Color("ffb07a"), "rune": Color("7ab8ff"),
}

static var _tex := {}
static var _badges := {}
## Shared style box for the debuff token and the count badge (draw_style_box emits at once).
static var _sb := StyleBoxFlat.new()
## The count pill's inner kind ring.
static var _sb_ring := StyleBoxFlat.new()


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


## The accent colour of status `key` (ACCENT; the buff / debuff colour for an unknown key).
static func accent(key: String) -> Color:
	if ACCENT.has(key):
		return ACCENT[key]
	return BUFF_COLOR if CardDB.is_buff(key) else DEBUFF_COLOR


## Kind (KIND_BUFF / KIND_DEBUFF / KIND_RUNE) of status `key`.
static func kind_of(key: String) -> int:
	if key == "rune":
		return KIND_RUNE
	return KIND_BUFF if CardDB.is_buff(key) else KIND_DEBUFF


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


## The enamelled badge of status `key` (L8; null if its file is missing: the plain token is drawn).
static func badge(key: String) -> Texture2D:
	if not _badges.has(key):
		var path := ICON_DIR + BADGE_PREFIX + key + ".svg"
		_badges[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _badges[key]


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
	_hit(pt, c, r, String(e["label"]), StatusHelp.describe(String(e["key"])), String(e["key"]))


## The token for `n` stacks of status `key` (kind `k`) on any CanvasItem, centred on `c`, half-size
## `r`; `count` shows the stack badge (above 1, and always for Runes). `text_os` is the text raster
## oversampling (0 = the viewport's own).
static func draw_token(ci: CanvasItem, c: Vector2, r: float, key: String, n: int, k: int, count: bool = true, text_os: float = 0.0) -> void:
	var rim := rim_color(k)
	var bt := badge(key)
	if bt != null:
		var h := r * (BADGE_K_RUNE if k == KIND_RUNE else BADGE_K)
		var br := Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)
		ci.draw_texture_rect(bt, Rect2(br.position + Vector2(0, r * 0.14), br.size), false, Color(0, 0, 0, 0.5))   # drop shadow
		ci.draw_texture_rect(bt, br, false)
		if count and (n > 1 or k == KIND_RUNE):
			_count_badge(ci, c + Vector2(r * 0.76, r * 0.74), r * 0.6, str(n), rim, text_os)
		return
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
	sb.bg_color = PILL_FILL
	sb.border_color = PILL_RIM
	sb.set_border_width_all(maxi(1, roundi(r * 0.2)))
	sb.set_corner_radius_all(maxi(1, roundi(r)))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(c.x - w / 2.0, c.y - r, w, r * 2.0))
	if r >= 5.0:
		# The kind colour as a fine inner ring (green buff, red debuff, blue Rune).
		var ib := r * 0.2 + maxf(0.75, r * 0.1)
		var sb2 := _sb_ring
		sb2.draw_center = false
		sb2.border_color = Color(rim, 0.85)
		sb2.set_border_width_all(maxi(1, roundi(r * 0.1)))
		sb2.set_corner_radius_all(maxi(1, roundi(r - ib)))
		sb2.anti_aliasing = true
		ci.draw_style_box(sb2, Rect2(c.x - w / 2.0 + ib, c.y - r + ib, w - ib * 2.0, r * 2.0 - ib * 2.0))
	var pos := Vector2(c.x - tw / 2.0, c.y + r * 0.04 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE, TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, text_os)


## Records the widget-space rect of an icon centred on face point `c` (plus a small margin), its
## name and its effect (the tip's second section).
static func _hit(pt: CardPainter, c: Vector2, r: float, label: String, detail: String = "", key: String = "") -> void:
	var face := Rect2(c - Vector2(r, r) * 1.1, Vector2(r, r) * 2.2)
	pt.hits.append({"rect": pt.face_xform() * face, "label": label, "detail": detail, "key": key})


## A status token as a Control (the card details panel's status rows, the status tooltip's header):
## `key`, `k` as in entries(). Setting either redraws it.
class Token extends Control:
	var key: String:
		set(v):
			key = v
			queue_redraw()
	var kind: int:
		set(v):
			kind = v
			queue_redraw()

	func _init(status_key: String, status_kind: int, px: float = 20.0) -> void:
		key = status_key
		kind = status_kind
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		CardStatusIcons.draw_token(self, size / 2.0, minf(size.x, size.y) / 2.0 - 1.0, key, 1, kind, false)
