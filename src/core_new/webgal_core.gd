# webgal_core.gd - minimal core entry for rewrite prototype (stage1)
# This is a non-invasive skeleton placed under src/core_new/ to avoid touching existing code.
extends Node

var _scene_data: Dictionary = {}
var _game_root: String = "res://"

func _ready() -> void:
	print("WebGAL Core (new skeleton) ready")

func initialize(root: String) -> void:
	_game_root = root
	if not _game_root.ends_with("/"):
		_game_root += "/"
	print("WebGAL Core initialized with root:", _game_root)

func load_scene_data_from_path(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("WebGAL Core: cannot open scene data: " + path)
		return false
	var raw := f.get_as_text()
	var parsed := JSON.parse_string(raw)
	if parsed is Dictionary:
		_scene_data = parsed.get("scenes", {})
		print("WebGAL Core: loaded scenes count:", _scene_data.size())
		return true
	else:
		push_warning("WebGAL Core: invalid scene_data JSON: " + path)
		return false

func get_scene(name: String) -> Array:
	return _scene_data.get(name, [])
