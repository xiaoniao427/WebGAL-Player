# scene_manager.gd - simple scene manager for core_new
extends Node
class_name WebgalSceneManagerNew

var scene_data: Dictionary = {}
var scene_stack: Array = []
var currentScene: Dictionary = {
	"sceneName": "",
	"sentenceList": [],
	"currentSentenceId": 0,
}

func _init():
	pass

func reset() -> void:
	scene_stack.clear()
	currentScene = {"sceneName":"","sentenceList":[],"currentSentenceId":0}

func load_scene_map(map: Dictionary) -> void:
	# map: scenes dict from core
	scene_data = map

func enter_scene(scene_name: String) -> bool:
	var list := scene_data.get(scene_name, null)
	if list == null:
		push_warning("WebGAL SceneManager: scene not found: " + scene_name)
		return false
	currentScene.sceneName = scene_name
	currentScene.sentenceList = list
	currentScene.currentSentenceId = 0
	return true

func call_scene(scene_name: String) -> bool:
	# push frame
	scene_stack.push_back({
		"sceneName": currentScene.sceneName,
		"sentenceList": currentScene.sentenceList.duplicate(true),
		"continueLine": currentScene.currentSentenceId
	})
	return enter_scene(scene_name)

func return_from_scene() -> void:
	if scene_stack.empty():
		# nothing
		return
	var entry := scene_stack.pop_back()
	currentScene.sentenceList = entry.get("sentenceList", [])
	currentScene.sceneName = entry.get("sceneName", "")
	currentScene.currentSentenceId = int(entry.get("continueLine", 0))

func get_current_sentence() -> Dictionary:
	var idx := currentScene.currentSentenceId
	if idx >= 0 and idx < currentScene.sentenceList.size():
		return currentScene.sentenceList[idx]
	return {}

func advance_sentence() -> void:
	currentScene.currentSentenceId += 1

func push_frame(frame: Dictionary) -> void:
	scene_stack.push_back(frame)

func pop_frame() -> Dictionary:
	if scene_stack.empty():
		return {}
	return scene_stack.pop_back()
