shader_type canvas_item;
render_mode unshaded, world_vertex_coords;

uniform vec2 player_world_pos = vec2(0.0);
uniform float tile_size = 8.0;
uniform int active_liquid_type = 0;

varying vec2 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	vec2 tile_coord = floor(world_pos / max(tile_size, 1.0));
	vec2 local_px = mod(world_pos, max(tile_size, 1.0));
	vec2 local_uv = local_px / max(tile_size, 1.0);
	float cell_noise = hash21(tile_coord);
	float t = TIME;

	vec4 raw = texture(TEXTURE, UV);
	float blueish = smoothstep(0.08, 0.22, raw.b - max(raw.r, raw.g));
	float greenish = smoothstep(0.05, 0.18, raw.g - max(raw.r, raw.b) * 0.9);
	float reddish = smoothstep(0.05, 0.18, raw.r - max(raw.g, raw.b) * 0.85);

	if (active_liquid_type == 1) {
		blueish = max(blueish, 0.75);
	}
	else if (active_liquid_type == 2) {
		greenish = max(greenish, 0.75);
	}
	else if (active_liquid_type == 3) {
		reddish = max(reddish, 0.75);
	}

	float flow_wave = sin(world_pos.x * 0.14 + t * 1.8 + cell_noise * 6.2831);
	float cross_wave = sin(world_pos.y * 0.19 - t * 1.2 + cell_noise * 9.0);
	vec2 flow_offset = vec2(
		0.45 * flow_wave + 0.18 * cross_wave,
		0.22 * cross_wave
	) * TEXTURE_PIXEL_SIZE;

	float player_dist = distance(world_pos, player_world_pos);
	float wake_band = exp(-pow((player_dist - 15.0) / 10.0, 2.0));
	float wake_core = exp(-pow(player_dist / 15.0, 2.0));
	float wake_wave = sin(player_dist * 0.42 - t * 7.0);
	float wake = wake_band * wake_wave + wake_core * 0.15;
	vec2 wake_dir = world_pos - player_world_pos;
	float wake_len = max(length(wake_dir), 0.001);
	vec2 wake_offset = (wake_dir / wake_len) * wake * 0.75 * TEXTURE_PIXEL_SIZE;

	vec2 distorted_uv = UV + flow_offset + wake_offset;
	vec4 base = texture(TEXTURE, distorted_uv);

	float tile_phase = t * 1.8 + cell_noise * 6.2831;
	float tile_phase_fast = t * 2.6 + cell_noise * 8.0;
	float tile_phase_lava = t * 2.1 + cell_noise * 5.0;

	vec2 px_uv = floor(local_uv * max(tile_size, 1.0)) / max(tile_size, 1.0);
	float diagonal_a = fract(px_uv.x + px_uv.y + tile_phase * 0.18);
	float diagonal_b = fract(px_uv.x - px_uv.y + tile_phase_fast * 0.14);
	float ripple_band = smoothstep(0.26, 0.38, diagonal_a) - smoothstep(0.38, 0.52, diagonal_a);
	float cross_band = smoothstep(0.48, 0.60, diagonal_b) - smoothstep(0.60, 0.72, diagonal_b);
	float lava_band = smoothstep(0.20, 0.34, fract(px_uv.y * 1.15 + tile_phase_lava * 0.12)) - smoothstep(0.34, 0.50, fract(px_uv.y * 1.15 + tile_phase_lava * 0.12));

	float water_motion = 0.5 + 0.5 * sin(world_pos.x * 0.11 + world_pos.y * 0.08 + t * 2.4);
	float poison_bubble = 0.5 + 0.5 * sin(world_pos.x * 0.09 - world_pos.y * 0.12 + t * 3.6 + cell_noise * 8.0);
	float lava_heat = 0.5 + 0.5 * sin(world_pos.x * 0.15 + world_pos.y * 0.04 + t * 4.8 + cell_noise * 10.0);

	vec3 final_rgb = base.rgb;
	final_rgb += vec3(0.05, 0.11, 0.14) * blueish * water_motion;
	final_rgb += vec3(0.03, 0.12, 0.04) * greenish * poison_bubble;
	final_rgb += vec3(0.16, 0.08, 0.02) * reddish * lava_heat;

	float water_detail = max(ripple_band, cross_band * 0.75);
	float poison_detail = max(cross_band, ripple_band * 0.5);
	float lava_detail = max(lava_band, ripple_band * 0.45);

	final_rgb -= vec3(0.06, 0.08, 0.09) * blueish * water_detail;
	final_rgb -= vec3(0.04, 0.08, 0.03) * greenish * poison_detail;
	final_rgb -= vec3(0.08, 0.03, 0.01) * reddish * lava_detail;

	float edge_shine = 0.5 + 0.5 * sin((world_pos.x + world_pos.y) * 0.18 + t * 2.0);
	final_rgb += vec3(0.06, 0.08, 0.09) * blueish * edge_shine * wake_core;
	final_rgb += vec3(0.02, 0.07, 0.03) * greenish * (1.0 - poison_bubble) * 0.6;
	final_rgb += vec3(0.18, 0.09, 0.02) * reddish * pow(lava_heat, 2.0) * 0.85;

	COLOR = vec4(final_rgb, base.a);
}
