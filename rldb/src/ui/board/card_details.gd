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
##   abilities - activated abilities: button name, AP/HP cost, once-per-turn, description
##   statuses  - runes and statuses with buff/debuff markers and explanations
##   notes     - why actions are unavailable (muted) and implementation warnings (red)
##
## Hierarchy never relies on colour alone: buff/debuff and stat changes carry a drawn
## triangle marker plus text. Text never drops below 13 px; long cards simply grow taller and
## the owning ScrollContainer scrolls. The compact card thumbnail was intentionally skipped to
## keep the rules text above the fold.
##
## Usage: put the panel (size_flags_horizontal = EXPAND_FILL) inside the sidebar ScrollContainer
## and call show_card(view, notes) / show_empty(hint) whenever the inspected card changes.

const BODY := 15
const SMALL := 13

## Section ids in the order they were built by the last show_* call (used by tests).
var sections: Array[String] = []
## Container inside the Type chip where the TypeIcons glyph can be added later.
var type_icon_slot: HBoxContainer = null


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
	add_child(_lbl(hint, 14, UIStyle.MUTED))


## Renders a card view. `c` = redacted card view ({} -> generic empty hint); `notes` = reasons
## actions are unavailable, e.g. "Cannot attack: ...".
func show_card(c: Dictionary, notes: Array) -> void:
	if c.is_empty():
		show_empty("Hover a card to read it, or click it to pin it here. Right-click or Esc to clear.")
		return
	_reset()
	_build_identity(c)
	if c.has("race"):
		_build_stats(c)
	_build_rules(c)
	if not c.get("abilities", []).is_empty():
		_build_abilities(c)
	_build_statuses(c)
	_build_notes(c, notes)


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
	type_icon_slot = null
	for ch in get_children():
		remove_child(ch)
		ch.free()   # children are passive display nodes; freeing now keeps min-size and tests exact


func _build_identity(c: Dictionary) -> void:
	sections.append("identity")
	var cat: String = c.get("category", "unit")
	var cat_col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.MUTED)
	var name_l := _lbl(String(c.get("name", "?")), 21, UIStyle.GOLD_HI, false, true)
	add_child(name_l)
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 5)
	badges.add_theme_constant_override("v_separation", 4)
	badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(badges)
	badges.add_child(_chip(String(UIStyle.CATEGORY_NAMES.get(cat, cat)).to_upper(), cat_col, "", true))
	badges.add_child(_cost_chip(c))
	if c.has("race"):
		var race: String = String(c.get("race", ""))
		badges.add_child(_chip("Race: " + race if race != "" else "No Race", UIStyle.BRONZE.lightened(0.25)))
		var ty = c.get("type", "")
		var ty_s: String = String(ty) if ty != null else ""
		var tc: Color = UIStyle.type_color(ty_s)
		var chip := _chip("Type: " + ty_s if ty_s != "" else "No Type", tc, "circle")
		# TYPE ICON: the lead adds the TypeIcons glyph into this slot (HBox inside the Type chip).
		type_icon_slot = HBoxContainer.new()
		var hb: HBoxContainer = chip.get_child(0)
		hb.add_child(type_icon_slot)
		hb.move_child(type_icon_slot, 0)
		type_icon_slot.add_child(TypeIcons.TypeBadge.new(ty_s))
		badges.add_child(chip)


func _cost_chip(c: Dictionary) -> Control:
	var kind: String = c.get("cost_kind", "ap")
	var col: Color = UIStyle.COST_COLORS.get(kind, UIStyle.COST_COLORS["ap"])
	var shape: String = {"ap": "circle", "fusion": "diamond", "ritual": "square", "arcane": "hex"}.get(kind, "circle")
	var txt: String
	if kind == "ap":
		var cost = c.get("cost")
		var printed = c.get("printed_cost")
		txt = "Cost %s" % str(cost)
		if cost != null and printed != null and cost != printed:
			txt += " AP (printed %s)" % str(printed)
			col = UIStyle.BAD if cost > printed else UIStyle.GOOD
			return _chip(txt, col, "up" if cost > printed else "down")
		return _chip(txt + " AP", col, shape)
	return _chip("Cost: " + String(c.get("cost_text", "")), col, shape)


