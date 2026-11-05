extends GdUnitTestSuite
## L10 (owner, 5 Nov: "remove all basic fonts ... no default arial looking font in the game").
## Every face is a FontVariation over the bundled TTF with a themed fallback chain; the body face is
## also the project-wide default (gui/theme/custom_font and the base theme), so even a control
## outside the game theme is drawn in Alegreya Sans. The symbol fallback (RLDB Symbols, a subset of
## Noto Sans Symbols 2) carries Alegreya's vertical metrics, so it adds glyphs without making any
## line or Font.get_ascent() taller (the unmatched Noto font made every body line 70% taller).

const ALEGREYA := "res://assets/fonts/AlegreyaSans-Regular.ttf"
const CINZEL := "res://assets/fonts/Cinzel-Variable.ttf"
## Every face of the game: [label, path].
const FACES := [
	["body", UIStyle.FONT_BODY], ["bold", UIStyle.FONT_BOLD], ["italic", UIStyle.FONT_ITALIC],
	["bold italic", UIStyle.FONT_BOLD_ITALIC], ["display", UIStyle.FONT_DISPLAY],
]
## Source folders and data whose text reaches the screen.
const SCAN_DIRS := ["res://src"]
const DATA_DIR := "res://data"
## Glyphs the UI is known to use (a fixed list on top of the scan): the menu bars, the check mark,
## status dots, arrows and rules.
const UI_GLYPHS := "☰✓●←→‹›«»·×–—…“”’‘•−§◆◇▲▼"


## The family a font resolves to (the base FontFile path through FontVariations).
static func _base_path(f: Font) -> String:
	var cur: Font = f
	for i in 8:
		if cur is FontVariation and (cur as FontVariation).base_font != null:
			cur = (cur as FontVariation).base_font
		else:
			break
	return cur.resource_path


