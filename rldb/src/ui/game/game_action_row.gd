class_name GameActionRow
extends RefCounted
## Action row for the click-selected own card (F02-01/F02-02/F02-04): its legal actions as
## buttons against the card, and running one of them.

## H2 (owner, 21 Oct): the action buttons are forged plates (ActionButton). Height, gap and the
## widths of a one- and two-column row (px).
const BUTTON_H := 34.0
const BUTTON_GAP := 5.0
const ONE_COL_W := 160.0
const TWO_COL_W := 252.0
## Label size (px) of an action button (Cinzel).
const LABEL_PX := 14

## The host screen this component works on.
var gs: GameScreen
## The row's button box (in the hover layer), or null.
var stack: Control
var _sig: String = ""


func _init(screen: GameScreen) -> void:
	gs = screen


## Removes the row.
func clear() -> void:
	if gs.board != null:
		gs.board.set_preview([])
	if stack != null and is_instance_valid(stack):
		stack.queue_free()
	stack = null
	_sig = ""


## Global rect of the row (Rect2() without one).
func stack_rect() -> Rect2:
	if stack == null or not is_instance_valid(stack):
		return Rect2()
	return stack.get_global_rect()


## Legal actions of a card (only enabled ones; reasons stay in the details panel notes).
func actions_for_card(uid: int) -> Array:
	if gs.locked():
		return []
	var oks := []
	for a in gs.mv.get("actions", []):
		if a.get("uid", -1) == uid and a["ok"]:
			oks.append(a)
	return oks


static func _act_sig(acts: Array) -> String:
	var parts := []
	for a in acts:
		parts.append("%s/%s/%s/%s/%s/%s/%s" % [a["t"], a.get("idx", ""), a.get("stance", ""), a.get("mode", ""), a.get("target", ""), a["ok"], a.get("reason", "")])
	return "|".join(parts)


func _row_wanted() -> bool:
	if not gs.row_open or gs.selected_uid == -1 or gs.locked():
		return false
	var it := gs.selection.item_for_uid(gs.selected_uid)
	return not it.is_empty() and it["own"]


## Rebuilds the row only when the selected card's actions (or keyboard focus) changed.
func refresh() -> void:
	if not _row_wanted():
		if stack != null:
			clear()
		return
	var sig := _sig_for(gs.selected_uid, actions_for_card(gs.selected_uid))
	if sig != _sig or stack == null:
		rebuild()


func _sig_for(uid: int, acts: Array) -> String:
	var kb := gs.keyboard
	return _act_sig(acts) + "#%d" % (kb.kb_idx if uid == kb.kb_uid else -1)


