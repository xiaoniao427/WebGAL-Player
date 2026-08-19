# ScriptExecutor.gd — 对应 WebGAL Core/controller/gamePlay/scriptExecutor.ts
# 语句执行器：变量插值、when 条件、执行/跳转调度
extends Node
class_name WebgalScriptExecutor

const MAX_FORWARD := 1000


func execute_script(script: Dictionary, depth: int = 0) -> void:
	if depth > MAX_FORWARD:
		push_warning("WebGAL: forward 执行超过限制，可能存在死循环")
		return
	
	var core = WebgalCore.instance
	if core == null:
		return
	
	# 超过场景语句数 → 出栈
	var scene_mgr = core.scene_manager
	if scene_mgr.scene_data.currentSentenceId >= scene_mgr.scene_data.currentScene.sentenceList.size():
		_return_from_scene()
		return
	
	var s: Dictionary = scene_mgr.get_current_sentence()
	
	# 变量插值
	_interpolate_sentence(s)
	
	# when 条件检查
	if not _when_checker(s):
		scene_mgr.advance_sentence()
		execute_script(script, depth + 1)
		return
	
	# jumpLabel 特殊处理：不触发 commit，只改指针
	if s.get("command", -1) == WebgalModels.Cmd.JUMP_LABEL:
		if _jump_to_label(s.get("content", "")):
			pass
		else:
			scene_mgr.advance_sentence()
		execute_script(script, depth + 1)
		return
	
	# 执行
	var runner = WebgalRunScript.new()
	runner.run(s)
	
	# 是否继续下一句
	var is_next = _get_bool_arg(s, "next")
	
	if is_next and not core.gameplay.perform_controller.has_blocking_next():
		scene_mgr.advance_sentence()
		execute_script(script, depth + 1)
		return
	
	scene_mgr.advance_sentence()


func _return_from_scene() -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	var entry = core.scene_manager.pop_frame()
	if entry.is_empty():
		# 栈空，游戏结束
		core.game_ended.emit()
		return
	# 恢复场景
	core.scene_manager.scene_data.currentScene.sentenceList = entry.get("sentenceList", [])
	core.scene_manager.scene_data.currentSentenceId = entry.get("continueLine", 0) + 1


func _interpolate_sentence(s: Dictionary) -> void:
	# ponytail: content 和 args 的 {var} 插值
	var core = WebgalCore.instance
	if core == null:
		return
	if s.has("content"):
		s["content"] = core.vars.interpolate(s["content"])
	if s.has("args"):
		var args: Array = s["args"]
		for i in args.size():
			if typeof(args[i]) == TYPE_DICTIONARY:
				var a = args[i].duplicate()
				if a.has("value") and typeof(a["value"]) == TYPE_STRING:
					a["value"] = core.vars.interpolate(a["value"])
				args[i] = a


func _when_checker(s: Dictionary) -> bool:
	var core = WebgalCore.instance
	if core == null:
		return true
	for a in s.get("args", []):
		if a.get("key", "") == "when":
			var val = str(a.get("value", ""))
			return WebgalStrIf.evaluate(val, core.vars)
	return true


func _jump_to_label(label: String) -> bool:
	var core = WebgalCore.instance
	if core == null:
		return false
	var list = core.scene_manager.scene_data.currentScene.sentenceList
	for i in list.size():
		var s = list[i]
		if s.get("command", -1) == WebgalModels.Cmd.LABEL and s.get("content", "") == label:
			core.scene_manager.scene_data.currentSentenceId = i
			return true
	push_warning("WebGAL: 未找到标签 ", label)
	return false


func _get_bool_arg(s: Dictionary, key: String) -> bool:
	for a in s.get("args", []):
		if a.get("key", "") == key:
			var v = a.get("value", false)
			if typeof(v) == TYPE_BOOL:
				return v
			if typeof(v) == TYPE_STRING:
				return v.to_lower() == "true"
	return false