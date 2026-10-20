class_name CardDetailsPanel
extends VBoxContainer
## Structured card-details panel (F02-08 / F02-05). Replaces the old wall of labels in the
## game screen sidebar. Pure display: it renders a redacted card view (MatchView.card_view)
## and never touches game state.
##
## Sections, top to bottom (each only when it has content):
##   identity  - name, category badge, cost badge, (units) Race / Type chips
##   stats     - (units; no heading, the tiles are self-labelled) ATK / DEF tiles with printed-vs-current markers, stance + flag chips,
##               and the "Modifiers" list from stat_parts
##   rules     - one block per text_parts entry, coloured timing caption + body text
##   abilities - activated abilities not already stated in the rules, in the same block style
##               ("Once per turn" / "Activate" caption with the cost, effect below)
##   statuses  - runes and statuses with buff/debuff markers and explanations (nothing when none)
##
## Hierarchy never relies on colour alone: buff/debuff and stat changes carry a drawn
## triangle marker plus text. Text never drops below 13 px; long cards simply grow taller and
## the owning ScrollContainer scrolls. The compact card thumbnail was intentionally skipped to
## keep the rules text above the fold.
##
## Usage: put the panel (size_flags_horizontal = EXPAND_FILL) inside the sidebar ScrollContainer
## and call show_card(view, notes) / show_empty(hint) whenever the inspected card changes.

## Text sizes (px, before compact scaling): body text, captions / chips, notes and the card name.
const BODY := 15
const SMALL := 13
const NOTE := 14
const TITLE := 21
## Left accent-bar width (px) of rule / status blocks.
const BLOCK_BAR_W := 3

## Compact rendering (pile list rows): every text size scaled down, tighter spacing.
var compact: bool = false
## Text size multiplier (the large card inspector reads at a distance: > 1).
var text_scale: float = 1.0
## Deck-construction rendering (F19): ATK / DEF tiles show one prominent printed value with no
## Base / Current split (they cannot differ outside a match). Off everywhere in a match.
var construction: bool = false
## Section ids in the order they were built by the last show_* call (used by tests).
var sections: Array[String] = []
## #43: open with a wide crop of the card's art (the match sidebar). Off in the other panels.
var art_crop: bool = false
## Height (px) of that crop (the owner sets `art_crop_h` to fit its panel).
const ART_CROP_H := 150.0
var art_crop_h: float = ART_CROP_H


## #43: a wide crop of the card art across the panel: rounded, framed in gold, with a soft vignette into
## the leather at the bottom. The crop keeps the art's upper middle (faces sit there).
class ArtCrop extends Control:
	var tex: Texture2D

	func _init(t: Texture2D, h: float) -> void:
		tex = t
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The texture region shown in a `sz` box: the full width of the (square) art, a band of the box's
	## aspect taken from the upper middle.
	static func region(tex_size: Vector2, sz: Vector2) -> Rect2:
		var w := tex_size.x
		var h := minf(tex_size.y, w * sz.y / maxf(sz.x, 1.0))
		var y := clampf(tex_size.y * 0.3 - h * 0.35, 0.0, tex_size.y - h)
		return Rect2(0, y, w, h)

	func _draw() -> void:
		if tex == null or size.x < 8.0:
			return
		var r := Rect2(Vector2.ZERO, size)
		var rg := region(tex.get_size(), size)
		var pts := UiSurface.round_rect_points(r, 6.0)
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append((rg.position + Vector2(p.x / size.x * rg.size.x, p.y / size.y * rg.size.y)) / tex.get_size())
		draw_colored_polygon(pts, Color.WHITE, uvs, tex)
		# Vignette: the lower third fades into the panel's leather, a light shade along the sides.
		var clear := Color(UIStyle.PANEL, 0.0)
		var dark := Color(UIStyle.PANEL, 0.92)
		var y0 := size.y * 0.55
		draw_polygon(PackedVector2Array([Vector2(1, y0), Vector2(size.x - 1, y0), Vector2(size.x - 1, size.y - 1), Vector2(1, size.y - 1)]),
			PackedColorArray([clear, clear, dark, dark]))
		var side := Color(0, 0, 0, 0.3)
		var sw := minf(28.0, size.x * 0.12)
		draw_polygon(PackedVector2Array([Vector2(1, 1), Vector2(sw, 1), Vector2(sw, size.y - 1), Vector2(1, size.y - 1)]), PackedColorArray([side, clear, clear, side]))
		draw_polygon(PackedVector2Array([Vector2(size.x - sw, 1), Vector2(size.x - 1, 1), Vector2(size.x - 1, size.y - 1), Vector2(size.x - sw, size.y - 1)]), PackedColorArray([clear, side, side, clear]))
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(1)
		ring.set_corner_radius_all(6)
		ring.anti_aliasing = true
		ring.border_color = Color(UIStyle.GOLD, 0.55)
		draw_style_box(ring, r)
		draw_line(Vector2(8, 1.5), Vector2(size.x - 8, 1.5), Color(UIStyle.GOLD_HI, 0.25), 1.0, true)


