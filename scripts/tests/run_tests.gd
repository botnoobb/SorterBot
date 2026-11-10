extends SceneTree

var _failures: int = 0
var _checks: int = 0
var _moves: Array[Vector2i] = []
var _action_running: bool = false
var _started_lines: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--reset-cargo"):
		await _test_reset_cargo()
		print("Проверки: %d; ошибки: %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return
	_test_parser()
	_test_print_parser()
	await _test_execution()
	await _test_diagnostics()
	await _test_scene()
	await _test_reference_panel()
	await _test_delivery()
	await _test_wrong_delivery()
	await _test_reset_cargo()
	print("Проверки: %d; ошибки: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_parser() -> void:
	var parser := ProgramParser.new()
	var commands: Array[ProgramCommand] = parser.parse(
		"move(\"up\")\nmove('down')\nmove(\"left\")\nmove('right')"
	)
	_expect((parser.error == null), "Оба вида кавычек принимаются")
	_expect(commands.size() == 4, "Разобраны четыре команды")
	if commands.size() == 4:
		_expect(commands[0].direction == Vector2i.UP, "Направление up")
		_expect(commands[1].direction == Vector2i.DOWN, "Направление down")
		_expect(commands[2].direction == Vector2i.LEFT, "Направление left")
		_expect(commands[3].direction == Vector2i.RIGHT, "Направление right")
	commands = parser.parse("\r\n  move ( 'up' ) \r\n\r\nmove(\"right\")\n")
	_expect(commands.size() == 2, "Пробелы, CRLF и пустые строки")
	if commands.size() == 2:
		_expect(commands[0].line == 2 and commands[1].line == 4, "Номера строк")
	for source: String in [
		"move(up)",
		"move('up'", "move('up\")", "move('up') move('down')",
		"move('up');", "move('u\np')", "move(42)",
		"move('up')\n@", "move('up')\nmove('bad'",
	]:
		commands = parser.parse(source)
		_expect(not (parser.error == null), "Отклонён ввод: " + source)
		_expect(commands.is_empty(), "При ошибке нет частичной программы")
	commands = parser.parse("move('left')")
	_expect(commands.size() == 1 and (parser.error == null), "Повторный разбор")
	commands = parser.parse(" \n\t\n")
	_expect(commands.is_empty() and (parser.error == null), "Пустая программа")


func _test_execution() -> void:
	var parser := ProgramParser.new()
	var executor := ProgramExecutor.new()
	executor.step_started.connect(_record_step)
	var commands: Array[ProgramCommand] = parser.parse("move('up')\n\nmove('right')")
	executor.run(commands, _record_move, self)
	_expect(executor.is_running, "Выполнение началось")
	var accepted: bool = await executor.run(commands, _record_move, self)
	_expect(not accepted, "Повторный запуск во время выполнения отклонён")
	while executor.is_running:
		await process_frame
	_expect(_moves == [Vector2i.UP, Vector2i.RIGHT], "Порядок команд сохранён")
	_expect(not _action_running, "Последнее действие завершено")
	_expect(_started_lines == [1, 3], "Шаги используют номера строк исходного кода")
	accepted = await executor.run([], _record_move, self)
	_expect(accepted and not executor.is_running, "Пустая программа завершается")


func _test_print_parser() -> void:
	var parser := ProgramParser.new()
	var commands: Array[ProgramCommand] = parser.parse("print(\"Привет\")\nprint('')")
	_expect(commands.size() == 2, "Оба вида кавычек в print")
	if commands.size() == 2:
		_expect(commands[0].text == "Привет", "Строка выводится без кавычек")
		_expect(commands[1].text.is_empty(), "Допустима пустая строка")
	for source: String in ["print(42)", "print(text)"]:
		commands = parser.parse(source)
		_expect(commands.is_empty() and not (parser.error == null), "Неверный print")


func _record_step(line: int) -> void:
	_expect(not _action_running, "Подсветка меняется после завершения действия")
	_started_lines.append(line)


func _test_diagnostics() -> void:
	var parser := ProgramParser.new()
	parser.parse("\nmove(\"up\"")
	_expect(parser.error != null, "Незакрытая скобка — синтаксическая ошибка")
	if parser.error != null:
		_expect(
			DiagnosticFormatter.format_error(parser.error) ==
			"  File \"main\", line 2\n    move(\"up\"\n        ^\nSyntaxError: '(' was never closed",
			"Формат SyntaxError с именем main, исходным кодом и указателем"
		)
	parser.parse("\r\n\tprint('oops)")
	_expect(parser.error.line == 2 and parser.error.column == 8, "Позиция кавычки после табуляции")
	_expect(parser.error.message == "unterminated string literal", "Незакрытая строка")
	parser.parse("move('up')\n@")
	_expect(parser.error.line == 2 and parser.error.column == 1, "Позиция неизвестного символа")
	for sample: Array in [
		["walk('up')", "NameError", "name 'walk' is not defined"],
		["move()", "TypeError", "move() takes exactly 1 argument (0 given)"],
		["print('a', 'b')", "TypeError", "print() takes exactly 1 argument (2 given)"],
		["move('north')", "ValueError", "invalid direction 'north'"],
	]:
		var source: String = "print('before')\nmove('right')\n" + sample[0] + "\nprint('after')"
		var commands: Array[ProgramCommand] = parser.parse(source)
		_expect(parser.error == null, "Ошибка выполнения не является синтаксической")
		var executor := ProgramExecutor.new()
		var output: Array[String] = []
		executor.output_emitted.connect(func(message: String) -> void: output.append(message))
		var move_count: int = _moves.size()
		var succeeded: bool = await executor.run(commands, _record_move, self)
		_expect(not succeeded and not executor.is_running, "Ошибка останавливает исполнение")
		_expect(output == ["before"], "Предыдущий вывод сохранён, последующий не выполняется")
		_expect(_moves.size() == move_count + 1, "Действие перед ошибкой выполнено")
		if executor.error != null:
			var expected: String = "Traceback (most recent call last):\n"
			expected += "  File \"main\", line 3\n    " + sample[0] + "\n"
			expected += sample[1] + ": " + sample[2]
			_expect(DiagnosticFormatter.format_error(executor.error) == expected, "Точный traceback")
		else:
			_expect(false, "Должна быть диагностика выполнения")
		await executor.run(parser.parse("print('fixed')"), _record_move, self)
		_expect(executor.error == null, "Исправленный запуск очищает диагностику")


func _record_move(direction: Vector2i, duration: float) -> void:
	_expect(is_equal_approx(duration, 0.35), "Исполнитель передаёт длительность шага")
	_expect(not _action_running, "Действия не перекрываются")
	_action_running = true
	await create_timer(0.01).timeout
	_moves.append(direction)
	_action_running = false


func _test_reference_panel() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	var panel: Panel = game.get_node_or_null("ReferencePanel")
	_expect(panel != null and panel.visible, "Справка доступна при запуске сцены")
	if panel == null:
		game.queue_free()
		return

	var code: CodeEdit = game.get_node("Layout/ProgramEditor/Margin/Content/Code")
	var field: Control = game.get_node("Layout/Field")
	var sections: VBoxContainer = panel.get_node("Content/Sections")
	var detail: VBoxContainer = panel.get_node("Content/Detail")
	var article: RichTextLabel = detail.get_node("Article")
	var movement: Button = sections.get_node("Movement")
	var back: Button = detail.get_node("Back")
	var source := "print('Строка')\n".repeat(80)
	code.text = source
	code.set_caret_line(40)
	code.set_caret_column(5)
	code.grab_focus()
	await process_frame
	code.scroll_vertical = 35
	var scroll := code.scroll_vertical
	var field_rect := field.get_global_rect()
	var code_rect := code.get_global_rect()
	var compact_rect := panel.get_global_rect()

	_click_reference_button(movement)
	_expect(not detail.visible, "Текст появляется после раскрытия")
	await create_timer(0.4).timeout
	_expect(detail.visible and article.text.contains('move("up")'), "В справке есть пример")
	_expect(panel.size.y > compact_rect.size.y, "Карточка раскрывается вверх")
	_expect(is_equal_approx(panel.get_global_rect().end.y, compact_rect.end.y),
			"Нижний край карточки закреплён")
	_expect(field.get_global_rect() == field_rect, "При раскрытии поле остаётся на месте")
	_click_reference_button(back)
	await create_timer(0.4).timeout
	_expect(sections.visible and panel.get_global_rect() == compact_rect, "Возврат к списку")
	_expect(code.text == source and code.get_caret_line() == 40 and code.get_caret_column() == 5,
			"Справка сохраняет текст и курсор")
	_expect(code.scroll_vertical == scroll and code.has_focus(), "Сохраняются прокрутка и фокус")
	_expect(code.get_global_rect() == code_rect, "Редактор остаётся на месте")
	_expect(field.get_global_rect() == field_rect, "При сворачивании поле остаётся на месте")
	game.queue_free()
	await process_frame


func _click_reference_button(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _test_scene() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
	var code: CodeEdit = editor.get_node("Margin/Content/Code")
	var button: Button = editor.get_node("Margin/Content/Header/Run")
	var stop: Button = editor.get_node("Margin/Content/Header/Stop")
	var robot: SorterRobot = game.get_node("Layout/Field/Viewport/World/Robot")
	var title: Label = editor.get_node("Margin/Content/Header/Title")
	_expect(title.global_position.y >= 0, "Заголовок редактора помещается в окне")
	_expect(code.gutters_draw_line_numbers, "В редакторе включены номера строк")
	code.text = "move('up')\nmove(\"right\")"
	button.pressed.emit()
	_expect(not button.disabled and button.text == "Ⅱ", "Во время выполнения доступна пауза")
	_expect(code.get_line_background_color(0).a > 0, "Первая строка подсвечена")
	await create_timer(0.1).timeout
	_expect(robot.cell == Vector2i(1, 3), "Шаг не заканчивается раньше анимации")
	_expect(robot.position.z < 3 and robot.position.z > 2, "Движение идёт внутри шага")
	while robot.cell == Vector2i(1, 3):
		await process_frame
	_expect(code.get_line_background_color(0).a == 0, "Подсветка первой строки снята")
	_expect(code.get_line_background_color(1).a > 0, "Вторая строка подсвечена")
	while not stop.disabled:
		await process_frame
	_expect(code.get_line_background_color(1).a == 0, "Подсветка снята после программы")
	_expect(robot.cell == Vector2i(2, 2), "Кнопка запуска перемещает робота")
	_expect(robot.position.is_equal_approx(Vector3(2, 0, 2)), "Положение в 3D")
	code.text = "move('up')\nmove('wrong'"
	button.pressed.emit()
	await process_frame
	_expect(robot.cell == Vector2i(2, 2), "Ошибочная программа не двигает робота")
	code.text = "move('left')"
	button.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(robot.cell == Vector2i(1, 2), "Повторный запуск сохраняет положение")
	code.text = "\n".repeat(80) + "move('up')"
	button.pressed.emit()
	await process_frame
	_expect(code.get_line_background_color(80).a > 0, "Подсветка после пустых строк")
	_expect(code.get_first_visible_line() > 0, "Редактор прокручивается к выполняемой строке")
	while not stop.disabled:
		await process_frame
	_expect(code.get_line_background_color(80).a == 0, "Повторный запуск очищает подсветку")
	var output: OutputPanel = editor.get_node("Margin/Content/OutputPanel")
	var messages: RichTextLabel = output.get_node("Messages")
	_expect(not output.visible, "Без вывода панель скрыта")
	var previous_cell: Vector2i = robot.cell
	code.text = "print('[b]Привет[/b]')\nmove('right')\nprint(\"Готово\")"
	button.pressed.emit()
	_expect(output.visible, "Первый print раскрывает панель")
	_expect(messages.get_parsed_text() == "[b]Привет[/b]\n", "Вывод — обычный текст")
	await create_timer(0.1).timeout
	_expect(robot.cell == previous_cell, "print не двигает робота")
	_expect(code.get_line_background_color(0).a > 0, "print занимает отдельный шаг")
	while not stop.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "[b]Привет[/b]\nГотово\n", "Порядок вывода")
	_expect(robot.cell == previous_cell + Vector2i.RIGHT, "Смешанная программа")
	code.text = "move('left')"
	_expect(output.visible and not messages.get_parsed_text().is_empty(), "Правка сохраняет вывод")
	button.pressed.emit()
	_expect(not output.visible and messages.get_parsed_text().is_empty(), "Новый запуск очищает вывод")
	while not stop.disabled:
		await process_frame
	for index: int in range(100):
		editor.append_output("Сообщение %d" % index)
	await process_frame
	await process_frame
	_expect(messages.get_v_scroll_bar().max_value > messages.size.y, "Длинный вывод прокручивается")
	_expect(messages.selection_enabled, "Вывод можно выделять и копировать")
	code.text = ""
	button.pressed.emit()
	_expect(not output.visible, "Пустой запуск также скрывает старый вывод")
	for invalid_source: String in ["move('north')", "print('незакрытая строка)"]:
		code.text = invalid_source
		button.pressed.emit()
		_expect(output.visible, "Ошибка раскрывает панель вывода")
		_expect(messages.get_parsed_text().contains('File "main", line 1'), "Ошибка содержит строку")
		_expect(editor.get_node("Margin/Content/Message").text == "", "Ошибка не дублируется под панелью")
		_expect(not button.disabled, "После ошибки можно запустить исправленный код")
	code.text = "print('Исправлено')"
	button.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "Исправлено\n", "Исправленный запуск очищает ошибку")
	code.text = "move('up')\nmove('right')"
	robot.cell = Vector2i(1, 3)
	robot.position = Vector3(1, 0, 3)
	previous_cell = robot.cell
	button.pressed.emit()
	await create_timer(0.1).timeout
	stop.pressed.emit()
	_expect(not stop.disabled and code.editable, "Остановка ждёт анимацию, ввод доступен")
	while not stop.disabled:
		await process_frame
	_expect(robot.cell == previous_cell + Vector2i.UP, "Остановка завершает только текущую инструкцию")
	_expect(stop.disabled, "После остановки квадрат недоступен")
	button.pressed.emit()
	await create_timer(0.1).timeout
	code.set_caret_line(0)
	code.set_caret_column(0)
	code.insert_text_at_caret(" ")
	await process_frame
	_expect(code.text.begins_with(" "), "Первая правка применяется")
	while not stop.disabled:
		await process_frame
	_expect(robot.cell == previous_cell + Vector2i.UP * 2, "Правка останавливает новый запуск после первой инструкции")
	code.text = "print('Сохранить')\nprint('Не выполнять')"
	button.pressed.emit()
	stop.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "Сохранить\n", "Остановка сохраняет вывод текущей инструкции")
	code.text = "move('up')\nprint('После паузы')"
	robot.cell = Vector2i(1, 3)
	robot.position = Vector3(1, 0, 3)
	previous_cell = robot.cell
	button.pressed.emit()
	await create_timer(0.1).timeout
	button.pressed.emit()
	await create_timer(0.4).timeout
	_expect(robot.cell == previous_cell + Vector2i.UP, "Пауза дожидается движения")
	_expect(button.text == "▶" and not stop.disabled, "В паузе доступны продолжение и остановка")
	_expect(messages.get_parsed_text().is_empty(), "Следующая инструкция ждёт продолжения")
	_expect(code.get_line_background_color(0).a > 0, "В паузе сохраняется подсветка")
	button.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "После паузы\n", "Продолжение выполняет следующую инструкцию")
	code.text = "print('Последняя')"
	button.pressed.emit()
	button.pressed.emit()
	await create_timer(0.4).timeout
	_expect(stop.disabled, "Пауза на последней инструкции завершает запуск")
	code.text = "print('Первый')\nprint('Второй')"
	button.pressed.emit()
	button.pressed.emit()
	await create_timer(0.4).timeout
	stop.pressed.emit()
	await process_frame
	await process_frame
	_expect(stop.disabled and messages.get_parsed_text() == "Первый\n", "Остановка из паузы сохраняет вывод без дополнительной инструкции")
	button.pressed.emit()
	button.pressed.emit()
	await create_timer(0.4).timeout
	code.set_caret_line(1)
	code.select(0, 0, 0, 5)
	await process_frame
	_expect(not stop.disabled and button.text == "▶", "Курсор и выделение сохраняют паузу")
	code.deselect()
	code.set_caret_column(0)
	code.insert_text_at_caret(" ")
	await process_frame
	await process_frame
	_expect(stop.disabled, "Правка в паузе завершает запуск")
	_expect(messages.get_parsed_text() == "Первый\n", "Правка в паузе сохраняет вывод")
	code.text = "print('Один')\nprint('Два')\nprint('Три')"
	code.set_caret_line(2)
	code.set_caret_column(3)
	button.pressed.emit()
	await create_timer(0.4).timeout
	_expect(code.get_caret_line() == 2 and code.get_caret_column() == 3, "Смена инструкции не перемещает курсор")
	code.insert_text_at_caret(" ")
	await process_frame
	_expect(code.get_line(2) == "pri nt('Три')", "Правка применяется в выбранной строке")
	while not stop.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "Один\nДва\n", "Правка завершает текущую инструкцию и останавливает запуск")
	var step: Button = editor.get_node("Margin/Content/Header/Step")
	code.text = "print('Шаг 1')\nmove('up')\nprint('Шаг 3')"
	robot.cell = Vector2i(1, 3)
	robot.position = Vector3(1, 0, 3)
	previous_cell = robot.cell
	step.pressed.emit()
	_expect(step.disabled and messages.get_parsed_text() == "Шаг 1\n", "Новый шаг очищает прежний вывод и блокирует кнопку")
	await create_timer(0.4).timeout
	_expect(not step.disabled and not stop.disabled and button.text == "▶", "После шага наступает пауза")
	await create_timer(0.4).timeout
	_expect(robot.cell == previous_cell, "В ожидании шага инструкция не начинается")
	step.pressed.emit()
	_expect(step.disabled, "Продолжение сразу блокирует повторный шаг")
	await create_timer(0.1).timeout
	_expect(robot.cell == previous_cell, "Шаг ждёт анимацию")
	await create_timer(0.3).timeout
	_expect(robot.cell == previous_cell + Vector2i.UP and not step.disabled, "Шаг заканчивает движение перед паузой")
	_expect(messages.get_parsed_text() == "Шаг 1\n", "Шаг из паузы сохраняет вывод")
	step.pressed.emit()
	await create_timer(0.4).timeout
	_expect(stop.disabled and not step.disabled, "Последний шаг завершает программу")
	_expect(messages.get_parsed_text() == "Шаг 1\nШаг 3\n", "Шаги не повторяют инструкции")
	code.text = "move('up')\nprint('Не выполнять')"
	robot.cell = Vector2i(1, 3)
	robot.position = Vector3(1, 0, 3)
	previous_cell = robot.cell
	step.pressed.emit()
	await create_timer(0.1).timeout
	stop.pressed.emit()
	_expect(not stop.disabled, "Остановка шага ждёт действие")
	await create_timer(0.3).timeout
	_expect(stop.disabled and robot.cell == previous_cell + Vector2i.UP, "Остановка шага завершает только начатое действие")
	step.pressed.emit()
	await create_timer(0.4).timeout
	code.set_caret_line(1)
	code.set_caret_column(0)
	code.insert_text_at_caret(" ")
	await process_frame
	await process_frame
	_expect(stop.disabled and code.get_line(1).begins_with(" "), "Правка в ожидании шага применяется и останавливает запуск")
	code.text = "print('A')\nmove('up')\nprint('B')\nmove('right')\nprint('C')\nmove('down')"
	robot.cell = Vector2i(1, 3)
	robot.position = Vector3(1, 0, 3)
	previous_cell = robot.cell
	button.pressed.emit()
	await create_timer(0.45).timeout
	button.pressed.emit()
	await create_timer(0.4).timeout
	_expect(robot.cell == previous_cell + Vector2i.UP and not step.disabled, "Автоматический режим переходит в паузу после движения")
	_expect(messages.get_parsed_text() == "A\n", "Пауза сохраняет накопленный вывод")
	step.pressed.emit()
	await create_timer(0.4).timeout
	_expect(messages.get_parsed_text() == "A\nB\n", "Шаг после автоматического режима продолжает тот же запуск")
	step.pressed.emit()
	await create_timer(0.4).timeout
	_expect(robot.cell == previous_cell + Vector2i.UP + Vector2i.RIGHT, "Второй шаг не повторяет предыдущие движения")
	button.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "A\nB\nC\n", "Автоматическое продолжение сохраняет все сообщения ровно один раз")
	_expect(robot.cell == previous_cell + Vector2i.RIGHT, "Переключение режимов не пропускает движения")
	step.pressed.emit()
	await create_timer(0.4).timeout
	stop.pressed.emit()
	await process_frame
	await process_frame
	button.pressed.emit()
	_expect(messages.get_parsed_text() == "A\n", "После остановки автоматический запуск начинается сначала")
	stop.pressed.emit()
	while not stop.disabled:
		await process_frame
	robot.cell = Vector2i(1, 3)
	robot.position = Vector3(1, 0, 3)
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var delivery_cells: Array[Vector2i] = []
	field.cargo_delivered.connect(func() -> void: delivery_cells.append(robot.cell))
	code.text = (
			"move('up')\ngrab()\nmove('right')\nmove('right')\nput()\n"
			+ "move('left')\nmove('left')\ngrab()\nmove('right')\nmove('right')\nput()\n"
			+ "print('Готово')"
	)
	button.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(
			delivery_cells == [SorterField.ZONE_CELL, SorterField.ZONE_CELL],
			"Одна программа выполняет две доставки, робот остаётся в зоне"
	)
	_expect(field.delivered and not field.carrying, "Доставка засчитана после put")
	_expect(game.get_node("Goal").text == "Коробка доставлена", "Успех виден игроку")
	_expect(messages.get_parsed_text() == "Готово\n", "После доставки программа продолжается")
	code.text = "print('Новый запуск')"
	await process_frame
	_expect(
			stop.disabled and messages.get_parsed_text() == "Готово\n",
			"Редактирование не запускает программу снова"
	)
	code.text = "grab()"
	button.pressed.emit()
	_expect(messages.get_parsed_text().contains("нет коробки"), "Новый груз не в зоне доставки")
	code.text = "print('До')\nmove('north')\nprint('После')"
	step.pressed.emit()
	await create_timer(0.4).timeout
	step.pressed.emit()
	await process_frame
	await process_frame
	_expect(stop.disabled and messages.get_parsed_text().contains("ValueError"), "Ошибка завершает пошаговый запуск")
	_expect(not messages.get_parsed_text().contains("После\n"), "После ошибки нет следующих инструкций")
	_expect(code.get_line_background_color(1).a > 0, "Ошибка подсвечена фоном")
	messages.meta_clicked.emit(Vector2i(2, 1))
	_expect(code.get_caret_line() == 1 and code.get_caret_column() == 0 and code.has_focus(), "Ссылка переводит курсор и фокус к ошибке")
	code.text = "print('Новый')"
	step.pressed.emit()
	_expect(not messages.get_parsed_text().contains("ValueError"), "Первый шаг очищает прежнюю ошибку")
	while not stop.disabled:
		await process_frame
	_expect(code.get_line_background_color(0).a == 0, "После нового запуска фон ошибки снят")
	code.text = "\nmove("
	button.pressed.emit()
	_expect(messages.get_parsed_text().begins_with('  File "main", line 2\n'), "Ссылка не добавляет строки к формату Python")
	_expect(not messages.get_parsed_text().contains("Строка "), "Нет дополнительного заголовка навигации")
	messages.meta_clicked.emit(Vector2i(2, 5))
	_expect(code.get_caret_line() == 1 and code.get_caret_column() == 4, "Переход учитывает позицию синтаксической ошибки")
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _test_delivery() -> void:
	var game: Control = load("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	var parser := ProgramParser.new()
	var executor := ProgramExecutor.new()
	for source: String in ["grab()", "put()"]:
		await executor.run(parser.parse(source), robot.move, self, false, field.perform)
		_expect(not executor.action_error.is_empty(), "Неверное действие отклонено: " + source)
	await executor.run(parser.parse("move('up')\ngrab()\nput()"), robot.move, self, false, field.perform)
	_expect(field.carrying and not field.delivered, "Отказ положить вне зоны сохраняет коробку у робота")
	await executor.run(parser.parse("grab()"), robot.move, self, false, field.perform)
	_expect(field.carrying and not executor.action_error.is_empty(), "Повторный захват отклонён")
	await executor.run(parser.parse("move('left')\nmove('left')"), robot.move, self, false, field.perform)
	_expect(robot.cell == Vector2i(0, 2) and field.carrying, "Граница сохраняет позицию и груз")
	var commands: Array[ProgramCommand] = parser.parse("move('right')\nmove('right')\nmove('right')\nput()")
	executor.run(commands, robot.move, self, true, field.perform)
	for index: int in range(3):
		while executor.is_running and not executor.is_paused:
			await process_frame
		_expect(executor.is_paused and not field.delivered, "Переноска по шагам не засчитывает доставку")
		executor.resume(true)
	await create_timer(0.1).timeout
	_expect(not field.delivered, "Успех ждёт завершения put")
	executor.request_stop()
	while executor.is_running:
		await process_frame
	_expect(field.delivered and not field.carrying, "Остановка дожидается завершения put и доставки")
	game.queue_free()
	await process_frame


func _test_wrong_delivery() -> void:
	for single_step: bool in [false, true]:
		var game: Control = load("res://scenes/SorterGame.tscn").instantiate()
		root.add_child(game)
		await process_frame
		var field: SorterField = game.get_node("Layout/Field/Viewport/World")
		var robot: SorterRobot = field.get_node("Robot")
		var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
		var code: CodeEdit = editor.get_node("Margin/Content/Code")
		var run: Button = editor.get_node("Margin/Content/Header/Run")
		var step: Button = editor.get_node("Margin/Content/Header/Step")
		var output: OutputPanel = editor.get_node("Margin/Content/OutputPanel")
		var messages: RichTextLabel = output.get_node("Messages")
		var executor: ProgramExecutor = game.get("_executor")
		for sample: Array in [
			["grab()", "На этой клетке нет коробки.\n"],
			["put()", "У робота нет коробки.\n"],
		]:
			code.text = sample[0]
			run.pressed.emit()
			while executor.is_running:
				await process_frame
			_expect(output.visible and messages.get_parsed_text() == sample[1], "Игровой отказ раскрывает панель и выводится без префикса")
		editor.clear_output()
		code.text = "move('up')\ngrab()\nput()\nprint('После отказа')\nmove('right')"
		_expect(not output.visible, "Перед ошибкой доставки панель скрыта")
		if single_step:
			step.pressed.emit()
			for index: int in range(2):
				while executor.is_running and not executor.is_paused:
					await process_frame
				_expect(executor.is_paused, "До ошибки доставки шаг ожидает нажатия")
				step.pressed.emit()
		else:
			run.pressed.emit()
		while executor.is_running:
			await process_frame
		_expect(not executor.is_paused, "Ошибка доставки завершает запуск без ожидания шага")
		_expect(output.visible, "Ошибка доставки раскрывает скрытую панель")
		_expect(messages.get_parsed_text() == "Коробку нужно положить в зоне доставки.\n", "Сообщение отказа без префикса и последующего вывода")
		_expect(field.carrying and not field.delivered, "Отказ сохраняет коробку у робота без зачёта")
		_expect(robot.cell == SorterField.CARGO_CELL, "После отказа следующие перемещения не выполняются")
		_expect(game.get_node("Goal").text != "Коробка доставлена", "После отказа нет сообщения об успехе")
		executor.resume(true)
		await process_frame
		_expect(not executor.is_running and robot.cell == SorterField.CARGO_CELL, "Ошибочный запуск нельзя продолжить")
		# Кнопка «Шаг» после отказа начинает программу с первой инструкции.
		step.pressed.emit()
		while executor.is_running and not executor.is_paused:
			await process_frame
		_expect(robot.cell == SorterField.CARGO_CELL + Vector2i.UP, "Шаг после отказа начинает новый запуск")
		executor.request_stop()
		while executor.is_running:
			await process_frame
		code.text = "grab()"
		run.pressed.emit()
		while executor.is_running:
			await process_frame
		_expect(messages.get_parsed_text() == "Робот уже несёт коробку.\n", "Повторный захват выводит только причину отказа")
		code.text = "move('down')\nmove('right')\nmove('right')\nput()"
		run.pressed.emit()
		while executor.is_running:
			await process_frame
		_expect(field.delivered and not field.carrying, "Сохранённую коробку можно доставить исправленной программой")
		_expect(not output.visible, "Успешный новый запуск очищает ошибку доставки")
		game.queue_free()
		await process_frame


func _test_reset_cargo() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	# Сброс во время движения, захвата, переноски, печати и ожидания шага.
	for scenario: int in range(5):
		var game: Control = packed.instantiate()
		root.add_child(game)
		await process_frame
		var field: SorterField = game.get_node("Layout/Field/Viewport/World")
		var robot: SorterRobot = field.get_node("Robot")
		var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
		var code: CodeEdit = editor.get_node("Margin/Content/Code")
		var run: Button = editor.get_node("Margin/Content/Header/Run")
		var step: Button = editor.get_node("Margin/Content/Header/Step")
		var reset: Button = editor.get_node_or_null("Margin/Content/ResetCargo")
		var messages: RichTextLabel = editor.get_node("Margin/Content/OutputPanel/Messages")
		var executor: ProgramExecutor = game.get("_executor")
		_expect(reset != null, "Есть отдельная кнопка восстановления груза")
		if reset == null:
			game.queue_free()
			await process_frame
			return
		var cargo: MeshInstance3D = field.get("_cargo")
		var original_mesh: Mesh = cargo.mesh
		var original_position: Vector3 = cargo.position
		reset.pressed.emit()
		_expect(not reset.disabled and cargo.position == original_position, "На выдаче коробка остаётся на месте, кнопка доступна")
		var source: String = "move('up')\ngrab()\nmove('right')\nprint('Нельзя продолжить')"
		if scenario == 3:
			source = "print('Сохранить')\nmove('right')"
		code.text = source
		if scenario == 4:
			step.pressed.emit()
			for index: int in range(2):
				while executor.is_running and not executor.is_paused:
					await process_frame
				if index == 0:
					step.pressed.emit()
		else:
			run.pressed.emit()
			if scenario in [1, 2]:
				while robot.cell != SorterField.CARGO_CELL:
					await process_frame
			if scenario == 2:
				while not field.carrying:
					await process_frame
			await create_timer(0.1).timeout
		var position_before_reset: Vector3 = robot.position
		var output_before_reset: String = messages.get_parsed_text()
		reset.pressed.emit()
		reset.pressed.emit()
		if scenario != 4:
			_expect(executor.is_running and robot.position == position_before_reset, "Восстановление ждёт завершения текущего действия")
		# Попытки запуска и шага во время ожидания не возобновляют старую программу.
		run.pressed.emit()
		step.pressed.emit()
		while executor.is_running:
			await process_frame
		_expect(not executor.is_paused, "Восстановление завершает запуск вместе с ожиданием шага")
		_expect(robot.cell == Vector2i(1, 3) and robot.position == Vector3(1, 0, 3), "Робот возвращён на старт карты")
		_expect(cargo == field.get("_cargo") and cargo.mesh == original_mesh, "Восстановлена та же коробка с прежним ресурсом")
		_expect(cargo.get_parent() == field and cargo.position == original_position, "Коробка возвращена на выдачу")
		_expect(not field.carrying and not field.delivered, "Груз снова доступен для захвата")
		_expect(code.text == source, "Восстановление сохраняет текст программы")
		_expect(messages.get_parsed_text() == output_before_reset, "Восстановление сохраняет накопленный вывод")
		executor.resume()
		await create_timer(0.4).timeout
		_expect(not executor.is_running and robot.cell == Vector2i(1, 3), "Старый запуск не продолжается после восстановления")
		_expect(code.get_line_background_color(0).a == 0, "Подсветка выполнения снята")
		# Исправление после неверной сдачи не теряется при восстановлении.
		code.text = "move('up')\ngrab()\nput()"
		run.pressed.emit()
		while executor.is_running:
			await process_frame
		code.text = "move('up')\ngrab()\nmove('right')\nmove('right')\nput()"
		var fixed_source: String = code.text
		reset.pressed.emit()
		_expect(code.text == fixed_source and not field.carrying, "После ошибки восстановление сохраняет исправленный код")
		run.pressed.emit()
		while executor.is_running and robot.cell != SorterField.ZONE_CELL:
			await process_frame
		# Восстановление во время сдачи не отменяет завершённую доставку.
		await create_timer(0.1).timeout
		reset.pressed.emit()
		while executor.is_running:
			await process_frame
		_expect(field.delivered and not field.carrying, "Восстановление во время put сохраняет успешную доставку")
		_expect(game.get_node("Goal").text == "Коробка доставлена", "Результат доставки сохранён")
		var delivered_position: Vector3 = cargo.position
		reset.pressed.emit()
		_expect(not reset.disabled and field.delivered and cargo.position == delivered_position, "После доставки кнопка доступна без отката результата")
		game.queue_free()
		await process_frame
	# Клетка появления берётся из карты, а не из фиксированных координат скрипта.
	var game: Control = packed.instantiate()
	var robot: SorterRobot = game.get_node("Layout/Field/Viewport/World/Robot")
	robot.position = Vector3(4, 0, 4)
	root.add_child(game)
	await process_frame
	var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
	var executor: ProgramExecutor = game.get("_executor")
	_expect(robot.cell == Vector2i(4, 4), "Карта задаёт клетку появления робота")
	editor.get_node("Margin/Content/Code").text = "move('left')"
	editor.get_node("Margin/Content/Header/Run").pressed.emit()
	while executor.is_running:
		await process_frame
	editor.get_node("Margin/Content/ResetCargo").pressed.emit()
	_expect(robot.cell == Vector2i(4, 4) and robot.position == Vector3(4, 0, 4), "Восстановление учитывает другую стартовую клетку карты")
	game.queue_free()
	await process_frame
