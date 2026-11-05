class_name SettingsForm
extends VBoxContainer
## The one settings form of the game (design review #9-#12, D5): the main menu's Settings panel and
## the in-game Interface settings are both built here, so they match exactly. A two-column grid (a
## 160 px label column, a 280 px control column, 12 px between them) at a fixed 44 px row pitch,
## grouped under SECTION headers:
##   Display    window mode and anti-aliasing (200x32 dropdowns)
##   Sound      music and effects volume: a 6 px inset track with a gold fill, an 18 px gem knob
##              that glows on hover, a soft tick every 10%, and a 24 px speaker toggle for mute
##   Interface  reduced motion, fast animations, the custom cursor (L22), any `extra` toggles of the caller, then the
##              statistics-sharing toggle with its explanation (12 px MUTED, line height 1.35,
##              aligned with the toggle's label)
## Toggles are full-width rows (HouseCheck): a 20 px bronze-bevel box whose tick draws on in 80 ms,
## a 6% gold row highlight on hover, and the toggle_on / toggle_off latch (Sfx's button hook).
## Values are read from and written through UIStyle, Music, Sfx and Telemetry; nothing else is kept.
##
##     var form := SettingsForm.new(func(on): screen.fx.finish_all())   # in game
##     panel.body.add_child(form)

const LABEL_W := 160.0
const CONTROL_W := 280.0
const COL_GAP := 12
const ROW_H := 44.0
const DROPDOWN := Vector2(200, 32)
const SLIDER_W := 228.0
const SPEAKER_PX := 24.0
const FONT := 16
## Indent of a toggle's explanation (lines it up with the toggle's label: box 20 + gap 12).
const NOTE_INDENT := 32
const NOTE_FONT := 12
## Line height 1.35 at 12 px.
const NOTE_LINE_SPACING := 4
## Volume steps that play a tick while dragging (10%).
const TICK_STEP := 0.1

## The controls by key (window_mode, aa, music, music_mute, sfx, sfx_mute, reduce_motion,
## fast_anim, custom_cursor, share, and the keys of `extra`), for drivers and tests.
var controls: Dictionary = {}

var _on_reduce_motion: Callable


## `on_reduce_motion(on)` runs after the reduced-motion option is saved (the game screen settles its
## effects). `extra`: more Interface toggles, each {key, text, on, toggled: Callable(bool)}.
func _init(on_reduce_motion: Callable = Callable(), extra: Array = []) -> void:
	name = "SettingsForm"
	_on_reduce_motion = on_reduce_motion
	UIStyle.load_settings()
	Sfx.load_settings()
	add_theme_constant_override("separation", 0)
	_section("Display", false)
	var ob := _dropdown(UIStyle.WINDOW_MODES, func(e): return e[0] == UIStyle.window_mode)
	ob.item_selected.connect(func(i): UIStyle.set_window_mode(UIStyle.WINDOW_MODES[i][0]))
	_row("Display", ob, "window_mode")
	var ab := _dropdown(UIStyle.AA_LEVELS, func(e): return int(e[0]) == UIStyle.aa_level)
	ab.item_selected.connect(func(i): UIStyle.set_aa_level(int(UIStyle.AA_LEVELS[i][0])))
	_row("Anti-aliasing", ab, "aa")
	_section("Sound")
	_volume_row("Music volume", "music", Music.get_volume(), Music.is_muted(), Music.set_volume, Music.set_muted)
	_volume_row("Sound effects", "sfx", Sfx.get_volume(), Sfx.is_muted(), Sfx.set_volume, Sfx.set_muted)
	_section("Interface")
	_toggle("reduce_motion", "Reduced motion (no travel, shake or particles)", UIStyle.reduce_motion, func(on):
		UIStyle.set_reduce_motion(on)
		if _on_reduce_motion.is_valid():
			_on_reduce_motion.call(on))
	_toggle("fast_anim", "Fast animations (half duration)", UIStyle.fast_anim, func(on): UIStyle.set_fast_anim(on))
	_toggle("custom_cursor", "Custom cursor (off: the system pointer)", CursorSkin.is_enabled(), func(on): CursorSkin.set_enabled(on))   # L22
	for e in extra:
		_toggle(String(e["key"]), String(e["text"]), bool(e["on"]), e["toggled"])
	_toggle("share", "Share anonymous gameplay statistics", Telemetry.share_enabled(), func(on): Telemetry.set_share_enabled(on))
	var note := UIStyle.label(Telemetry.PRIVACY_NOTE, NOTE_FONT, UIStyle.MUTED, true)
	note.name = "ShareNote"
	note.add_theme_constant_override("line_spacing", NOTE_LINE_SPACING)
	note.custom_minimum_size = Vector2(LABEL_W + COL_GAP + CONTROL_W - NOTE_INDENT, 0)
	var nm := MarginContainer.new()
	nm.add_theme_constant_override("margin_left", NOTE_INDENT)
	nm.add_theme_constant_override("margin_top", 0)
	nm.add_theme_constant_override("margin_bottom", UIStyle.sp("xs"))
	nm.add_child(note)
	add_child(nm)


