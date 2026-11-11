extends RefCounted
class_name Token

enum Type {
	IDENTIFIER, STRING, LEFT_PAREN, RIGHT_PAREN, COMMA, EQUALS, EQUAL_EQUAL, COLON, NEWLINE, END,
}

var type: Type
var text: String
var line: int
var column: int


func _init(token_type: Type, token_text: String, source_line: int, source_column: int = 1) -> void:
	type = token_type
	text = token_text
	line = source_line
	column = source_column
