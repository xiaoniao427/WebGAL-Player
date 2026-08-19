# webgal_player.gd - WebGAL 运行时解释器（重写 v4）
# 参考 WebGAL 官方 scene.ts / gamePlay.ts / events.ts 架构重写
# ponytail: 简洁实现，保持核心功能，特效/Live2D 走 upgrade 路径
extends Node

@export var auto_start := true
@export var export_root := ""
@export var start_scene := "start.txt"
@export var title_bg_custom := ""

const SAVE_DIR := "user://webgal_saves/"
const MAX_SLOTS := 9
const DESIGN_SIZE := Vector2(1920, 1080)  # WebGAL 设计分辨率

enum State { TITLE, RUNNING, WAITING_INPUT, WAITING_TIMER, CHOOSING, ENDED }
enum Speed { NORMAL = 1, DOUBLE = 2, TRIPLE = 3 }

var game_root := ""
var vars: WebgalVariables
var assets: WebgalAssets
var parser: WebgalScriptParser
var config: Dictionary = {}

# 场景状态（对应 WebGAL scene.ts 的 ISceneData）
var _state: int = State.TITLE
var _sentences: Array = []      # 当前场景已解析的句子列表
var _idx: int = 0               # 当前句子索引 (currentSentenceId)
var _scene_name: String = ""    # 当前场景名
var _scene_stack: Array = []    # 场景调用栈 [{sentences, idx, name}]

# 游戏状态
var _speaker_memory: String = ""
var _bg_path: String = ""
var _bgm_path: String = ""
var _figures: Dictionary = {}   # id -> TextureRect
var _wait_left: float = 0.0
var _current_tween: Tween = null
var _speed: int = Speed.NORMAL
var _auto_advance: bool = false
var _auto_timer: float = 0.0
var _last_vocal_player: AudioStreamPlayer = null

# UI 节点
var _root: Control
var _bg: TextureRect
var _figure_container: Control
var _dialog: Panel
var _dlg_speaker: Label
var _dlg_text: Label
var _intro: ColorRect
var _intro_label: Label
var _choose_box: VBoxContainer
var _menu_bar: HBoxContainer
var _btn_save: Button
var _btn_load: Button
var _btn_speed: Button
var _btn_auto: Button
var _btn_title: Button
var _title_screen: Control
var _title_bg: TextureRect
var _title_logo: TextureRect
var _title_btn_grp: VBoxContainer
var _title_btn_start: Button
var _title_btn_continue: Button
var _title_btn_load: Button
var _title_bgm_player: AudioStreamPlayer
var _sl_menu: Panel
var _sl_title: Label
var _sl_grid: GridContainer
var _sl_btn_close: Button
var _sl_slots: Array = []

# 输入框节点
var _input_dialog: Control
var _input_field: LineEdit
var _input_btn: Button
var _input_varname: String = ""

# Pixi 特效层
var _pixi_layer: ColorRect

# 窗口缩放比例（设计分辨率 → 实际窗口）
var _scale_factor: Vector2 = Vector2.ONE
# 章节转场黑色幕布（最顶层，点击消失）
var _curtain: ColorRect


signal game_ended
signal dialog_shown(speaker: String, text: String)
signal choose_shown(options: Array, targets: Array)


# ======================================================================
# 生命周期
# ======================================================================

func _ready() -> void:
	game_root = export_root
	if game_root == "":
		game_root = "res://"
	# 确保尾部 /
	if not game_root.ends_with("/"):
		game_root += "/"

	assets = WebgalAssets.new()
	assets.game_root = game_root
	parser = WebgalScriptParser.new()
	vars = WebgalVariables.new()

	# 读 config.txt — 直接在 game_root 下找
	var cfg_raw := _read_text(game_root + "config.txt")
	if cfg_raw == "":
		cfg_raw = _read_text("res://config.txt")
	if cfg_raw != "":
		config = WebgalConfigParser.parse(cfg_raw)

	# Android 适配：让节点在暂停时继续运行（Android 切后台时保持计时器工作）
	process_mode = PROCESS_MODE_ALWAYS
	# ponytail: Android 触摸默认已启用，无需额外设置

	_build_ui()
	# ponytail: 计算窗口缩放比例（设计分辨率 → 实际窗口）
	_scale_factor = get_viewport().get_visible_rect().size / DESIGN_SIZE
	# Godot canvas_items 原生缩放，无需手动
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)  # 原生全屏
	_show_title()


# ======================================================================
# 标题界面
# ======================================================================

func _show_title() -> void:
	_state = State.TITLE
	_hide_all_gameplay()
	_title_screen.visible = true
	_menu_bar.visible = false

	# 背景
	var img_path := title_bg_custom if title_bg_custom != "" else WebgalConfigParser.get_str(config, "Title_img", "")
	if img_path != "":
		var tex := _load_texture_safe(img_path, "background")
		if tex:
			_title_bg.texture = tex

	# Logo
	var logo := WebgalConfigParser.get_str(config, "Game_Logo", "")
	if logo != "":
		var tex := _load_texture_safe(logo, "background")
		if tex:
			_title_logo.texture = tex
			_title_logo.visible = true

	# BGM
	var bgm := WebgalConfigParser.get_str(config, "Title_bgm", "")
	if bgm != "":
		var stream := assets.load_audio(bgm, "bgm")
		if stream:
			_title_bgm_player.stream = stream
			_title_bgm_player.play()

	_title_btn_continue.visible = _has_any_save()


func _hide_title() -> void:
	_title_screen.visible = false
	if _title_bgm_player.playing:
		_title_bgm_player.stop()


func _on_start_game() -> void:
	start_game()


func _on_continue_game() -> void:
	_sl_mode = "load"
	_open_sl_menu()


func _on_load_game() -> void:
	_sl_mode = "load"
	_open_sl_menu()


# ======================================================================
# 游戏启动
# ======================================================================

func start_game() -> void:
	vars = WebgalVariables.new()
	_bg_path = ""
	_bgm_path = ""
	_speaker_memory = ""
	_speed = Speed.NORMAL
	_auto_advance = false
	_auto_timer = 0.0
	_clear_screen()
	_hide_title()
	_show_menu_bar()
	_state = State.RUNNING
	_enter_scene(start_scene)


