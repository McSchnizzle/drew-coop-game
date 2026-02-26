shader_type spatial;

uniform vec4 brick_color : source_color = vec4(0.35, 0.22, 0.18, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform float brick_width : hint_range(0.05, 1.0) = 0.09;
uniform float brick_height : hint_range(0.02, 0.5) = 0.05;
uniform float mortar_size : hint_range(0.002, 0.05) = 0.012;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.9;
uniform vec2 uv_scale = vec2(4.0, 3.5);

void fragment() {
	vec2 uv = UV * uv_scale;

	float cell_w = brick_width + mortar_size;
	float cell_h = brick_height + mortar_size;

	float row = floor(uv.y / cell_h);
	float offset = mod(row, 2.0) * cell_w * 0.5;

	vec2 brick_uv = vec2(uv.x + offset, uv.y);

	float bx = mod(brick_uv.x, cell_w);
	float by = mod(brick_uv.y, cell_h);

	bool is_mortar = bx < mortar_size || by < mortar_size;

	if (is_mortar) {
		ALBEDO = mortar_color.rgb;
		ROUGHNESS = 0.95;
	} else {
		// Per-brick color variation: dark red, medium red, light pinkish/whitish
		float brick_id = floor(brick_uv.x / cell_w) + row * 31.0;
		float hash = fract(sin(brick_id * 43758.5453) * 2.0);
		// Wide variation: -0.12 to +0.12 brightness shift
		float variation = hash * 0.24 - 0.12;
		// Some bricks get a pinkish/whitish tint (higher hash values)
		float pink_shift = smoothstep(0.6, 1.0, hash) * 0.08;
		ALBEDO = brick_color.rgb + vec3(variation + pink_shift, variation * 0.5 + pink_shift * 0.7, variation * 0.3 + pink_shift * 0.5);
		ROUGHNESS = roughness_val;

		// Subtle bump: darken edges of each brick for depth
		float edge_x = min(bx - mortar_size, cell_w - bx) / (cell_w * 0.5);
		float edge_y = min(by - mortar_size, cell_h - by) / (cell_h * 0.5);
		float edge = min(edge_x, edge_y);
		float darken = smoothstep(0.0, 0.15, edge);
		ALBEDO *= mix(0.7, 1.0, darken);
	}

	METALLIC = 0.0;

	// Fake normal perturbation for depth
	float bx_norm = (bx - mortar_size) / (cell_w - mortar_size);
	float by_norm = (by - mortar_size) / (cell_h - mortar_size);
	vec3 n = vec3(0.0, 0.0, 1.0);
	if (!is_mortar) {
		n.x = smoothstep(0.0, 0.08, bx_norm) - smoothstep(0.92, 1.0, bx_norm);
		n.x = (n.x - 0.5) * 0.3;
		n.y = smoothstep(0.0, 0.08, by_norm) - smoothstep(0.92, 1.0, by_norm);
		n.y = (n.y - 0.5) * 0.3;
		n = normalize(n);
	}
	NORMAL_MAP = n * 0.5 + 0.5;
}
