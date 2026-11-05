class_name GameBoardView
extends RefCounted
## The play field: table art, both players' zones (units, Trap/Spell, Power), pile stacks,
## player plates and the opponent's face-down hand. Renders the match view into them and
## answers where things are on screen (FxPlayer host contract).

## Zone geometry (screen units): unit square side, gap between slots, Power slot width,
## Trap/Spell slot height, gap between the pile stacks and the zones.
const UNIT_SIZE := 128.0
const SLOT_GAP := 8.0
const POWER_W := 85.0
const TRAP_H := 85.0
const PILE_GAP := 24.0
const BOARD_H := 730.0
const PLATE_W := PlayerPlate.PLATE_W
const OPP_HAND_MAX := 10
## Top of the opponent's face-down fan (#16: on the HUD safe margin, with no caption above it).
const OPP_HAND_Y := 24.0
## Slots per zone, in render order.
const ZONE_SLOTS := {"unit": 6, "backrow": 3, "power": 4}
## Action kinds that mark a card as able to act now (F02-11).
const READY_KINDS := ["summon", "cast", "set", "power", "ritual", "arcane", "ability", "attack", "activate_set"]
## Pile stacks beside the unit zones: [zone, title] (Draw, Extra, Spent, Exhaust).
const PILE_ZONES := [["draw", "Draw"], ["extra", "Extra"], ["spent", "Spent"], ["exhaust", "Exhaust"]]

## The host screen this component works on.
var gs: GameScreen
## Table background root.
var table: Control
## Decorative lines and glow between the two sides.
var deco: BoardDeco
## Table dust motes and their light cone (#23), as fractions of the play field.
var dust: AmbientMotes
const DUST_COUNT := AmbientMotes.DUST_COUNT
const DUST_SHAFT := Rect2(0.3, 0.0, 0.4, 1.0)
## Layer the cards of this view live on.
var layer: Control
## [top plate, bottom plate]
var plates: Array = []
## [side][zone] -> PileStack
var piles: Array = [{}, {}]
## "side:zone:slot" -> {zone_node, bg, holder, widget, hash, pidx, label, zone, rot, ring}
var slots: Dictionary = {}
## Row of face-down cards for the opponent hand.
var opp_hand_box: Control
## Opponent hand size label (inside opp_hand_chip).
var opp_hand_count_label: Label
## The count chip beside the opponent's fan (#16).
var opp_hand_chip: PanelContainer
## Number of opponent hand cards currently shown (-1 until first render).
var opp_hand_n: int = -1
## uid -> true for my cards that can act now (F02-11).
var ready_uids: Dictionary = {}
## Card my current pick belongs to (kept lit while everything else dims), or -1.
var src_uid: int = -1
## J6 / J11 (owner feedback 2026-10-22): the local player's duel controls under their plate
## (Sacrifice Unit, Trap Prompts toggle).
var controls: DuelControls
## J6: the Trap prompts setting last sent for this seat and game ("" none), so it is sent once.
var _prompts_sent := ""
## A2: face-down hand of the bottom player on a spectator's screen (and its caption).
var own_backs_box: Control
var own_backs_label: Label
var _own_backs_key := ""
## D9: field zones ({p, zone, slot}) previewed as the valid targets of the effect button under the
## pointer; empty when no preview is showing.
var preview_refs: Array = []
## Uid of the card whose effect button is hovered (it is not darkened by the preview).
var preview_src: int = -1
var _y0: float = 0.0
var _ux: float = 0.0


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the table background (the sidebar column shows the gradient, the field the art).
func build_table() -> void:
	# Brown candle-lit gradient behind everything (the sidebar column shows it) ...
	var base := ColorRect.new()
	base.color = UIStyle.TABLE_WOOD
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/table.gdshader")
	base.material = mat
	gs.add_child(base)
	# ... and the table art covering only the play field (sized in layout), with a light veil
	# so zones and cards stay readable over it. L28: the player's chosen table (Options).
	table = UIStyle.table_background()
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.clip_contents = true
	gs.add_child(table)
	# #23: the table is never perfectly still: a few warm dust motes drift in a soft centre light
	# cone (resting, faint, under reduce motion). Under the zones and cards; click-through.
	dust = AmbientMotes.dust(DUST_COUNT)
	dust.shaft = DUST_SHAFT
	dust.shaft_color = AmbientMotes.DUST_COLOR
	table.add_child(dust)