# ======================================================================
# 场景管理（对应 WebGAL scene.ts 的 SceneManager）
# ======================================================================

func _enter_scene(scene_name: String) -> void:
	var full := _resolve_scene_path(scene_name)
	var raw := _read_text(full)
	if raw == "":
		push_warning("WebGAL: 场景文件无法读取: " + full)
		_end_game()
		return
	_scene_stack.clear()
	_sentences = _parse_scene(raw)
	_idx = 0
	_scene_name = scene_name
	print("WebGAL: 进入场景 \"", scene_name, "\" → ", _sentences.size(), " 条语句")
	if _sentences.is_empty():
		push_warning("WebGAL: 场景无有效语句: " + scene_name)
		_end_game()
		return
	_continue()


func _call_scene(scene_name: String) -> void:
	var full := _resolve_scene_path(scene_name)
	var raw := _read_text(full)
	if raw == "":
		push_warning("WebGAL: callScene 目标缺失: " + scene_name)
		return
	# 保存当前现场
	_scene_stack.append({"sentences": _sentences, "idx": _idx, "name": _scene_name})
	_sentences = _parse_scene(raw)
	_idx = 0
	_scene_name = scene_name
	_continue()


func _resolve_scene_path(name: String) -> String:
	# 如果已经包含绝对路径标记，直接返回
	if name.begins_with("res://") or name.begins_with("user://"):
		return name
	# 否则拼接 scene/ 目录
	return game_root + "scene/" + name


# ======================================================================
# 主循环（对应 WebGAL 的 sentence 逐条执行）
# ======================================================================

func _continue() -> void:
	while true:
		if _state != State.RUNNING:
			return
		if _idx >= _sentences.size():
			if _scene_stack.is_empty():
				_end_game()
				return
			# 出栈：从 callScene 返回
			var pop: Dictionary = _scene_stack.pop_back()
			_sentences = pop["sentences"]
			_idx = pop["idx"] + 1
			_scene_name = pop.get("name", "")
			continue
		var s: Dictionary = _sentences[_idx]
		# 检查 -when 条件
		if not _eval_when(s):
			_idx += 1
			continue
		var cmd_name := WebgalCommands.name_of(s.get("command", WebgalModels.Cmd.SAY))
		var r := _execute(s)
		if r == -1:  # RET_DONE：继续循环
			continue
		elif r == 0:  # RET_PAUSE：等待输入/定时器
			return
		else:  # RET_ADVANCE：继续下一条
			_idx += 1


func _execute(s: Dictionary) -> int:
	var cmd: int = s.get("command", WebgalModels.Cmd.SAY)
	var content: String = vars.interpolate(s.get("content", ""))
	var args: Array = s.get("args", [])

	match cmd:
		WebgalModels.Cmd.SAY:
			return _do_say(s, content, args)
		WebgalModels.Cmd.CHANGE_BG:
			_set_bg(content, args)
			return _advance_flag(args)
		WebgalModels.Cmd.CHANGE_FIGURE:
			_set_figure(content, args)
			return _advance_flag(args)
		WebgalModels.Cmd.BGM:
			_play_bgm(content, args)
			return 1
		WebgalModels.Cmd.INTRO:
			_show_intro(content)
			return 1
		WebgalModels.Cmd.CHOOSE:
			_show_choose(content, args)
			_state = State.CHOOSING
			return 0
		WebgalModels.Cmd.END:
			_end_game_direct()
			return -1
		WebgalModels.Cmd.LABEL:
			return 1
		WebgalModels.Cmd.JUMP_LABEL:
			return _jump_to_label(content)
		WebgalModels.Cmd.SET_VAR:
			_set_var(content, args)
			return 1
		WebgalModels.Cmd.CHANGE_SCENE:
			_enter_scene(content)
			return -1
		WebgalModels.Cmd.CALL_SCENE:
			_call_scene(content)
			return -1
		WebgalModels.Cmd.RETURN:
			_idx = _sentences.size()  # 触发场景栈出栈
			return -1
		WebgalModels.Cmd.WAIT:
			_wait_left = maxf(0.0, float(content))
			_state = State.WAITING_TIMER
			return 0
		WebgalModels.Cmd.PLAY_EFFECT:
			_play_effect(content)
			return 1
		WebgalModels.Cmd.SET_TRANSFORM:
			_set_transform(content, args)
			return _advance_flag(args)
		WebgalModels.Cmd.SET_ANIMATION:
			_set_animation(content, args)
			return _advance_flag(args)
		WebgalModels.Cmd.GET_USER_INPUT:
			_show_input(content, args)
			return 0
		WebgalModels.Cmd.PIXI:
			_pixi_effect(content, args)
			return 1
		WebgalModels.Cmd.PIXI_INIT:
			_pixi_init(content, args)
			return 1
		WebgalModels.Cmd.SET_TEXTBOX:
			_set_textbox(content, args)
			return 1
		WebgalModels.Cmd.UNLOCK_CG:
			_unlock_cg(content, args)
			return 1
		WebgalModels.Cmd.UNLOCK_BGM:
			_unlock_bgm(content, args)
			return 1
		WebgalModels.Cmd.SET_TRANSITION:
			# ponytail: setTransition 同 setTransform，仅别名
			_set_transform(content, args)
			return _advance_flag(args)
		WebgalModels.Cmd.MINI_AVATAR, WebgalModels.Cmd.FILM_MODE, WebgalModels.Cmd.CALL_STEAM, WebgalModels.Cmd.APPLY_STYLE, WebgalModels.Cmd.SET_TEMP_ANIMATION, WebgalModels.Cmd.COMMENT, WebgalModels.Cmd.SHOW_VARS, WebgalModels.Cmd.VIDEO, WebgalModels.Cmd.DUMMY:
			# ponytail: 未实现功能 — 跳过不崩溃
			return 1
		_:
			push_warning("WebGAL[todo]: 未知命令 %s" % WebgalCommands.name_of(cmd))
			return 1


# ======================================================================
# 各命令实现
# ======================================================================

func _do_say(s: Dictionary, content: String, args: Array) -> int:
	var speaker := _speaker_memory
	for a in args:
		if a.get("key", "") == "speaker":
			speaker = vars.interpolate(str(a.get("value", "")))
	_speaker_memory = speaker
	_show_dialog(speaker, content, args)
	_state = State.WAITING_INPUT
	return 0


