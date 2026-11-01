extends RefCounted
class_name Lexer

var error_message: String = ""


func tokenize(source: String) -> Array[Token]:
	error_message = ""
	var tokens: Array[Token] = []
	var text: String = source.replace("\r\n", "\n").replace("\r", "\n")
	var position: int = 0
	var line: int = 1
	while position < text.length():
		var character: String = text[position]
		if character == " " or character == "\t":
			position += 1
			continue
		if character == "\n":
			tokens.append(Token.new(Token.Type.NEWLINE, character, line))
			line += 1
		elif character == "(" or character == ")":
			var type: Token.Type = Token.Type.LEFT_PAREN
			if character == ")":
				type = Token.Type.RIGHT_PAREN
			tokens.append(Token.new(type, character, line))
		elif character == "\"" or character == "'":
			var quote: String = character
			position += 1
			var start: int = position
			while position < text.length() and text[position] != quote:
				if text[position] == "\n":
					break
				position += 1
			if position == text.length() or text[position] != quote:
				error_message = "Строка %d: закройте строковый аргумент кавычкой %s." % [line, quote]
				return []
			tokens.append(Token.new(Token.Type.STRING, text.substr(start, position - start), line))
		elif _is_letter(character):
			var start: int = position
			while position < text.length() and _is_letter(text[position]):
				position += 1
			tokens.append(Token.new(Token.Type.IDENTIFIER, text.substr(start, position - start), line))
			continue
		else:
			error_message = "Строка %d: неподдерживаемый символ «%s»." % [line, character]
			return []
		position += 1
	tokens.append(Token.new(Token.Type.END, "", line))
	return tokens


func _is_letter(character: String) -> bool:
	return (
		(character >= "a" and character <= "z")
		or (character >= "A" and character <= "Z")
		or character == "_"
	)
