shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
// Star invincibility: a cycling rainbow overlay with a fresnel rim and fast shimmer,
// HDR so it blooms. Used as material_overlay on the kart body.
uniform float strength = 1.6;
uniform float speed = 3.0;

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 1.5);
	float h = TIME * speed * 0.3 + UV.x * 0.5 + UV.y * 0.5 + n.y * 0.2;
	float shimmer = 0.75 + 0.25 * sin(TIME * 30.0 + UV.x * 20.0);
	ALBEDO = hue(h) * (0.5 + fres) * strength * shimmer;
}
