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


func run(
		commands: Array[ProgramCommand], move_action: Callable, tree: SceneTree,
		single_step: bool = false, game_action: Callable = Callable(),
		read_box_color: Callable = Callable()
) -> bool:
	if is_running:
		return false
	error = null
	action_error = ""
	was_stopped = false
	_stop_requested = false
	_pause_requested = single_step
	is_paused = false
	is_running = true
	var variables: Dictionary[String, String] = {}
	var index := 0
	while index < commands.size():
		var command: ProgramCommand = commands[index]
		var next_index := index + 1
		step_started.emit(command.line)
		if command.error != null:
			error = command.error
			is_running = false
			return false
		# Следующая команда ждёт завершения движения робота.
		if command.type == ProgramCommand.Type.IF:
			var left := _read_expression(command, variables, read_box_color)
			if error != null:
				is_running = false
				return false
			var right := _read_expression(command.right_operand, variables, read_box_color)
			if error != null:
				is_running = false
				return false
			if left != right:
				next_index = command.jump_index
			await tree.create_timer(STEP_DURATION).timeout
		elif command.type in [ProgramCommand.Type.ASSIGN, ProgramCommand.Type.PRINT]:
			var value := _read_expression(command, variables, read_box_color)
			if error != null:
				is_running = false
				return false
			if command.type == ProgramCommand.Type.ASSIGN:
				variables[command.target_variable] = value
			else:
				output_emitted.emit(value)
			await tree.create_timer(STEP_DURATION).timeout
		elif game_action.is_valid():
			action_error = await game_action.call(command, STEP_DURATION)
			if not action_error.is_empty():
				is_running = false
				return false
		elif command.type == ProgramCommand.Type.MOVE:
			await move_action.call(command.direction, STEP_DURATION)
		else:
			output_emitted.emit(command.text)
			await tree.create_timer(STEP_DURATION).timeout
		# Переход через невыбранную ветвь не является шагом программы.
		while next_index < commands.size() and commands[next_index].type == ProgramCommand.Type.JUMP:
			next_index = commands[next_index].jump_index
		if _pause_requested and not _stop_requested and next_index < commands.size():
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
		index = next_index
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


func _read_expression(
		command: ProgramCommand, variables: Dictionary[String, String], read_box_color: Callable
) -> String:
	match command.operand_kind:
		ProgramCommand.OperandKind.LITERAL:
			return command.text
		ProgramCommand.OperandKind.VARIABLE:
			if variables.has(command.text):
				return variables[command.text]
			error = ProgramDiagnostic.new(
					"NameError", "name '%s' is not defined" % command.text,
					command.program_source, command.line, command.operand_column, true
			)
		ProgramCommand.OperandKind.BOX_COLOR:
			if read_box_color.is_valid():
				return read_box_color.call()
			error = ProgramDiagnostic.new(
					"RuntimeError", "box color is unavailable",
					command.program_source, command.line, command.operand_column, true
			)
	return ""
