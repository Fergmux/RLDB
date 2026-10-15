shader_type canvas_item;
// Destruction dissolve with a burnt ember edge; also desaturates as it burns.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.54, 0.23, 1.0);
uniform float edge_width = 0.09;

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
	float n = vnoise(FRAGCOORD.xy * 0.09) * 0.6 + vnoise(FRAGCOORD.xy * 0.25) * 0.4;
	float t = dissolve * (1.0 + edge_width) ;
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(gray), dissolve * 0.8);
	if (n < t - edge_width) {
		c.a = 0.0;
	} else if (n < t) {
		c.rgb = mix(c.rgb, edge_color.rgb, 0.95);
	}
	COLOR = c;
}