## Shape marker drawn with primitives so it never depends on font glyph coverage.
class Mark extends Control:
	var shape: String = "up"
	var color: Color = Color.WHITE

	func _init(s: String = "up", c: Color = Color.WHITE, px: int = 12) -> void:
		shape = s
		color = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var ctr := Vector2(w, h) / 2.0
		match shape:
			"up":
				draw_colored_polygon(PackedVector2Array([Vector2(w / 2, 0), Vector2(w, h), Vector2(0, h)]), color)
			"down":
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w / 2, h)]), color)
			"circle":
				draw_circle(ctr, minf(w, h) / 2.0, color)
			"diamond":
				draw_colored_polygon(PackedVector2Array([Vector2(w / 2, 0), Vector2(w, h / 2), Vector2(w / 2, h), Vector2(0, h / 2)]), color)
			"square":
				draw_rect(Rect2(1, 1, w - 2, h - 2), color)
			"hex":
				var pts := PackedVector2Array()
				for i in 6:
					pts.append(ctr + Vector2(cos(TAU * i / 6.0 + PI / 6.0), sin(TAU * i / 6.0 + PI / 6.0)) * (minf(w, h) / 2.0))
				draw_colored_polygon(pts, color)
			"dot":
				draw_circle(ctr, minf(w, h) / 4.0, color)


func _init() -> void:
	add_theme_constant_override("separation", 5)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ---------------------------------------------------------------- public API

## Shows the empty-state hint (nothing inspected).
func show_empty(hint: String) -> void:
	_reset()
	sections.append("empty")
	add_child(_lbl(hint, NOTE, UIStyle.MUTED))


## Renders a card view. `c` = redacted card view ({} -> generic empty hint); `notes` = reasons
## actions are unavailable, e.g. "Cannot attack: ..." (accepted for callers, not displayed).
func show_card(c: Dictionary, _notes: Array = []) -> void:
	if c.is_empty():
		show_empty("Hover a card to read it, or click it to pin it here.")
		return
	_reset()
	if art_crop and not c.get("hidden", false):
		var tex := CardArt.texture_for(c)
		if tex != null:
			sections.append("art")
			add_child(ArtCrop.new(tex, art_crop_h))
	_build_identity(c)
	if is_unit_view(c):
		_build_stats(c)
	_build_rules(c)
	if not c.get("abilities", []).is_empty():
		_build_abilities(c)
	_build_statuses(c)


## All label text currently shown, newline separated (test/debug helper).
func all_text() -> String:
	var out := PackedStringArray()
	_collect(self, out)
	return "\n".join(out)


## Number of times `needle` appears in the shown text.
func count_text(needle: String) -> int:
	if needle == "":
		return 0
	return all_text().count(needle)


# ---------------------------------------------------------------- sections

func _reset() -> void:
	sections.clear()
	for ch in get_children():
		remove_child(ch)
		ch.free()   # children are passive display nodes; freeing now keeps min-size and tests exact


## True when `c` is a unit (it has Race / Type and ATK / DEF). Spells, Traps and Powers carry no such
## section at all (D14: no "No race" / "?" placeholders).
static func is_unit_view(c: Dictionary) -> bool:
	return c.has("race") and CardDB.is_unit_category(String(c.get("category", "unit")))


