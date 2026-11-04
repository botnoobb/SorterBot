extends RefCounted
class_name ProgramExecutor

signal step_started(line: int)
signal output_emitted(message: String)
signal pause_changed(paused: bool)

const STEP_DURATION: float = 0.35

var is_running: bool = false
var is_paused: bool = false
var _pause_requested: bool = false
var was_stopped: bool = false
var _stop_requested: bool = false
var error: ProgramDiagnostic


func run(commands: Array[ProgramCommand], move_action: Callable, tree: SceneTree) -> bool:
	if is_running:
		return false
	error = null
	was_stopped = false
	_stop_requested = false
	_pause_requested = false
	is_paused = false
	is_running = true
	for index: int in range(commands.size()):
		var command: ProgramCommand = commands[index]
		step_started.emit(command.line)
		if command.error != null:
			error = command.error
			is_running = false
			return false
		# Следующая команда ждёт завершения движения робота.
		if command.type == ProgramCommand.Type.MOVE:
			await move_action.call(command.direction, STEP_DURATION)
		else:
			output_emitted.emit(command.text)
			await tree.create_timer(STEP_DURATION).timeout
		if _pause_requested and not _stop_requested and index + 1 < commands.size():
			is_paused = true
			pause_changed.emit(true)
			while is_paused and not _stop_requested:
				await tree.process_frame
			is_paused = false
			pause_changed.emit(false)
		if _stop_requested:
			was_stopped = true
			is_running = false
			return false
	is_running = false
	return true


func request_stop() -> void:
	if is_running:
		_stop_requested = true


func request_pause() -> void:
	if is_running and not is_paused:
		_pause_requested = true


func resume() -> void:
	if is_paused:
		_pause_requested = false
		is_paused = false
