shader_type canvas_item;

uniform vec4 warp_color : source_color = vec4(0.62, 0.02, 0.06, 1.0);
uniform vec4 edge_color : source_color = vec4(0.95, 0.18, 0.08, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float swirl_speed : hint_range(0.0, 8.0) = 4.6;
uniform float arm_count : hint_range(1.0, 8.0) = 3.0;
uniform float arm_tightness : hint_range(2.0, 32.0) = 9.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.68;
uniform float aperture : hint_range(0.0, 1.0) = 0.14;
uniform float alpha_strength : hint_range(0.0, 2.0) = 1.0;
uniform float collapse_bias : hint_range(0.0, 1.0) = 0.0;
uniform float crackle_strength : hint_range(0.0, 2.0) = 1.0;
uniform float tear_width : hint_range(0.02, 0.8) = 0.22;
uniform float vertical_bias : hint_range(0.0, 2.0) = 1.15;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float t = clamp(progress, 0.0, 1.0);
	float open_radius = mix(0.08, 1.02, t);
	float hole_radius = mix(aperture + collapse_bias * 0.09, 0.03, t);
	float outer_fade = 1.0 - smoothstep(open_radius - 0.08, open_radius + 0.02, r);
	float inner_hole = smoothstep(hole_radius, hole_radius + 0.09, r);

	float swirl = angle * arm_count - r * arm_tightness + TIME * swirl_speed;
	float arm_wave = 0.5 + 0.5 * sin(swirl);
	float radial_wave = 0.5 + 0.5 * sin(r * 36.0 - TIME * (swirl_speed * 2.4));
	float n0 = hash21(floor(p * 24.0) + vec2(floor(TIME * 10.0), floor(TIME * 7.0)));
	float n1 = hash21(floor(p * 41.0) + vec2(floor(TIME * 13.0), floor(TIME * 11.0)));
	float jag = (n0 * 0.7 + n1 * 0.3) * turbulence;
	float crack = abs(sin(angle * 10.0 + TIME * 10.2 + n1 * 6.28));
	float crackle = smoothstep(0.76, 1.0, crack) * crackle_strength;
	float edge_crack = smoothstep(0.82, 1.0, sin(angle * 14.0 - TIME * 12.0 + n0 * 7.0));

	float spiral_band = smoothstep(0.52, 1.0, arm_wave) * inner_hole;
	float vortex = mix(spiral_band, radial_wave, 0.22);
	float rim_band = smoothstep(open_radius - 0.22 - jag * 0.08, open_radius - 0.05 + crackle * 0.04, r);
	float rim_hot = smoothstep(open_radius - 0.1, open_radius + 0.01, r) * edge_crack;

	float storm = vortex + crackle * 0.75 + edge_crack * 0.35;
	float alpha = outer_fade * inner_hole * (0.24 + storm * 0.9) * alpha_strength;
	alpha += rim_hot * 0.16;
	alpha *= 1.0 - smoothstep(1.05, 1.28, r);

	vec3 ember = vec3(1.0, 0.34, 0.1) * (crackle * 0.62 + edge_crack * 0.22);
	vec3 base = mix(warp_color.rgb, edge_color.rgb, clamp(rim_band * 0.42 + crackle * 0.45 + storm * 0.18, 0.0, 1.0));
	base += ember;
	base -= vec3(0.46, 0.04, 0.04) * (1.0 - inner_hole);
	base *= 0.42 + radial_wave * 0.12 + crackle * 0.09;

	COLOR = vec4(base, alpha);
}
