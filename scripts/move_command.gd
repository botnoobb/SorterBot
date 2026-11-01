extends RefCounted
class_name MoveCommand

var direction: Vector2i
var line: int


func _init(move_direction: Vector2i, source_line: int) -> void:
	direction = move_direction
	line = source_line
