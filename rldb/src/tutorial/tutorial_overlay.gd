class_name TutorialOverlay
extends Control
## Tutorial UI over a GameScreen (F03-15): the guidance card at the top of the sidebar (lesson,
## step n/N, step text, Restart lesson, Exit tutorial and Next on read-only steps), the pulsing
## highlight on the card / zone / button / target the step needs, a hint when an off-script
## action is refused, and the lesson-complete card. Reads the TutorialHost; sends nothing to the
## rules engine except through the GameScreen's own controls.
##
## The guidance card sits over the game log at the top of the sidebar: the input-required banner
## uses the left column or the top centre of the board (depending on width), so the sidebar top is
## the one place that never overlaps it at any window size.
##
## H1 menus pass (design review #98-#103): the card's header reads "LESSON n OF N" over the lesson
## name (no ellipsis); Restart lesson / Exit tutorial are text links at the right of the footer and
## Next is the 40 px primary; a refused action shows ONE message, a floating amber-edged hint by the
## pointer that fades after HINT_SECS, while the highlight pulses once; a new lesson opens with a
## HERO banner; lesson / tutorial complete use HERO titles, a ray burst (the final one with a crown
## and motes) and their cues. Finished lessons are recorded in TutorialProgress.

const PANEL_PAD := 14.0
const HINT_SECS := 2.2
const COMPLETE_W := 560.0
## HERO title size of the banner and the completion cards (D3).
const HERO_PX := 48
## The floating off-script hint: its text size and its offset from the pointer.
const HINT_PX := 14
const HINT_OFFSET := Vector2(18, -52)
const HINT_EDGE := Color("e0a040")
## Lesson banner timing (s): fade in, hold, fade out.
const BANNER_IN := 0.3
const BANNER_HOLD := 1.5
const BANNER_OUT := 0.45
## Seconds the lesson's progress segment takes to fill on the completion card.
const FILL_TIME := 0.5
## Frames between two refreshes of the arrow's avoid rects (the text around the target).
const AVOID_EVERY := 6

## Screen this overlay guides.
var gs: GameScreen
## Tutorial authority.
var host: TutorialHost
## Guidance card.
var panel: PanelContainer
## Highlight layer.
var ring: TutorialHighlight
## Lesson-complete card (null while hidden).
var complete_card: Control
## Next button (read steps only).
var next_btn: Button
## Restart lesson button.
var restart_btn: Button
## Exit tutorial button.
var exit_btn: Button

## The floating off-script hint (null while hidden).
var hint_plate: PanelContainer
## The lesson banner shown when a lesson opens (null while hidden).
var banner: Control

var _lesson_label: Label
var _name_label: Label
var _count_label: Label
var _title_label: Label
var _text_label: RichTextLabel
var _panel_style: StyleBoxFlat
var _progress: TutorialDeco
var _step_box: VBoxContainer
var _shown_key: String = ""
## The lesson and step shown last, and whether it was a "do" step (the learner acts): moving on
## from one plays the small step_done chime.
var _last_lesson: int = -1
var _last_step: int = -1
var _last_do: bool = false
## step_done waits this long (s) so it lands after the action's own sound (a summon, an attack).
const STEP_DONE_DELAY := 0.35
const STEP_DONE_DB := -3.0
var _hint_gen: int = 0
var _banner_lesson: int = -1
var _avoid_tick: int = 0
var _avoid_target: Rect2 = Rect2()


