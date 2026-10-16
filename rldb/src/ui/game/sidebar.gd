class_name GameSidebar
extends RefCounted
## Right-hand column of the match screen: game log (top), card details / own pile list
## (middle) and the turn panel (bottom), or the series summary between games.

var gs: GameScreen
var side_root: Control
var turn_title: Label
var turn_note: Label
var pips: PhasePips
## Turn-bar row: the phase button, or the state chip while a choice is pending.
var brow: HBoxContainer
var phase_btn: Button
var state_chip: PanelContainer
var state_label: Label
var series_panel: PanelContainer
var series_box: VBoxContainer
var details_panel: PanelContainer
var log_panel: PanelContainer
## Hash of the series summary last rendered (0 forces a re-render).
var series_sig: int = 0


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the sidebar column (with the details and log panels of their components).
func build() -> void:
	side_root = Control.new()
	side_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gs.add_child(side_root)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 4
	col.offset_right = -8
	col.offset_top = 8
	col.offset_bottom = -8
	col.add_theme_constant_override("separation", 8)
	side_root.add_child(col)
	# Turn bar
	var tp := GameUi.side_panel()
	col.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tp.add_child(tv)
	turn_title = UIStyle.label("", 19, UIStyle.TEXT, false, true)
	turn_title.clip_text = true
	tv.add_child(turn_title)
	pips = PhasePips.new()
	tv.add_child(pips)
	brow = HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	tv.add_child(brow)
	phase_btn = UIStyle.primary_button("", 16)
	phase_btn.custom_minimum_size = Vector2(0, 44)
	phase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_btn.pressed.connect(func(): gs.send({"t": "next_phase"}))
	brow.add_child(phase_btn)
	# Status chip (NOT a button): shown instead of the phase button while a choice is pending.
	state_chip = PanelContainer.new()
	var cs := UIStyle.flat(Color(UIStyle.GOLD, 0.1), Color(UIStyle.GOLD, 0.55), 1, 6)
	cs.border_width_left = 6
	cs.content_margin_left = 10
	cs.content_margin_right = 8
	state_chip.add_theme_stylebox_override("panel", cs)
	state_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_chip.custom_minimum_size = Vector2(0, 44)
	state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_chip.visible = false
	state_label = UIStyle.label("", 15, UIStyle.GOLD_HI, false, true)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_chip.add_child(state_label)
	brow.add_child(state_chip)
	turn_note = UIStyle.label("", 13, Color("ff9ff3"), true)
	turn_note.visible = false
	tv.add_child(turn_note)
	# Series summary (deck selection, rewards, between games, series over)
	series_panel = GameUi.side_panel()
	series_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(series_panel)
	series_box = VBoxContainer.new()
	series_box.add_theme_constant_override("separation", 6)
	series_panel.add_child(series_box)
	details_panel = gs.details.build(col)
	log_panel = gs.game_log.build(col)
	# Log on top, card details in the middle, the turn panel at the bottom (user feedback).
	col.move_child(log_panel, 0)
	col.move_child(tp, col.get_child_count() - 1)


## Pins the column to the right edge, scaled by the screen's sidebar factor.
func layout(w: float, h: float) -> void:
	side_root.scale = Vector2(gs.side_k, gs.side_k)
	side_root.position = Vector2(w - gs.sidebar_w, 0)
	side_root.size = Vector2(GameScreen.SIDEBAR_W, h / gs.side_k)


## Turn panel: whose turn, phase pips and the phase button (or the state chip while a choice is
## pending); between games only the stage title. Also drives the wait notice.
func render_turnbar() -> void:
	var view := gs.view
	var mv := gs.mv
	var stage: String = view.get("stage", "")
	var in_game := not mv.is_empty() and stage == "game"
	pips.visible = in_game
	brow.visible = in_game
	details_panel.visible = in_game
	log_panel.visible = not mv.is_empty()
	series_panel.visible = not in_game
	gs.menu.update_conn()
	if not in_game:
		# Between games / before the first game nothing of the finished game's turn state is shown.
		turn_title.text = gs.overlays.stage_title(stage) if stage != "" else "Series"
		turn_note.visible = false
		return
	var owner_name: String = gs.pv(mv["active"])["name"]
	turn_title.text = "Turn %d · %s" % [mv["turn"], owner_name]
	pips.phase = mv["phase"]
	pips.queue_redraw()
	var pd := gs.pending()
	var label := ""
	var ok := false
	var tip := ""
	for a in mv.get("actions", []):
		if a["t"] == "next_phase":
			label = a["label"]
			ok = a["ok"]
			tip = a["reason"]
	var chip := ""
	var chip_mine := false
	if mv["winner"] != -1:
		chip = "Game over"
	elif not pd.is_empty():
		var resp: bool = pd["kind"] == "trap_response"
		if pd["mine"]:
			chip_mine = true
			chip = "Your response" if resp else ("Choose a target" if gs.selection.board_targeting() else "Your choice")
		else:
			chip = "Opponent is responding…" if resp else "Opponent is choosing…"
	elif mv["active"] != gs.me():
		chip = "Opponent's turn"
	elif mv["resolving"]:
		chip = "Resolving…"
	elif label == "":
		chip = "Please wait…"
	if mv["active"] == gs.me() and mv["first_turn"] and ok:
		tip = "No Battle Phase on the first turn."
	state_chip.visible = chip != ""
	phase_btn.visible = chip == ""
	var waiting: bool = not pd.is_empty() and not pd["mine"] and mv["winner"] == -1
	gs.prompt.show_wait((("Opponent is responding…" if pd["kind"] == "trap_response" else "Opponent is choosing…") if waiting else ""))
	state_label.text = chip
	state_label.add_theme_color_override("font_color", UIStyle.GOLD_HI if chip_mine else UIStyle.MUTED)
	phase_btn.text = label
	phase_btn.disabled = not ok
	phase_btn.tooltip_text = tip
	var note := ""
	if mv["reversal"]:
		note = "SNEAKY SNUNDAY: card-effect gains/losses reversed"
	turn_note.text = note
	turn_note.visible = note != ""


## Sidebar summary shown instead of the turn/log panels while no game is being played.
func render_series() -> void:
	var view := gs.view
	if view.is_empty() or view.get("stage", "") == "game":
		return
	var stage: String = view.get("stage", "")
	var sig := hash([stage, view.get("scores"), view.get("history"), view.get("deck_ready"), view.get("names"), view.get("best_of"), view.get("you"), view.get("game_no")])
	if sig == series_sig:
		return
	series_sig = sig
	GameUi.clear(series_box)
	series_box.add_child(GameUi.header("Series"))
	var names: Array = view["names"]
	for p in 2:
		var row := HBoxContainer.new()
		series_box.add_child(row)
		var nm := UIStyle.label(String(names[p]) + ("  (you)" if p == gs.me() else ""), 17, UIStyle.TEXT, false, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		row.add_child(nm)
		row.add_child(UIStyle.label(str(view["scores"][p]), 24, UIStyle.GOLD, false, true))
		if stage == "decks":
			series_box.add_child(UIStyle.label("Deck ready" if view["deck_ready"][p] else "Choosing a deck…", 14, UIStyle.GOOD if view["deck_ready"][p] else UIStyle.MUTED))
	series_box.add_child(UIStyle.label("Best of %d" % view["best_of"], 14, UIStyle.MUTED))
	for h in view.get("history", []):
		series_box.add_child(UIStyle.label("Game %d: %s won (turn %d)" % [h["game"], names[h["winner"]], h["turns"]], 14, UIStyle.TEXT, true))
