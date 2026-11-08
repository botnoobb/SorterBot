extends VBoxContainer
class_name OutputPanel

signal error_location_clicked(line: int, column: int)

@onready var _messages: RichTextLabel = $Messages


func _ready() -> void:
	_messages.meta_clicked.connect(_on_meta_clicked)


func append_message(message: String) -> void:
	show()
	_messages.add_text(message + "\n")


func clear_messages() -> void:
	_messages.clear()
	hide()


func append_error(message: String, line: int = 0, column: int = 0) -> void:
	show()
	_messages.push_color(Color(1.0, 0.48, 0.43))
	var location: String = '  File "main", line %d\n' % line
	var location_start: int = message.find(location) if line > 0 else -1
	if location_start >= 0:
		var link_start: int = location_start + '  File "main", '.length()
		var link_text: String = "line %d" % line
		_messages.add_text(message.left(link_start))
		_messages.push_meta(Vector2i(line, column))
		_messages.add_text(link_text)
		_messages.pop()
		_messages.add_text(message.substr(link_start + link_text.length()) + "\n")
	else:
		_messages.add_text(message + "\n")
	_messages.pop()


func append_action_error(message: String) -> void:
	show()
	_messages.push_color(Color(1.0, 0.7, 0.3))
	_messages.add_text(message + "\n")
	_messages.pop()


func _on_meta_clicked(meta: Variant) -> void:
	if meta is Vector2i:
		error_location_clicked.emit(meta.x, meta.y)