func _build_stats(c: Dictionary) -> void:
	sections.append("stats")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	row.add_child(_stat_tile("ATK", c.get("atk"), c.get("printed_atk")))
	row.add_child(_stat_tile("DEF", c.get("def"), c.get("printed_def")))
	var flags := HFlowContainer.new()
	flags.add_theme_constant_override("h_separation", 5)
	flags.add_theme_constant_override("v_separation", 4)
	flags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if c.get("zone", "") == "unit":
		flags.add_child(_chip("Attack stance" if c.get("stance", "atk") == "atk" else "Defense stance", UIStyle.SELECT))
		if c.get("protected", false):
			flags.add_child(_chip("Protected", UIStyle.GOOD))
		if c.get("new", false):
			flags.add_child(_chip("Summoned this turn", UIStyle.MUTED))
		if c.get("attacked", false):
			flags.add_child(_chip("Attacked this turn", UIStyle.MUTED))
		var cu = c.get("controlled_until", -1)
		if cu != null and int(cu) != -1:
			flags.add_child(_chip("Controlled until end of turn %d" % int(cu), UIStyle.BAD))
	if flags.get_child_count() > 0:
		add_child(flags)
	else:
		flags.free()
	var parts: Array = c.get("stat_parts", [])
	var plain: bool = parts.size() <= 1 and c.get("atk") == c.get("printed_atk") and c.get("def") == c.get("printed_def")
	if not parts.is_empty() and not plain:   # a lone "Base a/d" line adds nothing when nothing is modified
		add_child(_lbl("Modifiers", SMALL, UIStyle.GOLD, true))
		for p in parts:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 6)
			r.add_child(Mark.new("dot", UIStyle.MUTED, 10))
			r.add_child(_lbl(String(p), 14, UIStyle.MUTED))
			add_child(r)


## One stat tile: caption + trend line on the left, large current value on the right.
func _stat_tile(cap: String, cur, printed) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UIStyle.flat(UIStyle.PANEL_INK, Color(UIStyle.BRONZE, 0.8), 1, 6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
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
	var col := UIStyle.TEXT
	if cur != null and printed != null and cur != printed:
		var up: bool = cur > printed
		col = UIStyle.GOOD if up else UIStyle.BAD
		trend.add_child(Mark.new("up" if up else "down", col, 10))
		trend.add_child(_lbl("printed %s" % str(printed), SMALL, col, false, false, false))
	else:
		trend.add_child(_lbl("printed %s" % ("?" if printed == null else str(printed)), SMALL, UIStyle.MUTED, false, false, false))
	var num := Label.new()
	num.text = "?" if cur == null else str(cur)
	num.add_theme_font_override("font", UIStyle.font_display(700))
	num.add_theme_font_size_override("font_size", 30)
	num.add_theme_color_override("font_color", col)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(num)
	return pc


func _build_rules(c: Dictionary) -> void:
	var parts: Array = c.get("text_parts", [])
	if parts.is_empty() and String(c.get("text", "")) != "":
		parts = [{"k": "", "t": String(c["text"])}]
	sections.append("rules")
	add_child(_heading("Rules"))
	if parts.is_empty():
		add_child(_lbl("No effect text.", BODY, UIStyle.MUTED))
		return
	for p in parts:
		var k: String = String(p.get("k", ""))
		var col := _timing_color(k)
		var pc := PanelContainer.new()
		var sb := UIStyle.flat(Color(UIStyle.PANEL_INK, 0.85), Color(col, 0.55), 0, 4)
		sb.border_width_left = 3
		sb.content_margin_left = 9
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 4
		pc.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		pc.add_child(vb)
		if k != "":
			vb.add_child(_lbl(k.to_upper(), SMALL, col, true))
		vb.add_child(_lbl(String(p.get("t", "")), BODY, UIStyle.TEXT))
		add_child(pc)


func _build_abilities(c: Dictionary) -> void:
	sections.append("abilities")
	# The full effect is already in the Rules blocks above; this section maps each on-card
	# button name to its cost and limit, with the engine description as the tooltip (D10).
	add_child(_heading("On-card buttons"))
	for a in c["abilities"]:
		var pc := PanelContainer.new()
		var sb := UIStyle.flat(UIStyle.PANEL_LIGHT, Color(UIStyle.GOLD, 0.6), 1, 6)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 5
		pc.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		pc.add_child(vb)
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 5)
		fl.add_theme_constant_override("v_separation", 3)
		vb.add_child(fl)
		var short: String = String(a.get("short", a.get("label", "Ability")))
		fl.add_child(_lbl(short, 15, UIStyle.GOLD_HI, true, false, false))
		if int(a.get("ap", 0)) > 0:
			fl.add_child(_chip("%d AP" % int(a["ap"]), UIStyle.COST_COLORS["ap"], "circle"))
		if int(a.get("hp", 0)) > 0:
			fl.add_child(_chip("%d HP" % int(a["hp"]), UIStyle.BAD, "down"))
		if a.get("opt", false):
			fl.add_child(_chip("Once per turn", UIStyle.MUTED))
		pc.tooltip_text = String(a.get("label", ""))
		if not _rules_mention(c, String(a.get("label", ""))):
			vb.add_child(_lbl(String(a.get("label", "")), 14, UIStyle.TEXT))
		add_child(pc)


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
	var rows: Array = []   # [name, count, kind, help]
	if int(c.get("runes", 0)) > 0:
		rows.append(["Rune", int(c["runes"]), "counter", CardDB.STATUS_HELP["rune"]])
	var st: Dictionary = c.get("statuses", {})
	for s in CardDB.STATUS_ORDER:
		var n: int = int(st.get(s, 0))
		if n > 0:
			rows.append([String(s).capitalize(), n, "buff" if CardDB.is_buff(s) else "debuff", CardDB.STATUS_HELP.get(s, "")])
	if rows.is_empty():
		if c.has("race"):
			sections.append("statuses")
			add_child(_lbl("No statuses.", 14, UIStyle.MUTED))
		return
	sections.append("statuses")
	add_child(_heading("Statuses"))
	for r in rows:
		var kind: String = r[2]
		var col: Color = UIStyle.GOOD if kind == "buff" else (UIStyle.BAD if kind == "debuff" else UIStyle.RUNE_BLUE)
		var pc := PanelContainer.new()
		var sb := UIStyle.flat(Color(UIStyle.PANEL_INK, 0.85), Color(col, 0.6), 0, 4)
		sb.border_width_left = 3
		sb.content_margin_left = 9
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 4
		pc.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		pc.add_child(vb)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		vb.add_child(hb)
		hb.add_child(Mark.new("up" if kind == "buff" else ("down" if kind == "debuff" else "diamond"), col, 11))
		var tag := "Buff" if kind == "buff" else ("Debuff" if kind == "debuff" else "Counter")
		hb.add_child(_lbl("%s ×%d" % [r[0], r[1]], 15, col, true, false, false))
		hb.add_child(_lbl(tag, SMALL, UIStyle.MUTED, false, false, false))
		vb.add_child(_lbl(_strip_status_prefix(String(r[3])), 14, UIStyle.TEXT))
		add_child(pc)


