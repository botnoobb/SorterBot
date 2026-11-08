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
var action_error: String = ""
var action_error_line: int = 0


func run(commands: Array[ProgramCommand], move_action: Callable, tree: SceneTree, single_step: bool = false, game_action: Callable = Callable()) -> bool:
	if is_running:
		return false
	error = null
	action_error = ""
	action_error_line = 0
	was_stopped = false
	_stop_requested = false
	_pause_requested = single_step
	is_paused = false
	is_running = true
	var index: int = 0
	while index < commands.size():
		var command: ProgramCommand = commands[index]
		if command.type == ProgramCommand.Type.REPEAT:
			index = command.target
			continue
		step_started.emit(command.line)
		if command.error != null:
			error = command.error
			is_running = false
			return false
		# Следующая команда ждёт завершения движения робота.
		if command.type == ProgramCommand.Type.WHILE:
			# Проверка условия — отдельный шаг; кадр позволяет остановить любой цикл.
			await tree.process_frame
		elif command.type != ProgramCommand.Type.PRINT and game_action.is_valid():
			action_error = await game_action.call(command, STEP_DURATION)
			if not action_error.is_empty():
				action_error_line = command.line
				is_running = false
				return false
		elif command.type == ProgramCommand.Type.MOVE:
			await move_action.call(command.direction, STEP_DURATION)
		else:
			output_emitted.emit(command.text)
			await tree.create_timer(STEP_DURATION).timeout
		index += 1
		if _pause_requested and not _stop_requested and index < commands.size():
			is_paused = true
			pause_changed.emit(true)
			while is_paused and not _stop_requested:
				await tree.process_frame
			if is_paused:
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


func resume(single_step: bool = false) -> void:
	if is_paused:
		_pause_requested = single_step
		is_paused = false
		pause_changed.emit(false)