## Builds the decoration, every zone slot, the plates, piles and the opponent hand.
func build() -> void:
	deco = BoardDeco.new()
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gs.add_child(deco)
	layer = gs.passive_layer()
	for side in 2:
		for zone in ZONE_SLOTS:
			for slot in ZONE_SLOTS[zone]:
				_make_slot(side, zone, slot)
	for side in 2:
		var pl := PlayerPlate.new()
		layer.add_child(pl)
		var s := side
		plates.append(pl)
		for zt in PILE_ZONES:
			var ps := PileStack.new()
			ps.zone = zt[0]
			ps.title = zt[1]
			ps.pressed.connect(func(z): if s == 1: gs.selection.open_pile(z))   # L21: one selection at a time
			layer.add_child(ps)
			piles[side][zt[0]] = ps
	controls = DuelControls.new()
	controls.visible = false
	controls.sacrifice_pressed.connect(_on_sacrifice_pressed)
	controls.prompts_toggled.connect(_on_prompts_toggled)
	layer.add_child(controls)
	opp_hand_box = Control.new()
	opp_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(opp_hand_box)
	# #16: no debug-like caption over the fan; an F4 count chip beside it (a child of the fan, so it
	# fades in and out with it).
	opp_hand_chip = UIStyle.chip("", UIStyle.GOLD, 13)
	opp_hand_count_label = opp_hand_chip.get_child(0)
	opp_hand_count_label.add_theme_font_override("font", UIStyle.font_display(600))
	opp_hand_box.add_child(opp_hand_chip)


## A board zone: `zone_node` covers the zone rect (square unit slot, landscape Trap/Spell
## zone, portrait Power zone) and holds `bg`, the drawn empty zone. The card itself lives in
## `holder`, a box sized to the displayed 2:3 card (rotated 3:2 for Defense units and set
## cards) and centred in the zone, so cards are never stretched to the zone shape (F02-03).
func _make_slot(side: int, zone: String, slot: int) -> void:
	var zone_node := Control.new()
	zone_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := ""
	match zone:
		"unit": label = "%s %d" % ["Front" if slot < 3 else "Back", slot % 3 + 1]
		"backrow": label = "Trap / Spell %d" % (slot + 1)
		"power": label = "Power %d" % (slot + 1)
	var bg := CardWidget.new()
	bg.auto_hover = false
	bg.show_tooltip = false
	bg.setup(null, Zones.KIND[zone], label)
	bg.pressed.connect(gs.selection.on_widget_pressed)
	bg.right_pressed.connect(gs.selection.on_widget_right)
	zone_node.add_child(bg)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_node.add_child(holder)
	var ring := ZoneRing.new()
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(null, Zones.KIND[zone], label)
	w.visible = false
	w.pressed.connect(gs.selection.on_widget_pressed)
	w.right_pressed.connect(gs.selection.on_widget_right)
	holder.add_child(w)
	zone_node.add_child(ring)   # above the card: a zone pick outlines the whole zone
	layer.add_child(zone_node)
	slots[key(side, zone, slot)] = {"zone_node": zone_node, "bg": bg, "holder": holder, "widget": w, "hash": -1, "pidx": -1,
		"label": label, "zone": zone, "rot": false, "ring": ring}


