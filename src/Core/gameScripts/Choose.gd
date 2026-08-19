# Choose.gd — 对应 WebGAL Core/gameScripts/choose/index.tsx
extends Node
class_name WebgalChoose

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var pairs := content.split("|")
	var options: Array = []
	var targets: Array = []
	for pr in pairs:
		var parts := pr.split(":", false, 1)
		if parts.size() >= 2:
			options.push_back(parts[0].strip_edges())
			targets.push_back(parts[1].strip_edges())
		else:
			options.push_back(pr.strip_edges())
			targets.push_back("")
	core.stage_state.set_state("choose", options)
	core.stage_state.commit()
	core.choose_shown.emit(options, targets)