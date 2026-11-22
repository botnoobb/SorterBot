extends RefCounted

const PREFERRED_WEIGHT := 2
const DEFAULT_WEIGHT := 1
const MIN_COVERAGE_WINDOW := 6

var _random: RandomNumberGenerator
var _misses: Dictionary[String, int] = {}
var _coverage_window: int


func _init(colors: Array[String], random: RandomNumberGenerator, first_color: String = "") -> void:
	assert(not colors.is_empty(), "Для выдачи нужен хотя бы один вид груза.")
	_random = random
	for color: String in colors:
		_misses[color] = 0
	_coverage_window = maxi(MIN_COVERAGE_WINDOW, 2 * _misses.size())
	if not first_color.is_empty():
		assert(_misses.has(first_color), "Вид первой коробки должен быть доступен для выдачи.")
		_record_draw(first_color)


func next_color(preferred_color: String) -> String:
	var colors_by_wait: Array[String] = _misses.keys()
	colors_by_wait.sort_custom(func(a: String, b: String) -> bool:
		return _misses[a] > _misses[b]
	)
	var chosen: String
	for index: int in range(colors_by_wait.size()):
		# Самым давно не выпадавшим видам оставляем по одной выдаче до их предела.
		if _misses[colors_by_wait[index]] + index >= _coverage_window - 1:
			chosen = colors_by_wait[0]
			break
	if chosen.is_empty():
		chosen = _draw_weighted(preferred_color)
	_record_draw(chosen)
	return chosen


func _draw_weighted(preferred_color: String) -> String:
	var total_weight := 0
	for color: String in _misses:
		total_weight += _weight(color, preferred_color)
	var roll := _random.randi_range(1, total_weight)
	for color: String in _misses:
		roll -= _weight(color, preferred_color)
		if roll <= 0:
			return color
	return ""


func _weight(color: String, preferred_color: String) -> int:
	var base := PREFERRED_WEIGHT if color == preferred_color else DEFAULT_WEIGHT
	return base + _misses[color]


func _record_draw(color: String) -> void:
	for candidate: String in _misses:
		_misses[candidate] = 0 if candidate == color else _misses[candidate] + 1
