shader_type canvas_item;

uniform float blur_amount : hint_range(0, 100) = 0.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	float b = blur_amount * 4.0;
	
	if (b <= 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		// 9-tap box blur (足够轻量，效果近似高斯)
		vec4 col = vec4(0.0);
		col += texture(TEXTURE, UV + vec2(-ps.x * b, -ps.y * b));
		col += texture(TEXTURE, UV + vec2(0.0, -ps.y * b));
		col += texture(TEXTURE, UV + vec2(ps.x * b, -ps.y * b));
		col += texture(TEXTURE, UV + vec2(-ps.x * b, 0.0));
		col += texture(TEXTURE, UV + vec2(0.0, 0.0));
		col += texture(TEXTURE, UV + vec2(ps.x * b, 0.0));
		col += texture(TEXTURE, UV + vec2(-ps.x * b, ps.y * b));
		col += texture(TEXTURE, UV + vec2(0.0, ps.y * b));
		col += texture(TEXTURE, UV + vec2(ps.x * b, ps.y * b));
		col /= 9.0;
		COLOR = col;
	}
}