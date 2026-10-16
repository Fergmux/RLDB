class_name CardLayouts
extends RefCounted
## Per-kind card-face layouts in card-face space (base units, scaled by the painter): the compact
## 85x128 field unit, the 85x128 power / trap card, the tall hand / mini / big card, the name-only
## own face-down set card, and the empty zone background.

## Corner radius (base units) of the 85x128 board kinds and of the tall kinds.
const RADIUS_SMALL := 6.0
const RADIUS_TALL := 8.0
## Cost gem / type pip radius (base units) and gem text size on the 85x128 kinds.
const SMALL_GEM_R := 9.0
const SMALL_GEM_FS := 12
## Name plate largest / smallest font size on the 85x128 kinds.
const SMALL_NAME_FS := 10.5
const SMALL_NAME_FS_MIN := 8.0
## Rules-text well fill on the tall kinds.
const TEXT_WELL := Color(0.847, 0.8, 0.69, 0.08)

## Tall-card geometry (base units): rects are [x, y, w, h], "gem" is [cx, cy, r], "pip" is [cx, cy].
## The rules-text well is shorter on units (stat badges below it).
const TALL_BIG := {"art": [10, 10, 204, 110], "plate": [10, 100, 204, 32], "line": 136.0, "text_unit": [12, 156, 200, 98], "text_other": [12, 156, 200, 134],
	"chip_y": 258.0, "chip_x": [12.0, 212.0], "chip_rows": 1, "atk": [6, 279, 56, 53], "def": [162, 281, 52, 50], "gem": [27, 27, 17],
	"f_name": 19.0, "f_line": 13.0, "f_text": 13.0, "f_chip": 11.0, "f_stat": 30.0, "f_gem": 21.0, "chip_h": 15.0, "chip_y_nu": 298.0, "chip_rows_nu": 2, "pip": [197, 27]}
const TALL_HAND := {"art": [6, 6, 108, 58], "plate": [6, 52, 108, 22], "line": 76.0, "text_unit": [6, 90, 108, 44], "text_other": [6, 90, 108, 72],
	"chip_y": 136.0, "chip_x": [6.0, 114.0], "chip_rows": 1, "atk": [3, 146, 34, 32], "def": [84, 147, 32, 31], "gem": [17, 17, 11.5],
	"f_name": 12.5, "f_line": 11.0, "f_text": 10.5, "f_chip": 8.5, "f_stat": 17.0, "f_gem": 14.0, "chip_h": 9.5, "chip_y_nu": 164.0, "chip_rows_nu": 1, "pip": [103, 17]}


static func _is_unit(pt: CardPainter) -> bool:
	return String(pt.view.get("category", "")) in CardWidget.UNIT_CATS


## Compact 85x128 field unit card (no rules-text well).
static func draw_square(pt: CardPainter) -> void:
	var is_unit := _is_unit(pt)
	CardFaceParts.frame(pt, RADIUS_SMALL)
	CardArt.draw(pt, pt.r(4, 4, 77, 60))
	# Cost gem and type icon share one size (user feedback).
	CardFaceParts.type_pip(pt, pt.p(72, 13), SMALL_GEM_R / TypeIcons.PIP_K * pt.s)
	CardFaceParts.name_plate(pt, pt.r(4, 52, 77, 20), SMALL_NAME_FS, 0.0, 0.0, pt.accent(), SMALL_NAME_FS_MIN)
	CardChips.draw(pt, 4, 81, 73.0, 9.5, 7.5, 2)
	if is_unit:
		CardStatBadge.draw(pt, pt.r(2, 93, 36, 33), true, 16.0)
		CardStatBadge.draw(pt, pt.r(47, 94, 33, 32), false, 16.0)
	CardFaceParts.gem(pt, pt.p(13, 13), SMALL_GEM_R * pt.s, pt.fs(SMALL_GEM_FS))


## Power / trap card: art, name, short rules text, chips. Same 85x128 portrait.
static func draw_power(pt: CardPainter) -> void:
	CardFaceParts.frame(pt, RADIUS_SMALL)
	CardArt.draw(pt, pt.r(4, 4, 77, 56))
	CardFaceParts.name_plate(pt, pt.r(4, 48, 77, 20), SMALL_NAME_FS, 0.0, 0.0, pt.accent(), SMALL_NAME_FS_MIN)
	CardFaceParts.gem(pt, pt.p(13, 13), SMALL_GEM_R * pt.s, pt.fs(SMALL_GEM_FS))
	var txt := CardText.card_text(pt.view)
	if txt != "":
		var tp := CardTextLayout.para(txt, UIStyle.font_body(), "b", pt.fs(9.0), 77.0 * pt.s, 4)
		tp.draw(pt.ci.get_canvas_item(), pt.p(4, 70), Color(UIStyle.TEXT, 0.9))
	CardChips.draw(pt, 4, 81, 115.0, 10.0, 7.5, 1)


