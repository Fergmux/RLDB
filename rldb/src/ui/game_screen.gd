class_name GameScreen
extends Control
## Button-driven game UI for one seat. Renders the redacted series view from a
## SeatClient and sends commands; it never computes rules itself. All legality,
## costs, damage and statuses come from the authority's view.

signal back_to_menu

var client: SeatClient
var view: Dictionary = {}
var mv: Dictionary = {}          # match view (may be the finished game between games)
var selected_uid: int = -1
var multi: Array = []            # selected option indices for a multi-select prompt
var _log_seq_shown: int = 0
var _log_game: int = -1
var _overlay_hidden_by_user: bool = false
var _last_stage: String = ""
var _error_text: String = ""

# Layout nodes
var board_box: VBoxContainer
var opp_bar: HBoxContainer
var my_bar: HBoxContainer
var opp_support: HBoxContainer
var my_support: HBoxContainer
var opp_rows: Array = []   # [back, front]
var my_rows: Array = []    # [front, back]
var mid_bar: HBoxContainer
var hand_box: HBoxContainer
var details_box: VBoxContainer
var prompt_box: VBoxContainer
var log_label: RichTextLabel
var overlay: PanelContainer
var overlay_box: VBoxContainer
var pile_popup: PanelContainer
var pile_box: VBoxContainer
var toast: Label
var seat_label: Label


func _ready() -> void:
	theme = UIStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	margin.add_child(root)
	_build_board(root)
	_build_side(root)
	_build_overlays()


func attach(c: SeatClient) -> void:
	if client != null and client.view_changed.is_connected(_on_view):
		client.view_changed.disconnect(_on_view)
		client.status_changed.disconnect(_on_status)
	client = c
	client.view_changed.connect(_on_view)
	client.status_changed.connect(_on_status)
	selected_uid = -1
	multi = []
	_log_seq_shown = 0
	_log_game = -1
	log_label.clear()
	if not c.last_view.is_empty():
		_on_view(c.last_view)


# ---------------------------------------------------------------- layout

func _build_board(root: HBoxContainer) -> void:
	board_box = VBoxContainer.new()
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 4)
	root.add_child(board_box)
	opp_bar = HBoxContainer.new()
	board_box.add_child(opp_bar)
	opp_support = HBoxContainer.new()
	board_box.add_child(opp_support)
	for i in 2:
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", 8)
		board_box.add_child(r)
		opp_rows.append(r)
	mid_bar = HBoxContainer.new()
	mid_bar.add_theme_constant_override("separation", 10)
	board_box.add_child(mid_bar)
	for i in 2:
		var r2 := HBoxContainer.new()
		r2.alignment = BoxContainer.ALIGNMENT_CENTER
		r2.add_theme_constant_override("separation", 8)
		board_box.add_child(r2)
		my_rows.append(r2)
	my_support = HBoxContainer.new()
	board_box.add_child(my_support)
	my_bar = HBoxContainer.new()
	board_box.add_child(my_bar)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 180)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_box.add_child(hand_scroll)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(hand_box)


func _build_side(root: HBoxContainer) -> void:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(440, 0)
	side.add_theme_constant_override("separation", 6)
	root.add_child(side)
	var top := HBoxContainer.new()
	side.add_child(top)
	seat_label = UIStyle.label("", 13, UIStyle.MUTED)
	seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(seat_label)
	var menu_b := UIStyle.button("Menu", 12)
	menu_b.pressed.connect(func(): back_to_menu.emit())
	top.add_child(menu_b)
	var pp := UIStyle.panel()
	side.add_child(pp)
	prompt_box = VBoxContainer.new()
	prompt_box.add_theme_constant_override("separation", 4)
	pp.add_child(prompt_box)
	var dp := UIStyle.panel()
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(dp)
	var ds := ScrollContainer.new()
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(ds)
	details_box = VBoxContainer.new()
	details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(details_box)
	var lp := UIStyle.panel()
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(UIStyle.label("Game log", 13, UIStyle.ACCENT))
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.selection_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 12)
	lv.add_child(log_label)


