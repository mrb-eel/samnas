shader_type canvas_item;
// Post-process for the low-resolution 3D stage.
// Ordered dither and a coarse palette on the low-res grid, a little grain.
// "heard" mode: when Ari only has a voice line, the room is guessed from
// sound: dark, blue, most of it missing.

uniform float heard : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform float levels = 12.0;
uniform float motion = 1.0;
uniform vec3 lift = vec3(0.0);
uniform float warmth : hint_range(-1.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 grid = floor(UV / TEXTURE_PIXEL_SIZE);
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb + lift;
	col.r += warmth * 0.03;
	col.b -= warmth * 0.03;
	float d = bayer4(grid);
	col = floor(col * levels + d + 0.5) / levels;
	float t = floor(TIME * 12.0 * motion);
	float n = hash(grid + t) - 0.5;
	col += n * grain;
	if (heard > 0.0) {
		float lum = dot(col, vec3(0.3, 0.55, 0.15));
		vec3 blue = vec3(0.10, 0.16, 0.30) * (0.35 + lum * 1.6);
		// sparse, shifting samples: most of the room is missing
		float keep = step(0.86 - lum * 0.35, hash(floor(grid / 2.0) + floor(TIME * 3.0 * motion)));
		vec3 h = mix(vec3(0.02, 0.025, 0.04), blue, keep);
		col = mix(col, h, heard);
	}
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