func _build_identity(c: Dictionary) -> void:
	sections.append("identity")
	var cat: String = c.get("category", "unit")
	var cat_col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.MUTED)
	add_child(_name_title(String(c.get("name", "?"))))
	var badges := _flow()
	add_child(badges)
	badges.add_child(_chip(String(UIStyle.CATEGORY_NAMES.get(cat, cat)), cat_col, "", true))
	if String(c.get("cost_kind", "ap")) != "fusion":   # "Fusion Unit" already says how it is summoned
		badges.add_child(_cost_chip(c))
	if is_unit_view(c):
		var race: String = String(c.get("race", ""))
		badges.add_child(_chip(race if race != "" else "No race", UIStyle.BRONZE.lightened(0.25)))
		var ty = c.get("type", "")
		var ty_s: String = String(ty) if ty != null else ""
		var tc: Color = UIStyle.type_color(ty_s)
		var chip := _chip(ty_s if ty_s != "" else "No type", tc)
		# The type icon leads the Type chip, in its own slot before the text.
		var icon_slot := HBoxContainer.new()
		var hb: HBoxContainer = chip.get_child(0)
		hb.add_child(icon_slot)
		hb.move_child(icon_slot, 0)
		icon_slot.add_child(TypeIcons.TypeBadge.new(ty_s, float(_line_h(SMALL))))
		badges.add_child(chip)


## Cost badge: "N AP" (with the base cost and an up/down marker when changed) or the cost text.
func _cost_chip(c: Dictionary) -> Control:
	var kind: String = c.get("cost_kind", "ap")
	var col: Color = UIStyle.COST_COLORS.get(kind, UIStyle.COST_COLORS["ap"])
	var shape: String = {"ap": "circle", "fusion": "diamond", "ritual": "square", "arcane": "hex"}.get(kind, "circle")
	var txt: String
	if kind == "ap":
		var cost = c.get("cost")
		var printed = c.get("printed_cost")
		txt = "%s AP" % str(cost)
		if cost != null and printed != null and cost != printed:
			txt += " (base %s)" % str(printed)
			col = UIStyle.BAD if cost > printed else UIStyle.GOOD
			return _chip(txt, col, "up" if cost > printed else "down")
		return _chip(txt, col, shape)
	# Ritual / Arcane costs change too (Shimmer Serum, 2026-10-18): same base marker.
	if kind in ["ritual", "arcane"] and int(c.get("uid", -1)) >= 0:
		var rc = c.get("cost")
		var rp = c.get("printed_cost")
		if rc != null and rp != null and rc != rp:
			return _chip("%s (base %s)" % [String(c.get("cost_text", "")), str(rp)], UIStyle.BAD if rc > rp else UIStyle.GOOD, "up" if rc > rp else "down")
	return _chip(String(c.get("cost_text", "")), col, shape)


func _build_stats(c: Dictionary) -> void:
	sections.append("stats")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	row.add_child(_stat_tile("ATK", c.get("atk"), c.get("printed_atk")))
	row.add_child(_stat_tile("DEF", c.get("def"), c.get("printed_def")))
	var flags := _flow()
	if c.get("zone", "") == "unit":
		flags.add_child(_chip("Attack stance" if c.get("stance", "atk") == "atk" else "Defense stance", UIStyle.STATE_STEEL))
		if c.get("protected", false):
			flags.add_child(_chip("Protected", UIStyle.GOOD))
		if c.get("protecting", false):
			flags.add_child(_chip("Protecting", UIStyle.STATE_STEEL))
		var cu = c.get("controlled_until", -1)
		if cu != null and int(cu) != -1:
			flags.add_child(_chip("Controlled until end of turn %d" % int(cu), UIStyle.BAD))
	if flags.get_child_count() > 0:
		add_child(flags)
	else:
		flags.free()
	var parts := modifier_parts(c)
	if not parts.is_empty():   # F03-22: only real changes; no section when there are none
		add_child(_lbl("Modifiers", SMALL, UIStyle.GOLD, true))
		for p in parts:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 6)
			r.add_child(Mark.new("dot", UIStyle.MUTED, 10))
			r.add_child(_lbl(String(p), NOTE, UIStyle.MUTED))
			add_child(r)