## Creates the overlay on `screen` for `tutorial_host` and returns it.
static func attach_to(screen: GameScreen, tutorial_host: TutorialHost) -> TutorialOverlay:
	var o := TutorialOverlay.new()
	o.gs = screen
	o.host = tutorial_host
	screen.add_child(o)
	return o


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring = TutorialHighlight.new()
	ring.z_index = UiLayers.TUTORIAL_RING      # over the board and lifted cards, under every modal (F04-08)
	add_child(ring)
	_build_panel()
	host.step_changed.connect(refresh.unbind(1))
	host.lesson_completed.connect(refresh.unbind(1))
	host.lesson_completed.connect(_record_done.unbind(1))
	host.hint.connect(show_hint)
	refresh()


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.z_index = UiLayers.GAME_MENU - 3     # under the in-game menu and dialogs
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_style = UIStyle.flat(Color(0.075, 0.06, 0.04, 0.98), UIStyle.GOLD, 2, 10)
	_panel_style.border_width_left = 6
	# Children sit inside the border, so the bands never paint over the frame's rounded corners.
	_panel_style.content_margin_left = 6
	for side in [SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_panel_style.set_content_margin(side, 2)
	_panel_style.shadow_color = Color(0, 0, 0, 0.6)
	_panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)
	# Header band: lesson name and the step counter pill.
	var head_p := PanelContainer.new()
	var hs := UIStyle.flat(Color(0.15, 0.11, 0.05, 1.0), Color(UIStyle.GOLD, 0.55), 0, 8)
	# Inner radius = frame radius (10) minus the border it sits inside.
	hs.corner_radius_top_left = 4
	hs.corner_radius_top_right = 8
	hs.corner_radius_bottom_left = 0
	hs.corner_radius_bottom_right = 0
	hs.border_width_bottom = 1
	hs.content_margin_left = PANEL_PAD
	hs.content_margin_right = 10
	hs.content_margin_top = 7
	hs.content_margin_bottom = 7
	head_p.add_theme_stylebox_override("panel", hs)
	outer.add_child(head_p)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head_p.add_child(head)
	# Review #98: two lines, "LESSON 1 OF 7" (SECTION, 11 px) over the lesson's name (SCREEN, 18 px,
	# wrapping rather than trimmed); the step chip on the right.
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.add_theme_constant_override("separation", 2)
	head.add_child(hv)
	_lesson_label = UIStyle.label("", 11, UIStyle.GOLD, false, true)
	_lesson_label.name = "LessonOf"
	hv.add_child(_lesson_label)
	var lt := TitleText.apply(_lesson_label, TitleText.Tier.SECTION, 11)
	lt.show_underline = false
	TitleText.apply(_lesson_label, TitleText.Tier.SECTION, 11)
	_name_label = UIStyle.label("", 18, UIStyle.GOLD_HI, true, true)
	_name_label.name = "LessonName"
	hv.add_child(_name_label)
	TitleText.apply(_name_label, TitleText.Tier.SCREEN, 18)
	var pill := PanelContainer.new()
	var ps := UIStyle.flat(Color(0.04, 0.03, 0.02, 0.95), Color(UIStyle.GOLD, 0.6), 1, 11)
	ps.content_margin_left = 10
	ps.content_margin_right = 10
	ps.content_margin_top = 1
	ps.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", ps)
	head.add_child(pill)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_label = UIStyle.label("", 13, UIStyle.GOLD_HI, false, true)
	pill.add_child(_count_label)
	_progress = TutorialDeco.steps(1, 0)
	outer.add_child(_progress)
	# Body: step title, flourish, formatted text, refusal hint.
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_left", int(PANEL_PAD))
	body.add_theme_constant_override("margin_right", int(PANEL_PAD))
	body.add_theme_constant_override("margin_top", 12)
	body.add_theme_constant_override("margin_bottom", 10)
	outer.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	_step_box = VBoxContainer.new()
	_step_box.add_theme_constant_override("separation", 6)
	v.add_child(_step_box)
	_title_label = UIStyle.label("", 20, UIStyle.GOLD_HI, true, true)
	_step_box.add_child(_title_label)
	_step_box.add_child(TutorialDeco.divider(UIStyle.GOLD, 10.0))
	_text_label = TutorialMarkup.rich_label(16)
	_step_box.add_child(_text_label)
	# Footer: the buttons sit at the bottom of the box (F04-11).
	var foot_p := PanelContainer.new()
	var fs := UIStyle.flat(Color(0.045, 0.036, 0.026, 1.0), Color(UIStyle.BRONZE, 0.8), 0, 8)
	fs.corner_radius_top_left = 0
	fs.corner_radius_top_right = 0
	fs.corner_radius_bottom_left = 4
	fs.corner_radius_bottom_right = 8
	fs.border_width_top = 1
	fs.content_margin_left = PANEL_PAD
	fs.content_margin_right = 10
	fs.content_margin_top = 8
	fs.content_margin_bottom = 8
	foot_p.add_theme_stylebox_override("panel", fs)
	outer.add_child(foot_p)
	# Review #99: Next is the 40 px primary on the left; the two escape hatches are text links at the
	# right, so a step without Next keeps a balanced row.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIStyle.sp("sm"))
	foot_p.add_child(row)
	next_btn = UIStyle.primary_button("Next", 15)
	next_btn.custom_minimum_size = Vector2(112, 40)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.pressed.connect(_on_next)
	row.add_child(next_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size = Vector2(0, 40)
	row.add_child(gap)
	restart_btn = TextLink.make("Restart lesson", 13)
	restart_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	restart_btn.tooltip_text = "Start this lesson again from its first step."
	restart_btn.pressed.connect(_on_restart)
	row.add_child(restart_btn)
	exit_btn = TextLink.make("Exit tutorial", 13)
	exit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exit_btn.tooltip_text = "Back to the main menu."
	exit_btn.set_meta(Sfx.BUTTON_META, "back")
	exit_btn.pressed.connect(_on_exit)
	row.add_child(exit_btn)


## Re-reads the host: step text, buttons, completion card.
func refresh() -> void:
	if host == null or host.lesson.is_empty():
		return
	var n := host.step_count()
	_lesson_label.text = "LESSON %d OF %d" % [host.lesson_index + 1, TutorialLessons.count()]
	_name_label.text = TutorialMenu.lesson_name(String(host.lesson["title"]))
	var key := "%d/%d" % [host.lesson_index, host.step_index]
	if host.is_complete():
		_count_label.text = "Done"
		_title_label.text = "Lesson complete"
		TutorialMarkup.set_text(_text_label, String(host.lesson["summary"]))
		next_btn.visible = false
		_progress.set_current(n, n)
		_show_complete()
	else:
		var st := host.current_step()
		_count_label.text = "Step %d / %d" % [host.step_index + 1, n]
		_title_label.text = String(st.get("title", ""))
		var txt := String(st.get("text", ""))
		var bb := TutorialMarkup.to_bbcode(txt)
		if st.get("kind", "") == "wait":
			bb += "\n\n[i][color=#%s](The Rival is playing…)[/color][/i]" % UIStyle.TEXT_DIM.to_html(false)
		_text_label.text = bb
		next_btn.visible = st.get("kind", "") == "read"
		next_btn.text = "Finish lesson" if host.step_index == n - 1 else "Next"
		_progress.set_current(n, host.step_index)
	if key != _shown_key:
		_shown_key = key
		_fade_in(_step_box)
		if step_done_due(_last_lesson, _last_step, _last_do, host.lesson_index, host.step_index, host.is_complete()):
			_chime_step_done()
		_last_lesson = host.lesson_index
		_last_step = host.step_index
		_last_do = not host.is_complete() and String(host.current_step().get("kind", "")) == "do"
	if host.step_index == 0 and not host.is_complete() and host.lesson_index != _banner_lesson:
		_banner_lesson = host.lesson_index
		_show_banner()
	_hide_hint()
	_place_panel()


## True when moving from step (`l0`, `s0`, a "do" step when `was_do`) to (`l1`, `s1`) completes
## something the learner did: the next step of the same lesson after a "do" step. The lesson's last
## step is not chimed (the completion celebration plays instead).
static func step_done_due(l0: int, s0: int, was_do: bool, l1: int, s1: int, complete: bool) -> bool:
	return was_do and l0 == l1 and s1 == s0 + 1 and not complete


## The step_done chime, a moment after the action so the two never sound at once.
func _chime_step_done() -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(UIStyle.dur(STEP_DONE_DELAY)).timeout.connect(func() -> void:
		if is_instance_valid(self):
			Sfx.play("step_done", STEP_DONE_DB, 0.02))


## Short fade of a freshly changed block (skipped with reduced motion).
func _fade_in(c: Control) -> void:
	if UIStyle.reduce_motion:
		c.modulate.a = 1.0
		return
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, UIStyle.dur(0.25)).set_trans(Tween.TRANS_SINE)


