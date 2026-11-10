extends RefCounted
class_name ProgramParser

const DIRECTIONS: Dictionary[String, Vector2i] = {
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}

var error: ProgramDiagnostic


func parse(source: String) -> Array[ProgramCommand]:
	error = null
	var lexer := Lexer.new()
	var tokens: Array[Token] = lexer.tokenize(source)
	if lexer.error != null:
		error = lexer.error
		return []
	var commands: Array[ProgramCommand] = []
	var index: int = 0
	while tokens[index].type != Token.Type.END:
		if tokens[index].type == Token.Type.NEWLINE:
			index += 1
			continue
		var name: Token = tokens[index]
		if name.type != Token.Type.IDENTIFIER:
			return _fail(source, name)
		index += 1
		if tokens[index].type == Token.Type.EQUALS:
			index += 1
			var value: Token = tokens[index]
			if value.type not in [Token.Type.STRING, Token.Type.IDENTIFIER]:
				return _fail(source, value)
			index += 1
			var assignment := ProgramCommand.new(ProgramCommand.Type.ASSIGN, name.line)
			assignment.target_variable = name.text
			_set_expression(assignment, value, source)
			if value.type == Token.Type.IDENTIFIER and value.text == "cargo_color":
				if tokens[index].type == Token.Type.LEFT_PAREN:
					index += 1
					if tokens[index].type != Token.Type.RIGHT_PAREN:
						return _fail(source, tokens[index])
					index += 1
					assignment.operand_kind = ProgramCommand.OperandKind.CARGO_COLOR
			if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
				return _fail(source, tokens[index])
			commands.append(assignment)
			continue
		var opening: Token = tokens[index]
		if opening.type != Token.Type.LEFT_PAREN:
			return _fail(source, opening)
		index += 1
		var arguments: Array[Token] = []
		while tokens[index].type != Token.Type.RIGHT_PAREN:
			if tokens[index].type in [Token.Type.END, Token.Type.NEWLINE]:
				return _fail(source, opening, "'(' was never closed")
			var argument: Token = tokens[index]
			var variable_argument := (
					name.text == "print" and argument.type == Token.Type.IDENTIFIER
			)
			if argument.type != Token.Type.STRING and not variable_argument:
				return _fail(source, tokens[index])
			arguments.append(argument)
			index += 1
			if tokens[index].type == Token.Type.COMMA:
				index += 1
			elif tokens[index].type != Token.Type.RIGHT_PAREN:
				if tokens[index].type in [Token.Type.END, Token.Type.NEWLINE]:
					return _fail(source, opening, "'(' was never closed")
				return _fail(source, tokens[index])
		index += 1
		if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
			return _fail(source, tokens[index])
		commands.append(_make_command(source, name, arguments))
	return commands


func _make_command(source: String, name: Token, arguments: Array[Token]) -> ProgramCommand:
	var command := ProgramCommand.new(ProgramCommand.Type.INVALID, name.line)
	var error_type: String = ""
	var message: String = ""
	if name.text not in ["move", "print", "grab", "put"]:
		error_type = "NameError"
		message = "name '%s' is not defined" % name.text
	elif arguments.size() != (0 if name.text in ["grab", "put"] else 1):
		error_type = "TypeError"
		message = "%s() takes exactly %d argument (%d given)" % [name.text, 0 if name.text in ["grab", "put"] else 1, arguments.size()]
	elif name.text == "move" and not DIRECTIONS.has(arguments[0].text):
		error_type = "ValueError"
		message = "invalid direction '%s'" % arguments[0].text
	else:
		if name.text == "move":
			command.type = ProgramCommand.Type.MOVE
			command.direction = DIRECTIONS[arguments[0].text]
		elif name.text == "grab":
			command.type = ProgramCommand.Type.GRAB
		elif name.text == "put":
			command.type = ProgramCommand.Type.PUT
		else:
			command.type = ProgramCommand.Type.PRINT
			_set_expression(command, arguments[0], source)
		return command
	# Диагностика сохраняется в команде и возникает только при её выполнении.
	command.error = ProgramDiagnostic.new(
		error_type, message, source, name.line, name.column, true
	)
	return command


func _set_expression(command: ProgramCommand, value: Token, source: String) -> void:
	command.text = value.text
	if value.type == Token.Type.IDENTIFIER:
		command.operand_kind = ProgramCommand.OperandKind.VARIABLE
		command.operand_column = value.column
		command.program_source = source


func _fail(
	source: String, token: Token, message: String = "invalid syntax"
) -> Array[ProgramCommand]:
	error = ProgramDiagnostic.new("SyntaxError", message, source, token.line, token.column)
	return []
