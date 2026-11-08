extends PanelContainer
class_name ProgramEditor

signal run_requested(source: String)
signal stop_requested()
signal step_requested(source: String)
signal cargo_reset_requested()

const EXECUTION_COLOR := Color(1.0, 0.85, 0.25, 0.22)

var _error_line: int = -1
var _running: bool = false
var _execution_line: int = -1

@onready var _code: CodeEdit = $Margin/Content/Code
@onready var _run_button: Button = $Margin/Content/Header/Run
@onready var _step_button: Button = $Margin/Content/Header/Step
@onready var _stop_button: Button = $Margin/Content/Header/Stop
@onready var _reset_cargo_button: Button = $Margin/Content/ResetCargo
@onready var _message: Label = $Margin/Content/Message
@onready var _output: OutputPanel = $Margin/Content/OutputPanel


func _ready() -> void:
	_output.error_location_clicked.connect(_on_error_location_clicked)
	_run_button.pressed.connect(_on_run_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_code.text_changed.connect(_on_text_changed)
	_step_button.pressed.connect(_on_step_pressed)
	_reset_cargo_button.pressed.connect(func() -> void: cargo_reset_requested.emit())
	_step_button.disabled = false
	_step_button.tooltip_text = "Выполнить одну инструкцию"


func set_running(running: bool) -> void:
	_run_button.disabled = false
	_run_button.text = "Ⅱ" if running else "▶"
	_run_button.tooltip_text = "Пауза после текущей инструкции" if running else "Запустить"
	_step_button.disabled = running
	_running = running
	_stop_button.disabled = not running


func set_paused(paused: bool) -> void:
	_step_button.disabled = not paused
	_run_button.text = "▶" if paused else "Ⅱ"
	_run_button.tooltip_text = "Продолжить" if paused else "Пауза после текущей инструкции"
	show_message("Программа на паузе" if paused else "Программа выполняется…")


func show_message(message: String) -> void:
	_message.text = message


func append_output(message: String) -> void:
	_output.append_message(message)


func clear_output() -> void:
	_output.clear_messages()
	_clear_error_line()


func show_error(message: String, line: int = 0, column: int = 0) -> void:
	_message.text = ""
	_output.append_error(message, line, column)
	if line > 0 and line <= _code.get_line_count():
		_clear_error_line()
		_error_line = line - 1
		_code.set_line_background_color(_error_line, Color(1.0, 0.2, 0.2, 0.22))


func highlight_execution_line(source_line: int) -> void:
	clear_execution_line()
	_execution_line = source_line - 1
	_code.set_line_background_color(_execution_line, EXECUTION_COLOR)
	# Прокрутка к инструкции не должна перемещать курсор пользователя.
	_code.set_line_as_center_visible(_execution_line)


func show_action_error(message: String) -> void:
	_message.text = ""
	_output.append_action_error(message)


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


func _on_step_pressed() -> void:
	step_requested.emit(_code.text)


func _clear_error_line() -> void:
	# После правок фон может переместиться вместе со строкой.
	if _error_line >= 0:
		for line: int in range(_code.get_line_count()):
			_code.set_line_background_color(line, Color(0, 0, 0, 0))
	_error_line = -1


func _on_error_location_clicked(line: int, column: int) -> void:
	if line < 1 or line > _code.get_line_count():
		return
	_code.deselect()
	_code.set_caret_line(line - 1)
	_code.set_caret_column(clampi(column - 1, 0, _code.get_line(line - 1).length()))
	_code.adjust_viewport_to_caret()
	_code.grab_focus()
