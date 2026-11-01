extends RefCounted
class_name ProgramParser

const DIRECTIONS: Dictionary[String, Vector2i] = {
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}

var error_message: String = ""


func parse(source: String) -> Array[MoveCommand]:
	error_message = ""
	var lexer := Lexer.new()
	var tokens: Array[Token] = lexer.tokenize(source)
	if not lexer.error_message.is_empty():
		error_message = lexer.error_message
		return []
	var commands: Array[MoveCommand] = []
	var index: int = 0
	while tokens[index].type != Token.Type.END:
		if tokens[index].type == Token.Type.NEWLINE:
			index += 1
			continue
		var line: int = tokens[index].line
		# В первой версии языка одна команда занимает одну строку.
		if tokens[index].type != Token.Type.IDENTIFIER or tokens[index].text != "move":
			return _fail(line, "ожидается команда move с направлением в кавычках.")
		index += 1
		if tokens[index].type != Token.Type.LEFT_PAREN:
			return _fail(line, "после move ожидается открывающая скобка.")
		index += 1
		if tokens[index].type != Token.Type.STRING:
			return _fail(line, "укажите направление в одинарных или двойных кавычках.")
		var direction: String = tokens[index].text
		if not DIRECTIONS.has(direction):
			return _fail(line, "доступные направления: up, down, left, right.")
		index += 1
		if tokens[index].type != Token.Type.RIGHT_PAREN:
			return _fail(line, "после направления ожидается закрывающая скобка.")
		index += 1
		if tokens[index].type != Token.Type.NEWLINE and tokens[index].type != Token.Type.END:
			return _fail(line, "каждая команда должна находиться на отдельной строке.")
		commands.append(MoveCommand.new(DIRECTIONS[direction], line))
	return commands


func _fail(line: int, explanation: String) -> Array[MoveCommand]:
	error_message = "Строка %d: %s" % [line, explanation]
	return []
