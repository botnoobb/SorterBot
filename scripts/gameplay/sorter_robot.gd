extends Node3D
class_name SorterRobot

const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
const QUARTER_TURN := PI / 2.0
# Размеры и скорость верхней ветви гусеницы в исходной модели.
const HALF_TRACK_SPACING := 0.268
const TRACK_TRAVEL_PER_SECOND := 0.52
const PICKUP := &"Cargo/Pickup"
const DROPOFF := &"Cargo/Dropoff"
const CARGO_ANIMATION_SPEED := 2.0

var cell: Vector2i = Vector2i.ZERO
var direction := Vector2i.DOWN
var _spawn_pose: Transform3D
var _spawn_cell: Vector2i
var _spawn_direction: Vector2i

@onready var cargo_socket: Node3D = $Shtabel/Robot_Root/Lift_L/Reach_L/CargoSocket
@onready var _left_track: AnimationPlayer = $Shtabel/TrackL
@onready var _right_track: AnimationPlayer = $Shtabel/TrackR
@onready var _cargo_player: AnimationPlayer = $Shtabel/AnimationPlayer


func _ready() -> void:
	_spawn_pose = transform
	_spawn_cell = Vector2i(roundi(position.x), roundi(position.z))
	var heading_index: int = posmod(roundi(rotation.y / QUARTER_TURN), DIRECTIONS.size())
	_spawn_direction = DIRECTIONS[heading_index]
	_left_track.assigned_animation = &"Drive_L"
	_right_track.assigned_animation = &"Drive_R"
	_prepare_cargo_animations()
	reset_pose()


func reset_pose() -> void:
	transform = _spawn_pose
	cell = _spawn_cell
	direction = _spawn_direction
	_seek_tracks(Vector2.ZERO)
	_cargo_player.assigned_animation = PICKUP
	_cargo_player.seek(0.0, true)


func face(next_direction: Vector2i, duration: float) -> void:
	var turn_steps: int = _get_turn_steps(next_direction)
	if turn_steps == 0:
		return
	var tween: Tween = create_tween()
	var turn_duration: float = _turn_duration(turn_steps, duration)
	_queue_turn(tween, next_direction, turn_steps, turn_duration, _track_phase())
	await tween.finished


func animate_cargo(grabbing: bool, transfer: Callable) -> void:
	var clip: StringName = PICKUP
	var contact_frame := 40.0
	if not grabbing:
		clip = DROPOFF
		contact_frame = 25.0
	_cargo_player.assigned_animation = clip
	var contact_time: float = contact_frame / 30.0
	var end_time: float = _cargo_player.current_animation_length
	var tween: Tween = create_tween()
	tween.tween_method(_seek_cargo, 0.0, contact_time, contact_time / CARGO_ANIMATION_SPEED)
	tween.tween_callback(transfer)
	tween.tween_method(
			_seek_cargo, contact_time, end_time, (end_time - contact_time) / CARGO_ANIMATION_SPEED
	)
	await tween.finished


func move(next_direction: Vector2i, duration: float) -> void:
	var destination: Vector2i = cell + next_direction
	var target := Vector3(destination.x, position.y, destination.y)
	var tween: Tween = create_tween()
	var phase: Vector2 = _track_phase()
	var turn_steps: int = _get_turn_steps(next_direction)
	if turn_steps != 0:
		var turn_duration: float = _turn_duration(turn_steps, duration)
		phase = _queue_turn(tween, next_direction, turn_steps, turn_duration, phase)
		duration -= turn_duration
	tween.tween_property(self, "position", target, duration)
	var drive_clip_offset: float = 1.0 / (TRACK_TRAVEL_PER_SECOND * $Shtabel.scale.z)
	var drive_phase := phase + Vector2.ONE * drive_clip_offset
	tween.parallel().tween_method(_seek_tracks, phase, drive_phase, duration)
	await tween.finished
	cell = destination


func _get_turn_steps(next_direction: Vector2i) -> int:
	# Для разворота на 180° всегда поворачиваем вправо.
	return posmod(
			DIRECTIONS.find(next_direction) - DIRECTIONS.find(direction) + 2, DIRECTIONS.size()
	) - 2


func _turn_duration(turn_steps: int, duration: float) -> float:
	return duration * absi(turn_steps) / 4.0


func _queue_turn(
		tween: Tween, next_direction: Vector2i, turn_steps: int, duration: float, phase: Vector2
) -> Vector2:
	var yaw_delta: float = turn_steps * QUARTER_TURN
	var clip_offset: float = yaw_delta * HALF_TRACK_SPACING / TRACK_TRAVEL_PER_SECOND
	var turn_phase := phase + Vector2(clip_offset, -clip_offset)
	tween.tween_property(self, "rotation:y", rotation.y + yaw_delta, duration)
	tween.parallel().tween_method(_seek_tracks, phase, turn_phase, duration)
	var target_yaw: float = DIRECTIONS.find(next_direction) * QUARTER_TURN
	tween.tween_callback(_finish_turn.bind(next_direction, target_yaw))
	return turn_phase


func _finish_turn(next_direction: Vector2i, yaw: float) -> void:
	rotation.y = yaw
	direction = next_direction


func _seek_tracks(phase: Vector2) -> void:
	_left_track.seek(fposmod(phase.x, _left_track.current_animation_length), true)
	_right_track.seek(fposmod(phase.y, _right_track.current_animation_length), true)


func _track_phase() -> Vector2:
	return Vector2(_left_track.current_animation_position, _right_track.current_animation_position)


func _prepare_cargo_animations() -> void:
	var library := AnimationLibrary.new()
	for clip_name: StringName in [&"Pickup", &"Dropoff"]:
		var clip := _cargo_player.get_animation(clip_name).duplicate() as Animation
		# Godot добавляет статические дорожки гусениц даже в клипы захватов.
		for index: int in range(clip.get_track_count() - 1, -1, -1):
			var path: NodePath = clip.track_get_path(index)
			if path.get_name_count() > 1 and path.get_name(1) in [&"Track_Root_L", &"Track_Root_R"]:
				clip.remove_track(index)
		library.add_animation(clip_name, clip)
	_cargo_player.add_animation_library(&"Cargo", library)
	_cargo_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _seek_cargo(time: float) -> void:
	_cargo_player.seek(time, true)
