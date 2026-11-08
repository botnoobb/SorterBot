extends Node3D
class_name SorterField

signal cargo_delivered()

const CARGO_CELL := Vector2i(0, 2)
const ZONE_CELL := Vector2i(4, 2)

var zone_cell: Vector2i = ZONE_CELL
var repeated_delivery: bool = false
var _zone: MeshInstance3D
var _zone_label: Label3D
var carrying: bool = false
var delivered: bool = false
var _cargo: MeshInstance3D
var _robot_spawn_cell: Vector2i

@onready var _robot: SorterRobot = $Robot


func _ready() -> void:
	_robot_spawn_cell = Vector2i(roundi(_robot.position.x), roundi(_robot.position.z))
	_robot.cell = _robot_spawn_cell
	for x: int in range(5):
		for y: int in range(5):
			_box(Vector3(x, -0.08, y), Vector3(0.96, 0.1, 0.96), Color(0.2, 0.25, 0.3))
	_box(Vector3(CARGO_CELL.x, 0, CARGO_CELL.y), Vector3(0.9, 0.04, 0.9), Color(0.3, 0.5, 0.9))
	_zone = _box(Vector3(zone_cell.x, 0, zone_cell.y), Vector3(0.9, 0.04, 0.9), Color(0.3, 0.8, 0.4))
	_cargo = _box(Vector3(CARGO_CELL.x + 0.4, 0.3, CARGO_CELL.y), Vector3(0.45, 0.5, 0.45), Color(0.95, 0.65, 0.2))
	for item: Array in [["Выдача", Vector3(0, 0.1, 1.1)], ["Зона доставки", Vector3(4, 0.1, 1.5)]]:
		var label := Label3D.new()
		label.text = item[0]
		label.position = item[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		add_child(label)
		if item[0] == "Зона доставки":
			_zone_label = label


func start_task(destination: Vector2i, repeated: bool) -> void:
	zone_cell = destination
	repeated_delivery = repeated
	delivered = false
	_zone.position = Vector3(zone_cell.x, 0, zone_cell.y)
	_zone_label.position = Vector3(zone_cell.x, 0.1, zone_cell.y - 0.5)
	_cargo.show()
	reset_current_cargo()


func reset_current_cargo() -> void:
	_robot.cell = _robot_spawn_cell
	_robot.position = Vector3(_robot_spawn_cell.x, 0, _robot_spawn_cell.y)
	if not delivered:
		if _cargo.get_parent() != self:
			_cargo.reparent(self)
		_cargo.position = Vector3(CARGO_CELL.x + 0.4, 0.3, CARGO_CELL.y)
		carrying = false


func perform(command: ProgramCommand, duration: float) -> String:
	if command.type == ProgramCommand.Type.MOVE:
		var target: Vector2i = _robot.cell + command.direction
		if target.x < 0 or target.y < 0 or target.x >= 5 or target.y >= 5:
			return "Робот не может выйти за границу поля."
		await _robot.move(command.direction, duration)
		return ""
	if command.type == ProgramCommand.Type.GRAB:
		if carrying:
			return "Робот уже несёт коробку."
		if delivered or _robot.cell != CARGO_CELL:
			return "На этой клетке нет коробки."
	elif command.type == ProgramCommand.Type.PUT:
		if not carrying:
			return "У робота нет коробки."
		if _robot.cell != zone_cell:
			return "Коробку нужно положить в зоне доставки."
	else:
		return "Неизвестное игровое действие."
	var grabbing: bool = command.type == ProgramCommand.Type.GRAB
	_cargo.reparent(_robot if grabbing else self)
	var target_position: Vector3 = Vector3(0, 1, 0) if grabbing else Vector3(zone_cell.x + 0.4, 0.3, zone_cell.y)
	var tween: Tween = create_tween()
	tween.tween_property(_cargo, "position", target_position, duration)
	await tween.finished
	carrying = grabbing
	if not grabbing:
		delivered = not repeated_delivery
		if repeated_delivery:
			# После доставки активна ровно одна следующая коробка.
			_cargo.position = Vector3(CARGO_CELL.x + 0.4, 0.3, CARGO_CELL.y)
		cargo_delivered.emit()
	return ""


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
