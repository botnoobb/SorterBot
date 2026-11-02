extends VBoxContainer
class_name OutputPanel

@onready var _messages: RichTextLabel = $Messages


func append_message(message: String) -> void:
	show()
	_messages.add_text(message + "\n")


func clear_messages() -> void:
	_messages.clear()
	hide()
