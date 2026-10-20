class_name TitleText
extends Control
## Cinzel title with depth (D3, design/design-review-2026-10-20.md section 1.4.1): a vertical
## metal-gradient fill, an outline, up to two drop-shadow layers (hard bevel + soft), an outer glow,
## an optional engraved underline and a specular sweep. A Label cannot draw a gradient, so the
## layers are drawn here: shadows, glow and outline on this Control, the fill on a child layer with
## the `canvas_ui_title_fill` shader. Glyphs are rasterised at the drawn size (dynamic font; the
## project's canvas_items stretch oversamples them), so the title stays crisp at every size.
##
## Three ways in:
##   TitleText.make("RLDB", TitleText.Tier.HERO)        a new title Control
##   TitleText.apply(existing_label, TitleText.Tier.SECTION)
##       in-place restyle: the Label keeps its layout, text API and colour; a TitleText overlay
##       draws it (the Label's own glyphs are hidden with self_modulate).
##   TitleText.style_label(existing_label, tier)        Label-only fallback (outline + one hard
##       shadow, no gradient, glow or sweep) where a gradient isn't needed.
##
## Reduce motion (UIStyle.reduce_motion) removes the sweep only (the D3 acceptance rule).

## Title tiers. HERO_DEFEAT is the T1 ember palette; MENU is the ivory menu-item variant of T2.
enum Tier { HERO, HERO_DEFEAT, SCREEN, MENU, SECTION }

const SHADER := preload("res://assets/shaders/canvas_ui_title_fill.gdshader")
## Cinzel's cap height as a fraction of the font size, used when the glyph contours are unavailable.
const CAP_RATIO_FALLBACK := 0.70
## T1 specular sweep: one 0.9 s pass every 6 s (motion token `sweep`), 18% additive, a 30 deg band.
const SWEEP_PERIOD := 6.0
const SWEEP_DURATION := 0.9
const SWEEP_ALPHA := 0.18
const SWEEP_ANGLE_DEG := 30.0
## The band's half width as a fraction of the font size.
const SWEEP_HALF_WIDTH := 0.32
## Delay before the first pass of a looping sweep (so it is seen once the title has landed).
const SWEEP_FIRST_DELAY := 1.2
## Menu hover blend in / out (motion token `hover`).
const HOVER_IN := 0.12
const HOVER_OUT := 0.18
## Soft shadows and glows are stacked outlines: one layer per this many px of blur, capped.
const BLUR_STEP_PX := 2.0
const MAX_BLUR_LAYERS := 9
## Engraved underline (T3): gap below the text and the two 1 px lines.
const UNDERLINE_GAP := 5.0
const UNDERLINE_COLOR := Color(0.831, 0.651, 0.29, 0.45)
const UNDERLINE_SHADE := Color(0, 0, 0, 0.5)
## Sweep modes.
const SWEEP_NONE := "none"
const SWEEP_LOOP := "loop"
const SWEEP_ONCE := "once"


