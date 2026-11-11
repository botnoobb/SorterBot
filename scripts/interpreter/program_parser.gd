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
		var command := ProgramCommand.new(ProgramCommand.Type.INVALID, name.line)
		if tokens[index].type == Token.Type.EQUALS:
			command.type = ProgramCommand.Type.ASSIGN
			command.target_variable = name.text
			index = _parse_operand(source, tokens, index + 1, command)
			if error != null:
				return []
			if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
				return _fail(source, tokens[index])
			commands.append(command)
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
			arguments.append(argument)
			if name.text == "print":
				index = _parse_operand(source, tokens, index, command)
				if error != null:
					return []
			elif argument.type == Token.Type.STRING:
				index += 1
			else:
				return _fail(source, argument)
			if tokens[index].type == Token.Type.COMMA:
				index += 1
			elif tokens[index].type != Token.Type.RIGHT_PAREN:
				if tokens[index].type in [Token.Type.END, Token.Type.NEWLINE]:
					return _fail(source, opening, "'(' was never closed")
				return _fail(source, tokens[index])
		index += 1
		if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
			return _fail(source, tokens[index])
		_configure_call(source, name, arguments, command)
		commands.append(command)
	return commands


func _configure_call(
		source: String, name: Token, arguments: Array[Token], command: ProgramCommand
) -> void:
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
		return
	# Диагностика сохраняется в команде и возникает только при её выполнении.
	command.error = ProgramDiagnostic.new(
		error_type, message, source, name.line, name.column, true
	)


func _parse_operand(
		source: String, tokens: Array[Token], index: int, command: ProgramCommand
) -> int:
	var value := tokens[index]
	if value.type not in [Token.Type.STRING, Token.Type.IDENTIFIER]:
		error = ProgramDiagnostic.new("SyntaxError", "invalid syntax", source, value.line, value.column)
		return index
	command.text = value.text
	command.operand_kind = ProgramCommand.OperandKind.LITERAL
	if value.type == Token.Type.IDENTIFIER:
		command.operand_kind = ProgramCommand.OperandKind.VARIABLE
		command.operand_column = value.column
		command.program_source = source
		if value.text == "box_color" and tokens[index + 1].type == Token.Type.LEFT_PAREN:
			var closing := tokens[index + 2]
			if closing.type != Token.Type.RIGHT_PAREN:
				error = ProgramDiagnostic.new(
						"SyntaxError", "expected ')'", source, closing.line, closing.column
				)
				return index
			command.operand_kind = ProgramCommand.OperandKind.BOX_COLOR
			return index + 3
	return index + 1


func _fail(
	source: String, token: Token, message: String = "invalid syntax"
) -> Array[ProgramCommand]:
	error = ProgramDiagnostic.new("SyntaxError", message, source, token.line, token.column)
	return []
