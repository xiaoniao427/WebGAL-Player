# SetAnimation.gd — 对应 WebGAL Core/gameScripts/setAnimation.ts
extends Node
class_name WebgalSetAnimation

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var target_id := "center"
	for a in args:
		if a.get("key", "") == "target":
			target_id = str(a.get("value", "center"))
	core.stage_state.set_state("command", "animation")
	core.stage_state.commit()