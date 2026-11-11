extends RefCounted
class_name ProgramCommand

enum Type { MOVE, PRINT, GRAB, PUT, INVALID, ASSIGN }
enum OperandKind { LITERAL, VARIABLE, BOX_COLOR }

var type: Type
var line: int
var direction: Vector2i = Vector2i.ZERO
var text: String = ""
var target_variable: String = ""
var operand_kind: OperandKind = OperandKind.LITERAL
var operand_column: int = 1
var program_source: String = ""
var error: ProgramDiagnostic


func _init(command_type: Type, source_line: int) -> void:
	type = command_type
	line = source_line
