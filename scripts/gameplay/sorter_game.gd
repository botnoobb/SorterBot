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
const FIRST_ORDER_COLOR := "orange"
const FIRST_ORDER_TARGET := 3
# Габариты проекции рамы, конвейеров и робота с коробкой.
const FIELD_PROJECTION_SIZE := Vector2(10.1, 5.0)
const FIELD_PROJECTION_CENTER_X_OFFSET := -0.51
const FIELD_FRAME_MARGIN := 8.0
const FIELD_MAX_ZOOM := 2.0
const FIELD_ZOOM_STEP := 1.125
const MOVEMENT_REFERENCE := (
		"Движение\n\nmove(направление) перемещает робота на одну клетку. "
		+ 'Направления: "up", "down", "left", "right".\n\n'
		+ 'Пример:\nmove("up")'
)
const CARGO_REFERENCE := (
		"Работа с коробкой\n\ngrab() берёт коробку на клетке выдачи. "
		+ "put() отправляет её по выходному конвейеру в зоне доставки.\n\n"
		+ 'Пример со старта:\nmove("up")\nmove("up")\nmove("up")\nmove("left")\ngrab()\n'
		+ 'move("right")\nmove("right")\nmove("right")\nmove("right")\n'
		+ 'move("down")\nmove("down")\nput()\n\n'
		+ 'Для коробки blue добавьте move("down") перед put().'
)
const OUTPUT_REFERENCE := (
		"Вывод\n\nprint() выводит текст. Пишите текст в кавычках, а имя переменной без них.\n\n"
		+ 'Пример:\nprint("Готово")\n\n'
		+ 'Цвет коробки можно вывести напрямую:\nprint(get_box_color())\n\n'
		+ "Переменные\n\nСохраните цвет коробки под именем color, чтобы использовать его позже. "
		+ "saved = color копирует текущее значение. Новое присваивание меняет color, "
		+ "а saved хранит прежнюю строку. Цвет самой коробки при этом не меняется.\n\n"
		+ 'color = get_box_color()\nsaved = color\ncolor = "blue"\nprint(saved)\nprint(color)'
)
const CONDITIONS_REFERENCE := (
		"Условия\n\nДоставьте коробку в зону её цвета. "
		+ 'if сравнивает color с "orange". Если значения совпадают, выполнится первый блок. '
		+ "Иначе робот выполнит команды под else. Команды внутри ветвей пишутся с отступом.\n\n"
		+ 'color = get_box_color()\nmove("up")\nmove("up")\nmove("up")\nmove("left")\ngrab()\n'
		+ 'move("right")\nmove("right")\nmove("right")\nmove("right")\nmove("down")\nmove("down")\n'
		+ 'if color == "orange":\n    put()\nelse:\n    move("down")\n    put()\n\n'
		+ "Попробуйте обе коробки. В режиме «Шаг» строка if подсветится отдельно "
		+ "перед первой командой выбранной ветви."
)
const WHILE_REFERENCE := (
		"Цикл while\n\nДоставьте две коробки одним запуском. Цикл повторяет доставку "
		+ "и возвращает робота на выдачу. После второй доставки нажмите «Стоп».\n\n"
		+ 'move("up")\nmove("up")\nmove("up")\nmove("left")\n'
		+ 'while True:\n    color = get_box_color()\n    grab()\n'
		+ '    move("right")\n    move("right")\n    move("right")\n    move("right")\n'
		+ '    move("down")\n    move("down")\n    if color == "orange":\n'
		+ '        put()\n    else:\n        move("down")\n        put()\n'
		+ '        move("up")\n    move("up")\n    move("up")\n'
		+ '    move("left")\n    move("left")\n    move("left")\n    move("left")\n\n'
		+ 'Условие проверяется перед каждым повтором. Сравнение вроде state == "repeat" '
		+ "позволяет выйти из цикла, когда значение изменится.\n\n"
		+ "Попробуйте while True с командой pass внутри. Робот не двигается, "
		+ "но «Стоп» всё равно завершает выполнение."
)

