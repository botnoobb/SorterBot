@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(&"Pickup"):
		# Первый кадр импортированного клипа Pickup задаёт статическую позу модели.
		player.play(&"Pickup")
		player.advance(0)
		player.stop(true)
	return scene
