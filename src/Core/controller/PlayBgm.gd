# PlayBgm.gd — 对应 WebGAL Core/controller/stage/playBgm.ts
# BGM 播放控制
extends Node
class_name WebgalPlayBgm


func play(url: String, enter: float = 0.0, volume: float = 100.0) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	if url == "":
		var last = core.stage_state.get_calculation().get("bgm", {}).get("src", "")
		core.stage_state.set_state("bgm", {"src": last, "enter": -enter, "volume": volume})
	else:
		core.stage_state.set_state("bgm", {"src": url, "enter": enter, "volume": volume})
	core.stage_state.commit()