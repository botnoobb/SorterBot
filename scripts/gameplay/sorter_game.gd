extends Control

const EDITOR_LAYOUT_PATH := "user://editor_layout.cfg"
const EDITOR_LAYOUT_SECTION := "editor"
const EDITOR_WIDTH_KEY := "width"
const DIVIDER_LINE_COLOR := Color("#243953")
const DIVIDER_HANDLE_COLOR := Color("#537da9")
const DIVIDER_HANDLE_HOVER_COLOR := Color("#82b4e8")
const DIVIDER_HANDLE_SIZE := Vector2(2, 20)
const REFERENCE_ANIMATION_DURATION := 0.22
const LESSON_REFERENCE_GAP := 16.0
const LESSON_MAX_WIDTH := 380.0
const MOVEMENT_REFERENCE := (
		"Движение\n\nmove(направление) перемещает робота на одну клетку. "
		+ 'Направления: "up", "down", "left", "right".\n\n'
		+ 'Пример:\nmove("up")'
)
const CARGO_REFERENCE := (
		"Работа с коробкой\n\ngrab() берёт коробку на клетке выдачи. "
		+ "put() кладёт её в зоне доставки.\n\n"
		+ 'Пример со старта:\nmove("up")\ngrab()\n'
		+ 'move("right")\nmove("right")\nput()'
)
const OUTPUT_REFERENCE := (
		"Вывод\n\nprint(строка) выводит текст. Строку нужно заключить в кавычки.\n\n"
		+ 'Пример:\nprint("Готово")'
)

var _parser := ProgramParser.new()
var _executor := ProgramExecutor.new()
var _cargo_reset_requested: bool = false

@onready var _editor: ProgramEditor = $Layout/ProgramEditor
@onready var _field: SorterField = $Layout/Field/Viewport/World
@onready var _goal: Label = $Lesson/Content/Goal
@onready var _layout: HSplitContainer = $Layout
@onready var _field_view: Control = $Layout/Field
@onready var _lesson: PanelContainer = $Lesson
@onready var _lesson_details: RichTextLabel = $Lesson/Content/Details
@onready var _lesson_header: HBoxContainer = $Lesson/Content/Header
@onready var _lesson_title: Label = $Lesson/Content/Header/Title
@onready var _lesson_toggle: Button = $Lesson/Content/Header/Toggle
@onready var _reference_panel: Panel = $ReferencePanel
@onready var _reference_compact_top: float = _reference_panel.offset_top
@onready var _reference_sections: VBoxContainer = $ReferencePanel/Content/Sections
@onready var _reference_detail: VBoxContainer = $ReferencePanel/Content/Detail
@onready var _reference_article: RichTextLabel = $ReferencePanel/Content/Detail/Article
@onready var _robot: SorterRobot = $Layout/Field/Viewport/World/Robot


func _ready() -> void:
	_field.cargo_delivered.connect(func() -> void: _goal.text = "Коробка доставлена")
	_editor.run_requested.connect(_on_run_requested)
	_editor.step_requested.connect(_on_step_requested)
	_editor.stop_requested.connect(_executor.request_stop)
	_editor.cargo_reset_requested.connect(_on_cargo_reset_requested)
	_executor.output_emitted.connect(_editor.append_output)
	_executor.pause_changed.connect(_editor.set_paused)
	_executor.step_started.connect(_editor.highlight_execution_line)

	var drag_area: Control = _layout.get_drag_area_controls()[0]
	drag_area.draw.connect(_draw_editor_divider.bind(drag_area))
	drag_area.mouse_entered.connect(drag_area.queue_redraw)
	drag_area.mouse_exited.connect(drag_area.queue_redraw)
	_layout.drag_ended.connect(_save_editor_width, CONNECT_DEFERRED)
	_restore_editor_width.call_deferred()

	$ReferencePanel/Content/Sections/Movement.pressed.connect(
			_open_reference.bind(MOVEMENT_REFERENCE)
	)
	$ReferencePanel/Content/Sections/Cargo.pressed.connect(_open_reference.bind(CARGO_REFERENCE))
	$ReferencePanel/Content/Sections/Output.pressed.connect(_open_reference.bind(OUTPUT_REFERENCE))
	$ReferencePanel/Content/Detail/Back.pressed.connect(_close_reference)
	_lesson_toggle.toggled.connect(_toggle_lesson)
	_field_view.resized.connect(_resize_lesson, CONNECT_DEFERRED)
	_editor.resized.connect(_resize_lesson, CONNECT_DEFERRED)
	_lesson.resized.connect(_sync_reference_top)
	_resize_lesson.call_deferred()


func _resize_lesson() -> void:
	var width := minf(LESSON_MAX_WIDTH, _field_view.size.x - 2.0 * _lesson.offset_left)
	_lesson.size.x = width
	var font_size := _lesson_title.get_theme_default_font_size()
	if _editor.size.x <= ceilf(_editor.get_combined_minimum_size().x):
		var text_width := (
				width - _lesson.get_theme_stylebox("panel").get_minimum_size().x
				- _lesson_title.get_theme_stylebox("normal").get_minimum_size().x
				- _lesson_header.get_theme_constant("separation")
				- _lesson_toggle.get_combined_minimum_size().x
		)
		var font := _lesson_title.get_theme_font("font")
		while font_size > 1:
			var title_size := font.get_string_size(
					_lesson_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			)
			if ceilf(title_size.x) <= text_width:
				break
			font_size -= 1
	_lesson_title.add_theme_font_size_override("font_size", font_size)


