// canvas_fx_shockwave: RLDB technical art, release batch 2026-10-20 (D8 / B5 / D6 set pieces).
// Purpose: screen-space refraction for the summon and Serpent set pieces. A shockwave ring expands from
// `centre` and bends what is behind it, and an optional swirl twists the board into a vortex (Fusion).
// It is drawn on one full-screen, click-through ColorRect (FxPlayer.distort) for under a second.
// Pipeline: canvas_item on Forward+ (desktop) and Compatibility. Budget: 1 screen-texture sample and
// about 30 ALU ops per pixel, no loops and no dynamic branches. Only one instance is live at a time.
// Fallback: reduced motion never creates the rect (no distortion at all).
shader_type canvas_item;

// Ring crest shape: exp(-x^2 * CREST_SHARPNESS) with x = distance from the crest in ring widths.
const float CREST_SHARPNESS = 2.2;
// Guards against division by zero for degenerate widths and radii.
const float EPS = 0.0001;

// Plain linear filtering: a mip-mapped screen texture would rebuild its mip chain every frame.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

group_uniforms geometry;
// Ring centre in the rect's UV (0..1); the rect covers the window, so this is the screen point.
uniform vec2 centre = vec2(0.5, 0.5);
// Rect width / height, so the ring stays round on a wide window.
uniform float aspect : hint_range(0.2, 5.0) = 1.7778;
// Ring radius and thickness, in units of the rect height.
uniform float radius : hint_range(0.0, 2.0) = 0.1;
uniform float width : hint_range(0.001, 1.0) = 0.06;

group_uniforms refraction;
// Push at the ring crest (rect-height units); pixels inside the crest are pulled in, outside pushed out.
uniform float strength : hint_range(0.0, 0.2) = 0.0;
// Additive tint on the crest (rgb * alpha), a faint glint where the wave bends the light.
uniform vec4 glint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

group_uniforms swirl;
// Twist in radians at the centre, easing to none at swirl_radius (rect-height units).
uniform float swirl : hint_range(-12.0, 12.0) = 0.0;
uniform float swirl_radius : hint_range(0.0, 2.0) = 0.2;
group_uniforms;

void fragment() {
	// d: offset from the centre in height-normalised units (x scaled by the aspect so circles stay round).
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float r = length(d);
	vec2 dir = d / max(r, EPS);
	// x: signed distance from the crest in ring widths; crest: 1 on the ring, 0 away from it.
	float x = (r - radius) / max(width, EPS);
	float crest = exp(-x * x * CREST_SHARPNESS);
	float push = strength * crest * clamp(x, -1.0, 1.0);
	// Swirl: rotate the sample point about the centre by an angle with a quadratic falloff.
	float fall = clamp(1.0 - r / max(swirl_radius, EPS), 0.0, 1.0);
	float ang = swirl * fall * fall;
	vec2 twisted = vec2(d.x * cos(ang) - d.y * sin(ang), d.x * sin(ang) + d.y * cos(ang));
	// Total offset back in rect UV (undo the aspect scaling), applied to the screen UV.
	vec2 off = ((twisted - d) - dir * push) / vec2(aspect, 1.0);
	vec4 c = textureLod(screen_tex, SCREEN_UV + off, 0.0);
	c.rgb += glint.rgb * glint.a * crest * step(EPS, strength);
	COLOR = vec4(c.rgb, 1.0);
}
