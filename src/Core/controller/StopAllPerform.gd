# StopAllPerform.gd — 对应 WebGAL Core/controller/gamePlay/stopAllPerform.ts
extends Node
class_name WebgalStopAllPerform

static func execute() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.gameplay.perform_controller.remove_all()