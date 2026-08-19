# End.gd — 对应 WebGAL Core/gameScripts/end.ts
extends Node
class_name WebgalEnd

static func execute() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.game_ended.emit()