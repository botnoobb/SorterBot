extends Node3D
class_name SorterRobot

var cell: Vector2i = Vector2i.ZERO

func move(direction: Vector2i, duration: float) -> void:
	var destination: Vector2i = cell + direction
	var target := Vector3(destination.x, 0.0, destination.y)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target, duration)
	await tween.finished
	cell = destination
