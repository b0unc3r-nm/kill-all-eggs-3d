shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float distance_to_center = length(centered * vec2(1.0, 1.18));
	float vignette = smoothstep(0.34, 0.82, distance_to_center);
	float scanline = 0.5 + 0.5 * sin(UV.y * 1500.0);
	COLOR = vec4(0.0, 0.012, 0.018, vignette * vignette_strength + scanline * 0.012);
}
