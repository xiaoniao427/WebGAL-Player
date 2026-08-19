# WebGAL.gd — 全局单例（对应 WebGAL.ts 的 WebGAL 对象）
# 持有所有核心模块的引用
extends Node
class_name WebgalCore

static var instance: WebgalCore = null

var scene_manager: WebgalSceneManager
var gameplay: WebgalGamePlay
var stage_state: WebgalStageStateManager
var script_executor: WebgalScriptExecutor
var play_bgm: WebgalPlayBgm

var vars: WebgalVariables
var assets: WebgalAssets
var parser: WebgalScriptParser
var config: Dictionary = {}
var game_root: String = "res://"

var _scene_cache: Dictionary = {}

signal game_ended
signal dialog_shown(speaker: String, text: String)
signal choose_shown(options: Array, targets: Array)


func _init() -> void:
	instance = self


func initialize(root: String) -> void:
	game_root = root
	if not game_root.ends_with("/"):
		game_root += "/"
	
	vars = WebgalVariables.new()
	assets = WebgalAssets.new()
	assets.game_root = game_root
	parser = WebgalScriptParser.new()
	
	scene_manager = WebgalSceneManager.new()
	gameplay = WebgalGamePlay.new()
	stage_state = WebgalStageStateManager.new()
	script_executor = WebgalScriptExecutor.new()
	play_bgm = WebgalPlayBgm.new()
	
	# 读 config.txt
	var cfg_raw := _read_text(game_root + "config.txt")
	if cfg_raw == "":
		cfg_raw = _read_text("res://config.txt")
	if cfg_raw != "":
		config = WebgalConfigParser.parse(cfg_raw)


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func reset() -> void:
	vars = WebgalVariables.new()
	scene_manager.reset()
	gameplay.reset()
	stage_state.reset()