func _hide_hint() -> void:
	_hint_gen += 1
	if hint_plate != null and is_instance_valid(hint_plate):
		hint_plate.queue_free()
	hint_plate = null


## Review #100: the one message for a refused off-script action: a floating hint by the pointer
## (F5 tooltip plate with an amber edge, sentence case, 14 px), fading after HINT_SECS, while the
## highlighted element pulses once, with the `deny` cue.
func show_hint(text: String) -> void:
	_hide_hint()
	Sfx.play("deny")
	var gen := _hint_gen
	var p := PanelContainer.new()
	p.name = "OffScriptHint"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = UiLayers.TUTORIAL_RING + 1
	var sb := UIStyle.flat(Color("1b1712"), Color(HINT_EDGE, 0.9), 1, 4)
	sb.border_width_left = 3
	UIStyle.pad(sb, "md", "sm")
	UIStyle.lift(sb, UIStyle.DEPTH_FLOATING)
	p.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, 0.3))
	var l := UIStyle.label(sentence_case(text), HINT_PX, UIStyle.TEXT)
	l.name = "Text"
	l.add_theme_font_override("font", UIStyle.font_bold())
	p.add_child(l)
	add_child(p)
	hint_plate = p
	p.reset_size()
	p.position = hint_position(get_local_mouse_position(), p.get_combined_minimum_size(), size)
	UIStyle.tween_in(p, "tooltip_in")
	ring.flash()
	get_tree().create_timer(HINT_SECS).timeout.connect(func():
		if gen == _hint_gen and is_instance_valid(p):
			hint_plate = null
			UIStyle.tween_out(p, true))


## Where the floating hint of `sz` goes for a pointer at `at` in a layer of `layer` size: up and
## to the right of the pointer, kept 12 px inside the layer.
static func hint_position(at: Vector2, sz: Vector2, layer: Vector2) -> Vector2:
	var m := float(UIStyle.CONTENT_FLOOR)
	var pos := at + HINT_OFFSET
	if pos.x + sz.x > layer.x - m:
		pos.x = at.x - HINT_OFFSET.x - sz.x
	pos.x = clampf(pos.x, m, maxf(m, layer.x - m - sz.x))
	pos.y = clampf(pos.y, m, maxf(m, layer.y - m - sz.y))
	return pos.round()


