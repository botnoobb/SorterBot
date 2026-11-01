extends RefCounted
class_name ProgramExecutor

var is_running: bool = false


func run(commands: Array[MoveCommand], move_action: Callable) -> bool:
	if is_running:
		return false
	is_running = true
	for command: MoveCommand in commands:
		# Следующая команда ждёт завершения движения робота.
		await move_action.call(command.direction)
	is_running = false
	return true