## Sizes and centres a slot's card box for the card it shows (or the zone when empty).
static func place_card(it: Dictionary) -> void:
	var zr: Control = it["zone_node"]
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	var csz: Vector2 = w.size if w.visible else zr.size
	holder.size = csz
	holder.pivot_offset = csz / 2.0
	holder.position = ((zr.size - csz) / 2.0).round()


## Slot key "side:zone:slot" (side 1 = my half, at the bottom).
static func key(side: int, zone: String, slot: int) -> String:
	return "%d:%s:%d" % [side, zone, slot]


## Board side a player is drawn on (1 = bottom, me).
func side_of(p: int) -> int:
	return 1 if p == gs.me() else 0


func _slot_rect(side: int, zone: String, slot: int) -> Rect2:
	var col := slot % 3
	match zone:
		"unit":
			var front := slot < 3
			var ry := 0.0
			if side == 0:
				ry = 229.0 if front else 93.0
			else:
				ry = 373.0 if front else 509.0
			return Rect2(_ux + col * (UNIT_SIZE + SLOT_GAP), _y0 + ry, UNIT_SIZE, UNIT_SIZE)
		"backrow":
			return Rect2(_ux + slot * (UNIT_SIZE + SLOT_GAP), _y0 + (0.0 if side == 0 else 645.0), UNIT_SIZE, TRAP_H)
	var bx := _ux - PILE_GAP - (2.0 * POWER_W + SLOT_GAP) if side == 0 else _ux + 3.0 * UNIT_SIZE + 2.0 * SLOT_GAP + PILE_GAP
	var by := _y0 + (93.0 if side == 0 else 373.0)
	var cell := power_cell(side, slot)
	return Rect2(bx + cell.x * (POWER_W + SLOT_GAP), by + cell.y * (UNIT_SIZE + SLOT_GAP), POWER_W, UNIT_SIZE)


## F03-07: displayed (column, row) of authoritative Power slot `slot` in the 2x2 Power block of
## board side `side` (1 = my half, 0 = the opponent's). My own block shows slot s at column
## s % 2, row s / 2. The opponent's block is that arrangement rotated 180 degrees (both axes
## mirrored), so the slot nearest an owner's front unit row stays nearest that row from either
## seat: slot 0 top-left -> bottom-right, 1 top-right -> bottom-left, 2 -> top-right, 3 -> top-left.
## Display only: slot ids and the cards in them never change.
static func power_cell(side: int, slot: int) -> Vector2i:
	var col := slot % 2
	var row := slot / 2
	if side == 0:
		return Vector2i(1 - col, 1 - row)
	return Vector2i(col, row)


