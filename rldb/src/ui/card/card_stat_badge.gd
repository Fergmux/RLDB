class_name CardStatBadge
extends RefCounted
## ATK diamond (gold rim, red gradient) and DEF shield (gold rim, blue gradient) with the live value,
## raised / lowered markers, and the combat-preview decoration (F02-12): glow, dashed ring and a
## "+N" / "-N" tag. Drawn upright even on a rotated (Defense) card.

const ATK_TOP := Color("c9453a")
const ATK_BOTTOM := Color("4d1713")
const DEF_TOP := Color("3f7ab5")
const DEF_BOTTOM := Color("1b3a5a")
## Value colour while previewing, and the "lowered" colour of values, markers and tags.
const PREVIEW_TEXT := Color("eafcff")
const LOWERED := Color("ff8a84")
## Gold rim width (base units) inside the badge outline.
const RIM := 2.4
## F03-20: the badge is drawn at this fraction of the layout rect (about its centre), which leaves a
## margin to the card edge and the art; the font size scales with it.
const SHRINK := 0.86


## Draws the ATK (`is_atk`) or DEF badge filling `rect`. Shows the live value, or the preview value
## in a provisional cyan style while the painter's pv_stat targets this stat.
static func draw(pt: CardPainter, slot_rect: Rect2, is_atk: bool, fs_max: float) -> void:
	var rect := Rect2(slot_rect.get_center() - slot_rect.size * SHRINK / 2.0, slot_rect.size * SHRINK)
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
	if is_atk:
		var pts := CardGeometry.diamond_pts(rect)
		# Perpendicular half-distance from centre to an edge, for an even rim.
		var hw := rect.size.x / 2.0
		var hh := rect.size.y / 2.0
		var edge_d := hw * hh / sqrt(hw * hw + hh * hh)
		var k := 1.0 - (RIM * s) / edge_d
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * k)
		ci.draw_colored_polygon(pts, Color(UIStyle.GOLD, 0.98))
		ci.draw_polygon(inner, PackedColorArray([top.lightened(0.15), top.lerp(bot, 0.45), bot, top.lerp(bot, 0.45)]))
		# Upper facet highlight + rim glint (reads as cut metal).
		ci.draw_colored_polygon(PackedVector2Array([inner[0], inner[1], c + Vector2(0, hh * 0.02), inner[3]]), Color(1, 1, 1, 0.09))
		ci.draw_polyline(PackedVector2Array([pts[3], pts[0], pts[1]]), Color(UIStyle.GOLD_HI, 0.9), maxf(1.0, 0.9 * s), true)
		ci.draw_polyline(CardGeometry.closed(inner), Color(0, 0, 0, 0.35), maxf(1.0, 0.8 * s), true)
	else:
		# Same cut-metal treatment as the ATK diamond: gold rim, light falling from the upper left,
		# a bright upper facet, a glint along the top edges and a dark inner line.
		var outer := CardGeometry.shield_pts(rect)
		ci.draw_colored_polygon(outer, Color(UIStyle.GOLD, 0.98))
		var ins := Rect2(rect.position + Vector2(RIM, RIM) * s, rect.size - Vector2(RIM * 2.0, RIM * 2.0) * s)
		var spts := CardGeometry.shield_pts(ins)
		var cols := PackedColorArray()
		for p in spts:
			var ty := clampf((p.y - ins.position.y) / ins.size.y, 0.0, 1.0)
			var tx := clampf((p.x - ins.position.x) / ins.size.x, 0.0, 1.0)
			cols.append(top.lightened(0.15).lerp(bot, clampf(ty * 0.8 + tx * 0.35, 0.0, 1.0)))
		ci.draw_polygon(spts, cols)
		# Upper facet: the band above the shield's waist, slightly brighter.
		var waist := ins.position.y + ins.size.y * 0.5
		ci.draw_colored_polygon(PackedVector2Array([spts[0], spts[1], spts[2], Vector2(spts[3].x, waist), c + Vector2(0, ins.size.y * 0.02 + waist - c.y), Vector2(spts[5].x, waist), spts[6]]), Color(1, 1, 1, 0.09))
		ci.draw_polyline(PackedVector2Array([outer[5], outer[6], outer[0], outer[1], outer[2], outer[3]]), Color(UIStyle.GOLD_HI, 0.9), maxf(1.0, 0.9 * s), true)
		ci.draw_polyline(CardGeometry.closed(spts), Color(0, 0, 0, 0.35), maxf(1.0, 0.8 * s), true)
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
	var fs := CardTextLayout.fit_stat_fs(font, txt, fs_max, rect, is_atk, s)
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