func test_project_default_font_is_the_body_face() -> void:
	# Arrange / Act
	var custom_font := String(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	var custom_theme := String(ProjectSettings.get_setting("gui/theme/custom", ""))
	# Assert
	assert_str(custom_font).is_equal(UIStyle.FONT_BODY)
	assert_str(custom_theme).is_equal(UIStyle.BASE_THEME)
	assert_str(_base_path(ThemeDB.fallback_font)).is_equal(ALEGREYA)


func test_bare_label_outside_the_game_theme_uses_alegreya() -> void:
	# Arrange: no theme of our own anywhere above it.
	var l: Label = auto_free(Label.new())
	l.text = "Plain"
	add_child(l)
	# Act
	var f := l.get_theme_font("font")
	# Assert
	assert_str(_base_path(f)).is_equal(ALEGREYA)


func test_bare_rich_text_faces_are_the_house_faces() -> void:
	# Arrange
	var r: RichTextLabel = auto_free(RichTextLabel.new())
	add_child(r)
	# Act / Assert
	assert_str(_base_path(r.get_theme_font("normal_font"))).is_equal(ALEGREYA)
	assert_str(_base_path(r.get_theme_font("bold_font"))).is_equal("res://assets/fonts/AlegreyaSans-Bold.ttf")
	assert_str(_base_path(r.get_theme_font("italics_font"))).is_equal("res://assets/fonts/AlegreyaSans-Italic.ttf")
	assert_str(_base_path(r.get_theme_font("bold_italics_font"))).is_equal("res://assets/fonts/AlegreyaSans-BoldItalic.ttf")
	assert_str(_base_path(r.get_theme_font("mono_font"))).is_equal(ALEGREYA)


func test_game_theme_sets_bold_italic_and_mono_rich_text_faces() -> void:
	# Arrange / Act
	var th := UIStyle.make_theme()
	# Assert
	assert_str(_base_path(th.get_font("bold_italics_font", "RichTextLabel"))).is_equal("res://assets/fonts/AlegreyaSans-BoldItalic.ttf")
	assert_str(_base_path(th.get_font("mono_font", "RichTextLabel"))).is_equal(ALEGREYA)
	assert_str(_base_path(th.get_font("font", "PopupMenu"))).is_equal(ALEGREYA)


func test_symbol_fallback_leaves_font_metrics_unchanged() -> void:
	# Arrange
	var raw_body: Font = load(ALEGREYA)
	var raw_display: Font = load(CINZEL)
	# Act / Assert: the chains measure exactly like their base faces.
	for px in [12, 16, 30]:
		assert_float(UIStyle.font_body().get_ascent(px)).is_equal(raw_body.get_ascent(px))
		assert_float(UIStyle.font_body().get_descent(px)).is_equal(raw_body.get_descent(px))
		assert_float(UIStyle.font_title().get_ascent(px)).is_equal(raw_display.get_ascent(px))
		assert_float(UIStyle.font_title().get_descent(px)).is_equal(raw_display.get_descent(px))


func test_a_line_with_a_symbol_is_no_taller_than_plain_text() -> void:
	# Arrange
	var plain := TextLine.new()
	plain.add_string("Menu", UIStyle.font_body(), 16)
	var sym := TextLine.new()
	# Act
	sym.add_string("☰ Menu ✓ ●", UIStyle.font_body(), 16)
	# Assert
	assert_float(sym.get_line_ascent()).is_equal(plain.get_line_ascent())
	assert_float(sym.get_line_descent()).is_equal(plain.get_line_descent())


func test_known_ui_glyphs_are_covered_by_every_face() -> void:
	# Arrange
	var missing := []
	# Act
	for face in FACES:
		var f: Font = load(String(face[1]))
		for ch in UI_GLYPHS:
			if not UIStyle.font_covers(f, ch.unicode_at(0)):
				missing.append("%s U+%04X %s" % [face[0], ch.unicode_at(0), ch])
	# Assert
	assert_array(missing).is_empty()


func test_every_glyph_in_ui_strings_and_data_is_covered() -> void:
	# Arrange: every non-ASCII character in a string literal of the game's scripts and in the
	# text of data/*.json (card names and rules, credits, tutorial).
	var chars := {}
	for d in SCAN_DIRS:
		_scan_scripts(d, chars)
	_scan_data(DATA_DIR, chars)
	var missing := []
	# Act
	for face in FACES:
		var f: Font = load(String(face[1]))
		for c in chars:
			if not UIStyle.font_covers(f, int(c)):
				missing.append("%s U+%04X (%s)" % [face[0], int(c), chars[c]])
	# Assert
	assert_bool(chars.is_empty()).is_false()
	assert_array(missing).is_empty()


func test_font_covers_follows_fallback_chains() -> void:
	# Arrange
	var raw: Font = load(ALEGREYA)
	# Act / Assert: Alegreya alone lacks the check mark; the body chain has it (the symbol face).
	assert_bool(UIStyle.font_covers(raw, "✓".unicode_at(0))).is_false()
	assert_bool(UIStyle.font_covers(UIStyle.font_body(), "✓".unicode_at(0))).is_true()
	# Cinzel lacks arrows; the display chain borrows Alegreya's.
	assert_bool(UIStyle.font_covers(load(CINZEL), "→".unicode_at(0))).is_false()
	assert_bool(UIStyle.font_covers(UIStyle.font_title(), "→".unicode_at(0))).is_true()


# ---------------------------------------------------------------- scan helpers

static var _str_re: RegEx
static var _esc_re: RegEx


func _scan_scripts(dir: String, out: Dictionary) -> void:
	if _str_re == null:
		_str_re = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
		_esc_re = RegEx.create_from_string("\\\\u([0-9a-fA-F]{4,6})")
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var path := dir.path_join(f)
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if line.strip_edges().begins_with("#"):
				continue
			for m in _str_re.search_all(line):
				for ch in m.get_string(1):
					var c := ch.unicode_at(0)
					if c > 127 and not out.has(c):
						out[c] = "%s:%d" % [path.get_file(), n]
			for m in _esc_re.search_all(line):
				var c := m.get_string(1).hex_to_int()
				if c > 127 and not out.has(c):
					out[c] = "%s:%d escape" % [path.get_file(), n]
	for sub in DirAccess.get_directories_at(dir):
		_scan_scripts(dir.path_join(sub), out)


func _scan_data(dir: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(dir.path_join(f))
		for ch in text:
			var c := ch.unicode_at(0)
			if c > 127 and not out.has(c):
				out[c] = f
