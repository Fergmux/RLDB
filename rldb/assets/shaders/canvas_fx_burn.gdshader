// canvas_fx_burn: RLDB technical art, release batch 2026-10-20 (D6 sacrifice, D8 Ritual tribute).
// Purpose: a card consumed by fire. An organic burn front (three-octave value-noise fbm) climbs the card
// from its bottom edge; ahead of the hole the card chars, then glows ember-orange, then white-hot at the
// very edge, and the remaining paper desaturates and darkens as it heats.
// Pipeline: canvas_item on Forward+ and Compatibility, applied to a CardWidget ghost (its children use the
// parent material). Budget: no texture reads, about 60 ALU ops per pixel, no loops, no dynamic branches.
// Fallback: reduced motion never applies it (the ghost just fades).
shader_type canvas_item;

// Value noise scale (cycles per pixel) of the first fbm octave; later octaves double it.
const float NOISE_SCALE = 0.045;
// fbm octave weights (sum 1.0).
const float W1 = 0.55;
const float W2 = 0.3;
const float W3 = 0.15;

group_uniforms burn;
// 0 = untouched, 1 = fully burnt away.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// How strongly the front climbs from the bottom (0 = pure noise holes, 1 = a clean rising line).
uniform float sweep : hint_range(0.0, 1.0) = 0.65;
// The card's rect in viewport pixels (x, y, width, height), for the bottom-to-top sweep.
uniform vec4 rect_px = vec4(0.0, 0.0, 100.0, 150.0);

group_uniforms edge;
// Band widths in burn-progress units: white-hot edge, ember glow and char ahead of it.
uniform float hot_width : hint_range(0.0, 0.2) = 0.025;
uniform float ember_width : hint_range(0.0, 0.3) = 0.07;
uniform float char_width : hint_range(0.0, 0.4) = 0.16;
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 char_color : source_color = vec4(0.12, 0.05, 0.02, 1.0);
group_uniforms;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 c = COLOR;
	vec2 p = FRAGCOORD.xy * NOISE_SCALE;
	float n = vnoise(p) * W1 + vnoise(p * 2.03 + 17.0) * W2 + vnoise(p * 4.11 + 41.0) * W3;
	// Height from the card's bottom edge (0) to its top (1).
	float up = clamp((rect_px.y + rect_px.w - FRAGCOORD.y) / max(rect_px.w, 1.0), 0.0, 1.0);
	// Burn value of this pixel: low burns first. The bottom burns first when sweep > 0.
	float v = mix(n, up * 0.8 + n * 0.2, sweep);
	// Front position; the bands extend so that progress = 1 leaves nothing.
	float span = hot_width + ember_width + char_width;
	float front = progress * (1.0 + span);
	float d = v - front;   // < 0: burnt away; small positive: the edge bands
	float hot = 1.0 - smoothstep(0.0, hot_width, d);
	float ember = 1.0 - smoothstep(hot_width, hot_width + ember_width, d);
	float charred = 1.0 - smoothstep(hot_width + ember_width, span, d);
	// Heat desaturates and darkens the paper ahead of the front.
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(gray) * 0.85, progress * 0.6);
	c.rgb = mix(c.rgb, char_color.rgb, charred * 0.85);
	c.rgb = mix(c.rgb, ember_color.rgb, ember);
	c.rgb = mix(c.rgb, hot_color.rgb, hot);
	c.a *= step(0.0, d);
	COLOR = c;
}
