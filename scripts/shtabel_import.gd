@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return scene
	if player.has_animation(&"Pickup"):
		# Первый кадр импортированного клипа Pickup задаёт статическую позу модели.
		player.play(&"Pickup")
		player.advance(0)
		player.stop(true)
	for side: String in ["L", "R"]:
		var clip_name := StringName("Drive_" + side)
		if player.has_animation(clip_name):
			_add_track_player(scene, player.get_animation(clip_name), clip_name, side)
	return scene


func _add_track_player(scene: Node, source: Animation, clip_name: StringName, side: String) -> void:
	var clip := source.duplicate() as Animation
	var track_root := StringName("Track_Root_" + side)
	# Импортёр добавляет неподвижные дорожки и для остальных узлов модели.
	for index: int in range(clip.get_track_count() - 1, -1, -1):
		var path: NodePath = clip.track_get_path(index)
		if path.get_name_count() < 2 or path.get_name(1) != track_root:
			clip.remove_track(index)
	var library := AnimationLibrary.new()
	library.add_animation(clip_name, clip)
	var player := AnimationPlayer.new()
	player.name = "Track" + side
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library(&"", library)
	scene.add_child(player)
	player.owner = scene
