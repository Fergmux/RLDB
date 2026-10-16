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
var _text_label: Label
var _hint_label: Label
var _panel_style: StyleBoxFlat
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
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_panel_style.set_content_margin(side, PANEL_PAD)
	_panel_style.shadow_color = Color(0, 0, 0, 0.6)
	_panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_lesson_label = UIStyle.label("", 13, UIStyle.GOLD, false, true)
	_lesson_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lesson_label.clip_text = true
	_lesson_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_lesson_label)
	_count_label = UIStyle.label("", 13, UIStyle.TEXT_DIM, false, true)
	head.add_child(_count_label)
	_title_label = UIStyle.label("", 20, UIStyle.GOLD_HI, true, true)
	v.add_child(_title_label)
	_text_label = UIStyle.label("", 15, UIStyle.TEXT, true)
	v.add_child(_text_label)
	_hint_label = UIStyle.label("", 14, UIStyle.BAD, true, true)
	_hint_label.visible = false
	v.add_child(_hint_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
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
	if host.is_complete():
		_count_label.text = "Done"
		_title_label.text = "Lesson complete"
		_text_label.text = String(host.lesson["summary"])
		next_btn.visible = false
		_show_complete()
	else:
		var st := host.current_step()
		_count_label.text = "Step %d / %d" % [host.step_index + 1, n]
		_title_label.text = String(st.get("title", ""))
		var txt := String(st.get("text", ""))
		if st.get("kind", "") == "wait":
			txt += "\n(The Rival is playing…)"
		_text_label.text = txt
		next_btn.visible = st.get("kind", "") == "read"
		next_btn.text = "Finish lesson" if host.step_index == n - 1 else "Next"
	_hint_label.visible = false
	_place_panel()


## Shows the refusal hint under the step text and flashes the card's border.
func show_hint(text: String) -> void:
	_hint_gen += 1
	var gen := _hint_gen
	_hint_label.text = text
	_hint_label.visible = true
	_panel_style.border_color = UIStyle.BAD
	_place_panel()
	get_tree().create_timer(HINT_SECS).timeout.connect(func():
		if gen == _hint_gen and is_instance_valid(self):
			_hint_label.visible = false
			_panel_style.border_color = UIStyle.GOLD
			_place_panel())


func _on_next() -> void:
	Sfx.play("confirm")
	host.next_step()


func _on_restart() -> void:
	Sfx.play("confirm")
	host.restart()


func _on_exit() -> void:
	Sfx.play("cancel")
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
		for pat in st.get("expect", []):
			out.append(_expect_rect(pat))
			if String(pat.get("t", "")) == "choose":
				# A card option that also has a banner button (e.g. "Activate <Trap>"): ring both,
				# the button first (it carries the arrow).
				var b := _option_button_rect(TutorialScript.option_index(host.game(), host.keys, pat.get("opt", {})))
				if b.has_area() and b != out[-1]:
					out.insert(out.size() - 1, b)
	return out.filter(func(r): return (r as Rect2).has_area())


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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
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
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.06, 0.05, 0.035, 0.99), UIStyle.GOLD_HI, 2, 12)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 30)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 24)
	sb.shadow_color = Color(UIStyle.GOLD, 0.35)
	sb.shadow_size = 24
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(COMPLETE_W, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := UIStyle.title_label("Tutorial complete" if last else "Lesson complete", 34, UIStyle.GOLD_HI)
	v.add_child(head)
	v.add_child(UIStyle.label(String(host.lesson["title"]), 18, UIStyle.GOLD, true, true))
	var sum := UIStyle.label(String(host.lesson["summary"]), 16, UIStyle.TEXT, true)
	sum.custom_minimum_size = Vector2(COMPLETE_W - 60.0, 0)
	v.add_child(sum)
	if last:
		v.add_child(UIStyle.label("You have played every lesson. Start a series against the bot or a friend from Play.", 15, UIStyle.TEXT_DIM, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var replay := UIStyle.button("Replay lesson", 16)
	replay.custom_minimum_size = Vector2(0, 46)
	replay.pressed.connect(_on_restart)
	row.add_child(replay)
	if last:
		var menu_b := UIStyle.primary_button("Back to menu", 17)
		menu_b.custom_minimum_size = Vector2(0, 46)
		menu_b.pressed.connect(_on_exit)
		row.add_child(menu_b)
	else:
		var nxt := TutorialLessons.get_lesson(host.lesson_index + 1)
		var nb := UIStyle.primary_button("Next: %s" % String(nxt["title"]).get_slice("·", 1).strip_edges(), 17)
		nb.custom_minimum_size = Vector2(0, 46)
		nb.pressed.connect(func():
			Sfx.play("confirm")
			host.load_lesson(host.lesson_index + 1))
		row.add_child(nb)
		var ex := UIStyle.button("Exit tutorial", 16)
		ex.custom_minimum_size = Vector2(0, 46)
		ex.pressed.connect(_on_exit)
		row.add_child(ex)
	if not UIStyle.reduce_motion:
		p.modulate.a = 0.0
		p.scale = Vector2(0.94, 0.94)
		p.pivot_offset = Vector2(COMPLETE_W / 2.0, 120.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "modulate:a", 1.0, UIStyle.dur(0.3))
		tw.tween_property(p, "scale", Vector2.ONE, UIStyle.dur(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
