extends Node3D
class_name SorterField

signal cargo_delivered(color_name: String)

const FIELD_SIZE := 5
const FLOOR_TILE := preload("res://assets/models/field/floor_tile.glb")
const CARGO_CELL := Vector2i(0, 0)
const ZONE_CELL := Vector2i(4, 2)
const BLUE_ZONE_CELL := Vector2i(4, 3)
const INPUT_FEED_DURATION := 2.75
const INPUT_DROP_DURATION := 0.35
const OUTPUT_CARGO_END := Vector3(0.97, 0.592, 0)
const OUTPUT_FEED_DURATION := 0.8
const CARGO_MODELS := {
	"orange": preload("res://assets/models/cargo/parcel.glb"),
	"blue": preload("res://assets/models/cargo/parcel_blue.glb"),
}
const ZONES_BY_COLOR := {"orange": ZONE_CELL, "blue": BLUE_ZONE_CELL}
const ZONE_TILES := {
	ZONE_CELL: preload("res://assets/models/field/direction_tile.glb"),
	BLUE_ZONE_CELL: preload("res://assets/models/field/direction_tile_blue.glb"),
}

var carrying: bool = false
# Результат доставки сохраняется до захвата следующей коробки.
var delivered: bool = false
var _cargo: Node3D
var _input_feed: Tween
var _box_color_name: String = "orange"

@onready var _robot: SorterRobot = $Robot
@onready var _input_conveyor: SorterConveyor = $InputConveyor
@onready var _input_start: Marker3D = $InputConveyor/CargoStart
@onready var _input_drop_start: Marker3D = $InputConveyor/DropStart
@onready var _input_landing: Marker3D = $InputConveyor/InputTray/CargoLanding
@onready var _output_conveyors: Dictionary[Vector2i, SorterConveyor] = {
	ZONE_CELL: $OrangeOutputConveyor,
	BLUE_ZONE_CELL: $BlueOutputConveyor,
}


func _ready() -> void:
	for x: int in range(FIELD_SIZE):
		for y: int in range(FIELD_SIZE):
			var tile_scene: PackedScene = ZONE_TILES.get(Vector2i(x, y), FLOOR_TILE)
			var tile: Node3D = tile_scene.instantiate()
			# Совмещаем поверхность плитки с уровнем движения робота.
			tile.position = Vector3(x, -0.15, y)
			tile.scale = Vector3(0.98, 1, 0.98)
			add_child(tile)

	_box(Vector3(CARGO_CELL.x, 0, CARGO_CELL.y), Vector3(0.9, 0.04, 0.9), Color(0.3, 0.5, 0.9))
	for color_name: String in ZONES_BY_COLOR:
		var zone: Vector2i = ZONES_BY_COLOR[color_name]
		_add_label(color_name, Vector3(zone.x, 0.1, zone.y - 0.5))
	_add_label("Выдача", Vector3(CARGO_CELL.x, 0.1, CARGO_CELL.y - 0.5))
	_spawn_cargo()


func get_box_color() -> String:
	return _box_color_name


func reset_current_cargo() -> bool:
	_robot.reset_pose()
	if delivered or _input_feed.is_running():
		return false
	if _cargo.get_parent() != self:
		_cargo.reparent(self)
	_cargo.global_transform = _input_landing.global_transform
	carrying = false
	return true


func perform(command: ProgramCommand, duration: float) -> String:
	if command.type == ProgramCommand.Type.MOVE:
		var target: Vector2i = _robot.cell + command.direction
		if target.x < 0 or target.y < 0 or target.x >= FIELD_SIZE or target.y >= FIELD_SIZE:
			return "Робот не может выйти за границу поля."
		await _robot.move(command.direction, duration)
		return ""
	if command.type == ProgramCommand.Type.GRAB:
		if carrying:
			return "Робот уже несёт коробку."
		if _robot.cell != CARGO_CELL:
			return "На этой клетке нет коробки."
		if _input_feed.is_running():
			await _input_feed.finished
		await _robot.face(Vector2i.LEFT, duration)
		await _robot.animate_cargo(true, _attach_cargo)
		carrying = true
		delivered = false
	elif command.type == ProgramCommand.Type.PUT:
		if not carrying:
			return "У робота нет коробки."
		if _robot.cell not in ZONES_BY_COLOR.values():
			return "Коробку нужно положить в зоне доставки."
		if _robot.cell != ZONES_BY_COLOR[_box_color_name]:
			return "Этой коробке нужна зона %s." % _box_color_name
		await _robot.face(Vector2i.RIGHT, duration)
		await _deliver_cargo(_output_conveyors[_robot.cell])
	else:
		return "Неизвестное игровое действие."
	return ""


func _attach_cargo() -> void:
	_cargo.reparent(_robot.cargo_socket, false)
	_cargo.transform = Transform3D.IDENTITY


func _deliver_cargo(conveyor: SorterConveyor) -> void:
	var feed: Tween = create_tween()
	feed.pause()
	await _robot.animate_cargo(false, _release_cargo.bind(feed, conveyor))
	if feed.is_running():
		await feed.finished
	delivered = true
	remove_child(_cargo)
	_cargo.queue_free()
	var delivered_color := _box_color_name
	_box_color_name = "blue" if _box_color_name == "orange" else "orange"
	_spawn_cargo()
	cargo_delivered.emit(delivered_color)


func _release_cargo(feed: Tween, conveyor: SorterConveyor) -> void:
	_cargo.reparent(self)
	carrying = false
	conveyor.queue_transport(
			feed, _cargo, conveyor.to_global(OUTPUT_CARGO_END), OUTPUT_FEED_DURATION
	)
	feed.play()


func _spawn_cargo() -> void:
	var model: PackedScene = CARGO_MODELS[_box_color_name]
	_cargo = model.instantiate()
	_cargo.basis = global_basis.inverse() * _input_landing.global_basis
	_cargo.position = to_local(_input_start.global_position)
	add_child(_cargo)
	var drop_start: Vector3 = to_local(_input_drop_start.global_position)
	var landing: Vector3 = to_local(_input_landing.global_position)
	_input_feed = create_tween()
	_input_conveyor.queue_transport(
			_input_feed, _cargo, _input_drop_start.global_position,
			INPUT_FEED_DURATION - INPUT_DROP_DURATION
	)
	# После края ленты горизонтальная скорость постоянна, а падение ускоряется.
	_input_feed.tween_method(
			func(progress: float) -> void:
				var drop_position := drop_start.lerp(landing, progress)
				drop_position.y = lerpf(drop_start.y, landing.y, progress * progress)
				_cargo.position = drop_position,
			0.0, 1.0, INPUT_DROP_DURATION
	)


func _add_label(text: String, location: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = location
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	add_child(label)


func _box(location: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	instance.mesh = mesh
	instance.position = location
	add_child(instance)
	return instance