func _set_bg(file: String, args: Array) -> void:
	_bg_path = file
	# ponytail: 每次换背景先重置 _bg 为全屏（清除之前 transform 残留的 scale/position）
	_bg.position = Vector2.ZERO
	_bg.scale = Vector2.ONE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.offset_left = 0
	_bg.offset_top = 0
	_bg.offset_right = 0
	_bg.offset_bottom = 0
	_bg.modulate.a = 1.0
	_bg.rotation = 0.0
	if file == "" or file == "none":
		_bg.texture = null
		_bg.visible = false
		return
	var tex := assets.load_texture(file, "background")
	if tex:
		_bg.texture = tex
		_bg.visible = true
		# ponytail: 背景已是全屏铺满，transform 只取 alpha/rotation，忽略 position/scale
		var t: Variant = _get_arg(args, "transform")
		if t != null:
			_apply_bg_transform(t)


func _set_figure(file: String, args: Array) -> void:
	var fig_id: String = _get_arg(args, "id", "center")
	var node: TextureRect = _get_figure_node(fig_id)
	if node == null:
		node = _create_figure_node(fig_id)
	if file == "" or file == "none":
		node.texture = null
		node.visible = false
		return
	var tex := assets.load_texture(file, "figure")
	node.texture = tex
	node.visible = tex != null
	var zi: Variant = _get_arg(args, "zIndex")
	if zi != null:
		node.z_index = int(zi)
	var t: Variant = _get_arg(args, "transform")
	if t != null:
		_apply_transform_to_node(node, t)
	# 兼容 left/right
	if _get_arg(args, "left") == true:
		_apply_transform_to_node(node, '{"position":{"x":-400,"y":0}}')
	if _get_arg(args, "right") == true:
		_apply_transform_to_node(node, '{"position":{"x":400,"y":0}}')


func _play_bgm(file: String, args: Array) -> void:
	_bgm_path = file
	if file == "" or file == "none":
		_stop_bgm()
		return
	var vol := float(_get_arg(args, "volume", 80.0))
	var stream := assets.load_audio(file, "bgm")
	if stream == null:
		return
	var p: AudioStreamPlayer
	if has_node("BGMPlayer"):
		p = get_node("BGMPlayer")
	else:
		p = AudioStreamPlayer.new()
		p.name = "BGMPlayer"
		add_child(p)
	p.stream = stream
	p.volume_db = linear_to_db(clampf(vol / 100.0, 0.0, 1.0))
	p.play()


func _stop_bgm() -> void:
	if has_node("BGMPlayer"):
		(get_node("BGMPlayer") as AudioStreamPlayer).stop()


func _set_textbox(content: String, args: Array) -> void:
	# ponytail: setTextbox:hide → 隐藏对话框；setTextbox:on → 显示
	_dialog.visible = (content.strip_edges().to_lower() == "on")


func _unlock_cg(content: String, args: Array) -> void:
	# ponytail: unlockCg 仅日志记录，无实际图鉴系统
	if content == "":
		return
	var name := String(_get_arg(args, "name", ""))
	if name == "":
		name = content.get_file()
	print("WebGAL[图鉴]: CG解锁 - ", name, " (", content, ")")


func _unlock_bgm(content: String, args: Array) -> void:
	# ponytail: unlockBgm 仅日志记录，无实际图鉴系统
	if content == "":
		return
	print("WebGAL[图鉴]: BGM解锁 - ", content.get_file(), " (", content, ")")


func _show_intro(content: String) -> void:
	_intro.visible = true
	_intro_label.text = "\n".join(content.split("|"))


func _show_choose(content: String, args: Array) -> void:
	_clear_children(_choose_box)
	var raw_pairs := content.split("|")
	for pr in raw_pairs:
		var label := pr
		var target := ""
		var cond_hit := true
		# (条件) -> 标签:目标
		if pr.begins_with("("):
			var close := _find_matching_paren(pr, 0)
			if close >= 0:
				var cond_expr := pr.substr(1, close - 1)
				cond_hit = _eval_condition(cond_expr)
				var rest := pr.substr(close + 1)
				if rest.begins_with("->"):
					rest = rest.substr(2)
				if rest.begins_with("["):
					var endb := rest.find("]")
					if endb >= 0:
						rest = rest.substr(endb + 1)
						if rest.begins_with("->"):
							rest = rest.substr(2)
				pr = rest
		if not cond_hit:
			continue
		var parts := pr.split(":", false, 1)
		if parts.size() >= 2:
			label = parts[0].strip_edges()
			target = parts[1].strip_edges()
		var btn := Button.new()
		btn.text = label
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_choose_option.bind(target))
		_choose_box.add_child(btn)
	if _choose_box.get_child_count() == 0:
		# 所有选项条件不满足，跳过
		_state = State.RUNNING
		_idx += 1
		_continue()
		return
	_choose_box.visible = true


func _find_matching_paren(s: String, start: int) -> int:
	var depth := 0
	for i in range(start, s.length()):
		if s[i] == "(":
			depth += 1
		elif s[i] == ")":
			depth -= 1
			if depth == 0:
				return i
	return -1


func _choose_option(target: String) -> void:
	_choose_box.visible = false
	_clear_children(_choose_box)
	_state = State.RUNNING
	if target == "":
		_idx += 1
		_continue()
		return
	if target.ends_with(".txt"):
		_enter_scene(target)
	else:
		_jump_to_label_internal(target)
		_continue()


func _jump_to_label(label: String) -> int:
	if _jump_to_label_internal(label):
		return -1
	return 1


func _jump_to_label_internal(label: String) -> bool:
	for i in _sentences.size():
		var s: Dictionary = _sentences[i]
		if s.get("command", -1) == WebgalModels.Cmd.LABEL and s.get("content", "") == label:
			_idx = i
			return true
	push_warning("WebGAL: 未找到标签 " + label)
	return false


func _set_var(content: String, args: Array) -> void:
	var eq := content.find("=")
	if eq < 0:
		return
	var key := content.substr(0, eq).strip_edges()
	var val := content.substr(eq + 1).strip_edges()
	vars.set_var(key, vars.evaluate_value(val))


