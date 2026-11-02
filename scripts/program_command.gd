extends RefCounted
class_name ProgramCommand

enum Type { MOVE, PRINT }

var type: Type
var line: int
var direction: Vector2i = Vector2i.ZERO
var text: String = ""


func _init(command_type: Type, source_line: int) -> void:
	type = command_type
	line = source_line
