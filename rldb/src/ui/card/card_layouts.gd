class_name CardLayouts
extends RefCounted
## Per-kind card-face layouts in card-face space (base units, scaled by the painter). Redesigned
## 2026-10-18 around the square card art, which is the largest thing on every card:
##
## - FIELD (85x128 "board" unit): square art across the top, the name banner over the art's
##   lower edge, big ATK / DEF badges in the bottom strip. Rules live in the sidebar and inspector.
## - FIELD Power / Trap (85x128): the same art and banner, a short rules text in the bottom strip.
## - TALL (hand 120x180, mini, big 224x336 = the hand layout scaled): square art; the ATK / DEF badges
##   sit on the art's lower corners so the rules text below the banner gets the whole width.
##
## Everywhere: cost gem on the art's top left, Type pip on its top right, statuses and Runes as
## icons over the art's lower edge (CardStatusIcons), the banner right under them.

## Corner radius (base units) of the 85x128 board kinds and of the tall kinds.
const RADIUS_SMALL := 6.0
const RADIUS_TALL := 8.0
## Rules-text well fill on the tall kinds.
const TEXT_WELL := Color(0.847, 0.8, 0.69, 0.07)

## Geometry (base units): rects are [x, y, w, h], points [x, y]; "gem_r" is the cost gem radius.
## "icons" is [x0, x1, bottom y, icon size, rows].
const FIELD := {"art": [3, 3, 79, 79], "banner": [2, 73, 81, 19], "gem": [12, 12], "gem_r": 9.0, "pip": [73, 12],
	"icons": [4, 81, 72, 14.0, 2], "atk": [1, 93, 36, 34], "def": [48, 93, 36, 34], "text": [5, 94, 75, 31],
	"f_name": 10.5, "f_name_min": 7.5, "f_gem": 12.0, "f_stat": 17.0, "f_text": 8.5}
const TALL := {"art": [4, 4, 112, 112], "banner": [2, 100, 116, 19], "gem": [16, 16], "gem_r": 11.5, "pip": [104, 16],
	"icons": [6, 114, 98, 13.0, 2], "icons_unit": [35, 85, 98, 13.0, 3], "atk": [0, 66, 36, 34], "def": [84, 67, 36, 33],
	"line": [6, 120, 108, 10], "text": [4, 131, 112, 45],
	"f_name": 12.5, "f_name_min": 8.0, "f_gem": 14.0, "f_stat": 18.0, "f_line": 9.5, "f_text": 10.0}
## Smallest rules-text size, as a fraction of the layout's text size.
const TEXT_MIN_K := 0.5


static func _is_unit(pt: CardPainter) -> bool:
	return String(pt.view.get("category", "")) in CardWidget.UNIT_CATS


static func _r(pt: CardPainter, a: Array) -> Rect2:
	return pt.r(a[0], a[1], a[2], a[3])


## Compact 85x128 field unit: art, banner, ATK / DEF.
static func draw_square(pt: CardPainter) -> void:
	var g := FIELD
	CardFaceParts.frame(pt, RADIUS_SMALL)
	CardArt.draw(pt, _r(pt, g["art"]))
	_art_corners(pt, g)
	_icons(pt, g["icons"], 0.0)
	CardFaceParts.name_plate(pt, _r(pt, g["banner"]), g["f_name"], 0.0, 0.0, pt.accent(), g["f_name_min"])
	if _is_unit(pt):
		CardStatBadge.draw(pt, _r(pt, g["atk"]), true, g["f_stat"])
		CardStatBadge.draw(pt, _r(pt, g["def"]), false, g["f_stat"])
	CardFaceParts.gem(pt, pt.p(g["gem"][0], g["gem"][1]), float(g["gem_r"]) * pt.s, pt.fs(g["f_gem"]))


## Field Power / Trap (85x128): art, banner, short rules text.
static func draw_power(pt: CardPainter) -> void:
	var g := FIELD
	CardFaceParts.frame(pt, RADIUS_SMALL)
	CardArt.draw(pt, _r(pt, g["art"]))
	_icons(pt, g["icons"], 0.0)
	CardFaceParts.name_plate(pt, _r(pt, g["banner"]), g["f_name"], 0.0, 0.0, pt.accent(), g["f_name_min"])
	var txt := CardText.card_text(pt.view)
	if txt != "":
		var t: Array = g["text"]
		var tp := CardTextLayout.fit_para(txt, UIStyle.font_body(), pt.fs(g["f_text"]), maxi(CardPainter.MIN_FS - 1, pt.fs(g["f_text"] * 0.7)), float(t[2]) * pt.s, float(t[3]) * pt.s)
		pt.para_text(tp, pt.p(t[0], t[1]), Color(UIStyle.TEXT, 0.9), txt)
	CardFaceParts.gem(pt, pt.p(g["gem"][0], g["gem"][1]), float(g["gem_r"]) * pt.s, pt.fs(g["f_gem"]))


