extends Node3D
class_name SorterField

signal cargo_delivered()

const FIELD_SIZE := 5
const FLOOR_TILE := preload("res://assets/models/field/floor_tile.glb")
const CARGO_CELL := Vector2i(0, 0)
const ZONE_CELL := Vector2i(4, 2)
const BLUE_ZONE_CELL := Vector2i(4, 3)
const CARGO_POSITION := Vector3(CARGO_CELL.x + 0.4, 0.02, CARGO_CELL.y)
const INPUT_CARGO_START := Vector3(-2.24, 0.02, CARGO_CELL.y)
const INPUT_FEED_DURATION := 1.1
const OUTPUT_CARGO_START := Vector3(-0.75, 0.592, 0)
const OUTPUT_CARGO_END := Vector3(0.97, 0.592, 0)
const OUTPUT_FEED_DURATION := 0.8
const CARRIED_CARGO_POSITION := Vector3(0, 0.75, 0)
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
@onready var _output_conveyors: Dictionary[Vector2i, Node3D] = {
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
	_cargo.position = CARGO_POSITION
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
	elif command.type == ProgramCommand.Type.PUT:
		if not carrying:
			return "У робота нет коробки."
		if _robot.cell not in ZONES_BY_COLOR.values():
			return "Коробку нужно положить в зоне доставки."
		if _robot.cell != ZONES_BY_COLOR[_box_color_name]:
			return "Этой коробке нужна зона %s." % _box_color_name
	else:
		return "Неизвестное игровое действие."
	var grabbing: bool = command.type == ProgramCommand.Type.GRAB
	_cargo.reparent(_robot if grabbing else self)
	var tween: Tween = create_tween()
	if grabbing:
		tween.tween_property(_cargo, "position", CARRIED_CARGO_POSITION, duration)
	else:
		var conveyor: Node3D = _output_conveyors[_robot.cell]
		tween.tween_property(_cargo, "position", conveyor.transform * OUTPUT_CARGO_START, duration)
		tween.tween_property(
				_cargo, "position", conveyor.transform * OUTPUT_CARGO_END, OUTPUT_FEED_DURATION
		)
	await tween.finished
	carrying = grabbing
	delivered = not grabbing
	if not grabbing:
		remove_child(_cargo)
		_cargo.queue_free()
		_box_color_name = "blue" if _box_color_name == "orange" else "orange"
		_spawn_cargo()
		cargo_delivered.emit()
	return ""


func _spawn_cargo() -> void:
	var model: PackedScene = CARGO_MODELS[_box_color_name]
	_cargo = model.instantiate()
	_cargo.position = INPUT_CARGO_START
	add_child(_cargo)
	_input_feed = create_tween()
	_input_feed.tween_property(_cargo, "position", CARGO_POSITION, INPUT_FEED_DURATION)


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
