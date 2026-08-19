# ChangeBg.gd — 对应 WebGAL Core/gameScripts/changeBg/index.ts
extends Node
class_name WebgalChangeBg

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var bg_path = content
	if content == "" or content == "none":
		core.stage_state.set_state("bgName", "")
	else:
		core.stage_state.set_state("bgName", bg_path)
		# 处理 transform
		for a in args:
			if a.get("key", "") == "transform":
				var transform_val = a.get("value", "")
				if transform_val is String:
					var parsed = JSON.parse_string(transform_val)
					if parsed is Dictionary:
						core.stage_state.update_effect("bg-main", parsed)
	core.stage_state.commit()