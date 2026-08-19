# ChangeScene.gd — 对应 WebGAL Core/gameScripts/changeSceneScript.ts
extends Node
class_name WebgalChangeScene

static func execute(content: String) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.scene_manager.scene_data.currentScene.sceneName = content
	core.scene_manager.scene_data.currentSentenceId = 0