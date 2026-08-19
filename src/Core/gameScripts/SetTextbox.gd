# SetTextbox.gd — 对应 WebGAL Core/gameScripts/setTextbox.ts
extends Node
class_name WebgalSetTextbox

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.stage_state.set_state("isDisableTextbox", content.strip_edges().to_lower() != "on")
	core.stage_state.commit()