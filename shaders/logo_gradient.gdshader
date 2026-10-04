shader_type canvas_item;
// Mario Kart 64 logo fill: the letters shade from a light yellow at the top through orange to red
// at the baseline. Used on the fill layer of each logo letter (a Label); the glyph coverage comes
// from the font atlas alpha, the colour from the letter's local y between top_y and bottom_y.

uniform vec4 top_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.9, 0.14, 0.1, 1.0);
uniform float top_y = 0.0;
uniform float bottom_y = 100.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float t = clamp((local_y - top_y) / max(bottom_y - top_y, 1.0), 0.0, 1.0);
	vec3 grad = t < 0.5 ? mix(top_color.rgb, mid_color.rgb, t * 2.0) : mix(mid_color.rgb, bottom_color.rgb, (t - 0.5) * 2.0);
	float a = texture(TEXTURE, UV).a * COLOR.a;
	COLOR = vec4(grad, a);
}
