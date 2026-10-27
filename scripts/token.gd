extends RefCounted
class_name Token

enum Type {
	INTEGER,
}

var type: Type
var value: int


func _init(token_type: Type, token_value: int) -> void:
	type = token_type
	value = token_value