## Visual parameters of `tier` (pure data; the tiers table of design review 1.4.1). Keys:
## size, weight, spacing (extra px per glyph), stops + colors (fill gradient, top to bottom),
## hover_stops + hover_colors (the MENU hover gradient; the same as the fill otherwise), outline
## (px) + outline_color, shadows (Array of {offset, blur, color}, front layer first), glow (px) +
## glow_color, hover_glow (glow px shown only while hovered), sweep (SWEEP_*), underline (bool).
static func params(tier: int) -> Dictionary:
	var gold_stops := PackedFloat32Array([0.0, 0.45, 0.55, 1.0])
	var screen_stops := PackedFloat32Array([0.0, 0.5, 1.0])
	var screen_cols := PackedColorArray([Color("f6dc96"), Color("d4a64a"), Color("a97c34")])
	var screen_shadows := [
		{"offset": Vector2(0, 2), "blur": 0.0, "color": Color(0, 0, 0, 0.8)},
		{"offset": Vector2(0, 4), "blur": 8.0, "color": Color(0, 0, 0, 0.5)},
	]
	match tier:
		Tier.HERO, Tier.HERO_DEFEAT:
			var defeat := tier == Tier.HERO_DEFEAT
			var cols := PackedColorArray([Color("ffd0c4"), Color("e8605a"), Color("8e2a22"), Color("c4473d")]) if defeat \
				else PackedColorArray([Color("fff1c4"), Color("f0cf7a"), Color("b8862e"), Color("e2b75a")])
			return {
				"size": 88, "weight": 700, "spacing": 0,
				"stops": gold_stops, "colors": cols, "hover_stops": gold_stops, "hover_colors": cols,
				"outline": 2.0, "outline_color": Color("2a0806") if defeat else Color("2a1a08"),
				"shadows": [
					{"offset": Vector2(0, 3), "blur": 0.0, "color": Color(0, 0, 0, 0.85)},
					{"offset": Vector2(0, 8), "blur": 18.0, "color": Color(0, 0, 0, 0.6)},
				],
				"glow": 14.0, "glow_color": Color(Color("e8605a") if defeat else UIStyle.GOLD, 0.30), "hover_glow": 0.0,
				"sweep": SWEEP_LOOP, "underline": false,
			}
		Tier.SCREEN:
			return {
				"size": 36, "weight": 600, "spacing": 0,
				"stops": screen_stops, "colors": screen_cols, "hover_stops": screen_stops, "hover_colors": screen_cols,
				"outline": 1.0, "outline_color": Color("1a1208"),
				"shadows": screen_shadows,
				"glow": 0.0, "glow_color": Color(UIStyle.GOLD, 0.0), "hover_glow": 0.0,
				"sweep": SWEEP_ONCE, "underline": false,
			}
		Tier.MENU:
			var ivory := PackedColorArray([UIStyle.TEXT, UIStyle.TEXT])
			return {
				"size": 34, "weight": 500, "spacing": 0,
				"stops": PackedFloat32Array([0.0, 1.0]), "colors": ivory,
				"hover_stops": screen_stops, "hover_colors": screen_cols,
				"outline": 1.0, "outline_color": Color(0, 0, 0, 0.7),
				"shadows": screen_shadows,
				"glow": 0.0, "glow_color": Color(UIStyle.GOLD, 0.35), "hover_glow": 10.0,
				"sweep": SWEEP_NONE, "underline": false,
			}
		_:   # Tier.SECTION
			var gold := PackedColorArray([UIStyle.GOLD, UIStyle.GOLD])
			var flat_stops := PackedFloat32Array([0.0, 1.0])
			return {
				"size": 18, "weight": 700, "spacing": 2,
				"stops": flat_stops, "colors": gold, "hover_stops": flat_stops, "hover_colors": gold,
				"outline": 0.0, "outline_color": Color(0, 0, 0, 0),
				"shadows": [{"offset": Vector2(0, 1), "blur": 0.0, "color": Color(0, 0, 0, 0.9)}],
				"glow": 0.0, "glow_color": Color(UIStyle.GOLD, 0.0), "hover_glow": 0.0,
				"sweep": SWEEP_NONE, "underline": true,
			}


## Sweep progress (0..1) `elapsed` seconds after the sweep clock started, or -1 between passes.
## SWEEP_LOOP repeats a `duration` pass every `period`; SWEEP_ONCE plays one pass; SWEEP_NONE never.
static func sweep_phase(mode: String, elapsed: float, period: float = SWEEP_PERIOD, duration: float = SWEEP_DURATION) -> float:
	if mode == SWEEP_NONE or elapsed < 0.0 or duration <= 0.0:
		return -1.0
	var m := elapsed
	if mode == SWEEP_LOOP:
		m = fmod(elapsed, maxf(period, duration))
	return m / duration if m < duration else -1.0


## Alpha of one of `layers` stacked layers so that, where all of them overlap, the total is `alpha`.
static func layer_alpha(alpha: float, layers: int) -> float:
	if layers <= 1:
		return alpha
	return 1.0 - pow(1.0 - clampf(alpha, 0.0, 1.0), 1.0 / float(layers))


## Number of stacked layers used for a blur or glow of `px`.
static func blur_layers(px: float) -> int:
	return clampi(ceili(px / BLUR_STEP_PX), 1, MAX_BLUR_LAYERS)