func _input_default(varname: String, args: Array) -> void:
	var default_val := ""
	for a in args:
		if str(a.get("key", "")) == "defaultValue":
			default_val = str(a.get("value", ""))
	if varname != "":
		vars.set_var(varname, default_val)


func _show_input(varname: String, args: Array) -> void:
	_input_varname = varname
	var default_val := ""
	var placeholder := "请输入..."
	for a in args:
		var k := str(a.get("key", ""))
		if k == "defaultValue":
			default_val = str(a.get("value", ""))
		if k == "placeholder":
			placeholder = str(a.get("value", ""))
	_input_field.text = default_val
	_input_field.placeholder_text = placeholder
	_input_dialog.visible = true
	_input_field.grab_focus()
	_state = State.WAITING_INPUT


func _set_transform(content: String, args: Array) -> void:
	var target_id: String = _get_arg(args, "target", "center")
	# ponytail: setTransform 的 target 可以是 figure 节点或任意标识（如 black/white/校园等黑幕/场景名）
	# 先查现有 figure，找不到则创建临时透明节点（黑幕/白幕/场景名等）
	var node: Control = _get_figure_node(target_id)
	if node == null:
		# ponytail: black/white → 使用专用 _curtain 层（最顶层，可点击）
		if target_id == "black" or target_id == "white":
			_curtain.color = Color.BLACK if target_id == "black" else Color.WHITE
			_curtain.modulate.a = 0.0
			_curtain.visible = true
			_apply_transform_tween(_curtain, content, float(_get_arg(args, "duration", 0)) / 1000.0)
			return
		# ponytail: 非 figure 目标 → 创建临时全屏透明节点
		var tr := TextureRect.new()
		tr.name = target_id
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate.a = 0.0
		_figure_container.add_child(tr)
		_figures[target_id] = tr
		node = tr
	# ponytail: setTransform 的 JSON 在 content 中（如 setTransform:{"alpha":1} -target=black）
	# content 为空时查 -transform 参数（changeFigure/changeBg 用）
	# 两者皆空直接 return，不创建空 Tween
	var transform_str := content.strip_edges()
	if transform_str == "":
		transform_str = str(_get_arg(args, "transform", ""))
	if transform_str == "":
		return
	# ponytail: 非 JSON 格式（如 setTransform: alpha=1）→ 跳过不崩溃
	if not transform_str.begins_with("{"):
		push_warning("WebGAL: setTransform 非 JSON 格式，跳过: " + transform_str)
		return
	var duration := float(_get_arg(args, "duration", 0)) / 1000.0
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	_apply_transform_tween(node, transform_str, duration)


func _set_animation(content: String, args: Array) -> void:
	var target_id: String = _get_arg(args, "target", "center")
	var node = _get_figure_node(target_id)
	if node == null:
		return
	var anim_path := "animation/" + content + ".json"
	var full := game_root + anim_path
	var raw := _read_text(full)
	if raw == "":
		push_warning("WebGAL: 动画文件不存在 " + full)
		return
	var json := JSON.parse_string(raw)
	if json == null or typeof(json) != TYPE_ARRAY:
		push_warning("WebGAL: 动画 JSON 解析失败 " + anim_path)
		return
	var frames: Array = json
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	# ponytail: 逐帧关键帧插值，每帧可独立指定 easing
	for frame in frames:
		var dur := float(frame.get("duration", 0)) / 1000.0
		if dur <= 0.0:
			_apply_transform_to_node(node, frame)
			continue
		var easing := String(frame.get("easing", "linear"))
		var tween_type := _tween_easing(easing)
		var t := _current_tween.parallel()
		_apply_transform_tween_to(node, t, frame, dur, tween_type)


func _play_effect(file: String) -> void:
	var stream := assets.load_audio(file, "vocal")
	if stream == null:
		return
	if _last_vocal_player:
		_last_vocal_player.stop()
		_last_vocal_player.queue_free()
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = stream
	p.play()
	p.finished.connect(p.queue_free)
	_last_vocal_player = p


# ======================================================================
# 条件求值
# ======================================================================

func _eval_when(s: Dictionary) -> bool:
	for a in s.get("args", []):
		if a.get("key", "") == "when":
			return _eval_condition(str(a.get("value", "")))
	return true


func _eval_condition(expr: String) -> bool:
	expr = expr.strip_edges()
	if expr == "":
		return true
	var interp := vars.interpolate(expr)
	var ops := ["!=", "==", "<=", ">=", "<", ">"]
	for o in ops:
		var idx := interp.find(o)
		if idx >= 0:
			var left := interp.substr(0, idx).strip_edges()
			var right := interp.substr(idx + o.length()).strip_edges()
			return _compare(left, right, o)
	# 无运算符：布尔值判定
	var v := interp.strip_edges()
	return not (v == "" or v == "0" or v == "false")


func _compare(left: String, right: String, op: String) -> bool:
	var is_num := left.is_valid_float() and right.is_valid_float()
	var lf := float(left)
	var rf := float(right)
	match op:
		"==":
			return left == right if not is_num else lf == rf
		"!=":
			return left != right if not is_num else lf != rf
		"<":
			return lf < rf if is_num else false
		">":
			return lf > rf if is_num else false
		"<=":
			return lf <= rf if is_num else false
		">=":
			return lf >= rf if is_num else false
	return true


# ======================================================================
# Transform 处理
# ======================================================================

func _apply_transform_to_node(node: Control, json_data) -> void:
	var t: Dictionary
	if typeof(json_data) == TYPE_STRING:
		var p := JSON.parse_string(json_data)
		if p == null:
			return
		t = p
	else:
		t = json_data
	if t.has("position"):
		var pos = t["position"]
		if typeof(pos) == TYPE_DICTIONARY:
			var x := float(pos.get("x", 0)) * _scale_factor.x
			var y := float(pos.get("y", 0)) * _scale_factor.y
			node.position = Vector2(x, y)
	if t.has("scale"):
		var s = t["scale"]
		if typeof(s) == TYPE_DICTIONARY:
			node.scale = Vector2(float(s.get("x", 1)), float(s.get("y", 1)))
		else:
			node.scale = Vector2(float(s), float(s))
	if t.has("alpha"):
		node.modulate.a = float(t["alpha"])
	if t.has("rotation"):
		node.rotation = deg_to_rad(float(t["rotation"]))


