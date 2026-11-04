extends RefCounted
class_name ProgramExecutor

signal step_started(line: int)
signal output_emitted(message: String)

const STEP_DURATION: float = 0.35

var is_running: bool = false
var was_stopped: bool = false
var _stop_requested: bool = false
var error: ProgramDiagnostic


func run(commands: Array[ProgramCommand], move_action: Callable, tree: SceneTree) -> bool:
	if is_running:
		return false
	error = null
	was_stopped = false
	_stop_requested = false
	is_running = true
	for command: ProgramCommand in commands:
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
		if _stop_requested:
			was_stopped = true
			is_running = false
			return false
	is_running = false
	return true


func request_stop() -> void:
	if is_running:
		_stop_requested = true
