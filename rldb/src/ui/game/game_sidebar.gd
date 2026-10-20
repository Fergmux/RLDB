class_name GameSidebar
extends RefCounted
## Right-hand column of the match screen: game log (top), card details / own pile list
## (middle) and the turn panel (bottom), or the series summary between games.

## The host screen this component works on.
var gs: GameScreen
## Root of the sidebar column.
var side_root: Control
## The turn number (J7: not whose turn it is; the player plates mark that).
var turn_title: Label
## Secondary turn text.
var turn_note: Label
## Game and turn clock beside the turn title (C2).
var clock_view: DuelClockView
## Phase indicator.
var pips: PhasePips
## Turn-bar row: the phase button, or the state chip while a choice is pending.
var brow: HBoxContainer
## Advance-phase button.
var phase_btn: Button
## #41: its "do this next" cue (breathing rim and sweep) while nothing else is left to do.
var cta: CtaCue
## The status line's arrow towards the prompt pane (shown while the choice is this player's).
var state_arrow: Control
## Chip showing the game state.
var state_chip: PanelContainer
## Text of the state chip.
var state_label: Label
## Series score panel.
var series_panel: PanelContainer
## Content of the series panel.
var series_box: VBoxContainer
## The turn panel (turn title, phase track, the main action); hidden between games (#49: it only
## echoed the modal's title there).
var turn_panel: Control
## The series medallion while no game is being played (#49).
var medallion: SeriesMedallion
## Panel holding the card details.
var details_panel: PanelContainer
## Panel holding the game log.
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
	# D5 / #109: the HUD safe margin on the screen edge (right), lg top and bottom, md between panels.
	col.offset_left = UIStyle.sp("xs")
	col.offset_right = -UIStyle.SAFE_HUD
	col.offset_top = UIStyle.sp("lg")
	col.offset_bottom = -UIStyle.sp("lg")
	UIStyle.pad(col, "md")
	side_root.add_child(col)
	# Turn bar
	var tp := GameUi.side_panel()
	turn_panel = tp
	col.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tp.add_child(tv)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	tv.add_child(title_row)
	turn_title = UIStyle.label("", 19, UIStyle.TEXT, false, true)
	turn_title.clip_text = true
	turn_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(turn_title)
	clock_view = DuelClockView.new()
	clock_view.visible = false
	title_row.add_child(clock_view)
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
	cta = CtaCue.new()
	phase_btn.add_child(cta)
	# Status line (NOT a button, design review #40): shown instead of the phase button while a choice
	# is pending or it is not this player's move. An engraved F3 inset with italic MUTED text, so a
	# status never shares the call-to-action's look; when the choice is the player's, a gold arrow
	# bobs towards the prompt pane on the left of the board.
	state_chip = PanelContainer.new()
	var cs := UIStyle.inset_style(Color(UIStyle.PANEL_INK, 0.92))
	UIStyle.pad(cs, "md", "sm")
	state_chip.add_theme_stylebox_override("panel", cs)
	state_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_chip.custom_minimum_size = Vector2(0, 44)
	state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_chip.visible = false
	var srow := HBoxContainer.new()
	UIStyle.pad(srow, "sm")
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_chip.add_child(srow)
	state_arrow = PromptArrow.new()
	state_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(state_arrow)
	state_label = UIStyle.label("", 14, UIStyle.MUTED)
	state_label.add_theme_font_override("font", UIStyle.font_italic())
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.clip_text = true
	state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	srow.add_child(state_label)
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
	_col_h = h / gs.side_k
	if _log_tw != null and _log_tw.is_valid():
		_log_tw.kill()
	log_panel.custom_minimum_size.y = log_height(_col_h, GameLog.expanded())