## A new title showing `text` in `tier` (font size `size`, 0 = the tier's default size).
static func make(p_text: String, p_tier: int = Tier.SCREEN, size: int = 0) -> TitleText:
	var t := TitleText.new()
	t.tier = p_tier
	t.font_size = size
	t.text = p_text
	return t


## In-place restyle of `label` as a `tier` title (`size` 0 = keep the label's font size, or the
## tier's default when the label has none). The label keeps its layout, text, alignment, wrap and
## colour API: setting `label.text` or its "font_color" override later updates the title. Flat tiers
## (SECTION, MENU at rest) follow the label's font colour; gradient tiers ignore it. Calling it again
## re-tiers the existing overlay. Returns the overlay.
static func apply(label: Label, p_tier: int, size: int = 0) -> TitleText:
	var t: TitleText = label.get_meta(&"title_text") if label.has_meta(&"title_text") else null
	if t == null or not is_instance_valid(t):
		t = TitleText.new()
		t.name = "TitleText"
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.add_child(t, false, Node.INTERNAL_MODE_FRONT)
		label.set_meta(&"title_text", t)
		label.draw.connect(t._sync_from_label)
		label.resized.connect(t._sync_from_label)
	t._mirror = label
	t.tier = p_tier
	var p := params(p_tier)
	var fs := size
	if fs <= 0:
		fs = label.get_theme_font_size("font_size") if label.has_theme_font_size_override("font_size") else int(p["size"])
	t.font_size = fs
	label.add_theme_font_override("font", tier_font(p_tier))
	label.add_theme_font_size_override("font_size", fs)
	if _is_flat(p_tier):
		label.add_theme_color_override("font_color", (p["colors"] as PackedColorArray)[0])
	label.self_modulate = Color(1, 1, 1, 0)
	t._sync_from_label()
	t._reserve_underline()
	return t


## apply() + an underline: top-aligns the Label and grows its minimum height by the underline, so
## the rule sits inside the Label's rect (not over whatever is laid out below it). Call it again
## after toggling show_underline on an applied title.
func _reserve_underline() -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	var base: float = _mirror.get_meta(&"title_base_min_h", _mirror.custom_minimum_size.y)
	_mirror.set_meta(&"title_base_min_h", base)
	_layout()
	if underline_room() > 0.0:
		_mirror.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_mirror.custom_minimum_size.y = maxf(base, _natural.y)
	else:
		_mirror.custom_minimum_size.y = base


## Label-only fallback: the tier's font, its mid fill colour, outline and front (hard) shadow on
## the Label itself. No gradient, glow, sweep or underline. `size` 0 = the tier's default.
static func style_label(label: Label, p_tier: int, size: int = 0) -> void:
	var p := params(p_tier)
	var cols: PackedColorArray = p["colors"]
	label.add_theme_font_override("font", tier_font(p_tier))
	label.add_theme_font_size_override("font_size", size if size > 0 else int(p["size"]))
	label.add_theme_color_override("font_color", cols[cols.size() / 2] if cols.size() > 2 else cols[0])
	label.add_theme_color_override("font_outline_color", p["outline_color"])
	label.add_theme_constant_override("outline_size", roundi(float(p["outline"]) * 2.0))
	var sh: Dictionary = (p["shadows"] as Array)[0]
	label.add_theme_color_override("font_shadow_color", sh["color"])
	label.add_theme_constant_override("shadow_offset_x", roundi((sh["offset"] as Vector2).x))
	label.add_theme_constant_override("shadow_offset_y", roundi((sh["offset"] as Vector2).y))
	label.add_theme_constant_override("shadow_outline_size", roundi(float(p["outline"]) * 2.0))


## Cinzel at the tier's weight and glyph spacing (cached).
static func tier_font(p_tier: int) -> Font:
	var p := params(p_tier)
	var key := "%d_%d" % [int(p["weight"]), int(p["spacing"])]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(UIStyle.FONT_DISPLAY)
		fv.variation_opentype = {UIStyle.WGHT_TAG: int(p["weight"])}
		fv.spacing_glyph = int(p["spacing"])
		_fonts[key] = fv
	return _fonts[key]