## Lays the field out in the screen's play area (window size w x h).
func layout(w: float, h: float) -> void:
	var area := gs.play_area
	table.position = Vector2.ZERO
	table.size = Vector2(w - gs.sidebar_w, h)   # the field only; the sidebar keeps the brown gradient
	_y0 = area.position.y + maxf(0.0, (area.size.y - BOARD_H) / 2.0)
	_ux = area.position.x + (area.size.x - (3.0 * UNIT_SIZE + 2.0 * SLOT_GAP)) / 2.0
	for k in slots.keys():
		var parts: PackedStringArray = (k as String).split(":")
		var r := _slot_rect(int(parts[0]), parts[1], int(parts[2]))
		var it: Dictionary = slots[k]
		(it["zone_node"] as Control).position = r.position
		(it["zone_node"] as Control).size = r.size
		(it["bg"] as Control).size = r.size
		(it["ring"] as Control).size = r.size
		place_card(it)
	# Piles: a 2x2 grid beside the unit zones, mirroring the Power grid (Deck/Extra nearest the
	# centre line, Spent/Exhaust behind them).
	for side in 2:
		var px := _ux - PILE_GAP - (2.0 * POWER_W + SLOT_GAP) if side == 1 else _ux + 3.0 * UNIT_SIZE + 2.0 * SLOT_GAP + PILE_GAP
		var rows := [373.0, 509.0] if side == 1 else [229.0, 93.0]
		for i in PILE_ZONES.size():
			var ps: PileStack = piles[side][PILE_ZONES[i][0]]
			ps.position = Vector2(px + (i % 2) * (POWER_W + SLOT_GAP), _y0 + rows[int(i / 2)])
			ps.size = Vector2(POWER_W, UNIT_SIZE)
	# D5: the plates keep the HUD safe margin from the screen's left edge and from the sidebar.
	(plates[0] as Control).position = Vector2(area.end.x - PLATE_W - UIStyle.SAFE_HUD, _y0 - 10.0)
	(plates[0] as Control).size = Vector2(PLATE_W, 0)
	var ph := (plates[1] as Control).get_combined_minimum_size().y
	(plates[1] as Control).position = Vector2(UIStyle.SAFE_HUD, _y0 + BOARD_H - ph + 8.0)
	(plates[1] as Control).size = Vector2(PLATE_W, 0)
	controls.position = Vector2(UIStyle.SAFE_HUD, _y0 + BOARD_H + 8.0 + DuelControls.TOP_GAP)
	opp_hand_box.position = Vector2(UIStyle.SAFE_HUD, OPP_HAND_Y)
	deco.mid_y = _y0 + 365.0
	deco.x0 = _ux - 30.0
	deco.x1 = _ux + 3.0 * UNIT_SIZE + 2.0 * SLOT_GAP + 30.0
	deco.top_edge = _y0 - 8.0
	deco.bottom_edge = _y0 + BOARD_H + 8.0
	deco.queue_redraw()


## Rebuilds the opponent's face-down hand fan (up to OPP_HAND_MAX backs).
func place_opp_hand() -> void:
	for ch in opp_hand_box.get_children():
		if ch != opp_hand_chip:
			ch.queue_free()
	var n := maxi(opp_hand_n, 0)
	var shown := mini(n, OPP_HAND_MAX)
	var step := 0.0
	if shown > 1:
		step = minf(40.0, (200.0 - CardWidget.SIZES["back"].x) / float(shown - 1))
	for i in shown:
		var b := CardWidget.new().setup({"hidden": true, "zone": "hand"}, "back")
		b.show_tooltip = false
		b.auto_hover = false
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.position = Vector2(i * step, 0)
		opp_hand_box.add_child(b)
	opp_hand_box.move_child(opp_hand_chip, -1)
	_place_opp_chip(n, shown, step)


## The count chip beside the fan, vertically centred on it: "5 cards" ("Ben's hand · 5" for a spectator).
func _place_opp_chip(n: int, shown: int, step: float) -> void:
	var have := not gs.mv.is_empty()
	opp_hand_chip.visible = have
	if not have:
		return
	opp_hand_count_label.text = opp_hand_text(n, String(gs.pv(1 - gs.me())["name"]), gs.is_spectator())
	opp_hand_chip.reset_size()
	var span: float = (step * float(shown - 1) + CardWidget.SIZES["back"].x) if shown > 0 else 0.0
	var csz := opp_hand_chip.get_combined_minimum_size()
	opp_hand_chip.position = Vector2(span + (UIStyle.sp("md") if shown > 0 else 0.0), (CardWidget.SIZES["back"].y - csz.y) / 2.0)


## Text of the opponent hand chip.
static func opp_hand_text(n: int, name: String, spectator: bool) -> String:
	if spectator:
		return "%s's hand · %d" % [name, n]
	return "%d card%s" % [n, "" if n == 1 else "s"]