## #48 / H11 (owner, 21 Oct): the game log takes LOG_SHARE of the sidebar's height (at least
## LOG_MIN_H) by default, or LOG_SHARE_TALL (at least LOG_MIN_TALL, a little more than the 0.28 / 180
## it used to have) once the viewer expands it; the card details below get the rest.
const LOG_SHARE := 0.22
const LOG_MIN_H := 150.0
const LOG_SHARE_TALL := 0.34
const LOG_MIN_TALL := 220.0

## Sidebar height (layout px) of the last layout, and the log's height tween.
var _col_h: float = 0.0
var _log_tw: Tween


## Height of the log panel in a sidebar `col_h` tall (layout px), short or `tall`.
static func log_height(col_h: float, tall: bool = false) -> float:
	if tall:
		return maxf(LOG_MIN_TALL, roundf(col_h * LOG_SHARE_TALL))
	return maxf(LOG_MIN_H, roundf(col_h * LOG_SHARE))


## H11: eases the log panel to the height of the viewer's choice (the "slide" motion; at once under
## reduce motion). The log keeps following its newest line.
func animate_log() -> void:
	if log_panel == null or _col_h <= 0.0:
		return
	var to := log_height(_col_h, GameLog.expanded())
	if _log_tw != null and _log_tw.is_valid():
		_log_tw.kill()
	if UIStyle.reduce_motion or not log_panel.is_inside_tree():
		log_panel.custom_minimum_size.y = to
		return
	_log_tw = log_panel.create_tween()
	UIStyle.tween_token(_log_tw, log_panel, "custom_minimum_size:y", to, "slide")


## Turn panel: whose turn, phase pips and the phase button (or the state chip while a choice is
## pending); between games only the stage title. Also drives the wait notice.
func render_turnbar() -> void:
	var view := gs.view
	var mv := gs.mv
	var stage: String = view.get("stage", "")
	var in_game := not mv.is_empty() and stage == "game"
	pips.visible = in_game
	brow.visible = in_game
	details_panel.visible = in_game or gs.details.is_drafting()
	log_panel.visible = not mv.is_empty()
	series_panel.visible = not in_game
	gs.menu.update_conn()
	var clk := DuelClock.for_view(view) if in_game else null
	if clk != null:
		clk.observe(view)
	if clock_view.clock != clk:
		clock_view.set_clock(clk)
	turn_panel.visible = in_game
	if not in_game:
		# Between games / before the first game nothing of the finished game's turn state is shown.
		turn_title.text = gs.overlays.stage_title(stage) if stage != "" else "Series"
		turn_note.visible = false
		return
	var owner_name: String = gs.pv(mv["active"])["name"]
	# J7 (owner, 22 Oct): the turn number only; the player plates already mark whose turn it is, and
	# the name ran into the clock.
	turn_title.text = "Turn %d" % mv["turn"]
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
	var spec := gs.is_spectator()
	var actor: String = gs.pv(int(pd.get("player", mv["active"])))["name"] if not pd.is_empty() else owner_name
	if spec:
		# A2: a spectator is told who is acting; there is never a button to press.
		if mv["winner"] != -1:
			chip = "Game over"
		elif not pd.is_empty():
			chip = ("%s is responding…" if pd["kind"] == "trap_response" else "%s is choosing…") % actor
		elif mv["resolving"]:
			chip = "Resolving…"
		else:
			chip = "%s's turn" % owner_name
		state_chip.visible = true
		phase_btn.visible = false
		state_label.text = chip
		state_label.add_theme_color_override("font_color", UIStyle.MUTED)
		state_arrow.visible = false
		var waiting_s: bool = not pd.is_empty() and mv["winner"] == -1
		gs.prompt.show_wait(chip if waiting_s else "")
		turn_note.text = "SNEAKY SNUNDAY: card-effect gains/losses reversed (not Damage or Healing)" if mv["reversal"] else ""
		turn_note.visible = turn_note.text != ""
		return
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
	state_label.add_theme_color_override("font_color", UIStyle.TEXT if chip_mine else UIStyle.MUTED)
	state_arrow.visible = chip_mine
	phase_btn.text = label
	phase_btn.disabled = not ok
	cta.set_on(chip == "" and ok and nothing_left(mv.get("actions", [])))
	phase_btn.tooltip_text = tip
	var note := ""
	if mv["reversal"]:
		note = "SNEAKY SNUNDAY: card-effect gains/losses reversed (not Damage or Healing)"
	turn_note.text = note
	turn_note.visible = note != ""


