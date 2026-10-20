class_name FolderTabs
extends Container
## The game's one tab widget: folder tabs over a content pane (deck builder, deck selection, draft
## categories). Fantasy styled: a bronze metal rim with a gold inner line on the open tab, a leather
## grain on every face (UiSurface), a top sheen, a gold glow on hover and the shared click sound.
##
## The open tab and the pane are ONE shape: one fill and one rim, with no line between them. The
## pane's top border runs on beneath every closed tab. Tabs start after `left_margin`, like folder
## tabs, so the pane's top-left corner shows.
##
##     var ft := FolderTabs.new()
##     ft.add_tab("saved", "Saved Decks")
##     ft.add_tab("starters", "Starter Decks", {"badge": "12"})
##     ft.tab_selected.connect(func(key): ...)
##     ft.pane.add_child(content)
##
## Presentation only: it owns no game state, it reports which tab was chosen.

## A tab was chosen by the player (not emitted by `select(key, false)`).
signal tab_selected(key: String)

const RIM_W := 2.0
const FLARE := 5.0
const TAB_R := 9.0
const PANE_R := 8.0
## Closed tabs sit this far below the open one.
const DROP := 5.0
const GRAIN := 0.5

## Key of the open tab ("" when none).
var selected: String = ""
## Gap before the first tab, px.
var left_margin: float = 24.0
## Height of the tab strip (the open tab's full height), px.
var tab_height: float = 44.0
## Tab title size, px.
var font_size: int = 18
## Gap between tabs, px.
var tab_gap: float = 8.0
## Pane and open-tab fill.
var pane_fill: Color = Color(0.05, 0.042, 0.034, 0.93)
## Rim colour of the pane and the tabs.
var rim: Color = UIStyle.BRONZE.lightened(0.18)
## Grain material of the faces.
var grain_material: String = UiSurface.LEATHER
## Content parent: the pane under the tabs.
var pane: PanelContainer

var _strip: HBoxContainer
var _tabs_box: HBoxContainer
var _trailing_slot: HBoxContainer
var _tabs: Array[Tab] = []
var _pane_box: StyleBoxEmpty


func _init() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_PASS
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 18)
	add_child(_strip)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", int(tab_gap))
	_strip.add_child(_tabs_box)
	_trailing_slot = HBoxContainer.new()
	_trailing_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trailing_slot.alignment = BoxContainer.ALIGNMENT_END
	_strip.add_child(_trailing_slot)
	pane = PanelContainer.new()
	_pane_box = StyleBoxEmpty.new()
	pane.add_theme_stylebox_override("panel", _pane_box)
	set_pane_margins(10, 14, 10, 10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pane)
	sort_children.connect(queue_redraw)


## Content margins of the pane (the top one is kept clear of the rim and the open tab's foot).
func set_pane_margins(l: float, t: float, r: float, b: float) -> void:
	_pane_box.content_margin_left = l
	_pane_box.content_margin_top = maxf(t, RIM_W + 6.0)
	_pane_box.content_margin_right = r
	_pane_box.content_margin_bottom = b
	update_minimum_size()


## Adds a tab and returns it. `opts`: glyph (Control drawn before the title), badge (String shown in
## a pill after it), accent (Color of its rim accent), disabled (bool), tooltip (String),
## min_width (float).
func add_tab(key: String, title: String, opts: Dictionary = {}) -> Tab:
	var t := Tab.new(self, key, title, opts)
	_tabs.append(t)
	_tabs_box.add_child(t)
	if selected == "" and not t.disabled:
		selected = key
	_refresh_states()
	update_minimum_size()
	queue_redraw()
	return t


## Puts `c` at the right end of the tab strip (a hint line, a chip, a button).
func set_trailing(c: Control) -> void:
	for ch in _trailing_slot.get_children():
		_trailing_slot.remove_child(ch)
		ch.queue_free()
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trailing_slot.add_child(c)


## The tab with `key` (null when absent).
func tab(key: String) -> Tab:
	for t in _tabs:
		if t.key == key:
			return t
	return null


## Number of tabs.
func tab_count() -> int:
	return _tabs.size()


