# SetTransform.gd — 对应 WebGAL Core/gameScripts/setTransform.ts
extends Node
class_name WebgalSetTransform

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var target_id := "center"
	for a in args:
		if a.get("key", "") == "target":
			target_id = str(a.get("value", "center"))
	
	var transform_str := content.strip_edges()
	if transform_str == "":
		for a in args:
			if a.get("key", "") == "transform":
				transform_str = str(a.get("value", ""))
	if transform_str == "":
		transform_str = _build_from_args(args)
	if transform_str == "":
		return
	if not transform_str.begins_with("{"):
		return
	var parsed = JSON.parse_string(transform_str)
	if parsed is Dictionary:
		core.stage_state.update_effect(target_id, parsed)
		core.stage_state.commit()


static func _build_from_args(args: Array) -> String:
	var parts: Array = []
	for a in args:
		var k = str(a.get("key", ""))
		var v = a.get("value", null)
		if v == null:
			continue
		match k:
			"alpha":
				parts.push_back('"alpha":%s' % v)
			"position_x", "x":
				parts.push_back('"position":{"x":%s,"y":0}' % v)
			"position_y", "y":
				parts.push_back('"position":{"x":0,"y":%s}' % v)
			"scale_x":
				parts.push_back('"scale":{"x":%s,"y":1}' % v)
			"scale_y":
				parts.push_back('"scale":{"x":1,"y":%s}' % v)
			"scale":
				parts.push_back('"scale":{"x":%s,"y":%s}' % [v, v])
			"rotation":
				parts.push_back('"rotation":%s' % v)
			"blur":
				parts.push_back('"blur":%s' % v)
	if parts.is_empty():
		return ""
	return "{" + ",".join(parts) + "}"