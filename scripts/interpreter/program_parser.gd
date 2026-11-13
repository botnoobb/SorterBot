extends RefCounted
class_name ProgramParser

const DIRECTIONS: Dictionary[String, Vector2i] = {
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}

const RESERVED_NAMES := ["def", "if", "else", "while", "pass", "return", "True", "False"]

var error: ProgramDiagnostic


func parse(source: String) -> Array[ProgramCommand]:
	error = null
	var lexer := Lexer.new()
	var tokens: Array[Token] = lexer.tokenize(source)
	if lexer.error != null:
		error = lexer.error
		return []
	var commands: Array[ProgramCommand] = []
	_parse_block(source, tokens, 0, 0, commands)
	if error != null:
		return []
	return commands


func _parse_block(
		source: String, tokens: Array[Token], index: int, column: int,
		commands: Array[ProgramCommand]
) -> int:
	while tokens[index].type != Token.Type.END:
		if tokens[index].type == Token.Type.NEWLINE:
			index += 1
			continue
		var name: Token = tokens[index]
		if column > 0 and name.column < column:
			break
		if column > 0 and name.column > column:
			return _fail(source, name, "unexpected indent")
		if name.type != Token.Type.IDENTIFIER:
			return _fail(source, name)
		if name.text == "def":
			if column != 0 or name.column != 1:
				return _fail(source, name, "function definitions must be at the top level")
			index = _parse_function(source, tokens, index, commands)
			if error != null:
				return index
			continue
		if name.text in ["if", "while"]:
			index = _parse_control(source, tokens, index, commands)
			if error != null:
				return index
			continue
		if name.text in ["else", "return", "True", "False"]:
			return _fail(source, name)
		index += 1
		var command := ProgramCommand.new(ProgramCommand.Type.INVALID, name.line)
		if name.text == "pass":
			if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
				return _fail(source, tokens[index])
			command.type = ProgramCommand.Type.PASS
			commands.append(command)
			continue
		if tokens[index].type == Token.Type.EQUALS:
			command.type = ProgramCommand.Type.ASSIGN
			command.target_variable = name.text
			index = _parse_operand(source, tokens, index + 1, command)
			if error != null:
				return index
			if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
				return _fail(source, tokens[index])
			commands.append(command)
			continue
		var opening: Token = tokens[index]
		if opening.type != Token.Type.LEFT_PAREN:
			return _fail(source, opening)
		index += 1
		var arguments := command.arguments
		while tokens[index].type != Token.Type.RIGHT_PAREN:
			if tokens[index].type in [Token.Type.END, Token.Type.NEWLINE]:
				return _fail(source, opening, "'(' was never closed")
			var argument := ProgramCommand.new(ProgramCommand.Type.INVALID, name.line)
			index = _parse_operand(source, tokens, index, argument)
			if error != null:
				return index
			arguments.append(argument)
			if tokens[index].type == Token.Type.COMMA:
				index += 1
			elif tokens[index].type != Token.Type.RIGHT_PAREN:
				if tokens[index].type in [Token.Type.END, Token.Type.NEWLINE]:
					return _fail(source, opening, "'(' was never closed")
				return _fail(source, tokens[index])
		index += 1
		if tokens[index].type not in [Token.Type.NEWLINE, Token.Type.END]:
			return _fail(source, tokens[index])
		command.function_name = name.text
		command.program_source = source
		command.call_column = name.column
		_configure_call(source, name, arguments, command)
		commands.append(command)
	return index


func _parse_function(
		source: String, tokens: Array[Token], index: int, commands: Array[ProgramCommand]
) -> int:
	var keyword := tokens[index]
	var name := tokens[index + 1]
	if name.type != Token.Type.IDENTIFIER or name.text in RESERVED_NAMES:
		return _fail(source, name, "expected a function name")
	if name.text == "get_box_color":
		return _fail(source, name, "cannot redefine 'get_box_color'")
	if tokens[index + 2].type != Token.Type.LEFT_PAREN:
		return _fail(source, tokens[index + 2], "expected '('")
	var definition := ProgramCommand.new(ProgramCommand.Type.DEFINE_FUNCTION, keyword.line)
	definition.function_name = name.text
	index += 3
	while tokens[index].type != Token.Type.RIGHT_PAREN:
		var parameter := tokens[index]
		if parameter.type != Token.Type.IDENTIFIER or parameter.text in RESERVED_NAMES:
			return _fail(source, parameter, "expected a parameter name")
		if parameter.text in definition.parameters:
			return _fail(source, parameter, "duplicate argument '%s' in function definition" % parameter.text)
		definition.parameters.append(parameter.text)
		definition.local_names.append(parameter.text)
		index += 1
		if tokens[index].type != Token.Type.COMMA:
			break
		index += 1
	if tokens[index].type != Token.Type.RIGHT_PAREN:
		return _fail(source, tokens[index], "expected ')'")
	var body_start := commands.size() + 1
	commands.append(definition)
	index = _parse_indented_block(source, tokens, index + 1, keyword.column, commands)
	if error != null:
		return index
	for body_index: int in range(body_start, commands.size()):
		var instruction := commands[body_index]
		if instruction.type == ProgramCommand.Type.ASSIGN:
			var local_name := instruction.target_variable
			if local_name not in definition.local_names:
				definition.local_names.append(local_name)
	commands.append(ProgramCommand.new(ProgramCommand.Type.RETURN_FUNCTION, keyword.line))
	definition.jump_index = commands.size()
	return index


