shader_type spatial;
render_mode unshaded;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Сетка закреплена в мире, даже когда поле следует за роботом.
	vec2 cell_edge = abs(fract(world_position.xz + 0.5) - 0.5);
	float line = step(0.475, max(cell_edge.x, cell_edge.y));
	ALBEDO = mix(vec3(0.12, 0.17, 0.22), vec3(0.28, 0.36, 0.42), line);
}