## Total width of the form's grid.
static func form_width() -> float:
	return LABEL_W + COL_GAP + CONTROL_W


func _section(text: String, gap_above: bool = true) -> void:
	if gap_above:
		var g := Control.new()
		g.custom_minimum_size = Vector2(0, UIStyle.sp("md"))
		add_child(g)
	var l := UIStyle.label(text.to_upper(), 15, UIStyle.GOLD)
	l.name = "Section_" + text
	add_child(l)
	TitleText.apply(l, TitleText.Tier.SECTION, 15)
	var g2 := Control.new()
	g2.custom_minimum_size = Vector2(0, UIStyle.sp("xs"))
	add_child(g2)


func _row(text: String, ctl: Control, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + key
	row.custom_minimum_size = Vector2(form_width(), ROW_H)
	row.add_theme_constant_override("separation", COL_GAP)
	var l := UIStyle.label(text, FONT, UIStyle.TEXT)
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var cell := HBoxContainer.new()
	cell.custom_minimum_size = Vector2(CONTROL_W, 0)
	cell.add_theme_constant_override("separation", COL_GAP)
	cell.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(cell)
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(ctl)
	controls[key] = ctl
	add_child(row)
	return row


func _dropdown(items: Array, is_current: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = DROPDOWN
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 15)
	for i in items.size():
		ob.add_item(String(items[i][1]), i)
		if is_current.call(items[i]):
			ob.select(i)
	style_dropdown(ob)
	return ob


## The house dropdown: an F3 ink well with a bronze edge that turns gold on hover, 12 px text inset.
static func style_dropdown(ob: OptionButton) -> void:
	var n := UIStyle.flat(UIStyle.PANEL_INK, Color(UIStyle.BRONZE, 0.9), 1, 6)
	var h := UIStyle.flat(UIStyle.PANEL_INK.lightened(0.04), Color(UIStyle.GOLD, 0.95), 1, 6)
	var p := UIStyle.flat(UIStyle.PANEL_INK.darkened(0.2), UIStyle.GOLD_HI, 1, 6)
	for sb in [n, h, p]:
		sb.content_margin_left = UIStyle.sp("md")
		sb.content_margin_right = UIStyle.sp("md")
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.border_width_top = 1
	UIStyle.lift_style(n, Color(0, 0, 0, 0.45), 4, 1)
	UIStyle.lift_style(h, Color(UIStyle.GOLD, 0.25), 6, 0)
	for st in ["normal", "focus"]:
		ob.add_theme_stylebox_override(st, n)
	ob.add_theme_stylebox_override("hover", h)
	ob.add_theme_stylebox_override("pressed", p)
	ob.add_theme_stylebox_override("hover_pressed", p)
	ob.add_theme_font_size_override("font_size", 15)
	ob.add_theme_color_override("font_color", UIStyle.TEXT)
	ob.add_theme_color_override("font_hover_color", UIStyle.GOLD_HI)
	ob.add_theme_color_override("font_pressed_color", UIStyle.GOLD_HI)
	ob.add_theme_color_override("font_focus_color", UIStyle.TEXT)


func _volume_row(text: String, key: String, value: float, muted: bool, set_volume: Callable, set_muted: Callable) -> void:
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(SLIDER_W, 24)
	sl.focus_mode = Control.FOCUS_NONE
	style_slider(sl)
	var last_tick := [int(floor(value / TICK_STEP + 0.001))]
	sl.value_changed.connect(func(v: float):
		set_volume.call(v)
		var t := int(floor(v / TICK_STEP + 0.001))
		if t != last_tick[0]:
			last_tick[0] = t
			Sfx.hover_at(Time.get_ticks_msec()))
	if key == "sfx":
		sl.drag_ended.connect(func(_c): Sfx.play("select"))
	var row := _row(text, sl, key)
	var sp := SpeakerToggle.new(muted)
	sp.tooltip_text = "Mute %s" % text.to_lower().replace(" volume", "")
	sp.toggled.connect(func(on: bool):
		set_muted.call(on)
		Sfx.play("toggle_on" if on else "toggle_off"))
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(row.get_child(1) as HBoxContainer).add_child(sp)
	controls[key + "_mute"] = sp


## The house volume slider: a 6 px inset ink track, a gold fill up to the knob and an 18 px gold gem
## knob that brightens on hover.
static func style_slider(sl: HSlider) -> void:
	var track := UIStyle.flat(Color(0.02, 0.016, 0.012, 0.95), Color(0, 0, 0, 0.7), 1, 3)
	track.border_width_bottom = 0
	track.border_width_left = 0
	track.border_width_right = 0
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := UIStyle.flat(UIStyle.GOLD, Color(UIStyle.GOLD_HI, 0.8), 0, 3)
	fill.border_width_top = 1
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	var fill_hi := UIStyle.flat(UIStyle.GOLD_HI, Color.WHITE, 0, 3)
	fill_hi.border_width_top = 1
	fill_hi.content_margin_top = 3
	fill_hi.content_margin_bottom = 3
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	sl.add_theme_icon_override("grabber", gem_knob(false))
	sl.add_theme_icon_override("grabber_highlight", gem_knob(true))
	sl.add_theme_icon_override("grabber_disabled", gem_knob(false))


static var _knobs := {}


## The 18 px gold gem knob (drawn at 4x and downsampled; `lit` adds a soft glow). Cached.
static func gem_knob(lit: bool) -> ImageTexture:
	if _knobs.has(lit):
		return _knobs[lit]
	var px := 22
	var n := px * 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n, n) / 2.0
	var r := 18.0 * 4.0 / 2.0
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			if d > r + 10.0:
				continue
			if d > r:
				if lit:
					var a := 0.45 * (1.0 - (d - r) / 10.0)
					img.set_pixel(x, y, Color(UIStyle.GOLD_HI, a))
				continue
			if d > r - 5.0:
				img.set_pixel(x, y, Color("2a1a08"))
				continue
			# Faceted face: light from above-left, a darker lower-right, a white glint.
			var k := clampf(((p - c).dot(Vector2(-0.6, -0.8)) / r + 1.0) / 2.0, 0.0, 1.0)
			var col := Color("9a6416").lerp(Color("f2c25a"), k).lerp(Color("fff1b0"), maxf(0.0, k - 0.75) * 2.5)
			if lit:
				col = col.lightened(0.12)
			if p.distance_to(c + Vector2(-r * 0.35, -r * 0.4)) < r * 0.22:
				col = col.lerp(Color.WHITE, 0.7)
			img.set_pixel(x, y, col)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	_knobs[lit] = ImageTexture.create_from_image(img)
	return _knobs[lit]


