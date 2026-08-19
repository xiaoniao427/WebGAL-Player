# Say.gd — 对应 WebGAL Core/gameScripts/say.ts
extends Node
class_name WebgalSay

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var speaker := ""
	for a in args:
		if a.get("key", "") == "speaker":
			speaker = str(a.get("value", ""))
	core.stage_state.set_state("showText", content)
	core.stage_state.set_state("showName", speaker)
	core.stage_state.commit()
	core.dialog_shown.emit(speaker, content)