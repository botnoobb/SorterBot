extends RefCounted
class_name Lexer

var error: ProgramDiagnostic


func tokenize(source: String) -> Array[Token]:
	error = null
	var tokens: Array[Token] = []
	var text: String = source.replace("\r\n", "\n").replace("\r", "\n")
	var position: int = 0
	var line: int = 1
	var line_start: int = 0
	while position < text.length():
		var character: String = text[position]
		var column: int = position - line_start + 1
		if character == " " or character == "\t":
			position += 1
			continue
		if character == "\n":
			tokens.append(Token.new(Token.Type.NEWLINE, character, line, column))
			line += 1
			line_start = position + 1
		elif character == ",":
			tokens.append(Token.new(Token.Type.COMMA, character, line, column))
		elif character == "=":
			if position + 1 < text.length() and text[position + 1] == "=":
				tokens.append(Token.new(Token.Type.EQUAL_EQUAL, "==", line, column))
				position += 1
			else:
				tokens.append(Token.new(Token.Type.EQUALS, character, line, column))
		elif character == ":":
			tokens.append(Token.new(Token.Type.COLON, character, line, column))
		elif character == "(" or character == ")":
			var type: Token.Type = Token.Type.LEFT_PAREN
			if character == ")":
				type = Token.Type.RIGHT_PAREN
			tokens.append(Token.new(type, character, line, column))
		elif character == "\"" or character == "'":
			var quote: String = character
			position += 1
			var start: int = position
			while position < text.length() and text[position] != quote:
				if text[position] == "\n":
					break
				position += 1
			if position == text.length() or text[position] != quote:
				error = ProgramDiagnostic.new(
					"SyntaxError", "unterminated string literal", source, line, column
				)
				return []
			tokens.append(Token.new(
				Token.Type.STRING, text.substr(start, position - start), line, column
			))
		elif _is_letter(character):
			var start: int = position
			position += 1
			while position < text.length() and _is_identifier_character(text[position]):
				position += 1
			tokens.append(Token.new(
				Token.Type.IDENTIFIER, text.substr(start, position - start), line, column
			))
			continue
		else:
			error = ProgramDiagnostic.new("SyntaxError", "invalid syntax", source, line, column)
			return []
		position += 1
	tokens.append(Token.new(Token.Type.END, "", line, position - line_start + 1))
	return tokens


func _is_letter(character: String) -> bool:
	return (
		(character >= "a" and character <= "z")
		or (character >= "A" and character <= "Z")
		or character == "_"
	)


func _is_identifier_character(character: String) -> bool:
	return _is_letter(character) or (character >= "0" and character <= "9")