## Renders both halves of the board, the plates, piles, my hand and the opponent hand count.
func render() -> void:
	var mv := gs.mv
	var have := not mv.is_empty()
	var p := gs.me()
	var o := 1 - p
	gs.sacrifice.sync()   # L5: the mode ends once it can no longer apply
	var targeting := gs.selection.board_targeting()
	src_uid = gs.targeting.source_uid() if targeting else -1
	ready_uids = _compute_ready()
	for side in 2:
		var pidx := p if side == 1 else o
		for zone in ZONE_SLOTS:
			for slot in ZONE_SLOTS[zone]:
				_set_slot(side, zone, slot, pidx, have, targeting)
		var pl: PlayerPlate = plates[side]
		pl.visible = have
		if have:
			var pv := gs.pv(pidx)
			var active: bool = mv["active"] == pidx and mv["winner"] == -1
			var nxt := ""
			if pidx == p and not pv.get("ap_next", []).is_empty():
				var parts := []
				for m in pv["ap_next"]:
					parts.append("%+d" % m["n"])
				nxt = "next turn %s AP" % " ".join(parts)
			pl.begin_game("%s:%d" % [String(gs.view.get("save_id", "local")), int(gs.view.get("game_no", 0))])
			pl.update_from(pv, active, pidx == p and not gs.is_spectator(), "", nxt)
			_update_piles(side, pidx, pv)
	_render_controls(have)
	deco.glow_side = -1   # active player is shown by the plate's turn marker, not a table band
	deco.queue_redraw()
	gs.hand.render(targeting or gs.sacrifice.active)   # L5: the Hand dims in sacrifice mode
	var on: int = gs.pv(o)["counts"]["hand"] if have else -1
	if on != opp_hand_n:
		opp_hand_n = on
		place_opp_hand()
	_render_hidden_own_hand(have)


# ---------------------------------------------------------------- J6 / J11 duel controls

## Left edge (px, play-area x) the hand keeps clear of: the duel controls' right side plus a gap,
## or 0 while they are hidden.
func hand_left_min() -> float:
	if controls == null or not controls.visible:
		return 0.0
	return controls.position.x + DuelControls.block_size().x + HAND_CLEAR


## Gap (px) between the duel controls and the first hand card.
const HAND_CLEAR := 14.0


## True while this screen shows a seat's own game (not a spectator's, the tutorial's or a menu).
func _controls_shown(have: bool) -> bool:
	return have and not gs.is_spectator() and String(gs.view.get("stage", "")) == "game"


## The viewer's settings key for the Trap prompts choice (per seat in hot-seat play).
func prompts_pref_key() -> String:
	return DuelControls.pref_key(String(gs.view.get("mode", "")) == "local", gs.me())


## True in the tutorial: its scripted lessons keep the default prompts and send no setting.
func _tutorial() -> bool:
	return gs.view.has("tutorial") or String(gs.view.get("mode", "")) == "tutorial"


func _render_controls(have: bool) -> void:
	var shown := _controls_shown(have)
	var was := controls.visible
	controls.visible = shown
	if shown != was:
		gs.hand.layout([], true)          # the hand keeps clear of the controls
	if not shown:
		return
	# J11: enabled only while a sacrifice is legal (the tooltip says why not).
	var ok := false
	var tip := "Not your move."
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "sacrifice_pick":
			ok = bool(a["ok"]) and not gs.locked()
			tip = String(a["full"]) if ok else String(a["reason"])
	if gs.mv["winner"] != -1:
		tip = "The duel is over."
	if ok:
		tip = DuelControls.SACRIFICE_TIP
	controls.set_sacrifice(ok, tip, gs.sacrifice.active)   # L5: latched while sacrifice mode is on
	# J6: the toggle shows the viewer's saved choice; the seat's setting follows it.
	var tut := _tutorial()
	controls.prompts_btn.visible = not tut
	if tut:
		return
	var mode := DuelControls.load_prompts(prompts_pref_key())
	if mode != controls.prompts_mode():
		controls.set_prompts(mode)
	_sync_prompts(mode)