func _build_notes(c: Dictionary, notes: Array) -> void:
	var sup: String = c.get("support", "full")
	if notes.is_empty() and sup == "full":
		return
	sections.append("notes")
	add_child(_heading("Notes"))
	if sup != "full":
		var msg := "Implementation: %s. " % sup
		msg += "Some of this card's effects may not work yet." if sup == "partial" else "This card's effects are not implemented yet."
		add_child(_lbl(msg, 14, UIStyle.BAD))
	for n in notes:
		add_child(_lbl(String(n), 14, UIStyle.MUTED))


# ---------------------------------------------------------------- helpers

## "Burn (debuff): when this ..." -> "When this ..." (the name is already the row title).
static func _strip_status_prefix(help: String) -> String:
	var i := help.find("): ")
	if i < 0:
		return help
	var body := help.substr(i + 3)
	return body.substr(0, 1).to_upper() + body.substr(1)


static func _timing_color(k: String) -> Color:
	match k:
		"Condition", "Materials", "Activates": return UIStyle.RUNE_BLUE
		"On Summon": return UIStyle.GOOD
		"On Field": return UIStyle.GOLD
		"On Destruction": return UIStyle.BAD
		"Effect": return UIStyle.GOLD_HI
	return UIStyle.MUTED


func _collect(n: Node, out: PackedStringArray) -> void:
	if n is Label and (n as Label).text != "":
		out.append((n as Label).text)
	for ch in n.get_children():
		if not ch.is_queued_for_deletion():
			_collect(ch, out)


## Wrapping (by default) label that expands to the available width.
func _lbl(text: String, size: int, color: Color, bold: bool = false, display: bool = false, wrap: bool = true) -> Label:
	var l := UIStyle.label(text, size, color, wrap, display)
	if bold and not display:
		l.add_theme_font_override("font", UIStyle.font_bold())
	if wrap:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 40.0   # lets autowrap shrink below the text's natural width
	return l


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


## Small rounded badge: optional marker shape + text, tinted by `col`.
func _chip(text: String, col: Color, shape: String = "", strong: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	var bg := col.darkened(0.45) if strong else Color(col.darkened(0.6), 0.9)
	var sb := UIStyle.flat(bg, col, 1, 10)
	sb.content_margin_left = 7
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	pc.add_child(hb)
	if shape != "":
		hb.add_child(Mark.new(shape, col, 10))
	var l := _lbl(text, SMALL, UIStyle.TEXT, true, false, false)
	hb.add_child(l)
	return pc
