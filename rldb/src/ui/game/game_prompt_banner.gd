class_name GamePromptBanner
extends RefCounted
## My pending choice and the notices over the board: the F02-07 context banner (what is being
## chosen, non-card options, Confirm / Cancel), the F02-10 pile tray, the opponent-is-deciding
## notice and the short toast.

const TRAY_GAP := 10.0
## Padding inside the tray's house plate (clears the corner flourishes).
const TRAY_PAD := 20.0
const TRAY_MAX_COLS := 8
const TRAY_MIN_W := 280.0
const BANNER_MIN_W := 300.0
const BANNER_MAX_W := 380.0
## Narrowest free column beside the board the banner may sit in (F03-25), and its margin to the zones.
const BANNER_SIDE_MIN_W := 170.0
## Below this width the side column is "narrow": the card strip stacks the card above its text and
## shows fewer rules lines, so the panel stays in the free column instead of covering the board.
const BANNER_NARROW_W := 240.0
## Rules lines of the card strip in the narrow side column and in the top-centre fallback.
const SUBJECT_LINES_NARROW := 3
const BANNER_SIDE_MAX_W := 300.0
## Headline size of the panel, and its size in the narrow side column (keeps titles to a few lines).
const HEADLINE_PX := 21
const HEADLINE_NARROW_PX := 17
## G04: the headline of an exact-payment (Arcane) choice is a step smaller; with the cost circles
## it is the whole instruction (no status line between them).
const HEADLINE_PAY_PX := 19
const HEADLINE_PAY_NARROW_PX := 16
const BANNER_GAP := 12.0
## Breathing border period (s).
const BANNER_BREATH := 1.4
const OPTION_H := 32
## F05: size of the card image in the input panel, and the most rules-text lines shown there
## (the full text is its tooltip and the right-click inspection).
const SUBJECT_CARD := Vector2(64, 96)
const SUBJECT_LINES := 6
## The card strip in a short side column (compact): a smaller card and fewer rules lines.
const SUBJECT_CARD_COMPACT := Vector2(44, 66)
const SUBJECT_LINES_COMPACT := 2
## Type-choice buttons (F03): the icon box's left inset and its largest side (the left content
## margin of 42 px holds it with a gap before the label).
const TYPE_ICON_X := 9.0
const TYPE_ICON_MAX := 28.0
## Type-button label size, and the compact label size and left margin (still clears the icon box).
const TYPE_PX := 15
## Gap between Type-grid columns, and the most columns.
const TYPE_GRID_SEP := 6
const TYPE_GRID_MAX_COLS := 3
const TYPE_COMPACT_PX := 13
const TYPE_COMPACT_LEFT := 38
## G03: largest and smallest card of the response strip (attacker -> target, the responding card),
## and the card size in the compact top-strip panel.
const MENTION_CARD_MAX := 56.0
const MENTION_CARD_MIN := 38.0
const MENTION_CARD_TOP := Vector2(36, 54)
## Card width of the strip in a short side column (compact), and the rules lines of a responding card.
const MENTION_CARD_COMPACT := 42.0
const RESPONSE_LINES := 2
## Name size under a strip card, and the smallest it shrinks to so a long word fits.
const MENTION_NAME_PX := 12
const MENTION_NAME_MIN_PX := 9
## Name size of a responding card beside its picture.
const RESPONSE_NAME_PX := 14
## Width of the arrow between an attacker and its target in the response strip.
const MENTION_ARROW_W := 22.0
## Option labels that decline a choice: always the last button, below the accepting ones (G03).
const DECLINE_LABELS := ["Pass", "No", "Skip"]
## D13: tooltips of a Trap window's two declining answers.
const SKIP_TIP := "Let this one go. You are asked again at the next chance to respond."
const PASS_TURN_TIP := "Stop offering me Traps until this turn ends."
## Prompt kinds whose options are a vertical list (accept first, decline last) rather than a flow.
const LIST_KINDS := ["trap_response", "confirm", "order"]
## G09: gap between a card and the toast about it, the toast pointer's length, its fade-in (s), and
## how long after a command a refusal is still taken to be about that command's card (ms).
const TOAST_GAP := 10.0   # clears the ready badge over a board card
const TOAST_POINTER := 7.0
const TOAST_FADE := 0.12
const STATUS_ANCHOR_MS := 1500
## G03: caption under each card of the response strip, by role.
const ROLE_CAPTIONS := {"attacker": "Attacker", "target": "Target", "summoned": "Summoned",
	"activated": "Activated", "destroyed": "Destroyed", "direct": "Direct attack"}

## The host screen this component works on.
var gs: GameScreen
## Banner explaining the pending choice.
var ctx_banner: PanelContainer
## Banner headline.
var banner_title: Label
## Banner explanatory text.
var banner_sub: RichTextLabel
## Banner buttons (skip, confirm ...).
var banner_btns: HFlowContainer
## Banner flow of option buttons.
var banner_flow: HFlowContainer
## Grid of a Type choice's buttons (a direct child of the panel body, hidden otherwise). Its column
## count follows the panel width, so every row is even (review F03).
var type_grid: GridContainer
## F08: circles of an exact material cost (shown only for exact-total choices).
var cost_pips: CostPips
## F05: the card the choice is about (image, name and rules text), hidden when there is none.
var subject_box: PanelContainer
var _has_subject := false
## G04: the current choice pays an exact total (the cost circles replace the status line).
var _exact_pay := false
## True while the panel sits in the top strip (the side column cannot hold it): it is then a
## compact bar over the opponent's hand, without the card strip, so it never hides their zones.
var _in_top_strip := false
var subject_card: CardWidget
var subject_name: Label
var subject_text: Label
## G03: the cards a response prompt mentions: what it responds to (attacker -> target, or the card
## summoned / activated / destroyed) and each of my cards that may respond. Hidden otherwise.
var mention_box: PanelContainer
## Row of the cards responded to, and the column of my responding cards.
var mention_row: HBoxContainer
var respond_col: VBoxContainer
var _has_mentions := false
## Whether the strip was built for the top strip (one row) or the side column.
var _mentions_top := false
## G03: option buttons of a response, yes / no or ordering prompt, one per row, the declining
## option (Pass, No, Skip) always last, below the accepting ones.
var banner_list: VBoxContainer
## Tray offering pile cards for a choice (a HousePanel).
var tray: PanelContainer
## Container of the tray cards.
var tray_box: VBoxContainer
## Notice that the opponent is responding.
var wait_chip: PanelContainer
## Text of the wait notice.
var wait_label: Label
## Short toast message over the board.
var toast: Label
## uid -> card view shown only for the current choice (tray cards).
var tray_cards: Dictionary = {}
## Hash of the prompt last rendered (0 forces a re-render).
var prompt_sig: int = 0
## Last log seq checked for toast entries (-1: none yet; set on attach).
var seen_toast_seq: int = -1

