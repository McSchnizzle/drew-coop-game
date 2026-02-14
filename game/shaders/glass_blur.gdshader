shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.15, 0.13, 0.22, 0.35);

void fragment() {
	vec4 blur = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = vec4(mix(blur.rgb, tint.rgb, tint.a), 1.0);
}