## The stat_parts lines that are real changes (buffs, debuffs, effects): the leading
## "Base a/d" line only restates the printed/base stats shown in the stat tiles (F03-22).
static func modifier_parts(c: Dictionary) -> Array:
	var out := []
	for p in c.get("stat_parts", []):
		var s := String(p)
		if s.begins_with("Base ") and s.substr(5).split("/").size() == 2 and s.substr(5).replace("/", "").is_valid_int():
			continue
		out.append(s)
	return out


## #45: the stat tiles' edges echo the card badges (ATK red, DEF blue) at STAT_EDGE_A.
const STAT_EDGE := {"ATK": Color("e8605a"), "DEF": Color("5aa2ff")}
const STAT_EDGE_A := 0.4
const BASE_PX := 12


## H11 (owner, 21 Oct): the match tiles are short: one row with the caption over its "Base: N" line on
## the left and the current value on the right, in TILE_PAD_X / TILE_PAD_Y padding.
const TILE_PAD_X := 10
const TILE_PAD_Y := 5
## The current value's size (px) in a match tile (compact rows: 20).
const STAT_PX := 26


## One stat tile (#45): an F3 inset with an ATK-red / DEF-blue edge. In a match (H11) the caption sits
## over "Base: N" at the left and the value (with its up / down marker when changed) at the right,
## in one short row.
func _stat_tile(cap: String, cur: Variant, printed: Variant) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UIStyle.inset_style(UIStyle.PANEL_INK, 6)
	sb.base.border_color = Color(STAT_EDGE.get(cap, UIStyle.BRONZE), STAT_EDGE_A)
	sb.base.set_border_width_all(1)
	if compact:
		UIStyle.pad(sb, "sm", "xs")
	elif construction:
		UIStyle.pad(sb, "md", "md")   # D5: the construction tile's 36 px number keeps its 12 px
	else:
		sb.base.content_margin_left = TILE_PAD_X
		sb.base.content_margin_right = TILE_PAD_X
		sb.base.content_margin_top = TILE_PAD_Y
		sb.base.content_margin_bottom = TILE_PAD_Y
	sb.base = sb.base
	pc.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	pc.add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	left.add_child(_lbl(cap, SMALL, UIStyle.GOLD, true, false, false))
	var trend := HBoxContainer.new()
	trend.add_theme_constant_override("separation", 4)
	left.add_child(trend)
	if construction:
		return _plain_stat_tile(pc, hb, left, trend, cap, printed if printed != null or cur == null else cur)
	left.remove_child(trend)
	trend.free()
	var cap_l := left.get_child(0) as Label
	cap_l.add_theme_font_override("font", UIStyle.font_display(700))
	cap_l.add_theme_font_size_override("font_size", _fs(14))
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var base_l := _lbl("Base: %s" % ("?" if printed == null else str(printed)), BASE_PX - 1, UIStyle.MUTED, false, false, false)
	left.add_child(base_l)
	var col := UIStyle.TEXT
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 4)
	nrow.alignment = BoxContainer.ALIGNMENT_END
	nrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cur != null and printed != null and cur != printed:
		var up: bool = cur > printed
		col = UIStyle.GOOD if up else UIStyle.BAD
		nrow.add_child(Mark.new("up" if up else "down", col, 11))   # beside the resulting value
	var num := Label.new()
	num.text = "?" if cur == null else str(cur)
	num.add_theme_font_override("font", UIStyle.font_display(700))
	num.add_theme_font_size_override("font_size", _fs(STAT_PX) if not compact else 20)
	num.add_theme_color_override("font_color", col)
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	num.add_theme_constant_override("outline_size", 3)
	nrow.add_child(num)
	hb.add_child(nrow)
	return pc


