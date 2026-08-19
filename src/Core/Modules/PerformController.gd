# PerformController.gd — 对应 WebGAL Core/Modules/perform/performController.ts
extends Node
class_name WebgalPerformController

var _perform_list: Array = []


func arrange_new_perform(perform: Dictionary, script: Dictionary) -> void:
	# ponytail: 简化版，仅记录不实际执行
	_perform_list.push_back({"perform": perform, "script": script})


func remove_all() -> void:
	_perform_list.clear()


func has_blocking_next() -> bool:
	for p in _perform_list:
		if p.get("perform", {}).get("blockingNext", false):
			return true
	return false


func has_blocking_auto() -> bool:
	for p in _perform_list:
		if p.get("perform", {}).get("blockingAuto", false):
			return true
	return false


func has_pending_blocking_state_calculation() -> bool:
	for p in _perform_list:
		if p.get("perform", {}).get("blockingStateCalculation", false):
			return true
	return false