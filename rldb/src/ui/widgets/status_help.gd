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


## The effect of status `key` ("Poison (debuff): ..."), or "".
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
		out += "[url=%s%s]%s[/url]" % [META, sp["key"], text.substr(int(sp["from"]), int(sp["to"]) - int(sp["from"]))]
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


## The darker inset panel of a tooltip's effect section.
static func section_box() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color(0, 0, 0, 0.35), Color(UIStyle.BRONZE, 0.5), 1, 4)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	return p


## The wrapped effect text of a tooltip section.
static func section_label(text: String) -> Label:
	var l := UIStyle.label(text, 14, UIStyle.MUTED, true)
	l.custom_minimum_size.x = SECTION_W
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
