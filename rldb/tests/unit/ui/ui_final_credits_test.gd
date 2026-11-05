extends GdUnitTestSuite
## Final review #12 (design/review-final-2026-11-05.md): the Credits text in Options was small (13-14
## px muted on leather) and a licence URL wrapped mid-path ("creativecommons.org/ / licenses/by/3.0/").
## The body must read comfortably, no raw URL path may be printed (a short link label is shown and
## the address is its tooltip), and every link must open its https address.

## The smallest comfortable body size (layout px).
const MIN_BODY_PX := 16
## A printed web address with a path ("example.org/licenses/..."), or any scheme.
const RAW_URL := "(://|\\b[\\w-]+\\.(org|com|net|io)/\\S)"

var _opened: Array = []


func after_test() -> void:
	MainMenu.link_opener = MainMenu.default_link_opener


func _bodies(n: Node, out: Array) -> void:
	if n is RichTextLabel and n.has_meta("credit_line"):
		out.append(n)
	for c in n.get_children():
		_bodies(c, out)


func test_credits_body_is_comfortably_readable() -> void:
	var cv: Control = auto_free(MainMenu.credits_view())
	var lines := []
	_bodies(cv, lines)
	assert_int(lines.size()).is_greater(5)
	for l in lines:
		var rt := l as RichTextLabel
		assert_int(rt.get_theme_font_size("normal_font_size")).is_greater_equal(MIN_BODY_PX)
		assert_float(rt.get_theme_color("default_color").get_luminance()).is_greater(UIStyle.MUTED.get_luminance())


## Every text the credits print (labels and the parsed text of rich labels).
func _shown(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	for c in n.get_children():
		_shown(c, out)


func test_no_raw_url_path_is_printed() -> void:
	var cv: Control = auto_free(MainMenu.credits_view())
	var texts := []
	_shown(cv, texts)
	assert_int(texts.size()).is_greater(5)
	var re := RegEx.create_from_string(RAW_URL)
	for shown in texts:
		assert_object(re.search(String(shown))).override_failure_message("raw URL in: %s" % shown).is_null()


func test_every_credit_link_is_https_and_opens_on_click() -> void:
	MainMenu.link_opener = func(u: String) -> void: _opened.append(u)
	var cv: Control = auto_free(MainMenu.credits_view())
	var lines := []
	_bodies(cv, lines)
	var urls := []
	var re := RegEx.create_from_string("\\[url=([^\\]]+)\\]")
	for l in lines:
		for mt in re.search_all((l as RichTextLabel).text):
			urls.append(mt.get_string(1))
	# The licences named in the review keep a link: CC BY 3.0 and Godot's licence.
	assert_array(urls).contains(["https://creativecommons.org/licenses/by/3.0/", "https://godotengine.org/license"])
	for u in urls:
		assert_str(String(u)).starts_with("https://")
	# Act: click the CC BY 3.0 link.
	for l in lines:
		if (l as RichTextLabel).text.contains("creativecommons.org/licenses/by/3.0/"):
			(l as RichTextLabel).meta_clicked.emit("https://creativecommons.org/licenses/by/3.0/")
			break
	# Assert
	assert_array(_opened).is_equal(["https://creativecommons.org/licenses/by/3.0/"])
