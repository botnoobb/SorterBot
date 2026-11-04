extends PanelContainer
class_name ProgramEditor

signal run_requested(source: String)
signal stop_requested()

const EXECUTION_COLOR := Color(1.0, 0.85, 0.25, 0.22)

var _running: bool = false
var _execution_line: int = -1

@onready var _code: CodeEdit = $Margin/Content/Code
@onready var _run_button: Button = $Margin/Content/Header/Run
@onready var _stop_button: Button = $Margin/Content/Header/Stop
@onready var _message: Label = $Margin/Content/Message
@onready var _output: OutputPanel = $Margin/Content/OutputPanel


func _ready() -> void:
	_run_button.pressed.connect(_on_run_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_code.text_changed.connect(_on_text_changed)


func set_running(running: bool) -> void:
	_run_button.disabled = running
	_running = running
	_stop_button.disabled = not running


func show_message(message: String) -> void:
	_message.text = message


func append_output(message: String) -> void:
	_output.append_message(message)


func clear_output() -> void:
	_output.clear_messages()


func show_error(message: String) -> void:
	_message.text = ""
	_output.append_error(message)


func highlight_execution_line(source_line: int) -> void:
	clear_execution_line()
	_execution_line = source_line - 1
	_code.set_line_background_color(_execution_line, EXECUTION_COLOR)
	_code.set_caret_line(_execution_line)
	_code.adjust_viewport_to_caret()


func clear_execution_line() -> void:
	if _execution_line >= 0 and _execution_line < _code.get_line_count():
		_code.set_line_background_color(_execution_line, Color(0, 0, 0, 0))
	_execution_line = -1


func _on_run_pressed() -> void:
	run_requested.emit(_code.text)


func _on_stop_pressed() -> void:
	stop_requested.emit()


func _on_text_changed() -> void:
	if _running:
		# Правка могла переместить фон вместе со строками.
		for line: int in range(_code.get_line_count()):
			_code.set_line_background_color(line, Color(0, 0, 0, 0))
		_execution_line = -1
		stop_requested.emit()