func _build_overlays() -> void:
	overlay = PanelContainer.new()
	overlay.add_theme_stylebox_override("panel", UIStyle.flat(Color(0.06, 0.07, 0.09, 0.96), UIStyle.ACCENT, 2, 10))
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 60
	overlay.offset_right = -60
	overlay.offset_top = 40
	overlay.offset_bottom = -40
	overlay.visible = false
	add_child(overlay)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(sc)
	overlay_box = VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 8)
	sc.add_child(overlay_box)
	pile_popup = PanelContainer.new()
	pile_popup.add_theme_stylebox_override("panel", UIStyle.flat(Color(0.08, 0.09, 0.12, 0.97), UIStyle.SELECT, 2, 10))
	pile_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pile_popup.offset_left = 120
	pile_popup.offset_right = -560
	pile_popup.offset_top = 120
	pile_popup.offset_bottom = -200
	pile_popup.visible = false
	add_child(pile_popup)
	var ps := ScrollContainer.new()
	pile_popup.add_child(ps)
	pile_box = VBoxContainer.new()
	pile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ps.add_child(pile_box)
	toast = UIStyle.label("", 15, UIStyle.BAD, true)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(400, 6)
	toast.custom_minimum_size = Vector2(700, 0)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast)


# ---------------------------------------------------------------- view handling

func _on_status(text: String) -> void:
	_error_text = text
	toast.text = text
	var t := get_tree().create_timer(4.0)
	t.timeout.connect(func():
		if toast.text == text:
			toast.text = "")


func _on_view(v: Dictionary) -> void:
	view = v
	mv = v.get("match", {})
	if v["stage"] != _last_stage:
		_overlay_hidden_by_user = false
		_last_stage = v["stage"]
	if not mv.is_empty() and mv.get("pending", {}).is_empty():
		multi = []
	seat_label.text = "You are %s  ·  Series %d-%d (best of %d)%s" % [v["names"][v["you"]], v["scores"][0], v["scores"][1], v["best_of"],
		"" if client == null or client.label == "" else ""]
	_render_all()


func _render_all() -> void:
	_render_board()
	_render_prompt()
	_render_details()
	_render_log()
	_render_overlay()


func me() -> int:
	return view.get("you", 0)


func _pv(p: int) -> Dictionary:
	return mv["players"][p]


# ---------------------------------------------------------------- board

func _clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func _render_board() -> void:
	for n in [opp_bar, my_bar, opp_support, my_support, mid_bar, hand_box] + opp_rows + my_rows:
		_clear(n)
	if mv.is_empty():
		return
	var p := me()
	var o := 1 - p
	_render_bar(opp_bar, o)
	_render_bar(my_bar, p)
	_render_support(opp_support, o)
	_render_support(my_support, p)
	# Opponent: back row furthest away, front row facing ours.
	_render_row(opp_rows[0], o, [3, 4, 5])
	_render_row(opp_rows[1], o, [0, 1, 2])
	_render_row(my_rows[0], p, [0, 1, 2])
	_render_row(my_rows[1], p, [3, 4, 5])
	_render_mid()
	for c in _pv(p).get("hand", []):
		var w := _widget(c, "hand")
		hand_box.add_child(w)
	if _pv(p).get("hand", []).is_empty():
		hand_box.add_child(UIStyle.label("Your hand is empty.", 13, UIStyle.MUTED))


