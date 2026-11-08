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
	var lines: PackedStringArray = source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var has_loop: bool = false
	for line: String in lines:
		if line.strip_edges().begins_with("while"):
			has_loop = true
	if not has_loop:
		return _parse_calls(source)
	var commands: Array[ProgramCommand] = []
	_parse_block(source, lines, 0, 0, commands)
	return [] if error != null else commands


func _parse_block(
	source: String, lines: PackedStringArray, start: int, indent: int,
	commands: Array[ProgramCommand]
) -> int:
	var index: int = start
	while index < lines.size():
		var text: String = lines[index].strip_edges()
		if text.is_empty():
			index += 1
			continue
		var depth: int = _indent_width(lines[index])
		if depth < indent:
			return index
		if depth > indent:
			error = ProgramDiagnostic.new("IndentationError", "unexpected indent", source, index + 1, 1)
			return lines.size()
		if text.begins_with("while"):
			var header := RegEx.new()
			header.compile("^while[ \t]+True[ \t]*:$")
			if header.search(text) == null:
				error = ProgramDiagnostic.new("SyntaxError", "expected 'while True:'", source, index + 1, 1)
				return lines.size()
			var body: int = index + 1
			while body < lines.size() and lines[body].strip_edges().is_empty():
				body += 1
			if body >= lines.size() or _indent_width(lines[body]) <= indent:
				error = ProgramDiagnostic.new("IndentationError", "expected an indented block", source, index + 1, 1)
				return lines.size()
			var loop_index: int = commands.size()
			commands.append(ProgramCommand.new(ProgramCommand.Type.WHILE, index + 1))
			index = _parse_block(source, lines, body, _indent_width(lines[body]), commands)
			if error != null:
				return lines.size()
			var repeat := ProgramCommand.new(ProgramCommand.Type.REPEAT, commands[loop_index].line)
			repeat.target = loop_index
			commands.append(repeat)
		else:
			var parsed: Array[ProgramCommand] = _parse_calls(lines[index])
			if error != null:
				error.line = index + 1
				error.source_line = lines[index]
				return lines.size()
			for command: ProgramCommand in parsed:
				command.line = index + 1
				if command.error != null:
					command.error.line = index + 1
					command.error.source_line = lines[index]
				commands.append(command)
			index += 1
	return index


func _indent_width(line: String) -> int:
	var width: int = 0
	for character: String in line:
		if character == " ":
			width += 1
		elif character == "\t":
			width += 4
		else:
			break
	return width


func _parse_calls(source: String) -> Array[ProgramCommand]:
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
		var opening: Token = tokens[index]
		if opening.type != Token.Type.LEFT_PAREN:
			return _fail(source, opening)
		index += 1
		var arguments: Array[String] = []
		while tokens[index].type != Token.Type.RIGHT_PAREN:
			if tokens[index].type in [Token.Type.END, Token.Type.NEWLINE]:
				return _fail(source, opening, "'(' was never closed")
			if tokens[index].type != Token.Type.STRING:
				return _fail(source, tokens[index])
			arguments.append(tokens[index].text)
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


func _make_command(source: String, name: Token, arguments: Array[String]) -> ProgramCommand:
	var command := ProgramCommand.new(ProgramCommand.Type.INVALID, name.line)
	var error_type: String = ""
	var message: String = ""
	if name.text not in ["move", "print", "grab", "put"]:
		error_type = "NameError"
		message = "name '%s' is not defined" % name.text
	elif arguments.size() != (0 if name.text in ["grab", "put"] else 1):
		error_type = "TypeError"
		message = "%s() takes exactly %d argument (%d given)" % [name.text, 0 if name.text in ["grab", "put"] else 1, arguments.size()]
	elif name.text == "move" and not DIRECTIONS.has(arguments[0]):
		error_type = "ValueError"
		message = "invalid direction '%s'" % arguments[0]
	else:
		if name.text == "move":
			command.type = ProgramCommand.Type.MOVE
			command.direction = DIRECTIONS[arguments[0]]
		elif name.text == "grab":
			command.type = ProgramCommand.Type.GRAB
		elif name.text == "put":
			command.type = ProgramCommand.Type.PUT
		else:
			command.type = ProgramCommand.Type.PRINT
			command.text = arguments[0]
		return command
	# Диагностика сохраняется в команде и возникает только при её выполнении.
	command.error = ProgramDiagnostic.new(
		error_type, message, source, name.line, name.column, true
	)
	return command


func _fail(
	source: String, token: Token, message: String = "invalid syntax"
) -> Array[ProgramCommand]:
	error = ProgramDiagnostic.new("SyntaxError", message, source, token.line, token.column)
	return []
