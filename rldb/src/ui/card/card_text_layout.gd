class_name CardTextLayout
extends RefCounted
## Text fitting for the card face: cached shaped paragraphs, shrink-to-fit font sizes, ellipsizing
## and two-line name splitting. Sizes given in base units are scaled by the card scale `s`.

## Shaped text paragraphs are expensive; share them across all card widgets (bounded).
const PARA_CACHE_MAX := 600
## Smallest font size (px) any card text is drawn at.
const MIN_FS := 6
const ELLIPSIS := "…"

static var _para_shared := {}


## Paragraph `width` wide showing at most `max_lines` lines (trailing ellipsis). `tag` keeps
## different fonts apart in the shared cache.
static func para(text: String, font: Font, tag: String, fs: int, width: float, max_lines: int) -> TextParagraph:
	var key := "%s|%s|%d|%d|%d" % [text, tag, fs, int(width), max_lines]
	if _para_shared.has(key):
		return _para_shared[key]
	if _para_shared.size() > PARA_CACHE_MAX:
		_para_shared.clear()
	var tp := TextParagraph.new()
	tp.width = width
	tp.max_lines_visible = max_lines
	tp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tp.add_string(text, font, fs)
	_para_shared[key] = tp
	return tp


## Paragraph at the largest size (<= fs_max) at which ALL of `text` fits in width x height; at
## fs_min it is clipped with an ellipsis as a last resort. Shared cache like para().
static func fit_para(text: String, font: Font, fs_max: int, fs_min: int, width: float, height: float) -> TextParagraph:
	var key := "fit|%s|%d|%d|%d|%d" % [text, fs_max, fs_min, int(width), int(height)]
	if _para_shared.has(key):
		return _para_shared[key]
	if _para_shared.size() > PARA_CACHE_MAX:
		_para_shared.clear()
	var tp: TextParagraph = null
	for fs in range(fs_max, fs_min - 1, -1):
		tp = TextParagraph.new()
		tp.width = width
		tp.add_string(text, font, fs)
		if tp.get_size().y <= height:
			break
		if fs == fs_min:
			tp.max_lines_visible = maxi(1, int(height / maxf(1.0, tp.get_size().y / maxf(1.0, float(tp.get_line_count())))))
			tp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_para_shared[key] = tp
	return tp


## Largest one-line font size between fs_min and fs_max (base units, scaled by `s`) at which
## `text` fits in `width`; never below MIN_FS.
static func fit_name(text: String, width: float, fs_max: float, fs_min: float, font: Font, s: float) -> int:
	var fs := roundi(fs_max * s)
	var lo := maxi(MIN_FS, roundi(fs_min * s))
	while fs > lo and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


## Splits a long name for a two-line plate: before a trailing "(...)" if present, else at the space
## nearest the middle. Returns [name] when it cannot be split.
static func split_name(nm: String) -> PackedStringArray:
	var i := nm.rfind(" (")
	if i <= 0:
		var best := -1
		for j in nm.length():
			if nm[j] == " " and (best < 0 or absi(j - nm.length() / 2) < absi(best - nm.length() / 2)):
				best = j
		i = best
	if i <= 0:
		return PackedStringArray([nm])
	return PackedStringArray([nm.substr(0, i), nm.substr(i + 1)])


## `text` trimmed with a trailing ellipsis so it fits in `avail` px at size `fs` (unchanged if it fits).
static func ellipsize(font: Font, text: String, fs: int, avail: float) -> String:
	var shown := text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		while shown.length() > 3 and font.get_string_size(shown + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
			shown = shown.substr(0, shown.length() - 1)
		shown += ELLIPSIS
	return shown


## Largest font size <= fs_max (base px, scaled by `s`) at which `txt` fits inside a stat badge's
## text area: the ATK rhombus when `diamond`, else the DEF shield.
static func fit_stat_fs(font: Font, txt: String, fs_max: float, rect: Rect2, diamond: bool, s: float) -> int:
	var fs := maxi(MIN_FS, roundi(fs_max * s))
	while fs > MIN_FS:
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var th := float(fs) * 0.74
		if diamond:
			# Text box must sit inside the rhombus: tw/w + th/h <= 1 (with a margin for the outline).
			if tw / rect.size.x + th / rect.size.y <= 0.84:
				break
		elif tw <= rect.size.x * 0.76 and th <= rect.size.y * 0.52:
			break
		fs -= 1
	return fs
