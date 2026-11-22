extends SceneTree

const CargoGenerator = preload("res://scripts/gameplay/cargo_generator.gd")
const START_TO_INPUT := 'move("up")\nmove("up")\nmove("up")\nmove("left")\n'
const INPUT_TO_ORANGE := (
		'move("right")\nmove("right")\nmove("right")\nmove("right")\nmove("down")\nmove("down")\n'
)
const INPUT_TO_LOWER_ZONE := INPUT_TO_ORANGE + 'move("down")\n'
const ORANGE_TO_INPUT := (
		'move("up")\nmove("up")\nmove("left")\nmove("left")\nmove("left")\nmove("left")\n'
)
const DELIVER_ORANGE := START_TO_INPUT + "grab()\n" + INPUT_TO_ORANGE + "put()"
# Восемь шевронов на замкнутом профиле полотна из GLB.
const BELT_MARKING_INTERVAL := (4.0 * 0.839 + TAU * 0.155) / 8.0

var _failures: int = 0
var _checks: int = 0
var _moves: Array[Vector2i] = []
var _action_running: bool = false
var _started_lines: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var cargo_generation_requested := arguments.has("--cargo-generation")
	var robot_turns_requested := arguments.has("--robot-turns")
	var delivery_requested := arguments.has("--delivery")
	var input_tray_requested := arguments.has("--input-tray")
	var camera_drag_requested := arguments.has("--camera-drag")
	var camera_zoom_requested := arguments.has("--camera-zoom")
	var order_progress_requested := arguments.has("--order-progress")
	var evolve_program_requested := arguments.has("--evolve-program")
	var reference_requested := arguments.has("--learning-reference")
	var output_panel_requested := arguments.has("--output-panel")
	if (
			arguments.has("--reset-cargo") or arguments.has("--functions")
			or arguments.has("--syntax-highlighting") or camera_zoom_requested
			or camera_drag_requested or robot_turns_requested or delivery_requested or input_tray_requested
			or order_progress_requested or cargo_generation_requested or evolve_program_requested
			or reference_requested or output_panel_requested
	):
		if cargo_generation_requested:
			_test_cargo_generation()
		elif output_panel_requested:
			await _test_output_panel()
		elif reference_requested:
			await _test_reference_panel()
			await _test_while()
		elif evolve_program_requested:
			await _test_step_order_acceptance()
		elif order_progress_requested:
			await _test_order_progress()
			await _test_step_order_acceptance()
		elif input_tray_requested:
			await _test_input_tray()
		elif delivery_requested:
			await _test_delivery()
		elif robot_turns_requested:
			await _test_robot_turns()
		elif camera_drag_requested:
			await _test_camera_drag()
		elif camera_zoom_requested:
			await _test_camera_zoom()
		elif arguments.has("--syntax-highlighting"):
			await _test_syntax_highlighting()
		elif arguments.has("--functions"):
			await _test_functions()
		else:
			await _test_reset_cargo()
		print("Проверки: %d; ошибки: %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return
	_test_cargo_generation()
	await _test_variables()
	await _test_while()
	await _test_functions()
	await _test_conditions()
	await _test_first_lesson()
	await _test_order_progress()
	await _test_step_order_acceptance()
	_test_parser()
	_test_print_parser()
	await _test_execution()
	await _test_diagnostics()
	await _test_scene()
	await _test_output_panel()
	await _test_robot_turns()
	await _test_camera_zoom()
	await _test_camera_drag()
	await _test_reference_panel()
	await _test_syntax_highlighting()
	await _test_delivery()
	await _test_input_tray()
	await _test_wrong_delivery()
	await _test_reset_cargo()
	print("Проверки: %d; ошибки: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_cargo_generation() -> void:
	var colors: Array[String] = ["orange", "blue", "a", "b", "c", "d", "e", "f"]
	for color_count: int in [2, 6, 8]:
		var available := colors.slice(0, color_count)
		var random := RandomNumberGenerator.new()
		random.seed = 42
		var generator := CargoGenerator.new(available, random)
		var window := 6 if color_count == 2 else color_count * 2
		var seen: Dictionary[String, int] = {}
		var covers_every_window := true
		for index: int in range(300):
			var color: String = generator.next_color("orange")
			seen[color] = index
			for candidate: String in available:
				covers_every_window = (
						covers_every_window and index - seen.get(candidate, -1) < window
				)
		_expect(
				covers_every_window and seen.size() == color_count,
				"Покрываются все виды грузов при числе видов %d" % color_count
		)
	_test_cargo_weights()


func _test_cargo_weights() -> void:
	var first_draw_matches := true
	var next_draw_matches := true
	var first_colors: Dictionary[String, bool] = {}
	for sample_seed: int in range(128):
		var random := RandomNumberGenerator.new()
		var expected_random := RandomNumberGenerator.new()
		random.seed = sample_seed
		expected_random.seed = sample_seed
		var generator := CargoGenerator.new(["orange", "blue"], random, "orange")
		# Учебная выдача увеличила вес синей до 2, вес нужной оранжевой равен 2.
		var expected_first := "orange" if expected_random.randi_range(1, 4) <= 2 else "blue"
		var first := generator.next_color("orange")
		first_colors[first] = true
		first_draw_matches = first_draw_matches and first == expected_first
		# Второй заказ отдаёт предпочтение синей. После оранжевой веса 1:4, после синей 2:2.
		var next_roll := expected_random.randi_range(1, 5 if expected_first == "orange" else 4)
		var orange_weight := 1 if expected_first == "orange" else 2
		var expected_next := "orange" if next_roll <= orange_weight else "blue"
		var next := generator.next_color("blue")
		next_draw_matches = next_draw_matches and next == expected_next
	_expect(first_draw_matches and first_colors.size() == 2, "Веса определяют случайную выдачу")
	_expect(next_draw_matches, "Смена заказа меняет базовые веса и сохраняет бонусы за пропуски")


func _instantiate_game_with_known_cargo(cargo_seed: int = 74) -> Control:
	var game: Control = preload("res://scenes/SorterGame.tscn").instantiate()
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	# Начальное значение даёт оба цвета в нужном порядке для проверок маршрутов.
	field.cargo_random.seed = cargo_seed
	return game


func _test_robot_turns() -> void:
	var game: Control = preload("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	var robot: SorterRobot = game.get_node("Layout/Field/Viewport/World/Robot")
	var content: VBoxContainer = game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var messages: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var spawn_pose: Transform3D = robot.transform

	code.text = "move('down')\nmove('right')\nmove('down')"
	await _step_robot_move(robot, step, stop, Vector2i(1, 4), Vector3.BACK, 0)
	await _step_robot_move(robot, step, stop, Vector2i(2, 4), Vector3.RIGHT, 1)
	var edge_pose: Transform3D = robot.transform
	step.pressed.emit()
	await process_frame
	_expect(
			stop.disabled and messages.get_parsed_text().contains("границу поля"),
			"Выход за границу отклоняется сразу"
	)
	_expect(
			robot.cell == Vector2i(2, 4) and robot.transform == edge_pose,
			"Отказ сохраняет клетку и позу"
	)

	code.text = "move('up')\nmove('right')\nmove('left')\nmove('up')"
	await _step_robot_move(robot, step, stop, Vector2i(2, 3), Vector3.FORWARD, 1)
	await _step_robot_move(robot, step, stop, Vector2i(3, 3), Vector3.RIGHT, -1)
	await _step_robot_move(robot, step, stop, Vector2i(2, 3), Vector3.LEFT, -1, true)
	_expect(stop.disabled, "Стоп завершает выполнение после разворота и переезда")
	reset.pressed.emit()
	_expect(
			robot.cell == Vector2i(1, 3) and robot.transform == spawn_pose,
			"Сброс восстанавливает стартовую позу"
	)
	code.text = "move('down')"
	await _step_robot_move(robot, step, stop, Vector2i(1, 4), Vector3.BACK, 0)
	game.queue_free()
	await process_frame


func _step_robot_move(
		robot: SorterRobot, step: Button, stop: Button, destination: Vector2i,
		heading: Vector3, turn_sign: int, stop_during_turn: bool = false
) -> void:
	var start_cell: Vector2i = robot.cell
	var start_position: Vector3 = robot.position
	var start_heading: Vector3 = robot.basis.z
	var start_direction: Vector2i = robot.direction
	var destination_direction: Vector2i = destination - start_cell
	var treads: Array[Node] = robot.find_children("Tread_*", "MeshInstance3D", true, false)
	var tread_positions: PackedVector3Array = _get_tread_positions(treads)
	var drive_motion := Vector2.ZERO
	var turn_motion := Vector2.ZERO
	step.pressed.emit()
	var deadline: SceneTreeTimer = create_timer(2.0)
	var saw_turn := false
	var saw_move := false
	var turned_before_moving := true
	var signs_match := true
	var cell_and_direction_updated_in_order := true
	while step.disabled and deadline.time_left > 0:
		var new_positions: PackedVector3Array = _get_tread_positions(treads)
		var track_motion: Vector2 = _get_track_motion(tread_positions, new_positions)
		tread_positions = new_positions
		cell_and_direction_updated_in_order = (
				cell_and_direction_updated_in_order and robot.cell == start_cell
		)
		if not robot.position.is_equal_approx(start_position):
			if saw_move:
				drive_motion += track_motion
			saw_move = true
			turned_before_moving = turned_before_moving and robot.basis.z.is_equal_approx(heading)
			cell_and_direction_updated_in_order = (
					cell_and_direction_updated_in_order and robot.direction == destination_direction
			)
		elif not robot.basis.z.is_equal_approx(start_heading):
			var cross_y: float = start_heading.cross(robot.basis.z).y
			if not robot.basis.z.is_equal_approx(heading) and not is_zero_approx(cross_y):
				turn_motion += track_motion
				cell_and_direction_updated_in_order = (
						cell_and_direction_updated_in_order and robot.direction == start_direction
				)
				signs_match = signs_match and signf(cross_y) == turn_sign
				if not saw_turn and stop_during_turn:
					stop.pressed.emit()
				saw_turn = true
		await process_frame
	_expect(
			saw_turn == (turn_sign != 0) and signs_match,
			"Штабель поворачивает на месте в нужную сторону"
	)
	_expect(saw_move and turned_before_moving, "Штабель едет после поворота лицом к целевой клетке")
	_expect(
			cell_and_direction_updated_in_order,
			"Направление обновляется после поворота, клетка после переезда"
	)
	_expect(
			robot.cell == destination and robot.basis.z.is_equal_approx(heading),
			"Шаг завершает весь переезд"
	)
	_expect(drive_motion.x > 0 and drive_motion.y > 0, "При переезде обе гусеницы идут вперёд")
	if turn_sign != 0:
		_expect(
				turn_motion.x * turn_sign > 0 and turn_motion.y * turn_sign < 0,
				"При повороте гусеницы идут в противоположные стороны"
		)
	var stopped_positions: PackedVector3Array = _get_tread_positions(treads)
	await create_timer(0.05).timeout
	_expect(
			_get_tread_positions(treads) == stopped_positions,
			"Гусеницы останавливаются после шага"
	)


func _get_tread_positions(treads: Array[Node]) -> PackedVector3Array:
	var positions := PackedVector3Array()
	for tread: Node3D in treads:
		positions.append(tread.position)
	return positions


func _get_track_motion(previous: PackedVector3Array, current: PackedVector3Array) -> Vector2:
	var motion := Vector2.ZERO
	for index: int in previous.size():
		var before: Vector3 = previous[index]
		var after: Vector3 = current[index]
		# На верхней ветви гусеницы траки движутся вперёд по локальной оси Z.
		if before.y > 0.22 and after.y > 0.22:
			if after.x < 0.0:
				motion.x += after.z - before.z
			else:
				motion.y += after.z - before.z
	return motion


func _test_camera_drag() -> void:
	var game: Control = preload("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var field_view: SubViewportContainer = game.get_node("Layout/Field")
	var camera: Camera3D = field_view.get_node("Viewport/World/Camera")
	var code := game.find_child("Code", true, false) as CodeEdit
	var field_origin := field_view.global_position
	var field_position := field_origin + field_view.size * Vector2(0.85, 0.65)
	var editor_position := code.get_global_rect().get_center()
	var moved_position := field_position + Vector2(24, -16)
	const PROJECTION_DEPTH := 15.0
	_push_mouse_button(field_position, MOUSE_BUTTON_LEFT, true)
	_move_mouse_at(editor_position, editor_position - field_position, MOUSE_BUTTON_MASK_LEFT)
	_push_mouse_button(editor_position, MOUSE_BUTTON_MIDDLE, true)
	_push_mouse_button(editor_position, MOUSE_BUTTON_LEFT, false)
	var point_after_release := camera.project_position(field_position - field_origin, PROJECTION_DEPTH)
	_push_mouse_button(editor_position, MOUSE_BUTTON_LEFT, true)
	_move_mouse_at(moved_position, moved_position - editor_position,
			MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE)
	_expect(
			camera.unproject_position(point_after_release).distance_to(field_position - field_origin) < 1,
			"Новый жест над редактором не начинается при удержании другой кнопки"
	)
	_push_mouse_button(moved_position, MOUSE_BUTTON_LEFT, false)
	_push_mouse_button(moved_position, MOUSE_BUTTON_MIDDLE, false)

	# Правая кнопка в редакторе открывает контекстное меню, поэтому проверяем её последней.
	var buttons := {
		MOUSE_BUTTON_LEFT: MOUSE_BUTTON_MASK_LEFT,
		MOUSE_BUTTON_MIDDLE: MOUSE_BUTTON_MASK_MIDDLE,
		MOUSE_BUTTON_RIGHT: MOUSE_BUTTON_MASK_RIGHT,
	}
	for button: MouseButton in buttons:
		var mask: MouseButtonMask = buttons[button]
		var grabbed_point := camera.project_position(field_position - field_origin, PROJECTION_DEPTH)
		_push_mouse_button(field_position, button, true)
		_move_mouse_at(moved_position, moved_position - field_position, mask)
		var projected_point := camera.unproject_position(grabbed_point)
		_expect(
				projected_point.distance_to(moved_position - field_origin) < 1.0,
				"Точка поля остаётся под движущимся указателем с кнопкой %d" % button
		)
		_move_mouse_at(editor_position, editor_position - moved_position, mask)
		projected_point = camera.unproject_position(grabbed_point)
		_expect(
				projected_point.distance_to(editor_position - field_origin) < 1.0,
				"Жест кнопкой %d продолжается при выходе указателя за поле" % button
		)
		_push_mouse_button(editor_position, button, false)
		_move_mouse_at(field_position, field_position - editor_position, 0)
		_expect(
				camera.unproject_position(grabbed_point).is_equal_approx(projected_point),
				"Отпускание кнопки %d над редактором завершает жест" % button
		)
		_push_mouse_button(editor_position, button, true)
		_move_mouse_at(field_position, field_position - editor_position, mask)
		_push_mouse_button(field_position, button, false)
		_expect(
				camera.unproject_position(grabbed_point).is_equal_approx(projected_point),
				"Нажатие кнопки %d в редакторе не перетаскивает поле" % button
		)
	game.queue_free()
	await process_frame


func _test_camera_zoom() -> void:
	var game: Control = preload("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var field_view: SubViewportContainer = game.get_node("Layout/Field")
	var camera: Camera3D = field_view.get_node("Viewport/World/Camera")
	var field_position := field_view.global_position + field_view.size * Vector2(0.9, 0.65)
	var initial_size := camera.size
	_expect(_is_field_in_view(camera), "При открытии сцены всё поле помещается в кадр")
	var field_center := Vector3(2, 0, 2)
	var initial_screen_center := camera.unproject_position(field_center)
	_scroll_at(field_position, MOUSE_BUTTON_WHEEL_UP)
	_expect(camera.size < initial_size, "Колёсико вверх над полем приближает камеру")
	for tick in range(24):
		_scroll_at(field_position, MOUSE_BUTTON_WHEEL_UP)
	_expect(is_equal_approx(camera.size, initial_size / 2.0), "Приближение ограничено 2×")
	_expect(
		initial_screen_center.distance_to(camera.unproject_position(field_center)) < 1.0,
		"Центр поля остаётся на месте при приближении"
	)
	var closest_size := camera.size
	_scroll_at(field_position, MOUSE_BUTTON_WHEEL_DOWN)
	_expect(camera.size > closest_size, "Колёсико вниз над полем отдаляет камеру")
	for tick in range(24):
		_scroll_at(field_position, MOUSE_BUTTON_WHEEL_DOWN)
	_expect(is_equal_approx(camera.size, initial_size), "Отдаление ограничено видом всего поля")

	_scroll_at(field_position, MOUSE_BUTTON_WHEEL_UP)
	var zoomed_size := camera.size
	var code := game.find_child("Code", true, false) as CodeEdit
	code.text = "pass\n".repeat(100)
	await process_frame
	var first_visible_line := code.get_first_visible_line()
	_scroll_at(code.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	await process_frame
	_expect(code.get_first_visible_line() > first_visible_line, "Колёсико прокручивает программу")
	_expect(is_equal_approx(camera.size, zoomed_size), "Прокрутка программы сохраняет масштаб поля")
	game.queue_free()
	await process_frame


func _is_field_in_view(camera: Camera3D) -> bool:
	var visible_rect := camera.get_viewport().get_visible_rect()
	for mesh: MeshInstance3D in camera.get_parent().find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var bounds := mesh.get_aabb()
		for corner in range(8):
			var point := mesh.to_global(bounds.get_endpoint(corner))
			if camera.is_position_behind(point) or not visible_rect.has_point(
					camera.unproject_position(point)
			):
				return false
	return true


func _scroll_at(position: Vector2, button: MouseButton) -> void:
	_push_mouse_button(position, button, true)


func _push_mouse_button(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func _move_mouse_at(position: Vector2, relative: Vector2, buttons: MouseButtonMask) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = buttons
	root.push_input(event, true)


func _test_syntax_highlighting() -> void:
	var game: Node = preload("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	var code := game.find_child("Code", true, false) as CodeEdit
	var highlighter := code.syntax_highlighter
	_expect(highlighter != null, "В игровой сцене подключена подсветка синтаксиса")
	if highlighter != null:
		var examples := {
			"color = get_box_color()": {
				"color": "#b8d9ff", "=": "#a0b3c9", "get_box_color": "#7ddfff",
			},
			'color = "blue"': { '"blue"': "#a6e3a1" },
			'if color == "orange":': { "if": "#cba6f7", "==": "#a0b3c9" },
			"else:": { "else": "#cba6f7" },
			'while state == "repeat":': { "while": "#cba6f7", "==": "#a0b3c9" },
			"while True:": { "while": "#cba6f7", "True": "#f9c97a" },
			"while False:": { "False": "#f9c97a" },
			"    pass": { "pass": "#cba6f7" },
			"def deliver():": { "def": "#cba6f7", "deliver": "#7ddfff" },
			"deliver()": { "deliver": "#7ddfff" },
			"def travel(direction):": { "direction": "#b8d9ff" },
			'travel("right")': { '"right"': "#a6e3a1" },
			"travel(direction)": { "direction": "#b8d9ff" },
			"    return direction": { "return": "#cba6f7" },
			"    return None": { "return": "#cba6f7", "None": "#cba6f7" },
			"import len(42) #": { "import": "#b8d9ff", "len": "#7ddfff" },
			'color = "if': { '"if': "#a6e3a1" },
		}
		for source: String in examples:
			code.text = source
			await process_frame
			var changes := highlighter.get_line_syntax_highlighting(0)
			for token: String in examples[source]:
				var change: Dictionary = changes.get(source.find(token), {})
				_expect(
					change.get("color") == Color(examples[source][token]),
					"Цвет «%s» в строке «%s»" % [token, source]
				)
		code.text = "if\npass"
		await process_frame
		var before := highlighter.get_line_syntax_highlighting(1)
		code.set_line(1, "False")
		await process_frame
		var after := highlighter.get_line_syntax_highlighting(1)
		_expect(before != after, "Подсветка обновляется при редактировании строки")
		code.text = "42 # while_true"
		await process_frame
		var unsupported := highlighter.get_line_syntax_highlighting(0)
		_expect(
			not unsupported.has(0) and not unsupported.has(3),
			"Числа и знак комментария Python не получают отдельной подсветки"
		)
		_expect(
			unsupported.get(5, {}).get("color") == Color("#b8d9ff"),
			"Ключевое слово внутри имени не меняет цвет идентификатора"
		)
	game.queue_free()
	await process_frame


func _test_functions() -> void:
	var game := _instantiate_game_with_known_cargo()
	root.add_child(game)
	await process_frame
	var content := game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var output: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var run: Button = content.get_node("Header/Run")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	var executor: ProgramExecutor = game.get("_executor")
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	var lines: Array[int] = []
	var cells_before_step: Array[Vector2i] = []
	executor.step_started.connect(func(line: int) -> void:
		lines.append(line)
		cells_before_step.append(robot.cell)
		_expect(code.get_line_background_color(line - 1).a > 0, "Строка функции подсвечена")
	)
	code.text = "def choose():\n    return 'right'\n    pass\nx = choose()\nmove(x)"
	for single_step: bool in [false, true]:
		lines.clear()
		var start: Button = step if single_step else run
		start.pressed.emit()
		var return_deadline := create_timer(5.0)
		while not stop.disabled and return_deadline.time_left > 0.0:
			if single_step and not step.disabled:
				step.pressed.emit()
			await process_frame
		_expect(lines == [4, 2, 5] and robot.cell == Vector2i(2, 3), "Возврат передаёт направление")
		content.get_node("ResetCargo").pressed.emit()
		await process_frame
	code.text = "def travel(direction):\n    move(direction)\ntravel('right')\n"
	code.text += "right = 'left'\ntravel(right)"
	for single_step: bool in [false, true]:
		lines.clear()
		cells_before_step.clear()
		var start: Button = step if single_step else run
		start.pressed.emit()
		var deadline := create_timer(5.0)
		while not stop.disabled and deadline.time_left > 0.0:
			if single_step and not step.disabled:
				step.pressed.emit()
			await process_frame
		_expect(stop.disabled and lines == [3, 2, 4, 5, 2]
				and cells_before_step == [Vector2i(1, 3), Vector2i(1, 3), Vector2i(2, 3),
						Vector2i(2, 3), Vector2i(2, 3)] and robot.cell == Vector2i(1, 3),
				"Аргументы меняют направление движения в обоих режимах")
	code.text = (
			'message = "global"\ndef advance():\n    print(message)\n'
			+ '    move("right")\ndef finish():\n    message = "local"\n'
			+ "    advance()\n    print(message)\nadvance()\nfinish()\nprint(message)"
	)
	for single_step: bool in [false, true]:
		lines.clear()
		var pauses: Array[int] = []
		var start: Button = step if single_step else run
		start.pressed.emit()
		var deadline := create_timer(8.0)
		while not stop.disabled and deadline.time_left > 0.0:
			if single_step and not step.disabled:
				pauses.append(lines.back())
				step.pressed.emit()
			await process_frame
		_expect(stop.disabled and lines == [1, 9, 3, 4, 10, 6, 7, 3, 4, 8, 11],
				"Вызов и тело функции подсвечиваются по порядку, возврат проходит без шага")
		_expect(output.get_parsed_text() == "global\nglobal\nlocal\nglobal\n",
				"Функции читают глобальные переменные, присваивания остаются локальными")
		if single_step:
			_expect(pauses == [1, 9, 3, 4, 10, 6, 7, 3, 4, 8],
					"Вызов и каждая инструкция тела занимают отдельный шаг")
		else:
			_expect(robot.cell == Vector2i(3, 3), "Два вызова перемещают робота дважды")
			var reset: Button = content.get_node("ResetCargo")
			reset.pressed.emit()
			await process_frame

	var reference := game.get_node("ReferencePanel")
	await _open_reference_section(game, "Functions")
	var article: RichTextLabel = reference.get_node("Content/Detail/Article")
	_expect(article.get_parsed_text().contains("def travel(direction):"),
			"Справка содержит пример функции с параметром")
	var paragraphs := article.get_parsed_text().split("\n\n")
	_expect(paragraphs.size() >= 5 and paragraphs[0] == "Функции",
			"Справка содержит объяснение и пример функций")
	if paragraphs.size() >= 5:
		var reset: Button = content.get_node("ResetCargo")
		reset.pressed.emit()
		await process_frame
		var zones: Array[Vector2i] = []
		field.cargo_delivered.connect(func(_color_name: String) -> void: zones.append(robot.cell))
		code.text = paragraphs[2] + "\n" + paragraphs[3]
		run.pressed.emit()
		var deadline := create_timer(20.0)
		while not stop.disabled and deadline.time_left > 0.0:
			await process_frame
		_expect(stop.disabled and zones == [Vector2i(4, 2), Vector2i(4, 3)],
				"Пример из справки двумя вызовами доставляет коробки в зоны их цветов")
	var return_zones: Array[Vector2i] = []
	field.cargo_delivered.connect(func(_color_name: String) -> void: return_zones.append(robot.cell))
	for single_step: bool in [false, true]:
		content.get_node("ResetCargo").pressed.emit()
		await process_frame
		code.text = paragraphs[-1]
		var start: Button = step if single_step else run
		start.pressed.emit()
		var deadline := create_timer(10.0)
		while not stop.disabled and deadline.time_left > 0.0:
			if single_step and not step.disabled:
				step.pressed.emit()
			await process_frame
		_expect(stop.disabled and executor.error == null, "Пример с return завершается")
	_expect(return_zones == [SorterField.ZONE_CELL, SorterField.BLUE_ZONE_CELL],
			"Назначение из return используется при доставке в обоих режимах")
	game.queue_free()
	await process_frame

	var parser := ProgramParser.new()
	for source: String in ["def", "def f(x, x):\n    pass", "def f():\npass",
			"def f():\n    def g():\n        pass", "def get_box_color():\n    pass", "return"]:
		_expect(parser.parse(source).is_empty() and parser.error != null,
				"Синтаксическая ошибка в определении функции: " + source)
	var diagnostics_executor := ProgramExecutor.new()
	var output_values: Array[String] = []
	diagnostics_executor.output_emitted.connect(func(value: String) -> void: output_values.append(value))
	var parameter_program := parser.parse(
			"def show(first, second):\n    print(first)\n    print(second)\n"
			+ "def forward(value):\n    show(value, get_box_color())\nforward('local')"
	)
	var ran: bool = await diagnostics_executor.run(
			parameter_program, Callable(), self, false, Callable(), func() -> String: return "blue"
	)
	_expect(ran and output_values == ["local", "blue"],
			"Позиционные аргументы читаются в области вызывающего кода")
	output_values.clear()
	var none_program := parser.parse(
			"def empty():\n    pass\ndef bare():\n    return\n"
			+ "x = empty()\ny = bare()\nprint(x)\nprint(y)\n"
			+ "if x == None:\n    print('equal')\nif x == 'None':\n    print('wrong')"
	)
	ran = await diagnostics_executor.run(none_program, Callable(), self)
	_expect(ran and output_values == ["None", "None", "equal"], "Неявный возврат и return дают None")
	var missing_operand := parser.parse("def f():\n    print(missing)\nf()")
	var printed: bool = await diagnostics_executor.run(missing_operand, Callable(), self)
	_expect(not printed and diagnostics_executor.error != null
			and diagnostics_executor.error.line == 2 and diagnostics_executor.error.column == 11,
			"Диагностика указывает на имя в аргументе print")
	for sample: Array in [
		["f()\ndef f():\n    pass", "NameError"],
		["def f():\n    pass\nf('x')", "TypeError"],
		["def f(first, second):\n    pass\nf('x')", "TypeError"],
		["def f(value):\n    pass\nf(missing)", "NameError"],
		["direction = 'north'\nmove(direction)", "ValueError"],
		["move(right)", "NameError"],
		["def f():\n    f()\nf()", "RuntimeError"],
		["def f(x):\n    f()\nf('x')", "TypeError"],
		["f()", "NameError"],
	]:
		var commands := parser.parse(sample[0])
		var success: bool = await diagnostics_executor.run(commands, Callable(), self)
		_expect(parser.error == null and not success and diagnostics_executor.error != null
				and diagnostics_executor.error.type == sample[1],
				"Диагностика вызова: " + sample[0])


func _test_while() -> void:
	var game := _instantiate_game_with_known_cargo()
	root.add_child(game)
	await process_frame
	var content := game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var output: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var run: Button = content.get_node("Header/Run")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	var executor: ProgramExecutor = game.get("_executor")
	var lines: Array[int] = []
	executor.step_started.connect(func(line: int) -> void:
		lines.append(line)
		_expect(code.get_line_background_color(line - 1).a > 0, "Строка цикла подсвечена")
	)
	code.text = (
			'state = "repeat"\nwhile state == "repeat":\n'
			+ '    state = "done"\nprint(state)\nwhile False:\n    pass'
	)
	for single_step: bool in [false, true]:
		lines.clear()
		var pauses: Array[int] = []
		var start: Button = step if single_step else run
		start.pressed.emit()
		var deadline := create_timer(5.0)
		while not stop.disabled and deadline.time_left > 0.0:
			if single_step and not step.disabled:
				pauses.append(lines.back())
				step.pressed.emit()
			await process_frame
		_expect(stop.disabled and lines == [1, 2, 3, 2, 4, 5], "Цикл повторно проверяет условие")
		_expect(output.get_parsed_text() == "done\n", "После выхода доступно значение из цикла")
		if single_step:
			_expect(pauses == [1, 2, 3, 2, 4], "Каждая проверка while занимает отдельный шаг")

	code.text = "while True:\n    pass"
	lines.clear()
	run.pressed.emit()
	var deadline := create_timer(4.0)
	while not stop.disabled and lines.size() < 3 and deadline.time_left > 0.0:
		await process_frame
	_expect(lines == [1, 2, 1], "pass возвращает управление к условию while")
	stop.pressed.emit()
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(stop.disabled and executor.was_stopped, "Стоп прерывает цикл без движений")
	step.pressed.emit()
	deadline = create_timer(4.0)
	while step.disabled and not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(executor.is_paused, "Цикл с pass можно приостановить пошаговым запуском")
	stop.pressed.emit()
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(stop.disabled and executor.was_stopped, "Стоп работает и в паузе цикла")

	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	var progress: Label = game.get_node("Lesson/Content/OrderProgress")
	var reference: Panel = game.get_node("ReferencePanel")
	await _open_reference_section(game, "While")
	var article: RichTextLabel = reference.get_node("Content/Detail/Article")
	code.text = article.text.get_slice("\n\n", 2)
	_expect(
			article.is_visible_in_tree() and code.text.contains("while True:")
			and article.text.contains("Когда заказ выполнен"),
			"Справка объясняет, как завершить заказ встроенным циклом"
	)
	var reference_toggle: Button = game.get_node("ReferenceToggle")
	reference_toggle.button_pressed = false
	var zones: Array[Vector2i] = []
	field.cargo_delivered.connect(func(_color_name: String) -> void:
		zones.append(robot.cell)
		if progress.text == "Заказ выполнен: 3 из 3 оранжевых":
			stop.pressed.emit()
	)
	run.pressed.emit()
	deadline = create_timer(60.0)
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(
			stop.disabled and progress.text == "Заказ выполнен: 3 из 3 оранжевых"
			and zones.has(SorterField.ZONE_CELL) and zones.has(SorterField.BLUE_ZONE_CELL),
			"Встроенный пример завершает первый заказ и доставляет коробки обоих цветов"
	)
	game.queue_free()
	await process_frame


func _test_conditions() -> void:
	var game := _instantiate_game_with_known_cargo()
	root.add_child(game)
	await process_frame
	var content := game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var executor: ProgramExecutor = game.get("_executor")
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	var lines: Array[int] = []
	executor.step_started.connect(func(line: int) -> void:
		lines.append(line)
		_expect(code.get_line_background_color(line - 1).a > 0, "Текущий шаг подсвечен")
	)
	code.text = (
			"color = get_box_color()\n" + START_TO_INPUT + "grab()\n" + INPUT_TO_ORANGE
			+ 'if color == "orange":\n    put()\nelse:\n    move("down")\n    put()'
	)
	var lines_before_branch: Array[int] = []
	lines_before_branch.assign(range(1, 14))
	var orange_conveyor: SorterConveyor = field.get_node("OrangeOutputConveyor")
	var blue_conveyor: SorterConveyor = field.get_node("BlueOutputConveyor")
	for single_step: bool in [false, true]:
		for orange: bool in [true, false]:
			reset.pressed.emit()
			lines.clear()
			var selected: SorterConveyor = orange_conveyor if orange else blue_conveyor
			var idle: SorterConveyor = blue_conveyor if orange else orange_conveyor
			var selected_offset: float = selected.get_belt_offset()
			var idle_offset: float = idle.get_belt_offset()
			var start: Button = step if single_step else run
			start.pressed.emit()
			var deadline := create_timer(8.0)
			var condition_paused := false
			while not stop.disabled and deadline.time_left > 0.0:
				if single_step and not step.disabled:
					if lines == lines_before_branch:
						condition_paused = field.carrying
					step.pressed.emit()
				await process_frame
			if single_step:
				_expect(condition_paused, "После проверки if есть пауза перед командой ветви")
			var expected: Array[int] = lines_before_branch.duplicate()
			expected.append_array([14] if orange else [16, 17])
			_expect(lines == expected, "После if выполняются только строки выбранной ветви")
			var zone := Vector2i(4, 2) if orange else Vector2i(4, 3)
			_expect(stop.disabled and field.delivered and robot.cell == zone,
					"Коробка доставлена в зону своего цвета")
			_expect(
					selected.get_belt_offset() != selected_offset
					and idle.get_belt_offset() == idle_offset,
					"При доставке движется только выбранная выходная лента"
			)
	reset.pressed.emit()
	code.text = START_TO_INPUT + "grab()\n" + INPUT_TO_ORANGE + 'move("down")\nput()'
	run.pressed.emit()
	var deadline := create_timer(8.0)
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(executor.action_error == "Этой коробке нужна зона orange.",
			"Зона другого цвета отклоняет доставку")
	_expect(robot.direction == Vector2i.DOWN, "Отказ в чужой зоне не поворачивает Штабеля")
	_expect(field.carrying and not field.delivered, "Ошибочная доставка не меняет текущий груз")
	reset.pressed.emit()
	_expect(field.get_box_color() == "orange", "Перезапуск груза сохраняет цвет")
	code.text = 'if get_box_color() == "blue":\n    print("blue")\nprint("После if")'
	lines.clear()
	run.pressed.emit()
	deadline = create_timer(3.0)
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(lines == [1, 3], "Ложное условие без else пропускает блок и продолжает программу")
	var reference: Panel = game.get_node("ReferencePanel")
	await _open_reference_section(game, "Conditions")
	var article: RichTextLabel = reference.get_node("Content/Detail/Article")
	_expect(article.is_visible_in_tree() and article.text.contains('if color == "orange":'),
			"Учебный пример условий доступен в справке")
	game.queue_free()
	await process_frame


func _test_variables() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	var content := game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var output: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var run: Button = content.get_node("Header/Run")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	code.text = (
			"color = get_box_color()\nsaved = color\n"
			+ 'color = "blue"\nprint(saved)\nprint(color)\n'
			+ START_TO_INPUT + "grab()\nprint(get_box_color())"
	)
	step.pressed.emit()
	var deadline := create_timer(8.0)
	while step.disabled and not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	var paused := not step.disabled and not stop.disabled
	_expect(paused, "После присваивания пошаговый запуск ставит программу на паузу")
	if paused:
		run.pressed.emit()
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(output.get_parsed_text() == "orange\nblue\norange\n",
			"Строковые переменные сохраняются между шагами и копируются по значению")
	code.text = "print(color)"
	run.pressed.emit()
	_expect(output.get_parsed_text().contains("NameError: name 'color' is not defined"),
			"Новый запуск не наследует переменные")
	_expect(code.get_line_background_color(0).a > 0, "Неизвестная переменная выделяет строку")
	var reference: Panel = game.get_node("ReferencePanel")
	await _open_reference_section(game, "Output")
	var article: RichTextLabel = reference.get_node("Content/Detail/Article")
	_expect(article.is_visible_in_tree() and article.text.contains("saved = color"),
			"Справка объясняет сохранение и копирование значения")
	_expect(article.text.contains("Как читать ошибки") and article.text.contains("номер строки"),
			"В справке объяснены диагностика и переход к строке")
	game.queue_free()
	await process_frame


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
		"move('up'", "move('up\")", "move('up') move('down')",
		"move('up');", "move('u\np')", "move(42)",
		"move('up')\n@", "move('up')\nmove('bad'",
		"if 'a' == 'a':\nprint('нет отступа')",
		"if 'a' = 'a':\n    print('нет сравнения')",
		"if 'a' == 'a':\n    print('ветвь')\n  print('неверный отступ')",
		"while True:\npass", "while False\n    pass", "while True:\n    pass()",
		"True = 'repeat'", "while 'repeat' == False:\n    pass",
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
	commands = parser.parse("print(42)")
	_expect(commands.is_empty() and parser.error != null, "print не принимает число")
	commands = parser.parse("print(get_box_color())")
	_expect(commands.size() == 1 and parser.error == null, "В print допустим вызов get_box_color()")
	for source: String in ["print(get_box_color(", "print(get_box_color()", "print(get_box_color('x'))"]:
		commands = parser.parse(source)
		_expect(commands.is_empty() and parser.error != null, "Ошибочный вложенный вызов отклоняется")


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


func _test_first_lesson() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	var lesson: PanelContainer = game.get_node_or_null("Lesson")
	_expect(lesson != null and lesson.visible, "Задание доступно при запуске")
	if lesson == null:
		game.queue_free()
		await process_frame
		return

	var toggle: Button = lesson.get_node("Content/Header/Toggle")
	var details: RichTextLabel = lesson.get_node("Content/Details")
	var delivery_program := DELIVER_ORANGE
	var field: Control = game.get_node("Layout/Field")
	var field_rect := field.get_global_rect()
	_expect(not details.visible and not toggle.button_pressed, "Задание изначально свёрнуто")
	_expect(is_equal_approx(lesson.size.y, lesson.get_combined_minimum_size().y),
			"При запуске свёрнутая карточка занимает только высоту своего содержимого")
	_click_button(toggle)
	await process_frame
	_expect(details.visible and details.text.contains('move("up")'), "В уроке есть первая команда")
	_expect(details.text.contains(delivery_program), "В уроке есть проверенная программа доставки")
	_expect(field.get_global_rect() == field_rect, "Карточка задания не сдвигает поле")
	_click_button(toggle)
	await process_frame
	_expect(not details.visible and not toggle.button_pressed, "Шеврон сворачивает задание")
	_expect(is_equal_approx(lesson.size.y, lesson.get_combined_minimum_size().y),
			"После сворачивания карточка возвращается к высоте своего содержимого")
	_click_button(toggle)
	await process_frame
	_expect(details.visible, "Урок можно открыть снова")
	await _play_first_lesson(game, lesson.get_node("Content/Goal"), delivery_program)
	await _test_lesson_width(game, lesson)
	game.queue_free()
	await process_frame


func _test_lesson_width(game: Control, lesson: PanelContainer) -> void:
	var layout: HSplitContainer = game.get_node("Layout")
	var field: Control = layout.get_node("Field")
	var title: Label = lesson.get_node("Content/Header/Title")
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size.x = 1152
	layout.split_offsets = PackedInt32Array([10000])
	await process_frame
	await process_frame
	_expect(is_equal_approx(lesson.size.x, 380), "На широком поле карточка шириной 380 px")
	_expect(title.get_line_count() == 1, "На широком поле заголовок занимает одну строку")
	var wide_font_size := title.get_theme_font_size("font_size")

	layout.clamp_split_offset()
	layout.split_offsets = PackedInt32Array([layout.split_offsets[0] - 24])
	await process_frame
	await process_frame
	_expect(is_equal_approx(lesson.size.x, 380), "Небольшой сдвиг не сужает карточку")
	_expect(title.get_line_count() == 1, "При прежней ширине карточки заголовок не переносится")
	_expect(title.get_theme_font_size("font_size") == wide_font_size, "Шрифт не скачет при сдвиге")

	game.size.x = 672
	layout.split_offsets = PackedInt32Array([10000])
	await process_frame
	await process_frame
	_expect(title.get_line_count() == 1, "При минимальном редакторе переносов нет и в узком окне")
	_expect(lesson.get_rect().end.x <= field.size.x - 16, "Карточка помещается на узком поле")

	game.size.x = 1152
	layout.split_offsets = PackedInt32Array([-10000])
	await process_frame
	await process_frame
	_expect(title.get_line_count() > 1, "При расширении редактора заголовок может переноситься")
	_expect(title.get_theme_font_size("font_size") == wide_font_size, "Перенос не увеличивает шрифт")
	_expect(lesson.get_rect().end.x <= field.size.x - 16, "Карточка сужается вслед за полем")


func _play_first_lesson(game: Control, goal: Label, delivery_program: String) -> void:
	var content := game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var robot: SorterRobot = game.get_node("Layout/Field/Viewport/World/Robot")
	var first_step_cell: Vector2i = robot.cell + Vector2i.UP

	code.text = 'move("up")'
	step.pressed.emit()
	_expect(code.get_line_background_color(0).a > 0, "Первый шаг подсвечивает команду")
	while not stop.disabled:
		await process_frame
	_expect(robot.cell == first_step_cell, "Первый шаг ведёт к коробке")
	reset.pressed.emit()
	code.text = 'move("north")'
	run.pressed.emit()
	_expect(code.get_line_background_color(0).a > 0, "Ошибка направления выделяет строку")

	code.text = delivery_program
	run.pressed.emit()
	stop.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(robot.cell == first_step_cell, "Стоп завершает только текущую команду")
	reset.pressed.emit()
	step.pressed.emit()
	while step.disabled:
		await process_frame
	_expect(robot.cell == first_step_cell, "После первой команды программа на паузе")
	run.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(goal.text == "Коробка доставлена", "Продолжение со второй строки завершает урок")


func _test_order_progress() -> void:
	var game := _instantiate_game_with_known_cargo()
	root.add_child(game)
	await process_frame
	var progress: Label = game.get_node_or_null("Lesson/Content/OrderProgress")
	var accept_order: Button = game.get_node_or_null("Lesson/Content/AcceptOrder")
	_expect(
			progress != null and progress.is_visible_in_tree()
			and progress.text == "Заказ: оранжевые коробки — 0 из 3",
			"Карточка показывает цель первого заказа и начальный прогресс"
	)
	if progress == null:
		game.queue_free()
		await process_frame
		return
	_expect(
			accept_order != null and not accept_order.is_visible_in_tree(),
			"Предложение следующего заказа скрыто при запуске"
	)

	var content: VBoxContainer = game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var message: Label = content.get_node("Message")
	var output: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var deliver_blue := START_TO_INPUT + "grab()\n" + INPUT_TO_LOWER_ZONE + "put()"
	var empty_progress := "Заказ: оранжевые коробки — 0 из 3"
	var first_delivery := "Заказ: оранжевые коробки — 1 из 3"
	var second_delivery := "Заказ: оранжевые коробки — 2 из 3"

	code.text = deliver_blue
	_expect(
			await _run_order_program(run, stop)
			and output.get_parsed_text().contains("Этой коробке нужна зона orange.")
			and progress.text == empty_progress,
			"Попытка доставить оранжевую коробку в синюю зону не засчитывается"
	)

	code.text = 'move("up")\nput()'
	_expect(
			await _run_order_program(run, stop) and progress.text == first_delivery,
			"Правильная доставка оранжевой коробки продвигает заказ"
	)

	code.text = ORANGE_TO_INPUT + "grab()"
	await process_frame
	_expect(progress.text == first_delivery, "Редактирование кода сохраняет прогресс заказа")
	_expect(
			await _run_order_program(run, stop) and message.text == "Программа завершена.",
			"Робот забирает следующий груз с выдачи"
	)
	reset.pressed.emit()
	_expect(
			message.text == "Текущий груз возвращён на выдачу." and progress.text == first_delivery,
			"Возврат захваченного груза сохраняет прогресс по предыдущей коробке"
	)

	var completed := "Заказ выполнен: 3 из 3 оранжевых"
	for delivery: Array in [
		[deliver_blue, first_delivery],
		[DELIVER_ORANGE, second_delivery],
		[deliver_blue, second_delivery],
		[DELIVER_ORANGE, completed],
	]:
		code.text = delivery[0]
		_expect(
				await _run_order_program(run, stop)
				and message.text == "Программа завершена." and progress.text == delivery[1],
				"После правильной доставки карточка показывает «%s»" % delivery[1]
		)
		reset.pressed.emit()
	_expect(
			accept_order != null and accept_order.is_visible_in_tree() and not accept_order.disabled,
			"Выполнение первого заказа открывает кнопку принятия следующего"
	)
	await _verify_order_acceptance(game, false)
	game.queue_free()
	await process_frame


func _test_step_order_acceptance() -> void:
	# В этом сценарии оба цвета поступают по два раза после смены правил.
	var game := _instantiate_game_with_known_cargo(75)
	root.add_child(game)
	await process_frame
	var content: VBoxContainer = game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var old_program := (
			START_TO_INPUT + "grab()\n" + INPUT_TO_ORANGE
			+ 'if get_box_color() == "orange":\n    put()\nelse:\n    move("down")\n    put()'
	)
	code.text = old_program
	for delivery: int in range(5):
		if not await _run_order_program(run, stop):
			_expect(false, "Первый заказ выполнен перед проверкой пошагового принятия")
			break
		reset.pressed.emit()
	await _verify_order_acceptance(game, true)
	await _verify_evolved_program(game, old_program)
	game.queue_free()
	await process_frame


func _verify_evolved_program(game: Control, old_program: String) -> void:
	var lesson: PanelContainer = game.get_node("Lesson")
	var toggle: Button = lesson.get_node("Content/Header/Toggle")
	var details: RichTextLabel = lesson.get_node("Content/Details")
	var progress: Label = lesson.get_node("Content/OrderProgress")
	toggle.button_pressed = true
	await process_frame
	_expect(
			details.is_visible_in_tree() and details.text.begins_with("Как обновить программу")
			and details.text.contains("выбор зоны по цвету")
			and details.text.contains("функцию") and details.text.contains(DELIVER_ORANGE),
			"Карточка подсказывает, как обновить маршруты, и сохраняет объяснение первого урока"
	)
	toggle.button_pressed = false
	await _open_reference_section(game, "While")
	var article: RichTextLabel = game.get_node("ReferencePanel/Content/Detail/Article")
	_expect(article.text.contains('if color == "blue":'), "Цикл учитывает новый порядок зон")
	await _open_reference_section(game, "Functions")
	_expect(
			article.text.contains('if color == "blue":')
			and article.text.contains('if zone == "orange":'),
			"Примеры функций и return учитывают новый порядок зон"
	)
	await _open_reference_section(game, "Conditions")
	var inline_program := article.text.get_slice("\n\n", 2)
	_expect(inline_program.contains('if color == "blue":'),
			"Условие открывается с новым маршрутом")
	var reference_toggle: Button = game.get_node("ReferenceToggle")
	reference_toggle.button_pressed = false
	var content: VBoxContainer = game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var output: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	reset.pressed.emit()
	_expect(
			code.text == old_program and await _run_order_program(run, stop)
			and output.get_parsed_text().contains("нужна зона blue")
			and progress.text == "Заказ: синие коробки — 0 из 3",
			"Сохранённая программа со старыми маршрутами требует правки для второго заказа"
	)
	var delivered_cells: Array[Vector2i] = []
	field.cargo_delivered.connect(func(_color_name: String) -> void:
		delivered_cells.append(robot.cell)
	)
	var function_program := (
			'def put_in_zone(color):\n    if color == "blue":\n        put()\n'
			+ '    else:\n        move("down")\n        put()\n'
			+ START_TO_INPUT + "grab()\n" + INPUT_TO_ORANGE + "put_in_zone(get_box_color())"
	)
	for program: String in [inline_program, function_program]:
		delivered_cells.clear()
		code.text = program
		for delivery: int in range(2):
			reset.pressed.emit()
			if not await _run_order_program(run, stop):
				break
		var expected := "1 из 3" if program == inline_program else "2 из 3"
		_expect(
				delivered_cells == [SorterField.ZONE_CELL, SorterField.BLUE_ZONE_CELL]
				and progress.text == "Заказ: синие коробки — " + expected,
				"Корректная программа с %s доставляет коробки обоих цветов"
				% ("условием" if program == inline_program else "функцией")
		)


func _verify_order_acceptance(game: Control, single_step: bool) -> void:
	var progress: Label = game.get_node("Lesson/Content/OrderProgress")
	var accept_order: Button = game.get_node_or_null("Lesson/Content/AcceptOrder")
	var rules: Label = game.get_node_or_null("Lesson/Content/OrderRules")
	var content: VBoxContainer = game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var step: Button = content.get_node("Header/Step")
	var stop: Button = content.get_node("Header/Stop")
	var message: Label = content.get_node("Message")
	var output: RichTextLabel = content.get_node("EditorSplit/OutputPanel/Messages")
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	if accept_order == null or not accept_order.is_visible_in_tree() or rules == null:
		_expect(false, "Карточка предлагает следующий заказ")
		return
	var upper_zone := Vector2i(4, 2)
	var lower_zone := Vector2i(4, 3)
	_expect(
			progress.text == "Заказ выполнен: 3 из 3 оранжевых"
			and rules.is_visible_in_tree() and rules.text.contains("3 синие коробки")
			and _zones_match(field, upper_zone, lower_zone),
			"Предложение показывает новый заказ и сохраняет прежние зоны до принятия"
	)
	if not single_step:
		code.text = DELIVER_ORANGE
		_expect(
				await _run_order_program(run, stop)
				and output.get_parsed_text().contains("нужна зона blue")
				and progress.text == "Заказ выполнен: 3 из 3 оранжевых",
				"Будущая клетка синей зоны отклоняет синюю коробку до принятия заказа"
		)
	var source := code.text if single_step else 'move("up")\nmove("up")\nprint("Старый запуск")'
	var cargo_color := field.get_box_color()
	var was_carrying := field.carrying
	var held_box: Node3D
	if not single_step:
		var blue_model: PackedScene = SorterField.CARGO_MODELS["blue"]
		held_box = _find_scene_instance(robot.cargo_socket, blue_model.resource_path)
		_expect(
				was_carrying and cargo_color == "blue" and held_box != null,
				"До принятия заказа робот держит синюю коробку"
		)
	code.text = source
	var next_cell := robot.cell + Vector2i.UP
	if single_step:
		step.pressed.emit()
		var pause_deadline := create_timer(3.0)
		while step.disabled and pause_deadline.time_left > 0.0:
			await process_frame
		_expect(not step.disabled and not stop.disabled, "Программа ждёт следующего шага")
	else:
		run.pressed.emit()
		_expect(not stop.disabled, "Программа выполняется автоматически")
	accept_order.pressed.emit()
	var stop_deadline := create_timer(5.0)
	while not stop.disabled and stop_deadline.time_left > 0.0:
		await process_frame
	await create_timer(0.5).timeout
	_expect(
			stop.disabled and robot.cell == next_cell and code.text == source
			and field.get_box_color() == cargo_color and field.carrying == was_carrying,
			"Принятие останавливает старый запуск после текущей инструкции и сохраняет код и груз"
	)
	_expect(
			not accept_order.is_visible_in_tree()
			and progress.text == "Заказ: синие коробки — 0 из 3"
			and rules.text.contains("Синие") and rules.text.contains("верхняя")
			and message.text.contains("Заказ принят") and _zones_match(field, lower_zone, upper_zone),
			"После принятия видны новые правила, цветные плитки и подписи поменялись местами"
	)
	if single_step:
		return
	_expect(
			is_instance_valid(held_box) and held_box.get_parent() == robot.cargo_socket,
			"После принятия заказа у робота остаётся та же коробка"
	)
	code.text = 'move("down")\nmove("down")\nput()'
	_expect(
			await _run_order_program(run, stop) and output.get_parsed_text().contains("нужна зона blue")
			and progress.text == "Заказ: синие коробки — 0 из 3"
			and is_instance_valid(held_box) and held_box.get_parent() == robot.cargo_socket,
			"Прежняя зона отклоняет доставку и оставляет ту же коробку у робота"
	)
	code.text = 'move("up")'
	_expect(
			await _run_order_program(run, stop) and robot.cell == upper_zone
			and is_instance_valid(held_box) and held_box.get_parent() == robot.cargo_socket,
			"Робот привозит исходную коробку в новую зону"
	)
	code.text = "put()"
	_expect(
			await _run_order_program(run, stop) and message.text == "Программа завершена."
			and not field.carrying and progress.text == "Заказ: синие коробки — 1 из 3",
			"Доставка в новую синюю зону продвигает второй заказ"
	)
	_expect(
			field.get_box_color() == "blue",
			"Для заданной выборки следующая коробка синяя только с весами второго заказа"
	)


func _zones_match(field: SorterField, orange: Vector2i, blue: Vector2i) -> bool:
	var tiles_match := true
	for tile: Array in [
		["res://assets/models/field/direction_tile.glb", orange],
		["res://assets/models/field/direction_tile_blue.glb", blue],
	]:
		var model := _find_scene_instance(field, tile[0])
		var cell: Vector2i = tile[1]
		tiles_match = tiles_match and model != null and model.global_position.is_equal_approx(
				field.to_global(Vector3(cell.x, -0.15, cell.y))
		)
	var labels_match := 0
	for label: Label3D in field.find_children("*", "Label3D", true, false):
		for zone: Array in [["orange", orange], ["blue", blue]]:
			var cell: Vector2i = zone[1]
			if label.text == zone[0] and label.global_position.is_equal_approx(
					field.to_global(Vector3(cell.x, 0.1, cell.y - 0.5))
			):
				labels_match += 1
	return tiles_match and labels_match == 2


func _run_order_program(run: Button, stop: Button) -> bool:
	run.pressed.emit()
	var deadline := create_timer(20.0)
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	return stop.disabled


func _test_reference_panel() -> void:
	var packed: PackedScene = load("res://scenes/SorterGame.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame
	var panel: Panel = game.get_node_or_null("ReferencePanel")
	var toggle: Button = game.get_node_or_null("ReferenceToggle")
	_expect(panel != null and not panel.visible and toggle != null and toggle.visible,
			"При запуске видна только кнопка справки")
	if panel == null or toggle == null:
		game.queue_free()
		return

	var code: CodeEdit = game.get_node("Layout/ProgramEditor/Margin/Content/EditorSplit/Code")
	var field: Control = game.get_node("Layout/Field")
	var sections: ScrollContainer = panel.get_node("Content/Sections")
	var detail: VBoxContainer = panel.get_node("Content/Detail")
	var article: RichTextLabel = detail.get_node("Article")
	var movement: Button = sections.get_node("List/Movement")
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
	var camera: Camera3D = field.get_node("Viewport/World/Camera")
	var camera_size := camera.size
	var camera_offset := Vector2(camera.h_offset, camera.v_offset)
	_click_button(toggle)
	await process_frame
	var compact_rect := panel.get_global_rect()
	_expect(panel.visible and sections.visible and compact_rect.end.y < toggle.global_position.y,
			"Список разделов открывается над кнопкой")
	_expect(panel.size.x <= 320.0 and panel.size.y <= field.size.y * 0.4,
			"Выпадающая справка укладывается в согласованные размеры")
	_click_button(movement)
	await process_frame
	_expect(detail.visible and article.text.contains('move("up")'), "В справке есть пример")
	_expect(panel.get_global_rect() == compact_rect, "Статья открывается в том же окне")
	_expect(field.get_global_rect() == field_rect, "При раскрытии поле остаётся на месте")
	_click_button(back)
	await process_frame
	_expect(sections.visible and panel.get_global_rect() == compact_rect, "Возврат к списку")
	await _open_reference_section(game, "Output")
	article.scroll_to_line(article.get_line_count() - 1)
	_expect(article.get_v_scroll_bar().value > 0.0 and panel.get_global_rect() == compact_rect,
			"Длинная статья прокручивается внутри окна")
	_click_button(toggle)
	_expect(not panel.visible, "Повторное нажатие сворачивает справку")
	_expect(camera.size == camera_size
			and Vector2(camera.h_offset, camera.v_offset) == camera_offset,
			"Открытие и закрытие справки сохраняют кадр поля")
	_expect(code.text == source and code.get_caret_line() == 40 and code.get_caret_column() == 5,
			"Справка сохраняет текст и курсор")
	_expect(code.scroll_vertical == scroll and code.has_focus(), "Сохраняются прокрутка и фокус")
	_expect(code.get_global_rect() == code_rect, "Редактор остаётся на месте")
	_expect(field.get_global_rect() == field_rect, "При сворачивании поле остаётся на месте")
	game.queue_free()
	await process_frame


func _open_reference_section(game: Control, section_name: String) -> void:
	var toggle: Button = game.get_node("ReferenceToggle")
	toggle.button_pressed = false
	_click_button(toggle)
	await process_frame
	var sections: ScrollContainer = game.get_node("ReferencePanel/Content/Sections")
	var section: Button = sections.get_node("List/" + section_name)
	sections.ensure_control_visible(section)
	await process_frame
	_click_button(section)
	await process_frame


func _click_button(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	_push_mouse_button(position, MOUSE_BUTTON_LEFT, true)
	_push_mouse_button(position, MOUSE_BUTTON_LEFT, false)


func _test_output_panel() -> void:
	var game := _instantiate_game_with_known_cargo()
	root.add_child(game)
	var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
	var code := editor.find_child("Code", true, false) as CodeEdit
	var output := editor.find_child("OutputPanel", true, false) as OutputPanel
	var messages: RichTextLabel = output.get_node("Messages")
	var toggle: Button = output.get_node("Title")
	editor.append_output("Первое сообщение")
	await process_frame
	await process_frame
	_expect(
			toggle.text == "Вывод" and output.position.y - code.get_rect().end.y <= 8.0,
			"Между кодом и выводом узкий разделитель, заголовок без стрелки"
	)
	var initial_output_height := output.size.y
	await _drag_output_boundary(code, output, -game.size.y)
	_expect(
			is_equal_approx(code.size.y, 180.0) and output.size.y > initial_output_height,
			"Перетаскивание вверх увеличивает вывод и сохраняет минимум поля кода"
	)
	await _drag_output_boundary(code, output, output.size.y - 80.0)
	_expect(
			is_equal_approx(output.size.y, 120.0) and code.size.y > 180.0,
			"Перетаскивание вниз сохраняет минимум панели вывода"
	)
	await _drag_output_boundary(code, output, -40.0)
	_expect(is_equal_approx(output.size.y, 160.0), "Граница следует за мышью")
	var expanded_code_height := code.size.y
	await _drag_output_boundary(code, output, output.size.y - 24.0)
	_expect(
			toggle.is_visible_in_tree() and toggle.text == "Вывод"
			and not messages.is_visible_in_tree()
			and code.size.y > expanded_code_height,
			"Перетаскивание к нижнему краю оставляет заголовок и увеличивает поле кода"
	)
	_click_button(toggle)
	await process_frame
	await process_frame
	_expect(
			messages.is_visible_in_tree() and messages.get_parsed_text() == "Первое сообщение\n"
			and is_equal_approx(output.size.y, 160.0),
			"Повторное раскрытие сохраняет сообщения и выбранную высоту"
	)
	var down := Vector2(0.0, 2.0)
	_move_mouse_at(_output_boundary_position(code, output) + down, down, 0)
	await process_frame
	await process_frame
	_expect(is_equal_approx(output.size.y, 160.0), "Наведение на границу не меняет высоту")
	_click_button(toggle)
	editor.append_output("Второе сообщение")
	_expect(
			messages.is_visible_in_tree()
			and messages.get_parsed_text() == "Первое сообщение\nВторое сообщение\n",
			"Новое сообщение раскрывает свёрнутый вывод и сохраняет предыдущие сообщения"
	)
	_click_button(toggle)
	editor.show_error("Ошибка программы")
	_expect(
			messages.is_visible_in_tree()
			and messages.get_parsed_text().ends_with("Ошибка программы\n"),
			"Ошибка программы раскрывает свёрнутый вывод"
	)
	_click_button(toggle)
	editor.show_action_error("Ошибка действия")
	_expect(
			messages.is_visible_in_tree()
			and messages.get_parsed_text().ends_with("Ошибка действия\n"),
			"Ошибка действия раскрывает свёрнутый вывод"
	)
	_click_button(toggle)
	var previous_output := messages.get_parsed_text()
	code.text = "print('Новый запуск')"
	_expect(
			not messages.is_visible_in_tree() and messages.get_parsed_text() == previous_output,
			"Правка программы сохраняет свёрнутый вывод"
	)
	var run: Button = editor.get_node("Margin/Content/Header/Run")
	_click_button(run)
	_expect(
			messages.is_visible_in_tree() and messages.get_parsed_text() == "Новый запуск\n",
			"Новый запуск очищает свёрнутый вывод и показывает новые сообщения"
	)
	game.queue_free()
	await process_frame


func _drag_output_boundary(code: CodeEdit, output: OutputPanel, distance: float) -> void:
	var position := _output_boundary_position(code, output)
	var motion := Vector2(0.0, distance)
	_move_mouse_at(position, Vector2.ZERO, 0)
	_push_mouse_button(position, MOUSE_BUTTON_LEFT, true)
	_move_mouse_at(position + motion, motion, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_push_mouse_button(position + motion, MOUSE_BUTTON_LEFT, false)
	await process_frame
	await process_frame


func _output_boundary_position(code: CodeEdit, output: OutputPanel) -> Vector2:
	var code_rect := code.get_global_rect()
	var boundary_y := (code_rect.end.y + output.get_global_rect().position.y) * 0.5
	return Vector2(code_rect.get_center().x, boundary_y)


func _test_scene() -> void:
	var game := _instantiate_game_with_known_cargo()
	root.add_child(game)
	await process_frame
	var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
	var code: CodeEdit = editor.get_node("Margin/Content/EditorSplit/Code")
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
	var output: OutputPanel = editor.get_node("Margin/Content/EditorSplit/OutputPanel")
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
	field.cargo_delivered.connect(
			func(_color_name: String) -> void: delivery_cells.append(robot.cell)
	)
	code.text = (
			DELIVER_ORANGE + "\n" + ORANGE_TO_INPUT + "grab()\n" + INPUT_TO_ORANGE
			+ "move('down')\nput()\n"
			+ "print('Готово')"
	)
	button.pressed.emit()
	while not stop.disabled:
		await process_frame
	_expect(
			delivery_cells == [SorterField.ZONE_CELL, SorterField.BLUE_ZONE_CELL],
			"Одна программа выполняет две доставки, робот остаётся в зоне"
	)
	_expect(field.delivered and not field.carrying, "Доставка засчитана после put")
	_expect(game.get_node("Lesson/Content/Goal").text == "Коробка доставлена", "Успех виден игроку")
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


func _test_input_tray() -> void:
	var game: Control = preload("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	var content: Control = game.get_node("Layout/ProgramEditor/Margin/Content")
	var code: CodeEdit = content.get_node("EditorSplit/Code")
	var run: Button = content.get_node("Header/Run")
	var stop: Button = content.get_node("Header/Stop")
	var reset: Button = content.get_node("ResetCargo")
	var cargo_scene: PackedScene = SorterField.CARGO_MODELS[field.get_box_color()]
	var cargo: Node3D = _find_scene_instance(field, cargo_scene.resource_path)
	var landing_marker: Marker3D = field.get_node("InputConveyor/InputTray/CargoLanding")
	var landing: Vector3 = field.to_local(landing_marker.global_position)
	var belt_height: float = cargo.position.y
	var input: SorterConveyor = field.get_node("InputConveyor")
	var start_offset: float = input.get_belt_offset()
	var start_x: float = cargo.position.x
	await create_timer(0.1).timeout
	_expect(
			is_equal_approx(input.get_belt_offset() - start_offset, cargo.position.x - start_x)
			and cargo.position.x > start_x,
			"Рисунок входной ленты движется на то же расстояние, что и коробка"
	)
	var position_before_reset: Vector3 = cargo.position
	reset.pressed.emit()
	_expect(cargo.position == position_before_reset, "Сброс сохраняет ход подачи коробки")
	var saw_drop := false
	var falling_offset: float = NAN
	var deadline: SceneTreeTimer = create_timer(4.0)
	while not cargo.position.is_equal_approx(landing) and deadline.time_left > 0.0:
		saw_drop = saw_drop or cargo.position.y < belt_height - 0.02
		if saw_drop and is_nan(falling_offset):
			falling_offset = input.get_belt_offset()
		await process_frame
	_expect(
			saw_drop and cargo.position.is_equal_approx(landing),
			"Коробка опускается с ленты и остаётся в точке захвата в лотке"
	)
	_expect(input.get_belt_offset() == falling_offset, "Во время падения входная лента неподвижна")
	var settled_offset: float = input.get_belt_offset()
	var tray: Node3D = landing_marker.get_parent_node_3d()
	var lip_x: float = field.to_local(tray.global_position).x
	_expect(
			absf(settled_offset - fposmod(lip_x - start_x, BELT_MARKING_INTERVAL)) < 0.002,
			"Входная лента останавливается у края полотна"
	)
	var next_feed_offsets: Array[float] = []
	field.cargo_delivered.connect(
			func(_color_name: String) -> void: next_feed_offsets.append(input.get_belt_offset())
	)

	code.text = DELIVER_ORANGE
	run.pressed.emit()
	deadline = create_timer(8.0)
	while not stop.disabled and deadline.time_left > 0.0:
		await process_frame
	_expect(stop.disabled and field.delivered, "После доставки запускается следующая подача")
	_expect(next_feed_offsets == [settled_offset], "Следующая подача сохраняет положение рисунка")
	if not stop.disabled or not field.delivered:
		game.queue_free()
		await process_frame
		return

	cargo_scene = SorterField.CARGO_MODELS[field.get_box_color()]
	cargo = _find_scene_instance(field, cargo_scene.resource_path)
	code.text = 'move("left")\n'.repeat(4) + 'move("up")\n'.repeat(2) + "grab()"
	run.pressed.emit()
	var waited_for_cargo := false
	deadline = create_timer(5.0)
	while not stop.disabled and deadline.time_left > 0.0:
		if (robot.cell == SorterField.CARGO_CELL and cargo.get_parent() == field
				and not cargo.position.is_equal_approx(landing)):
			waited_for_cargo = true
		await process_frame
	_expect(waited_for_cargo, "Ранний grab ждёт коробку на клетке выдачи")
	_expect(
			is_equal_approx(
					input.get_belt_offset(), fposmod(2.0 * settled_offset, BELT_MARKING_INTERVAL)
			),
			"Следующая коробка продвигает рисунок с сохранённого положения"
	)
	_expect(stop.disabled and field.carrying and robot.is_ancestor_of(cargo), "Захват ждёт падения")
	_expect(robot.direction == Vector2i.LEFT, "grab разворачивает Штабеля к приёмному лотку")
	_expect(
			cargo.get_parent() == robot.cargo_socket and cargo.transform.is_equal_approx(
					Transform3D.IDENTITY
			),
			"После захвата коробка следует за точкой крепления захватов"
	)
	reset.pressed.emit()
	_expect(
			cargo.get_parent() == field and cargo.position.is_equal_approx(landing) and not field.carrying,
			"Сброс возвращает захваченную коробку в лоток"
	)
	game.queue_free()
	await process_frame


func _test_delivery() -> void:
	var game: Control = load("res://scenes/SorterGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var field: SorterField = game.get_node("Layout/Field/Viewport/World")
	var robot: SorterRobot = field.get_node("Robot")
	var model: Node3D = _find_scene_instance(robot, "res://assets/models/robots/shtabel.glb")
	_expect(model != null and model.is_visible_in_tree(), "На поле отображается модель Штабеля")
	var model_pose: Transform3D
	if model != null:
		model_pose = robot.global_transform.affine_inverse() * model.global_transform
		var body := model.find_child("Body_LowerShell", true, false) as MeshInstance3D
		_expect(body != null, "У модели Штабеля виден корпус")
		if body != null:
			var bounds: AABB = body.global_transform * body.get_aabb()
			var center: Vector3 = bounds.get_center()
			_expect(bounds.size.x < 1.0 and bounds.size.z < 1.0, "Корпус помещается на клетке")
			_expect(
					Vector2(center.x, center.z).is_equal_approx(Vector2(robot.cell)),
					"Середина корпуса совпадает с центром клетки"
			)
		var model_bounds: AABB = _get_mesh_bounds(model)
		_expect(absf(model_bounds.position.y - 0.01) < 0.002, "Гусеницы стоят на поверхности плитки")
	var parser := ProgramParser.new()
	var executor := ProgramExecutor.new()
	for source: String in ["grab()", "put()"]:
		await executor.run(parser.parse(source), robot.move, self, false, field.perform)
		_expect(not executor.action_error.is_empty(), "Неверное действие отклонено: " + source)
	await executor.run(
			parser.parse(START_TO_INPUT + "grab()\nput()"), robot.move, self, false, field.perform
	)
	_expect(field.carrying and not field.delivered, "Отказ положить вне зоны сохраняет коробку у робота")
	if model != null:
		_expect(
				robot.cell == SorterField.CARGO_CELL and model.global_transform.is_equal_approx(
						robot.global_transform * model_pose
				),
				"Модель поворачивается и перемещается вместе с роботом"
		)
		var cargo_scene: PackedScene = SorterField.CARGO_MODELS[field.get_box_color()]
		var cargo: Node3D = _find_scene_instance(robot, cargo_scene.resource_path)
		_expect(
				cargo != null and cargo.is_visible_in_tree()
				and cargo.get_parent() == robot.cargo_socket
				and robot.to_local(cargo.global_position).z > 0.5,
				"Переносимая коробка видна в захватах перед корпусом"
		)
	await executor.run(parser.parse("grab()"), robot.move, self, false, field.perform)
	_expect(field.carrying and not executor.action_error.is_empty(), "Повторный захват отклонён")
	await executor.run(parser.parse("move('left')\nmove('left')"), robot.move, self, false, field.perform)
	_expect(
			robot.cell == SorterField.CARGO_CELL and field.carrying,
			"Граница сохраняет позицию и груз"
	)
	var commands: Array[ProgramCommand] = parser.parse(INPUT_TO_ORANGE + "put()")
	var orange_conveyor: SorterConveyor = field.get_node("OrangeOutputConveyor")
	var output_start_offset: float = orange_conveyor.get_belt_offset()
	executor.run(commands, robot.move, self, true, field.perform)
	for index: int in range(6):
		while executor.is_running and not executor.is_paused:
			await process_frame
		_expect(executor.is_paused and not field.delivered, "Переноска по шагам не засчитывает доставку")
		executor.resume(true)
	await create_timer(0.1).timeout
	_expect(not field.delivered, "Успех ждёт завершения put")
	var stationary_until_release: bool = orange_conveyor.get_belt_offset() == output_start_offset
	executor.request_stop()
	var cargo_scene: PackedScene = SorterField.CARGO_MODELS[field.get_box_color()]
	var outgoing: Node3D = _find_scene_instance(field, cargo_scene.resource_path)
	var travelled_on_belt := false
	var released_on_belt := false
	var release_x: float = NAN
	var release_offset: float = NAN
	var followed_box := true
	var half_interval: float = BELT_MARKING_INTERVAL / 2.0
	while executor.is_running:
		if is_instance_valid(outgoing) and outgoing.get_parent() == field:
			if is_nan(release_x):
				release_x = outgoing.position.x
				release_offset = orange_conveyor.get_belt_offset()
				released_on_belt = absf(outgoing.position.y - 0.211) < 0.002
			var distance: float = outgoing.position.x - release_x
			var belt_delta: float = orange_conveyor.get_belt_offset() - release_offset
			var gap: float = wrapf(belt_delta - distance, -half_interval, half_interval)
			followed_box = followed_box and absf(gap) < 0.001
			travelled_on_belt = travelled_on_belt or outgoing.position.x > release_x + 0.1
		elif is_instance_valid(outgoing):
			var offset: float = orange_conveyor.get_belt_offset()
			stationary_until_release = stationary_until_release and offset == output_start_offset
		await process_frame
	_expect(field.delivered and not field.carrying, "Остановка дожидается завершения put и доставки")
	_expect(robot.direction == Vector2i.RIGHT, "put разворачивает Штабеля к выходному конвейеру")
	_expect(travelled_on_belt, "Коробка проезжает по выходному конвейеру")
	_expect(followed_box and travelled_on_belt, "Выходная лента движется вместе с коробкой")
	_expect(released_on_belt, "Захваты отпускают коробку на уровне выходной ленты")
	_expect(stationary_until_release, "До отпускания выходная лента стоит")
	await process_frame
	_expect(not is_instance_valid(outgoing), "Коробка исчезает после проезда по ленте")
	var output_stop_offset: float = orange_conveyor.get_belt_offset()
	await create_timer(0.1).timeout
	_expect(
			orange_conveyor.get_belt_offset() == output_stop_offset,
			"После доставки выходная лента стоит"
	)
	game.queue_free()
	await process_frame


func _find_scene_instance(parent: Node, scene_path: String) -> Node3D:
	for child: Node3D in parent.find_children("*", "Node3D", true, false):
		if child.scene_file_path == scene_path:
			return child
	return null


func _get_mesh_bounds(model: Node3D) -> AABB:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	var bounds := AABB()
	for index: int in meshes.size():
		var mesh: MeshInstance3D = meshes[index]
		var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = mesh_bounds if index == 0 else bounds.merge(mesh_bounds)
	return bounds


func _test_wrong_delivery() -> void:
	for single_step: bool in [false, true]:
		var game: Control = load("res://scenes/SorterGame.tscn").instantiate()
		root.add_child(game)
		await process_frame
		var field: SorterField = game.get_node("Layout/Field/Viewport/World")
		var robot: SorterRobot = field.get_node("Robot")
		var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
		var code: CodeEdit = editor.get_node("Margin/Content/EditorSplit/Code")
		var run: Button = editor.get_node("Margin/Content/Header/Run")
		var step: Button = editor.get_node("Margin/Content/Header/Step")
		var output: OutputPanel = editor.get_node("Margin/Content/EditorSplit/OutputPanel")
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
		code.text = START_TO_INPUT + "grab()\nput()\nprint('После отказа')\nmove('right')"
		_expect(not output.visible, "Перед ошибкой доставки панель скрыта")
		if single_step:
			step.pressed.emit()
			for index: int in range(5):
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
		var goal: Label = game.get_node("Lesson/Content/Goal")
		_expect(goal.text != "Коробка доставлена", "После отказа нет сообщения об успехе")
		executor.resume(true)
		await process_frame
		_expect(not executor.is_running and robot.cell == SorterField.CARGO_CELL, "Ошибочный запуск нельзя продолжить")
		# Кнопка «Шаг» после отказа начинает программу с первой инструкции.
		code.text = "move('right')\nprint('Не выполнять')"
		step.pressed.emit()
		while executor.is_running and not executor.is_paused:
			await process_frame
		_expect(
				robot.cell == SorterField.CARGO_CELL + Vector2i.RIGHT,
				"Шаг после отказа начинает новый запуск"
		)
		executor.request_stop()
		while executor.is_running:
			await process_frame
		code.text = "grab()"
		run.pressed.emit()
		while executor.is_running:
			await process_frame
		_expect(messages.get_parsed_text() == "Робот уже несёт коробку.\n", "Повторный захват выводит только причину отказа")
		code.text = "move('right')\nmove('right')\nmove('right')\nmove('down')\nmove('down')\nput()"
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
		await create_timer(SorterField.INPUT_FEED_DURATION + 0.1).timeout
		var field: SorterField = game.get_node("Layout/Field/Viewport/World")
		var robot: SorterRobot = field.get_node("Robot")
		var editor: ProgramEditor = game.get_node("Layout/ProgramEditor")
		var code: CodeEdit = editor.get_node("Margin/Content/EditorSplit/Code")
		var run: Button = editor.get_node("Margin/Content/Header/Run")
		var step: Button = editor.get_node("Margin/Content/Header/Step")
		var reset: Button = editor.get_node_or_null("Margin/Content/ResetCargo")
		var output: OutputPanel = editor.get_node("Margin/Content/EditorSplit/OutputPanel")
		var messages: RichTextLabel = output.get_node("Messages")
		var executor: ProgramExecutor = game.get("_executor")
		_expect(reset != null, "Есть отдельная кнопка восстановления груза")
		if reset == null:
			game.queue_free()
			await process_frame
			return
		var cargo: Node3D = field.get("_cargo")
		var original_position: Vector3 = cargo.position
		reset.pressed.emit()
		_expect(not reset.disabled and cargo.position == original_position, "На выдаче коробка остаётся на месте, кнопка доступна")
		var source: String = START_TO_INPUT + "grab()\nmove('right')\nprint('Нельзя продолжить')"
		if scenario == 3:
			source = "print('Сохранить')\nmove('right')"
		code.text = source
		if scenario == 4:
			step.pressed.emit()
			for index: int in range(5):
				while executor.is_running and not executor.is_paused:
					await process_frame
				if index < 4:
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
		_expect(cargo == field.get("_cargo"), "Восстановлена та же коробка")
		_expect(cargo.get_parent() == field and cargo.position == original_position, "Коробка возвращена на выдачу")
		_expect(not field.carrying and not field.delivered, "Груз снова доступен для захвата")
		_expect(code.text == source, "Восстановление сохраняет текст программы")
		_expect(messages.get_parsed_text() == output_before_reset, "Восстановление сохраняет накопленный вывод")
		executor.resume()
		await create_timer(0.4).timeout
		_expect(not executor.is_running and robot.cell == Vector2i(1, 3), "Старый запуск не продолжается после восстановления")
		_expect(code.get_line_background_color(0).a == 0, "Подсветка выполнения снята")
		# Исправление после неверной сдачи не теряется при восстановлении.
		code.text = START_TO_INPUT + "grab()\nput()"
		run.pressed.emit()
		while executor.is_running:
			await process_frame
		code.text = DELIVER_ORANGE
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
		var goal: Label = game.get_node("Lesson/Content/Goal")
		_expect(goal.text == "Коробка доставлена", "Результат доставки сохранён")
		var next_cargo: Node3D = field.get("_cargo")
		var feed_position: Vector3 = next_cargo.position
		reset.pressed.emit()
		_expect(not reset.disabled and field.delivered and next_cargo == field.get("_cargo")
				and next_cargo.get_parent() == field and next_cargo.position == feed_position,
				"После доставки кнопка доступна без отката результата")
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
	editor.get_node("Margin/Content/EditorSplit/Code").text = "move('left')"
	editor.get_node("Margin/Content/Header/Run").pressed.emit()
	while executor.is_running:
		await process_frame
	editor.get_node("Margin/Content/ResetCargo").pressed.emit()
	_expect(robot.cell == Vector2i(4, 4) and robot.position == Vector3(4, 0, 4), "Восстановление учитывает другую стартовую клетку карты")
	game.queue_free()
	await process_frame