func _sync_reference_top() -> void:
	if _reference_detail.visible:
		_reference_panel.offset_top = _lesson.get_rect().end.y + LESSON_REFERENCE_GAP


func _toggle_lesson(expanded: bool) -> void:
	_lesson_details.visible = expanded
	_lesson_toggle.text = "⌃" if expanded else "⌄"
	_lesson_toggle.tooltip_text = "Свернуть задание" if expanded else "Развернуть задание"
	if expanded:
		_lesson.set_anchor_and_offset(
				SIDE_BOTTOM, 1.0, _reference_compact_top - LESSON_REFERENCE_GAP
		)
		if _reference_detail.visible:
			_close_reference()
	else:
		_lesson.set_anchor_and_offset(SIDE_BOTTOM, 0.0, _lesson.offset_top)


func _open_reference(article: String) -> void:
	_lesson_toggle.button_pressed = false
	_reference_article.text = article
	_reference_article.scroll_to_line(0)
	await _animate_reference(true)
	_reference_detail.show()
	_sync_reference_top()


func _close_reference() -> void:
	await _animate_reference(false)
	_reference_sections.show()


func _animate_reference(expanded: bool) -> void:
	_lesson_toggle.disabled = true
	_reference_sections.hide()
	_reference_detail.hide()
	await get_tree().process_frame
	var top_anchor := 0.0 if expanded else 1.0
	var top_offset := (
			_lesson.get_rect().end.y + LESSON_REFERENCE_GAP if expanded else _reference_compact_top
	)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_reference_panel, "anchor_top", top_anchor, REFERENCE_ANIMATION_DURATION)
	tween.tween_property(_reference_panel, "offset_top", top_offset, REFERENCE_ANIMATION_DURATION)
	await tween.finished
	_lesson_toggle.disabled = false


func _draw_editor_divider(drag_area: Control) -> void:
	var center := (drag_area.size * 0.5).floor()
	drag_area.draw_rect(Rect2(center.x, 0, 1, drag_area.size.y), DIVIDER_LINE_COLOR)
	var handle_position := center - DIVIDER_HANDLE_SIZE * 0.5
	var hovered := get_viewport().gui_get_hovered_control() == drag_area
	var handle_color := DIVIDER_HANDLE_HOVER_COLOR if hovered else DIVIDER_HANDLE_COLOR
	drag_area.draw_rect(Rect2(handle_position, DIVIDER_HANDLE_SIZE), handle_color)


func _restore_editor_width() -> void:
	var config := ConfigFile.new()
	if config.load(EDITOR_LAYOUT_PATH) != OK:
		return
	var width: Variant = config.get_value(EDITOR_LAYOUT_SECTION, EDITOR_WIDTH_KEY, 0)
	if typeof(width) != TYPE_INT or width <= 0:
		return
	# Фактическая ширина уже учитывает минимумы, поэтому сначала ограничиваем смещение.
	_layout.clamp_split_offset()
	var offset: int = _layout.split_offsets[0] + roundi(_editor.size.x) - width
	_layout.split_offsets = PackedInt32Array([offset])
	_layout.clamp_split_offset()


func _save_editor_width() -> void:
	var config := ConfigFile.new()
	config.set_value(EDITOR_LAYOUT_SECTION, EDITOR_WIDTH_KEY, roundi(_editor.size.x))
	var error := config.save(EDITOR_LAYOUT_PATH)
	if error != OK:
		push_warning("Не удалось сохранить ширину редактора: %s" % error_string(error))


func _on_run_requested(source: String) -> void:
	if _cargo_reset_requested:
		return
	if _executor.is_running:
		if _executor.is_paused:
			_executor.resume()
		else:
			_executor.request_pause()
		return
	_start_program(source)


func _on_step_requested(source: String) -> void:
	if _cargo_reset_requested:
		return
	if _executor.is_running:
		if _executor.is_paused:
			_executor.resume(true)
		return
	_start_program(source, true)


func _on_cargo_reset_requested() -> void:
	if _cargo_reset_requested:
		return
	_cargo_reset_requested = true
	if _executor.is_running:
		_executor.request_stop()
		return
	_reset_current_cargo()


func _reset_current_cargo() -> void:
	_field.reset_current_cargo()
	_editor.clear_execution_line()
	_editor.show_message("Робот возвращён на старт." if _field.delivered else "Текущий груз возвращён на выдачу.")
	_cargo_reset_requested = false


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
	if _cargo_reset_requested:
		_reset_current_cargo()
		return
	if not _executor.action_error.is_empty():
		_editor.show_action_error(_executor.action_error)
	elif _executor.error != null:
		_editor.show_error(DiagnosticFormatter.format_error(_executor.error), _executor.error.line, _executor.error.column)
	elif _executor.was_stopped:
		_editor.show_message("Программа остановлена.")
	else:
		_editor.show_message("Программа завершена.")
