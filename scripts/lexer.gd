extends RefCounted
class_name Lexer


# Читает строку из цифр. Если строка пустая или содержит другие символы,
# возвращает null вместо токена.
func read_number(source: String) -> Token:
	var position: int = 0
	var number_text: String = ""

	while position < source.length():
		var character: String = source[position]
		if not character.is_valid_int():
			return null

		number_text += character
		position += 1

	if number_text.is_empty():
		return null

	return Token.new(Token.Type.INTEGER, number_text.to_int())


# Читает целые числа, разделённые обычными пробелами.
# Для пустого ввода или неподдерживаемых символов возвращает пустой массив.
func tokenize(source: String) -> Array[Token]:
	var tokens: Array[Token] = []
	var position: int = 0

	while position < source.length():
		if source[position] == " ":
			position += 1
			continue

		var number_text: String = ""
		while position < source.length():
			var character: String = source[position]
			if not character.is_valid_int():
				break

			number_text += character
			position += 1

		var token: Token = read_number(number_text)
		if token == null:
			return []

		tokens.append(token)

	return tokens
