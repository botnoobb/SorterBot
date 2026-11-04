extends SceneTree

var _failures: int = 0
var _checks: int = 0
var _moves: Array[Vector2i] = []
var _action_running: bool = false
var _started_lines: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_parser()
	_test_print_parser()
	await _test_execution()
	await _test_diagnostics()
	await _test_scene()
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


func _test_scene() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
	var code: CodeEdit = editor.get_node("Margin/Content/Code")
	var button: Button = editor.get_node("Margin/Content/Header/Run")
	var robot: SorterRobot = game.get_node("Layout/Field/Viewport/World/Robot")
	var title: Label = editor.get_node("Margin/Content/Header/Title")
	_expect(title.global_position.y >= 0, "Заголовок редактора помещается в окне")
	_expect(code.gutters_draw_line_numbers, "В редакторе включены номера строк")
	code.text = "move('up')\nmove(\"right\")"
	button.pressed.emit()
	_expect(button.disabled, "Кнопка блокируется на время выполнения")
	_expect(code.get_line_background_color(0).a > 0, "Первая строка подсвечена")
	await create_timer(0.1).timeout
	_expect(robot.cell == Vector2i.ZERO, "Шаг не заканчивается раньше анимации")
	_expect(robot.position.z < 0 and robot.position.z > -1, "Движение идёт внутри шага")
	while robot.cell == Vector2i.ZERO:
		await process_frame
	_expect(code.get_line_background_color(0).a == 0, "Подсветка первой строки снята")
	_expect(code.get_line_background_color(1).a > 0, "Вторая строка подсвечена")
	while button.disabled:
		await process_frame
	_expect(code.get_line_background_color(1).a == 0, "Подсветка снята после программы")
	_expect(robot.cell == Vector2i(1, -1), "Кнопка запуска перемещает робота")
	_expect(robot.position.is_equal_approx(Vector3(1, 0, -1)), "Положение в 3D")
	code.text = "move('up')\nmove('wrong'"
	button.pressed.emit()
	await process_frame
	_expect(robot.cell == Vector2i(1, -1), "Ошибочная программа не двигает робота")
	code.text = "move('left')"
	button.pressed.emit()
	while button.disabled:
		await process_frame
	_expect(robot.cell == Vector2i(0, -1), "Повторный запуск сохраняет положение")
	code.text = "\n".repeat(80) + "move('up')"
	button.pressed.emit()
	await process_frame
	_expect(code.get_line_background_color(80).a > 0, "Подсветка после пустых строк")
	_expect(code.get_first_visible_line() > 0, "Редактор прокручивается к выполняемой строке")
	while button.disabled:
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
	while button.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "[b]Привет[/b]\nГотово\n", "Порядок вывода")
	_expect(robot.cell == previous_cell + Vector2i.RIGHT, "Смешанная программа")
	code.text = "move('left')"
	_expect(output.visible and not messages.get_parsed_text().is_empty(), "Правка сохраняет вывод")
	button.pressed.emit()
	_expect(not output.visible and messages.get_parsed_text().is_empty(), "Новый запуск очищает вывод")
	while button.disabled:
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
	while button.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "Исправлено\n", "Исправленный запуск очищает ошибку")
	var stop: Button = editor.get_node("Margin/Content/Header/Stop")
	code.text = "move('up')\nmove('right')"
	previous_cell = robot.cell
	button.pressed.emit()
	await create_timer(0.1).timeout
	stop.pressed.emit()
	_expect(button.disabled and code.editable, "Остановка ждёт анимацию, ввод доступен")
	while button.disabled:
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
	while button.disabled:
		await process_frame
	_expect(robot.cell == previous_cell + Vector2i.UP * 2, "Правка останавливает новый запуск после первой инструкции")
	code.text = "print('Сохранить')\nprint('Не выполнять')"
	button.pressed.emit()
	stop.pressed.emit()
	while button.disabled:
		await process_frame
	_expect(messages.get_parsed_text() == "Сохранить\n", "Остановка сохраняет вывод текущей инструкции")
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
