class_name CardChips
extends RefCounted
## Status chips on the card face: runes and statuses as full-name pills with a shape marker, laid out
## left to right over a number of rows, with a "+N" chip for whatever does not fit.

## Chip `kind` values: +1 buff (up triangle), -1 debuff (down triangle), 0 rune (diamond), 2 neutral (no mark).
const KIND_BUFF := 1
const KIND_DEBUFF := -1
const KIND_RUNE := 0
const KIND_NEUTRAL := 2
const BUFF_COLOR := Color("6fd38a")
const DEBUFF_COLOR := Color("e8605a")
## Vertical gap between chip rows and horizontal gap between chips (base units).
const ROW_GAP := 1.5
const CHIP_GAP := 2.0


## Chip entries for the view: {"t": text, "c": colour, "k": kind}, runes first, then STATUS_ORDER.
static func status_list(view: Dictionary) -> Array:
	var out := []
	if view.get("runes", 0) > 0:
		out.append({"t": "Rune %d" % view["runes"], "c": UIStyle.RUNE_BLUE, "k": KIND_RUNE})
	var backrow: bool = view.get("zone", "") == "backrow"
	for s in CardDB.STATUS_ORDER:
		if backrow and s == "reveal":
			continue   # a backrow card shows face up or face down by itself; no Reveal chip there
		var n: int = view.get("statuses", {}).get(s, 0)
		if n > 0:
			out.append({"t": "%s %d" % [String(s).capitalize(), n], "c": BUFF_COLOR if CardDB.is_buff(s) else DEBUFF_COLOR, "k": KIND_BUFF if CardDB.is_buff(s) else KIND_DEBUFF})
	return out


## Full-name status chips laid out left to right from x0 to x1 at y (base units), chip height `h`,
## over up to `rows` rows; whatever does not fit collapses into a "+N" chip at the end of the last row.
static func draw(pt: CardPainter, x0: float, x1: float, y: float, h: float, fs_base: float, rows: int = 1) -> void:
	var list := status_list(pt.view)
	if list.is_empty():
		return
	var s := pt.s
	var font := UIStyle.font_bold()
	var fs := pt.fs(fs_base)
	var left := x0 * s
	var xmax := x1 * s
	var x := left
	var row := 0
	var i := 0
	while i < list.size():
		var e: Dictionary = list[i]
		var w := font.get_string_size(e["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (h * s * 0.67 + 6.0 * s if int(e["k"]) != KIND_NEUTRAL else 8.0 * s)
		var remaining := list.size() - i - 1
		var last_row := row >= rows - 1
		var reserve := (font.get_string_size("+%d" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * s) if (remaining > 0 and last_row) else 0.0
		if x + w + reserve > xmax and x > left:
			if not last_row:
				row += 1
				x = left
				continue
			var more := list.size() - i
			_chip(pt, x, (y + float(row) * (h + ROW_GAP)) * s, font.get_string_size("+%d" % more, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 7.0 * s, h * s, "+%d" % more, UIStyle.MUTED, font, fs)
			return
		_chip(pt, x, (y + float(row) * (h + ROW_GAP)) * s, w, h * s, e["t"], e["c"], font, fs, int(e["k"]))
		x += w + CHIP_GAP * s
		i += 1


## One chip at (x, y) px, `w` x `h`. The `kind` mark means chips never rely on colour alone.
static func _chip(pt: CardPainter, x: float, y: float, w: float, h: float, text: String, col: Color, font: Font, fs: int, kind: int = KIND_NEUTRAL) -> void:
	var ci := pt.ci
	var s := pt.s
	pt.round_rect(Rect2(x, y, w, h), Color(col.darkened(0.7), 0.95), h / 2.0, col, maxf(1.0, s))
	var tx := x + w / 2.0
	if kind != KIND_NEUTRAL:
		var m := Vector2(x + h * 0.4 + 1.0 * s, y + h / 2.0)
		var a := h * 0.17
		var lc := col.lightened(0.45)
		if kind > 0:
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -a), m + Vector2(a, a), m + Vector2(-a, a)]), lc)
		elif kind < 0:
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, a), m + Vector2(a, -a), m + Vector2(-a, -a)]), lc)
		else:
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -a * 1.2), m + Vector2(a, 0), m + Vector2(0, a * 1.2), m + Vector2(-a, 0)]), lc)
		tx = x + h * 0.67 + 2.0 * s + (w - h * 0.67 - 2.0 * s) / 2.0
	pt.text_c(font, text, Vector2(tx, y + h / 2.0), fs, col.lightened(0.45))
