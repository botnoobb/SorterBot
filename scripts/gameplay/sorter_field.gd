extends Node3D
class_name SorterField

signal cargo_delivered()

const FIELD_SIZE := 5
const FLOOR_TILE := preload("res://assets/models/field/floor_tile.glb")
const CARGO_CELL := Vector2i(1, 2)
const ZONE_CELL := Vector2i(3, 2)
const BLUE_ZONE_CELL := Vector2i(3, 3)
const CARGO_POSITION := Vector3(CARGO_CELL.x + 0.4, 0.02, CARGO_CELL.y)
const CARRIED_CARGO_POSITION := Vector3(0, 0.75, 0)
const BOX_COLORS := {"orange": Color(0.95, 0.65, 0.2), "blue": Color(0.25, 0.55, 0.95)}
const CARGO_MODELS := {
	"orange": preload("res://assets/models/cargo/parcel.glb"),
	"blue": preload("res://assets/models/cargo/parcel_blue.glb"),
}
const ZONES_BY_COLOR := {"orange": ZONE_CELL, "blue": BLUE_ZONE_CELL}

var carrying: bool = false
# Результат доставки сохраняется до захвата следующей коробки.
var delivered: bool = false
var _cargo: Node3D
var _box_color_name: String = "orange"
var _robot_spawn_cell: Vector2i

@onready var _robot: SorterRobot = $Robot


func _ready() -> void:
	_robot_spawn_cell = Vector2i(roundi(_robot.position.x), roundi(_robot.position.z))
	_robot.cell = _robot_spawn_cell

	for x: int in range(FIELD_SIZE):
		for y: int in range(FIELD_SIZE):
			var tile: Node3D = FLOOR_TILE.instantiate()
			# Совмещаем поверхность плитки с уровнем движения робота.
			tile.position = Vector3(x, -0.15, y)
			tile.scale = Vector3(0.98, 1, 0.98)
			add_child(tile)

	_box(Vector3(CARGO_CELL.x, 0, CARGO_CELL.y), Vector3(0.9, 0.04, 0.9), Color(0.3, 0.5, 0.9))
	for color_name: String in ZONES_BY_COLOR:
		var zone: Vector2i = ZONES_BY_COLOR[color_name]
		_box(Vector3(zone.x, 0, zone.y), Vector3(0.9, 0.04, 0.9), BOX_COLORS[color_name])
		_add_label(color_name, Vector3(zone.x, 0.1, zone.y - 0.5))
	_add_label("Выдача", Vector3(CARGO_CELL.x, 0.1, CARGO_CELL.y - 0.5))
	_spawn_cargo()


func get_box_color() -> String:
	return _box_color_name


func reset_current_cargo() -> void:
	_robot.cell = _robot_spawn_cell
	_robot.position = Vector3(_robot_spawn_cell.x, 0, _robot_spawn_cell.y)
	if not delivered:
		if _cargo.get_parent() != self:
			_cargo.reparent(self)
		_cargo.position = CARGO_POSITION
		carrying = false


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
	var target_position := (
			CARRIED_CARGO_POSITION if grabbing
			else Vector3(_robot.cell.x + 0.4, CARGO_POSITION.y, _robot.cell.y)
	)
	var tween: Tween = create_tween()
	tween.tween_property(_cargo, "position", target_position, duration)
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
	_cargo.position = CARGO_POSITION
	add_child(_cargo)


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
