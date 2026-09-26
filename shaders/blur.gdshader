shader_type canvas_item;
// Behind the in-game menus: the night, out of focus and a little darker.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 4.0;
uniform float dim = 0.5;
uniform vec3 tint : source_color = vec3(0.05, 0.045, 0.06);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 acc = vec3(0.0);
	float w = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float k = exp(-float(x * x + y * y) / 7.0);
			acc += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * k;
			w += k;
		}
	}
	vec3 c = acc / w;
	float v = distance(SCREEN_UV, vec2(0.5)) * 1.3;
	COLOR = vec4(mix(c, tint, clamp(dim + v * 0.25, 0.0, 1.0)), 1.0);
}
