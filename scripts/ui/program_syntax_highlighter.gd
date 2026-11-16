extends SyntaxHighlighter

const KEYWORD_COLOR := Color("#cba6f7")
const BOOLEAN_COLOR := Color("#f9c97a")
const STRING_COLOR := Color("#a6e3a1")
const FUNCTION_COLOR := Color("#7ddfff")
const IDENTIFIER_COLOR := Color("#b8d9ff")
const SYMBOL_COLOR := Color("#a0b3c9")

# Кавычки действуют до конца строки, даже пока игрок не ввёл закрывающую.
const TOKEN_PATTERN := "\"[^\"]*\"?|'[^']*'?|[a-zA-Z_][a-zA-Z_0-9]*|==|[=():,]"

var _token_regex := RegEx.create_from_string(TOKEN_PATTERN)


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var code := get_text_edit()
	var source := code.get_line(line)
	var default_color := code.get_theme_color(&"font_color")
	var changes := {}
	for token in _token_regex.search_all(source):
		var start := token.get_start()
		var end := token.get_end()
		var text := token.get_string()
		changes[start] = { "color": _token_color(text, source, end) }
		changes[end] = { "color": default_color }
	return changes


func _token_color(text: String, source: String, end: int) -> Color:
	if text.begins_with('"') or text.begins_with("'"):
		return STRING_COLOR
	if text == "True" or text == "False":
		return BOOLEAN_COLOR
	if text in ProgramParser.RESERVED_NAMES:
		return KEYWORD_COLOR
	if text.is_valid_ascii_identifier():
		var next := source.substr(end).strip_edges()
		return FUNCTION_COLOR if next.begins_with("(") else IDENTIFIER_COLOR
	return SYMBOL_COLOR
