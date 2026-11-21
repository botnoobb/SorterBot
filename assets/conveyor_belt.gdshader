shader_type spatial;

uniform vec4 belt_color : source_color;
uniform vec4 marking_color : source_color;
uniform vec2 drum_center;
uniform float drum_radius;
uniform float pattern_period;
uniform float belt_offset = 0.0;

varying vec3 belt_position;

void vertex() {
	belt_position = VERTEX;
}

float distance_along_belt(vec2 position) {
	float height = position.y - drum_center.y;
	// Начало отсчёта на середине верхней ветви. На барабанах считаем длину дуги.
	if (position.x > drum_center.x) {
		return drum_center.x + drum_radius * atan(position.x - drum_center.x, height);
	}
	if (position.x < -drum_center.x) {
		return -drum_center.x - drum_radius * atan(-position.x - drum_center.x, height);
	}
	// На нижней ветви направление обратное. Шов замыкается через целое число шевронов.
	return height >= 0.0 ? position.x : 2.0 * drum_center.x + PI * drum_radius - position.x;
}

void fragment() {
	// Координаты шеврона повторяют разметку исходной модели конвейера.
	float along_belt = distance_along_belt(belt_position.xy);
	float x = mod(along_belt - belt_offset + pattern_period * 0.5, pattern_period)
			- pattern_period * 0.5;
	float z = abs(belt_position.z);
	float side = clamp(z / 0.151, 0.0, 1.0);
	float tail = mix(0.014, -0.118, side);
	float tip = mix(0.122, -0.010, side);
	float distance_to_edge = min(min(x - tail, tip - x), 0.151 - z);
	float along_pixel = length(dFdx(belt_position.xy)) + length(dFdy(belt_position.xy));
	float aa = max(max(along_pixel, fwidth(belt_position.z)) * 0.5, 0.0001);
	float marking = smoothstep(-aa, aa, distance_to_edge);
	ALBEDO = mix(belt_color.rgb, marking_color.rgb, marking);
	ROUGHNESS = mix(0.88, 0.77, marking);
}