const FUNCTIONS_REFERENCE := (
		"Функции\n\nДоставьте две коробки одним запуском. Вынесите повторяющийся маршрут "
		+ "в функцию deliver. Строка def задаёт имя, а инструкции с отступом образуют тело. "
		+ "Каждый вызов deliver() выполняет тело заново.\n\n"
		+ "def deliver():\n    color = get_box_color()\n    grab()\n"
		+ '    move("right")\n    move("right")\n    move("right")\n    move("right")\n'
		+ '    move("down")\n    move("down")\n    if color == "orange":\n'
		+ '        put()\n    else:\n        move("down")\n        put()\n'
		+ '        move("up")\n    move("up")\n    move("up")\n'
		+ '    move("left")\n    move("left")\n    move("left")\n    move("left")\n\n'
		+ 'move("up")\nmove("up")\nmove("up")\nmove("left")\ndeliver()\ndeliver()\n\n'
		+ "Попробуйте режим «Шаг». После подсветки deliver() следующий шаг начнёт тело, "
		+ "а после последней инструкции выполнение продолжится после вызова. "
		+ "Присваивание внутри функции создаёт локальную переменную.\n\n"
		+ "Параметры\n\nНапишите функцию, которая двигает робота в заданном направлении. "
		+ "При каждом вызове параметр direction получает значение переданного аргумента. "
		+ "С исходной клетки робот сначала пойдёт вправо, затем вернётся.\n\n"
		+ 'def travel(direction):\n    move(direction)\n\ntravel("right")\n'
		+ 'direction = "left"\ntravel(direction)\n\n'
		+ "Возвращаемое значение\n\nФункция выбирает назначение по цвету коробки. "
		+ "return завершает функцию и передаёт результат в zone. Пустой return и "
		+ "конец тела возвращают None. Перезапустите сцену перед примером.\n\n"
		+ 'def choose_zone(color):\n    if color == "orange":\n        return "orange"\n'
		+ '    return "blue"\nmove("up")\nmove("up")\nmove("up")\nmove("left")\n'
		+ 'color = get_box_color()\nzone = choose_zone(color)\ngrab()\n'
		+ 'move("right")\nmove("right")\nmove("right")\nmove("right")\nmove("down")\nmove("down")\n'
		+ 'if zone == "blue":\n    move("down")\nput()'
)

var _parser := ProgramParser.new()
var _executor := ProgramExecutor.new()
var _cargo_reset_requested: bool = false
var _order_deliveries: int = 0
var _field_zoom: float = 1.0
var _field_pan := Vector2.ZERO
var _field_drag_button: MouseButton = MOUSE_BUTTON_NONE
var _field_drag_position := Vector2.ZERO

@onready var _editor: ProgramEditor = $Layout/ProgramEditor
@onready var _field: SorterField = $Layout/Field/Viewport/World
@onready var _goal: Label = $Lesson/Content/Goal
@onready var _layout: HSplitContainer = $Layout
@onready var _field_view: Control = $Layout/Field
@onready var _camera: Camera3D = $Layout/Field/Viewport/World/Camera
@onready var _lesson: PanelContainer = $Lesson
@onready var _lesson_details: RichTextLabel = $Lesson/Content/Details
@onready var _lesson_header: HBoxContainer = $Lesson/Content/Header
@onready var _lesson_title: Label = $Lesson/Content/Header/Title
@onready var _lesson_toggle: Button = $Lesson/Content/Header/Toggle
@onready var _order_progress: Label = $Lesson/Content/OrderProgress
@onready var _reference_panel: Panel = $ReferencePanel
@onready var _reference_compact_top: float = _reference_panel.offset_top
@onready var _reference_sections: VBoxContainer = $ReferencePanel/Content/Sections
@onready var _reference_detail: VBoxContainer = $ReferencePanel/Content/Detail
@onready var _reference_article: RichTextLabel = $ReferencePanel/Content/Detail/Article
@onready var _robot: SorterRobot = $Layout/Field/Viewport/World/Robot


func _ready() -> void:
	_field.cargo_delivered.connect(_on_cargo_delivered)
	_update_order_progress()
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
	$ReferencePanel/Content/Sections/Conditions.pressed.connect(
			_open_reference.bind(CONDITIONS_REFERENCE)
	)
	$ReferencePanel/Content/Sections/While.pressed.connect(_open_reference.bind(WHILE_REFERENCE))
	$ReferencePanel/Content/Sections/Functions.pressed.connect(
			_open_reference.bind(FUNCTIONS_REFERENCE)
	)
	$ReferencePanel/Content/Detail/Back.pressed.connect(_close_reference)
	_lesson_toggle.toggled.connect(_toggle_lesson)
	_field_view.gui_input.connect(_on_field_gui_input)
	_field_view.resized.connect(_resize_lesson, CONNECT_DEFERRED)
	_editor.resized.connect(_resize_lesson, CONNECT_DEFERRED)
	_lesson.minimum_size_changed.connect(_fit_compact_lesson_height)
	_lesson.resized.connect(_sync_reference_top)
	_resize_lesson.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_field_drag_button = MOUSE_BUTTON_NONE


func _on_field_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _field_drag_button != MOUSE_BUTTON_NONE:
		_field_pan += event.position - _field_drag_position
		_field_drag_position = event.position
		_frame_field()
		_field_view.accept_event()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_handle_field_drag_button(event)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_field(event)


func _handle_field_drag_button(event: InputEventMouseButton) -> void:
	if event.pressed and _field_drag_button == MOUSE_BUTTON_NONE:
		if not Rect2(Vector2.ZERO, _field_view.size).has_point(event.position):
			return
		_field_drag_button = event.button_index
		_field_drag_position = event.position
	elif not event.pressed and event.button_index == _field_drag_button:
		_field_drag_button = MOUSE_BUTTON_NONE
	_field_view.accept_event()