## J6: sends the seat's Trap prompts setting when the authority's (own-seat only) differs from the
## viewer's choice: at the start of every game, after a resume or reconnect, and on a toggle. Sent
## once per seat, game and value, so a refused command is not repeated every frame.
func _sync_prompts(want: String) -> void:
	var have := String(gs.pv(gs.me()).get("trap_prompts", ""))
	if have == want:
		return
	var key := "%d|%s|%d|%s" % [gs.me(), String(gs.view.get("save_id", "")), int(gs.view.get("game_no", 0)), want]
	if key == _prompts_sent:
		return
	_prompts_sent = key
	# A seat setting, not a game action: straight to the seat (no toast, not counted as a move).
	if gs.client != null:
		gs.client.send({"t": "trap_prompts", "mode": want})


func _on_prompts_toggled(mode: String) -> void:
	DuelControls.store_prompts(prompts_pref_key(), mode)
	if not gs.mv.is_empty():
		_sync_prompts(mode)


## J11 / L5: the Sacrifice Unit button toggles sacrifice mode (GameSacrificeMode).
func _on_sacrifice_pressed() -> void:
	gs.sacrifice.toggle()


## A2: a spectator who may not see the bottom player's hand gets its card backs along the bottom
## (fanned like the hand), with "<name>'s hand · N cards", so the count is still readable.
func _render_hidden_own_hand(have: bool) -> void:
	var n := 0
	if have and gs.is_spectator() and not gs.pv(gs.me()).has("hand"):
		n = int(gs.pv(gs.me())["counts"]["hand"])
	if own_backs_box == null:
		own_backs_box = Control.new()
		own_backs_box.name = "SpectatorHandBacks"
		own_backs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(own_backs_box)
		own_backs_label = UIStyle.label("", 13, UIStyle.MUTED, false, true)
		own_backs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(own_backs_label)
	var key := "%d:%s:%s" % [n, gs.pv(gs.me())["name"] if have else "", str(gs.size)]
	if key == _own_backs_key:
		return
	_own_backs_key = key
	for ch in own_backs_box.get_children():
		ch.queue_free()
	own_backs_label.visible = n > 0
	own_backs_box.visible = n > 0
	if n == 0:
		return
	var shown := mini(n, OPP_HAND_MAX)
	var bw: float = CardWidget.SIZES["hand"].x
	var step := minf(bw * 0.62, (520.0 - bw) / maxf(1.0, float(shown - 1)))
	var span := step * (shown - 1) + bw
	var x0 := gs.play_area.size.x / 2.0 - span / 2.0
	var top := gs.size.y - GameScreen.HAND_H + 6.0
	for i in shown:
		var b := CardWidget.new().setup({"hidden": true, "zone": "hand"}, "hand")
		b.show_tooltip = false
		b.auto_hover = false
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := 0.0 if shown == 1 else (float(i) - float(shown - 1) / 2.0) / (float(shown - 1) / 2.0)
		b.position = Vector2(x0 + i * step, top + t * t * 6.0)
		b.pivot_offset = Vector2(bw / 2.0, 0.0)
		b.scale = Vector2(0.88, 0.88)   # card backs carry no text: a little smaller keeps the fan on screen
		b.rotation = deg_to_rad(t * 2.0) if not UIStyle.reduce_motion else 0.0
		own_backs_box.add_child(b)
	own_backs_label.text = "%s's hand · %d card%s" % [String(gs.pv(gs.me())["name"]), n, "" if n == 1 else "s"]
	own_backs_label.size = Vector2(gs.play_area.size.x, 20)
	own_backs_label.position = Vector2(0, gs.size.y - GameScreen.HAND_H - 18.0)