## "TUTORIAL: FOLLOW THE STEP." -> "Tutorial: follow the step." (a learner is never shouted at).
static func sentence_case(text: String) -> String:
	var t := text.strip_edges()
	if t == "" or t != t.to_upper():
		return t
	var low := t.to_lower()
	return low.substr(0, 1).to_upper() + low.substr(1)


func _on_next() -> void:
	host.next_step()   # F25: the button's own click


func _on_restart() -> void:
	host.restart()   # F25: the button's own click


func _on_exit() -> void:
	Sfx.play("back")   # F22
	gs.leave_to_menu.emit()


## Rect of the top of the sidebar (the game log panel) in screen coordinates.
func _sidebar_rect() -> Rect2:
	var lp: Control = gs.sidebar.log_panel
	if lp == null or not lp.is_visible_in_tree():
		var w := gs.sidebar_w
		return Rect2(gs.size.x - w + 4.0, 8.0, w - 12.0, 240.0)
	return lp.get_global_transform() * Rect2(Vector2.ZERO, lp.size)


func _place_panel() -> void:
	if panel == null:
		return
	var r := _sidebar_rect()
	var inv := get_global_transform().affine_inverse()
	# Same scale as the sidebar, so the text grows with it on wide windows.
	var k := gs.side_k
	panel.scale = Vector2(k, k)
	panel.size = Vector2(r.size.x / k, 0)
	panel.reset_size()
	# The card sits over the game log. When a step needs more height than the log has, the log
	# grows to match, so the sidebar pushes Card Details down instead of the card covering it.
	var lp: Control = gs.sidebar.log_panel
	if lp != null and lp.is_visible_in_tree():
		var need := panel.get_combined_minimum_size().y * k / maxf(0.001, lp.get_global_transform().get_scale().y)
		if absf(lp.custom_minimum_size.y - need) > 1.0:
			lp.custom_minimum_size.y = need
		r = _sidebar_rect()
	# Covers the whole log panel (a half-hidden log reads as clutter); grows if the text needs it.
	panel.size = Vector2(r.size.x / k, maxf(panel.get_combined_minimum_size().y, r.size.y / k))
	panel.position = inv * r.position


func _process(_d: float) -> void:
	if host == null or gs == null:
		return
	_place_panel()
	var inv := get_global_transform().affine_inverse()
	var rects := []
	for r in target_rects():
		if (r as Rect2).has_area():
			rects.append(inv * (r as Rect2))
	ring.rects = rects
	# An action button under a field card: point at it from below so the arrow never covers the card.
	ring.arrow_from_below = false
	if not rects.is_empty() and gs.action_row.stack != null and is_instance_valid(gs.action_row.stack):
		var sr: Rect2 = inv * _rect_of(gs.action_row.stack)
		var cr: Rect2 = inv * _card_rect(gs.selected_uid)
		ring.arrow_from_below = (rects[0] as Rect2).is_equal_approx(sr) and cr.has_area() and sr.get_center().y > cr.get_center().y
	# A button inside the prompt banner: a tight ring (its neighbours stay readable and clickable)
	# and the arrow from below, so it never covers the banner's text.
	ring.compact = false
	# A card in the choice tray: point up from below so the arrow never covers the tray's title.
	var tr: Control = gs.prompt.tray
	if not rects.is_empty() and tr != null and tr.is_visible_in_tree() and (inv * _rect_of(tr)).encloses(rects[0] as Rect2):
		ring.arrow_from_below = true
	var bn: Control = gs.prompt.ctx_banner
	if not rects.is_empty() and bn != null and bn.is_visible_in_tree():
		var br: Rect2 = inv * _rect_of(bn)
		if br.encloses(rects[0] as Rect2):
			ring.compact = true
			ring.arrow_from_below = true
	ring.visible = complete_card == null
	# The text around the target: measured at once for a new target (the arrow's side is decided
	# on its first frame), then refreshed every few frames.
	var first: Rect2 = rects[0] if not rects.is_empty() else Rect2()
	_avoid_tick += 1
	if _avoid_tick >= AVOID_EVERY or not first.is_equal_approx(_avoid_target):
		_avoid_tick = 0
		_avoid_target = first
		ring.avoid = avoid_rects(first)


