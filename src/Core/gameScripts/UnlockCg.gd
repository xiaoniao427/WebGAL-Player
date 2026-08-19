# UnlockCg.gd — 对应 WebGAL Core/gameScripts/unlockCg.ts
extends Node
class_name WebgalUnlockCg

static func execute(content: String, args: Array) -> void:
	if content == "":
		return
	var name := content.get_file()
	for a in args:
		if a.get("key", "") == "name":
			name = str(a.get("value", name))
	print("WebGAL[图鉴]: CG解锁 - ", name, " (", content, ")")