shader_type canvas_item;
// The last pass over the whole 640x360 screen, interface included: fewer
// colours, ordered dither, grain that crawls, faint scanlines, dark corners,
// the odd torn line. The picture should look like it came down a bad cable.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 24.0;
uniform float grain : hint_range(0.0, 0.3) = 0.045;
uniform float scan : hint_range(0.0, 0.5) = 0.07;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float motion = 1.0;
uniform float tear : hint_range(0.0, 1.0) = 0.0;
uniform float bleed : hint_range(0.0, 2.0) = 1.0;
uniform float plain = 0.0;

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
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 grid = floor(SCREEN_UV / px);
	float t = floor(TIME * 15.0 * motion);
	vec2 uv = SCREEN_UV;
	// a tear: a band of rows slides sideways for a frame or two
	float band = floor(grid.y / 6.0);
	float torn = step(1.0 - tear * 0.25, hash(vec2(band, t))) * tear;
	uv.x += torn * (hash(vec2(t, band)) - 0.5) * 0.06;
	vec3 col = texture(screen_tex, uv).rgb;
	if (plain < 0.5) {
		// colour bleed: red lags a pixel to the right, like composite video
		float r = texture(screen_tex, uv - vec2(px.x * bleed, 0.0)).r;
		col.r = mix(col.r, r, 0.6);
		float d = bayer4(grid);
		col = floor(col * levels + d + 0.5) / levels;
		col += (hash(grid + t) - 0.5) * grain;
		col *= 1.0 - scan * mod(grid.y, 2.0);
		vec2 c = SCREEN_UV - 0.5;
		float v = dot(c * vec2(1.0, 1.25), c * vec2(1.0, 1.25));
		col *= 1.0 - vignette * smoothstep(0.08, 0.5, v);
	}
	COLOR = vec4(col, 1.0);
}
