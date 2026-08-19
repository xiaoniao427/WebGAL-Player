# GamePlay.gd — 对应 WebGAL Core/Modules/gamePlay.ts
# 游戏运行时变量：自动播放、快进、演出控制器
extends Node
class_name WebgalGamePlay

var is_auto := false
var is_fast := false
var is_fast_preview := false
var auto_interval: int = 0
var fast_interval: int = 0
var auto_timeout: int = 0
var perform_controller: WebgalPerformController = null


func _init() -> void:
	perform_controller = WebgalPerformController.new()


func reset() -> void:
	is_auto = false
	is_fast = false
	is_fast_preview = false
	auto_interval = 0
	fast_interval = 0
	auto_timeout = 0
	if perform_controller:
		perform_controller.remove_all()


func get_skip_animation() -> bool:
	return is_fast or is_fast_preview