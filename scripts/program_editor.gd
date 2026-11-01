extends PanelContainer
class_name ProgramEditor

signal run_requested(source: String)

@onready var _code: CodeEdit = $Margin/Content/Code
@onready var _run_button: Button = $Margin/Content/Run
@onready var _message: Label = $Margin/Content/Message


func _ready() -> void:
	_run_button.pressed.connect(_on_run_pressed)


func set_running(running: bool) -> void:
	_run_button.disabled = running
	_code.editable = not running


func show_message(message: String) -> void:
	_message.text = message


func _on_run_pressed() -> void:
	run_requested.emit(_code.text)
