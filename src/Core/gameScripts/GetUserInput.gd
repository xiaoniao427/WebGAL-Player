# GetUserInput.gd — 对应 WebGAL Core/gameScripts/getUserInput/index.tsx
extends Node
class_name WebgalGetUserInput

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var default_val := ""
	for a in args:
		if a.get("key", "") == "defaultValue":
			default_val = str(a.get("value", ""))
	# ponytail: 赋值默认值，不弹出输入框
	if content != "":
		core.vars.set_var(content, default_val)