## ponytail: 背景专用 transform — 全屏铺满，只取 alpha/rotation，忽略 position/scale
func _apply_bg_transform(json_data) -> void:
	var t: Dictionary
	if typeof(json_data) == TYPE_STRING:
		var p := JSON.parse_string(json_data)
		if p == null:
			return
		t = p
	else:
		t = json_data
	if t.has("alpha"):
		_bg.modulate.a = float(t["alpha"])
	if t.has("rotation"):
		_bg.rotation = deg_to_rad(float(t["rotation"]))


func _apply_transform_tween(node: Control, json_data, duration: float) -> void:
	if _current_tween == null:
		return
	# ponytail: 空字符串 → 无操作，避免 JSON.parse_string("") 报错
	if json_data is String and json_data.strip_edges() == "":
		return
	var t: Dictionary
	if typeof(json_data) == TYPE_STRING:
		var p := JSON.parse_string(json_data)
		if p == null:
			return
		t = p
	else:
		t = json_data
	# ponytail: 空字典 → 无 Tweeners，直接返回避免 Tween 空转
	if t.is_empty():
		return
	if duration <= 0.0:
		_apply_transform_to_node(node, t)
		return
	_apply_transform_tween_to(node, _current_tween, t, duration, Tween.EASE_IN_OUT)


## 在指定 Tween 上应用一帧变换，支持 easing
func _apply_transform_tween_to(node: Control, tween: Tween, t: Dictionary, duration: float, ease_type: int) -> void:
	if t.has("position"):
		var pos = t["position"]
		if typeof(pos) == TYPE_DICTIONARY:
			var x := float(pos.get("x", 0)) * _scale_factor.x
			var y := float(pos.get("y", 0)) * _scale_factor.y
			tween.tween_property(node, "position", Vector2(x, y), duration).set_ease(ease_type)
	if t.has("scale"):
		var s = t["scale"]
		if typeof(s) == TYPE_DICTIONARY:
			tween.tween_property(node, "scale", Vector2(float(s.get("x", 1)), float(s.get("y", 1))), duration).set_ease(ease_type)
		else:
			tween.tween_property(node, "scale", Vector2(float(s), float(s)), duration).set_ease(ease_type)
	if t.has("alpha"):
		tween.tween_property(node, "modulate:a", float(t["alpha"]), duration).set_ease(ease_type)
	if t.has("rotation"):
		tween.tween_property(node, "rotation", deg_to_rad(float(t["rotation"])), duration).set_ease(ease_type)


## 将 WebGAL easing 字符串映射为 Godot Tween.EASE 常量
## ponytail: 暂不支持自定义贝塞尔曲线，使用 ease 近似
func _tween_easing(easing: String) -> int:
	match easing.to_lower():
		"ease-in", "ease_in", "in":      return Tween.EASE_IN
		"ease-out", "ease_out", "out":    return Tween.EASE_OUT
		"ease-in-out", "ease_in_out":     return Tween.EASE_IN_OUT
		_:                                 return Tween.EASE_IN_OUT


# ======================================================================
# Pixi 特效（基于 Godot ColorRect 近似实现）
# ======================================================================

## pixiInit: 初始化特效层
func _pixi_init(content: String, args: Array) -> void:
	# ponytail: 创建全屏透明层，后续特效绘制在此层上
	_pixi_layer.visible = true
	_pixi_layer.color = Color(0, 0, 0, 0)
	# 如果 content 有初始化参数，暂不处理


## pixiPerform / pixi: 执行特效
## 支持: fadeIn, fadeOut, flash, shake, blur(简化)
func _pixi_effect(content: String, args: Array) -> void:
	var effect := content.strip_edges().to_lower()
	var duration := float(_get_arg(args, "duration", 1000)) / 1000.0
	var color_str := String(_get_arg(args, "color", "black"))
	var color := _parse_color(color_str)
	if effect == "fadein":
		_pixi_layer.color = Color(color.r, color.g, color.b, 0)
		_pixi_layer.visible = true
		var t := create_tween()
		t.tween_property(_pixi_layer, "color", Color(color.r, color.g, color.b, 1.0), duration)
		t.tween_callback(_pixi_layer.set_visible.bind(false))
	elif effect == "fadeout":
		_pixi_layer.color = Color(color.r, color.g, color.b, 1.0)
		_pixi_layer.visible = true
		var t := create_tween()
		t.tween_property(_pixi_layer, "color", Color(color.r, color.g, color.b, 0), duration)
		t.tween_callback(_pixi_layer.set_visible.bind(false))
	elif effect == "flash":
		_pixi_layer.color = Color.WHITE
		_pixi_layer.visible = true
		var t := create_tween()
		t.tween_property(_pixi_layer, "color", Color(1, 1, 1, 0), duration)
		t.tween_callback(_pixi_layer.set_visible.bind(false))
	elif effect == "shake":
		_pixi_layer.visible = true
		_pixi_layer.color = Color(0, 0, 0, 0)
		# ponytail: 用 _root 的 offset 做简单抖动
		var intensity := float(_get_arg(args, "intensity", 8))
		var orig_pos := _root.position
		var t := create_tween()
		for i in range(6):
			var ox := randf_range(-intensity, intensity)
			var oy := randf_range(-intensity, intensity)
			t.tween_property(_root, "position", Vector2(ox, oy), duration / 12.0)
		t.tween_property(_root, "position", orig_pos, duration / 12.0)
	elif effect == "blur":
		# ponytail: blur 简化 — 半透明黑色遮罩
		_pixi_layer.color = Color(0, 0, 0, 0.5)
		_pixi_layer.visible = true
	else:
		# 未知特效，静默
		push_warning("WebGAL[todo]: 未知 pixi 特效: " + effect)


## 解析颜色字符串（支持英文名和 #hex）
func _parse_color(s: String) -> Color:
	match s.to_lower():
		"black":  return Color.BLACK
		"white":  return Color.WHITE
		"red":    return Color.RED
		"green":  return Color.GREEN
		"blue":   return Color.BLUE
		"yellow": return Color.YELLOW
		"cyan":   return Color.CYAN
		"magenta","pink": return Color.MAGENTA
		_:
			if s.begins_with("#"):
				return Color(s)
			return Color.BLACK