## Construction-mode tile body: big caption on the left, large value on the right. A printed
## value of null (dynamic stat, e.g. "copies the target") reads "?" with a "Varies" note.
func _plain_stat_tile(pc: PanelContainer, hb: HBoxContainer, left: VBoxContainer, trend: HBoxContainer, cap: String, value: Variant) -> Control:
	left.remove_child(trend)
	trend.free()
	var cap_l := left.get_child(0) as Label
	cap_l.add_theme_font_override("font", UIStyle.font_display(700))
	cap_l.add_theme_font_size_override("font_size", _fs(17))
	cap_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	if value == null:
		left.add_child(_lbl("Varies", SMALL, UIStyle.MUTED, false, false, false))
	var num := Label.new()
	num.text = "?" if value == null else str(value)
	num.add_theme_font_override("font", UIStyle.font_display(700))
	num.add_theme_font_size_override("font_size", _fs(36) if not compact else 24)
	num.add_theme_color_override("font_color", UIStyle.GOLD_HI if value == null else UIStyle.TEXT)
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	num.add_theme_constant_override("outline_size", 4)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(num)
	# D5: the tile keeps the md padding of _stat_tile (a 6 px override put the 36 px number on the rim).
	return pc


func _build_rules(c: Dictionary) -> void:
	var parts: Array = c.get("text_parts", [])
	if parts.is_empty() and String(c.get("text", "")) != "":
		parts = [{"k": "", "t": String(c["text"])}]
	if parts.is_empty():
		return   # no effect: no Rules section at all (user feedback)
	sections.append("rules")
	add_child(_heading("Rules"))
	for p0 in parts:
		var p := split_once_per_turn(p0)
		var k: String = String(p.get("k", ""))
		var col := _timing_color(k)
		add_child(_rule_block(k, String(p.get("t", "")), col))


## One timing block: coloured caption (e.g. ON SUMMON, ONCE PER TURN) over the effect text.
func _rule_block(caption: String, body: String, col: Color) -> PanelContainer:
	var pc := _block(col, 0.55)
	var vb: VBoxContainer = pc.get_child(0)
	if caption != "":
		vb.add_child(_lbl(caption.to_upper(), SMALL, col, true))
	var bl := _lbl(body, BODY, UIStyle.TEXT)
	StatusHelp.watch_label(bl)      # hover a status name: its effect (2026-10-18)
	vb.add_child(bl)
	return pc


## A rules part whose text starts with "Once per turn" gets that as its caption (user feedback:
## every effect reads as caption + effect): {"k": "On Field", "t": "Once per turn: you can ..."}
## -> {"k": "Once per turn", "t": "You can ..."}.
static func split_once_per_turn(part: Dictionary) -> Dictionary:
	var t := String(part.get("t", ""))
	if not t.to_lower().begins_with("once per turn"):
		return part
	var rest := t.substr(13).lstrip(" :,").strip_edges()
	if rest == "":
		return part
	return {"k": "Once per turn", "t": rest.substr(0, 1).to_upper() + rest.substr(1)}


func _build_abilities(c: Dictionary) -> void:
	# Abilities the rules text already states are not repeated; any other one gets a block in the
	# timing style: caption ("Once per turn" or "Activate", plus its cost) over the effect.
	var extra := []
	for a in c["abilities"]:
		if not _rules_mention(c, String(a.get("label", ""))):
			extra.append(a)
	if extra.is_empty():
		return
	sections.append("abilities")
	for a in extra:
		var cap := "Once per turn" if a.get("opt", false) else "Activate"
		var costs := []
		if int(a.get("ap", 0)) > 0:
			costs.append("%d AP" % int(a["ap"]))
		if int(a.get("hp", 0)) > 0:
			costs.append("%d HP" % int(a["hp"]))
		if not costs.is_empty():
			cap += " · " + ", ".join(costs)
		add_child(_rule_block(cap, String(a.get("label", "")), _timing_color("Once per turn")))


## Whether the card's rules text already states this ability (most of its words appear there).
func _rules_mention(c: Dictionary, label: String) -> bool:
	var rules := String(c.get("text", "")).to_lower()
	var hit := 0
	var long_words := 0
	for w in label.to_lower().replace(":", " ").replace(",", " ").split(" ", false):
		if w.length() > 3:
			long_words += 1
			if rules.contains(w):
				hit += 1
	return long_words > 0 and float(hit) / float(long_words) >= 0.6


