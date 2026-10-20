class_name CardStatBadge
extends RefCounted
## ATK diamond (red) and DEF shield (blue) with the live value, raised / lowered markers, and the
## combat-preview decoration (F02-12): glow, dashed ring and a "+N" / "-N" tag. Drawn upright even
## on a rotated (Defense) card. H17 (21 Oct): cut gems (ruby rhombus, sapphire shield) in a slim
## gilded setting, the AP gems' look, kept slim (2026-10-18 "a bit chunky"); the numbers keep their size.

const ATK_TOP := Color("c9453a")
const ATK_BOTTOM := Color("4d1713")
const DEF_TOP := Color("3f7ab5")
const DEF_BOTTOM := Color("1b3a5a")
## Value colour while previewing, and the "lowered" colour of values, markers and tags.
const PREVIEW_TEXT := Color("eafcff")
const LOWERED := Color("ff8a84")
## Depth (base units) of the gilded setting inside the badge outline (H17).
const RIM := 2.1
## Dark outline (base units) around the rim, so the badge reads on light art.
const OUTLINE := 0.9
## Size of the gem's flat table as a share of the girdle (H17): wide, so the number sits on it.
const TABLE_K := 0.62
## F03-20: the badge is drawn at this fraction of the layout rect (about its centre), which leaves a
## margin to the card edge and the art; the font size scales with it.
const SHRINK := 0.86
## Width of each shape as a fraction of its (shrunk) rect: a slightly upright diamond, a narrower
## shield (the old full-width ones read as chunky).
const ATK_W := 0.84
const DEF_W := 0.8


## Draws the ATK (`is_atk`) or DEF badge filling `rect`. Shows the live value, or the preview value
## in a provisional cyan style while the painter's pv_stat targets this stat.
static func draw(pt: CardPainter, slot_rect: Rect2, is_atk: bool, fs_max: float) -> void:
	var rect := shape_rect(slot_rect, is_atk)
	var ci := pt.ci
	var s := pt.s
	var view := pt.view
	var value = view.get("atk" if is_atk else "def")
	var printed = view.get("printed_atk" if is_atk else "printed_def")
	var previewing := pt.pv_stat == ("atk" if is_atk else "def")
	var c := rect.get_center()
	pt.upright_begin(c)   # a Defense (rotated) card still shows its numbers the right way up
	var top := ATK_TOP if is_atk else DEF_TOP
	var bot := ATK_BOTTOM if is_atk else DEF_BOTTOM
	var outer := CardGeometry.diamond_pts(rect) if is_atk else CardGeometry.shield_pts(rect)
	# H17 (21 Oct): a cut ruby rhombus / sapphire shield in a slim gilded setting, the AP gems' look:
	# soft shadow, metal band, crown facets lit from the upper left round a deep table (the white
	# number reads on it), and a glint on the lit shoulder.
	CardJewel.drop_shadow(ci, outer, c, s)
	CardJewel.setting(ci, outer, c, RIM * s, s)
	var girdle := _inset(outer, rect, is_atk, RIM * s)
	CardJewel.gem(ci, girdle, c, top.lerp(bot, 0.15), TABLE_K, false, true)
	var gl := girdle[0].lerp(girdle[3], 0.5).lerp(c, 0.3) if is_atk else girdle[6].lerp(girdle[0], 0.4).lerp(c, 0.22)
	CardJewel.sparkle(ci, gl, maxf(0.9, 1.2 * s), 0.85)
	var tcol := Color.WHITE
	var mod := 0
	var shown_v = value
	if previewing:
		shown_v = pt.pv_value
		tcol = PREVIEW_TEXT
	elif value != null and printed != null and view.get("zone", "") == "unit":
		if value > printed:
			tcol = UIStyle.GOOD
			mod = 1
		elif value < printed:
			tcol = LOWERED
			mod = -1
	var txt := "?" if shown_v == null else str(shown_v)
	var font := UIStyle.font_display(700)
	# The numbers keep their earlier size: fitted to the slot before the shapes were narrowed.
	var fit_rect := Rect2(slot_rect.get_center() - slot_rect.size * SHRINK / 2.0, slot_rect.size * SHRINK)
	var fs := CardTextLayout.fit_stat_fs(font, txt, fs_max, fit_rect, is_atk, s)
	pt.text_c(font, txt, c + Vector2(0, -rect.size.y * (0.0 if is_atk else 0.04)), fs, tcol, maxf(1.5, 1.8 * s))
	if mod != 0:
		var ac := Vector2(c.x, rect.position.y + rect.size.y * (0.15 if is_atk else 0.1))
		var a := 3.0 * s
		if mod > 0:
			ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(0, -a), ac + Vector2(a, a * 0.8), ac + Vector2(-a, a * 0.8)]), UIStyle.GOOD)
		else:
			ac.y = rect.position.y + rect.size.y * (0.85 if is_atk else 0.92)
			ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(0, a), ac + Vector2(a, -a * 0.8), ac + Vector2(-a, -a * 0.8)]), LOWERED)
	if previewing:
		_preview_decor(pt, rect, is_atk)
	pt.upright_end()


