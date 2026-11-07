shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.018, 0.032, 0.036, 1.0);
uniform vec4 grid_color : source_color = vec4(0.07, 0.27, 0.22, 1.0);
uniform vec4 accent_color : source_color = vec4(0.9, 0.42, 0.12, 1.0);
uniform float grid_scale = 2.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz / grid_scale;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);

	vec2 coord2 = world_pos.xz / (grid_scale * 4.0);
	vec2 grid2 = abs(fract(coord2 - 0.5) - 0.5) / fwidth(coord2);
	float line2 = 1.0 - min(min(grid2.x, grid2.y), 1.0);

	float noise = hash21(floor(world_pos.xz * 2.0));
	vec3 col = base_color.rgb * (0.82 + noise * 0.36);
	col = mix(col, grid_color.rgb, line * 0.16);
	col = mix(col, grid_color.rgb * 1.5, line2 * 0.32);

	float border = smoothstep(19.2, 21.2, max(abs(world_pos.x), abs(world_pos.z)));
	col = mix(col, accent_color.rgb * 0.4, border * 0.32);

	ALBEDO = col;
	METALLIC = 0.18;
	ROUGHNESS = 0.78;
	EMISSION = grid_color.rgb * (line2 * 0.045 + line * 0.008) + accent_color.rgb * border * 0.018;
}