## Cap height (px) of `font` at `size`, measured from the "H" glyph outline (cached per font).
static func cap_height(font: Font, size: int) -> float:
	var id := font.get_instance_id()
	if not _cap_ratio.has(id):
		var ratio := CAP_RATIO_FALLBACK
		var ts := TextServerManager.get_primary_interface()
		for rid in font.get_rids():
			var gi := ts.font_get_glyph_index(rid, 100, "H".unicode_at(0), 0)
			if gi == 0:
				continue
			var c: Dictionary = ts.font_get_glyph_contours(rid, 100, gi)
			var pts: PackedVector3Array = c.get("points", PackedVector3Array())
			var top := 0.0
			for q in pts:
				top = minf(top, q.y)
			if top < -1.0:
				ratio = -top / 100.0
				break
		_cap_ratio[id] = ratio
	return float(_cap_ratio[id]) * float(size)


static func _is_flat(p_tier: int) -> bool:
	return p_tier == Tier.SECTION or p_tier == Tier.MENU


static func _gradient_texture(stops: PackedFloat32Array, cols: PackedColorArray) -> GradientTexture1D:
	var key := str(stops) + str(cols)
	if not _grads.has(key):
		var g := Gradient.new()
		g.offsets = stops
		g.colors = cols
		var gt := GradientTexture1D.new()
		gt.gradient = g
		gt.width = 256
		_grads[key] = gt
	return _grads[key]


static var _fonts := {}
static var _grads := {}
static var _cap_ratio := {}


## The fill layer: draws the glyphs in white under the gradient shader.
class FillLayer extends Control:
	var owner_title: TitleText

	func _init(t: TitleText) -> void:
		owner_title = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		owner_title._draw_fill(self)


## Text shown. Setting it relayouts.
var text: String = "":
	set(v):
		if v == text:
			return
		text = v
		_relayout()
## Tier (Tier.*).
var tier: int = Tier.SCREEN:
	set(v):
		tier = v
		_p = params(v)
		_relayout()
		_restart_sweep()
## Font size in px (0 = the tier's default).
var font_size: int = 0:
	set(v):
		font_size = v
		_relayout()
var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(v):
		horizontal_alignment = v
		_relayout()
var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER:
	set(v):
		vertical_alignment = v
		_relayout()
## Word-wrap to the control's width (multi-line titles keep the gradient per line).
var autowrap: bool = false:
	set(v):
		autowrap = v
		_relayout()
## Trim with an ellipsis when wider than the control (single line).
var ellipsis: bool = false:
	set(v):
		ellipsis = v
		_relayout()
## Draw the text upper-cased.
var uppercase: bool = false:
	set(v):
		uppercase = v
		_relayout()
## Extra px between lines (a mirrored Label's "line_spacing" constant).
var line_spacing: float = 0.0:
	set(v):
		line_spacing = v
		_relayout()
## Shrink the font (down to `min_font_size`) until a single line fits the width.
var shrink_to_fit: bool = false:
	set(v):
		shrink_to_fit = v
		_relayout()
var min_font_size: int = 12
## T3 underline spans the whole control width (a panel-header rule) instead of the text width.
var underline_full_width: bool = true:
	set(v):
		underline_full_width = v
		queue_redraw()
## Draw the tier's engraved underline (T3). Off for inline names (player plates).
var show_underline: bool = true:
	set(v):
		show_underline = v
		_relayout()
		_reserve_underline()
## Flat fill colour replacing the tier's flat gradient (SECTION / MENU at rest); alpha 0 = none.
var fill_color: Color = Color(0, 0, 0, 0):
	set(v):
		fill_color = v
		_apply_material()
		queue_redraw()
## Menu hover blend 0..1 (MENU tier: ivory -> gold gradient and glow). Use set_hovered().
var hover: float = 0.0:
	set(v):
		hover = clampf(v, 0.0, 1.0)
		_apply_material()
		queue_redraw()
## Seconds clock for the sweep (tests inject a fake one).
var clock: Callable = func() -> float: return float(Time.get_ticks_usec()) / 1000000.0

