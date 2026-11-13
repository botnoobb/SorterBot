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
	var globals: Dictionary[String, String] = {}
	var functions: Dictionary[String, int] = {}
	var call_stack: Array[Dictionary] = []
	var index := 0
	var completed_step := false
	while index < commands.size():
		# Определения и переходы обрабатываются между подсвечиваемыми инструкциями.
		var instruction := commands[index]
		match instruction.type:
			ProgramCommand.Type.DEFINE_FUNCTION:
				functions[instruction.function_name] = index
				globals.erase(instruction.function_name)
				index = instruction.jump_index
				continue
			ProgramCommand.Type.JUMP:
				index = instruction.jump_index
				continue
			ProgramCommand.Type.RETURN_FUNCTION:
				var frame: Dictionary = call_stack.pop_back()
				index = frame.return_index
				continue
		if completed_step and _pause_requested and not _stop_requested:
			is_paused = true
			pause_changed.emit(true)
			while is_paused and not _stop_requested:
				await tree.process_frame
			if is_paused:
				is_paused = false
				pause_changed.emit(false)
		if _stop_requested:
			break
		var variables: Dictionary[String, String] = globals
		var local_names: Array[String] = []
		if not call_stack.is_empty():
			var frame := call_stack.back() as Dictionary
			variables = frame.variables
			local_names = commands[frame.definition_index].local_names
		var command := instruction
		var next_index := index + 1
		step_started.emit(command.line)
		if not command.function_name.is_empty() and (
				functions.has(command.function_name)
				or command.type == ProgramCommand.Type.CALL_FUNCTION
		):
			var name := command.function_name
			var definition_index: int = functions.get(name, -1)
			var parameter_count := 0
			if definition_index >= 0:
				parameter_count = commands[definition_index].parameters.size()
			error = _check_function_call(
					command, definition_index, parameter_count, variables, local_names, call_stack
			)
			if error != null:
				is_running = false
				return false
			var definition := commands[definition_index]
			var scope := globals.duplicate()
			for local_name: String in definition.local_names:
				scope.erase(local_name)
			for argument_index: int in command.arguments.size():
				var value := _read_expression(command.arguments[argument_index], variables, read_box_color)
				if error != null:
					is_running = false
					return false
				scope[definition.parameters[argument_index]] = value
			call_stack.append({
				"variables": scope,
				"definition_index": definition_index,
				"return_index": next_index,
			})
			next_index = definition_index + 1
			await tree.create_timer(STEP_DURATION).timeout
		elif command.error != null:
			error = command.error
			is_running = false
			return false
		# Следующая команда ждёт завершения движения робота.
		elif command.type == ProgramCommand.Type.CONDITION:
			var matches := _condition_matches(command, variables, read_box_color)
			if error != null:
				is_running = false
				return false
			if not matches:
				next_index = command.jump_index
			await tree.create_timer(STEP_DURATION).timeout
		elif command.type == ProgramCommand.Type.PASS:
			await tree.create_timer(STEP_DURATION).timeout
		elif command.type in [ProgramCommand.Type.ASSIGN, ProgramCommand.Type.PRINT]:
			var operand := command.arguments[0] if command.type == ProgramCommand.Type.PRINT else command
			var value := _read_expression(operand, variables, read_box_color)
			if error != null:
				is_running = false
				return false
			if command.type == ProgramCommand.Type.ASSIGN:
				variables[command.target_variable] = value
				if call_stack.is_empty():
					functions.erase(command.target_variable)
			else:
				output_emitted.emit(value)
			await tree.create_timer(STEP_DURATION).timeout
		elif command.type == ProgramCommand.Type.MOVE:
			var movement := command
			if not command.arguments.is_empty() and command.direction == Vector2i.ZERO:
				var operand := command.arguments[0]
				var direction := _read_expression(operand, variables, read_box_color)
				if error == null and not ProgramParser.DIRECTIONS.has(direction):
					error = ProgramDiagnostic.new(
							"ValueError", "invalid direction '%s'" % direction,
							command.program_source, command.line, operand.operand_column, true
					)
				if error != null:
					is_running = false
					return false
				movement = ProgramCommand.new(ProgramCommand.Type.MOVE, command.line)
				movement.direction = ProgramParser.DIRECTIONS[direction]
			action_error = await _perform_action(movement, move_action, game_action, tree)
		else:
			action_error = await _perform_action(command, move_action, game_action, tree)
		if not action_error.is_empty():
			is_running = false
			return false
		completed_step = true
		if _stop_requested:
			break
		index = next_index
	was_stopped = _stop_requested
	is_running = false
	return not was_stopped


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


func _perform_action(
		command: ProgramCommand, move_action: Callable, game_action: Callable, tree: SceneTree
) -> String:
	if game_action.is_valid():
		var message: String = await game_action.call(command, STEP_DURATION)
		return message
	if command.type == ProgramCommand.Type.MOVE:
		await move_action.call(command.direction, STEP_DURATION)
	else:
		output_emitted.emit(command.text)
		await tree.create_timer(STEP_DURATION).timeout
	return ""


func _check_function_call(
		command: ProgramCommand, definition_index: int, parameter_count: int,
		variables: Dictionary[String, String], local_names: Array[String], call_stack: Array[Dictionary]
) -> ProgramDiagnostic:
	var name := command.function_name
	var error_type: String
	var message: String
	if variables.has(name):
		error_type = "TypeError"
		message = "'str' object is not callable"
	elif name in local_names:
		error_type = "UnboundLocalError"
		message = "local variable '%s' is not assigned" % name
	elif definition_index < 0:
		error_type = "NameError"
		message = "name '%s' is not defined" % name
	elif command.arguments.size() != parameter_count:
		error_type = "TypeError"
		message = "%s() takes %d positional arguments (%d given)" % [
			name, parameter_count, command.arguments.size(),
		]
	else:
		for frame: Dictionary in call_stack:
			if frame.definition_index == definition_index:
				return ProgramDiagnostic.new(
						"RuntimeError", "recursive calls are not supported", command.program_source,
						command.line, command.call_column, true
				)
		return null
	return ProgramDiagnostic.new(
			error_type, message, command.program_source, command.line, command.call_column, true
	)


func _condition_matches(
		command: ProgramCommand, variables: Dictionary[String, String], read_box_color: Callable
) -> bool:
	if command.right_operand == null:
		return command.constant_condition
	var left := _read_expression(command, variables, read_box_color)
	if error != null:
		return false
	var right := _read_expression(command.right_operand, variables, read_box_color)
	return left == right


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