## Pile stacks: counts for both players; only your own piles open for inspection. Your Extra
## pile carries the "can act" ring while a Ritual/Arcane summon is available from it, or a
## Fusion method can be activated now with a summonable Fusion unit (F03-08, `extra_avail`).
func _update_piles(side: int, pidx: int, pv: Dictionary) -> void:
	# A spectator opens the bottom player's piles only when that player lets them see their cards.
	var mine := pidx == gs.me() and (not gs.is_spectator() or pv.has("spent"))
	var extra_ready := false
	if mine:
		for c in pv.get("extra", []):
			if ready_uids.has(int(c.get("uid", -1))):
				extra_ready = true
		if not gs.locked() and not gs.sacrifice.active and bool(gs.mv.get("extra_avail", {}).get("any", false)):
			extra_ready = true
	for zt in PILE_ZONES:
		var ps: PileStack = piles[side][zt[0]]
		ps.visible = not gs.mv.is_empty()
		ps.set_pile(int(pv["counts"][zt[0]]), mine, mine and zt[0] == "extra" and extra_ready)
		ps.set_selected(mine and gs.details.pile_zone == zt[0])


## F02-11: cards of yours that can act right now (play/summon/set from Hand, manual
## Unit/Power/set-Spell effects, attacks). Stance changes and sacrifices are always
## available in Main 1 and would light up every unit, so they do not count.
func _compute_ready() -> Dictionary:
	var out := {}
	var mv := gs.mv
	if gs.locked() or mv["active"] != gs.me() or gs.sacrifice.active:   # L5: only the sacrificable units glow
		return out
	for a in mv.get("actions", []):
		if a["ok"] and a.has("uid") and String(a["t"]) in READY_KINDS:
			out[int(a["uid"])] = true
	return out


func _set_slot(side: int, zone: String, slot: int, pidx: int, have: bool, targeting: bool) -> void:
	var sel := gs.selection
	var it: Dictionary = slots[key(side, zone, slot)]
	var w: CardWidget = it["widget"]
	var cv = null
	if have:
		cv = gs.pv(pidx)[Zones.KEY[zone]][slot]
	var hsh := hash(cv) if cv != null else 0
	var bg: CardWidget = it["bg"]
	if it["hash"] != hsh or it["pidx"] != pidx:
		# Defense units and every Trap/Spell-zone card are the 2:3 card turned sideways.
		var rot: bool = cv != null and (zone == "backrow" or (zone == "unit" and cv.get("stance", "atk") == "def"))
		if cv != null:
			w.setup(cv, Zones.KIND[zone], it["label"], rot)
		w.visible = cv != null
		it["hash"] = hsh
		it["pidx"] = pidx
		it["rot"] = rot
		place_card(it)
	bg.show_label = have and bool(gs.mv.get("first_turn", false))
	var opt := sel.option_for_ref(pidx, zone, slot)
	var vis: bool = cv != null and not cv.get("hidden", false)
	var uid: int = cv.get("uid", -2) if vis else -2
	var is_sel: bool = vis and uid == gs.selected_uid
	var chosen: bool = opt != -1 and opt in gs.multi
	var dim: bool = targeting and opt == -1 and not (vis and uid == src_uid)
	# D9: while an effect button is hovered, the invalid targets stay darkened and the valid ones get a
	# subtle border (the real targeting highlight only starts once the effect is chosen).
	var previewing: bool = not targeting and not preview_refs.is_empty()
	var pv_hit: bool = previewing and _in_preview(pidx, zone, slot)
	if previewing and not pv_hit and not (vis and uid == preview_src):
		dim = true
	var pd := gs.pending()
	var zone_pick: bool = opt != -1 and String(pd.get("kind", "")) == "slot"
	# The card whose summon / activation a Trap prompt responds to is outlined in red.
	var cause_ref: Dictionary = pd.get("cause", {}).get("card", {}) if pd.get("mine", false) else {}
	var is_cause: bool = not cause_ref.is_empty() and int(cause_ref["p"]) == pidx and String(cause_ref["zone"]) == zone and int(cause_ref["slot"]) == slot
	# L5: in sacrifice mode only my sacrificable units are ringed in ember; everything else dims.
	var sac_on: bool = gs.sacrifice.active
	var sac_ok: bool = sac_on and vis and pidx == gs.me() and zone == "unit" and gs.sacrifice.can_sacrifice(uid)
	if sac_on:
		dim = not sac_ok
		is_sel = vis and uid == gs.sacrifice.kb_uid
	var ring: ZoneRing = it["ring"]
	ring.col = GameSacrificeMode.EMBER if sac_ok else (GameTargeting.HOSTILE_COLOR if is_cause else UIStyle.TARGET)
	ring.set_on((zone_pick or is_cause or sac_ok) and cv != null)
	if ring.on:
		ring.queue_redraw()
	if cv == null:
		bg.set_marks(opt != -1, chosen, dim)
		return
	bg.set_marks(false, false, dim)
	w.set_preview_target(pv_hit)
	w.set_marks(opt != -1 and not zone_pick, is_sel or chosen, dim)
	w.set_ready(vis and ready_uids.has(uid))
	w.order_no = sel.order_no(opt)
	w.queue_redraw()