## Review #101: the text around the arrow's target that the arrow must not cover (layer
## coordinates): the sidebar's and the prompt banner's labels and buttons, and the phase pills,
## except the target itself and what lies inside it.
func avoid_rects(target: Rect2) -> Array:
	var out := []
	if not target.has_area():
		return out
	var inv := get_global_transform().affine_inverse()
	var roots: Array = [gs.sidebar, gs.prompt.ctx_banner]
	var found := []
	for rt in roots:
		if rt is Node and is_instance_valid(rt):
			found.append_array((rt as Node).find_children("*", "Label", true, false))
			found.append_array((rt as Node).find_children("*", "Button", true, false))
	if gs.sidebar.pips != null:
		found.append(gs.sidebar.pips)
	for c in found:
		var cc := c as Control
		if cc == null or not cc.is_visible_in_tree() or cc is TitleText:
			continue
		var r: Rect2 = inv * _rect_of(cc)
		if r.has_area() and not r.intersects(target) and not target.encloses(r):
			out.append(r)
	return out


# ---------------------------------------------------------------- targets

## Screen rects the current step highlights: its focus list, or for a `do` step the expected
## card, its action button once the card is selected, the phase button or the expected option.
func target_rects() -> Array:
	var st := host.current_step()
	if st.is_empty() or gs.mv.is_empty():
		return []
	var out := []
	for f in st.get("focus", []):
		out.append(_focus_rect(f))
	if st.get("kind", "") == "do" and out.is_empty():
		var multi := _multi_rects(st.get("expect", []))
		if not multi.is_empty():
			return multi.filter(func(r): return (r as Rect2).has_area())
		for pat in st.get("expect", []):
			out.append(_expect_rect(pat))
			if String(pat.get("t", "")) == "choose":
				# A card option that also has a banner button (e.g. "Activate <Trap>"): ring both,
				# the button first (it carries the arrow).
				var b := _option_button_rect(TutorialScript.option_index(host.game(), host.keys, pat.get("opt", {})))
				if b.has_area() and b != out[-1]:
					out.insert(out.size() - 1, b)
	return out.filter(func(r): return (r as Rect2).has_area())


## A multi-pick step (opt.cards, e.g. Arcane materials): the expected cards not yet selected of
## every combination the current selection can still complete; Confirm once a combination is
## complete; the picks to deselect when none can be completed. [] when the step has no multi-pick.
func _multi_rects(pats: Array) -> Array:
	var sets := []
	for pat in pats:
		if String(pat.get("t", "")) == "choose" and pat.get("opt", {}).has("cards"):
			var w := TutorialScript.option_indices(host.game(), host.keys, pat["opt"])
			if not w.is_empty():
				sets.append(w)
	if sets.is_empty():
		return []
	var sel: Array = gs.multi.duplicate()
	sel.sort()
	for w in sets:
		if w == sel:
			return [_banner_button_rect("Confirm")]
	var out := []
	var seen := {}
	for w in sets:
		if sel.all(func(i): return i in w):
			for i in w:
				if not (i in sel) and not seen.has(i):
					seen[i] = true
					out.append(_option_rect(i))
	if out.is_empty():
		# No combination can be completed (e.g. both Dragons, an over-pay): ring the picks to
		# deselect, measured against the combination sharing the most picks.
		var best: Array = sets[0]
		for w in sets:
			if sel.filter(func(i): return i in w).size() > sel.filter(func(i): return i in best).size():
				best = w
		for i in sel:
			if not (i in best):
				out.append(_option_rect(i))
	return out


func _banner_button_rect(text: String) -> Rect2:
	if gs.prompt.banner_btns == null:
		return Rect2()
	for b in (gs.prompt.banner_btns as Node).get_children():
		if b is Button and String((b as Button).text) == text:
			return _rect_of(b)
	return Rect2()


## A Ritual / Arcane summon of an Extra Deck unit (F05-01): the Extra Deck pile until its list is
## open, then the unit's row until it is selected, then the row's Summon button.
func _extra_action_rect(uid: int, pat: Dictionary) -> Rect2:
	var d := gs.details
	if d.pile_zone != "extra":
		return _rect_of(gs.board.piles[gs.board.side_of(gs.me())]["extra"])
	var row := d.pile_row(uid)
	if row == null:
		return Rect2()
	if d.pile_selected() != uid:
		return _rect_of(row)
	var want := "Summon"
	for b in row.find_children("*", "Button", true, false):
		if String((b as Button).text) == want:
			return _rect_of(b)
	return _rect_of(row)


func _seat(who: String) -> int:
	return gs.me() if who == "me" else 1 - gs.me()