## True when tab `key` is the open one.
func is_open(key: String) -> bool:
	return selected == key


## Opens tab `key`. `emit` reports it through `tab_selected` (only when it changed).
func select(key: String, emit: bool = true) -> void:
	var t := tab(key)
	if t == null or t.disabled or key == selected:
		return
	selected = key
	_refresh_states()
	queue_redraw()
	if emit:
		tab_selected.emit(key)


## The rect of tab `key` in this widget's coordinates (empty when absent).
func tab_rect(key: String) -> Rect2:
	var t := tab(key)
	if t == null:
		return Rect2()
	return Rect2(t.position + _tabs_box.position + _strip.position, t.size)


## The x-ranges ([from, to] pairs, in widget px) where the pane's top border is drawn: the whole
## width, minus the foot of the open tab (and its two flares), where the tab joins the pane.
## `open_x0` / `open_x1` are the open tab's left and right edges (`open_x1 <= open_x0`: none open).
static func top_border_spans(width: float, open_x0: float, open_x1: float) -> Array:
	var a := 1.0 + PANE_R
	var b := width - 1.0 - PANE_R
	if open_x1 <= open_x0:
		return [[a, b]]
	return [[a, open_x0 - FLARE], [open_x1 + FLARE, b]]


func _get_minimum_size() -> Vector2:
	var sm := _strip.get_combined_minimum_size()
	var pm := pane.get_combined_minimum_size()
	return Vector2(maxf(sm.x + left_margin, pm.x), tab_height + pm.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		fit_child_in_rect(_strip, Rect2(left_margin, 0.0, maxf(0.0, size.x - left_margin - 12.0), tab_height))
		fit_child_in_rect(pane, Rect2(0.0, tab_height, size.x, maxf(0.0, size.y - tab_height)))
		queue_redraw()


func _refresh_states() -> void:
	for t in _tabs:
		t.apply_state(t.key == selected)


# ------------------------------------------------------------------ drawing
func _arc(pts: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float, n: int = 7) -> void:
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		var p := c + Vector2(cos(a), sin(a)) * r
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.05:
			pts.append(p)


func _push(pts: PackedVector2Array, p: Vector2) -> void:
	if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.05:
		pts.append(p)


## The rounded outline of one tab from its bottom-left up over the top to its bottom-right.
func _tab_path(x0: float, x1: float, y_top: float, y_bot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(TAB_R, (x1 - x0) / 2.0)
	_push(pts, Vector2(x0, y_bot))
	_arc(pts, Vector2(x0 + r, y_top + r), r, PI, 1.5 * PI)
	_arc(pts, Vector2(x1 - r, y_top + r), r, 1.5 * PI, 2.0 * PI)
	_push(pts, Vector2(x1, y_bot))
	return pts


## The silhouette of the pane with the open tab (when any) grown out of its top edge: one closed shape.
func _silhouette(open_x0: float, open_x1: float) -> PackedVector2Array:
	var w := size.x
	var yt := tab_height
	var yb := size.y - 1.0
	var pts := PackedVector2Array()
	_arc(pts, Vector2(1.0 + PANE_R, yt + PANE_R), PANE_R, PI, 1.5 * PI)
	if open_x1 > open_x0:
		_push(pts, Vector2(open_x0 - FLARE, yt))
		_arc(pts, Vector2(open_x0 - FLARE, yt - FLARE), FLARE, 0.5 * PI, 0.0, 4)
		for p in _tab_path(open_x0, open_x1, 1.0, yt - FLARE):
			_push(pts, p)
		_arc(pts, Vector2(open_x1 + FLARE, yt - FLARE), FLARE, PI, 0.5 * PI, 4)
	_push(pts, Vector2(w - 1.0 - PANE_R, yt))
	_arc(pts, Vector2(w - 1.0 - PANE_R, yt + PANE_R), PANE_R, 1.5 * PI, 2.0 * PI)
	_arc(pts, Vector2(w - 1.0 - PANE_R, yb - PANE_R), PANE_R, 0.0, 0.5 * PI)
	_arc(pts, Vector2(1.0 + PANE_R, yb - PANE_R), PANE_R, 0.5 * PI, PI)
	return pts


func _draw() -> void:
	if size.x < 8.0 or size.y < tab_height:
		return
	var yt := tab_height
	var open := Rect2()
	if selected != "":
		open = tab_rect(selected)
	var open_x0 := open.position.x
	var open_x1 := open.end.x if open.size.x > 0.0 else open.position.x
	# Closed tabs first; the pane's rim runs over their feet.
	for t in _tabs:
		if t.key == selected:
			continue
		var r := tab_rect(t.key)
		var path := _tab_path(r.position.x, r.end.x, DROP, yt)
		var fill: Color = t.face_color()
		draw_colored_polygon(path, fill)
		UiSurface.draw_poly(self, path, grain_material, fill, GRAIN)
		draw_polygon(path, UiSurface.sheen_colors(path, Rect2(r.position.x, DROP, r.size.x, yt - DROP), 0.07 + 0.08 * t.glow))
		var edge := Color(t.accent.lerp(rim, 0.55), 0.95) if t.accent.a > 0.0 else Color(rim, 0.95)
		if t.disabled:
			edge = Color(rim, 0.4)
		if t.glow > 0.01:
			for g in [[9.0, 0.07], [6.0, 0.1], [3.5, 0.16]]:
				draw_polyline(path, Color(UIStyle.GOLD, float(g[1]) * t.glow), float(g[0]), true)
			edge = edge.lerp(UIStyle.GOLD_HI, t.glow)
		draw_polyline(path, Color(0, 0, 0, 0.4), RIM_W + 2.0, true)
		draw_polyline(path, edge, RIM_W, true)
		if not t.disabled and t.accent.a > 0.0:
			# A thin band of the tab's accent under the rim: the tab's colour code.
			var band := PackedVector2Array([Vector2(r.position.x + TAB_R, DROP + RIM_W + 1.0), Vector2(r.end.x - TAB_R, DROP + RIM_W + 1.0)])
			draw_polyline(band, Color(t.accent, 0.5), 1.0, true)
	# The pane and the open tab as one shape.
	var sil := _silhouette(open_x0, open_x1)
	var shadow := PackedVector2Array()
	for p in sil:
		shadow.append(p + Vector2(0, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	draw_colored_polygon(sil, pane_fill)
	UiSurface.draw_poly(self, sil, grain_material, pane_fill, GRAIN)
	if open.size.x > 0.0:
		var tp := _tab_path(open_x0, open_x1, 1.0, yt - FLARE)
		var lit := PackedVector2Array(tp)
		lit.append(Vector2(open_x1, yt))
		lit.append(Vector2(open_x0, yt))
		draw_polygon(lit, UiSurface.sheen_colors(lit, Rect2(open_x0, 1.0, open_x1 - open_x0, yt), 0.12))
	# Rim: a dark outer stroke, the rim colour, then (on the open tab) a gold inner line and glow.
	var closed := PackedVector2Array(sil)
	closed.append(sil[0])
	if open.size.x > 0.0:
		var t_open := tab(selected)
		var tp2 := _tab_path(open_x0, open_x1, 1.0, yt - FLARE)
		var glow_k: float = 1.0 if t_open == null else 0.55 + 0.45 * t_open.glow
		for g in [[10.0, 0.05], [7.0, 0.08], [4.5, 0.12]]:
			draw_polyline(tp2, Color(UIStyle.GOLD, float(g[1]) * glow_k), float(g[0]), true)
	draw_polyline(closed, Color(0, 0, 0, 0.45), RIM_W + 2.0, true)
	draw_polyline(closed, rim, RIM_W, true)
	if open.size.x > 0.0:
		var inner := _tab_path(open_x0 + 3.0, open_x1 - 3.0, 4.5, yt - FLARE)
		draw_polyline(inner, Color(UIStyle.GOLD, 0.75), 1.0, true)
	# A fine inner hairline along the pane's top, below the rim, gives the metal edge some depth.
	for span in top_border_spans(size.x, open_x0, open_x1):
		draw_line(Vector2(span[0], yt + 2.0), Vector2(span[1], yt + 2.0), Color(1, 0.9, 0.7, 0.08), 1.0)


## One folder tab: a flat button whose face FolderTabs draws; it holds the glyph, title and badge.
class Tab extends Button:
	## Key passed to `tab_selected`.
	var key: String = ""
	## Text shown on the tab.
	var title: String = ""
	## Rim accent (transparent: none, the tab takes the plain rim colour).
	var accent: Color = Color.TRANSPARENT
	## Hover glow 0..1 (eased).
	var glow: float = 0.0:
		set(v):
			glow = v
			if _owner != null and is_instance_valid(_owner):
				_owner.queue_redraw()
	var _owner: FolderTabs
	var _content: HBoxContainer
	var _label: Label
	var _badge: Control
	var _glyph: Control
	var _tw: Tween

	func _init(owner_tabs: FolderTabs, k: String, text_title: String, opts: Dictionary) -> void:
		_owner = owner_tabs
		key = k
		title = text_title
		accent = opts.get("accent", Color.TRANSPARENT)
		disabled = bool(opts.get("disabled", false))
		tooltip_text = String(opts.get("tooltip", ""))
		focus_mode = Control.FOCUS_NONE
		flat = true
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
		_content = HBoxContainer.new()
		_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_content.alignment = BoxContainer.ALIGNMENT_CENTER
		_content.add_theme_constant_override("separation", 9)
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_content)
		if opts.get("glyph") is Control:
			_glyph = opts["glyph"]
			_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_content.add_child(_glyph)
		_label = UIStyle.label(title, owner_tabs.font_size, UIStyle.MUTED, false, true)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_content.add_child(_label)
		if String(opts.get("badge", "")) != "":
			_badge = GameUi.pill(String(opts["badge"]), accent if accent.a > 0.0 else UIStyle.GOLD, 13)
			_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			GameUi.ignore_mouse(_badge)
			_content.add_child(_badge)
		# Measured from the fonts: a container outside the tree reports no minimum size yet.
		var gap := float(_content.get_theme_constant("separation"))
		var need := UIStyle.font_display(600).get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, owner_tabs.font_size).x + 36.0
		if _glyph != null:
			need += _glyph.custom_minimum_size.x + gap
		if _badge != null:
			need += UIStyle.font_body().get_string_size(String(opts["badge"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0 + gap
		custom_minimum_size = Vector2(maxf(float(opts.get("min_width", 0.0)), need), owner_tabs.tab_height)
		mouse_entered.connect(func(): _hover(true))
		mouse_exited.connect(func(): _hover(false))
		pressed.connect(func(): _owner.select(key))

	## The new text of the tab (the width follows).
	func set_title(t: String) -> void:
		title = t
		_label.text = t

	func _hover(on: bool) -> void:
		if disabled:
			return
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if UIStyle.reduce_motion or not is_inside_tree():
			glow = 1.0 if on else 0.0
			return
		_tw = create_tween()
		_tw.tween_property(self, "glow", 1.0 if on else 0.0, UIStyle.dur(0.14))

	## Fill of the tab face while closed (the accent, darkened, lit by hover).
	func face_color() -> Color:
		var base := Color(0.075, 0.062, 0.05, 0.97)
		if disabled:
			return Color(base.darkened(0.2), 0.8)
		if accent.a <= 0.0:
			return base.lerp(Color(0.14, 0.11, 0.075, 0.98), 0.6 * glow)
		return base.lerp(Color(accent.darkened(0.6), 0.97), 0.28 + 0.4 * glow)

	## Colours and offset for open or closed.
	func apply_state(open: bool) -> void:
		var col := UIStyle.GOLD_HI if open else (UIStyle.DISABLED if disabled else UIStyle.MUTED)
		_label.add_theme_color_override("font_color", col)
		_content.offset_top = 0.0 if open else FolderTabs.DROP * 0.6
		if open:
			_content.offset_top = -1.0
		mouse_default_cursor_shape = Control.CURSOR_ARROW if (disabled or open) else Control.CURSOR_POINTING_HAND
		if _owner != null:
			_owner.queue_redraw()
