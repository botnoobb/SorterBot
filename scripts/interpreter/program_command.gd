extends RefCounted
class_name ProgramCommand

enum Type { MOVE, PRINT, GRAB, PUT, WHILE, REPEAT, INVALID }

var type: Type
var line: int
var direction: Vector2i = Vector2i.ZERO
var text: String = ""
var target: int = -1
var error: ProgramDiagnostic


func _init(command_type: Type, source_line: int) -> void:
	type = command_type
	line = source_line