func _zoom_field(event: InputEventMouseButton) -> void:
	var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
	var wheel_steps: float = event.factor if event.factor > 0.0 else 1.0
	var zoom_multiplier: float = pow(FIELD_ZOOM_STEP, direction * wheel_steps)
	_field_zoom = clampf(_field_zoom * zoom_multiplier, 1.0, FIELD_MAX_ZOOM)
	_frame_field()
	_field_view.accept_event()


func _resize_lesson() -> void:
	var available_width := _field_view.size.x - 2.0 * _lesson.offset_left
	_lesson.size.x = minf(LESSON_MAX_WIDTH, available_width)

	# Подбираем шрифт для самого широкого положения карточки в текущем окне.
	var editor_minimum := ceilf(_editor.get_combined_minimum_size().x)
	var editor_extra := maxf(0.0, _editor.size.x - editor_minimum)
	var widest_card := minf(LESSON_MAX_WIDTH, available_width + editor_extra)
	var text_width := (
			widest_card - _lesson.get_theme_stylebox("panel").get_minimum_size().x
			- _lesson_title.get_theme_stylebox("normal").get_minimum_size().x
			- _lesson_header.get_theme_constant("separation")
			- _lesson_toggle.get_combined_minimum_size().x
	)
	var font := _lesson_title.get_theme_font("font")
	var font_size := _lesson_title.get_theme_default_font_size()
	while font_size > 1:
		var title_size := font.get_string_size(
				_lesson_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
		if ceilf(title_size.x) <= text_width:
			break
		font_size -= 1
	_lesson_title.add_theme_font_size_override("font_size", font_size)
	_frame_field.call_deferred()


func _fit_compact_lesson_height() -> void:
	if not _lesson_details.visible:
		_lesson.size.y = _lesson.get_combined_minimum_size().y
		_frame_field()


func _frame_field() -> void:
	var field_rect: Rect2 = _field_view.get_global_rect()
	var lesson_margin: float = _lesson.get_theme_stylebox("panel").get_margin(SIDE_BOTTOM)
	var top: float = _order_progress.get_global_rect().end.y - field_rect.position.y + lesson_margin
	var reference_top: float = field_rect.size.y + _reference_compact_top
	var reference_right: float = _reference_panel.get_global_rect().end.x - field_rect.position.x
	var above_reference := Rect2(0, top, field_rect.size.x, reference_top - top)
	var beside_reference := Rect2(
			reference_right, top, field_rect.size.x - reference_right, field_rect.size.y - top
	)

	# Выбираем область, в которой поле будет крупнее.
	var above_scale := _field_units_per_pixel(above_reference.size)
	var beside_scale := _field_units_per_pixel(beside_reference.size)
	var area := above_reference if above_scale <= beside_scale else beside_reference
	var units_per_pixel := minf(above_scale, beside_scale) / _field_zoom

	var offset := area.get_center() - field_rect.size * 0.5 + _field_pan
	_camera.size = field_rect.size.y * units_per_pixel
	# Входной конвейер удлиняет кадр влево. Центр клеток остаётся опорой зума.
	_camera.h_offset = FIELD_PROJECTION_CENTER_X_OFFSET / _field_zoom - offset.x * units_per_pixel
	_camera.v_offset = offset.y * units_per_pixel


func _field_units_per_pixel(area_size: Vector2) -> float:
	var available := (area_size - Vector2.ONE * FIELD_FRAME_MARGIN * 2.0).max(Vector2.ONE)
	return maxf(FIELD_PROJECTION_SIZE.x / available.x, FIELD_PROJECTION_SIZE.y / available.y)


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


func _on_cargo_delivered(color_name: String) -> void:
	_goal.text = "Коробка доставлена"
	if color_name == FIRST_ORDER_COLOR and _order_deliveries < FIRST_ORDER_TARGET:
		_order_deliveries += 1
		_update_order_progress()


func _update_order_progress() -> void:
	var count := "%d из %d" % [_order_deliveries, FIRST_ORDER_TARGET]
	if _order_deliveries == FIRST_ORDER_TARGET:
		_order_progress.text = "Заказ выполнен: %s оранжевых" % count
	else:
		_order_progress.text = "Заказ: оранжевые коробки — %s" % count


func _on_cargo_reset_requested() -> void:
	if _cargo_reset_requested:
		return
	_cargo_reset_requested = true
	if _executor.is_running:
		_executor.request_stop()
		return
	_reset_current_cargo()


func _reset_current_cargo() -> void:
	var cargo_reset: bool = _field.reset_current_cargo()
	_editor.clear_execution_line()
	_editor.show_message(
			"Текущий груз возвращён на выдачу." if cargo_reset else "Робот возвращён на старт."
	)
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
	await _executor.run(
			commands, _robot.move, get_tree(), single_step, _field.perform, _field.get_box_color
	)
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
