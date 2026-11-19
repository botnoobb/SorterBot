extends Node3D
class_name SorterRobot

const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
const QUARTER_TURN := PI / 2.0

var cell: Vector2i = Vector2i.ZERO
var direction := Vector2i.DOWN
var _spawn_pose: Transform3D
var _spawn_cell: Vector2i
var _spawn_direction: Vector2i


func _ready() -> void:
	_spawn_pose = transform
	_spawn_cell = Vector2i(roundi(position.x), roundi(position.z))
	var heading_index: int = posmod(roundi(rotation.y / QUARTER_TURN), DIRECTIONS.size())
	_spawn_direction = DIRECTIONS[heading_index]
	reset_pose()


func reset_pose() -> void:
	transform = _spawn_pose
	cell = _spawn_cell
	direction = _spawn_direction


func move(next_direction: Vector2i, duration: float) -> void:
	var destination: Vector2i = cell + next_direction
	var target := Vector3(destination.x, position.y, destination.y)
	var tween: Tween = create_tween()
	if next_direction != direction:
		var heading_index: int = DIRECTIONS.find(next_direction)
		var current_heading: int = DIRECTIONS.find(direction)
		# Для разворота на 180° всегда поворачиваем вправо.
		var turn_steps: int = posmod(heading_index - current_heading + 2, DIRECTIONS.size()) - 2
		var turn_duration := duration * absi(turn_steps) / 4.0
		var target_yaw: float = rotation.y + turn_steps * QUARTER_TURN
		tween.tween_property(self, "rotation:y", target_yaw, turn_duration)
		tween.tween_callback(_finish_turn.bind(next_direction, heading_index * QUARTER_TURN))
		duration -= turn_duration
	tween.tween_property(self, "position", target, duration)
	await tween.finished
	cell = destination


func _finish_turn(next_direction: Vector2i, yaw: float) -> void:
	rotation.y = yaw
	direction = next_direction
