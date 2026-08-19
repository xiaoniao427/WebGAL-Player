# CallScene.gd — 对应 WebGAL Core/gameScripts/callSceneScript.ts
extends Node
class_name WebgalCallScene

static func execute(content: String) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.scene_manager.push_frame({})
	core.scene_manager.scene_data.currentScene.sceneName = content
	core.scene_manager.scene_data.currentSentenceId = 0