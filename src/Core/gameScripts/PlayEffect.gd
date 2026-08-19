# PlayEffect.gd — 对应 WebGAL Core/gameScripts/playEffect.ts
extends Node
class_name WebgalPlayEffect

static func execute(content: String) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.stage_state.set_state("playVocal", content)
	core.stage_state.commit()