class_name SacrificeVignette
extends Control
## L5 sacrifice mode's screen-edge burn: the window's edges smoulder blood-red into ember, licked by
## slow flame tongues and a few rising sparks, breathing on a slow pulse, while the middle of the
## board stays clear; a hint pill at the top of the board says what the mode does and how to leave
## it. Over the board and the lifted cards, under the targeting arrow and the effects. Click-through.
## Fades in and out. Under reduced motion the burn is still (no pulse, flicker or sparks).

## Fade in / out (s).
const FADE_IN := 0.3
const FADE_OUT := 0.25
## The hint pill's text, size (px) and its top margin under the top strip.
const HINT_TITLE := "Sacrifice mode"
const HINT := "Click a glowing unit to sacrifice it (+1 AP)"
const HINT_PX := 15
## In the top strip, clear of the opponent's Trap row.
const HINT_TOP := 7.0

const SHADER_CODE := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1600.0, 1000.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float motion = 1.0;
uniform vec4 blood : source_color = vec4(0.36, 0.015, 0.03, 1.0);
uniform vec4 ember : source_color = vec4(1.0, 0.33, 0.07, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.8, 0.45, 1.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
// Gradient noise (smooth, not grid-blocky), about 0..1.
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a0 = hash(i) * 6.2831853;
	float a1 = hash(i + vec2(1.0, 0.0)) * 6.2831853;
	float a2 = hash(i + vec2(0.0, 1.0)) * 6.2831853;
	float a3 = hash(i + vec2(1.0, 1.0)) * 6.2831853;
	float v0 = dot(vec2(cos(a0), sin(a0)), f);
	float v1 = dot(vec2(cos(a1), sin(a1)), f - vec2(1.0, 0.0));
	float v2 = dot(vec2(cos(a2), sin(a2)), f - vec2(0.0, 1.0));
	float v3 = dot(vec2(cos(a3), sin(a3)), f - vec2(1.0, 1.0));
	return 0.5 + 0.7 * mix(mix(v0, v1, u.x), mix(v2, v3, u.x), u.y);
}
// Octaves rotated against each other, so no axis shows through.
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) { v += a * gnoise(p); p = r * p * 2.03 + vec2(17.0, 9.0); a *= 0.5; }
	return v / 0.9375;
}

void fragment() {
	vec2 px = UV * rect_size;
	float t = mod(TIME, 600.0) * motion;
	vec2 d2 = min(px, rect_size - px);
	float d = min(d2.x, d2.y);
	// The corners smoulder a little deeper.
	float corner = length(max(vec2(170.0) - d2, vec2(0.0)));
	float pulse = 0.5 + 0.5 * sin(t * 6.2831853 * 0.55);
	// Slow flicker of the burn's reach, and flame tongues rising up the screen (screen space, seamless).
	float flick = fbm(px * 0.006 + vec2(0.0, t * 0.22));
	float reach = 50.0 + 22.0 * pulse * motion + 46.0 * flick + corner * 0.3;
	float g = exp(-d / reach * 2.1);
	float tongues = smoothstep(0.5, 0.82, fbm(px * 0.013 + vec2(0.0, t * 0.9))) * exp(-d / 90.0);
	// A few sparks rising near the edges.
	vec2 sp = px / 26.0 + vec2(0.0, t * 1.3);
	vec2 cell = floor(sp);
	vec2 off = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
	float spark = smoothstep(0.14, 0.0, length(fract(sp) - 0.5 - off * 0.6)) * step(0.87, hash(cell + 1.7)) * exp(-d / 70.0) * motion;
	float heat = clamp(g * 0.9 + tongues * 0.55, 0.0, 1.0);
	vec3 col = mix(blood.rgb, ember.rgb, smoothstep(0.3, 0.9, heat));
	col = mix(col, core.rgb, smoothstep(0.88, 1.0, heat) * 0.55);
	col = mix(col, core.rgb, spark);
	float alpha = (heat * (0.6 + 0.2 * pulse) + spark * 0.8) * strength;
	COLOR = vec4(col, clamp(alpha, 0.0, 0.92));
}
"""

static var _shader: Shader

## The burn layer (the shader) and the hint pill.
var burn: ColorRect
var hint: HintPill
## Shader strength (tweened by the fade).
var strength: float = 0.0:
	set(v):
		strength = v
		if burn != null:
			(burn.material as ShaderMaterial).set_shader_parameter("strength", v)
		if hint != null:
			hint.modulate.a = v
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = UiLayers.ARROW - 1
	visible = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	burn = ColorRect.new()
	burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	burn.material = mat
	add_child(burn)
	hint = HintPill.new()
	add_child(hint)
	resized.connect(_place)


## Shows (fading in) or hides (fading out) the burn; `instant` skips the fade.
func set_on(on: bool, instant: bool = false) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	(burn.material as ShaderMaterial).set_shader_parameter("motion", 0.0 if UIStyle.reduce_motion else 1.0)
	if instant or not is_inside_tree():
		strength = 1.0 if on else 0.0
		visible = on
		_place()
		return
	if on:
		visible = true
		_place()
		_tw = create_tween()
		_tw.tween_property(self, "strength", 1.0, UIStyle.dur(FADE_IN))
	else:
		_tw = create_tween()
		_tw.tween_property(self, "strength", 0.0, UIStyle.dur(FADE_OUT))
		_tw.tween_callback(func(): visible = false)


## True while it is shown (or fading in).
func is_on() -> bool:
	return visible and (strength > 0.0 or (_tw != null and _tw.is_valid()))


func _place() -> void:
	(burn.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	var gs := get_parent() as GameScreen
	var area := gs.play_area if gs != null else Rect2(Vector2.ZERO, size)
	hint.reset_size()
	hint.position = Vector2(area.position.x + (area.size.x - hint.size.x) / 2.0, HINT_TOP).round()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_place()


## The hint pill: an ember-rimmed dark plate with a small flame, Cinzel text.
class HintPill extends PanelContainer:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := UIStyle.flat(Color(0.09, 0.03, 0.025, 0.92), Color(GameSacrificeMode.EMBER, 0.85), 1, 14)
		sb.content_margin_left = 34
		sb.content_margin_right = 16
		sb.content_margin_top = 5
		sb.content_margin_bottom = 6
		sb.shadow_color = Color(GameSacrificeMode.EMBER, 0.28)
		sb.shadow_size = 10
		add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var title := UIStyle.label(SacrificeVignette.HINT_TITLE.to_upper(), SacrificeVignette.HINT_PX, Color("ffb07a"), false, true)
		title.add_theme_font_override("font", UIStyle.font_display(700))
		var l := UIStyle.label(SacrificeVignette.HINT, SacrificeVignette.HINT_PX, Color("ffe6d6"))
		l.add_theme_font_override("font", UIStyle.font_bold())
		for x in [title, l]:
			(x as Label).add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			(x as Label).add_theme_constant_override("outline_size", 3)
			(x as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(x)

	func _draw() -> void:
		# A small flame at the left (the Sacrifice button's glyph).
		var c := Vector2(19.0, size.y / 2.0)
		var s := 7.0
		draw_circle(c, 10.0, Color(0, 0, 0, 0.5), true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.6, s * 0.45),
			c + Vector2(0, s), c + Vector2(-s * 0.6, s * 0.45), c + Vector2(-s * 0.4, -s * 0.2)]), GameSacrificeMode.EMBER)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.2), c + Vector2(s * 0.3, s * 0.3), c + Vector2(0, s * 0.75),
			c + Vector2(-s * 0.3, s * 0.3)]), Color("ffd27a"))