var _banner_how: String = ""
## Who must act and that input is needed (the header strip title of the plate).
var banner_tag: Label
var _banner_pid: int = -2
var _wait_tween: Tween
var _toast_game: int = -99
## G09: the card of the last command sent and when (a refusal of it shows over that card).
var _sent_uid: int = -1
var _sent_ms: int = 0
## Full actor tag ("BEN · YOUR DECISION"); the narrow panel shows only "YOUR DECISION".
var _tag_full: String = ""
## Prompt + column for which the side column proved too short (the panel then uses the top strip).
var _side_overflow_key: int = 0
## Prompt + column for which the side column needed the compact layout (smaller headline, shorter
## option buttons, fewer rules lines) to fit; tried before giving the column up.
var _compact_key: int = 0


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the context banner and the pile tray (hidden).
func build() -> void:
	# F02-07 / F03-25 context banner: a tall, narrow card with a gold pulse. It sits in the free
	# column beside the board (or the top strip when there is none) so it never covers a target.
	var plate := PromptPlate.new()
	ctx_banner = plate
	ctx_banner.visible = false
	ctx_banner.z_index = UiLayers.BANNER
	gs.add_child(ctx_banner)
	var bcol := plate.body
	banner_tag = plate.title_label
	banner_title = plate.add_headline("", 21)
	StatusHelp.watch_label(banner_title)
	_build_subject(bcol)
	_build_mentions(bcol)
	banner_sub = RichTextLabel.new()
	banner_sub.bbcode_enabled = true
	banner_sub.fit_content = true
	banner_sub.custom_minimum_size = Vector2(40, 21)
	banner_sub.scroll_active = false
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.mouse_filter = Control.MOUSE_FILTER_PASS
	StatusHelp.watch_rich(banner_sub)
	banner_sub.add_theme_font_size_override("normal_font_size", 16)
	banner_sub.add_theme_font_size_override("bold_font_size", 17)
	banner_sub.add_theme_font_override("normal_font", UIStyle.font_body())
	banner_sub.add_theme_font_override("bold_font", UIStyle.font_bold())
	bcol.add_child(banner_sub)
	cost_pips = CostPips.new()
	cost_pips.visible = false
	bcol.add_child(cost_pips)
	banner_flow = HFlowContainer.new()
	banner_flow.add_theme_constant_override("h_separation", 6)
	banner_flow.add_theme_constant_override("v_separation", 6)
	bcol.add_child(banner_flow)
	type_grid = GridContainer.new()
	type_grid.add_theme_constant_override("h_separation", TYPE_GRID_SEP)
	type_grid.add_theme_constant_override("v_separation", 6)
	type_grid.visible = false
	bcol.add_child(type_grid)
	banner_list = VBoxContainer.new()
	banner_list.add_theme_constant_override("separation", 6)
	banner_list.visible = false
	bcol.add_child(banner_list)
	banner_btns = HFlowContainer.new()
	banner_btns.add_theme_constant_override("h_separation", 6)
	banner_btns.add_theme_constant_override("v_separation", 6)
	bcol.add_child(banner_btns)
	# F02-10 pile tray: cards offered only for this choice; click a card to choose it.
	tray = HousePanel.new("Choose a card", "", Vector2(TRAY_PAD, TRAY_PAD), 8)
	tray.visible = false
	tray.z_index = UiLayers.TRAY
	gs.add_child(tray)
	var tsc := ScrollContainer.new()
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(tray as HousePanel).body.add_child(tsc)
	tray_box = VBoxContainer.new()
	tray_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_box.add_theme_constant_override("separation", 8)
	tsc.add_child(tray_box)


