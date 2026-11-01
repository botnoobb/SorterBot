extends RefCounted
class_name Token

enum Type { IDENTIFIER, STRING, LEFT_PAREN, RIGHT_PAREN, NEWLINE, END }

var type: Type
var text: String
var line: int


func _init(token_type: Type, token_text: String, source_line: int) -> void:
	type = token_type
	text = token_text
	line = source_line
