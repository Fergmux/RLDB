class_name TutorialMarkup
extends RefCounted
## Lesson-text markup (F04-12). Lessons are authored with a few semantic tags and this helper
## turns them into BBCode in the game's palette and fonts, so every step is formatted the same
## way and a restyle is a one-place change:
##
##   [kw]Battle Phase[/kw]    phases and rules terms: gold, bold
##   [stat]8 ATK[/stat]       stats, coloured by the stat named inside (ATK, DEF, HP, AP), bold
##   [card]Bastion Wyrm[/card] card names: bold, warm white
##   [type]Water[/type]       element Types, in the Type's colour, bold
##   [zone]Spent[/zone]       zones and piles: teal, bold
##   [btn]Go to Recovery[/btn] a button's label: shown in quotes, bold
##   [b]..[/b] [i]..[/i]      plain emphasis
##
## Newlines in the source are kept as line breaks ("\n\n" leaves a blank line between paragraphs).

const KW_COLOR := UIStyle.GOLD_HI
const CARD_COLOR := Color("fff1c9")
const ZONE_COLOR := Color("86d8c6")
const BTN_COLOR := Color("ffffff")
const STAT_COLORS := {
	"ATK": Color("ff7d6e"), "DEF": Color("74bdff"), "HP": Color("7fe09b"), "AP": UIStyle.COST_COLORS["ap"],
}
## Colour of a [stat] that names no known stat.
const STAT_DEFAULT := UIStyle.TEXT

const _TAGS := ["kw", "stat", "card", "type", "zone", "btn"]
static var _re: RegEx


## BBCode for `src` (see the class doc for the tags). Unknown text passes through unchanged.
static func to_bbcode(src: String) -> String:
	if _re == null:
		_re = RegEx.new()
		_re.compile("\\[(kw|stat|card|type|zone|btn)\\](.*?)\\[/\\1\\]")
	var out := ""
	var pos := 0
	for m in _re.search_all(src):
		out += src.substr(pos, m.get_start() - pos)
		out += _render(m.get_string(1), m.get_string(2))
		pos = m.get_end()
	return out + src.substr(pos)


## `src` without any tags, for tooltips, logs and tests ([btn] keeps its quotes).
static func plain(src: String) -> String:
	var s := to_bbcode(src)
	var re := RegEx.new()
	re.compile("\\[/?[a-z_]+(=[^\\]]*)?\\]")
	return re.sub(s, "", true)


static func _render(tag: String, inner: String) -> String:
	match tag:
		"kw":
			return "[b][color=#%s]%s[/color][/b]" % [KW_COLOR.to_html(false), inner]
		"stat":
			return "[b][color=#%s]%s[/color][/b]" % [stat_color(inner).to_html(false), inner]
		"card":
			# Bold body face: display small caps read as shouting mid-sentence.
			return "[b][color=#%s]%s[/color][/b]" % [CARD_COLOR.to_html(false), inner]
		"type":
			return "[b][color=#%s]%s[/color][/b]" % [UIStyle.type_color(inner).lightened(0.2).to_html(false), inner]
		"zone":
			return "[b][color=#%s]%s[/color][/b]" % [ZONE_COLOR.to_html(false), inner]
		"btn":
			return "[b][color=#%s]\u201c%s\u201d[/color][/b]" % [BTN_COLOR.to_html(false), inner]
	return inner


## Colour for a stat phrase such as "8 ATK" or "+6 ATK" (by the stat word inside it).
static func stat_color(text: String) -> Color:
	for k in STAT_COLORS:
		if text.contains(k):
			return STAT_COLORS[k]
	return STAT_DEFAULT


## A RichTextLabel set up for lesson text at `size` px: BBCode on, wrapping, sized to its content,
## in the body face with bold / italic faces from UIStyle.
static func rich_label(size: int = 16, color: Color = UIStyle.TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", UIStyle.font_body())
	r.add_theme_font_override("bold_font", UIStyle.font_bold())
	r.add_theme_font_override("italics_font", UIStyle.font_italic())
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_constant_override("line_separation", 3)
	return r


## Sets `label`'s text from lesson markup `src`.
static func set_text(label: RichTextLabel, src: String) -> void:
	label.text = to_bbcode(src)
