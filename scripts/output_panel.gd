extends VBoxContainer
class_name OutputPanel

@onready var _messages: RichTextLabel = $Messages


func append_message(message: String) -> void:
	show()
	_messages.add_text(message + "\n")


func clear_messages() -> void:
	_messages.clear()
	hide()


func append_error(message: String) -> void:
	show()
	_messages.push_color(Color(1.0, 0.48, 0.43))
	_messages.add_text(message + "\n")
	_messages.pop()
