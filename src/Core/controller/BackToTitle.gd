# BackToTitle.gd — 对应 WebGAL Core/controller/gamePlay/backToTitle.ts
extends Node
class_name WebgalBackToTitle

static func execute() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	WebgalResetStage.execute(true, true)
	core.game_ended.emit()