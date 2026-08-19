# Intro.gd — 对应 WebGAL Core/gameScripts/intro.tsx
extends Node
class_name WebgalIntro

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	core.stage_state.set_state("showText", content)
	core.stage_state.commit()