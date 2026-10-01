shader_type spatial;
render_mode unshaded;
// Animated chevrons that stream toward the front of the pad (-Z local) with HDR emission for glow.
uniform vec3 base_color : source_color = vec3(0.05, 0.1, 0.35);
uniform vec3 arrow_color : source_color = vec3(1.0, 0.75, 0.1);
uniform float scroll_speed = 1.6;
uniform float emission_energy = 3.0;

void fragment() {
	float f = fract((UV.y - 0.9 * abs(UV.x - 0.5)) * 3.0 + TIME * scroll_speed);
	float band = 1.0 - smoothstep(0.30, 0.38, f);
	float edge = smoothstep(0.46, 0.5, abs(UV.x - 0.5)) + smoothstep(0.46, 0.5, abs(UV.y - 0.5));
	vec3 c = mix(base_color, arrow_color * emission_energy, clamp(band + edge, 0.0, 1.0));
	ALBEDO = c;
}
