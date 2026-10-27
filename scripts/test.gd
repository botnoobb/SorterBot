extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var lexer = Lexer.new()
	var token = lexer.read_number("42")
	print(token.type == Token.Type.INTEGER)
	print(token.value)
	
