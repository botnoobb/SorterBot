extends RefCounted
class_name ProgramExecutor

signal step_started(line: int)

const STEP_DURATION: float = 0.35

var is_running: bool = false


func run(commands: Array[MoveCommand], move_action: Callable) -> bool:
	if is_running:
		return false
	is_running = true
	for command: MoveCommand in commands:
		step_started.emit(command.line)
		# Следующая команда ждёт завершения движения робота.
		await move_action.call(command.direction, STEP_DURATION)
	is_running = false
	return true
