# ChangeFigure.gd — 对应 WebGAL Core/gameScripts/changeFigure.ts
extends Node
class_name WebgalChangeFigure

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var fig_id := "center"
	for a in args:
		if a.get("key", "") == "id":
			fig_id = str(a.get("value", "center"))
	
	if content == "" or content == "none":
		core.stage_state.set_figure_by_key(fig_id, "", {})
	else:
		core.stage_state.set_figure_by_key(fig_id, content, {})
		
		# 处理 transform
		for a in args:
			if a.get("key", "") == "transform":
				var transform_val = a.get("value", "")
				if transform_val is String:
					var parsed = JSON.parse_string(transform_val)
					if parsed is Dictionary:
						core.stage_state.update_effect(fig_id, parsed)
	core.stage_state.commit()