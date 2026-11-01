extends Control

var _parser := ProgramParser.new()
var _executor := ProgramExecutor.new()

@onready var _editor: ProgramEditor = $Layout/ProgramEditor
@onready var _robot: SorterRobot = $Layout/Field/Viewport/World/Robot


func _ready() -> void:
	_editor.run_requested.connect(_on_run_requested)
	_executor.step_started.connect(_editor.highlight_execution_line)


func _on_run_requested(source: String) -> void:
	if _executor.is_running:
		return
	var commands: Array[MoveCommand] = _parser.parse(source)
	if not _parser.error_message.is_empty():
		_editor.show_message(_parser.error_message)
		return
	if commands.is_empty():
		_editor.show_message("Введите команду move с направлением в кавычках.")
		return
	_editor.set_running(true)
	_editor.show_message("Программа выполняется…")
	await _executor.run(commands, _robot.move)
	_editor.clear_execution_line()
	_editor.set_running(false)
	_editor.show_message("Программа завершена.")