## Tall card with a rules-text well: hand / mini (`big` false, 120x180 base) or big (224x336).
static func draw_tall(pt: CardPainter, big: bool) -> void:
	var is_unit := _is_unit(pt)
	var g: Dictionary = TALL_BIG if big else TALL_HAND
	var s := pt.s
	CardFaceParts.frame(pt, RADIUS_TALL)
	var a: Array = g["art"]
	CardArt.draw(pt, pt.r(a[0], a[1], a[2], a[3]))
	var gm: Array = g["gem"]
	CardFaceParts.type_pip(pt, pt.p(g["pip"][0], g["pip"][1]), float(gm[2]) / TypeIcons.PIP_K * s)   # same size as the cost gem
	var pl: Array = g["plate"]
	CardFaceParts.name_plate(pt, pt.r(pl[0], pl[1], pl[2], pl[3]), g["f_name"], 0.0, 0.0, pt.accent())
	# Type / race line.
	var line_fs := pt.fs(g["f_line"])
	var ly: float = g["line"]
	var lx: float = float(pl[0]) + 4.0
	var lh := float(g["f_line"] + 3) * s
	var t: Array = g["text_unit"] if is_unit else g["text_other"]
	if is_unit:
		CardFaceParts.race_type_line(pt, Vector2(lx * s, ly * s), (float(t[0]) + float(t[2]) - 4.0 - lx) * s, lh, line_fs)
	else:
		# F04-06: the kind is the text only; no colour square (the frame and art already carry the colour).
		pt.text_at(UIStyle.font_italic(), UIStyle.CATEGORY_NAMES.get(pt.view.get("category", ""), ""), pt.p(lx, ly), line_fs, UIStyle.MUTED, -1.0, HORIZONTAL_ALIGNMENT_LEFT, lh)
	# Rules text well.
	var rules := CardText.card_text(pt.view)
	if pt.view.get("support", "full") == "unimplemented":
		rules = "[Effect not implemented] " + rules
	pt.round_rect(pt.r(t[0], t[1], t[2], t[3]), TEXT_WELL, 3.0 * s)
	if rules != "":
		# The whole rules text always fits: the size steps down until it does (user feedback).
		var tp := CardTextLayout.fit_para(rules, UIStyle.font_body(), pt.fs(g["f_text"]), maxi(5, pt.fs(g["f_text"] * 0.55)), (float(t[2]) - 8.0) * s, (float(t[3]) - 3.0) * s)
		tp.draw(pt.ci.get_canvas_item(), pt.p(t[0] + 4, t[1] + 2), UIStyle.TEXT)
	# Chips + stat badges + gem.
	if is_unit:
		var at: Array = g["atk"]
		var df: Array = g["def"]
		CardChips.draw(pt, g["chip_x"][0], g["chip_x"][1], g["chip_y"], g["chip_h"], g["f_chip"], g["chip_rows"])
		CardStatBadge.draw(pt, pt.r(at[0], at[1], at[2], at[3]), true, g["f_stat"])
		CardStatBadge.draw(pt, pt.r(df[0], df[1], df[2], df[3]), false, g["f_stat"])
	else:
		CardChips.draw(pt, g["chip_x"][0], g["chip_x"][1], g["chip_y_nu"], g["chip_h"], g["f_chip"], g["chip_rows_nu"])
	CardFaceParts.gem(pt, pt.p(gm[0], gm[1]), float(gm[2]) * s, pt.fs(g["f_gem"]))


## Name plate across the middle of an own face-down set card, in screen orientation (widget space).
## The back stays identical for every kind: no kind-coloured stripe on the plate (bronze).
static func draw_set_name(pt: CardPainter) -> void:
	var s := pt.s
	var h := 22.0 * s
	CardFaceParts.name_plate(pt, Rect2(pt.cr.position.x + 5.0 * s, pt.cr.get_center().y - h / 2.0, pt.cr.size.x - 10.0 * s, h),
		SMALL_NAME_FS, 0.0, 0.0, UIStyle.CATEGORY_COLORS.get("", UIStyle.BRONZE), SMALL_NAME_FS_MIN)


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
	CardArt.draw_glyph(pt.ci, {"unit": "sword", "trap": "eye", "power": "crown"}[role], r.get_center(), minf(size.x, size.y) * 0.22, Color(1, 1, 1, 0.09))
	# Zones never show a text label ("Front 1", "Trap / Spell 2", ...) — user feedback 2026-10-16.
