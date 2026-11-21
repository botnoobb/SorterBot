shader_type spatial;

uniform vec4 belt_color : source_color;
uniform vec4 marking_color : source_color;
uniform float pattern_period;
uniform float belt_offset = 0.0;

// Граница плоской части полотна по локальной оси X.
const float BELT_FLAT_END = 0.839;
const float CHEVRON_TIP_OFFSET = 0.122;
const float EDGE_MARGIN = 0.02;
const float FADE_DISTANCE = 0.16;

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
	float tip = mix(CHEVRON_TIP_OFFSET, -0.010, side);
	float distance_to_edge = min(min(x - tail, tip - x), 0.151 - z);
	float aa = max(max(fwidth(belt_position.x), fwidth(belt_position.z)) * 0.5, 0.0001);
	float marking = smoothstep(-aa, aa, distance_to_edge) * step(0.5915, belt_position.y);
	// Один коэффициент затухания для всей стрелки, включая наконечник.
	float chevron_center = belt_position.x - x;
	float end_clearance = BELT_FLAT_END - CHEVRON_TIP_OFFSET - EDGE_MARGIN - abs(chevron_center);
	marking *= smoothstep(0.0, FADE_DISTANCE, end_clearance);
	ALBEDO = mix(belt_color.rgb, marking_color.rgb, marking);
	ROUGHNESS = mix(0.88, 0.77, marking);
}
