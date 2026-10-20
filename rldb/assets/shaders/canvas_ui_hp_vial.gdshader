shader_type canvas_item;
// canvas_ui_hp_vial: the "Vial of Life" HP display body (src/ui/board/hp_vial.gd).
// Author: technical-artist, release batch 2026-10-20 (design/design-review-2026-10-20.md, D4).
//
// Draws, from one full-rect quad: the 1 px dark outer edge, the 3 px gilded bronze bezel (vertical
// GOLD_HI -> GOLD -> BRONZE gradient with brushed-metal grain), the 1 px black lip, and the glass
// well with its contents: the ruby liquid (3-stop gradient, drifting noise, bright meniscus), the
// amber damage trail (with its white hit flash), the emerald-gold heal glow and shimmer band, the
// 10 HP segment ticks, the low-HP inner glow pulse, the glass highlight line, the top sheen and the
// travelling specular glint. Studs, crack decal, number and particles are drawn on top by GDScript.
// All values in px are layout px at 1600x900 (the vial is 228 x 30).
//
// Target: Forward+ (D3D12 / Vulkan) and the Compatibility fallback; 2D only.
// Budget: 3 texture samples per fragment (noise, glass grain, metal grain), no loops, no branches.
// The quad covers 228 x 30 px, two per HUD: under 14k fragments a frame.
// Motion (noise drift, glint, low-HP pulse) runs on TIME; `motion` = 0 freezes it (reduce motion).

group_uniforms geometry;
// Control size in px.
uniform vec2 vial_size = vec2(228.0, 30.0);
// Outer corner radius, and the inset / radius of the glass well (bezel edge + ring + lip).
uniform float outer_radius = 8.0;
uniform float well_inset = 5.0;
uniform float well_radius = 5.0;

group_uniforms levels;
// Liquid level, damage trail span and heal glow span, as fractions of the well width.
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail_from : hint_range(0.0, 1.0) = 0.0;
uniform float trail_to : hint_range(0.0, 1.0) = 0.0;
// Trail opacity, and its white hit flash (0..1).
uniform float trail_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float trail_flash : hint_range(0.0, 1.0) = 0.0;
uniform float heal_from : hint_range(0.0, 1.0) = 0.0;
uniform float heal_to : hint_range(0.0, 1.0) = 0.0;
uniform float heal_glow : hint_range(0.0, 1.0) = 0.0;
// Heal shimmer band centre (px from the well's left edge; far negative = off).
uniform float shimmer_x = -10000.0;
// Segment tick spacing as a fraction of the well width (0 = no ticks).
uniform float tick_step = 0.0;

group_uniforms state;
// Low-HP blend 0..1 (fill brightens, inner glow on).
uniform float low_hp : hint_range(0.0, 1.0) = 0.0;
// 1 = animated (TIME-driven drift, glint and pulse), 0 = static (reduce motion).
uniform float motion : hint_range(0.0, 1.0) = 1.0;
// Per-vial phase offset (s) so two vials do not glint in lockstep.
uniform float time_offset = 0.0;
// Dev / screenshots: a fixed time (s) replacing TIME when >= 0 (deterministic frames).
uniform float frozen_time = -1.0;

group_uniforms textures;
// 64 x 32 tileable noise (r channel), glass grain (leather relief) and bezel metal relief.
uniform sampler2D noise_tex : filter_linear, repeat_enable, hint_default_black;
uniform sampler2D glass_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D metal_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
group_uniforms;

