shader_type canvas_item;
render_mode unshaded;

uniform int fx_kind = 0;
uniform float fx_energy = 0.8;
uniform vec2 travel_dir = vec2(1.0, 0.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a <= 0.001) {
		COLOR = tex;
		return;
	}

	vec2 p = UV - vec2(0.5);
	vec2 dir = normalize(vec2(travel_dir.x, -travel_dir.y) + vec2(0.0001, 0.0001));
	float radial = 1.0 - clamp(length(p) * 2.1, 0.0, 1.0);
	float front = max(dot(normalize(p + vec2(0.0001)), dir), 0.0);
	float tail = max(dot(normalize(p + vec2(0.0001)), -dir), 0.0);
	float pulse = 0.5 + 0.5 * sin(TIME * (4.0 + fx_energy * 3.0) + (UV.x + UV.y) * 8.0);

	vec3 glow = vec3(0.0);
	if (fx_kind == 1) {
		glow = vec3(1.0, 0.45, 0.08) * (0.35 + 0.65 * pulse);
	}
	else if (fx_kind == 2) {
		glow = vec3(0.25, 0.95, 0.25) * (0.3 + 0.7 * pulse);
	}
	else if (fx_kind == 3) {
		glow = vec3(0.45, 0.9, 1.0) * (0.35 + 0.65 * pulse);
	}
	else if (fx_kind == 4) {
		glow = vec3(0.9, 0.95, 1.0) * (0.45 + 0.55 * pulse);
	}
	else if (fx_kind == 5) {
		glow = vec3(0.8, 0.45, 1.0) * (0.35 + 0.65 * pulse);
	}

	float halo = radial * (0.2 + 0.45 * fx_energy);
	float front_flash = pow(front, 3.0) * 0.55 * fx_energy;
	float tail_trail = pow(tail, 2.0) * 0.25 * fx_energy;
	vec3 final_rgb = tex.rgb + glow * (halo + front_flash + tail_trail);
	COLOR = vec4(final_rgb, tex.a);
}
