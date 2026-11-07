extends Control

var _parser := ProgramParser.new()
var _executor := ProgramExecutor.new()

@onready var _editor: ProgramEditor = $Layout/ProgramEditor
@onready var _field: SorterField = $Layout/Field/Viewport/World
@onready var _goal: Label = $Goal
@onready var _robot: SorterRobot = $Layout/Field/Viewport/World/Robot


func _ready() -> void:
	_field.cargo_delivered.connect(func() -> void: _goal.text = "Коробка доставлена")
	_editor.run_requested.connect(_on_run_requested)
	_editor.step_requested.connect(_on_step_requested)
	_editor.stop_requested.connect(_executor.request_stop)
	_executor.output_emitted.connect(_editor.append_output)
	_executor.pause_changed.connect(_editor.set_paused)
	_executor.step_started.connect(_editor.highlight_execution_line)


func _on_run_requested(source: String) -> void:
	if _executor.is_running:
		if _executor.is_paused:
			_executor.resume()
		else:
			_executor.request_pause()
		return
	_start_program(source)


func _on_step_requested(source: String) -> void:
	if _executor.is_running:
		if _executor.is_paused:
			_executor.resume(true)
		return
	_start_program(source, true)


func _start_program(source: String, single_step: bool = false) -> void:
	_editor.clear_output()
	var commands: Array[ProgramCommand] = _parser.parse(source)
	if _parser.error != null:
		_editor.show_error(DiagnosticFormatter.format_error(_parser.error), _parser.error.line, _parser.error.column)
		return
	if commands.is_empty():
		_editor.show_message("Введите команду move или print со строковым аргументом.")
		return
	_editor.set_running(true)
	_editor.show_message("Программа выполняется…")
	await _executor.run(commands, _robot.move, get_tree(), single_step, _field.perform)
	_editor.clear_execution_line()
	_editor.set_running(false)
	if not _executor.action_error.is_empty():
		_editor.show_error(_executor.action_error)
	elif _executor.error != null:
		_editor.show_error(DiagnosticFormatter.format_error(_executor.error), _executor.error.line, _executor.error.column)
	elif _executor.was_stopped:
		_editor.show_message("Программа остановлена.")
	else:
		_editor.show_message("Программа завершена.")