// ---- palette (review D4) ----
const vec3 EDGE = vec3(0.102, 0.063, 0.024);          // #1a1006 outer edge
const vec3 GOLD_HI = vec3(0.941, 0.812, 0.478);       // #f0cf7a bezel top
const vec3 GOLD = vec3(0.831, 0.651, 0.290);          // #d4a64a bezel middle
const vec3 BRONZE = vec3(0.478, 0.353, 0.188);        // #7a5a30 bezel bottom
const float METAL_GRAIN = 0.10;
const vec3 WELL = vec3(0.078, 0.031, 0.031);          // #140808 empty glass
const vec3 GLASS_TINT = vec3(0.227, 0.071, 0.063);    // #3a1210 scratched glass
const float GLASS_GRAIN = 0.15;
const vec3 LIQ_TOP = vec3(1.0, 0.478, 0.361);         // #ff7a5c meniscus highlight band
const vec3 LIQ_CORE = vec3(0.769, 0.165, 0.122);      // #c42a1f
const vec3 LIQ_CORE_LOW = vec3(0.878, 0.251, 0.184);  // #e0402f (low HP)
const vec3 LIQ_BOTTOM = vec3(0.431, 0.059, 0.047);    // #6e0f0c
const vec3 MENISCUS = vec3(1.0, 0.725, 0.627);        // #ffb9a0
const vec3 TRAIL = vec3(1.0, 0.690, 0.541);           // #ffb08a amber (top)
const vec3 TRAIL_DEEP = vec3(0.851, 0.420, 0.180);    // #d96b2e ember amber (bottom)
const vec3 HEAL_BASE = vec3(0.435, 0.827, 0.541);     // #6fd38a
const vec3 HEAL_HI = vec3(0.561, 1.0, 0.690);         // #8fffb0
const vec3 LOW_GLOW = vec3(1.0, 0.290, 0.227);        // #ff4a3a
const float NOISE_ALPHA = 0.18;
const float NOISE_DRIFT = 6.0;                        // px/s, leftwards
const float GLINT_PERIOD = 7.0;
const float GLINT_PASS = 0.9;
const float LOW_PULSE_PERIOD = 1.1;
const float LOW_PULSE_MAX = 0.45;
const float LOW_STATIC = 0.35;                        // reduce motion: static glow

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// Signed distance to a rounded box centred at the origin (half size h, radius r).
float sd_round_box(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// 1 inside x0..x1 (px), anti-aliased over one pixel.
float span(float x, float x0, float x1) {
	return clamp(x - x0 + 0.5, 0.0, 1.0) * clamp(x1 - x + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 p = local_pos;
	vec2 c = vial_size * 0.5;
	float d_out = sd_round_box(p - c, c, outer_radius);
	vec2 wh = c - vec2(well_inset);
	float d_in = sd_round_box(p - c, wh, well_radius);
	vec2 wp = p - vec2(well_inset);              // well-local px
	vec2 ws = wh * 2.0;                           // well size px
	float v = clamp(wp.y / ws.y, 0.0, 1.0);
	float t = mix(TIME, frozen_time, step(0.0, frozen_time)) * motion + time_offset;

	// ---- bezel ----
	float by = clamp(p.y / vial_size.y, 0.0, 1.0);
	vec3 ring = mix(GOLD_HI, GOLD, smoothstep(0.0, 0.5, by));
	ring = mix(ring, BRONZE, smoothstep(0.5, 1.0, by));
	float metal = texture(metal_tex, p / 160.0).r;
	ring *= mix(1.0, metal * 2.0, METAL_GRAIN);
	// A bright bevel along the ring's outer top edge.
	ring += vec3(0.18) * (1.0 - smoothstep(0.0, 2.0, abs(d_out + 1.6))) * (1.0 - by);
	vec3 col = EDGE;
	col = mix(col, ring, clamp(0.5 - (d_out + 1.0), 0.0, 1.0));
	vec3 lip = vec3(0.0);
	col = mix(col, mix(ring, lip, 0.8), clamp(0.5 - (d_in - 1.0), 0.0, 1.0));

	// ---- glass well ----
	float glass = texture(glass_tex, p / 96.0).r;
	vec3 well = mix(WELL, GLASS_TINT * glass * 2.0, GLASS_GRAIN);

	// Damage trail: amber (lighter at the top), flashing white on the hit.
	float tr = span(wp.x, trail_from * ws.x, trail_to * ws.x) * trail_alpha;
	vec3 trail = mix(TRAIL, TRAIL_DEEP, smoothstep(0.15, 1.0, v));
	trail = mix(trail, vec3(1.0), trail_flash);
	well = mix(well, trail, tr * 0.9);

	// Heal glow: emerald-gold, ahead of the pouring liquid.
	float hg = span(wp.x, heal_from * ws.x, heal_to * ws.x) * heal_glow;
	vec3 heal = mix(HEAL_BASE, HEAL_HI, 0.55) * mix(1.15, 0.8, v);
	well = mix(well, heal, hg * 0.85);

	// Liquid: 3-stop vertical gradient, drifting noise, meniscus line and glow at the edge.
	float edge_x = fill * ws.x;
	float liq = clamp(edge_x - wp.x + 0.5, 0.0, 1.0) * step(0.0005, fill);
	vec3 core = mix(LIQ_CORE, LIQ_CORE_LOW, low_hp);
	vec3 lc = mix(LIQ_TOP, core, smoothstep(0.0, 0.2, v));
	lc = mix(lc, LIQ_BOTTOM, smoothstep(0.35, 1.0, v));
	float n = texture(noise_tex, (wp + vec2(t * NOISE_DRIFT, 0.0)) / vec2(64.0, 32.0)).r;
	lc += vec3(1.0, 0.62, 0.5) * n * NOISE_ALPHA;
	float sb = 1.0 - smoothstep(4.0, 12.0, abs(wp.x - shimmer_x + (wp.y - ws.y * 0.5) * 0.6));
	lc += vec3(0.4) * sb;
	float dx = edge_x - wp.x;
	float m_on = step(0.002, fill) * step(fill, 0.998);
	float m_line = (1.0 - smoothstep(0.6, 1.6, abs(dx - 1.0))) * 0.7;
	lc = mix(lc, MENISCUS, m_line * m_on);
	col = mix(col, well, clamp(0.5 - d_in, 0.0, 1.0));
	col = mix(col, lc, liq * clamp(0.5 - d_in, 0.0, 1.0));
	// Freshly poured liquid keeps an emerald-gold cast while the heal glow fades.
	col += heal * hg * 0.16 * liq * clamp(0.5 - d_in, 0.0, 1.0);
	// Soft 6 px meniscus glow on both sides of the edge (onto the glass too).
	col += MENISCUS * exp(-abs(dx) / 3.0) * 0.28 * m_on * clamp(0.5 - d_in, 0.0, 1.0);

	// Segment ticks every tick_step: a 1 px dark line with a 1 px light line beside it.
	float period = max(tick_step * ws.x, 1.0);
	float k = floor(wp.x / period + 0.5);
	float sx = wp.x - k * period;
	float tick_ok = step(0.5, k) * step(k * period, ws.x - 3.0) * step(0.0001, tick_step);
	float dark = (1.0 - smoothstep(0.5, 1.0, abs(sx))) * tick_ok;
	float light = (1.0 - smoothstep(0.5, 1.0, abs(sx - 1.0))) * tick_ok;
	float tick_a = mix(0.5, 1.0, liq);
	float in_well = clamp(0.5 - d_in, 0.0, 1.0);
	col = mix(col, vec3(0.0), dark * 0.35 * tick_a * in_well);
	col = mix(col, vec3(1.0), light * 0.08 * tick_a * in_well);

	// Inner shadow from the top (0 3 6 #000 70%): the glass sits below the lip.
	float d_sh = sd_round_box(p - c - vec2(0.0, 3.0), wh, well_radius);
	float shade = (1.0 - smoothstep(0.0, 6.0, -d_sh)) * 0.7;
	col *= 1.0 - shade * mix(1.0, 0.55, liq) * in_well;

	// Low-HP inner glow on the bezel's inside edge: a 1.1 s pulse, or a static 35% (reduce motion).
	// Drawn over the inner shadow so the glass edge lights up red.
	float pulse = (0.5 - 0.5 * cos(TAU * t / LOW_PULSE_PERIOD)) * LOW_PULSE_MAX;
	float low_a = low_hp * mix(LOW_STATIC, pulse, motion);
	float inner = (1.0 - smoothstep(0.0, 6.0, -d_in)) * in_well;
	col = mix(col, LOW_GLOW, inner * low_a);
	col += LOW_GLOW * inner * inner * low_a * 0.35;

	// Glass: a 1 px white 35% line at y = 3, a 40% -> 0% sheen over the top 35%.
	float x_fade = smoothstep(0.0, well_radius, wp.x) * smoothstep(0.0, well_radius, ws.x - wp.x);
	float hl = (1.0 - smoothstep(0.0, 1.0, abs(wp.y - 3.0))) * 0.35 * x_fade;
	float sheen = (1.0 - smoothstep(0.0, 0.35, v)) * 0.40;
	col = mix(col, vec3(1.0), (sheen * mix(0.55, 0.25, tr) + hl) * in_well);

	// Specular glint: an 18 px soft white oval at 25%, sweeping left to right every 7 s.
	float gt = mod(t, GLINT_PERIOD) / GLINT_PASS;
	float gx = mix(-18.0, ws.x + 18.0, clamp(gt, 0.0, 1.0));
	vec2 g = vec2((wp.x - gx) / 9.0, (wp.y - ws.y * 0.32) / 4.0);
	float glint = exp(-dot(g, g) * 1.6) * 0.25 * step(gt, 1.0) * motion;
	col += vec3(glint) * in_well;

	float alpha = clamp(0.5 - d_out, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