func _build_statuses(c: Dictionary) -> void:
	var rows: Array = []   # [name, count, kind, help, key]
	if int(c.get("runes", 0)) > 0:
		rows.append(["Rune", int(c["runes"]), "counter", CardDB.STATUS_HELP["rune"], "rune"])
	var st: Dictionary = c.get("statuses", {})
	for s in CardDB.STATUS_ORDER:
		var n: int = int(st.get(s, 0))
		if n > 0:
			rows.append([String(s).capitalize(), n, "buff" if CardDB.is_buff(s) else "debuff", CardDB.STATUS_HELP.get(s, ""), s])
	if rows.is_empty():
		return
	sections.append("statuses")
	add_child(_heading("Statuses"))
	for r in rows:
		var kind: String = r[2]
		var col: Color = UIStyle.GOOD if kind == "buff" else (UIStyle.BAD if kind == "debuff" else UIStyle.RUNE_BLUE)
		var pc := _block(col, 0.6)
		var vb: VBoxContainer = pc.get_child(0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		vb.add_child(hb)
		# The same icon the card shows over its art (token shape: buff round, debuff square, Rune hexagon).
		var tk := CardStatusIcons.Token.new(String(r[4]), CardStatusIcons.KIND_BUFF if kind == "buff" else (CardStatusIcons.KIND_DEBUFF if kind == "debuff" else CardStatusIcons.KIND_RUNE), roundf(20.0 * text_scale))
		tk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tk)
		var tag := "Buff" if kind == "buff" else ("Debuff" if kind == "debuff" else "Counter")
		hb.add_child(_lbl("%s ×%d" % [r[0], r[1]], 15, col, true, false, false))
		if kind != "counter":   # runes need no "Counter" tag (user feedback)
			hb.add_child(_lbl(tag, SMALL, UIStyle.MUTED, false, false, false))
		vb.add_child(_lbl(_strip_status_prefix(String(r[3])), NOTE, UIStyle.TEXT))
		add_child(pc)


# ---------------------------------------------------------------- helpers

## "Burn: when this ..." -> "When this ..." (the name is already the row title).
static func _strip_status_prefix(help: String) -> String:
	var i := help.find(": ")
	if i < 0:
		return help
	var body := help.substr(i + 2)
	return body.substr(0, 1).to_upper() + body.substr(1)


## Caption colour of a rules timing ("On Summon", "Once per turn", ...).
static func _timing_color(k: String) -> Color:
	match k:
		"Condition", "Materials", "Activates": return UIStyle.RUNE_BLUE
		"On Summon": return UIStyle.GOOD
		"On Field": return UIStyle.GOLD
		"On Destruction": return UIStyle.BAD
		"Effect": return UIStyle.GOLD_HI
		"Once per turn": return Color("e0b25a")
	return UIStyle.MUTED


## Appends the text of every non-empty Label under `n` (depth first) to `out`.
func _collect(n: Node, out: PackedStringArray) -> void:
	if n is Label and (n as Label).text != "":
		out.append((n as Label).text)
	for ch in n.get_children():
		if not ch.is_queued_for_deletion():
			_collect(ch, out)


## Card name size range (design review #44): T2 at NAME_PX, shrinking to NAME_MIN_PX before it wraps.
const NAME_PX := 20
const NAME_MIN_PX := 16