func _parse_control(
		source: String, tokens: Array[Token], index: int, commands: Array[ProgramCommand]
) -> int:
	var keyword := tokens[index]
	var condition_index := commands.size()
	var condition := ProgramCommand.new(ProgramCommand.Type.CONDITION, keyword.line)
	index = _parse_condition(source, tokens, index + 1, condition, keyword.text == "while")
	if error != null:
		return index
	commands.append(condition)
	index = _parse_indented_block(source, tokens, index, keyword.column, commands)
	if error != null:
		return index
	var next := tokens[index]
	if keyword.text == "while":
		var repeat := ProgramCommand.new(ProgramCommand.Type.JUMP, keyword.line)
		repeat.jump_index = condition_index
		commands.append(repeat)
		condition.jump_index = commands.size()
	elif next.type == Token.Type.IDENTIFIER and next.text == "else" and next.column == keyword.column:
		var skip_else := ProgramCommand.new(ProgramCommand.Type.JUMP, next.line)
		commands.append(skip_else)
		condition.jump_index = commands.size()
		index = _parse_indented_block(source, tokens, index + 1, keyword.column, commands)
		skip_else.jump_index = commands.size()
	else:
		condition.jump_index = commands.size()
	return index


func _parse_condition(
		source: String, tokens: Array[Token], index: int, condition: ProgramCommand,
		allow_boolean: bool
) -> int:
	var value := tokens[index]
	if allow_boolean and value.type == Token.Type.IDENTIFIER and value.text in ["True", "False"]:
		condition.constant_condition = value.text == "True"
		return index + 1
	index = _parse_operand(source, tokens, index, condition)
	if error != null:
		return index
	if tokens[index].type != Token.Type.EQUAL_EQUAL:
		return _fail(source, tokens[index], "expected '=='")
	condition.right_operand = ProgramCommand.new(ProgramCommand.Type.INVALID, condition.line)
	return _parse_operand(source, tokens, index + 1, condition.right_operand)


func _parse_indented_block(
		source: String, tokens: Array[Token], index: int, parent_column: int,
		commands: Array[ProgramCommand]
) -> int:
	if tokens[index].type != Token.Type.COLON:
		return _fail(source, tokens[index], "expected ':'")
	index += 1
	if tokens[index].type != Token.Type.NEWLINE:
		return _fail(source, tokens[index], "expected an indented block")
	while tokens[index].type == Token.Type.NEWLINE:
		index += 1
	var first := tokens[index]
	if first.type == Token.Type.END or first.column <= parent_column:
		return _fail(source, first, "expected an indented block")
	index = _parse_block(source, tokens, index, first.column, commands)
	if error == null and tokens[index].type != Token.Type.END:
		if tokens[index].column > parent_column:
			return _fail(source, tokens[index], "unindent does not match an outer indentation level")
	return index


func _configure_call(
		source: String, name: Token, arguments: Array[ProgramCommand], command: ProgramCommand
) -> void:
	var error_type: String = ""
	var message: String = ""
	if name.text not in ["move", "print", "grab", "put"]:
		command.type = ProgramCommand.Type.CALL_FUNCTION
		return
	elif arguments.size() != (0 if name.text in ["grab", "put"] else 1):
		error_type = "TypeError"
		message = "%s() takes exactly %d argument (%d given)" % [name.text, 0 if name.text in ["grab", "put"] else 1, arguments.size()]
	elif (name.text == "move" and arguments[0].operand_kind == ProgramCommand.OperandKind.LITERAL
			and not DIRECTIONS.has(arguments[0].text)):
		error_type = "ValueError"
		message = "invalid direction '%s'" % arguments[0].text
	else:
		if name.text == "move":
			command.type = ProgramCommand.Type.MOVE
			if arguments[0].operand_kind == ProgramCommand.OperandKind.LITERAL:
				command.direction = DIRECTIONS[arguments[0].text]
		elif name.text == "grab":
			command.type = ProgramCommand.Type.GRAB
		elif name.text == "put":
			command.type = ProgramCommand.Type.PUT
		else:
			command.type = ProgramCommand.Type.PRINT
			command.text = arguments[0].text
		return
	# Диагностика сохраняется в команде и возникает только при её выполнении.
	command.error = ProgramDiagnostic.new(
		error_type, message, source, name.line, name.column, true
	)


func _parse_operand(
		source: String, tokens: Array[Token], index: int, command: ProgramCommand
) -> int:
	var value := tokens[index]
	var reserved := value.type == Token.Type.IDENTIFIER and value.text in RESERVED_NAMES
	if reserved or value.type not in [Token.Type.STRING, Token.Type.IDENTIFIER]:
		error = ProgramDiagnostic.new("SyntaxError", "invalid syntax", source, value.line, value.column)
		return index
	command.text = value.text
	command.operand_kind = ProgramCommand.OperandKind.LITERAL
	if value.type == Token.Type.IDENTIFIER:
		command.operand_kind = ProgramCommand.OperandKind.VARIABLE
		command.operand_column = value.column
		command.program_source = source
		if value.text == "get_box_color" and tokens[index + 1].type == Token.Type.LEFT_PAREN:
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
) -> int:
	error = ProgramDiagnostic.new("SyntaxError", message, source, token.line, token.column)
	return -1
