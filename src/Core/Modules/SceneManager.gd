# SceneManager.gd — 对应 WebGAL Core/Modules/scene.ts
# 场景管理：场景栈、场景数据、进入/退出场景
extends Node
class_name WebgalSceneManager

var scene_data := {
	"currentSentenceId": 0,
	"sceneStack": [],
	"currentScene": {
		"sceneName": "",
		"sceneUrl": "",
		"sentenceList": [],
		"assetsList": [],
		"subSceneList": [],
	},
	"currentLocals": {},
}

var settled_scenes: Dictionary = {}
var settled_assets: Dictionary = {}
var lock_scene_write := false
var scene_write_promise: Dictionary = {}

const MAX_SCENE_STACK_DEPTH := 64


func reset() -> void:
	scene_data.currentSentenceId = 0
	scene_data.sceneStack = []
	scene_data.currentScene = {
		"sceneName": "",
		"sceneUrl": "",
		"sentenceList": [],
		"assetsList": [],
		"subSceneList": [],
	}
	scene_data.currentLocals = {}
	settled_scenes.clear()
	settled_assets.clear()


func push_frame(locals: Dictionary, write_return_to := "") -> void:
	scene_data.sceneStack.push_back({
		"sceneName": scene_data.currentScene.sceneName,
		"sceneUrl": scene_data.currentScene.sceneUrl,
		"continueLine": scene_data.currentSentenceId,
		"locals": scene_data.currentLocals,
		"writeReturnTo": write_return_to,
	})
	scene_data.currentLocals = locals.duplicate()


func pop_frame() -> Dictionary:
	var entry = scene_data.sceneStack.pop_back()
	if entry != null:
		scene_data.currentLocals = entry.get("locals", {}).duplicate()
		return entry
	return {}


func get_current_sentence() -> Dictionary:
	var list = scene_data.currentScene.sentenceList
	var idx = scene_data.currentSentenceId
	if idx < list.size():
		return list[idx]
	return {}


func advance_sentence() -> void:
	scene_data.currentSentenceId += 1