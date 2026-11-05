class_name StatusHelp
extends RefCounted
## Status names in text (owner feedback 2026-10-18): hovering a status name anywhere it is written
## shows its effect at once (StatusTip), and a tooltip whose text names a status gets a separate
## section describing each one.
##
##   StatusHelp.watch_label(label)          # a Label (details panel, prompts): hover a status word
##   StatusHelp.watch_rich(rtl)             # a RichTextLabel whose text went through linkify()
##   rtl.text = StatusHelp.linkify(bbcode)  # wraps status words in [url=status:<key>] links
##   func _make_custom_tooltip(t): return StatusHelp.tooltip(t)   # tooltip + effect section
##
## Status words are matched case-sensitively with a capital first letter, as the card wording
## writes them ("Apply 1 Poison", "Paralysed", "Runes"), so ordinary words are never caught.

## Prefix of the rich-text links linkify() adds.
const META := "status:"
## Wrap width of a tooltip's effect section.
const SECTION_W := 340.0

static var _re: RegEx
static var _by_word: Dictionary = {}


## The pattern of every status word and its inflections, built once.
static func _regex() -> RegEx:
	if _re == null:
		var words := []
		for k in CardDB.STATUS_ORDER + ["rune"]:
			var w: String = String(k).capitalize()
			_by_word[w] = k
			words.append(w)
		_re = RegEx.new()
		_re.compile("\\b(%s)(?:s|d|ed)?\\b" % "|".join(words))
	return _re


## Every status word in `text`: [{"from": index, "to": end index (exclusive), "key": status}].
static func spans(text: String) -> Array:
	var out := []
	for m in _regex().search_all(text):
		out.append({"from": m.get_start(), "to": m.get_end(), "key": _by_word[m.get_string(1)]})
	return out


## The statuses named in `text`, each once, in order of first mention.
static func keys_in(text: String) -> Array:
	var out := []
	for sp in spans(text):
		if not (sp["key"] in out):
			out.append(sp["key"])
	return out


## The status whose word covers character `idx` of `text`, or "".
static func key_at(text: String, idx: int) -> String:
	for sp in spans(text):
		if idx >= int(sp["from"]) and idx < int(sp["to"]):
			return sp["key"]
	return ""


## The effect of status `key` ("Poison: at the end of its controller's turn ..."), or "".
static func describe(key: String) -> String:
	return String(CardDB.STATUS_HELP.get(key, ""))


## `bbcode` with each status word outside existing tags and links wrapped in a status link.
static func linkify(bbcode: String) -> String:
	var out := ""
	var depth := 0                 # inside [url]...[/url]: never nest a link
	var i := 0
	while i < bbcode.length():
		var lb := bbcode.find("[", i)
		var plain := bbcode.substr(i, (lb if lb != -1 else bbcode.length()) - i)
		out += plain if depth > 0 else _link_plain(plain)
		if lb == -1:
			break
		var rb := bbcode.find("]", lb)
		if rb == -1:
			out += bbcode.substr(lb)
			break
		var tag := bbcode.substr(lb, rb - lb + 1)
		if tag.begins_with("[url"):
			depth += 1
		elif tag == "[/url]":
			depth = maxi(0, depth - 1)
		out += tag
		i = rb + 1
	return out


static func _link_plain(text: String) -> String:
	var out := ""
	var at := 0
	for sp in spans(text):
		out += text.substr(at, int(sp["from"]) - at)
		out += "[color=#%s][u][url=%s%s]%s[/url][/u][/color]" % [UIStyle.STATUS_LINK.to_html(false), META, sp["key"], text.substr(int(sp["from"]), int(sp["to"]) - int(sp["from"]))]
		at = int(sp["to"])
	return out + text.substr(at)


## Shows the effect of the status word under the pointer of `label` while it is hovered. The label
## takes the mouse (PASS) so it can see the pointer; clicks still reach what is behind it.
static func watch_label(label: Label) -> void:
	if label.has_meta("status_help"):
		return
	label.set_meta("status_help", true)
	if label.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		label.mouse_filter = Control.MOUSE_FILTER_PASS
	var ink := Ink.new(label)
	label.add_child(ink)
	label.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseMotion:
			_label_hover(label, (e as InputEventMouseMotion).position))
	label.mouse_exited.connect(func(): StatusTip.hide_for(label))


