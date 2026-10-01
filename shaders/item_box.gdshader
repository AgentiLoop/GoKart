shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
// Translucent rainbow cube: hue cycles over time and across the surface, with a fresnel
// rim and bright "?" glyph on every face. HDR output so the environment glow blooms it.
uniform float energy = 1.6;
uniform float hue_speed = 0.35;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// crude "?" : hook arc + stem + dot in UV space
float question(vec2 uv) {
	vec2 p = uv - 0.5;
	vec2 q = p - vec2(0.0, -0.12);
	float ring = abs(length(q) - 0.17) - 0.045;
	if (q.y > 0.0 && q.x < 0.0) ring = 1.0;   // open the hook on the lower left
	float stem = max(abs(p.x) - 0.045, abs(p.y - 0.06) - 0.075);
	float dotp = length(p - vec2(0.0, 0.24)) - 0.055;
	float d = min(min(ring, stem), dotp);
	return 1.0 - smoothstep(0.0, 0.015, d);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float hue = fract(TIME * hue_speed + UV.x * 0.3 + UV.y * 0.3);
	vec3 rainbow = hsv2rgb(vec3(hue, 0.85, 1.0));
	float q = question(UV);
	vec3 c = rainbow * (0.25 + 1.2 * fres) + vec3(1.0) * q * 0.9;
	ALBEDO = c * energy;
}
