extends Control

const LESSONS: Array[String] = [
	"Доставьте коробку с клетки «Выдача» в зону доставки. Составьте программу в редакторе: каждая инструкция записывается на отдельной строке. Робот выполняет их сверху вниз.\n\nmove(\"up\"), move(\"down\"), move(\"left\"), move(\"right\") перемещают робота на одну клетку в указанную сторону.\n\nНа клетке коробки выполните grab(), чтобы взять её. На клетке зоны доставки выполните put(), чтобы положить.\n\nНажмите «Запуск», чтобы выполнить программу, или «Шаг», чтобы выполнять её по одной инструкции.",
	"Зона доставки переместилась. Ваша программа сохранена. Измените маршрут и доставьте коробку в новую зону.",
	"Доставьте пять коробок по знакомому маршруту. После каждой правильной доставки на выдаче появляется следующая коробка. Робот должен вернуться за ней по вашей программе.\n\nwhile True: повторяет инструкции внутри цикла. Запишите их ниже с одинаковым отступом. Для отступа используйте Tab. Включите в повторение доставку и возвращение за следующей коробкой.\n\nЭтот цикл сам не заканчивается. После пяти доставок игра покажет успех, но программа продолжит работать. Остановите её кнопкой «Стоп».",
]
const HELP: String = "Новый запуск выполняет программу с начала из текущего положения робота и коробки.\n\n«Начать текущий груз заново» прекращает запуск и возвращает робота и текущую коробку в исходные положения. Код и число правильных доставок сохраняются.\n\nПри ошибке выполнение прекращается, а неправильная инструкция подсвечивается. Прочитайте причину ошибки и исправьте программу."
const TITLES: Array[String] = ["Первая доставка", "Новая зона назначения", "Повторная обработка"]

var _parser := ProgramParser.new()
var _executor := ProgramExecutor.new()
var _cargo_reset_requested: bool = false
var _task_index: int = 0
var _deliveries: int = 0

@onready var _editor: ProgramEditor = $Layout/ProgramEditor
@onready var _field: SorterField = $Layout/Field/Viewport/World
@onready var _goal: Label = $Goal
@onready var _next: Button = $NextTask
@onready var _help: AcceptDialog = $HelpDialog
@onready var _help_text: RichTextLabel = $HelpDialog/Text
@onready var _robot: SorterRobot = $Layout/Field/Viewport/World/Robot


func _ready() -> void:
	_field.cargo_delivered.connect(_on_cargo_delivered)
	_next.pressed.connect(_on_next_task)
	$Lesson.pressed.connect(_show_lesson)
	$Help.pressed.connect(_show_help)
	_update_goal()
	_show_lesson.call_deferred()
	_editor.run_requested.connect(_on_run_requested)
	_editor.step_requested.connect(_on_step_requested)
	_editor.stop_requested.connect(_executor.request_stop)
	_editor.cargo_reset_requested.connect(_on_cargo_reset_requested)
	_executor.output_emitted.connect(_editor.append_output)
	_executor.pause_changed.connect(_editor.set_paused)
	_executor.step_started.connect(_editor.highlight_execution_line)


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
	_update_goal()


func _start_program(source: String, single_step: bool = false) -> void:
	_editor.clear_output()
	var commands: Array[ProgramCommand] = _parser.parse(source)
	if _parser.error != null:
		_editor.show_error(DiagnosticFormatter.format_error(_parser.error), _parser.error.line, _parser.error.column)
		return
	if commands.is_empty():
		_editor.show_message("Введите программу. Доступные инструкции описаны в объяснении.")
		return
	_editor.set_running(true)
	_next.disabled = true
	_editor.show_message("Программа выполняется…")
	await _executor.run(commands, _robot.move, get_tree(), single_step, _field.perform)
	_editor.clear_execution_line()
	_editor.set_running(false)
	_update_goal()
	if _cargo_reset_requested:
		_reset_current_cargo()
		return
	if not _executor.action_error.is_empty():
		_editor.show_action_error(_executor.action_error, _executor.action_error_line)
	elif _executor.error != null:
		_editor.show_error(DiagnosticFormatter.format_error(_executor.error), _executor.error.line, _executor.error.column)
	elif _executor.was_stopped:
		_editor.show_message("Программа остановлена.")
	else:
		_editor.show_message("Программа завершена.")


func _on_cargo_delivered() -> void:
	_deliveries = mini(_deliveries + 1, 5 if _task_index == 2 else 1)
	_update_goal()


func _update_goal() -> void:
	var target: int = 5 if _task_index == 2 else 1
	var succeeded: bool = _deliveries >= target
	_goal.text = "%d. %s\n%d/%d%s" % [
		_task_index + 1, TITLES[_task_index], _deliveries, target,
		" — Коробка доставлена!" if succeeded and _task_index < 2 else (" — Цель достигнута! Остановите программу вручную." if succeeded else ""),
	]
	_next.visible = _task_index < 2
	_next.disabled = not succeeded or _executor.is_running or _cargo_reset_requested


func _on_next_task() -> void:
	if _next.disabled or _task_index >= 2:
		return
	_task_index += 1
	_deliveries = 0
	_field.start_task(Vector2i(4, 4), _task_index == 2)
	_editor.clear_output()
	_editor.clear_execution_line()
	_editor.show_message("Новая цель. Программа сохранена.")
	_update_goal()
	_show_lesson()


func _show_lesson() -> void:
	_help.title = TITLES[_task_index]
	_help_text.text = LESSONS[_task_index]
	_help.popup_centered(Vector2i(620, 440))


func _show_help() -> void:
	_help.title = "Справка"
	_help_text.text = LESSONS[0] + "\n\n" + (LESSONS[2] + "\n\n" if _task_index == 2 else "") + HELP
	_help.popup_centered(Vector2i(620, 440))