static func _label_hover(label: Label, at: Vector2) -> void:
	var text := label.text
	for sp in spans(text):
		var r := Rect2()
		for c in range(int(sp["from"]), int(sp["to"])):
			var b := label.get_character_bounds(c)
			r = b if r.size == Vector2.ZERO else r.merge(b)
		if r.grow(1.0).has_point(at):
			StatusTip.show_for(label, "", label.get_global_transform_with_canvas() * r, describe(sp["key"]))
			return
	StatusTip.hide_for(label)


## Shows a status link's effect while it is hovered in `rtl` (text from linkify()).
static func watch_rich(rtl: RichTextLabel) -> void:
	if rtl.has_meta("status_help"):
		return
	rtl.set_meta("status_help", true)
	rtl.meta_hover_started.connect(func(meta):
		var m := str(meta)
		if m.begins_with(META):
			var at := rtl.get_local_mouse_position()
			StatusTip.show_for(rtl, "", rtl.get_global_transform_with_canvas() * Rect2(at - Vector2(4, 10), Vector2(8, 20)), describe(m.substr(META.length()))))
	rtl.meta_hover_ended.connect(func(meta):
		if str(meta).begins_with(META):
			StatusTip.hide_for(rtl))
	rtl.mouse_exited.connect(func(): StatusTip.hide_for(rtl))


## A custom tooltip for `text` with a separate section describing each status it names, or null
## (the default tooltip) when it names none.
static func tooltip(text: String) -> Control:
	var keys := keys_in(text)
	if keys.is_empty():
		return null
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var main := UIStyle.label(text, 15, UIStyle.TEXT, true)
	main.custom_minimum_size.x = minf(SECTION_W, UIStyle.font_body().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2.0)
	v.add_child(main)
	var box := section_box()
	var lines := []
	for k in keys:
		lines.append(describe(k))
	box.add_child(section_label("\n".join(lines)))
	v.add_child(box)
	return v


## H8 (owner, 21 Oct): the rich tooltip of card view `v`, coloured like the details panel: the name
## (gold, in the title face) over a kind line, then one block per rules part with its timing caption in
## the panel's timing colour and the same accent bar. J16 (owner, 22 Oct): no blocks describing the
## statuses the card names. `prefix` / `suffix` are the caller's own lines around the card text (a
## role caption, "Right-click to inspect"), shown plainly above / below. Hidden cards get none (null).
static func card_tooltip(v: Dictionary, prefix: String = "", suffix: String = "") -> Control:
	if v.is_empty() or bool(v.get("hidden", false)) or not v.has("name"):
		return null
	var col := VBoxContainer.new()
	col.name = "CardTooltip"
	col.add_theme_constant_override("separation", TIP_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if prefix.strip_edges() != "":
		col.add_child(_tip_label(prefix.strip_edges(), 13, UIStyle.MUTED))
	var nm := UIStyle.label(String(v.get("name", "")), 17, UIStyle.GOLD_HI, false, true)
	nm.name = "TipName"
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var kind := tip_kind_line(v)
	if kind != "":
		var kl := _tip_label(kind, 13, UIStyle.category_text_color(String(v.get("category", ""))))
		kl.name = "TipKind"
		col.add_child(kl)
	var parts: Array = v.get("text_parts", [])
	if parts.is_empty() and String(v.get("text", "")).strip_edges() != "":
		parts = [{"k": "", "t": String(v["text"])}]
	for p0 in parts:
		var p := CardDetailsPanel.split_once_per_turn(p0)
		var k := String(p.get("k", ""))
		var c := CardDetailsPanel.timing_color(k)
		col.add_child(_tip_block(k.to_upper(), String(p.get("t", "")), c, "TipRule"))
	if suffix.strip_edges() != "":
		col.add_child(_tip_label(suffix.strip_edges(), 13, UIStyle.MUTED))
	return col


## Width (px) of the card tooltip's text and the gap between its sections.
const TIP_W := 330.0
const TIP_GAP := 6


## The kind line of a card tooltip: "Fusion Unit · Dragon · Fire", "Spell · 2 AP" ...
static func tip_kind_line(v: Dictionary) -> String:
	var cat := String(v.get("category", ""))
	var bits := [String(UIStyle.CATEGORY_NAMES.get(cat, cat.capitalize()))]
	if String(v.get("cost_kind", "ap")) != "fusion" and String(v.get("cost_text", "")) != "":
		bits.append(String(v["cost_text"]))
	if CardDetailsPanel.is_unit_view(v):
		if String(v.get("race", "")) != "":
			bits.append(String(v["race"]))
		var ty = v.get("type", "")
		if ty != null and String(ty) != "":
			bits.append(String(ty))
	return " · ".join(bits.filter(func(b): return String(b) != ""))


static func _tip_label(text: String, px: int, col: Color) -> Label:
	var l := UIStyle.label(text, px, col, true)
	l.custom_minimum_size.x = TIP_W
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## One section of the card tooltip: the details panel's block (accent bar in `col`) with the caption
## in `col` over the body text.
static func _tip_block(caption: String, body: String, col: Color, name: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.name = name
	pc.set_meta(&"tip_section", name)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", CardDetailsPanel.block_style(col, 0.7, UIStyle.sp("sm")))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(vb)
	if caption != "":
		var cap := UIStyle.label(caption, 12, col)
		cap.add_theme_font_override("font", UIStyle.font_bold())
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(CardDetailsPanel.caption_icon(cap, caption, 14.0))   # L23: the Evolve section's icon
	var bl := UIStyle.label(body, 14, UIStyle.TEXT, true)
	bl.custom_minimum_size.x = TIP_W - float(CardDetailsPanel.BLOCK_BAR_W + 2 * UIStyle.sp("sm"))
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bl)
	return pc


## The card tooltip for a control showing card `v` whose tooltip text is `for_text`: the coloured
## card tooltip when the text holds the card's own tooltip (with the caller's lines around it), else
## the default tooltip (null) for a card, or the plain status-section tooltip when no card is shown.
## J16 (owner, 22 Oct): a card's tooltip never describes statuses.
static func tooltip_for_card(v: Dictionary, for_text: String) -> Control:
	if not v.is_empty() and not bool(v.get("hidden", false)) and v.has("name"):
		var own := CardText.tooltip_for(v)
		var at := for_text.find(own) if own != "" else -1
		if at >= 0:
			return card_tooltip(v, for_text.substr(0, at), for_text.substr(at + own.length()))
		return null
	return tooltip(for_text)


## The darker inset panel of a tooltip's effect section.
static func section_box() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color(0, 0, 0, 0.35), Color(UIStyle.BRONZE, 0.5), 1, 4)
	UIStyle.pad(sb, "md")   # D5: 12 px around the effect text (it was 4-7 px)
	p.add_theme_stylebox_override("panel", sb)
	return p


