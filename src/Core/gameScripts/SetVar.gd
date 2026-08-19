# SetVar.gd — 对应 WebGAL Core/gameScripts/setVar.ts
extends Node
class_name WebgalSetVar

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var eq := content.find("=")
	if eq < 0:
		return
	var key := content.substr(0, eq).strip_edges()
	var val := content.substr(eq + 1).strip_edges()
	core.vars.set_var(key, core.vars.evaluate_value(val))