## Tall card (hand / mini 120x180 base, big 224x336 drawn from the same layout at a larger scale):
## art with the ATK / DEF badges on its lower corners, banner, race / Type line, rules text well.
static func draw_tall(pt: CardPainter, _big: bool = false) -> void:
	var g := TALL
	var s := pt.s
	var is_unit := _is_unit(pt)
	CardFaceParts.frame(pt, RADIUS_TALL)
	CardArt.draw(pt, _r(pt, g["art"]))
	_art_corners(pt, g)
	_icons(pt, g["icons_unit"] if is_unit else g["icons"], 0.5)
	# Race / Type line (units) or the card kind (Spells, Traps, Powers).
	var ln: Array = g["line"]
	var line_fs := pt.fs(g["f_line"])
	if is_unit:
		CardFaceParts.race_type_line(pt, pt.p(ln[0], ln[1]), float(ln[2]) * s, float(ln[3]) * s, line_fs)
	else:
		pt.text_at(UIStyle.font_italic(), UIStyle.CATEGORY_NAMES.get(pt.view.get("category", ""), ""), pt.p(ln[0], ln[1]), line_fs, UIStyle.MUTED, float(ln[2]) * s, HORIZONTAL_ALIGNMENT_CENTER, float(ln[3]) * s)
	# Rules text well: the whole text always fits, the size steps down until it does (user feedback).
	var t: Array = g["text"]
	var rules := CardText.card_text(pt.view)
	if pt.view.get("support", "full") == "unimplemented":
		rules = "[Effect not implemented] " + rules
	pt.round_rect(_r(pt, t), TEXT_WELL, 3.0 * s)
	if rules != "":
		var tp := CardTextLayout.fit_para(rules, UIStyle.font_body(), pt.fs(g["f_text"]), maxi(5, pt.fs(g["f_text"] * TEXT_MIN_K)), (float(t[2]) - 6.0) * s, (float(t[3]) - 3.0) * s)
		pt.para_text(tp, pt.p(float(t[0]) + 3.0, float(t[1]) + 1.5), UIStyle.TEXT, rules)
	else:
		# No rules (Basic Units): a faint kind emblem instead of an empty well.
		var wr := _r(pt, t)
		CardArt.draw_glyph(pt.ci, CardArt._glyph_kind(pt.view), wr.get_center(), wr.size.y * 0.3, Color(UIStyle.GOLD, 0.16))
	CardFaceParts.name_plate(pt, _r(pt, g["banner"]), g["f_name"], 0.0, 0.0, pt.accent(), g["f_name_min"])
	if is_unit:
		CardStatBadge.draw(pt, _r(pt, g["atk"]), true, g["f_stat"])
		CardStatBadge.draw(pt, _r(pt, g["def"]), false, g["f_stat"])
	CardFaceParts.gem(pt, pt.p(g["gem"][0], g["gem"][1]), float(g["gem_r"]) * s, pt.fs(g["f_gem"]))


## The Type pip on the art's top right (same size as the cost gem, user feedback).
static func _art_corners(pt: CardPainter, g: Dictionary) -> void:
	CardFaceParts.type_pip(pt, pt.p(g["pip"][0], g["pip"][1]), float(g["gem_r"]) / TypeIcons.PIP_K * pt.s)


static func _icons(pt: CardPainter, a: Array, align: float) -> void:
	CardStatusIcons.draw_rows(pt, a[0], a[1], a[2], a[3], a[4], align)


## Name plate across the middle of an own face-down set card, in screen orientation (widget space).
## The back stays identical for every kind: no kind-coloured stripe on the plate (bronze).
static func draw_set_name(pt: CardPainter) -> void:
	var s := pt.s
	var h := 22.0 * s
	CardFaceParts.name_plate(pt, Rect2(pt.cr.position.x + 5.0 * s, pt.cr.get_center().y - h / 2.0, pt.cr.size.x - 10.0 * s, h),
		FIELD["f_name"], 0.0, 0.0, UIStyle.CATEGORY_COLORS.get("", UIStyle.BRONZE), FIELD["f_name_min"])


## Empty zone background filling `size` (unit / trap / power tint by `size_kind`), brighter while a target.
static func draw_empty(pt: CardPainter, size: Vector2, highlighted: bool) -> void:
	var s := pt.s
	var role := "unit"
	match pt.size_kind:
		"trap": role = "trap"
		"power": role = "power"
	var tint: Color = UIStyle.ZONE_TINT[role]
	var r := Rect2(Vector2.ZERO, size)
	var rad := 8.0 * s
	var fill := Color(tint, 0.62)
	if highlighted:
		fill = Color(tint.lightened(0.25), 0.85)
	pt.round_rect(r, fill, rad, Color(UIStyle.BRONZE, 0.55), maxf(1.0, s))
	pt.vgrad(Rect2(2 * s, 2 * s, size.x - 4 * s, 12 * s), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	CardArt.draw_glyph(pt.ci, {"unit": "sword", "trap": "eye", "power": "crown"}[role], r.get_center(), minf(size.x, size.y) * 0.25, Color(1, 1, 1, 0.17))
	# Zones never show a text label ("Front 1", "Trap / Spell 2", ...) — user feedback 2026-10-16.