static func _rect_of(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


func _focus_rect(f: Dictionary) -> Rect2:
	if f.has("plate"):
		return _rect_of(gs.board.plate_of(_seat(String(f["plate"]))))
	if f.has("hand"):
		var u := Rect2()
		for uid in gs.hand.items:
			var r := _rect_of(gs.hand.items[uid]["widget"])
			u = r if not u.has_area() else u.merge(r)
		return u
	if f.has("pips"):
		return _rect_of(gs.sidebar.pips)
	if f.has("pile"):
		var who: String = f["pile"][0]
		var side := gs.board.side_of(_seat(who))
		var ps = gs.board.piles[side].get(String(f["pile"][1]))
		return _rect_of(ps)
	if f.has("slot"):
		return gs.board.slot_global_rect(_seat(String(f["slot"][0])), String(f["slot"][1]), int(f["slot"][2]))
	if f.has("card"):
		return _card_rect(int(host.keys.get(String(f["card"]), -1)))
	return Rect2()


## Rect of a visible card by uid: in my Hand, on the board or in the choice tray.
func _card_rect(uid: int) -> Rect2:
	if uid == -1:
		return Rect2()
	if gs.hand.items.has(uid):
		return _rect_of(gs.hand.items[uid]["widget"])
	var m := host.game()
	if m != null and m.cards.has(uid) and m.cards[uid]["zone"] in ["unit", "backrow", "power"]:
		var inst: Dictionary = m.cards[uid]
		return gs.board.slot_global_rect(int(inst["ctl"]), String(inst["zone"]), int(inst["slot"]))
	for w in _tray_widgets():
		if int((w as CardWidget).view.get("uid", -9)) == uid:
			return _rect_of(w)
	return Rect2()


func _tray_widgets() -> Array:
	var out := []
	if gs.prompt.tray == null or not gs.prompt.tray.visible:
		return out
	var stack := [gs.prompt.tray]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CardWidget:
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _expect_rect(pat: Dictionary) -> Rect2:
	var t: String = String(pat.get("t", ""))
	if t == "next_phase":
		return _rect_of(gs.sidebar.phase_btn)
	if t == "choose":
		var i := TutorialScript.option_index(host.game(), host.keys, pat.get("opt", {}))
		var r := _option_rect(i)
		return r if r.has_area() else _option_button_rect(i)
	var uid: int = int(host.keys.get(String(pat.get("card", "")), -1))
	if t in ["ritual", "arcane"]:
		return _extra_action_rect(uid, pat)
	if uid == gs.selected_uid and gs.action_row.stack != null and is_instance_valid(gs.action_row.stack) \
			and gs.action_row.stack.get_child_count() > 0:
		return _rect_of(gs.action_row.stack)
	return _card_rect(uid)


## Rect of my pending option i: its board zone / card, its tray card or its banner button.
func _option_rect(i: int) -> Rect2:
	var pd := gs.pending()
	if i < 0 or pd.is_empty() or not pd.get("mine", false):
		return Rect2()
	var o: Dictionary = {}
	for x in pd["options"]:
		if int(x["i"]) == i:
			o = x
	if o.is_empty():
		return Rect2()
	if o.has("ref"):
		return gs.board.slot_global_rect(int(o["ref"]["p"]), String(o["ref"]["zone"]), int(o["ref"]["slot"]))
	if o.has("slot"):
		return gs.board.slot_global_rect(gs.me(), GameSelection.mapped_zone(String(o.get("zone", ""))), int(o["slot"]))
	if o.has("card"):
		return _card_rect(int(o["card"].get("uid", -1)))
	return Rect2()


## Rect of the banner button of my pending option i (Rect2() when it has none).
func _option_button_rect(i: int) -> Rect2:
	var pd := gs.pending()
	if i < 0 or pd.is_empty() or not pd.get("mine", false):
		return Rect2()
	var label := ""
	for x in pd["options"]:
		if int(x["i"]) == i:
			label = String(x.get("label", ""))
	if label == "":
		return Rect2()
	for box in [gs.prompt.banner_btns, gs.prompt.banner_flow, gs.prompt.banner_list]:
		if box == null:
			continue
		# find_children: a Trap window's Skip / Pass pair sits in a row of its own (D13).
		for b in (box as Node).find_children("*", "Button", true, false):
			if String((b as Button).text).contains(label):
				return _rect_of(b)
	return Rect2()


# ---------------------------------------------------------------- completion

func _show_complete() -> void:
	if complete_card != null and is_instance_valid(complete_card):
		return
	var last := not host.has_next_lesson()
	var idx := host.lesson_index
	var total := TutorialLessons.count()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = UiLayers.CONFIRM_DIALOG - 2
	var area := gs.play_area
	dim.position = get_global_transform().affine_inverse() * area.position
	dim.size = Vector2(area.size.x, gs.size.y - area.position.y)
	add_child(dim)
	complete_card = dim
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	# House plate (F06-01): the header strip carries the lesson count; every layer follows the
	# rim's rounded corners, so nothing squares off the frame.
	# Celebration behind the card (#102 / #103): a gold ray burst; the final one adds motes.
	var cel := Control.new()
	cel.name = "Celebration"
	cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cel)
	dim.move_child(cel, 0)   # behind the card
	var p := HousePanel.new("Tutorial complete" if last else "Lesson %d of %d" % [idx + 1, total], "Tutorial", Vector2(28, 24), 10)
	p.arm = 18.0
	p.custom_minimum_size = Vector2(COMPLETE_W, 0)
	c.add_child(p)
	var bv := p.body
	if last:
		var crown := Crown.new()
		crown.name = "Crown"
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(crown)
	# HERO title (D3): the gold metal gradient, bevel shadow, glow and its sweep.
	var head := UIStyle.label("Tutorial complete" if last else "Lesson complete", HERO_PX, UIStyle.GOLD_HI)
	head.name = "CompleteTitle"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(head)
	var hero := TitleText.apply(head, TitleText.Tier.HERO, HERO_PX)
	hero.uppercase = true
	var lt := String(host.lesson["title"])
	var name_l := UIStyle.label(lt.get_slice("·", 1).strip_edges() if lt.contains("·") else lt, 18, UIStyle.TEXT, true, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(name_l)
	# The progress bar: this lesson's segment fills with light (#102).
	var bar := TutorialDeco.steps(total, idx)
	bar.name = "LessonBar"
	bar.custom_minimum_size = Vector2(0, 6)
	bar.highlight = false
	bar.fill_time = FILL_TIME
	bv.add_child(bar)
	bv.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.55), true, 12.0))
	var sum := TutorialMarkup.rich_label(17)
	sum.text = "[center]%s[/center]" % TutorialMarkup.to_bbcode(String(host.lesson["summary"]))
	bv.add_child(sum)
	var learned_head := UIStyle.label("WHAT YOU LEARNED", 13, UIStyle.GOLD, false, true)
	learned_head.name = "LearnedHead"
	bv.add_child(learned_head)
	TitleText.apply(learned_head, TitleText.Tier.SECTION, 13)
	var rows := []
	for item in host.lesson.get("learned", []):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var bl := TutorialDeco.bullet()
		bl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bl.custom_minimum_size = Vector2(14, 22)
		r.add_child(bl)
		var rl := TutorialMarkup.rich_label(16)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.text = TutorialMarkup.to_bbcode(String(item))
		r.add_child(rl)
		bv.add_child(r)
		rows.append(r)
	if last:
		var done := TutorialMarkup.rich_label(15, UIStyle.TEXT_DIM)
		done.text = "You have played every lesson. Start a series against the bot or a friend from [b]Play[/b]."
		bv.add_child(done)
	# Buttons: the way forward on top, the other two below it.
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 10)
	bv.add_child(Control.new())   # a little more air above the buttons
	bv.add_child(fv)
	var main_b: Button
	if last:
		main_b = UIStyle.primary_button("Back to menu", 18)
		main_b.pressed.connect(_on_exit)
	else:
		var nxt := TutorialLessons.get_lesson(idx + 1)
		main_b = UIStyle.primary_button("Next: %s" % String(nxt["title"]).get_slice("·", 1).strip_edges(), 18)
		main_b.pressed.connect(func():
			host.load_lesson(idx + 1))
	main_b.custom_minimum_size = Vector2(0, 52)
	fv.add_child(main_b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	fv.add_child(row)
	var replay := UIStyle.button("Replay lesson", 16)
	replay.custom_minimum_size = Vector2(0, 44)
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.pressed.connect(_on_restart)
	row.add_child(replay)
	if not last:
		var ex := UIStyle.button("Exit tutorial", 16)
		ex.custom_minimum_size = Vector2(0, 44)
		ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ex.pressed.connect(_on_exit)
		row.add_child(ex)
	p.appear()
	hero.play_sweep()
	_celebrate(cel, last)
	bar.set_current(total, idx + 1)
	if not UIStyle.reduce_motion:
		# What-you-learned lines arrive one after another.
		for i in rows.size():
			var rw: Control = rows[i]
			rw.modulate.a = 0.0
			var t2 := create_tween()
			t2.tween_interval(UIStyle.dur(0.3 + 0.12 * i))
			t2.tween_property(rw, "modulate:a", 1.0, UIStyle.dur(0.25))


## Records the finished lesson (review #97: its tick in the lesson list).
func _record_done() -> void:
	if host != null and not host.lesson.is_empty():
		TutorialProgress.mark_done(String(host.lesson.get("id", "")))


## The ray burst behind a completion card and its cue (#102); the final completion gets the
## series-victory weight: bigger rays, rising gold motes and victory_big (#103). Under reduce
## motion the rays hold one static frame and the motes rest.
func _celebrate(layer: Control, last: bool) -> void:
	var area := gs.play_area
	var rays := FxSigil.new()
	rays.name = "Rays"
	rays.kind = "rays"
	rays.col = Color(UIStyle.GOLD, 0.55)
	rays.radius = area.size.length() * (0.55 if last else 0.4)
	rays.position = area.size / 2.0
	layer.add_child(rays)
	if last:
		var motes := AmbientMotes.new(30, [AmbientMotes.GOLD], 2603)
		motes.name = "Motes"
		motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(motes)
	Sfx.play("victory_big" if last else "victory")
	if UIStyle.reduce_motion or not is_inside_tree():
		rays.t = 0.25   # one calm static frame
		return
	var tw := rays.create_tween()
	tw.tween_property(rays, "t", 1.0, UIStyle.motion("celebrate") * (1.6 if last else 1.2)).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Review "LESSON" HERO banner: when a lesson opens, "LESSON n" (HERO, 48 px) over its name
## (SCREEN) on a soft dark band across the board, in and out on its own; click-through, so it
## never blocks the first step. A 120 ms fade each way under reduce motion.
func _show_banner() -> void:
	if banner != null and is_instance_valid(banner):
		banner.queue_free()
	var area := gs.play_area
	var inv := get_global_transform().affine_inverse()
	var b := Banner.new()
	b.name = "LessonBanner"
	b.z_index = UiLayers.TUTORIAL_RING + 2
	b.position = inv * area.position
	b.size = area.size
	add_child(b)
	banner = b
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", UIStyle.sp("xs"))
	b.add_child(v)
	var t := TitleText.make("LESSON %d" % (host.lesson_index + 1), TitleText.Tier.HERO, HERO_PX)
	t.name = "BannerTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var nm := TitleText.make(TutorialMenu.lesson_name(String(host.lesson["title"])).to_upper(), TitleText.Tier.SCREEN, 26)
	nm.name = "BannerName"
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	Sfx.play("notice")
	b.modulate.a = 0.0
	if not is_inside_tree():
		return
	var tw := b.create_tween()
	var reduced := UIStyle.reduce_motion
	tw.tween_property(b, "modulate:a", 1.0, UIStyle.motion("reduced") if reduced else UIStyle.dur(BANNER_IN))
	if not reduced:
		t.play_sweep()
		b.scale_in(UIStyle.dur(BANNER_IN))
	tw.tween_interval(UIStyle.dur(BANNER_HOLD))
	tw.tween_property(b, "modulate:a", 0.0, UIStyle.motion("reduced") if reduced else UIStyle.dur(BANNER_OUT))
	tw.tween_callback(func():
		if is_instance_valid(b):
			b.queue_free())


## The lesson banner's ground: a horizontal band of shadow that fades out at the top and bottom,
## with gold hairlines; its content grows from 0.92 when it opens.
class Banner extends Control:
	const BAND_H := 190.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Eases the banner's content from 0.92 to full size over `sec`.
	func scale_in(sec: float) -> void:
		pivot_offset = size / 2.0
		scale = Vector2(0.92, 0.92)
		create_tween().tween_property(self, "scale", Vector2.ONE, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var cy := size.y / 2.0
		var half := BAND_H / 2.0
		Ornate.vgradient(self, Rect2(0, cy - half, size.x, half), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.62))
		Ornate.vgradient(self, Rect2(0, cy, size.x, half), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.0))
		for y in [cy - half * 0.78, cy + half * 0.78]:
			Ornate.hgradient(self, Rect2(size.x * 0.12, y, size.x * 0.38, 1.0), Color(UIStyle.GOLD, 0.0), Color(UIStyle.GOLD, 0.7))
			Ornate.hgradient(self, Rect2(size.x * 0.5, y, size.x * 0.38, 1.0), Color(UIStyle.GOLD, 0.7), Color(UIStyle.GOLD, 0.0))
			Ornate.diamond(self, Vector2(size.x / 2.0, y + 0.5), 4.0, UIStyle.GOLD_HI)


