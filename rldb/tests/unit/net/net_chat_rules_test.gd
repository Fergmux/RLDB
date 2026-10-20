extends GdUnitTestSuite
## A1: chat text is cleaned to one line of plain text (no markup can be injected), capped at
## NetChat.MAX_LEN, and each sender is rate limited.


func test_sanitize_strips_bbcode_tags_expected_plain_text() -> void:
	assert_str(NetChat.sanitize("[color=red]hi[/color] there")).is_equal("hi there")
	assert_str(NetChat.sanitize("[url=https://x.example]click[/url]")).is_equal("click")
	assert_str(NetChat.sanitize("[img]res://icon.svg[/img]")).is_equal("res://icon.svg")


func test_sanitize_nested_tag_tricks_leave_no_brackets() -> void:
	var s := NetChat.sanitize("[[b]b]bold[[/b]/b] [font_size=90]")
	assert_str(s).not_contains("[")
	assert_str(s).not_contains("]")


func test_sanitize_control_characters_and_newlines_become_one_line() -> void:
	assert_str(NetChat.sanitize("  one\ntwo\r\n\tthree​  ")).is_equal("one two three")


func test_sanitize_caps_length_at_max() -> void:
	var long := "a".repeat(NetChat.MAX_LEN + 150)
	assert_int(NetChat.sanitize(long).length()).is_equal(NetChat.MAX_LEN)


func test_sanitize_whitespace_only_expected_empty() -> void:
	assert_str(NetChat.sanitize("   \n\t ")).is_empty()
	assert_str(NetChat.sanitize("[b][/b]")).is_empty()


func test_clean_name_caps_and_falls_back() -> void:
	assert_str(NetChat.clean_name("x".repeat(40))).has_length(NetChat.MAX_NAME)
	assert_str(NetChat.clean_name("[b][/b]")).is_equal("Player")


func test_guard_refuses_messages_closer_than_min_gap() -> void:
	var g := NetChat.Guard.new()
	assert_bool(g.allow(7, 1000)).is_true()
	assert_bool(g.allow(7, 1000 + NetChat.MIN_GAP_MS - 1)).is_false()
	assert_bool(g.allow(7, 1000 + NetChat.MIN_GAP_MS)).is_true()


func test_guard_burst_limit_then_window_frees_it() -> void:
	var g := NetChat.Guard.new()
	var t := 0
	for i in NetChat.BURST:
		assert_bool(g.allow("p", t)).is_true()
		t += NetChat.MIN_GAP_MS
	assert_bool(g.allow("p", t)).is_false()
	# Senders are independent.
	assert_bool(g.allow("q", t)).is_true()
	# Once the oldest message leaves the window, one more is allowed.
	assert_bool(g.allow("p", NetChat.WINDOW_MS + 1)).is_true()