# ======================================================================
# 输入推进
# ======================================================================

func _unhandled_input(event: InputEvent) -> void:
	var click: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var touch: bool = (event is InputEventScreenTouch and event.pressed)
	var key_enter: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER)
	var key_esc: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)
	var key_back: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_BACK)
	if click or touch or key_enter:
		_on_advance()
	if key_esc or key_back:
		if _sl_menu.visible:
			_close_sl_menu()
		elif _state != State.TITLE and _state != State.ENDED:
			_menu_bar.visible = not _menu_bar.visible


func _input_submit(_submitted_text := "") -> void:
	if _input_varname == "":
		return
	vars.set_var(_input_varname, _input_field.text)
	_input_dialog.visible = false
	_input_varname = ""
	_state = State.RUNNING
	_idx += 1
	_continue()


func _on_curtain_clicked(event: InputEvent) -> void:
	# ponytail: 黑色幕布点击 → 消失并推进到下一条语句
	if event is InputEventScreenTouch and event.pressed:
		_curtain.visible = false
		_curtain.modulate.a = 0.0
		# 推进到下一步
		_state = State.RUNNING
		_idx += 1
		_continue()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_curtain.visible = false
		_curtain.modulate.a = 0.0
		_state = State.RUNNING
		_idx += 1
		_continue()


func _on_advance() -> void:
	if _input_dialog.visible:
		_input_submit()
		return
	if _state == State.WAITING_INPUT:
		_state = State.RUNNING
		_idx += 1
		_continue()
	elif _state == State.WAITING_TIMER:
		_state = State.RUNNING
		_idx += 1
		_continue()


func _process(delta: float) -> void:
	if _state == State.WAITING_TIMER:
		_wait_left -= delta * _speed
		if _wait_left <= 0.0:
			_state = State.RUNNING
			_idx += 1
			_continue()
	if _auto_advance and _state == State.WAITING_INPUT:
		_auto_timer += delta * _speed
		if _auto_timer >= 2.0:
			_auto_timer = 0.0
			_on_advance()


# ======================================================================
# 场景解析（简化版，参考 WebGAL sceneParser.ts / scriptParser.ts）
# ======================================================================

func _parse_scene(raw: String) -> Array:
	var out: Array = []
	for line in raw.split("\n"):
		var l := line.strip_edges()
		if l == "" or l.begins_with(";") or l.begins_with("//"):
			continue
		var s := parser.parse_line(l)
		if not s.is_empty():
			out.append(s)
	return out


# ======================================================================
# 存档 / 读档
# ======================================================================

var _sl_mode: String = ""

func _open_sl_menu() -> void:
	_sl_menu.visible = true
	_build_sl_grid()
	_sl_title.text = "保存" if _sl_mode == "save" else "读取"


func _close_sl_menu() -> void:
	_sl_menu.visible = false


func _has_any_save() -> bool:
	for i in range(1, MAX_SLOTS + 1):
		if FileAccess.file_exists(SAVE_DIR + "save_" + str(i) + ".json"):
			return true
	return false


func _build_sl_grid() -> void:
	_clear_children(_sl_grid)
	_sl_slots.clear()
	for i in range(1, MAX_SLOTS + 1):
		var sc := VBoxContainer.new()
		sc.custom_minimum_size = Vector2(180, 120)
		sc.add_theme_constant_override("separation", 4)
		var btn := Button.new()
		var path := SAVE_DIR + "save_" + str(i) + ".json"
		if FileAccess.file_exists(path):
			var data := _read_save_json(path)
			btn.text = "存档 " + str(i) + "\n" + data.get("scene_name", "???") + ":" + str(data.get("scene_idx", 0))
		else:
			btn.text = "【空】"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_clicked.bind(i))
		sc.add_child(btn)
		_sl_slots.append(btn)
		# 预览缩略图
		var preview_path := SAVE_DIR + "save_" + str(i) + ".png"
		if FileAccess.file_exists(preview_path):
			var img := Image.new()
			if img.load(preview_path) == OK:
				var pr := TextureRect.new()
				pr.texture = ImageTexture.create_from_image(img)
				pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				pr.custom_minimum_size = Vector2(0, 60)
				sc.add_child(pr)
		_sl_grid.add_child(sc)


func _on_slot_clicked(slot_idx: int) -> void:
	if _sl_mode == "save":
		_save_game(slot_idx)
	else:
		_load_game(slot_idx)


