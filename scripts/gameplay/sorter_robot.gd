extends Node3D
class_name SorterRobot

const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
const QUARTER_TURN := PI / 2.0
# Размеры и скорость верхней ветви гусеницы в исходной модели.
const HALF_TRACK_SPACING := 0.268
const TRACK_TRAVEL_PER_SECOND := 0.52

var cell: Vector2i = Vector2i.ZERO
var direction := Vector2i.DOWN
var _spawn_pose: Transform3D
var _spawn_cell: Vector2i
var _spawn_direction: Vector2i

@onready var _left_track: AnimationPlayer = $Shtabel/TrackL
@onready var _right_track: AnimationPlayer = $Shtabel/TrackR


func _ready() -> void:
	_spawn_pose = transform
	_spawn_cell = Vector2i(roundi(position.x), roundi(position.z))
	var heading_index: int = posmod(roundi(rotation.y / QUARTER_TURN), DIRECTIONS.size())
	_spawn_direction = DIRECTIONS[heading_index]
	_left_track.assigned_animation = &"Drive_L"
	_right_track.assigned_animation = &"Drive_R"
	reset_pose()


func reset_pose() -> void:
	transform = _spawn_pose
	cell = _spawn_cell
	direction = _spawn_direction
	_seek_tracks(Vector2.ZERO)


func move(next_direction: Vector2i, duration: float) -> void:
	var destination: Vector2i = cell + next_direction
	var target := Vector3(destination.x, position.y, destination.y)
	var tween: Tween = create_tween()
	var phase := Vector2(
			_left_track.current_animation_position, _right_track.current_animation_position
	)
	if next_direction != direction:
		var target_heading_index: int = DIRECTIONS.find(next_direction)
		var current_heading_index: int = DIRECTIONS.find(direction)
		# Для разворота на 180° всегда поворачиваем вправо.
		var turn_steps: int = posmod(
				target_heading_index - current_heading_index + 2, DIRECTIONS.size()
		) - 2
		var turn_duration := duration * absi(turn_steps) / 4.0
		var yaw_delta: float = turn_steps * QUARTER_TURN
		var turn_clip_offset: float = yaw_delta * HALF_TRACK_SPACING / TRACK_TRAVEL_PER_SECOND
		var turn_phase := phase + Vector2(turn_clip_offset, -turn_clip_offset)
		tween.tween_property(self, "rotation:y", rotation.y + yaw_delta, turn_duration)
		tween.parallel().tween_method(_seek_tracks, phase, turn_phase, turn_duration)
		var target_yaw: float = target_heading_index * QUARTER_TURN
		tween.tween_callback(_finish_turn.bind(next_direction, target_yaw))
		phase = turn_phase
		duration -= turn_duration
	tween.tween_property(self, "position", target, duration)
	var drive_clip_offset: float = 1.0 / (TRACK_TRAVEL_PER_SECOND * $Shtabel.scale.z)
	var drive_phase := phase + Vector2.ONE * drive_clip_offset
	tween.parallel().tween_method(_seek_tracks, phase, drive_phase, duration)
	await tween.finished
	cell = destination


func _finish_turn(next_direction: Vector2i, yaw: float) -> void:
	rotation.y = yaw
	direction = next_direction


func _seek_tracks(phase: Vector2) -> void:
	_left_track.seek(fposmod(phase.x, _left_track.current_animation_length), true)
	_right_track.seek(fposmod(phase.y, _right_track.current_animation_length), true)
