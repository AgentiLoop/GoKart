shader_type spatial;
render_mode unshaded;
// Green shell: green dome with a white belt, a fresnel glow and a pulsing HDR halo
// so it blooms against the track.
uniform vec3 shell_color : source_color = vec3(0.1, 0.8, 0.2);
uniform vec3 rim_color : source_color = vec3(0.9, 1.0, 0.9);
uniform float glow = 1.8;

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.5);
	float band = 1.0 - smoothstep(0.08, 0.14, abs(UV.y - 0.5));
	float pulse = 0.85 + 0.15 * sin(TIME * 18.0);
	vec3 c = mix(shell_color * (0.45 + 0.55 * n.y), rim_color, band);
	c += shell_color * fres * glow * pulse;
	ALBEDO = c;
}
