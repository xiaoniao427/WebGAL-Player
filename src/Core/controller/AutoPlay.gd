# AutoPlay.gd — 对应 WebGAL Core/controller/gamePlay/autoPlay.ts
extends Node
class_name WebgalAutoPlay

static func toggle() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.gameplay.is_auto = not core.gameplay.is_auto