func _toggle(key: String, text: String, on: bool, toggled: Callable) -> HouseCheck:
	var cb := HouseCheck.new(text, on)
	cb.name = "Toggle_" + key
	cb.custom_minimum_size = Vector2(form_width(), 40)
	cb.toggled.connect(toggled)
	add_child(cb)
	controls[key] = cb
	return cb


## A settings toggle row: a CheckBox (so it keeps the toggle_on / toggle_off click and every
## CheckBox API) drawn as a 20 px bronze-bevel box with a tick that draws on in 80 ms, the label
## 12 px to its right, and a 6% gold highlight across the row on hover.
class HouseCheck extends CheckBox:
	const BOX := 20.0
	## Tick drawn 0..1 (animated).
	var tick: float = 0.0:
		set(v):
			tick = v
			queue_redraw()
	var _tw: Tween

	func _init(t: String = "", on: bool = false) -> void:
		text = t
		button_pressed = on
		tick = 1.0 if on else 0.0
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_font_size_override("font_size", FONT)
		var blank := ImageTexture.create_from_image(Image.create(int(BOX), int(BOX), false, Image.FORMAT_RGBA8))
		for ic in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
			add_theme_icon_override(ic, blank)
		add_theme_constant_override("h_separation", UIStyle.sp("md"))
		for st in ["normal", "pressed", "focus", "disabled"]:
			var e := StyleBoxEmpty.new()
			e.content_margin_left = 0
			e.content_margin_right = UIStyle.sp("sm")
			add_theme_stylebox_override(st, e)
		for st in ["hover", "hover_pressed"]:
			var h := UIStyle.flat(Color(UIStyle.GOLD, 0.06), Color(0, 0, 0, 0), 0, 6)
			h.content_margin_left = 0
			h.content_margin_right = UIStyle.sp("sm")
			h.expand_margin_left = 6
			add_theme_stylebox_override(st, h)
		add_theme_color_override("font_color", UIStyle.TEXT)
		add_theme_color_override("font_pressed_color", UIStyle.TEXT)
		add_theme_color_override("font_hover_color", UIStyle.GOLD_HI)
		add_theme_color_override("font_hover_pressed_color", UIStyle.GOLD_HI)
		add_theme_color_override("font_focus_color", UIStyle.TEXT)
		toggled.connect(_on_toggled)

	func _on_toggled(on: bool) -> void:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if UIStyle.reduce_motion or not is_inside_tree():
			tick = 1.0 if on else 0.0
			return
		_tw = create_tween()
		UIStyle.tween_token(_tw, self, "tick", 1.0 if on else 0.0, "tick")

	func _draw() -> void:
		var r := Rect2(Vector2(0, (size.y - BOX) / 2.0).round(), Vector2(BOX, BOX))
		var hov := is_hovered()
		# Bevel: dark socket, bronze rim (gold on hover), a light top edge.
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6), true)
		draw_rect(r, UIStyle.PANEL_INK, true)
		draw_rect(r, (UIStyle.GOLD if hov or button_pressed else UIStyle.BRONZE.lightened(0.15)), false, 1.5)
		draw_line(r.position + Vector2(2, 1.5), Vector2(r.end.x - 2, r.position.y + 1.5), Color(1, 1, 1, 0.08), 1.0)
		if tick > 0.0:
			draw_rect(r.grow(-3.0), Color(UIStyle.GOLD, 0.16 * tick), true)
			var a := r.position + Vector2(4.5, 10.5)
			var m := r.position + Vector2(8.5, 14.5)
			var b := r.position + Vector2(15.5, 5.5)
			var l1 := a.distance_to(m)
			var l2 := m.distance_to(b)
			var len := (l1 + l2) * tick
			var col := UIStyle.GOLD_HI
			if len <= l1:
				draw_line(a, a.lerp(m, len / l1), col, 2.6, true)
			else:
				draw_line(a, m, col, 2.6, true)
				draw_line(m, m.lerp(b, (len - l1) / l2), col, 2.6, true)


