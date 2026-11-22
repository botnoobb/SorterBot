extends PanelContainer
class_name ProgramEditor

signal run_requested(source: String)
signal stop_requested()
signal step_requested(source: String)
signal cargo_reset_requested()

const EXECUTION_COLOR := Color(1.0, 0.85, 0.25, 0.22)
const DIVIDER_FOCUS_COLOR := Color("#82b4e8")
const DIVIDER_FOCUS_SIZE := Vector2(48.0, 3.0)
const PAUSE_TOOLTIP := "Пауза после текущей инструкции (F5)"
const OUTPUT_COLLAPSE_DISTANCE := 48.0
const OUTPUT_EXPAND_DRAG_DISTANCE := 12.0
const ProgramSyntaxHighlighter = preload("res://scripts/ui/program_syntax_highlighter.gd")

var _error_line: int = -1
var _running: bool = false
var _execution_line: int = -1
var _output_drag_start_offset: int = 0
var _output_collapsed: bool = false
var _expanded_output_offset: int = 0
var _output_drag_start_y: float = -INF

@onready var _editor_split: VSplitContainer = $Margin/Content/EditorSplit
@onready var _output_divider: Control = _editor_split.get_drag_area_controls()[0]
@onready var _code: CodeEdit = $Margin/Content/EditorSplit/Code
@onready var _run_button: Button = $Margin/Content/Header/Run
@onready var _step_button: Button = $Margin/Content/Header/Step
@onready var _stop_button: Button = $Margin/Content/Header/Stop
@onready var _reset_cargo_button: Button = $Margin/Content/ResetCargo
@onready var _message: Label = $Margin/Content/Message
@onready var _output: OutputPanel = $Margin/Content/EditorSplit/OutputPanel


func _ready() -> void:
	_code.syntax_highlighter = ProgramSyntaxHighlighter.new()
	_output.error_location_clicked.connect(_on_error_location_clicked)
	_output.collapse_changed.connect(_on_output_collapse_changed)
	_output_divider.focus_mode = Control.FOCUS_ALL
	_output_divider.tooltip_text = "Высота вывода: стрелки ↑ и ↓ при фокусе (F7)"
	_output_divider.gui_input.connect(_on_output_drag_input)
	_output_divider.draw.connect(_draw_output_divider_focus)
	_output_divider.focus_entered.connect(_output_divider.queue_redraw)
	_output_divider.focus_exited.connect(_output_divider.queue_redraw)
	_run_button.pressed.connect(_on_run_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_code.text_changed.connect(_on_text_changed)
	_step_button.pressed.connect(_on_step_pressed)
	_reset_cargo_button.pressed.connect(func() -> void: cargo_reset_requested.emit())
	_step_button.disabled = false


func set_text_size(value: int) -> void:
	var vertical_scroll := _code.scroll_vertical
	var horizontal_scroll := _code.scroll_horizontal
	_code.add_theme_font_size_override("font_size", value)
	_code.scroll_vertical = vertical_scroll
	_code.scroll_horizontal = horizontal_scroll
	_output.set_text_size(value)


func handle_program_shortcut(event: InputEventKey) -> bool:
	if (
			not event.pressed or event.echo or event.alt_pressed or event.ctrl_pressed
			or event.meta_pressed or (event.shift_pressed and event.keycode != KEY_F5)
	):
		return false

	var button: Button
	match event.keycode:
		KEY_F5:
			button = _stop_button if event.shift_pressed else _run_button
		KEY_F10:
			button = _step_button
		KEY_F8:
			if _output.is_visible_in_tree():
				var messages_had_focus := _output.get_messages_focus_target().has_focus()
				_output.set_collapsed(not _output_collapsed)
				if messages_had_focus:
					_output_divider.grab_focus()
			return true
		_:
			return false
	if button.is_visible_in_tree() and not button.disabled:
		button.pressed.emit()
	return true


func get_keyboard_focus_targets() -> Array[Control]:
	var targets: Array[Control] = []
	for control: Control in [_code, _output_divider, _output.get_messages_focus_target()]:
		if control.is_visible_in_tree():
			targets.append(control)
	return targets


func set_running(running: bool) -> void:
	_run_button.disabled = false
	_run_button.text = "Ⅱ" if running else "▶"
	_run_button.tooltip_text = PAUSE_TOOLTIP if running else "Запустить (F5)"
	_step_button.disabled = running
	_running = running
	_stop_button.disabled = not running


func set_paused(paused: bool) -> void:
	_step_button.disabled = not paused
	_run_button.text = "▶" if paused else "Ⅱ"
	_run_button.tooltip_text = "Продолжить (F5)" if paused else PAUSE_TOOLTIP
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


func _on_output_collapse_changed(collapsed: bool) -> void:
	_output_collapsed = collapsed
	_output_drag_start_y = -INF
	if collapsed:
		_expanded_output_offset = _editor_split.split_offsets[0]
		_editor_split.split_offsets = PackedInt32Array([0])
	else:
		_editor_split.split_offsets = PackedInt32Array([_expanded_output_offset])


func _on_output_drag_input(event: InputEvent) -> void:
	if _output_collapsed and _output_divider.has_focus():
		if event.is_action_pressed("ui_up", true):
			_output.set_collapsed(false)
			_output_divider.accept_event()
			return
		if event.is_action_pressed("ui_down", true):
			_output_divider.accept_event()
			return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _output_collapsed:
		_output_divider.accept_event()
	var position := _output_divider.get_transform() * button.position
	if button.pressed:
		_output_drag_start_y = position.y
		_output_drag_start_offset = _editor_split.split_offsets[0]
		return
	var start_y := _output_drag_start_y
	_output_drag_start_y = -INF
	if button.is_canceled() or start_y == -INF:
		return
	if _output_collapsed:
		if start_y - position.y >= OUTPUT_EXPAND_DRAG_DISTANCE:
			_output.set_collapsed(false)
	elif _editor_split.size.y - position.y <= OUTPUT_COLLAPSE_DISTANCE:
		# Разделитель сначала должен обработать отпускание кнопки.
		_collapse_output_after_drag.call_deferred(_output_drag_start_offset)


func _draw_output_divider_focus() -> void:
	if _output_divider.has_focus():
		var width := minf(DIVIDER_FOCUS_SIZE.x, _output_divider.size.x)
		var size := Vector2(width, DIVIDER_FOCUS_SIZE.y)
		var position := (_output_divider.size - size) * 0.5
		_output_divider.draw_rect(Rect2(position, size), DIVIDER_FOCUS_COLOR)


func _collapse_output_after_drag(previous_offset: int) -> void:
	_editor_split.split_offsets = PackedInt32Array([previous_offset])
	_output.set_collapsed(true)


func _on_error_location_clicked(line: int, column: int) -> void:
	if line < 1 or line > _code.get_line_count():
		return
	_code.deselect()
	_code.set_caret_line(line - 1)
	_code.set_caret_column(clampi(column - 1, 0, _code.get_line(line - 1).length()))
	_code.adjust_viewport_to_caret()
	_code.grab_focus()
