extends Node3D
class_name SorterConveyor

const BELT_SHADER := preload("res://assets/conveyor_belt.gdshader")
# Размеры верхней и нижней ветвей и барабанов из модели конвейера.
const DRUM_CENTER_X := 0.839
const DRUM_CENTER_Y := 0.437
const DRUM_RADIUS := 0.155
const CHEVRONS_PER_LOOP := 8
const PATTERN_PERIOD := (4.0 * DRUM_CENTER_X + TAU * DRUM_RADIUS) / CHEVRONS_PER_LOOP
const BELT_END_X := DRUM_CENTER_X + DRUM_RADIUS
const BELT_SURFACE := 0
const MARKING_SURFACE := 1

var _belt_material := ShaderMaterial.new()

@onready var _belt: MeshInstance3D = get_node("Полотно с разметкой")


func _ready() -> void:
	# Запечённые шевроны заменяем подвижным рисунком, сохраняя импортированный меш.
	var mesh := _belt.mesh.duplicate() as ArrayMesh
	var rubber := mesh.surface_get_material(BELT_SURFACE) as StandardMaterial3D
	var marking := mesh.surface_get_material(MARKING_SURFACE) as StandardMaterial3D
	mesh.surface_remove(MARKING_SURFACE)
	_belt.mesh = mesh
	_belt_material.shader = BELT_SHADER
	_belt_material.set_shader_parameter(&"belt_color", rubber.albedo_color)
	_belt_material.set_shader_parameter(&"marking_color", marking.albedo_color)
	_belt_material.set_shader_parameter(&"drum_center", Vector2(DRUM_CENTER_X, DRUM_CENTER_Y))
	_belt_material.set_shader_parameter(&"drum_radius", DRUM_RADIUS)
	_belt_material.set_shader_parameter(&"pattern_period", PATTERN_PERIOD)
	_belt_material.set_shader_parameter(&"belt_offset", 0.0)
	_belt.set_surface_override_material(BELT_SURFACE, _belt_material)


func get_belt_offset() -> float:
	return _belt_material.get_shader_parameter(&"belt_offset")


func queue_transport(tween: Tween, cargo: Node3D, destination: Vector3, duration: float) -> void:
	var start: Vector3 = cargo.global_position
	var start_x: float = to_local(start).x
	var start_offset: float = get_belt_offset()
	tween.tween_method(
			func(world_position: Vector3) -> void:
				cargo.global_position = world_position
				# На входе коробка ещё немного едет вперёд после края полотна.
				var distance: float = minf(to_local(world_position).x, BELT_END_X) - start_x
				_belt_material.set_shader_parameter(
						&"belt_offset", fposmod(start_offset + distance, PATTERN_PERIOD)
				),
			start, destination, duration
	)