## D9: shows (refs non-empty) or clears (empty) the target preview of the hovered effect button of card
## `src`. `refs` are the {p, zone, slot} zones the effect's first target choice offers (from the view).
func set_preview(refs: Array, src: int = -1) -> void:
	if refs.is_empty() and preview_refs.is_empty():
		return
	preview_refs = refs.duplicate()
	preview_src = src if not refs.is_empty() else -1
	render()


func _in_preview(pidx: int, zone: String, slot: int) -> bool:
	for r in preview_refs:
		if int(r["p"]) == pidx and String(r["zone"]) == zone and int(r["slot"]) == slot:
			return true
	return false


# ---------------------------------------------------------------- where things are

## Slot item of player p's zone slot, or {}.
func slot_item(p: int, zone: String, slot: int) -> Dictionary:
	return slots.get(key(side_of(p), zone, slot), {})


## Width of the unit block (3 unit zones and their gaps): the unit of normalised board space.
const BLOCK_W := 3.0 * UNIT_SIZE + 2.0 * SLOT_GAP


## A2: screen-local point `p` in normalised board space (see CursorTrack): (0, 0) is the top-left
## of the unit block, (1, 1) its bottom-right. The board is drawn at a fixed size, so the same
## normalised point is over the same zone in any window.
func local_to_norm(p: Vector2) -> Vector2:
	return (p - Vector2(_ux, _y0)) / Vector2(BLOCK_W, BOARD_H)


## The screen-local point of normalised board position `n` (inverse of local_to_norm).
func norm_to_local(n: Vector2) -> Vector2:
	return Vector2(_ux, _y0) + n * Vector2(BLOCK_W, BOARD_H)


## Global rect of the card box in player p's zone slot (Rect2() when there is no such slot).
func slot_global_rect(p: int, zone: String, slot: int) -> Rect2:
	var it: Dictionary = slot_item(p, zone, slot)
	if it.is_empty():
		return Rect2()
	return (it["holder"] as Control).get_global_rect()


## Player p's plate.
func plate_of(p: int) -> PlayerPlate:
	return plates[side_of(p)]


## Global point cards fly to/from for a player's hand.
func hand_anchor(p: int) -> Vector2:
	if p == gs.me():
		return gs.get_global_transform() * Vector2(gs.play_area.size.x / 2.0, gs.size.y - GameScreen.HAND_H / 2.0)
	return opp_hand_box.get_global_rect().get_center() + Vector2(60, 40)


## Centre of a player's unit block (direct-attack animations aim here).
func side_center(p: int) -> Vector2:
	var y := _y0 + (229.0 + 128.0 if side_of(p) == 0 else 373.0 + 128.0)
	return gs.get_global_transform() * Vector2(_ux + (3.0 * UNIT_SIZE + 2.0 * SLOT_GAP) / 2.0, y - 64.0)


## Where cards fly to/from for a player's pile (draw animations).
func pile_anchor(p: int, zone: String) -> Vector2:
	var ps: PileStack = piles[side_of(p)].get(zone)
	return ps.top_center() if ps != null else hand_anchor(p)