## #41: true when none of `actions` is a legal play other than moving on (stance changes and
## sacrifices are always open in Main 1 and do not count, as for the ready marks).
static func nothing_left(actions: Array) -> bool:
	for a in actions:
		if bool(a.get("ok", false)) and String(a.get("t", "")) in GameBoardView.READY_KINDS:
			return false
	return true


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
	var history: Array = view.get("history", [])
	# #49: the Best-of medallion with one socket per game (won / lost gems, the next one breathing).
	var res := []
	for h in history:
		res.append(0 if int(h["winner"]) == gs.me() else 1)
	medallion = SeriesMedallion.new().setup(int(view.get("best_of", 3)), res, -1 if stage == "over" else history.size())
	medallion.name = "SeriesMedallion"
	series_box.add_child(_gap(UIStyle.sp("sm")))
	series_box.add_child(medallion)
	series_box.add_child(_gap(UIStyle.sp("lg")))
	for p in 2:
		series_box.add_child(_seat_plate(p, String(names[p]) + ("  (you)" if p == gs.me() and not gs.is_spectator() else ""), int(view["scores"][p]), stage, bool(view["deck_ready"][p])))
	if not history.is_empty():
		series_box.add_child(_gap(UIStyle.sp("md")))
		series_box.add_child(GameUi.header("Games"))
	for h in history:
		var won: bool = int(h["winner"]) == gs.me()
		var line := UIStyle.label("Game %d: %s won (turn %d)" % [h["game"], names[h["winner"]], h["turns"]], 14, UIStyle.TEXT if won else UIStyle.MUTED, true)
		series_box.add_child(line)


## A fixed vertical gap of `h` px.
static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## One player of the series (#49): an F3 well with the name and score, and in the deck choice a
## status line: "Choosing a deck" with the waiting dots, or "Deck ready" with a tick.
func _seat_plate(p: int, title: String, score: int, stage: String, ready: bool) -> Control:
	var well := UIStyle.inset(UIStyle.PANEL_INK, 0.25)
	(well.get_theme_stylebox("panel") as StyleBox).content_margin_left = UIStyle.sp("md")
	(well.get_theme_stylebox("panel") as StyleBox).content_margin_right = UIStyle.sp("md")
	well.name = "SeatPlate%d" % p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UIStyle.sp("xs"))
	well.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var nm := UIStyle.label(title, 17, UIStyle.TEXT, false, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(nm)
	row.add_child(UIStyle.label(str(score), 24, UIStyle.GOLD, false, true))
	if stage == "decks":
		if ready:
			v.add_child(UIStyle.label("\u2713 Deck ready", 14, UIStyle.GOOD))
		else:
			var dots := WaitingDots.new("Choosing a deck", 14, UIStyle.MUTED)
			dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(dots)
	return well


## Gold chevron pointing left (towards the prompt pane), bobbing 4 px on a 1.2 s loop; still under
## reduce motion. Design review #40.
class PromptArrow extends Control:
	const BOB_PX := 4.0
	const PERIOD := 1.2

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree() and not UIStyle.reduce_motion)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var off := 0.0
		if not UIStyle.reduce_motion:
			off = -BOB_PX * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 / PERIOD * TAU))
		var c := size / 2.0 + Vector2(off + 2.0, 0)
		var pts := PackedVector2Array([c + Vector2(4, -7), c + Vector2(-5, 0), c + Vector2(4, 7)])
		draw_polyline(pts, Color(UIStyle.GOLD, 0.3), 6.0, true)
		draw_polyline(pts, UIStyle.GOLD_HI, 2.4, true)
