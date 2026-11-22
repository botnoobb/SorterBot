extends Control
class_name SettingsPanel

signal editor_side_changed(editor_on_left: bool)
signal text_size_changed(value: int)
signal text_size_step_requested(direction: int)
signal text_size_reset_requested()
signal closed()

const MIN_TEXT_SIZE := 12
const MAX_TEXT_SIZE := 28
const DEFAULT_TEXT_SIZE := 18

const SHORTCUTS := [
	["Запуск, пауза, продолжение", "F5"],
	["Остановка", "Shift+F5"],
	["Шаг", "F10"],
	["Открыть или закрыть настройки", "Esc"],
	["Изменить или сбросить размер текста", "Ctrl++ / Ctrl+− / Ctrl+0"],
	["Свернуть или раскрыть вывод", "F8"],
	["Перевести фокус между областями", "F7"],
	["Изменить размер панели", "Стрелки на разделителе"],
	["Скопировать выделение в выводе", "Ctrl+C"],
]

@onready var _left: Button = %Left
@onready var _right: Button = %Right
@onready var _slider: HSlider = %SizeSlider
@onready var _entry: LineEdit = %SizeEntry
@onready var _decrease: Button = %Decrease
@onready var _increase: Button = %Increase
@onready var _reset: Button = %Reset
@onready var _close: Button = %Close
@onready var _shortcut_list: GridContainer = %ShortcutList


func _ready() -> void:
	_slider.min_value = MIN_TEXT_SIZE
	_slider.max_value = MAX_TEXT_SIZE
	_slider.set_value_no_signal(DEFAULT_TEXT_SIZE)
	_slider.tooltip_text = "Размер текста от %d до %d px" % [MIN_TEXT_SIZE, MAX_TEXT_SIZE]
	_entry.tooltip_text = "Введите размер текста от %d до %d px" % [MIN_TEXT_SIZE, MAX_TEXT_SIZE]
	_reset.tooltip_text = "Сбросить размер текста до %d px (Ctrl+0)" % DEFAULT_TEXT_SIZE
	_entry.text = str(DEFAULT_TEXT_SIZE)
	_left.pressed.connect(func() -> void: editor_side_changed.emit(true))
	_right.pressed.connect(func() -> void: editor_side_changed.emit(false))
	_slider.value_changed.connect(_on_slider_value_changed)
	_entry.text_submitted.connect(_commit_text_size)
	_entry.focus_exited.connect(func() -> void: _commit_text_size(_entry.text))
	_entry.gui_input.connect(_on_size_entry_input)
	_decrease.pressed.connect(func() -> void: text_size_step_requested.emit(-1))
	_increase.pressed.connect(func() -> void: text_size_step_requested.emit(1))
	_reset.pressed.connect(text_size_reset_requested.emit)
	_close.pressed.connect(close)
	_connect_focus_cycle()
	for shortcut: Array in SHORTCUTS:
		var action := Label.new()
		action.text = shortcut[0]
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.add_theme_font_size_override("font_size", 16)
		_shortcut_list.add_child(action)
		var keys := Label.new()
		keys.text = shortcut[1]
		keys.add_theme_font_size_override("font_size", 16)
		_shortcut_list.add_child(keys)


func open() -> void:
	if visible:
		return
	show()
	if _left.button_pressed:
		_left.grab_focus()
	else:
		_right.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func set_values(editor_on_left: bool, text_size: int) -> void:
	_left.set_pressed_no_signal(editor_on_left)
	_right.set_pressed_no_signal(not editor_on_left)
	_slider.set_value_no_signal(text_size)
	_entry.text = str(roundi(_slider.value))


func _connect_focus_cycle() -> void:
	var controls: Array[Control] = [
		_left, _right, _decrease, _slider, _increase, _entry, _reset, _close,
	]
	for index: int in range(controls.size()):
		var control := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_right = control.focus_next
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next


func _on_slider_value_changed(value: float) -> void:
	_entry.text = str(roundi(value))
	text_size_changed.emit(roundi(value))


func _on_size_entry_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	_entry.accept_event()
	var menu := _entry.get_menu()
	if menu.visible:
		menu.hide()
	else:
		close()


func _commit_text_size(text: String) -> void:
	var value := roundi(_slider.value)
	var stripped := text.strip_edges()
	if stripped.is_valid_int():
		value = clampi(stripped.to_int(), roundi(_slider.min_value), roundi(_slider.max_value))
	_entry.text = str(value)
	if value != roundi(_slider.value):
		text_size_changed.emit(value)
