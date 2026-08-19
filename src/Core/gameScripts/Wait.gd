# Wait.gd — 对应 WebGAL Core/gameScripts/wait.ts
extends Node
class_name WebgalWait

static func execute(content: String) -> void:
	# ponytail: wait 由场景循环控制，这里只记录
	var core = WebgalCore.instance
	if core == null:
		return
	core.stage_state.set_state("command", "wait")
	core.stage_state.commit()