## F05: the card-context strip of the input panel: the card on the left, its name and rules
## text beside it. Right-click the card to inspect it in full.
func _build_subject(col: VBoxContainer) -> void:
	subject_box = PanelContainer.new()
	var sb := UIStyle.flat(Color(0.045, 0.035, 0.025, 0.92), Color(UIStyle.BRONZE, 0.75), 1, 8)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	subject_box.add_theme_stylebox_override("panel", sb)
	subject_box.visible = false
	subject_box.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(subject_box)
	# A plain BoxContainer: _fit_subject flips it vertical in the narrow side column (an
	# HBoxContainer's orientation is fixed; setting it only logs an error).
	var h := BoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subject_box.add_child(h)
	subject_card = CardWidget.new().setup(null, "mini")
	GameUi.resize_card(subject_card, SUBJECT_CARD)
	subject_card.auto_hover = false
	subject_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	subject_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # centred when the strip stacks
	subject_card.tooltip_text = "Right-click to inspect"
	subject_card.right_pressed.connect(func(w): gs.inspect.inspect_widget(w))
	h.add_child(subject_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	subject_name = UIStyle.label("", 15, UIStyle.GOLD_HI, true, true)
	subject_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(subject_name)
	subject_text = UIStyle.label("", 13, UIStyle.TEXT, true)
	subject_text.max_lines_visible = SUBJECT_LINES
	subject_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subject_text.mouse_filter = Control.MOUSE_FILTER_PASS
	StatusHelp.watch_label(subject_text)
	v.add_child(subject_text)


## F05: the visible card my choice `pd` is about, or {}: the card a placement prompt names (a
## Fusion unit), else the choice's source. Only cards this seat may see are ever used: the source
## is given only when visible (MatchView._add_source) and the name is matched among my own visible
## cards; a Trap response names no card (which face-down card may respond stays hidden).
func subject_for(pd: Dictionary) -> Dictionary:
	if pd.is_empty() or not bool(pd.get("mine", false)) or String(pd.get("kind", "")) == "trap_response":
		return {}
	# G08: a zone choice is about the card it places (e.g. a unit summoned from Spent).
	var placing := gs.details.find_card(int(pd.get("placing_uid", -1)))
	if not placing.is_empty():
		return placing
	var src := gs.details.find_card(int(pd.get("source_uid", -1)))
	var sc: Variant = pd.get("source_card", {})
	if src.is_empty() and sc is Dictionary and (sc as Dictionary).has("uid") and not (sc as Dictionary).get("hidden", false):
		src = sc   # e.g. a resolving Spell, which no pile of the view lists
	var prompt := String(pd.get("prompt", ""))
	if not src.is_empty() and prompt.contains(String(src.get("name", "~"))):
		return src
	# The prompt names another card of mine (the Fusion unit being summoned with a Spell's
	# materials, zone and stance): show that one. Longest name wins ("Dragon" vs "Ultimate Dragon").
	# G03: also a unit or set card on either side of the Field the prompt names ("Move X to which
	# zone?"); hidden cards never match (they carry no name).
	var best := {}
	for p in 2:
		var pv := gs.pv(p)
		var zones := ["extra", "hand", "units", "backrow", "powers"] if p == gs.me() else ["units", "backrow", "powers"]
		for z in zones:
			for c in pv.get(z, []):
				if c == null or c.get("hidden", false):
					continue
				var nm := String(c.get("name", ""))
				if nm != "" and prompt.contains(nm) and nm.length() > String(best.get("name", "")).length():
					best = c
	return best if not best.is_empty() else src


func _render_subject(pd: Dictionary) -> void:
	var c := subject_for(pd)
	_has_subject = not c.is_empty()
	subject_box.visible = _has_subject and not _in_top_strip
	if c.is_empty():
		return
	subject_card.setup(c, "mini")
	GameUi.resize_card(subject_card, SUBJECT_CARD)
	subject_name.text = String(c.get("name", ""))
	var txt := String(c.get("text", "")).strip_edges()
	subject_text.text = txt if txt != "" else "No rules text."
	subject_text.tooltip_text = txt
	subject_box.tooltip_text = "%s\n%s" % [String(c.get("name", "")), txt]


## G03: the response strip, in the card strip's style: a row of the cards responded to over a
## column of my responding cards.
func _build_mentions(col: VBoxContainer) -> void:
	mention_box = PanelContainer.new()
	var sb := UIStyle.flat(Color(0.045, 0.035, 0.025, 0.92), Color(UIStyle.BRONZE, 0.75), 1, 8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	mention_box.add_theme_stylebox_override("panel", sb)
	mention_box.visible = false
	mention_box.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(mention_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mention_box.add_child(v)
	mention_row = HBoxContainer.new()
	mention_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mention_row.add_theme_constant_override("separation", 4)
	mention_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mention_row)
	respond_col = VBoxContainer.new()
	respond_col.add_theme_constant_override("separation", 6)
	respond_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(respond_col)


## G03: the cards a response prompt `pd` mentions, in reading order: [{"role", "card"}] of what it
## responds to (MatchView.event_cards, already redacted for this seat), then {"role": "response"}
## for each card of mine that may respond (an "Activate" option). [] for any other prompt.
static func mentions_for(pd: Dictionary) -> Array:
	if pd.is_empty() or not bool(pd.get("mine", false)) or String(pd.get("kind", "")) != "trap_response":
		return []
	var out: Array = []
	for e in pd.get("mentions", []):
		out.append(e)
	for o in pd.get("options", []):
		if o.has("card") and not is_decline(String(o.get("label", ""))):
			out.append({"role": "response", "card": o["card"], "label": String(o["label"])})
	return out


## True for an option that declines the choice (Skip, Skip (no Trap can respond), Pass for the rest
## of this turn, No).
static func is_decline(label: String) -> bool:
	return label in DECLINE_LABELS or label.begins_with("Pass ") or label.begins_with("Skip ")


func _render_mentions(pd: Dictionary) -> void:
	var ms := mentions_for(pd)
	_has_mentions = not ms.is_empty()
	_mentions_top = _in_top_strip
	mention_box.visible = _has_mentions
	GameUi.clear(mention_row)
	GameUi.clear(respond_col)
	if not _has_mentions:
		return
	var cause := ms.filter(func(e): return String(e.get("role", "")) != "response")
	var resp := ms.filter(func(e): return String(e.get("role", "")) == "response")
	for i in cause.size():
		var e: Dictionary = cause[i]
		if i > 0:
			var arrow := MentionArrow.new()
			arrow.attack = String(e.get("role", "")) in ["target", "direct"]
			arrow.custom_minimum_size = Vector2(MENTION_ARROW_W, 0)
			arrow.size_flags_vertical = Control.SIZE_FILL
			arrow.tooltip_text = "attacks" if arrow.attack else ""
			mention_row.add_child(arrow)
		mention_row.add_child(_mention_figure(e))
	if _in_top_strip:
		# The compact top-strip panel: one row, the responding cards after a divider.
		for e in resp:
			if mention_row.get_child_count() > 0:
				var div := ColorRect.new()
				div.color = Color(UIStyle.BRONZE, 0.55)
				div.custom_minimum_size = Vector2(1, 0)
				div.size_flags_vertical = Control.SIZE_FILL
				div.mouse_filter = Control.MOUSE_FILTER_IGNORE
				div.set_meta("divider", true)
				mention_row.add_child(div)
			mention_row.add_child(_mention_figure(e))
		resp = []
	mention_row.visible = mention_row.get_child_count() > 0
	if not resp.is_empty():
		if not cause.is_empty():
			var rule := ColorRect.new()
			rule.color = Color(UIStyle.BRONZE, 0.55)
			rule.custom_minimum_size = Vector2(0, 1)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			respond_col.add_child(rule)
		var cap := UIStyle.label("YOUR RESPONSE" if resp.size() == 1 else "YOUR RESPONSES", 10, UIStyle.MUTED)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		respond_col.add_child(cap)
		for e in resp:
			respond_col.add_child(_response_row(e))
	respond_col.visible = not resp.is_empty()


## A card of the response strip with its role and name beneath (a direct attack is a plain token
## for the defending player). Right-click a visible card to inspect it.
func _mention_figure(e: Dictionary) -> Control:
	var role := String(e.get("role", ""))
	var fig := VBoxContainer.new()
	fig.add_theme_constant_override("separation", 1)
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.set_meta("role", role)
	var c: Dictionary = e.get("card", {})
	var nm := ""
	if role == "direct":
		var tok := DirectToken.new()
		var p := int(e.get("p", gs.me()))
		tok.who = "YOU" if p == gs.me() else String(gs.pv(p).get("name", "")).to_upper()
		tok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tok.tooltip_text = "A direct attack on %s" % ("you" if p == gs.me() else String(gs.pv(p).get("name", "")))
		fig.add_child(tok)
		nm = "Direct attack"
	else:
		var w := CardWidget.new().setup(c, "mini")
		w.auto_hover = false
		w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		w.set_meta("mention", true)
		if role == "response":
			w.set_meta("response", true)
		w.right_pressed.connect(func(cw): gs.inspect.inspect_widget(cw))
		var hidden := bool(c.get("hidden", false)) or not c.has("name")
		nm = ("Set Spell/Trap" if String(c.get("zone", "")) == "backrow" else "Hidden card") if hidden else String(c.get("name", ""))
		w.tooltip_text = "%s: %s" % [ROLE_CAPTIONS.get(role, role.capitalize()), nm] + ("" if hidden else "\nRight-click to inspect")
		fig.add_child(w)
	var cap := "TARGET" if role == "direct" else String(ROLE_CAPTIONS.get(role, role.capitalize())).to_upper()
	var role_l := UIStyle.label(cap, 10, UIStyle.MUTED)
	role_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.add_child(role_l)
	# The name wraps onto a second line before it is cut (the full name is its tooltip).
	var name_l := UIStyle.label(nm, MENTION_NAME_PX, UIStyle.GOLD_HI, true, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD     # between words only ("Radablast" never splits)
	name_l.set_meta("name", true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.max_lines_visible = 2
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.tooltip_text = nm
	name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	fig.add_child(name_l)
	return fig


## A card of mine that may respond: the card, its name and the start of its rules text (like the
## card strip, F05).
func _response_row(e: Dictionary) -> Control:
	var c: Dictionary = e["card"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := CardWidget.new().setup(c, "mini")
	w.auto_hover = false
	w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	w.set_meta("mention", true)
	w.set_meta("response", true)
	w.tooltip_text = "Right-click to inspect"
	w.right_pressed.connect(func(cw): gs.inspect.inspect_widget(cw))
	row.add_child(w)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var nm := UIStyle.label(String(c.get("name", "")), 14, UIStyle.GOLD_HI, true, true)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD
	nm.set_meta("rname", true)
	v.add_child(nm)
	var txt := String(c.get("text", "")).strip_edges()
	var t := UIStyle.label(txt if txt != "" else "No rules text.", 12, UIStyle.TEXT, true)
	t.max_lines_visible = RESPONSE_LINES
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.tooltip_text = txt
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.set_meta("rules", true)
	v.add_child(t)
	return row


## G03: sizes the response strip for a panel `w` wide. The figures share the row (each card no
## larger than MENTION_CARD_MAX, the names wrapping in the figure's share); `compact` (a short side
## column) and the top strip use smaller cards, and the responding card's rules text then hides.
func _fit_mentions(w: float, compact: bool = false) -> void:
	if mention_box == null or not _has_mentions:
		return
	var content := w - (ctx_banner as HousePanel).chrome_size().x - 12.0
	var figs := mention_row.get_children().filter(func(n): return n.has_meta("role"))
	var arrows := mention_row.get_children().filter(func(n): return n is MentionArrow).size()
	var divs := mention_row.get_children().filter(func(n): return n.has_meta("divider")).size()
	var share := content
	if not figs.is_empty():
		share = floorf((content - arrows * (MENTION_ARROW_W + 4.0) - divs * 5.0) / figs.size()) - 4.0
	var top_c := MENTION_CARD_TOP.x if _in_top_strip else (MENTION_CARD_COMPACT if compact else MENTION_CARD_MAX)
	var cw := clampf(share - 8.0, MENTION_CARD_MIN, top_c)
	var sz := Vector2(cw, roundf(cw * 1.5))
	for a in mention_row.get_children():
		if a is MentionArrow:
			(a as MentionArrow).card_h = sz.y
			(a as Control).queue_redraw()
	for f in figs:
		var fw := maxf(sz.x + 8.0, share)
		(f as Control).custom_minimum_size.x = fw
		for n in (f as Node).get_children():
			if n is CardWidget:
				GameUi.resize_card(n, sz)
			elif n is DirectToken:
				(n as Control).custom_minimum_size = sz
			elif n is Label and n.has_meta("name"):
				_fit_name(n as Label, fw)
	var rsz := Vector2(MENTION_CARD_COMPACT, MENTION_CARD_COMPACT * 1.5) if compact else Vector2(48, 72)
	for row in respond_col.get_children():
		for n in (row as Node).get_children():
			if n is CardWidget:
				GameUi.resize_card(n, rsz)
			elif n is VBoxContainer:
				for l in (n as Node).get_children():
					if l.has_meta("rname"):
						_fit_name(l as Label, content - rsz.x - 8.0, RESPONSE_NAME_PX)
					if l.has_meta("rules"):
						(l as Label).visible = not compact


## A strip name in the largest size (MENTION_NAME_PX down to MENTION_NAME_MIN_PX) at which its
## longest word fits the figure width `w`, so a name wraps between words instead of being cut.
static func _fit_name(l: Label, w: float, start_px: int = MENTION_NAME_PX) -> void:
	var font := l.get_theme_font("font")
	var px := start_px
	var longest := 0.0
	while px > MENTION_NAME_MIN_PX:
		longest = 0.0
		for word in l.text.split(" ", false):
			longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		if longest <= w - 2.0:
			break
		px -= 1
	l.add_theme_font_size_override("font_size", px)


## The arrow from an attacker to its target in the response strip (hostile red, like the board's
## attack arrow); between other cards a plain bronze chevron.
class MentionArrow extends Control:
	var attack := true
	## Height of the cards beside it (the arrow sits on their middle, above the captions).
	var card_h := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var col := GameTargeting.HOSTILE_COLOR if attack else Color(UIStyle.BRONZE, 0.9)
		var y := card_h / 2.0 if card_h > 0.0 else size.y * 0.38
		var x0 := 2.0
		var x1 := size.x - 2.0
		draw_line(Vector2(x0, y), Vector2(x1 - 6.0, y), col, 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(x1, y), Vector2(x1 - 9.0, y - 6.0), Vector2(x1 - 9.0, y + 6.0)]), col)


## The defending player of a direct attack, in the strip in place of a target card.
class DirectToken extends Control:
	var who := "YOU"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := UIStyle.flat(Color(0.12, 0.05, 0.04, 0.95), GameTargeting.HOSTILE_COLOR, 2, 6)
		draw_style_box(sb, r)
		var f := UIStyle.font_display(600)
		var fs := 12 if size.x >= 44.0 else 10
		var tw := f.get_string_size(who, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var txt := who if tw <= size.x - 6.0 else "YOU"
		draw_string(f, Vector2(3.0, size.y / 2.0 + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6.0, fs, UIStyle.TEXT)


## Builds the opponent-is-deciding notice and the toast (hidden).
func build_notices() -> void:
	# Opponent-is-deciding notice in the middle of the board (user feedback: otherwise the game
	# looks stuck). Click-through.
	wait_chip = PanelContainer.new()
	var wsb := UIStyle.flat(Color(0.05, 0.04, 0.035, 0.9), Color(UIStyle.GOLD, 0.75), 2, 22)
	wsb.content_margin_left = 26
	wsb.content_margin_right = 26
	wsb.content_margin_top = 8
	wsb.content_margin_bottom = 8
	wsb.shadow_color = Color(0, 0, 0, 0.5)
	wsb.shadow_size = 8
	wait_chip.add_theme_stylebox_override("panel", wsb)
	wait_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait_chip.z_index = UiLayers.WAIT
	wait_chip.visible = false
	wait_label = UIStyle.label("", 22, UIStyle.GOLD_HI, false, true)
	wait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 10)
	wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait_chip.add_child(wrow)
	var rune := WaitPlate.Rune.new()
	rune.custom_minimum_size = Vector2(30, 30)
	rune.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(rune)
	wrow.add_child(wait_label)
	gs.add_child(wait_chip)
	var tl := ToastLabel.new()
	tl.follow = place_toast
	toast = tl
	toast.add_theme_color_override("font_color", UIStyle.BAD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 4)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := UIStyle.flat(Color(0.06, 0.05, 0.045, 0.94), Color(UIStyle.GOLD, 0.7), 1, 8)
	tsb.content_margin_left = 14
	tsb.content_margin_right = 14
	tsb.content_margin_top = 6
	tsb.content_margin_bottom = 6
	toast.add_theme_stylebox_override("normal", tsb)
	toast.add_theme_font_size_override("font_size", 17)
	toast.z_index = UiLayers.TOAST
	toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	toast.visible = false
	gs.add_child(toast)


## The choice banner and the pile tray follow the pending choice (rebuilt only when it changes).
func render() -> void:
	var view := gs.view
	var mv := gs.mv
	var pd := gs.pending()
	var sig := hash([view.get("stage", ""), view.get("net", {}), pd, mv.get("active", -1), mv.get("winner", -1), mv.get("resolving", false),
		gs.multi, view.get("deck_ready", []), view.get("you", 0)])
	if sig == prompt_sig:
		return
	# F04: a Fusion started from the Extra Deck list answers its "which Fusion unit" prompt
	# with the unit the player chose there; the banner then shows the next step instead.
	if gs.details.consume_fusion_intent():
		return
	prompt_sig = sig
	gs.targeting.hover_opt = -1
	_render_banner()
	_render_tray()


func _multi_status(pd: Dictionary) -> String:
	var ep := exact_payment(pd, gs.multi)
	if not ep.is_empty():
		return exact_status(ep)
	var total_txt := ""
	if pd.get("min_total", 0) > 0:
		var total := 0
		for i in gs.multi:
			# The option's `value` is the material's current (modified) cost, as the authority counts it.
			var o: Dictionary = pd["options"][i]
			total += maxi(int(o.get("value", o.get("card", {}).get("cost", 0))), 0)
		total_txt = "  ·  cost total %d / %s%d" % [total, "exactly " if pd.get("total_exact", false) else "", pd["min_total"]]
	var rng := "%d" % pd["min"] if pd["min"] == pd["max"] else "%d–%d" % [pd["min"], pd["max"]]
	return "Selected %d of %s%s" % [gs.multi.size(), rng, total_txt]


## F08: the exact-total payment of a material choice for picks `picks`:
## {"need", "paid", "remaining", "costs"} (costs: each pick's current cost, in pick order), or {}
## when the choice has no exact total. Values are the authority's current modified costs.
static func exact_payment(pd: Dictionary, picks: Array) -> Dictionary:
	if pd.is_empty() or not bool(pd.get("total_exact", false)) or not pd.has("total_required"):
		return {}
	var need := int(pd["total_required"])
	var costs := []
	for i in picks:
		costs.append(option_value(pd, int(i)))
	var paid := 0
	for v in costs:
		paid += int(v)
	return {"need": need, "paid": paid, "remaining": need - paid, "costs": costs}


## Current cost an option pays (its `value`, else its card's cost; never below 0).
static func option_value(pd: Dictionary, i: int) -> int:
	for o in pd.get("options", []):
		if int(o["i"]) == i:
			return maxi(int(o.get("value", o.get("card", {}).get("cost", 0))), 0)
	return 0


## F08: whether option `o` is offered at all in an exact-total choice: its cost must be above 0
## and no more than the whole total (other choices offer every option).
static func payable_option(pd: Dictionary, o: Dictionary) -> bool:
	var ep := exact_payment(pd, [])
	if ep.is_empty():
		return true
	var v := option_value(pd, int(o["i"]))
	return v > 0 and v <= int(ep["need"])


## F08: true when adding option `i` to `picks` would pay more than the exact total. A picked
## option never overpays (it can always be deselected).
static func would_overpay(pd: Dictionary, picks: Array, i: int) -> bool:
	if i in picks:
		return false
	var ep := exact_payment(pd, picks)
	if ep.is_empty():
		return false
	return option_value(pd, i) > int(ep["remaining"])


## Status line of an exact payment: what is still owed, or that it is paid exactly.
static func exact_status(ep: Dictionary) -> String:
	var need := int(ep["need"])
	var paid := int(ep["paid"])
	if paid == 0:
		return "Pay exactly %d: select materials whose costs fill the circles." % need
	if paid == need:
		return "Exact cost paid (%d of %d). Confirm to continue." % [paid, need]
	return "%d of %d paid · %d remaining." % [paid, need, need - paid]


## F02-07 context banner: what is being chosen, for which effect, how many and in what order,
## plus the non-card options (e.g. a direct attack), Confirm and Cancel. It covers only the top
## strip, never a target card.
func _render_banner() -> void:
	var pd := gs.pending()
	var on: bool = not pd.is_empty() and pd.get("mine", false) and not gs.overlays.overlay.visible and gs.view.get("stage", "") == "game"
	ctx_banner.visible = on
	_animate_banner(on, int(pd.get("id", -1)) if on else -1)
	GameUi.clear(banner_btns)
	GameUi.clear(banner_flow)
	banner_flow.visible = false
	GameUi.clear(banner_list)
	banner_list.visible = false
	GameUi.clear(type_grid)
	type_grid.visible = false
	_exact_pay = false
	if not on:
		return
	banner_title.text = String(pd["prompt"])
	_render_subject(pd)
	_render_mentions(pd)
	_tag_full = ("%s · your decision" % String(gs.pv(gs.me())["name"])).to_upper()
	banner_tag.text = _tag_full
	var pick := gs.selection.board_targeting()
	var how := ""
	if pick:
		var what := "zone" if pd["kind"] == "slot" else "card"
		if int(pd["max"]) > 1:
			how = _multi_status(pd)
		else:
			how = "Click a highlighted %s%s." % [what, " in the tray" if not gs.selection.tray_options(pd).is_empty() else ""]
		if pd["kind"] == "attack_target":
			how = "Hover a target to preview the battle, click to attack."
	elif pd["kind"] == "trap_response":
		# G03: with my responding cards shown under what they answer, the buttons say the rest.
		var responders := mentions_for(pd).filter(func(e): return String(e.get("role", "")) == "response")
		how = "" if not responders.is_empty() else ("Your opponent is waiting: activate a Trap or skip." if _has_activate(pd) else "Your opponent is waiting: skip to continue.")
	elif int(pd["max"]) > 1:
		how = _multi_status(pd)
	_banner_how = how
	var ep := exact_payment(pd, gs.multi)
	_exact_pay = not ep.is_empty()
	cost_pips.visible = _exact_pay
	if not ep.is_empty():
		cost_pips.set_payment(int(ep["need"]), ep["costs"])
		cost_pips.tooltip_text = exact_status(ep)
	update_banner_sub()
	# Card/zone options are picked on the board; every other option is a button here. G03: a
	# response, yes / no or ordering prompt lists its options one per row, and the declining option
	# (Pass, No, Skip) always comes last, below the accepting ones (Activate, Yes, Confirm).
	var row: Control = banner_btns if pick else banner_flow
	var type_choice := is_type_choice(pd)
	if type_choice and not pick:
		row = type_grid
	elif not pick and (String(pd["kind"]) in LIST_KINDS or _has_decline(pd)):
		row = banner_list
	var declines: Array[Button] = []
	for o in pd["options"]:
		if pick and (o.has("ref") or o.has("slot") or o.has("card")):
			continue
		var idx: int = o["i"]
		var chosen: bool = idx in gs.multi
		var label := ("✓ " if chosen else "") + String(o["label"])
		var decline := is_decline(String(o["label"]))
		var b: Button
		if type_choice:
			b = type_button(String(o["label"]), 15)
			b.set_meta("type_choice", String(o["label"]))
		elif pd["kind"] == "attack_target" or (not pick and not decline and (String(o["label"]).begins_with("Activate") or (pd["kind"] == "confirm" and String(o["label"]) == "Yes"))):
			b = UIStyle.primary_button(label, 14)
		elif String(o["label"]) == EffectEngine.TRAP_PASS_TURN:
			b = UIStyle.wine_button(label, 14)        # D13: the third, "stand down" answer
		else:
			b = UIStyle.button(label, 14)
		b.custom_minimum_size = Vector2(0, OPTION_H + (6 if type_choice else 0))
		b.set_meta("option", idx)
		b.pressed.connect(gs.selection.pick_option.bind(idx))
		b.mouse_entered.connect(func(): gs.targeting.hover_opt = idx)
		b.mouse_exited.connect(func(): if gs.targeting.hover_opt == idx: gs.targeting.hover_opt = -1)
		if row == banner_list:
			list_button(b, String(o["label"]))
		if pd["kind"] == "trap_response":
			if String(o["label"]) == EffectEngine.TRAP_PASS_TURN:
				b.tooltip_text = PASS_TURN_TIP
			elif String(o["label"]).begins_with(EffectEngine.TRAP_SKIP):
				b.tooltip_text = SKIP_TIP
		if decline:
			b.set_meta("decline", true)
			declines.append(b)
			continue
		row.add_child(b)
	if int(pd["max"]) > 1:
		var c := UIStyle.primary_button("Confirm", 14)
		c.custom_minimum_size = Vector2(0, OPTION_H)
		c.disabled = MatchView.multi_pick_error(pd, gs.multi) != ""   # count and exact Arcane total (F03-04)
		c.pressed.connect(gs.selection.confirm_multi)
		banner_btns.add_child(c)
	if pd["kind"] == "trap_response" and row == banner_list and declines.size() == 2:
		# D13: Skip and Pass for the rest of this turn share one row under the gold Activate, the
		# declining pair side by side (it also keeps the panel short enough for the full layout).
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		pair.set_meta("decline_pair", true)
		row.add_child(pair)
		declines[0].size_flags_stretch_ratio = 0.75
		declines[1].size_flags_stretch_ratio = 1.25
		declines[1].add_theme_font_size_override("font_size", 13)
		for b in declines:
			b.custom_minimum_size.y = OPTION_H + 10
			pair.add_child(b)
		declines.clear()
	for b in declines:
		row.add_child(b)
	if not pick and row.get_child_count() > 0:
		row.visible = true
	if type_choice:
		even_type_widths(row)
	if pd["cancellable"] and not gs.view.has("tutorial"):   # a forced tutorial step has no Cancel button
		var x := UIStyle.button("Cancel", 14)
		x.custom_minimum_size = Vector2(0, OPTION_H)
		x.pressed.connect(gs.selection.cancel)
		banner_btns.add_child(x)
	place_banner()


## True when one of the prompt's options activates a card ("Activate ...").
static func _has_activate(pd: Dictionary) -> bool:
	for o in pd.get("options", []):
		if String(o.get("label", "")).begins_with("Activate"):
			return true
	return false


## True when one of the prompt's options declines it (Pass, No, Skip).
static func _has_decline(pd: Dictionary) -> bool:
	for o in pd.get("options", []):
		if is_decline(String(o.get("label", ""))):
			return true
	return false


## A full-width row button of the option list (G03): its label wraps instead of widening the panel,
## and the full label is its tooltip.
static func list_button(b: Button, full: String) -> void:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.tooltip_text = full


## Where the banner goes (F03-25). Preferred: the free column left of the board below the
## opponent's hand (tall and narrow, clear of every zone, pile and plate). If that column is too
## narrow (small window) it falls back to the top strip, centred between the seat label and the
## opponent's plate.
func place_banner() -> void:
	if ctx_banner == null:
		return
	var area := gs.play_area
	var board := gs.board
	var col_left := 14.0
	var col_right := area.end.x
	var top := area.position.y + 6.0
	var have_zones := not board.slots.is_empty()
	if have_zones:
		# Left edge of the leftmost zone or pile.
		var edge := area.end.x
		for k in board.slots:
			edge = minf(edge, (board.slots[k]["zone_node"] as Control).position.x)
		for side in 2:
			for z in board.piles[side]:
				edge = minf(edge, (board.piles[side][z] as Control).position.x)
		col_right = edge - BANNER_GAP
		top = board.opp_hand_box.position.y + CardWidget.SIZES["back"].y + BANNER_GAP
	var side_w := minf(BANNER_SIDE_MAX_W, col_right - col_left)
	# The column ends above my own plate (bottom left), which the panel must never cover.
	var bottom := (board.plates[1] as Control).position.y - BANNER_GAP if board.plates.size() > 1 else area.end.y
	var key := hash([prompt_sig, banner_title.text, side_w, bottom - top])
	if have_zones and side_w >= BANNER_SIDE_MIN_W and key != _side_overflow_key:
		_set_top_strip(false)
		ctx_banner.position = Vector2(col_left, top)
		_size_banner(side_w, key == _compact_key)
		_check_side_fit(key, bottom)
		_after_banner_settles()
		return
	var left := area.position.x + 230.0
	var plates := board.plates
	var right := (plates[0] as Control).position.x - 10.0 if not plates.is_empty() else area.end.x - 230.0
	var bw := clampf(right - left, BANNER_MIN_W, BANNER_MAX_W)
	_set_top_strip(true)
	_size_banner(bw, true)
	ctx_banner.position = Vector2(maxf(area.position.x + 8.0, (left + right) / 2.0 - bw / 2.0), 10.0)
	_after_banner_settles()


func _set_top_strip(on: bool) -> void:
	_in_top_strip = on
	if subject_box != null:
		subject_box.visible = _has_subject and not on
	# G03: the response strip is laid out differently there (one row); rebuild it on a change.
	if mention_box != null and _has_mentions and _mentions_top != on:
		_render_mentions(gs.pending())


## Once the panel has settled (HousePanel.fit takes a few frames), a side-column panel taller than
## the column (a long choice in a small window) is first laid out compact, and only if that still
## overruns does it move to the top strip for this prompt.
func _check_side_fit(key: int, bottom: float) -> void:
	if not is_instance_valid(gs) or not gs.is_inside_tree():
		return
	var tree := gs.get_tree()
	for i in 6:
		await tree.process_frame
	if not is_instance_valid(gs) or not ctx_banner.visible or key == _side_overflow_key:
		return
	if ctx_banner.position.y + ctx_banner.size.y > bottom + 0.5:
		if _compact_key != key:
			_compact_key = key
		else:
			_side_overflow_key = key
		place_banner()


## Re-places the tray once the banner has measured itself (HousePanel.fit settles over frames).
func _after_banner_settles() -> void:
	if tray == null or not tray.visible or not is_instance_valid(gs) or not gs.is_inside_tree():
		return
	var tree := gs.get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(gs) and gs.is_inside_tree() and is_instance_valid(tray) and tray.visible:
		place_tray()


func _size_banner(w: float, compact: bool = false) -> void:
	_fit_subject(w, compact)
	# F04-13: the plate measures itself in passes after layout (see HousePanel.fit), so wrapped
	# labels that were laid out at a stale width cannot leave it too tall.
	(ctx_banner as HousePanel).fit(w)


## The card strip (F05) adapts to the panel width: side by side when there is room, otherwise the
## card sits above a shorter text so the panel does not grow over the board.
## `compact`: the side column is short for this choice; headline, option buttons and rules text shrink.
func _fit_subject(w: float, compact: bool = false) -> void:
	if subject_box == null or subject_text == null:
		return
	_fit_mentions(w, compact)
	var narrow := w < BANNER_NARROW_W or ctx_banner.position.y < 20.0 or compact
	subject_text.max_lines_visible = SUBJECT_LINES_NARROW if narrow else SUBJECT_LINES
	_fit_type_buttons(w - (ctx_banner as HousePanel).chrome_size().x, compact)
	var row := subject_card.get_parent()
	# A short column (compact): a smaller card beside two lines of text, so the panel can stay in
	# the side column instead of falling back to the top strip over the opponent's zones.
	GameUi.resize_card(subject_card, SUBJECT_CARD_COMPACT if compact else SUBJECT_CARD)
	if compact:
		subject_text.max_lines_visible = SUBJECT_LINES_COMPACT
	if row is BoxContainer:
		(row as BoxContainer).vertical = w < BANNER_NARROW_W and not compact
	# The narrow column: a smaller headline and the tag without the player's name, so neither
	# wraps word by word nor clips (UI review, 1600x900).
	var thin := w < BANNER_NARROW_W
	var px := HEADLINE_NARROW_PX if thin or compact else HEADLINE_PX
	if _exact_pay:
		px = HEADLINE_PAY_NARROW_PX if thin or compact else HEADLINE_PAY_PX
	banner_title.add_theme_font_size_override("font_size", px)
	if _tag_full != "":
		banner_tag.text = "YOUR DECISION" if thin else _tag_full
		banner_tag.tooltip_text = _tag_full


## Attention treatment (F03-25): a pop and gold flare when a new choice appears, then a gentle
## breathing border and glow (HousePanel.attend). Static with UIStyle.reduce_motion.
func _animate_banner(on: bool, pid: int) -> void:
	var plate := ctx_banner as HousePanel
	if not on:
		plate.calm()
		_banner_pid = -2
		return
	var fresh := pid != _banner_pid
	_banner_pid = pid
	plate.attend(fresh)


## True when every option of a choice is a Type name (Waang, Chaos Witch, ...): those render as
## Type-coloured buttons with the Type icon (F03-27). Only the offered options are shown.
static func is_type_choice(pd: Dictionary) -> bool:
	if pd.is_empty() or String(pd.get("kind", "")) != "mode":
		return false
	var opts: Array = pd.get("options", [])
	if opts.is_empty():
		return false
	for o in opts:
		var l := String(o.get("label", ""))
		if l == "No type":
			continue
		if l == "" or not UIStyle.TYPE_COLORS.has(l):
			return false
	return true


## Readable text colour (white or near-black, whichever contrasts more) on a fill.
static func type_text_color(fill: Color) -> Color:
	var dark := Color(0.06, 0.05, 0.05)
	return dark if _contrast(fill, dark) >= _contrast(fill, Color.WHITE) else Color.WHITE


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## WCAG contrast ratio of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Fill of a Type button: the Type colour at `v` of its brightness and 80% of its saturation.
static func type_fill(col: Color, v: float) -> Color:
	return Color.from_hsv(col.h, col.s * 0.8, col.v * v)


## A Type declaration button: a deep tint of the Type's colour with a rim in the full colour
## (hover brighter with a glow, pressed darker), the Type icon on the left and the Type name as
## text, so the Type is never told by colour alone. Owner feedback 2026-10-18: the full-colour
## fills were too bright; the fill is now the Type's hue, softened and darkened.
static func type_button(type_name: String, size: int = 15) -> Button:
	var ty := "" if type_name == "No type" else type_name
	var col := UIStyle.type_color(ty)
	var b := UIStyle.button(type_name, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var fills := {"normal": type_fill(col, 0.5), "hover": type_fill(col, 0.66), "pressed": type_fill(col, 0.4)}
	for k in fills:
		var fill: Color = fills[k]
		var sb := UIStyle.flat(fill, col.lightened(0.1) if k != "pressed" else col.darkened(0.1), 2, 8)
		sb.content_margin_left = 42
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if k == "hover":
			UIStyle.lift_style(sb, Color(fill, 0.55), 9, 0)
		b.add_theme_stylebox_override(k, sb)
		b.add_theme_color_override("font_color" if k == "normal" else "font_%s_color" % k, type_text_color(fill))
	b.add_theme_color_override("font_focus_color", type_text_color(col))
	# F03: a fixed square icon box, centred on the button's vertical middle. The bottom anchor is
	# set before the top one: setting the top anchor (0.5) above a bottom anchor still at 0 made
	# Godot clamp it back to 0, which stretched the box from the button's top and drew every icon
	# high (Waang's Type choice). The box scales with the label size, not with the button height.
	var px := icon_box(size)
	var badge := TypeIcons.TypeBadge.new(ty, px)
	badge.pip = true          # review F03: the same filled disc for every Type, readable on its own fill
	badge.anchor_bottom = 0.5
	badge.anchor_top = 0.5
	badge.anchor_left = 0.0
	badge.anchor_right = 0.0
	badge.offset_top = -px / 2.0
	badge.offset_bottom = px / 2.0
	badge.offset_left = TYPE_ICON_X
	badge.offset_right = TYPE_ICON_X + px
	badge.set_meta("type_icon", true)
	b.add_child(badge)
	return b


## Review F03: every Type button in `row` as wide as the widest, so the rows read as an even grid.
static func even_type_widths(row: Control) -> void:
	var w := 0.0
	for b in row.get_children():
		if b is Button and b.has_meta("type_choice"):
			(b as Button).custom_minimum_size.x = 0.0
			w = maxf(w, (b as Button).get_combined_minimum_size().x)
	for b in row.get_children():
		if b is Button and b.has_meta("type_choice"):
			(b as Button).custom_minimum_size.x = w


## Restyles a Type button between its regular look and the compact one (smaller label, tighter
## margins, shorter) used when the side column is short; the icon box keeps its size and place.
static func compact_type_button(b: Button, compact: bool) -> void:
	b.add_theme_font_size_override("font_size", TYPE_COMPACT_PX if compact else TYPE_PX)
	for k in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(k) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = TYPE_COMPACT_LEFT if compact else 42
			sb.content_margin_right = 8 if compact else 14
			sb.content_margin_top = 4 if compact else 6
			sb.content_margin_bottom = 4 if compact else 6
	b.custom_minimum_size.y = OPTION_H + (0 if compact else 6)


## Type buttons for a body `content_w` wide: regular or compact style, all one width, and as many
## grid columns as fit (at most TYPE_GRID_MAX_COLS); the columns share the row width evenly.
func _fit_type_buttons(content_w: float, compact: bool) -> void:
	if type_grid == null or not type_grid.visible:
		return
	var btns := type_grid.get_children().filter(func(b): return b is Button and b.has_meta("type_choice"))
	if btns.is_empty():
		return
	type_grid.add_theme_constant_override("v_separation", 4 if compact else 6)
	for b in btns:
		compact_type_button(b, compact)
	even_type_widths(type_grid)
	var bw: float = (btns[0] as Button).custom_minimum_size.x
	var cols := clampi(int(floor((content_w + TYPE_GRID_SEP) / (bw + TYPE_GRID_SEP))), 1, mini(TYPE_GRID_MAX_COLS, btns.size()))
	type_grid.columns = cols
	var cell := floorf((content_w - TYPE_GRID_SEP * (cols - 1)) / cols)
	for b in btns:
		(b as Button).custom_minimum_size.x = maxf(bw, cell)


## Side of the Type icon box of a Type button whose label is `font_px` (fits the left margin).
static func icon_box(font_px: int) -> float:
	return clampf(roundf(font_px * 1.6), 18.0, TYPE_ICON_MAX)


## Banner sub-line: how to answer the choice, or the hovered battle target coloured by the
## expected outcome (the full breakdown is the tooltip).
func update_banner_sub() -> void:
	if banner_sub == null:
		return
	var pv := gs.preview
	var t := "[color=#c2b8a2]%s[/color]" % _banner_how.replace("[", "(")
	if pv.text != "":
		# Only the target, coloured by the expected outcome (green / red / purple); the full
		# breakdown stays in the tooltip.
		var col: Color = GameScreen.VERDICT_COLORS.get(pv.verdict, UIStyle.TEXT)
		t = "[b][color=#%s]%s[/color][/b]" % [col.to_html(false), pv.target.replace("[", "(")]
	# G04: an exact payment reads from its headline and circles alone; the status stays the circles'
	# tooltip. A battle preview (never during a payment) would still show. A prompt with nothing to
	# say here (yes / no, a mode) leaves no empty line either.
	var shown := pv.text != "" or not (_exact_pay or _banner_how == "")
	if banner_sub.visible != shown:
		banner_sub.visible = shown
		if ctx_banner != null and ctx_banner.visible:
			place_banner()
	t = StatusHelp.linkify(t)
	if banner_sub.text != t:
		banner_sub.text = t
		banner_sub.tooltip_text = pv.text if pv.text != "" else _banner_how
		if ctx_banner != null and ctx_banner.visible:
			place_banner()


## Columns of the pile tray: as many as fit the play area (max 8), never more than the cards.
func _tray_cols(n: int) -> int:
	var cw: float = CardWidget.SIZES["mini"].x
	var fit := int(floor((gs.play_area.size.x - 80.0 - 2.0 * TRAY_PAD + TRAY_GAP) / (cw + TRAY_GAP)))
	return clampi(mini(n, fit), 1, TRAY_MAX_COLS)


## The tray hugs its cards (same padding on every side) and sits in the middle of the play area.
func place_tray() -> void:
	if tray == null:
		return
	var area := gs.play_area
	var n := maxi(1, tray_cards.size())
	var cols := _tray_cols(n)
	var cw: float = CardWidget.SIZES["mini"].x
	var grid_w := cols * cw + (cols - 1) * TRAY_GAP
	var chrome := (tray as HousePanel).chrome_size()
	var w := maxf(grid_w, TRAY_MIN_W) + chrome.x
	var need := tray_box.get_combined_minimum_size()
	var h := minf(need.y + chrome.y, area.size.y - 40.0)
	if need.y + chrome.y > area.size.y - 40.0:
		w += 12.0   # room for the scroll bar
	tray.size = Vector2(w, h)
	tray.position = (area.position + (area.size - tray.size) / 2.0).round()
	# The input panel (taller with its card context, F05) must never cover the offered cards: when
	# it sits over the tray (the top-strip fallback), the tray moves down below it.
	if ctx_banner != null and ctx_banner.visible:
		var br := Rect2(ctx_banner.position, ctx_banner.size)
		if br.intersects(Rect2(tray.position, tray.size)):
			tray.position.y = roundf(br.end.y + BANNER_GAP)
			tray.size.y = maxf(chrome.y + 60.0, minf(tray.size.y, area.end.y - tray.position.y - 8.0))


## F02-10 tray of the cards offered from a pile (Spent, Draw, Extra, an opponent's pile when
## the effect allows it). Click a card to choose it; multi-choices keep their order and use
## the banner's Confirm. Hover shows the card's details; the tray never offers other cards.
func _render_tray() -> void:
	var pd := gs.pending()
	var opts: Array = gs.selection.tray_options(pd) if gs.selection.board_targeting() else []
	tray_cards.clear()
	GameUi.clear(tray_box)
	var was_open := tray.visible
	tray.visible = not opts.is_empty() and not gs.overlays.overlay.visible
	if not tray.visible:
		return
	var house := tray as HousePanel
	house.set_title("Choose %s" % ("a card" if int(pd["max"]) <= 1 else "cards"))
	house.set_tag("%d offered" % opts.size())
	if not was_open:
		house.appear()   # pops in when it opens, not on every pick of a multi-choice
	var lead := Control.new()   # room above the cards for their order badges (the scroll clips)
	lead.custom_minimum_size = Vector2(0, 6)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_box.add_child(lead)
	var flow := GridContainer.new()
	flow.columns = _tray_cols(opts.size())
	flow.add_theme_constant_override("h_separation", int(TRAY_GAP))
	flow.add_theme_constant_override("v_separation", int(TRAY_GAP))
	flow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tray_box.add_child(flow)
	for o in opts:
		var cv: Dictionary = o["card"]
		var uid: int = int(cv.get("uid", -1))
		tray_cards[uid] = cv
		var idx: int = o["i"]
		var w := CardWidget.new().setup(cv, "mini")
		# F08: a material that would pay more than what remains is visibly unavailable.
		var over := would_overpay(pd, gs.multi, idx)
		w.set_marks(not over, idx in gs.multi, over)
		if over:
			w.tooltip_text = "Cannot overpay"
			w.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		w.set_meta("overpay", over)
		w.order_no = gs.selection.order_no(idx)
		w.pressed.connect(func(_w): gs.selection.pick_option(idx))
		w.right_pressed.connect(gs.inspect.inspect_widget)
		w.mouse_entered.connect(func():
			gs.peek_uid = uid
			gs.details.render())
		w.mouse_exited.connect(func():
			if gs.peek_uid == uid:
				gs.peek_uid = -1
				gs.details.render())
		flow.add_child(w)
	place_tray()
	_fit_tray.call_deferred()


func _fit_tray() -> void:
	await gs.get_tree().process_frame
	place_tray()


## Shows (text != "") or hides the centre-of-board wait notice; it breathes gently while shown.
func show_wait(text: String) -> void:
	if text == "":
		if wait_chip.visible:
			wait_chip.visible = false
			if _wait_tween != null and _wait_tween.is_valid():
				_wait_tween.kill()
		return
	wait_label.text = text
	wait_chip.reset_size()
	var sz := wait_chip.get_combined_minimum_size()
	wait_chip.size = sz
	var area := gs.play_area
	wait_chip.position = Vector2(area.position.x + (area.size.x - sz.x) / 2.0, gs.board.deco.mid_y - sz.y / 2.0)
	if wait_chip.visible:
		return
	wait_chip.visible = true
	wait_chip.modulate.a = 1.0
	if not UIStyle.reduce_motion:
		_wait_tween = gs.create_tween().set_loops()
		_wait_tween.tween_property(wait_chip, "modulate:a", 0.65, 0.9).set_trans(Tween.TRANS_SINE)
		_wait_tween.tween_property(wait_chip, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)



## Short non-blocking message over the board; it never waits for input. G09: with an `anchor`
## ({"uid": card uid, "at": {p, zone, slot}}) about a card, it appears just above that card on the
## board, in the Hand or in the pile tray (below it when there is no room above), kept on screen,
## and follows the card while shown; it falls back to the top of the board when the card cannot be
## found (no longer visible).
func show_toast(text: String, col: Color, secs: float, anchor: Dictionary = {}) -> void:
	toast.text = text
	toast.visible = text != ""
	toast.size = Vector2.ZERO
	toast.add_theme_color_override("font_color", col)
	(toast as ToastLabel).anchor = anchor
	place_toast()
	if toast.visible and not UIStyle.reduce_motion:
		toast.modulate.a = 0.0
		gs.create_tween().tween_property(toast, "modulate:a", 1.0, UIStyle.dur(TOAST_FADE))
	else:
		toast.modulate.a = 1.0
	var t := gs.get_tree().create_timer(secs)
	t.timeout.connect(func():
		# The screen (and its toast) may be gone by now: a SceneTree timer outlives it.
		if is_instance_valid(toast) and toast.text == text:
			toast.text = ""
			toast.visible = false
			(toast as ToastLabel).anchor = {})


## Places the toast over its card (G09) or, without one, centred at the top of the board.
func place_toast() -> void:
	if toast == null or not toast.visible:
		return
	var tl := toast as ToastLabel
	var area := gs.play_area
	var sz := toast.get_combined_minimum_size()
	toast.size = sz
	var r := toast_anchor_rect(tl.anchor)
	if r.size == Vector2.ZERO:
		tl.pointer = 0
		toast.position = Vector2(area.position.x + (area.size.x - minf(area.size.x - 120.0, sz.x)) / 2.0, GameScreen.TOP_H + 8.0).round()
		return
	var inv := gs.get_global_transform().affine_inverse()
	var lr := Rect2(inv * r.position, inv * r.end - inv * r.position)
	var view := gs.get_rect().size
	var gap := TOAST_GAP + TOAST_POINTER
	var y := lr.position.y - gap - sz.y
	tl.pointer = 1                               # pointing down at the card under it
	if y < GameScreen.TOP_H + 4.0:
		y = lr.end.y + gap                       # no room above (the opponent's top row): below it
		tl.pointer = -1
	y = clampf(y, 4.0, view.y - sz.y - 4.0)
	var x := clampf(lr.get_center().x - sz.x / 2.0, 8.0, maxf(8.0, view.x - sz.x - 8.0))
	toast.position = Vector2(x, y).round()
	tl.pointer_x = clampf(lr.get_center().x - toast.position.x, 12.0, sz.x - 12.0)
	toast.queue_redraw()


## Global rect of the card a toast anchor names, or Rect2() when it is not visible: the card by uid
## (board, Hand, pile tray), else the board zone it was in.
func toast_anchor_rect(anchor: Dictionary) -> Rect2:
	if anchor.is_empty():
		return Rect2()
	var uid := int(anchor.get("uid", -1))
	if uid != -1:
		var slots := gs.board.slots
		for k in slots:
			var w: CardWidget = slots[k]["widget"]
			if w.visible and not w.view.get("hidden", false) and int(w.view.get("uid", -9)) == uid:
				return (slots[k]["holder"] as Control).get_global_rect()
		var items := gs.hand.items
		if items.has(uid) and (items[uid]["holder"] as Control).is_visible_in_tree():
			return (items[uid]["holder"] as Control).get_global_rect()
		if tray != null and tray.visible:
			for w in _tray_widgets():
				if int(w.view.get("uid", -9)) == uid:
					return w.get_global_rect()
	var at: Dictionary = anchor.get("at", {})
	if not at.is_empty():
		var it: Dictionary = gs.fx_slot_item(int(at["p"]), String(at["zone"]), int(at["slot"]))
		if not it.is_empty():
			var w2: CardWidget = it["widget"]
			# Only while a card is still in that zone (the uid lookup above failed: it may be hidden).
			if w2.visible and (uid == -1 or int(w2.view.get("uid", uid)) == uid):
				return (it["holder"] as Control).get_global_rect()
	return Rect2()


func _tray_widgets() -> Array:
	var out := []
	var stack: Array = [tray_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is CardWidget:
				out.append(c)
			else:
				stack.append(c)
	return out


## Hides the toast at once (a command was sent). G09: remembers the card the command is about,
## so a refusal of it (on_status) appears over that card.
func hide_toast() -> void:
	toast.text = ""
	toast.visible = false
	(toast as ToastLabel).anchor = {}
	_sent_uid = gs.acting_uid
	_sent_ms = Time.get_ticks_msec()


## A rejected command / status message from the seat client. A refusal that answers a card's
## command just sent shows over that card (G09); connection messages stay at the top.
func on_status(text: String) -> void:
	if text != "":
		Sfx.play("deny")
	var anchor := {}
	if _sent_uid != -1 and Time.get_ticks_msec() - _sent_ms <= STATUS_ANCHOR_MS and not _is_connection_text(text):
		anchor = {"uid": _sent_uid}
	show_toast(text, UIStyle.BAD, 4.0, anchor)


## True for a session / connection message (never about a card).
static func _is_connection_text(text: String) -> bool:
	var t := text.to_lower()
	for w in ["connect", "host", "lobby", "steam", "reconnect"]:
		if t.contains(w):
			return true
	return false


## F02-09: log entries flagged as toasts (e.g. a triggered effect with no legal target)
## also show briefly over the board. Only new entries of the current game; never on attach.
## G09: over the card the entry is about when every shown entry is about the same card.
func show_log_toasts() -> void:
	var mv := gs.mv
	if mv.is_empty():
		return
	var game_no: int = gs.view.get("game_no", 0)
	var entries: Array = mv.get("log", [])
	var maxseq := -1
	for e in entries:
		maxseq = maxi(maxseq, int(e["seq"]))
	if game_no != _toast_game or seen_toast_seq < 0:
		_toast_game = game_no
		seen_toast_seq = maxseq
		return
	var shown := []
	for e in entries:
		if int(e["seq"]) > seen_toast_seq and e.get("toast", false) and String(e["text"]) != "":
			shown.append(e)
	seen_toast_seq = maxi(seen_toast_seq, maxseq)
	if shown.is_empty():
		return
	shown = shown.slice(maxi(0, shown.size() - 2))
	var anchor := log_toast_anchor(shown)
	Sfx.play("notice")
	show_toast("  ·  ".join(shown.map(func(e): return String(e["text"]))), UIStyle.GOLD_HI, 4.5, anchor)


## The card shared by toast log rows `rows` ({"uid", "at"}), or {} when they name different cards
## or none.
static func log_toast_anchor(rows: Array) -> Dictionary:
	var anchor := {}
	for e in rows:
		var a := {}
		if e.has("toast_uid"):
			a["uid"] = int(e["toast_uid"])
		if not (e.get("toast_at", {}) as Dictionary).is_empty():
			a["at"] = e["toast_at"]
		if a.is_empty():
			return {}
		if not anchor.is_empty() and (int(anchor.get("uid", -1)) != int(a.get("uid", -1)) or str(anchor.get("at", {})) != str(a.get("at", {}))):
			return {}
		anchor = a
	return anchor


## The toast label (G09): follows its card every frame while shown and draws a small pointer
## toward it.
class ToastLabel extends Label:
	## {"uid", "at"} of the card the toast is about, or {}.
	var anchor: Dictionary = {}
	## 1: pointing down (the toast is above its card), -1: pointing up, 0: no pointer.
	var pointer: int = 0
	## Pointer position along the toast (local x).
	var pointer_x: float = 0.0
	## Re-places the toast (the banner's place_toast).
	var follow: Callable

	func _process(_d: float) -> void:
		if visible and not anchor.is_empty() and follow.is_valid():
			follow.call()

	func _draw() -> void:
		if pointer == 0:
			return
		var h := GamePromptBanner.TOAST_POINTER
		var y := size.y if pointer == 1 else 0.0
		var tip := Vector2(pointer_x, y + h * pointer)
		var fill := Color(0.06, 0.05, 0.045, 0.94)
		var base := y - 1.5 * pointer             # over the plate's border, so the pointer joins it
		var pts := PackedVector2Array([Vector2(pointer_x - 7.0, base), Vector2(pointer_x + 7.0, base), tip])
		draw_colored_polygon(pts, fill)
		draw_polyline(PackedVector2Array([pts[0], tip, pts[1]]), Color(UIStyle.GOLD, 0.7), 1.0, true)
