extends SceneTree

var _failures: int = 0
var _checks: int = 0
var _moves: Array[Vector2i] = []
var _action_running: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_parser()
	await _test_execution()
	await _test_scene()
	print("Проверки: %d; ошибки: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_parser() -> void:
	var parser := ProgramParser.new()
	var commands: Array[MoveCommand] = parser.parse(
		"move(\"up\")\nmove('down')\nmove(\"left\")\nmove('right')"
	)
	_expect(parser.error_message.is_empty(), "Оба вида кавычек принимаются")
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
		"move()", "move(up)", "move('north')", "move('UP')", "walk('up')",
		"move('up'", "move('up\")", "move('up') move('down')",
		"move('up', 'down')", "move('up');", "move('u\np')", "move(42)",
		"move('up')\n@", "move('up')\nmove('bad')",
	]:
		commands = parser.parse(source)
		_expect(not parser.error_message.is_empty(), "Отклонён ввод: " + source)
		_expect(commands.is_empty(), "При ошибке нет частичной программы")
	commands = parser.parse("move('left')")
	_expect(commands.size() == 1 and parser.error_message.is_empty(), "Повторный разбор")
	commands = parser.parse(" \n\t\n")
	_expect(commands.is_empty() and parser.error_message.is_empty(), "Пустая программа")


func _test_execution() -> void:
	var parser := ProgramParser.new()
	var executor := ProgramExecutor.new()
	var commands: Array[MoveCommand] = parser.parse("move('up')\nmove('right')")
	executor.run(commands, _record_move)
	_expect(executor.is_running, "Выполнение началось")
	var accepted: bool = await executor.run(commands, _record_move)
	_expect(not accepted, "Повторный запуск во время выполнения отклонён")
	while executor.is_running:
		await process_frame
	_expect(_moves == [Vector2i.UP, Vector2i.RIGHT], "Порядок команд сохранён")
	_expect(not _action_running, "Последнее действие завершено")
	accepted = await executor.run([], _record_move)
	_expect(accepted and not executor.is_running, "Пустая программа завершается")


func _record_move(direction: Vector2i) -> void:
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
	var button: Button = editor.get_node("Margin/Content/Run")
	var robot: SorterRobot = game.get_node("Layout/Field/Viewport/World/Robot")
	var title: Label = editor.get_node("Margin/Content/Title")
	_expect(title.global_position.y >= 0, "Заголовок редактора помещается в окне")
	_expect(code.gutters_draw_line_numbers, "В редакторе включены номера строк")
	code.text = "move('up')\nmove(\"right\")"
	button.pressed.emit()
	_expect(button.disabled, "Кнопка блокируется на время выполнения")
	while button.disabled:
		await process_frame
	_expect(robot.cell == Vector2i(1, -1), "Кнопка запуска перемещает робота")
	_expect(robot.position.is_equal_approx(Vector3(1, 0, -1)), "Положение в 3D")
	code.text = "move('up')\nmove('wrong')"
	button.pressed.emit()
	await process_frame
	_expect(robot.cell == Vector2i(1, -1), "Ошибочная программа не двигает робота")
	code.text = "move('left')"
	button.pressed.emit()
	while button.disabled:
		await process_frame
	_expect(robot.cell == Vector2i(0, -1), "Повторный запуск сохраняет положение")
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
