shader_type canvas_item;
// canvas_ui_title_fill: the gradient fill of a TitleText (src/ui/widgets/title_text.gd).
// Author: technical-artist, release batch 2026-10-20 (design/design-review-2026-10-20.md 1.4.1, D3).
//
// The glyphs are drawn white on the TitleText's fill layer; this shader replaces their colour with a
// vertical metal gradient measured per text line (cap top -> baseline), optionally blended into a
// second gradient (menu-item hover), plus an additive diagonal specular sweep band. Shadows, glow and
// outline are drawn underneath by TitleText without this material.
//
// Target: Forward+ (D3D12 / Vulkan) and the Compatibility fallback; 2D only.
// Budget: 2 texture samples per fragment, no loops, no branches. It only runs on glyph pixels of a
// few titles per screen, so the cost is negligible next to the backdrop.

group_uniforms gradient;
// 1D gradients (GradientTexture1D), sampled on the line's cap-height position (0 top, 1 baseline).
uniform sampler2D gradient_a : source_color, filter_linear, repeat_disable;
uniform sampler2D gradient_b : source_color, filter_linear, repeat_disable;
// 0 = gradient_a only, 1 = gradient_b only (menu hover blend).
uniform float gradient_mix : hint_range(0.0, 1.0) = 0.0;

group_uniforms layout;
// Local-space y (px) of the first line's cap top; cap height and line pitch (px).
uniform float cap_top = 0.0;
uniform float cap_height : hint_range(1.0, 400.0) = 10.0;
uniform float line_pitch : hint_range(1.0, 600.0) = 20.0;

group_uniforms sweep;
// Specular sweep: band centre x (local px), half width (px), additive strength (0 = off) and the
// band's tilt (tan of its angle from vertical; tan 30 deg = 0.577).
uniform float sweep_x = -10000.0;
uniform float sweep_half_width : hint_range(1.0, 200.0) = 12.0;
uniform float sweep_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_tilt : hint_range(-2.0, 2.0) = 0.577;
group_uniforms;

// Fraction of the sweep half width that is at full strength.
const float SWEEP_CORE = 0.4;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// COLOR already holds the glyph coverage (texture * vertex colour; the glyphs are drawn white).
	float cover = COLOR.a;
	// Each line owns a slot of line_pitch px centred on its cap band.
	float slot_top = cap_top - (line_pitch - cap_height) * 0.5;
	float line_i = floor((local_pos.y - slot_top) / line_pitch);
	float line_cap_top = cap_top + line_i * line_pitch;
	float t = clamp((local_pos.y - line_cap_top) / cap_height, 0.0, 1.0);
	vec3 col = mix(texture(gradient_a, vec2(t, 0.5)).rgb, texture(gradient_b, vec2(t, 0.5)).rgb, gradient_mix);
	// Tilted band: distance from the band centre, leaning right towards the top of the line.
	float mid = line_cap_top + cap_height * 0.5;
	float d = abs(local_pos.x - sweep_x + (local_pos.y - mid) * sweep_tilt);
	// A flat core over the inner 40% of the half width, then a smooth shoulder.
	float band = 1.0 - smoothstep(sweep_half_width * SWEEP_CORE, sweep_half_width, d);
	col += vec3(band * sweep_strength);
	COLOR = vec4(col, cover);
}