func _render_bar(bar: HBoxContainer, p: int) -> void:
	var pv := _pv(p)
	var mine := p == me()
	var active: bool = mv["active"] == p
	var name_l := UIStyle.label(("▶ " if active else "") + pv["name"] + (" (you)" if mine else ""), 16, UIStyle.ACCENT if active else UIStyle.TEXT)
	name_l.custom_minimum_size = Vector2(190, 0)
	bar.add_child(name_l)
	var hp := UIStyle.label("HP %d" % pv["hp"], 20, UIStyle.GOOD if pv["hp"] > 20 else UIStyle.BAD)
	hp.custom_minimum_size = Vector2(90, 0)
	bar.add_child(hp)
	var ap_text := "AP %d" % pv["ap"]
	if mine and not pv.get("ap_next", []).is_empty():
		var parts := []
		for m in pv["ap_next"]:
			parts.append("%+d" % m["n"])
		ap_text += "  (next turn %s)" % " ".join(parts)
	bar.add_child(UIStyle.label(ap_text, 18, UIStyle.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var counts: Dictionary = pv["counts"]
	for z in ["hand", "draw", "spent", "exhaust", "extra"]:
		var b := UIStyle.button("%s %d" % [z.capitalize() if z != "extra" else "Extra Deck", counts[z]], 12)
		if mine and z != "hand":
			b.pressed.connect(_show_pile.bind(z))
			b.tooltip_text = "Inspect your %s" % z + (" (shown in a random order; real order unchanged)" if z == "draw" else "")
		else:
			b.disabled = not mine
			b.tooltip_text = "Hidden: only the count is public." if not mine else ""
		bar.add_child(b)


func _render_support(box: HBoxContainer, p: int) -> void:
	var pv := _pv(p)
	box.add_child(UIStyle.label("Traps/Spells", 11, UIStyle.MUTED))
	for i in 3:
		box.add_child(_slot_widget(pv["backrow"][i], p, "backrow", i, "mini"))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(24, 0)
	box.add_child(sp)
	box.add_child(UIStyle.label("Powers", 11, UIStyle.MUTED))
	for i in 4:
		box.add_child(_slot_widget(pv["powers"][i], p, "power", i, "mini"))


func _render_row(row: HBoxContainer, p: int, slots: Array) -> void:
	var pv := _pv(p)
	var tag := UIStyle.label("Front" if slots[0] == 0 else "Back", 11, UIStyle.MUTED)
	tag.custom_minimum_size = Vector2(40, 0)
	row.add_child(tag)
	for s in slots:
		row.add_child(_slot_widget(pv["units"][s], p, "unit", s, "board"))


func _slot_widget(cv, p: int, zone: String, slot: int, kind: String) -> CardWidget:
	var empty_label := ""
	match zone:
		"unit": empty_label = "%s %d" % ["Front" if slot < 3 else "Back", slot % 3 + 1]
		"backrow": empty_label = "Col %d" % (slot + 1)
		"power": empty_label = "Power %d" % (slot + 1)
	var w := CardWidget.new().setup(cv, kind, empty_label)
	w.set_meta("ref", {"p": p, "zone": zone, "slot": slot})
	w.pressed.connect(_on_widget_pressed)
	var opt := _option_for_ref(p, zone, slot)
	var is_sel: bool = cv != null and not cv.get("hidden", false) and cv.get("uid", -2) == selected_uid
	w.set_marks(opt != -1, is_sel or (opt != -1 and opt in multi))
	return w


func _widget(cv: Dictionary, kind: String) -> CardWidget:
	var w := CardWidget.new().setup(cv, kind)
	w.pressed.connect(_on_widget_pressed)
	var opt := _option_for_uid(cv.get("uid", -2))
	w.set_marks(opt != -1, cv.get("uid", -2) == selected_uid or (opt != -1 and opt in multi))
	return w


func _render_mid() -> void:
	var phase_names := {"main1": "Main Phase 1", "battle": "Battle Phase", "main2": "Main Phase 2", "end": "End of turn", "over": "Game over"}
	var turn_owner: String = _pv(mv["active"])["name"]
	mid_bar.add_child(UIStyle.label("Turn %d · %s · %s" % [mv["turn"], turn_owner, phase_names.get(mv["phase"], mv["phase"])], 16, UIStyle.TEXT))
	if mv["first_turn"]:
		mid_bar.add_child(UIStyle.label("(no Battle Phase on the first turn)", 12, UIStyle.MUTED))
	if mv["reversal"]:
		mid_bar.add_child(UIStyle.label("SNEAKY SNUNDAY: card-effect gains/losses reversed", 13, Color("ff9ff3")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_bar.add_child(sp)
	if mv["winner"] != -1:
		mid_bar.add_child(UIStyle.label("%s wins the game" % _pv(mv["winner"])["name"], 16, UIStyle.ACCENT))
		return
	for a in mv["actions"]:
		if a["t"] == "next_phase":
			var b := UIStyle.button(a["label"], 15)
			b.disabled = not a["ok"]
			b.tooltip_text = a["reason"]
			b.pressed.connect(func(): _send({"t": "next_phase"}))
			mid_bar.add_child(b)
	var concede := UIStyle.button("Concede game", 12)
	concede.pressed.connect(_confirm_concede)
	mid_bar.add_child(concede)


func _confirm_concede() -> void:
	_show_message("Concede this game?", [["Concede", func(): _send({"t": "concede"}); pile_popup.visible = false], ["Keep playing", func(): pile_popup.visible = false]])


# ---------------------------------------------------------------- selection & prompts

func _pending() -> Dictionary:
	if mv.is_empty():
		return {}
	return mv.get("pending", {})


func _option_for_ref(p: int, zone: String, slot: int) -> int:
	var pd := _pending()
	if pd.is_empty() or not pd["mine"]:
		return -1
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == p and o["ref"]["zone"] == zone and o["ref"]["slot"] == slot:
			return o["i"]
		if o.has("slot") and p == me() and not o.has("ref"):
			var oz: String = o.get("zone", "")
			var mapped := "unit" if oz in ["unit", "adjacent", "column", "orig"] else oz
			if mapped == zone and o["slot"] == slot and pd["kind"] == "slot":
				return o["i"]
	return -1


func _option_for_uid(uid: int) -> int:
	var pd := _pending()
	if pd.is_empty() or not pd["mine"]:
		return -1
	for o in pd["options"]:
		if o.has("card") and o["card"].get("uid", -1) == uid:
			return o["i"]
	return -1


func _on_widget_pressed(w: CardWidget) -> void:
	var opt := -1
	if w.has_meta("ref"):
		var r: Dictionary = w.get_meta("ref")
		opt = _option_for_ref(r["p"], r["zone"], r["slot"])
	if opt == -1 and not w.view.is_empty():
		opt = _option_for_uid(w.view.get("uid", -2))
	if opt != -1:
		_pick_option(opt)
		return
	if not w.view.is_empty() and not w.view.get("hidden", false):
		selected_uid = w.view["uid"]
		_render_all()


func _pick_option(i: int) -> void:
	var pd := _pending()
	if pd["max"] > 1:
		if i in multi:
			multi.erase(i)
		else:
			multi.append(i)
		_render_all()
		return
	_send({"t": "choose", "id": pd["id"], "indices": [i]})


func _send(cmd: Dictionary) -> void:
	toast.text = ""
	if client != null:
		client.send(cmd)


func _render_net_banner() -> bool:
	var net: Dictionary = view.get("net", {})
	if net.is_empty():
		return false
	var blocking := false
	if net.get("paused", false):
		prompt_box.add_child(UIStyle.label("MATCH PAUSED", 18, UIStyle.BAD))
		prompt_box.add_child(UIStyle.label(net["message"] if net.get("message", "") != "" else "Waiting for the connection to be restored. Nothing can happen until both players are connected.", 13, UIStyle.TEXT, true))
		blocking = true
	elif not net.get("opponent_connected", true) and net.get("is_host", false):
		prompt_box.add_child(UIStyle.label(net.get("message", "Waiting for an opponent…"), 14, UIStyle.ACCENT, true))
		if net.get("transport", "") == "steam":
			var inv := UIStyle.button("Invite a Steam friend", 14)
			inv.pressed.connect(func(): get_tree().call_group("net_session", "invite_friend"))
			prompt_box.add_child(inv)
	return blocking


func _render_prompt() -> void:
	_clear(prompt_box)
	if _render_net_banner():
		return
	var pd := _pending()
	if view.get("stage", "") != "game" or mv.is_empty():
		prompt_box.add_child(UIStyle.label(_stage_hint(), 14, UIStyle.MUTED, true))
		return
	if mv["winner"] != -1:
		prompt_box.add_child(UIStyle.label("Game over: %s wins." % _pv(mv["winner"])["name"], 16, UIStyle.ACCENT))
		return
	if pd.is_empty():
		var txt := "Your turn. Select a card to see its actions." if mv["active"] == me() else "Opponent's turn."
		if mv["resolving"]:
			txt = "Resolving…"
		prompt_box.add_child(UIStyle.label(txt, 14, UIStyle.TEXT if mv["active"] == me() else UIStyle.MUTED, true))
		return
	if not pd["mine"]:
		prompt_box.add_child(UIStyle.label(pd["prompt"], 14, UIStyle.ACCENT, true))
		prompt_box.add_child(UIStyle.label("You cannot act until this choice is made.", 12, UIStyle.MUTED, true))
		return
	var title := UIStyle.label(pd["prompt"], 15, UIStyle.TARGET, true)
	prompt_box.add_child(title)
	if pd["kind"] == "trap_response":
		prompt_box.add_child(UIStyle.label("Your opponent is waiting. Activate a Trap or pass.", 12, UIStyle.MUTED, true))
	# Cards shown only for this selection (e.g. a hidden pile) get previews; everything
	# else (zones, field cards, yes/no) is a full-width text button.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	var list := VBoxContainer.new()
	prompt_box.add_child(flow)
	prompt_box.add_child(list)
	for o in pd["options"]:
		var chosen: bool = o["i"] in multi
		if o.has("card") and not o.has("ref"):
			var cell := VBoxContainer.new()
			var w := CardWidget.new().setup(o["card"], "mini")
			w.set_marks(true, chosen)
			var idx: int = o["i"]
			w.pressed.connect(func(_w): _pick_option(idx))
			cell.add_child(w)
			var b := UIStyle.button(("✓ " if chosen else "") + "Choose", 11)
			b.pressed.connect(_pick_option.bind(o["i"]))
			cell.add_child(b)
			flow.add_child(cell)
		else:
			var b2 := UIStyle.button(("✓ " if chosen else "") + o["label"], 13)
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b2.tooltip_text = o["label"]
			b2.pressed.connect(_pick_option.bind(o["i"]))
			list.add_child(b2)
	if pd["max"] > 1:
		var total_txt := ""
		if pd.get("min_total", 0) > 0:
			var total := 0
			for i in multi:
				total += maxi(pd["options"][i].get("card", {}).get("cost", 0), 0)
			total_txt = "  ·  cost total %d / %d" % [total, pd["min_total"]]
		prompt_box.add_child(UIStyle.label("Selected %d (choose %d–%d)%s" % [multi.size(), pd["min"], pd["max"], total_txt], 12, UIStyle.MUTED))
		var confirm := UIStyle.button("Confirm selection", 14)
		confirm.disabled = multi.size() < pd["min"]
		confirm.pressed.connect(func(): _send({"t": "choose", "id": pd["id"], "indices": multi.duplicate()}))
		prompt_box.add_child(confirm)
	if pd["cancellable"]:
		var cancel := UIStyle.button("Cancel", 13)
		cancel.pressed.connect(func(): multi = []; _send({"t": "cancel", "id": pd["id"]}))
		prompt_box.add_child(cancel)


func _stage_hint() -> String:
	match view.get("stage", ""):
		"decks": return "Choose a deck."
		"rewards": return "Choose your rewards."
		"first_player": return "Choosing who goes first."
		"over": return "The series is over."
	return ""


# ---------------------------------------------------------------- details

func _find_card(uid: int) -> Dictionary:
	if mv.is_empty() or uid == -1:
		return {}
	for p in 2:
		var pv: Dictionary = mv["players"][p]
		for z in ["units", "backrow", "powers", "hand", "spent", "exhaust", "extra", "draw_inspect"]:
			for c in pv.get(z, []):
				if c != null and not c.get("hidden", false) and c.get("uid", -1) == uid:
					return c
	return {}


func _render_details() -> void:
	_clear(details_box)
	var c := _find_card(selected_uid)
	if c.is_empty():
		details_box.add_child(UIStyle.label("Card details", 14, UIStyle.ACCENT))
		details_box.add_child(UIStyle.label("Select any visible card to see its full text, live stats and the actions available to it.", 12, UIStyle.MUTED, true))
		return
	_card_details(details_box, c)
	var acts: Array = mv.get("actions", []).filter(func(a): return a.get("uid", -1) == selected_uid)
	if not acts.is_empty():
		details_box.add_child(UIStyle.label("Actions", 13, UIStyle.ACCENT))
		for a in acts:
			var b := UIStyle.button(a["label"], 13)
			b.disabled = not a["ok"]
			b.tooltip_text = a["reason"]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var cmd := {"t": a["t"], "uid": a["uid"]}
			if a.has("idx"):
				cmd["idx"] = a["idx"]
			b.pressed.connect(func(): _send(cmd))
			details_box.add_child(b)
			if not a["ok"] and a["reason"] != "":
				details_box.add_child(UIStyle.label("   " + a["reason"], 11, UIStyle.MUTED, true))


func _card_details(box: VBoxContainer, c: Dictionary) -> void:
	box.add_child(UIStyle.label(c["name"], 18, UIStyle.ACCENT, true))
	var cat_line := "%s  ·  Cost: %s" % [UIStyle.CATEGORY_NAMES[c["category"]], c["cost_text"]]
	box.add_child(UIStyle.label(cat_line, 13, UIStyle.TEXT, true))
	if c.has("race"):
		box.add_child(UIStyle.label("Race: %s   Type: %s" % [c["race"] if c["race"] != "" else "None (no race)", c["type"] if c["type"] != "" else "None (no type)"], 13))
		var pa = c.get("printed_atk")
		var pd = c.get("printed_def")
		box.add_child(UIStyle.label("ATK %s   DEF %s   (printed %s / %s)" % [str(c.get("atk", "?")), str(c.get("def", "?")),
			"?" if pa == null else str(pa), "?" if pd == null else str(pd)], 14))
		for part in c.get("stat_parts", []):
			box.add_child(UIStyle.label("  • " + part, 11, UIStyle.MUTED, true))
		if c.get("zone", "") == "unit":
			var flags := []
			flags.append("Attack stance" if c["stance"] == "atk" else "Defense stance")
			if c.get("protected", false):
				flags.append("Protected")
			if c.get("new", false):
				flags.append("Summoned this turn")
			if c.get("attacked", false):
				flags.append("Attacked this turn")
			box.add_child(UIStyle.label(" · ".join(flags), 12, UIStyle.MUTED, true))
	var any_status := false
	if c.get("runes", 0) > 0:
		box.add_child(UIStyle.label("Rune ×%d — %s" % [c["runes"], CardDB.STATUS_HELP["rune"]], 12, Color("8fc1ff"), true))
		any_status = true
	for s in CardDB.STATUS_ORDER:
		var n: int = c.get("statuses", {}).get(s, 0)
		if n > 0:
			any_status = true
			box.add_child(UIStyle.label("%s ×%d — %s" % [s.capitalize(), n, CardDB.STATUS_HELP[s]], 12, Color("9be7b7") if CardDB.is_buff(s) else Color("ff9d9d"), true))
	if not any_status and c.has("race"):
		box.add_child(UIStyle.label("No statuses.", 12, UIStyle.MUTED))
	var text: String = c.get("text", "")
	box.add_child(UIStyle.label(text if text != "" else "No effect text.", 13, UIStyle.TEXT, true))
	var sup: String = c.get("support", "full")
	if sup != "full":
		box.add_child(UIStyle.label("Implementation: %s" % sup, 12, UIStyle.BAD, true))


# ---------------------------------------------------------------- log

func _render_log() -> void:
	if mv.is_empty():
		return
	var game_no: int = view.get("game_no", 0)
	if game_no != _log_game:
		log_label.clear()
		_log_seq_shown = 0
		_log_game = game_no
		log_label.append_text("[color=#f2b544]Game %d[/color]\n" % game_no)
	for e in mv.get("log", []):
		if e["seq"] <= _log_seq_shown:
			continue
		_log_seq_shown = e["seq"]
		var t: String = e["text"]
		var col := "#e8e6e1"
		if t.begins_with("—"):
			col = "#f2b544"
		elif t.contains("loses") and t.contains("HP"):
			col = "#ff8a8a"
		elif t.contains("gains") and t.contains("HP"):
			col = "#8fe3a8"
		elif t.begins_with("Battle:"):
			col = "#ffd84a"
		elif t.begins_with("GAME OVER"):
			col = "#ff9ff3"
		log_label.append_text("[color=%s]%s[/color]\n" % [col, t.replace("[", "(").replace("]", ")")])


# ---------------------------------------------------------------- piles

func _show_pile(zone: String) -> void:
	_clear(pile_box)
	var pv := _pv(me())
	var key := "draw_inspect" if zone == "draw" else zone
	var head := HBoxContainer.new()
	pile_box.add_child(head)
	var title := "Your %s (%d)" % [zone.capitalize() if zone != "extra" else "Extra Deck", pv.get(key, []).size()]
	if zone == "draw":
		title += " — shown in a random order; the real Draw order is unchanged"
	var tl := UIStyle.label(title, 15, UIStyle.ACCENT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := UIStyle.button("Close", 13)
	close.pressed.connect(func(): pile_popup.visible = false)
	head.add_child(close)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	pile_box.add_child(flow)
	for c in pv.get(key, []):
		var w := CardWidget.new().setup(c, "hand")
		w.pressed.connect(func(_w):
			selected_uid = c["uid"]
			_render_details())
		flow.add_child(w)
	if pv.get(key, []).is_empty():
		pile_box.add_child(UIStyle.label("Empty.", 13, UIStyle.MUTED))
	pile_popup.visible = true


func _show_message(text: String, buttons: Array) -> void:
	_clear(pile_box)
	pile_box.add_child(UIStyle.label(text, 16, UIStyle.ACCENT, true))
	var row := HBoxContainer.new()
	pile_box.add_child(row)
	for pair in buttons:
		var b := UIStyle.button(pair[0], 14)
		b.pressed.connect(pair[1])
		row.add_child(b)
	pile_popup.visible = true


# ---------------------------------------------------------------- series stages (overlay)

func _render_overlay() -> void:
	_clear(overlay_box)
	var stage: String = view.get("stage", "")
	if stage == "game" or _overlay_hidden_by_user:
		overlay.visible = false
		if _overlay_hidden_by_user and stage != "game":
			var back := UIStyle.button("Return to %s" % _stage_title(stage), 14)
			back.pressed.connect(func(): _overlay_hidden_by_user = false; _render_overlay())
			_clear(prompt_box)
			prompt_box.add_child(back)
		return
	overlay.visible = true
	overlay_box.add_child(UIStyle.label(_stage_title(stage), 26, UIStyle.ACCENT))
	overlay_box.add_child(UIStyle.label("Score %d – %d  ·  best of %d" % [view["scores"][0], view["scores"][1], view["best_of"]], 15, UIStyle.MUTED))
	match stage:
		"decks": _render_decks()
		"rewards": _render_rewards()
		"first_player": _render_first()
		"over": _render_over()
	if not mv.is_empty() and stage != "decks":
		var see := UIStyle.button("View the final board and log of game %d" % view["game_no"], 13)
		see.pressed.connect(func(): _overlay_hidden_by_user = true; _render_all())
		overlay_box.add_child(see)


func _stage_title(stage: String) -> String:
	match stage:
		"decks": return "Choose your deck" if view.get("deck_mode", "starter") == "starter" else "Draft your deck"
		"rewards": return "Game %d complete — rewards" % view["game_no"]
		"first_player": return "Next game"
		"over": return "Series over"
	return ""


func _game_result_line() -> String:
	if view.get("history", []).is_empty():
		return ""
	var h: Dictionary = view["history"][-1]
	return "%s won game %d (turn %d, HP %d–%d)." % [view["names"][h["winner"]], h["game"], h["turns"], h["hp"][0], h["hp"][1]]


func _render_decks() -> void:
	var p := me()
	if view["deck_ready"][p]:
		overlay_box.add_child(UIStyle.label("Deck locked in: %s. Waiting for your opponent…" % view["deck_name"], 16, UIStyle.TEXT, true))
		return
	if view.has("starters"):
		for i in view["starters"].size():
			var s: Dictionary = view["starters"][i]
			var row := HBoxContainer.new()
			overlay_box.add_child(row)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			col.add_child(UIStyle.label(s["name"], 18, UIStyle.TEXT))
			col.add_child(UIStyle.label(s["theme"], 13, UIStyle.MUTED))
			var names_txt := ", ".join(s["main"].map(func(c): return c["name"]))
			col.add_child(UIStyle.label("Main (%d): %s" % [s["main"].size(), names_txt], 11, UIStyle.MUTED, true))
			col.add_child(UIStyle.label("Extra Deck: %s" % ", ".join(s["extra"].map(func(c): return c["name"])), 11, UIStyle.MUTED, true))
			var b := UIStyle.button("Choose %s" % s["name"], 14)
			b.pressed.connect(func(): _send({"t": "pick_starter", "index": i}))
			row.add_child(b)
		return
	var dr: Dictionary = view["draft"]
	overlay_box.add_child(UIStyle.label("Pick %d of %d — %s" % [dr["step"] + 1, dr["total"], String(dr["category"]).capitalize()], 18, UIStyle.TEXT))
	var flow := HFlowContainer.new()
	overlay_box.add_child(flow)
	for i in dr["offer"].size():
		var c: Dictionary = dr["offer"][i]
		var cell := VBoxContainer.new()
		cell.add_child(CardWidget.new().setup(_summary_view(c), "big"))
		var b2 := UIStyle.button("Pick", 14)
		b2.pressed.connect(func(): _send({"t": "draft_pick", "index": i}))
		cell.add_child(b2)
		flow.add_child(cell)
	overlay_box.add_child(UIStyle.label("Picked: " + ", ".join(dr["picked"].map(func(c): return c["name"])), 12, UIStyle.MUTED, true))


func _summary_view(c: Dictionary) -> Dictionary:
	var kind := "ap"
	var printed = null
	match c["category"]:
		"fusion": kind = "fusion"
		"ritual": kind = "ritual"
		"arcane": kind = "arcane"
	var d := CardDB.get_def(c["id"])
	printed = d["cost"]
	return {"uid": -1000 - c["id"], "id": c["id"], "name": c["name"], "category": c["category"], "cost_kind": kind,
		"cost_text": c["cost_text"], "cost": printed if printed != null else 0, "printed_cost": printed,
		"race": c["race"], "type": c["type"], "atk": c["atk"], "def": c["def"], "printed_atk": c["atk"], "printed_def": c["def"],
		"text": c["text"], "support": c["support"], "art": d["art"], "statuses": {}, "runes": 0, "zone": "pile"}


func _render_rewards() -> void:
	overlay_box.add_child(UIStyle.label(_game_result_line(), 16, UIStyle.TEXT, true))
	var r: Dictionary = view["rewards"]
	if r["done"]:
		overlay_box.add_child(UIStyle.label("You have finished choosing rewards. Waiting for your opponent…" if not r["opponent_done"] else "Starting soon…", 15, UIStyle.TEXT, true))
		for t in r["taken"]:
			overlay_box.add_child(UIStyle.label("• " + t, 13, UIStyle.MUTED))
		return
	overlay_box.add_child(UIStyle.label("Rewards left to choose: %d — any combination of adding a card, removing a card or changing a basic unit's Type." % r["left"], 15, UIStyle.ACCENT, true))
	if r["opponent_done"]:
		overlay_box.add_child(UIStyle.label("Your opponent has finished.", 12, UIStyle.MUTED))
	for t in r["taken"]:
		overlay_box.add_child(UIStyle.label("✓ " + t, 13, UIStyle.GOOD))
	overlay_box.add_child(UIStyle.label("Add a card (pick one of these):", 15, UIStyle.TEXT))
	var flow := HFlowContainer.new()
	overlay_box.add_child(flow)
	for i in r["offer"].size():
		var c: Dictionary = r["offer"][i]
		var cell := VBoxContainer.new()
		cell.add_child(CardWidget.new().setup(_summary_view(c), "big"))
		var b := UIStyle.button("Add %s" % c["name"], 12)
		b.pressed.connect(func(): _send({"t": "reward_add", "index": i}))
		cell.add_child(b)
		flow.add_child(cell)
	overlay_box.add_child(UIStyle.label("Remove a card from your deck:", 15, UIStyle.TEXT))
	var deck_flow := HFlowContainer.new()
	overlay_box.add_child(deck_flow)
	var counts := {}
	var order := []
	for c in view["deck"]:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	for c in order:
		var b2 := UIStyle.button("− %s%s" % [c["name"], " ×%d" % counts[c["id"]] if counts[c["id"]] > 1 else ""], 12)
		b2.tooltip_text = c["text"]
		b2.pressed.connect(func(): _send({"t": "reward_remove", "card_id": c["id"]}))
		deck_flow.add_child(b2)
	overlay_box.add_child(UIStyle.label("Change a basic unit's Type (all copies):", 15, UIStyle.TEXT))
	for c in order:
		if c["category"] != "basic_unit":
			continue
		var row := HBoxContainer.new()
		overlay_box.add_child(row)
		row.add_child(UIStyle.label("%s ×%d →" % [c["name"], counts[c["id"]]], 13))
		for t in r["basic_types"]:
			if t == c["type"]:
				continue
			var tb := UIStyle.button(t, 12)
			tb.add_theme_color_override("font_color", UIStyle.type_color(t).lightened(0.3))
			tb.pressed.connect(func(): _send({"t": "reward_basic", "from_id": c["id"], "to_type": t}))
			row.add_child(tb)
	var fin := UIStyle.button("Skip remaining rewards", 13)
	fin.pressed.connect(func(): _send({"t": "reward_finish"}))
	overlay_box.add_child(fin)


func _render_first() -> void:
	overlay_box.add_child(UIStyle.label(_game_result_line(), 16, UIStyle.TEXT, true))
	if view["last_loser"] == me():
		overlay_box.add_child(UIStyle.label("You lost the last game, so you choose who goes first in game %d." % (view["game_no"] + 1), 16, UIStyle.ACCENT, true))
		var row := HBoxContainer.new()
		overlay_box.add_child(row)
		var b1 := UIStyle.button("I go first", 15)
		b1.pressed.connect(func(): _send({"t": "first_player", "who": me()}))
		row.add_child(b1)
		var b2 := UIStyle.button("My opponent goes first", 15)
		b2.pressed.connect(func(): _send({"t": "first_player", "who": 1 - me()}))
		row.add_child(b2)
	else:
		overlay_box.add_child(UIStyle.label("Your opponent lost the last game and is choosing who goes first…", 15, UIStyle.TEXT, true))


func _render_over() -> void:
	var w := 0 if view["scores"][0] > view["scores"][1] else 1
	overlay_box.add_child(UIStyle.label("%s wins the series %d–%d." % [view["names"][w], view["scores"][0], view["scores"][1]], 20, UIStyle.TEXT))
	for h in view["history"]:
		overlay_box.add_child(UIStyle.label("Game %d: %s (turn %d, HP %d–%d)" % [h["game"], view["names"][h["winner"]], h["turns"], h["hp"][0], h["hp"][1]], 13, UIStyle.MUTED))
	var b := UIStyle.button("Back to main menu", 15)
	b.pressed.connect(func(): back_to_menu.emit())
	overlay_box.add_child(b)
