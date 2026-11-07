extends RefCounted
class_name ProgramDiagnostic

var type: String
var message: String
var line: int
var column: int
var source_line: String
var is_runtime: bool


func _init(
	error_type: String, explanation: String, source: String,
	source_line_number: int, source_column: int, runtime: bool = false
) -> void:
	type = error_type
	message = explanation
	line = source_line_number
	column = source_column
	is_runtime = runtime
	var lines: PackedStringArray = source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	source_line = lines[line - 1] if line > 0 and line <= lines.size() else ""
