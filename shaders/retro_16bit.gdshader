shader_type canvas_item;

uniform bool enabled = false;
uniform float color_depth : hint_range(4.0, 32.0) = 16.0;

// Матрица упорядоченного дизеринга Байера 4x4
const float bayer4x4[16] = float[16](
	0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;

	if (col.a <= 0.001) {
		COLOR = vec4(0.0);
	} else if (!enabled) {
		COLOR = col;
	} else {
		int x = int(mod(FRAGCOORD.x, 4.0));
		int y = int(mod(FRAGCOORD.y, 4.0));
		float dither = bayer4x4[y * 4 + x] - 0.5;

		vec3 c = col.rgb + (dither / color_depth);
		c = floor(c * color_depth + 0.5) / color_depth;
		COLOR = vec4(clamp(c, 0.0, 1.0), col.a);
	}
}