## Action row for the click-selected own card. It sits against the card but OUTSIDE its
## body — above a lifted hand card, just below a field card — so the name plate, ATK/DEF and
## status chips stay visible. Buttons carry short labels; the full description is the tooltip
## and lives in the details panel.
func rebuild() -> void:
	clear()
	if not _row_wanted():
		return
	var uid := gs.selected_uid
	var it := gs.selection.item_for_uid(uid)
	var acts := actions_for_card(uid)
	_sig = _sig_for(uid, acts)
	if acts.is_empty():
		return
	var tr := gs.hover.target_rect(it)
	var kind: String = it["kind"]
	var n := acts.size()
	var hand := kind == "hand"
	var bh := BUTTON_H
	var gap := BUTTON_GAP
	var cols := 1 if (hand or n <= 2) else 2
	var rows := int(ceil(float(n) / float(cols)))
	var w := maxf(tr.size.x, ONE_COL_W if cols == 1 else TWO_COL_W)
	var bw := (w - gap * float(cols - 1)) / float(cols)
	# Owner (21 Oct): labels show whole. A button widens to its longest label instead of cutting it.
	var labels := []
	for a in acts:
		labels.append(String(a["label"]) if a["ok"] else String(a["reason"]))
	bw = maxf(bw, label_fit_width(labels))
	w = bw * float(cols) + gap * float(cols - 1)
	var total := rows * bh + (rows - 1) * gap
	var x := tr.get_center().x - w / 2.0
	var top := 0.0
	if hand:
		top = tr.position.y - total - 6.0
	else:
		top = tr.end.y + 4.0
		if top + total > gs.size.y - GameScreen.HAND_H + 4.0 and it["own"]:
			top = tr.position.y - total - 4.0
	x = clampf(x, 4.0, maxf(4.0, gs.play_area.end.x - w - 4.0))
	top = maxf(top, GameScreen.TOP_H + 2.0)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size = Vector2(w, total)
	box.position = gs.hover_layer.get_global_transform().affine_inverse() * Vector2(x, top)
	var kb := gs.keyboard
	for i in n:
		var a: Dictionary = acts[i]
		var txt: String = String(a["label"]) if a["ok"] else String(a["reason"])
		var kbf: bool = uid == kb.kb_uid and i == kb.kb_idx
		var b := ActionButton.new(txt, String(a["t"]), String(a.get("stance", "")), kbf)
		b.size = Vector2(bw, bh)
		b.custom_minimum_size = Vector2(bw, bh)
		b.position = Vector2(float(i % cols) * (bw + gap), float(int(i / cols)) * (bh + gap))
		b.tooltip_text = String(a.get("full", a["label"])) + ("" if a["ok"] else "\n" + String(a["reason"]))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if a["ok"] else Control.CURSOR_ARROW
		# D9: hovering an effect that targets field cards previews the valid targets until the pointer leaves.
		var tg: Array = a.get("targets", [])
		if a["ok"] and not tg.is_empty():
			b.mouse_entered.connect(func(): gs.board.set_preview(tg, uid))
			b.mouse_exited.connect(func(): gs.board.set_preview([]))
		if a["ok"]:
			b.pressed.connect(run_action.bind(uid, a))
		else:
			b.disabled = true
		box.add_child(b)
	gs.hover_layer.add_child(box)
	stack = box
	if not UIStyle.reduce_motion:
		# H2: the plates rise into place one after another (STAGGER apart), fading in.
		var tw := gs.create_tween().set_parallel(true)
		for j in box.get_child_count():
			var bj := box.get_child(j) as Control
			var home := bj.position
			bj.modulate.a = 0.0
			bj.position = home + Vector2(0, -RISE_PX if hand else RISE_PX)
			var at := UIStyle.dur(STAGGER * j)
			tw.tween_property(bj, "modulate:a", 1.0, UIStyle.dur(0.1)).set_delay(at)
			tw.tween_property(bj, "position", home, UIStyle.dur(0.14)).set_delay(at).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	box.set_meta("rect_global", Rect2(Vector2(x, top), Vector2(w, total)))


## H2: the row's entrance: each plate rises RISE_PX into place, STAGGER s after the one before.
const RISE_PX := 6.0
const STAGGER := 0.03


## Sends action `a` of card `uid` if it is still legal (a stale click is denied).
func run_action(uid: int, a: Dictionary) -> void:
	# Ignore a stale click: the action must still be legal for this card instance.
	var still := false
	for b in gs.mv.get("actions", []):
		if b.get("uid", -1) == uid and b["t"] == a["t"] and b.get("idx", -1) == a.get("idx", -1) \
				and b.get("stance", "") == a.get("stance", "") and b.get("mode", "") == a.get("mode", "") 				and b.get("target", -1) == a.get("target", -1) and b["ok"]:
			still = true
	if not still or gs.locked():
		Sfx.play("deny")
		return
	var cmd := {"t": a["t"], "uid": uid}
	if a.has("idx"):
		cmd["idx"] = a["idx"]
	if a.has("stance"):
		cmd["stance"] = a["stance"]
	if a.has("mode"):
		cmd["mode"] = a["mode"]          # G07: Attack / Attack Direct
	if a.has("target"):
		cmd["target"] = a["target"]      # a targeted Ritual Tribute (J14: the button sends none; the tray asks)
	gs.selected_uid = uid
	gs.acting_uid = uid
	gs.row_open = false
	gs.keyboard.kb_uid = -1
	clear()
	var it := gs.selection.item_for_uid(uid)
	var hv := gs.hover.hv
	if not it.is_empty() and it["kind"] == "hand":
		gs.hover.release_hand(uid)          # D2: back to normal size at once, off the trap zones
	elif not it.is_empty() and not (not hv.is_empty() and hv["uid"] == uid):
		gs.hover.unlift(it)
	Sfx.play("confirm")
	gs.send(cmd)


