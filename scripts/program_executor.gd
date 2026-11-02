extends RefCounted
class_name ProgramExecutor

signal step_started(line: int)
signal output_emitted(message: String)

const STEP_DURATION: float = 0.35

var is_running: bool = false


func run(commands: Array[ProgramCommand], move_action: Callable, tree: SceneTree) -> bool:
	if is_running:
		return false
	is_running = true
	for command: ProgramCommand in commands:
		step_started.emit(command.line)
		# Следующая команда ждёт завершения движения робота.
		if command.type == ProgramCommand.Type.MOVE:
			await move_action.call(command.direction, STEP_DURATION)
		else:
			output_emitted.emit(command.text)
			await tree.create_timer(STEP_DURATION).timeout
	is_running = false
	return true