func _save_game(slot_idx: int) -> void:
	var data := {
		"scene_name": _scene_name,
		"scene_idx": _idx,
		"sentences": _sentences,
		"scene_stack": _scene_stack,
		"vars": vars._vars.duplicate(),
		"speaker_memory": _speaker_memory,
		"bg_path": _bg_path,
		"bgm_path": _bgm_path,
		"figures": _serialize_figures(),
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SAVE_DIR + "save_" + str(slot_idx) + ".json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	_save_screenshot(SAVE_DIR + "save_" + str(slot_idx) + ".png")
	_build_sl_grid()


func _load_game(slot_idx: int) -> void:
	var path := SAVE_DIR + "save_" + str(slot_idx) + ".json"
	if not FileAccess.file_exists(path):
		return
	var data := _read_save_json(path)
	if data.is_empty():
		return
	_hide_title()
	_show_menu_bar()
	_state = State.RUNNING
	_close_sl_menu()
	vars = WebgalVariables.new()
	for k in data.get("vars", {}):
		vars.set_var(k, data["vars"][k])
	_speaker_memory = data.get("speaker_memory", "")
	_bg_path = data.get("bg_path", "")
	_bgm_path = data.get("bgm_path", "")
	_scene_name = data.get("scene_name", start_scene)
	_sentences = data.get("sentences", [])
	_idx = data.get("scene_idx", 0)
	_scene_stack = data.get("scene_stack", [])
	_clear_screen()
	if _bg_path != "":
		_set_bg(_bg_path, [])
	if _bgm_path != "":
		_play_bgm(_bgm_path, [])
	for fd in data.get("figures", []):
		_set_figure(fd.get("file", ""), fd.get("args", []))
	_continue()


func _read_save_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.parse_string(f.get_as_text())
	if json is Dictionary:
		return json
	return {}


func _serialize_figures() -> Array:
	var out: Array = []
	for fig_id in _figures:
		var node: TextureRect = _figures[fig_id]
		out.append({
			"id": fig_id,
			"file": "",
			"args": [],
			"visible": node.visible,
			"position": [node.position.x, node.position.y],
			"scale": [node.scale.x, node.scale.y],
			"modulate": [node.modulate.a],
		})
	return out


func _save_screenshot(path: String) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var img := vp.get_texture().get_image()
	if img:
		img.save_png(path)


# ======================================================================
# 菜单按钮回调
# ======================================================================

func _on_btn_save() -> void:
	_sl_mode = "save"
	_open_sl_menu()

func _on_btn_load() -> void:
	_sl_mode = "load"
	_open_sl_menu()

func _on_btn_speed() -> void:
	_speed = Speed.DOUBLE if _speed == Speed.NORMAL else (Speed.TRIPLE if _speed == Speed.DOUBLE else Speed.NORMAL)
	match _speed:
		Speed.NORMAL: _btn_speed.text = "1x"
		Speed.DOUBLE: _btn_speed.text = "2x"
		Speed.TRIPLE: _btn_speed.text = "3x"

func _on_btn_auto() -> void:
	_auto_advance = not _auto_advance
	_btn_auto.text = "自动" if _auto_advance else "手动"
	if _auto_advance:
		_auto_timer = 0.0

func _on_btn_title() -> void:
	_show_title()


# ======================================================================
# 工具函数
# ======================================================================

func _get_arg(args: Array, key: String, default = null):
	for a in args:
		if a.get("key", "") == key:
			return a.get("value", default)
	return default


func _advance_flag(args: Array) -> int:
	# ponytail: 非 SAY 命令永远不暂停等待输入，直接推进
	# -next 仅表示"链式执行"，不影响阻塞行为
	return 1  # RET_ADVANCE


func _get_figure_node(fig_id: String) -> TextureRect:
	if _figures.has(fig_id):
		return _figures[fig_id]
	for c in _figure_container.get_children():
		if c is TextureRect and c.name == fig_id:
			return c
	return null


func _create_figure_node(fig_id: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = fig_id
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure_container.add_child(tr)
	_figures[fig_id] = tr
	return tr


func _load_texture_safe(path: String, type_name: String) -> Texture2D:
	if path == "":
		return null
	# 如果已经是 res:// 路径，直接加载
	if path.begins_with("res://"):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
		return null
	return assets.load_texture(path, type_name)


# ======================================================================
# UI 构建
# ======================================================================

func _hide_all_gameplay() -> void:
	_bg.visible = false
	_figure_container.visible = false
	_dialog.visible = false
	_intro.visible = false
	_choose_box.visible = false
	_menu_bar.visible = false
	_curtain.visible = false
	_curtain.modulate.a = 0.0


func _show_menu_bar() -> void:
	_menu_bar.visible = true


func _show_dialog(speaker: String, text: String, args: Array = []) -> void:
	_dlg_speaker.text = speaker
	var fs: String = _get_arg(args, "fontSize", "default")
	match fs:
		"large": _dlg_text.add_theme_font_size_override("font_size", 28)
		"small": _dlg_text.add_theme_font_size_override("font_size", 14)
		"medium": _dlg_text.add_theme_font_size_override("font_size", 22)
		_: _dlg_text.add_theme_font_size_override("font_size", 18)
	_dlg_text.text = text
	_dialog.visible = true
	dialog_shown.emit(speaker, text)


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _clear_screen() -> void:
	if _bg:
		_bg.texture = null
		_bg.visible = true
		_bg.position = Vector2.ZERO
		_bg.scale = Vector2.ONE
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg.offset_left = 0
		_bg.offset_top = 0
		_bg.offset_right = 0
		_bg.offset_bottom = 0
		_bg.modulate.a = 1.0
		_bg.rotation = 0.0
	_figure_container.visible = true  # ponytail: 恢复被 _hide_all_gameplay 隐藏的容器
	# ponytail: 清理时隐藏幕布（不删除，保留节点）
	_curtain.visible = false
	_curtain.modulate.a = 0.0
	for f in _figures.values():
		var tr: TextureRect = f
		tr.texture = null
		tr.visible = false
	_figures.clear()
	for c in _figure_container.get_children():
		if c is TextureRect:
			_figure_container.remove_child(c)
			c.queue_free()
	if _intro:
		_intro.visible = false
	if _choose_box:
		_choose_box.visible = false
	if _dialog:
		_dialog.visible = false


func _end_game() -> void:
	if _state == State.ENDED:
		return
	_state = State.ENDED
	game_ended.emit()
	_show_title()


func _end_game_direct() -> void:
	_idx = _sentences.size()


func _read_text(fullpath: String) -> String:
	var f := FileAccess.open(fullpath, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


# ======================================================================

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡触屏穿透到 _unhandled_input
	add_child(_root)

	# === 游戏层 ===
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	_figure_container = Control.new()
	_figure_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_figure_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure_container.z_index = 1  # 在背景之上
	_root.add_child(_figure_container)

	_dialog = Panel.new()
	_dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_top = -200
	_dialog.offset_bottom = -8
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 点击穿透，不阻挡触屏事件
	_dialog.z_index = 3  # 在遮罩之上
	_root.add_child(_dialog)
	_dlg_speaker = Label.new()
	_dlg_speaker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dlg_speaker.offset_left = 20
	_dlg_speaker.offset_top = 12
	_dlg_speaker.add_theme_font_size_override("font_size", 22)
	_dlg_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡触屏穿透
	_dialog.add_child(_dlg_speaker)
	_dlg_text = Label.new()
	_dlg_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dlg_text.offset_left = 20
	_dlg_text.offset_top = 46
	_dlg_text.offset_right = -20
	_dlg_text.offset_bottom = -10
	_dlg_text.add_theme_font_size_override("font_size", 18)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡触屏穿透
	_dialog.add_child(_dlg_text)
	_dlg_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialog.visible = false

	_intro = ColorRect.new()
	_intro.color = Color.BLACK
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.z_index = 2  # 普通遮罩
	_root.add_child(_intro)
	_intro_label = Label.new()
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_label.add_theme_font_size_override("font_size", 28)
	_intro_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(_intro_label)
	_intro.visible = false

	_choose_box = VBoxContainer.new()
	_choose_box.set_anchors_preset(Control.PRESET_CENTER)
	_choose_box.add_theme_constant_override("separation", 12)
	_choose_box.visible = false
	_choose_box.z_index = 4  # 在聊天框之上
	# === Pixi 特效层 ===
	_pixi_layer = ColorRect.new()
	_pixi_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pixi_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixi_layer.visible = false
	_pixi_layer.z_index = 2  # 普通遮罩/图片层
	_root.add_child(_pixi_layer)
	# === 输入框 ===
	_input_dialog = Control.new()
	_input_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_dialog.visible = false
	_input_dialog.mouse_filter = Control.MOUSE_FILTER_STOP  # 阻挡点击穿透
	_input_dialog.z_index = 4  # 在聊天框之上
	_root.add_child(_input_dialog)
	var _input_bg := ColorRect.new()
	_input_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_bg.color = Color(0, 0, 0, 0.6)
	_input_dialog.add_child(_input_bg)
	var _input_panel := Panel.new()
	_input_panel.set_anchors_preset(Control.PRESET_CENTER)
	_input_panel.custom_minimum_size = Vector2(500, 150)
	_input_dialog.add_child(_input_panel)
	_input_field = LineEdit.new()
	_input_field.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_input_field.offset_top = 20
	_input_field.offset_left = 20
	_input_field.offset_right = -20
	_input_field.add_theme_font_size_override("font_size", 24)
	_input_field.text_submitted.connect(_input_submit)
	_input_panel.add_child(_input_field)
	_input_btn = Button.new()
	_input_btn.text = "确定"
	_input_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_input_btn.offset_bottom = -10
	_input_btn.offset_left = 150
	_input_btn.offset_right = -150
	_input_btn.pressed.connect(_input_submit)
	_input_panel.add_child(_input_btn)
	# === 菜单栏（顶部） ===
	_menu_bar = HBoxContainer.new()
	_menu_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_menu_bar.offset_top = 8
	_menu_bar.add_theme_constant_override("separation", 8)
	_menu_bar.visible = false
	_menu_bar.z_index = 5  # 在选项/输入框之上
	_root.add_child(_menu_bar)

	_btn_save = Button.new()
	_btn_save.text = "存档"
	_btn_save.pressed.connect(_on_btn_save)
	_menu_bar.add_child(_btn_save)

	_btn_load = Button.new()
	_btn_load.text = "读档"
	_btn_load.pressed.connect(_on_btn_load)
	_menu_bar.add_child(_btn_load)

	_btn_speed = Button.new()
	_btn_speed.text = "1x"
	_btn_speed.pressed.connect(_on_btn_speed)
	_menu_bar.add_child(_btn_speed)

	_btn_auto = Button.new()
	_btn_auto.text = "手动"
	_btn_auto.pressed.connect(_on_btn_auto)
	_menu_bar.add_child(_btn_auto)

	_btn_title = Button.new()
	_btn_title.text = "标题"
	_btn_title.pressed.connect(_on_btn_title)
	_menu_bar.add_child(_btn_title)

	# === 标题界面 ===
	_title_screen = Control.new()
	_title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_screen.visible = false
	_title_screen.z_index = 8  # 在幕布之下、菜单之上
	_root.add_child(_title_screen)

	_title_bg = TextureRect.new()
	_title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_screen.add_child(_title_bg)

	_title_logo = TextureRect.new()
	_title_logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_logo.offset_top = 60
	_title_logo.offset_bottom = -300
	_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_logo.visible = false
	_title_screen.add_child(_title_logo)

	_title_btn_grp = VBoxContainer.new()
	_title_btn_grp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_title_btn_grp.offset_top = -240
	_title_btn_grp.offset_bottom = -40
	_title_btn_grp.offset_right = -40
	_title_btn_grp.offset_left = -240
	_title_btn_grp.add_theme_constant_override("separation", 16)
	_title_screen.add_child(_title_btn_grp)

	_title_btn_start = Button.new()
	_title_btn_start.text = "开始游戏"
	_title_btn_start.pressed.connect(_on_start_game)
	_title_btn_grp.add_child(_title_btn_start)

	_title_btn_continue = Button.new()
	_title_btn_continue.text = "继续游戏"
	_title_btn_continue.pressed.connect(_on_continue_game)
	_title_btn_grp.add_child(_title_btn_continue)

	_title_btn_load = Button.new()
	_title_btn_load.text = "读取存档"
	_title_btn_load.pressed.connect(_on_load_game)
	_title_btn_grp.add_child(_title_btn_load)

	_title_bgm_player = AudioStreamPlayer.new()
	_title_screen.add_child(_title_bgm_player)

	# === 存档界面 ===
	_sl_menu = Panel.new()
	_sl_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sl_menu.visible = false
	_sl_menu.z_index = 6  # 在菜单栏之上
	_root.add_child(_sl_menu)
	_root.add_child(_choose_box)
	_sl_title = Label.new()
	_sl_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sl_title.offset_top = 16
	_sl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sl_title.add_theme_font_size_override("font_size", 24)
	_sl_menu.add_child(_sl_title)

	_sl_grid = GridContainer.new()
	_sl_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sl_grid.offset_top = 60
	_sl_grid.offset_bottom = 60
	_sl_grid.columns = 3
	_sl_grid.add_theme_constant_override("h_separation", 12)
	_sl_grid.add_theme_constant_override("v_separation", 12)
	_sl_menu.add_child(_sl_grid)

	_sl_btn_close = Button.new()
	_sl_btn_close.text = "关闭"
	_sl_btn_close.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sl_btn_close.offset_bottom = -8
	_sl_btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sl_btn_close.pressed.connect(_close_sl_menu)
	_sl_menu.add_child(_sl_btn_close)

	# === 黑色幕布遮罩（最顶层，章节转场用，点击消失） ===
	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.color = Color.BLACK
	_curtain.modulate.a = 0.0  # 初始透明
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP  # 拦截点击
	_curtain.visible = false
	_curtain.z_index = 10  # 最顶层
	_curtain.gui_input.connect(_on_curtain_clicked)
	_root.add_child(_curtain)
