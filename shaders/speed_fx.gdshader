shader_type canvas_item;
// Full-screen post effect: radial boost blur + anime-style speed lines + vignette.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float speed_amount : hint_range(0.0, 1.0) = 0.0;  // 0..1 of top speed
uniform float boost_amount : hint_range(0.0, 1.0) = 0.0;  // boost intensity
uniform float time_s = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;  // mini-turbo release flash
uniform vec3 flash_color : source_color = vec3(1.0);
uniform int blur_samples = 10;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 center = vec2(0.5, 0.45);
	vec2 d = UV - center;
	float dist = length(d);
	vec2 dir = d / max(dist, 0.0001);

	// radial blur, strongest at screen edges
	float blur = (boost_amount * 0.06 + speed_amount * 0.012) * smoothstep(0.1, 0.8, dist);
	vec3 col = vec3(0.0);
	for (int i = 0; i < blur_samples; i++) {
		float t = float(i) / float(blur_samples);
		col += textureLod(screen_tex, UV - dir * blur * t, 0.0).rgb;
	}
	col /= float(blur_samples);

	// speed lines: streaks in angular bins, scrolling outward
	float ang = atan(d.y, d.x);
	float bin = floor(ang * 40.0);
	float rnd = hash(bin);
	float flow = fract(dist * 1.5 - time_s * (1.5 + rnd * 2.0) + rnd * 7.0);
	float streak = smoothstep(0.0, 0.1, flow) * (1.0 - smoothstep(0.1, 0.4, flow));
	float edge = smoothstep(0.3, 0.75, dist);
	float lines = streak * edge * step(0.55, rnd) * clamp(boost_amount + max(speed_amount - 0.7, 0.0) * 2.0, 0.0, 1.0);
	col = mix(col, vec3(1.0), lines * 0.55);

	// vignette + slight blue-white boost tint
	col *= 1.0 - smoothstep(0.55, 1.1, dist) * (0.15 + 0.25 * boost_amount);
	col += vec3(0.05, 0.1, 0.2) * boost_amount * smoothstep(0.3, 0.9, dist);
	// mini-turbo flash: coloured glow pulse from the screen edges
	col += flash_color * flash_amount * (0.12 + 0.5 * smoothstep(0.2, 0.9, dist));
	COLOR = vec4(col, 1.0);
}