## Width (px) an action button needs to show the longest of `labels` whole: the label in the
## button font plus the medallion and the side margins.
static func label_fit_width(labels: Array) -> float:
	var font := UIStyle.font_display(700)
	var widest := 0.0
	for t in labels:
		widest = maxf(widest, font.get_string_size(String(t), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX).x)
	return ceilf(widest + ActionButton.GLYPH_W + 6.0 + 12.0 + 4.0)


## H2 (owner, 21 Oct): a card action button as a forged plate in the game's gold and metal: a dark
## iron face with metal grain and a top sheen, a gold-leaf rim on a bronze foot, an engraved inner
## line, gold rivets at the ends and a medallion with the action's glyph (Summon chevrons, Set card,
## Cast spark, Attack sword, stance shield...). Hover warms the face, lights the rim and glows gold;
## pressing sinks the plate; disabled is a plain slate plate with muted text. The keyboard's choice
## wears the hover rim. JuicyButton gives the lift, the press-in and the focus ring; the hover cue
## comes from the shared button hook and the press sound from run_action (confirm, or deny).
## Everything is drawn in _draw, which only runs again on a state change (no per-frame cost).
class ActionButton extends JuicyButton:
	## Iron face, its hover face and the pressed face.
	const FACE := Color("2a2420")
	const FACE_HOVER := Color("3a3026")
	const FACE_DOWN := Color("1d1915")
	const RADIUS := 6
	## Room (px) the medallion takes at the left of the label.
	const GLYPH_W := 26.0
	## Action kind -> accent of its medallion (the gold default for summons and the rest).
	const ACCENT := {"attack": Color("e8605a"), "stance": Color("b4b6bc"), "cast": Color("5aa2ff"),
		"activate_set": Color("5aa2ff"), "ability": Color("5aa2ff"), "power": Color("5aa2ff"),
		"sacrifice": Color("e07a3a"), "ritual": Color("a874e0"), "ritual_tribute": Color("a874e0"),
		"arcane": Color("b4b6bc"), "set": Color("c49a5a")}

	## The action kind (the action's "t") and, for a stance change, the stance it goes to.
	var kind := ""
	var to_stance := ""
	## Drawn as the keyboard's current choice.
	var keyboard_pick := false

	func _init(text_: String = "", kind_: String = "", stance_: String = "", kb_pick: bool = false) -> void:
		super()
		kind = kind_
		to_stance = stance_
		keyboard_pick = kb_pick
		text = text_
		focus_mode = Control.FOCUS_NONE
		clip_text = true
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_theme_font_override("font", UIStyle.font_display(700))
		add_theme_font_size_override("font_size", LABEL_PX)
		add_theme_color_override("font_color", UIStyle.GOLD_HI if kb_pick else UIStyle.TEXT)
		add_theme_color_override("font_hover_color", UIStyle.GOLD_HI)
		add_theme_color_override("font_pressed_color", UIStyle.GOLD_HI)
		add_theme_color_override("font_hover_pressed_color", UIStyle.GOLD_HI)
		add_theme_color_override("font_focus_color", UIStyle.TEXT)
		add_theme_color_override("font_disabled_color", UIStyle.DISABLED)
		add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		add_theme_constant_override("outline_size", 3)
		var st := ActionButton.styles(kb_pick)
		for k in st:
			add_theme_stylebox_override(k, st[k])
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		hover_inner_glow = Color(UIStyle.GOLD, 0.16)
		set_meta(Sfx.BUTTON_META, "none")   # run_action plays confirm (or deny for a stale click)

	## The plate's state boxes {normal, hover, pressed, hover_pressed, disabled}; `kb_pick` gives the
	## normal plate the hover rim (the keyboard's choice).
	static func styles(kb_pick: bool = false) -> Dictionary:
		var n := UIStyle.flat(FACE, Color(UIStyle.GOLD, 0.8), 1, RADIUS)
		n.border_width_bottom = 2
		var h := UIStyle.flat(FACE_HOVER, UIStyle.GOLD_HI, 1, RADIUS)
		h.border_width_bottom = 2
		var p := UIStyle.flat(FACE_DOWN, Color(UIStyle.GOLD, 0.9), 1, RADIUS)
		var d := UIStyle.flat(UIStyle.PANEL, UIStyle.DISABLED_EDGE, 1, RADIUS)
		for sb in [n, h, p, d]:
			sb.content_margin_left = GLYPH_W + 6.0
			sb.content_margin_right = 12
			sb.content_margin_top = 1
			sb.content_margin_bottom = 2
			sb.anti_aliasing = true
		p.content_margin_top = 3
		p.content_margin_bottom = 0
		UIStyle.lift_style(n, Color(0, 0, 0, 0.6), 5, 2)
		UIStyle.lift_style(h, Color(UIStyle.GOLD, 0.42), 9, 0)
		UIStyle.lift_style(p, Color(0, 0, 0, 0.5), 2, 1)
		if kb_pick:
			n.border_color = UIStyle.GOLD_HI
			n.set_border_width_all(2)
			UIStyle.lift_style(n, Color(UIStyle.GOLD, 0.35), 8, 0)
		var grain := UIStyle.BUTTON_GRAIN
		return {
			"normal": UiSurface.box(n, UiSurface.METAL, grain, UIStyle.BUTTON_SHEEN * 1.4),
			"hover": UiSurface.box(h, UiSurface.METAL, grain, UIStyle.BUTTON_SHEEN * 1.8),
			"pressed": UiSurface.box(p, UiSurface.METAL, grain, UIStyle.BUTTON_SHEEN * 0.5),
			"hover_pressed": UiSurface.box(p, UiSurface.METAL, grain, UIStyle.BUTTON_SHEEN * 0.5),
			"disabled": d,
		}

	## The state the plate is drawn in: "disabled", "pressed", "hover" or "normal".
	func plate_state() -> String:
		if disabled:
			return "disabled"
		if _down:
			return "pressed"
		return "hover" if (_hover or keyboard_pick) else "normal"

	func _draw() -> void:
		super()
		if size.x < 24.0 or size.y < 16.0:
			return
		var st := plate_state()
		var lit := st == "hover" or st == "pressed"
		var off := st == "disabled"
		var dy := 1.0 if st == "pressed" else 0.0
		var gold: Color = UIStyle.DISABLED if off else (UIStyle.GOLD_HI if lit else UIStyle.GOLD)
		# The engraved inner line, 3 px inside the rim.
		var inner := StyleBoxFlat.new()
		inner.draw_center = false
		inner.set_border_width_all(1)
		inner.set_corner_radius_all(RADIUS - 2)
		inner.anti_aliasing = true
		inner.border_color = Color(gold, 0.16 if off else (0.42 if lit else 0.26))
		draw_style_box(inner, Rect2(Vector2(3, 3 + dy), size - Vector2(6, 7)))
		# Rivets: a gold diamond on each end of the rim.
		var cy := size.y / 2.0 + dy - 1.0
		for x in [1.5, size.x - 1.5]:
			Ornate.diamond(self, Vector2(x, cy), 3.2, Color(0, 0, 0, 0.6))
			Ornate.diamond(self, Vector2(x, cy), 2.3, Color(gold, 0.95))
		# The medallion with the action's glyph.
		var c := Vector2(GLYPH_W / 2.0 + 5.0, cy)
		var r := minf(11.0, size.y / 2.0 - 5.0)
		var acc: Color = ACCENT.get(kind, UIStyle.GOLD)
		if kind == "stance" and to_stance == "atk":
			acc = Color("e8605a")
		draw_circle(c, r + 1.2, Color(0, 0, 0, 0.55))
		draw_circle(c, r, UIStyle.PANEL_INK if off else acc.darkened(0.7))
		if lit and not off:
			draw_circle(c, r - 1.5, Color(acc, 0.22))
		draw_arc(c, r, 0.0, TAU, 28, Color(gold, 0.95 if lit else 0.8), 1.3, true)
		var gc: Color = UIStyle.DISABLED if off else (Color(1, 0.96, 0.84) if lit else gold.lightened(0.2))
		ActionButton.draw_glyph(self, kind, to_stance, c, r * 0.62, gc)

	## Draws the glyph of action `k` (stance target `stance`) centred on `c`, about `s` px in radius.
	static func draw_glyph(ci: CanvasItem, k: String, stance: String, c: Vector2, s: float, col: Color) -> void:
		match k:
			"summon", "ritual", "arcane", "ritual_tribute":   # rising double chevron
				for j in 2:
					var y := c.y + s * (0.5 - 0.8 * j)
					ci.draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.8, y + s * 0.35), Vector2(c.x, y - s * 0.4), Vector2(c.x + s * 0.8, y + s * 0.35)]), col, 1.7, true)
			"set":   # a face-down card, tilted
				var pts := PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.9), c + Vector2(s * 0.75, -s * 0.62), c + Vector2(s * 0.5, s * 0.9), c + Vector2(-s * 0.75, s * 0.62)])
				ci.draw_colored_polygon(pts, Color(col, 0.25))
				var closed := pts.duplicate()
				closed.append(pts[0])
				ci.draw_polyline(closed, col, 1.4, true)
				Ornate.diamond(ci, c, s * 0.3, col)
			"cast", "activate_set", "ability":   # four-point spark
				var pts := PackedVector2Array()
				for j in 8:
					var ang := TAU * j / 8.0 - PI / 2.0
					pts.append(c + Vector2(cos(ang), sin(ang)) * (s if j % 2 == 0 else s * 0.3))
				ci.draw_colored_polygon(pts, col)
			"power":   # hexagon gem
				var pts := PackedVector2Array()
				for j in 6:
					var ang := TAU * j / 6.0 + PI / 6.0
					pts.append(c + Vector2(cos(ang), sin(ang)) * s * 0.9)
				ci.draw_colored_polygon(pts, Color(col, 0.35))
				pts.append(pts[0])
				ci.draw_polyline(pts, col, 1.3, true)
			"attack":   # sword, point up-right
				var d := Vector2(0.7071, -0.7071)
				var n := Vector2(0.7071, 0.7071)
				ci.draw_line(c - d * s * 0.95, c + d * s, col, 2.0, true)
				ci.draw_line(c - d * s * 0.35 - n * s * 0.45, c - d * s * 0.35 + n * s * 0.45, col, 1.8, true)
			"stance":   # a shield (to Defense) or an upright sword (to Attack)
				if stance == "atk":
					ci.draw_line(c + Vector2(0, s), c + Vector2(0, -s), col, 2.0, true)
					ci.draw_line(c + Vector2(-s * 0.5, s * 0.35), c + Vector2(s * 0.5, s * 0.35), col, 1.8, true)
				else:
					var pts := PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.8, s * 0.05), c + Vector2(0, s), c + Vector2(-s * 0.8, s * 0.05)])
					ci.draw_colored_polygon(pts, Color(col, 0.3))
					pts.append(pts[0])
					ci.draw_polyline(pts, col, 1.4, true)
			"sacrifice":   # a flame
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.6, s * 0.45),
					c + Vector2(0, s), c + Vector2(-s * 0.6, s * 0.45), c + Vector2(-s * 0.4, -s * 0.2)]), col)
			"move":   # a two-headed arrow
				ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, 1.6, true)
				for sx in [-1.0, 1.0]:
					ci.draw_polyline(PackedVector2Array([c + Vector2(sx * s * 0.45, -s * 0.5), c + Vector2(sx * s, 0), c + Vector2(sx * s * 0.45, s * 0.5)]), col, 1.6, true)
			_:   # a gold diamond
				Ornate.diamond(ci, c, s * 0.75, col)