## The card name as a T2 screen title (TitleText SCREEN, D3). It shrinks from NAME_PX to NAME_MIN_PX
## to stay on one line; a name still too long splits after its first comma ("Boom," / "Councillor of
## the Order"), else word-wraps. Refitted whenever its width changes.
func _name_title(text: String) -> Label:
	var l := _lbl(text, NAME_PX, UIStyle.GOLD_HI, false, true, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40.0
	l.set_meta(&"full_name", text)
	TitleText.apply(l, TitleText.Tier.SCREEN, _fs(NAME_PX))
	l.resized.connect(_fit_name.bind(l))
	return l


## Fits the name title `l` to its width (see _name_title). Pure layout, no state.
func _fit_name(l: Label) -> void:
	if not is_instance_valid(l) or l.size.x < 41.0:
		return
	var plan := name_fit(String(l.get_meta(&"full_name", l.text)), l.size.x, _fs(NAME_PX), _fs(NAME_MIN_PX))
	if l.text != String(plan["text"]):
		l.text = plan["text"]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if bool(plan["wrap"]) else TextServer.AUTOWRAP_OFF
	if l.get_theme_font_size("font_size") != int(plan["size"]):
		l.add_theme_font_size_override("font_size", int(plan["size"]))


## How a card name fits `width` px: {text, size, wrap}. The largest size from `px` down to `min_px`
## that keeps it on one line; else `min_px` with a break after the first comma when both halves fit,
## else `min_px` word-wrapped.
static func name_fit(text: String, width: float, px: int, min_px: int) -> Dictionary:
	var font := TitleText.tier_font(TitleText.Tier.SCREEN)
	for fs in range(px, min_px - 1, -1):
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
			return {"text": text, "size": fs, "wrap": false}
	var at := text.find(", ")
	if at > 0:
		var a := text.substr(0, at + 1)
		var b := text.substr(at + 2)
		if font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, min_px).x <= width and font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, min_px).x <= width:
			return {"text": a + "\n" + b, "size": min_px, "wrap": false}
	return {"text": text, "size": min_px, "wrap": true}


## Wrapping (by default) label that expands to the available width.
func _lbl(text: String, size: int, color: Color, bold: bool = false, display: bool = false, wrap: bool = true) -> Label:
	var l := UIStyle.label(text, _fs(size), color, wrap, display)
	if bold and not display:
		l.add_theme_font_override("font", UIStyle.font_bold())
	if wrap:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 40.0   # lets autowrap shrink below the text's natural width
	return l


## Section heading: gold caption followed by a bronze rule line.
func _heading(text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(_lbl(text.to_upper(), SMALL, UIStyle.GOLD, true, false, false))
	var line := HSeparator.new()
	var sl := StyleBoxLine.new()
	sl.color = Color(UIStyle.BRONZE, 0.9)
	sl.thickness = 1
	line.add_theme_stylebox_override("separator", sl)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(line)
	return hb


## Wrapping row for badges / flag chips, full width.
func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 5)
	f.add_theme_constant_override("v_separation", 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


## Rule / status block: dark panel with a left accent bar in `col` (bar alpha `bar_a`) holding an
## empty zero-separation VBoxContainer (its first child) for the content.
func _block(col: Color, bar_a: float) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIStyle.flat(Color(UIStyle.PANEL_INK, 0.85), Color(col, bar_a), 0, 4)
	sb.border_width_left = BLOCK_BAR_W
	# D5: the text keeps the 12 px content floor from the block's edges (it sat 3-6 px from them);
	# the compact pile rows keep the 8 px chip scale.
	var pad := UIStyle.CONTENT_FLOOR if not compact else UIStyle.sp("sm")
	sb.content_margin_left = BLOCK_BAR_W + pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	pc.add_child(vb)
	return pc


## Font size a label of base size `size` really gets (compact rows scale down).
func _fs(size: int) -> int:
	return roundi(size * text_scale) if not compact else maxi(10, roundi(size * 0.8))


## Text line height (px) at base size `size`: the height every tag's content is held to, so an
## icon or marker never makes one tag taller than its peers (F03-03).
func _line_h(size: int) -> int:
	return ceili(UIStyle.font_body().get_height(_fs(size)))


## Small rounded badge: optional marker shape + text, tinted by `col`. Every badge has the same
## height (text line + fixed padding); icons and markers are centred inside it, never larger.
func _chip(text: String, col: Color, shape: String = "", strong: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	var bg := col.darkened(0.45) if strong else Color(col.darkened(0.6), 0.9)
	var sb := UIStyle.flat(bg, col, 1, 10)
	sb.content_margin_left = 7
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.y = _line_h(SMALL) + sb.content_margin_top + sb.content_margin_bottom
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(hb)
	if shape != "":
		hb.add_child(Mark.new(shape, col, 10))
	var l := _lbl(text, SMALL, UIStyle.TEXT, true, false, false)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	return pc