## Mute toggle: a 24 px speaker with sound waves, struck through (and dimmed) while muted.
class SpeakerToggle extends Button:
	func _init(muted: bool = false) -> void:
		toggle_mode = true
		button_pressed = muted
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(SPEAKER_PX + 8.0, SPEAKER_PX + 8.0)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta(Sfx.BUTTON_META, "none")   # the toggled handler plays the latch
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		toggled.connect(func(_on): queue_redraw())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		var s := SPEAKER_PX
		var hov := is_hovered()
		var muted := button_pressed
		var col := UIStyle.GOLD_HI if hov else (UIStyle.TEXT_DIM if muted else UIStyle.GOLD)
		if hov:
			draw_circle(c, s * 0.62, Color(UIStyle.GOLD, 0.12), true, -1.0, true)
		var x0 := c.x - s * 0.42
		var body := PackedVector2Array([Vector2(x0, c.y - s * 0.14), Vector2(x0 + s * 0.2, c.y - s * 0.14),
			Vector2(x0 + s * 0.44, c.y - s * 0.36), Vector2(x0 + s * 0.44, c.y + s * 0.36),
			Vector2(x0 + s * 0.2, c.y + s * 0.14), Vector2(x0, c.y + s * 0.14)])
		draw_colored_polygon(body, col)
		if muted:
			var a := Vector2(c.x + s * 0.12, c.y - s * 0.16)
			draw_line(a, a + Vector2(s * 0.3, s * 0.32), UIStyle.BAD, 2.2, true)
			draw_line(a + Vector2(0, s * 0.32), a + Vector2(s * 0.3, 0), UIStyle.BAD, 2.2, true)
		else:
			var o := Vector2(x0 + s * 0.44, c.y)
			draw_arc(o, s * 0.2, -0.9, 0.9, 10, col, 1.8, true)
			draw_arc(o, s * 0.36, -0.9, 0.9, 12, Color(col, col.a * 0.7), 1.8, true)