## The wrapped effect text of a tooltip section.
static func section_label(text: String) -> Label:
	var l := UIStyle.label(text, 14, UIStyle.MUTED, true)
	l.custom_minimum_size.x = SECTION_W
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## D12: draws `tp` (a shaped paragraph, left aligned) at `pos` on canvas item `ci` like TextParagraph.draw,
## but with each status word of `text` in `link` colour and underlined, so it reads as hoverable.
## `oversampling` is the text oversampling the surrounding draw uses (0: the default).
static func draw_marked(ci: CanvasItem, tp: TextParagraph, pos: Vector2, col: Color, text: String, link: Color, oversampling: float = 0.0) -> void:
	var sp := spans(text)
	var y := pos.y
	for i in tp.get_line_count():
		y += draw_marked_line(ci, tp, i, Vector2(pos.x, y), col, sp, link, oversampling)


## Draws line `i` of `tp` with its top-left at `pos` (status words recoloured and underlined, `sp` from
## spans()) and returns the line's height.
static func draw_marked_line(ci: CanvasItem, tp: TextParagraph, i: int, pos: Vector2, col: Color, sp: Array, link: Color, oversampling: float = 0.0) -> float:
	var srv := TextServerManager.get_primary_interface()
	var canvas := ci.get_canvas_item()
	var rid: RID = tp.get_line_rid(i)
	var ofs := pos + Vector2(0.0, srv.shaped_text_get_ascent(rid))
	var rng: Vector2i = tp.get_line_range(i)
	var marks: Array = []             # x ranges (line space) of the status words on this line
	for m in sp:
		var a := maxi(int(m["from"]), rng.x)
		var b := mini(int(m["to"]), rng.y)
		if a < b:
			for r in srv.shaped_text_get_selection(rid, a, b):
				marks.append(r)
	marks.sort_custom(func(p, q): return p.x < q.x)
	var at := -1.0
	for r in marks:
		srv.shaped_text_draw(rid, canvas, ofs, at, r.x, col, oversampling)
		at = r.y
	srv.shaped_text_draw(rid, canvas, ofs, at, -1.0, col, oversampling)
	for r in marks:
		srv.shaped_text_draw(rid, canvas, ofs, r.x, r.y, link, oversampling)
		var uy := ofs.y + srv.shaped_text_get_underline_position(rid) + 0.5
		var th := maxf(1.0, srv.shaped_text_get_underline_thickness(rid))
		ci.draw_rect(Rect2(ofs.x + r.x, uy, r.y - r.x, th), Color(link, 0.9))
	return srv.shaped_text_get_size(rid).y