## The crown sigil over the final "Tutorial complete" (review #103: the series VICTORY language).
class Crown extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(76, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0.1 * w, 0.86 * h), Vector2(0.06 * w, 0.28 * h), Vector2(0.3 * w, 0.56 * h),
			Vector2(0.5 * w, 0.1 * h), Vector2(0.7 * w, 0.56 * h), Vector2(0.94 * w, 0.28 * h), Vector2(0.9 * w, 0.86 * h)])
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(0, 3))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.55))
		draw_colored_polygon(pts, UIStyle.GOLD)
		# Lit face: the same outline drawn smaller toward the light (up and left).
		var c := Vector2(0.48 * w, 0.5 * h)
		var lit := PackedVector2Array()
		for q in pts:
			lit.append(c + (q - c) * 0.78 + Vector2(-1, -2))
		draw_colored_polygon(lit, Color(UIStyle.GOLD_HI, 0.5))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(0.16, 0.1, 0.02, 0.95), 1.5, true)
		draw_rect(Rect2(0.1 * w, 0.78 * h, 0.8 * w, 0.1 * h), UIStyle.GOLD.darkened(0.25))
		for x in [0.06, 0.5, 0.94]:
			Ornate.diamond(self, Vector2(x * w, (0.1 if x == 0.5 else 0.28) * h), 4.0, UIStyle.GOLD_HI)
		Ornate.diamond(self, Vector2(0.5 * w, 0.66 * h), 5.0, Color("e8605a"))
