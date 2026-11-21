shader_type spatial;

uniform vec4 belt_color : source_color;
uniform vec4 marking_color : source_color;
uniform float pattern_period;
uniform float belt_offset = 0.0;

varying vec3 belt_position;

void vertex() {
	belt_position = VERTEX;
}

void fragment() {
	// Координаты шеврона повторяют разметку исходной модели конвейера.
	float x = mod(belt_position.x - belt_offset + pattern_period * 0.5, pattern_period)
			- pattern_period * 0.5;
	float z = abs(belt_position.z);
	float side = clamp(z / 0.151, 0.0, 1.0);
	float tail = mix(0.014, -0.118, side);
	float tip = mix(0.122, -0.010, side);
	float distance_to_edge = min(min(x - tail, tip - x), 0.151 - z);
	float aa = max(max(fwidth(belt_position.x), fwidth(belt_position.z)) * 0.5, 0.0001);
	float marking = smoothstep(-aa, aa, distance_to_edge) * step(0.5915, belt_position.y);
	ALBEDO = mix(belt_color.rgb, marking_color.rgb, marking);
	ROUGHNESS = mix(0.88, 0.77, marking);
}
