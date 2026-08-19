# ResetStage.gd — 对应 WebGAL Core/controller/stage/resetStage.ts
extends Node
class_name WebgalResetStage

static func execute(reset_backlog: bool, reset_scene_and_var := true) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.scene_manager.reset()
	core.gameplay.reset()
	core.stage_state.reset()