var _p: Dictionary = params(Tier.SCREEN)
var _para := TextParagraph.new()
var _fill: FillLayer
var _mat := ShaderMaterial.new()
var _mirror: Label = null
var _dirty := true
var _fs := 0
var _cap := 0.0
var _line_h := 0.0
var _line_ascent := 0.0
var _natural := Vector2.ZERO
var _layout_w := -1.0
var _sweep_origin := -1.0
var _hover_tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat.shader = SHADER
	_fill = FillLayer.new(self)
	_fill.material = _mat
	add_child(_fill, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_on_resized)


func _ready() -> void:
	_restart_sweep()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_restart_sweep()


## Plays one sweep pass now (SCREEN titles call this when their panel opens; looping tiers restart).
## Does nothing under reduce motion or for tiers without a sweep.
func play_sweep() -> void:
	if UIStyle.reduce_motion or String(_p["sweep"]) == SWEEP_NONE:
		return
	_sweep_origin = float(clock.call())
	set_process(true)


## Menu hover: blends to the gold gradient and glow (120 ms in, 180 ms out; a plain fade, so it is
## also used under reduce motion). `instant` snaps.
func set_hovered(on: bool, instant: bool = false) -> void:
	if _hover_tw != null and _hover_tw.is_valid():
		_hover_tw.kill()
	var target := 1.0 if on else 0.0
	if instant or not is_inside_tree():
		hover = target
		return
	_hover_tw = create_tween()
	_hover_tw.tween_property(self, "hover", target, UIStyle.dur(HOVER_IN if on else HOVER_OUT)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The effective font size (after the tier default and shrink-to-fit).
func effective_font_size() -> int:
	_layout()
	return _fs


## Current sweep progress 0..1, or -1 between passes (reads the clock).
func current_sweep_phase() -> float:
	if _sweep_origin < 0.0 or UIStyle.reduce_motion:
		return -1.0
	var elapsed := float(clock.call()) - _sweep_origin
	return sweep_phase(String(_p["sweep"]), elapsed)


func _restart_sweep() -> void:
	if not is_inside_tree():
		return
	var mode := String(_p["sweep"])
	if UIStyle.reduce_motion or mode == SWEEP_NONE:
		_sweep_origin = -1.0
		set_process(false)
		_set_sweep(-1.0)
		return
	if mode == SWEEP_LOOP:
		_sweep_origin = float(clock.call()) + SWEEP_FIRST_DELAY
	else:
		_sweep_origin = float(clock.call())
	set_process(true)


func _process(_d: float) -> void:
	var ph := current_sweep_phase()
	_set_sweep(ph)
	var elapsed := float(clock.call()) - _sweep_origin
	if String(_p["sweep"]) == SWEEP_ONCE and elapsed >= SWEEP_DURATION:
		_set_sweep(-1.0)
		set_process(false)
	if UIStyle.reduce_motion:
		_set_sweep(-1.0)
		set_process(false)


func _set_sweep(ph: float) -> void:
	if ph < 0.0:
		_mat.set_shader_parameter("sweep_strength", 0.0)
		return
	_layout()
	var hw := float(_fs) * SWEEP_HALF_WIDTH
	var x0 := _text_left() - hw - _cap * tan(deg_to_rad(SWEEP_ANGLE_DEG))
	var x1 := _text_left() + _natural.x + hw + _cap * tan(deg_to_rad(SWEEP_ANGLE_DEG))
	_mat.set_shader_parameter("sweep_strength", SWEEP_ALPHA)
	_mat.set_shader_parameter("sweep_half_width", hw)
	_mat.set_shader_parameter("sweep_tilt", tan(deg_to_rad(SWEEP_ANGLE_DEG)))
	_mat.set_shader_parameter("sweep_x", lerpf(x0, x1, ease(ph, -1.8)))


func _relayout() -> void:
	_dirty = true
	update_minimum_size()
	queue_redraw()
	if _fill != null:
		_fill.queue_redraw()


func _on_resized() -> void:
	if autowrap or ellipsis or shrink_to_fit:
		_relayout()
	else:
		queue_redraw()
		_fill.queue_redraw()


func _shown_text() -> String:
	return text.to_upper() if uppercase else text


func _layout() -> void:
	# Width-dependent layouts redo themselves when the width changed (resized does not fire out of
	# the tree).
	if (autowrap or ellipsis or shrink_to_fit) and not is_equal_approx(_layout_w, size.x):
		_dirty = true
	if not _dirty:
		return
	_dirty = false
	_layout_w = size.x
	var font := tier_font(tier)
	_fs = font_size if font_size > 0 else int(_p["size"])
	var s := _shown_text()
	if shrink_to_fit and size.x > 1.0:
		while _fs > min_font_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x > size.x:
			_fs -= 1
	_para.clear()
	_para.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_para.break_flags = TextServer.BREAK_MANDATORY | (TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE if autowrap else 0)
	_para.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if ellipsis else TextServer.OVERRUN_NO_TRIMMING
	_para.max_lines_visible = 1 if ellipsis and not autowrap else -1
	_para.width = size.x if (autowrap or ellipsis) and size.x > 1.0 else -1.0
	_para.add_string(s, font, _fs)
	_cap = cap_height(font, _fs)
	_line_ascent = font.get_ascent(_fs)
	_line_h = font.get_height(_fs)
	var w := 0.0
	for i in _para.get_line_count():
		w = maxf(w, _para.get_line_width(i))
	_natural = Vector2(w, _content_height())
	_apply_material()


func _visible_lines() -> int:
	var n := _para.get_line_count()
	return mini(n, 1) if ellipsis and not autowrap else n


func _content_height() -> float:
	var n := maxi(1, _visible_lines())
	var h := float(n) * _line_h + float(n - 1) * line_spacing
	if _has_underline():
		h += UNDERLINE_GAP + 2.0
	return h


func _has_underline() -> bool:
	return bool(_p["underline"]) and show_underline


## Px the underline adds below the text (0 without one): apply() reserves it in the Label.
func underline_room() -> float:
	return UNDERLINE_GAP + 2.0 if _has_underline() else 0.0


func _get_minimum_size() -> Vector2:
	if _mirror != null:
		return Vector2.ZERO   # the Label owns the layout
	_layout()
	var w := 0.0 if (autowrap or ellipsis or shrink_to_fit) else ceilf(_natural.x)
	return Vector2(w, ceilf(_natural.y))


func _top() -> float:
	match vertical_alignment:
		VERTICAL_ALIGNMENT_TOP:
			return 0.0
		VERTICAL_ALIGNMENT_BOTTOM:
			return size.y - _natural.y
	return floorf((size.y - _natural.y) / 2.0)


func _line_x(i: int) -> float:
	var lw := _para.get_line_width(i)
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return floorf((size.x - lw) / 2.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			return size.x - lw
	return 0.0


func _text_left() -> float:
	var x := INF
	for i in _visible_lines():
		x = minf(x, _line_x(i))
	return 0.0 if x == INF else x


func _line_pos(i: int) -> Vector2:
	return Vector2(_line_x(i), _top() + float(i) * (_line_h + line_spacing))


func _apply_material() -> void:
	if _mat == null:
		return
	var cols: PackedColorArray = _p["colors"]
	var stops: PackedFloat32Array = _p["stops"]
	if fill_color.a > 0.0 and _is_flat(tier):
		cols = PackedColorArray([fill_color, fill_color])
		stops = PackedFloat32Array([0.0, 1.0])
	_mat.set_shader_parameter("gradient_a", _gradient_texture(stops, cols))
	_mat.set_shader_parameter("gradient_b", _gradient_texture(_p["hover_stops"], _p["hover_colors"]))
	_mat.set_shader_parameter("gradient_mix", hover if tier == Tier.MENU else 0.0)
	_mat.set_shader_parameter("cap_top", _top() + _line_ascent - _cap)
	_mat.set_shader_parameter("cap_height", maxf(1.0, _cap))
	_mat.set_shader_parameter("line_pitch", maxf(1.0, _line_h + line_spacing))


## Draws every visible line of the paragraph at `offset`: an outline of `radius` px (0 = the glyphs
## only) in `col`.
func _draw_layer(ci: RID, offset: Vector2, radius: int, col: Color) -> void:
	for i in _visible_lines():
		var pos := _line_pos(i) + offset
		if radius > 0:
			_para.draw_line_outline(ci, pos, i, radius * 2, col)
		_para.draw_line(ci, pos, i, col)


## A soft layer (blur / glow): stacked outlines up to `px`, totalling `col.a` where they overlap.
func _draw_soft(ci: RID, offset: Vector2, base_radius: float, px: float, col: Color) -> void:
	var n := blur_layers(px)
	var a := layer_alpha(col.a, n + 1)
	var c := Color(col, a)
	for k in range(n, -1, -1):
		var r := roundi(base_radius + px * float(k) / float(n))
		_draw_layer(ci, offset, r, c)


func _draw() -> void:
	_layout()
	if _shown_text().is_empty():
		return
	var ci := get_canvas_item()
	var outline := float(_p["outline"])
	var shadows: Array = _p["shadows"]
	# Back to front: the soft (rear) shadows, the glow, the hard shadows, then the outline.
	for k in range(shadows.size() - 1, -1, -1):
		var sh: Dictionary = shadows[k]
		var blur := float(sh["blur"])
		if blur > 0.0:
			_draw_soft(ci, sh["offset"], outline, blur, sh["color"])
	var glow := float(_p["glow"]) + float(_p["hover_glow"]) * hover
	var gcol: Color = _p["glow_color"]
	if tier == Tier.MENU:
		gcol.a *= hover
	if glow > 0.0 and gcol.a > 0.001:
		_draw_soft(ci, Vector2.ZERO, outline, glow, gcol)
	for k in range(shadows.size() - 1, -1, -1):
		var sh: Dictionary = shadows[k]
		if float(sh["blur"]) <= 0.0:
			_draw_layer(ci, sh["offset"], roundi(outline), sh["color"])
	if outline > 0.0:
		for i in _visible_lines():
			_para.draw_line_outline(ci, _line_pos(i), i, roundi(outline * 2.0), _p["outline_color"])
	if _has_underline():
		var y := _top() + _natural.y - 2.0
		var x0 := 0.0 if underline_full_width else _text_left()
		var x1 := size.x if underline_full_width else _text_left() + _natural.x
		var ucol := UNDERLINE_COLOR if fill_color.a <= 0.0 else Color(fill_color, UNDERLINE_COLOR.a)
		draw_line(Vector2(x0, y + 0.5), Vector2(x1, y + 0.5), ucol, 1.0)
		draw_line(Vector2(x0, y + 1.5), Vector2(x1, y + 1.5), UNDERLINE_SHADE, 1.0)


## Fill layer draw (called from FillLayer._draw): the glyphs in white; the shader colours them.
func _draw_fill(layer: Control) -> void:
	_layout()
	if _shown_text().is_empty():
		return
	_apply_material()
	var ci := layer.get_canvas_item()
	for i in _visible_lines():
		_para.draw_line(ci, _line_pos(i), i, Color.WHITE)


## Copies the mirrored Label's text, alignment, wrap, spacing and (flat tiers) colour.
func _sync_from_label() -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	var l := _mirror
	# Only assign what changed: every setter relayouts, and this runs on each Label redraw.
	if horizontal_alignment != l.horizontal_alignment:
		horizontal_alignment = l.horizontal_alignment
	if vertical_alignment != l.vertical_alignment:
		vertical_alignment = l.vertical_alignment
	var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF
	if autowrap != wrap:
		autowrap = wrap
	var trim := l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if ellipsis != trim:
		ellipsis = trim
	if uppercase != l.uppercase:
		uppercase = l.uppercase
	var ls := float(l.get_theme_constant("line_spacing"))
	if not is_equal_approx(line_spacing, ls):
		line_spacing = ls
	if l.has_theme_font_size_override("font_size") and font_size != l.get_theme_font_size("font_size"):
		font_size = l.get_theme_font_size("font_size")
	if _is_flat(tier):
		var c := l.get_theme_color("font_color")
		if c != fill_color:
			fill_color = c
	text = l.text
