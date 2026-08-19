# NextSentence.gd — 对应 WebGAL Core/controller/gamePlay/nextSentence.ts
extends Node
class_name WebgalNextSentence

static func next() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.scene_manager.advance_sentence()
	# 触发场景执行（由 webgal_player.gd 的 _process 驱动）