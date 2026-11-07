extends Node3D
class_name SorterField

signal cargo_delivered()

const CARGO_CELL := Vector2i(1, 2)
const ZONE_CELL := Vector2i(3, 2)

var carrying: bool = false
var delivered: bool = false
var delivery_failed: bool = false
var _cargo: MeshInstance3D

@onready var _robot: SorterRobot = $Robot


func _ready() -> void:
	_robot.cell = Vector2i(1, 3)
	_robot.position = Vector3(1, 0, 3)
	for x: int in range(5):
		for y: int in range(5):
			_box(Vector3(x, -0.08, y), Vector3(0.96, 0.1, 0.96), Color(0.2, 0.25, 0.3))
	_box(Vector3(CARGO_CELL.x, 0, CARGO_CELL.y), Vector3(0.9, 0.04, 0.9), Color(0.3, 0.5, 0.9))
	_box(Vector3(ZONE_CELL.x, 0, ZONE_CELL.y), Vector3(0.9, 0.04, 0.9), Color(0.3, 0.8, 0.4))
	_cargo = _box(Vector3(CARGO_CELL.x + 0.4, 0.3, CARGO_CELL.y), Vector3(0.45, 0.5, 0.45), Color(0.95, 0.65, 0.2))
	for item: Array in [["Выдача", Vector3(1, 0.1, 1.5)], ["Зона доставки", Vector3(3, 0.1, 1.5)]]:
		var label := Label3D.new()
		label.text = item[0]
		label.position = item[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		add_child(label)


func perform(command: ProgramCommand, duration: float) -> String:
	delivery_failed = false
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
		if _robot.cell != ZONE_CELL:
			delivery_failed = true
			return "коробку нужно положить в зоне доставки."
	else:
		return "Неизвестное игровое действие."
	var grabbing: bool = command.type == ProgramCommand.Type.GRAB
	_cargo.reparent(_robot if grabbing else self)
	var target_position: Vector3 = Vector3(0, 1, 0) if grabbing else Vector3(ZONE_CELL.x + 0.4, 0.3, ZONE_CELL.y)
	var tween: Tween = create_tween()
	tween.tween_property(_cargo, "position", target_position, duration)
	await tween.finished
	carrying = grabbing
	if not grabbing:
		delivered = true
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
