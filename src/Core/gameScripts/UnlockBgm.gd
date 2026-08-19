# UnlockBgm.gd — 对应 WebGAL Core/gameScripts/unlockBgm.ts
extends Node
class_name WebgalUnlockBgm

static func execute(content: String, args: Array) -> void:
	if content == "":
		return
	print("WebGAL[图鉴]: BGM解锁 - ", content.get_file(), " (", content, ")")