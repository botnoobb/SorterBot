@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
    var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
    for side in ["L", "R"]:
        var clip := player.get_animation("Drive_" + side)
        for index in range(clip.get_track_count() - 1, -1, -1):
            if not ("/Track_Root_" + side + "/") in str(clip.track_get_path(index)):
                clip.remove_track(index)
    return scene
