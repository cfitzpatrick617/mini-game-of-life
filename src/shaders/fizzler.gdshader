shader_type canvas_item;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	//COLOR = vec4(textureColor.r, textureColor.g, textureColor.b, clamp(textureColor.a-0.05, 0, 1));
	COLOR -= vec4(0.0, 0.0, 0.0, tex.a-0.9);
}