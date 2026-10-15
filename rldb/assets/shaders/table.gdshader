shader_type canvas_item;
// Candle-lit war table: dark wood grain, warm light pool, vignette (art bible section 5).
uniform vec4 wood_a : source_color = vec4(0.165, 0.129, 0.102, 1.0);
uniform vec4 wood_b : source_color = vec4(0.106, 0.086, 0.071, 1.0);
uniform vec4 deep : source_color = vec4(0.055, 0.051, 0.047, 1.0);
uniform vec4 pool : source_color = vec4(0.29, 0.23, 0.157, 1.0);
uniform vec2 pool_center = vec2(0.34, 0.40);
uniform float flicker = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 uv = UV;
	vec3 base = mix(wood_a.rgb, wood_b.rgb, uv.y);
	float g = fbm(vec2(uv.x * 5.0, uv.y * 80.0));
	float g2 = fbm(vec2(uv.x * 2.0 + 3.0, uv.y * 12.0));
	base *= 0.90 + 0.20 * (g * 0.7 + g2 * 0.3);
	float d = distance(uv * vec2(1.6, 1.0), pool_center * vec2(1.6, 1.0));
	base += pool.rgb * 0.20 * smoothstep(0.75, 0.0, d) * (1.0 + flicker);
	float v = distance(uv, vec2(0.5));
	base = mix(base, deep.rgb, smoothstep(0.30, 0.85, v) * 0.6);
	COLOR = vec4(base, 1.0);
}
