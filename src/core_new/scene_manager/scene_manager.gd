# scene_manager.gd - simple scene manager for core_new (fixed types and API)
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
	currentScene["sceneName"] = scene_name
	currentScene["sentenceList"] = list
	currentScene["currentSentenceId"] = 0
	return true

func call_scene(scene_name: String) -> bool:
	# push frame
	scene_stack.push_back({
		"sceneName": currentScene.get("sceneName", ""),
		"sentenceList": currentScene.get("sentenceList", []).duplicate(true),
		"continueLine": int(currentScene.get("currentSentenceId", 0))
	})
	return enter_scene(scene_name)

func return_from_scene() -> void:
	if scene_stack.is_empty():
		# nothing
		return
	var entry := scene_stack.pop_back()
	currentScene["sentenceList"] = entry.get("sentenceList", [])
	currentScene["sceneName"] = entry.get("sceneName", "")
	currentScene["currentSentenceId"] = int(entry.get("continueLine", 0))

func get_current_sentence() -> Dictionary:
	var idx: int = int(currentScene.get("currentSentenceId", 0))
	var list := currentScene.get("sentenceList", [])
	if idx >= 0 and idx < int(list.size()):
		return list[idx]
	return {}

func advance_sentence() -> void:
	currentScene["currentSentenceId"] = int(currentScene.get("currentSentenceId", 0)) + 1

func push_frame(frame: Dictionary) -> void:
	scene_stack.push_back(frame)

func pop_frame() -> Dictionary:
	if scene_stack.is_empty():
		return {}
	return scene_stack.pop_back()
