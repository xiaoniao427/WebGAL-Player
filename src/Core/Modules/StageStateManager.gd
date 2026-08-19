# StageStateManager.gd — 对应 WebGAL Core/Modules/stage/stageStateManager.ts
# 舞台状态机：calculation 与 view 两层状态，commit 时同步
extends Node
class_name WebgalStageStateManager

var _calculation_state: Dictionary = _init_state()
var _view_state: Dictionary = _init_state()
var _commit_handler: Callable = Callable()


static func _init_state() -> Dictionary:
	return {
		"oldBgName": "",
		"bgName": "",
		"figName": "",
		"figNameLeft": "",
		"figNameRight": "",
		"freeFigure": [],
		"figureAssociatedAnimation": [],
		"isRead": false,
		"showText": "",
		"showTextSize": -1,
		"showName": "",
		"command": "",
		"choose": [],
		"vocal": "",
		"playVocal": "",
		"vocalVolume": 100,
		"bgm": {"src": "", "enter": 0, "volume": 100},
		"uiSe": "",
		"miniAvatar": "",
		"GameVar": {},
		"effects": [],
		"animationSettings": [],
		"bgFilter": "",
		"bgTransform": "",
		"PerformList": [],
		"currentDialogKey": "initial",
		"enableFilm": "",
		"isDisableTextbox": false,
	}


func reset() -> void:
	_calculation_state = _init_state()
	_view_state = _init_state()


func get_calculation() -> Dictionary:
	return _calculation_state


func get_view() -> Dictionary:
	return _view_state


func set_state(key: String, value) -> void:
	_calculation_state[key] = value


func set_state_and_commit(key: String, value) -> void:
	set_state(key, value)
	commit()


func commit() -> void:
	_view_state = _calculation_state.duplicate(true)
	if _commit_handler.is_valid():
		_commit_handler.call(_view_state)


func set_commit_handler(handler: Callable) -> void:
	_commit_handler = handler


func update_effect(target: String, transform: Dictionary) -> void:
	var state = _calculation_state
	var effects: Array = state["effects"]
	var idx = -1
	for i in effects.size():
		if effects[i]["target"] == target:
			idx = i
			break
	if idx >= 0:
		if transform.is_empty():
			effects[idx]["transform"] = {}
		else:
			# merge
			var cur = effects[idx].get("transform", {})
			for k in transform:
				if typeof(transform[k]) == TYPE_DICTIONARY and typeof(cur.get(k)) == TYPE_DICTIONARY:
					var merged = cur[k].duplicate()
					for k2 in transform[k]:
						merged[k2] = transform[k][k2]
					cur[k] = merged
				else:
					cur[k] = transform[k]
			effects[idx]["transform"] = cur
	else:
		effects.push_back({"target": target, "transform": transform.duplicate()})


func remove_effect(target: String) -> void:
	var effects: Array = _calculation_state["effects"]
	var idx = -1
	for i in effects.size():
		if effects[i]["target"] == target:
			idx = i
			break
	if idx >= 0:
		effects.remove_at(idx)


func set_figure_by_key(fig_key: String, name: String, base_position: Dictionary) -> void:
	var state = _calculation_state
	var free_figures: Array = state["freeFigure"]
	var idx = -1
	for i in free_figures.size():
		if free_figures[i]["key"] == fig_key:
			idx = i
			break
	if idx >= 0:
		if name == "":
			free_figures.remove_at(idx)
		else:
			free_figures[idx]["name"] = name
			free_figures[idx]["basePosition"] = base_position
	elif name != "":
		free_figures.push_back({"key": fig_key, "name": name, "basePosition": base_position})