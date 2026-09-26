shader_type canvas_item;
// A picture as a green screen would show it: brightness only, a few steps
// of green, ordered dither on the screen's own pixels, and scanlines.

uniform vec3 ink : source_color = vec3(0.55, 1.0, 0.6);
uniform vec3 ground : source_color = vec3(0.02, 0.07, 0.04);
uniform float steps = 5.0;
uniform float contrast = 1.25;
uniform float lift = 0.0;
uniform float noise : hint_range(0.0, 1.0) = 0.0;
uniform float motion = 1.0;
uniform float cell = 1.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[x + y * 4] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 grid = floor(FRAGCOORD.xy / cell);
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	l = clamp((l - 0.5) * contrast + 0.5 + lift, 0.0, 1.0);
	float t = floor(TIME * 12.0 * motion);
	l = mix(l, hash(grid + t), noise);
	float q = floor(l * steps + bayer4(grid) + 0.5) / steps;
	q *= 1.0 - 0.28 * mod(grid.y, 2.0);
	COLOR = vec4(mix(ground, ink, clamp(q, 0.0, 1.0)), c.a * COLOR.a);
}