## The badge's shape rect inside its layout slot: shrunk about the centre, then narrowed.
static func shape_rect(slot_rect: Rect2, is_atk: bool) -> Rect2:
	var sz := slot_rect.size * SHRINK
	sz.x *= ATK_W if is_atk else DEF_W
	return Rect2(slot_rect.get_center() - sz / 2.0, sz)


## The outline `pts` of the shape in `rect` moved inwards by `d` px: the same shape on a smaller rect.
static func _inset(pts: PackedVector2Array, rect: Rect2, is_atk: bool, d: float) -> PackedVector2Array:
	if is_atk:
		var c := rect.get_center()
		var hw := rect.size.x / 2.0
		var hh := rect.size.y / 2.0
		var edge_d := hw * hh / sqrt(hw * hw + hh * hh)
		var k := 1.0 - d / edge_d
		var out := PackedVector2Array()
		for p in pts:
			out.append(c + (p - c) * k)
		return out
	return CardGeometry.shield_pts(rect.grow(-d))


## Preview glow + dashed white ring around the badge and, when pv_bonus != 0, a "+N"/"-N" tag above it.
static func _preview_decor(pt: CardPainter, rect: Rect2, is_atk: bool) -> void:
	var ci := pt.ci
	var s := pt.s
	var c := rect.get_center()
	var base := CardGeometry.diamond_pts(rect) if is_atk else CardGeometry.shield_pts(rect)
	var glow := CardGeometry.grow_pts(base, c, 3.6 * s)
	var ring := CardGeometry.grow_pts(base, c, 2.4 * s)
	ci.draw_polyline(CardGeometry.closed(glow), Color(UIStyle.PREVIEW, 0.45), maxf(4.0, 4.5 * s), true)
	for i in ring.size():
		ci.draw_dashed_line(ring[i], ring[(i + 1) % ring.size()], Color.WHITE, maxf(2.2, 2.4 * s), 4.0 * s, true, true)
	if pt.pv_bonus == 0:
		return
	var up := pt.pv_bonus > 0
	var font := UIStyle.font_bold()
	var fs := maxi(11, pt.fs(11.5))
	var minus := "−" if font.has_char(0x2212) else "-"
	var tag := "%s%d" % ["+" if up else minus, absi(pt.pv_bonus)]
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ph := maxf(15.0, 14.0 * s)
	var pw := tw + ph * 1.0
	var pc := Vector2(c.x, rect.position.y - 2.0 * s)
	var pr := Rect2(pc - Vector2(pw / 2.0, ph / 2.0), Vector2(pw, ph))
	pt.round_rect(pr, Color(0.03, 0.12, 0.16, 0.96), ph / 2.0, UIStyle.PREVIEW, maxf(1.0, s))
	var m := Vector2(pr.position.x + ph * 0.55, pc.y)
	var a := ph * 0.2
	var tc := UIStyle.GOOD if up else LOWERED
	if up:
		ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -a), m + Vector2(a, a), m + Vector2(-a, a)]), tc)
	else:
		ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, a), m + Vector2(a, -a), m + Vector2(-a, -a)]), tc)
	pt.text_c(font, tag, Vector2(pr.position.x + pw / 2.0 + 3.0 * s, pc.y), fs, tc)
