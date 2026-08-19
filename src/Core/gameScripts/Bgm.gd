# Bgm.gd — 对应 WebGAL Core/gameScripts/bgm.ts
extends Node
class_name WebgalBgm

static func execute(content: String, args: Array) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var enter := 0.0
	var volume := 100.0
	for a in args:
		if a.get("key", "") == "enter":
			enter = float(a.get("value", 0))
		if a.get("key", "") == "volume":
			volume = float(a.get("value", 80.0))
	core.play_bgm.play(content, enter, volume)