## Lines of `tp` that show: all of them, or at most its max_lines_visible (the paragraph still
## shapes every line; drawing them all ran a trimmed label's status-word ink past its last line).
static func visible_lines(tp: TextParagraph) -> int:
	var n := tp.get_line_count()
	return mini(n, tp.max_lines_visible) if tp.max_lines_visible > 0 else n


## D12: child of a watched Label. It draws the label's text itself with the status words highlighted
## and underlined, and keeps the label's own text transparent (the label still sizes, wraps, trims
## and answers hover as before). A label naming no status is left alone.
class Ink extends Control:
	var _label: Label
	var _ink: Color = Color.WHITE
	var _hidden: bool = false
	## Lines drawn by the last redraw (tests).
	var drawn_lines: int = 0

	func _init(label: Label) -> void:
		_label = label
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.draw.connect(queue_redraw)
		label.resized.connect(queue_redraw)

	func _draw() -> void:
		var text := _label.text
		var want := not StatusHelp.spans(text).is_empty()
		var cur := _label.get_theme_color("font_color")
		if cur.a > 0.01:
			_ink = cur                      # the label's real text colour (also if it was changed later)
		if not want:
			if _hidden:
				_restore()
			return
		if cur.a > 0.01 or not _hidden:
			_label.add_theme_color_override("font_color", Color(_ink, 0.0))
			_hidden = true
		var font := _label.get_theme_font("font")
		var fs := _label.get_theme_font_size("font_size")
		var tp := TextParagraph.new()
		var wrap := _label.autowrap_mode != TextServer.AUTOWRAP_OFF
		tp.width = _label.size.x if wrap else -1.0
		var flags := TextServer.BREAK_MANDATORY
		match _label.autowrap_mode:
			TextServer.AUTOWRAP_WORD: flags |= TextServer.BREAK_WORD_BOUND
			TextServer.AUTOWRAP_WORD_SMART: flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			TextServer.AUTOWRAP_ARBITRARY: flags |= TextServer.BREAK_GRAPHEME_BOUND
		tp.break_flags = flags
		tp.alignment = _label.horizontal_alignment
		if _label.max_lines_visible > 0:
			tp.max_lines_visible = _label.max_lines_visible
		tp.text_overrun_behavior = _label.text_overrun_behavior
		tp.add_string(text, font, fs)
		var spacing := float(_label.get_theme_constant("line_spacing"))
		var total := tp.get_size().y + spacing * float(maxi(0, tp.get_line_count() - 1))
		var y := 0.0
		match _label.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER: y = (_label.size.y - total) / 2.0
			VERTICAL_ALIGNMENT_BOTTOM: y = _label.size.y - total
		_draw_lines(tp, Vector2(0.0, y), spacing, text)

	func _draw_lines(tp: TextParagraph, pos: Vector2, spacing: float, text: String) -> void:
		# One line at a time so the label's line spacing and alignment are honoured.
		var sp := StatusHelp.spans(text)
		var srv := TextServerManager.get_primary_interface()
		var y := pos.y
		drawn_lines = StatusHelp.visible_lines(tp)
		for i in drawn_lines:
			var lw := srv.shaped_text_get_size(tp.get_line_rid(i)).x
			var dx := 0.0
			match _label.horizontal_alignment:
				HORIZONTAL_ALIGNMENT_CENTER: dx = (_label.size.x - lw) / 2.0
				HORIZONTAL_ALIGNMENT_RIGHT: dx = _label.size.x - lw
			y += StatusHelp.draw_marked_line(self, tp, i, Vector2(pos.x + dx, y), _ink, sp, UIStyle.STATUS_LINK) + spacing

	func _restore() -> void:
		_hidden = false
		_label.add_theme_color_override("font_color", _ink)

	func _exit_tree() -> void:
		if _hidden and is_instance_valid(_label):
			_restore()


## A PanelContainer whose tooltip is the rich one: the text plus a section for each status it names.
## With a card view in its "tip_card" meta (a pile row) it shows the coloured card tooltip (H8).
class TipPanel extends PanelContainer:
	func _make_custom_tooltip(for_text: String) -> Object:
		if has_meta(&"tip_card"):
			return StatusHelp.tooltip_for_card(get_meta(&"tip_card"), for_text)
		return StatusHelp.tooltip(for_text)
