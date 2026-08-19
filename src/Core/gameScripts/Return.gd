# Return.gd — 对应 WebGAL Core/gameScripts/returnScript.ts
extends Node
class_name WebgalReturn

static func execute() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	# 让场景管理器在下一帧自动出栈（通过设置 sentenceId 超出范围）
	core.scene_manager.scene_data.currentSentenceId = 999999