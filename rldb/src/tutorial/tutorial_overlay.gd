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

const PANEL_PAD := 14.0
const HINT_SECS := 3.5
const COMPLETE_W := 560.0

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

var _lesson_label: Label
var _count_label: Label
var _title_label: Label
var _text_label: RichTextLabel
var _hint_label: Label
var _panel_style: StyleBoxFlat
var _progress: TutorialDeco
var _step_box: VBoxContainer
var _hint_panel: PanelContainer
var _shown_key: String = ""
var _hint_gen: int = 0


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
	_lesson_label = UIStyle.label("", 13, UIStyle.GOLD, false, true)
	_lesson_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lesson_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lesson_label.clip_text = true
	_lesson_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_lesson_label)
	var pill := PanelContainer.new()
	var ps := UIStyle.flat(Color(0.04, 0.03, 0.02, 0.95), Color(UIStyle.GOLD, 0.6), 1, 11)
	ps.content_margin_left = 10
	ps.content_margin_right = 10
	ps.content_margin_top = 1
	ps.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", ps)
	head.add_child(pill)
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
	_hint_panel = PanelContainer.new()
	var hts := UIStyle.flat(Color(0.2, 0.05, 0.045, 0.92), Color(UIStyle.BAD, 0.8), 1, 6)
	hts.border_width_left = 4
	hts.content_margin_left = 10
	hts.content_margin_right = 8
	hts.content_margin_top = 5
	hts.content_margin_bottom = 5
	_hint_panel.add_theme_stylebox_override("panel", hts)
	_hint_panel.visible = false
	v.add_child(_hint_panel)
	_hint_label = UIStyle.label("", 14, Color("ffc9c4"), true, true)
	_hint_panel.add_child(_hint_label)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	foot_p.add_child(row)
	restart_btn = UIStyle.button("Restart lesson", 13)
	restart_btn.custom_minimum_size = Vector2(0, 32)
	restart_btn.pressed.connect(_on_restart)
	row.add_child(restart_btn)
	exit_btn = UIStyle.button("Exit tutorial", 13)
	exit_btn.custom_minimum_size = Vector2(0, 32)
	exit_btn.pressed.connect(_on_exit)
	row.add_child(exit_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	next_btn = UIStyle.primary_button("Next", 15)
	next_btn.custom_minimum_size = Vector2(96, 34)
	next_btn.pressed.connect(_on_next)
	row.add_child(next_btn)


## Re-reads the host: step text, buttons, completion card.
func refresh() -> void:
	if host == null or host.lesson.is_empty():
		return
	var n := host.step_count()
	_lesson_label.text = "TUTORIAL · %s" % String(host.lesson["title"]).to_upper()
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
	_hide_hint()
	_place_panel()


## Short fade of a freshly changed block (skipped with reduced motion).
func _fade_in(c: Control) -> void:
	if UIStyle.reduce_motion:
		c.modulate.a = 1.0
		return
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, UIStyle.dur(0.25)).set_trans(Tween.TRANS_SINE)


func _hide_hint() -> void:
	_hint_panel.visible = false
	_panel_style.border_color = UIStyle.GOLD


## Shows the refusal hint under the step text and flashes the card's border.
func show_hint(text: String) -> void:
	_hint_gen += 1
	var gen := _hint_gen
	_hint_label.text = text
	_hint_panel.visible = true
	_fade_in(_hint_panel)
	_panel_style.border_color = UIStyle.BAD
	_place_panel()
	get_tree().create_timer(HINT_SECS).timeout.connect(func():
		if gen == _hint_gen and is_instance_valid(self):
			_hide_hint()
			_place_panel())


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
## open, then the unit's row until it is selected, then the row's action button for the stance.
func _extra_action_rect(uid: int, pat: Dictionary) -> Rect2:
	var d := gs.details
	if d.pile_zone != "extra":
		return _rect_of(gs.board.piles[gs.board.side_of(gs.me())]["extra"])
	var row := d.pile_row(uid)
	if row == null:
		return Rect2()
	if d.pile_selected() != uid:
		return _rect_of(row)
	var want := "Summon Attack" if String(pat.get("stance", "atk")) == "atk" else "Summon Defense"
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
	for box in [gs.prompt.banner_btns, gs.prompt.banner_flow]:
		if box == null:
			continue
		for b in (box as Node).get_children():
			if b is Button and String((b as Button).text).contains(label):
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
	var p := HousePanel.new("Tutorial complete" if last else "Lesson %d of %d" % [idx + 1, total], "Tutorial", Vector2(28, 24), 10)
	p.arm = 18.0
	p.custom_minimum_size = Vector2(COMPLETE_W, 0)
	c.add_child(p)
	var bv := p.body
	var head := UIStyle.title_label("Tutorial complete" if last else "Lesson complete", 34, UIStyle.GOLD_HI)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	head.add_theme_constant_override("shadow_offset_y", 2)
	bv.add_child(head)
	var lt := String(host.lesson["title"])
	var name_l := UIStyle.label(lt.get_slice("·", 1).strip_edges() if lt.contains("·") else lt, 18, UIStyle.TEXT, true, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(name_l)
	var bar := TutorialDeco.steps(total, idx + 1)
	bar.custom_minimum_size = Vector2(0, 6)
	bar.highlight = false
	bv.add_child(bar)
	bv.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.55), true, 12.0))
	var sum := TutorialMarkup.rich_label(17)
	sum.text = "[center]%s[/center]" % TutorialMarkup.to_bbcode(String(host.lesson["summary"]))
	bv.add_child(sum)
	var learned_head := UIStyle.label("WHAT YOU LEARNED", 12, UIStyle.TEXT_DIM, false, true)
	bv.add_child(learned_head)
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
	if not UIStyle.reduce_motion:
		# What-you-learned lines arrive one after another.
		for i in rows.size():
			var rw: Control = rows[i]
			rw.modulate.a = 0.0
			var t2 := create_tween()
			t2.tween_interval(UIStyle.dur(0.3 + 0.12 * i))
			t2.tween_property(rw, "modulate:a", 1.0, UIStyle.dur(0.25))
