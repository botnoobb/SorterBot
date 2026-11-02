extends RefCounted
class_name ProgramParser

const DIRECTIONS: Dictionary[String, Vector2i] = {
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}

var error_message: String = ""


func parse(source: String) -> Array[ProgramCommand]:
	error_message = ""
	var lexer := Lexer.new()
	var tokens: Array[Token] = lexer.tokenize(source)
	if not lexer.error_message.is_empty():
		error_message = lexer.error_message
		return []
	var commands: Array[ProgramCommand] = []
	var index: int = 0
	while tokens[index].type != Token.Type.END:
		if tokens[index].type == Token.Type.NEWLINE:
			index += 1
			continue
		var line: int = tokens[index].line
		# В первой версии языка одна команда занимает одну строку.
		if tokens[index].type != Token.Type.IDENTIFIER or tokens[index].text not in ["move", "print"]:
			return _fail(line, "ожидается команда move или print со строковым аргументом.")
		var name: String = tokens[index].text
		index += 1
		if tokens[index].type != Token.Type.LEFT_PAREN:
			return _fail(line, "после имени команды ожидается открывающая скобка.")
		index += 1
		if tokens[index].type != Token.Type.STRING:
			return _fail(line, "укажите строковый аргумент в одинарных или двойных кавычках.")
		var argument: String = tokens[index].text
		if name == "move" and not DIRECTIONS.has(argument):
			return _fail(line, "доступные направления: up, down, left, right.")
		index += 1
		if tokens[index].type != Token.Type.RIGHT_PAREN:
			return _fail(line, "после аргумента ожидается закрывающая скобка.")
		index += 1
		if tokens[index].type != Token.Type.NEWLINE and tokens[index].type != Token.Type.END:
			return _fail(line, "каждая команда должна находиться на отдельной строке.")
		var type: ProgramCommand.Type = ProgramCommand.Type.MOVE
		if name == "print":
			type = ProgramCommand.Type.PRINT
		var command := ProgramCommand.new(type, line)
		if name == "move":
			command.direction = DIRECTIONS[argument]
		else:
			command.text = argument
		commands.append(command)
	return commands


func _fail(line: int, explanation: String) -> Array[ProgramCommand]:
	error_message = "Строка %d: %s" % [line, explanation]
	return []
