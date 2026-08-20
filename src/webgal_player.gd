# webgal_player.gd — WebGAL for Godot 运行时入口
# 薄 Node 包装器：UI 构建 + 委托给 Core 模块
# 对应 WebGAL 的 App.tsx + gamePlay.ts 入口
extends Node

@export var auto_start := true
@export var export_root := ""
@export var start_scene := "start.txt"
@export var title_bg_custom := ""

const SAVE_DIR := "user://webgal_saves/"
const MAX_SLOTS := 9

enum State { TITLE, RUNNING, WAITING_INPUT, WAITING_TIMER, CHOOSING, ENDED }
enum Speed { NORMAL = 1, DOUBLE = 2, TRIPLE = 3 }

var _state: int = State.TITLE
var _speed: int = Speed.NORMAL
var _auto_advance: bool = false
var _auto_timer: float = 0.0
var _wait_left: float = 0.0
var _current_tween: Tween = null
var _last_vocal_player: AudioStreamPlayer = null
var _speaker_memory: String = ""
var _bg_path: String = ""
var _bgm_path: String = ""
var _figures: Dictionary = {}  # id -> TextureRect
var _waiting_replacements: Dictionary = {} # resolved_path -> [nodes waiting]
var _scene_cache: Dictionary = {}
var _sentences: Array = []
var _idx: int = 0
var _scene_name: String = ""
var _scene_stack: Array = []

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
var _input_dialog: Control
var _input_field: LineEdit
var _input_btn: Button
var _input_varname: String = ""
var _pixi_layer: ColorRect
var _curtain: ColorRect
var _blur_shader: Shader = null
var _scale_factor: Vector2 = Vector2.ONE

signal game_ended
signal dialog_shown(speaker: String, text: String)
signal choose_shown(options: Array, targets: Array)


func _ready() -> void:
	var root := export_root
	if root == "":
		root = "res://"
	var core := WebgalCore.new()
	core.initialize(root)
	add_child(core)
	# connect asset texture_ready if available
	if core.assets != null and not core.assets.is_connected("texture_ready", self, "_on_texture_ready"):
		core.assets.connect("texture_ready", Callable(self, "_on_texture_ready"))
	process_mode = PROCESS_MODE_ALWAYS
	_blur_shader = load("res://addons/webgal/shaders/blur.gdshader")
	if _blur_shader == null:
		_blur_shader = load(root + "addons/webgal/shaders/blur.gdshader")
	_build_ui()
	_scale_factor = get_viewport().get_visible_rect().size / Vector2(1920, 1080)
	_show_title()


func _show_title() -> void:
	_state = State.TITLE
	_hide_all_gameplay()
	_title_screen.visible = true
	_menu_bar.visible = false
	var core := WebgalCore.instance
	if core == null:
		return
	var img_path := title_bg_custom if title_bg_custom != "" else WebgalConfigParser.get_str(core.config, "Title_img", "")
	if img_path != "":
		var tex := _load_texture_safe(img_path, "background")
		if tex:
			_title_bg.texture = tex
	var logo := WebgalConfigParser.get_str(core.config, "Game_Logo", "")
	if logo != "":
		var tex := _load_texture_safe(logo, "background")
		if tex:
			_title_logo.texture = tex
			_title_logo.visible = true
	var bgm := WebgalConfigParser.get_str(core.config, "Title_bgm", "")
	if bgm != "":
		var stream := core.assets.load_audio(bgm, "bgm")
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


func start_game() -> void:
	var core := WebgalCore.instance
	if core == null:
		return
	core.reset()
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


func _load_scene_cache() -> bool:
	var core := WebgalCore.instance
	if core == null:
		return false
	var cache_path := core.game_root + "addons/webgal/dist/scene_data.json"
	if not FileAccess.file_exists(cache_path):
		cache_path = "res://addons/webgal/dist/scene_data.json"
		if not FileAccess.file_exists(cache_path):
			return false
	var raw := _read_text(cache_path)
	if raw == "":
		return false
	var json := JSON.parse_string(raw)
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return false
	var scenes = json.get("scenes", {})
	if typeof(scenes) != TYPE_DICTIONARY:
		return false
	_scene_cache = scenes
	return true


func _get_scene_sentences(scene_name: String) -> Array:
	if not _scene_cache.is_empty():
		var cached = _scene_cache.get(scene_name)
		if cached != null and typeof(cached) == TYPE_ARRAY:
			return cached
		if _scene_cache.has(scene_name):
			return []
	var core := WebgalCore.instance
	if core == null:
		return []
	var full := core.game_root + "scene/" + scene_name
	var raw := _read_text(full)
	if raw == "":
		raw = _read_text("res://scene/" + scene_name)
	if raw == "":
		return []
	return core.parser.parse(raw)


func _enter_scene(scene_name: String) -> void:
	var sentences := _get_scene_sentences(scene_name)
	if sentences.is_empty():
		push_warning("WebGAL: 场景无法读取或为空: ", scene_name)
		_end_game()
		return
	_scene_stack.clear()
	_sentences = sentences
	_idx = 0
	_scene_name = scene_name
	print("WebGAL: 进入场景 \"", scene_name, "\" → ", _sentences.size(), " 条语句")
	_continue()


func _call_scene(scene_name: String) -> void:
	var sentences := _get_scene_sentences(scene_name)
	if sentences.is_empty():
		push_warning("WebGAL: callScene 目标缺失: ", scene_name)
		return
	_scene_stack.append({"sentences": _sentences, "idx": _idx, "name": _scene_name})
	_sentences = sentences
	_idx = 0
	_scene_name = scene_name
	_continue()


func _continue() -> void:
	while true:
		if _state != State.RUNNING:
			return
		if _idx >= _sentences.size():
			if _scene_stack.is_empty():
				_end_game()
				return
			var pop: Dictionary = _scene_stack.pop_back()
			_sentences = pop["sentences"]
			_idx = pop["idx"] + 1
			_scene_name = pop.get("name", "")
			continue
		var s: Dictionary = _sentences[_idx]
		if not _eval_when(s):
			_idx += 1
			continue
		var r := _execute(s)
		if r == -1:
			continue
		elif r == 0:
			return
		else:
			_idx += 1


func _execute(s: Dictionary) -> int:
	var core := WebgalCore.instance
	if core == null:
		return 1
	var cmd: int = s.get("command", WebgalModels.Cmd.SAY)
	var content: String = core.vars.interpolate(s.get("content", ""))
	var args: Array = s.get("args", [])

	match cmd:
		WebgalModels.Cmd.SAY:
			var speaker := _speaker_memory
			for a in args:
				if a.get("key", "") == "speaker":
					speaker = core.vars.interpolate(str(a.get("value", "")))
			_speaker_memory = speaker
			_show_dialog(speaker, content, args)
			_state = State.WAITING_INPUT
			return 0
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
			if _jump_to_label_internal(content):
				return -1
			return 1
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
			_idx = _sentences.size()
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
			_dialog.visible = (content.strip_edges().to_lower() == "on")
			return 1
		WebgalModels.Cmd.UNLOCK_CG:
			if content != "":
				var name := content.get_file()
				for a in args:
					if a.get("key", "") == "name":
						name = str(a.get("value", name))
				print("WebGAL[图鉴]: CG解锁 - ", name, " (", content, ")")
			return 1
		WebgalModels.Cmd.UNLOCK_BGM:
			if content != "":
				print("WebGAL[图鉴]: BGM解锁 - ", content.get_file(), " (", content, ")")
			return 1
		WebgalModels.Cmd.SET_TRANSITION:
			_set_transform(content, args)
			return _advance_flag(args)
		_:
			push_warning("WebGAL[todo]: 未知命令 %s" % WebgalCommands.name_of(cmd))
			return 1


func _set_bg(file: String, args: Array) -> void:
	_bg_path = file
	_bg.position = Vector2.ZERO
	_bg.scale = Vector2.ONE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.offset_left = 0
	_bg.offset_top = 0
	_bg.offset_right = 0
	_bg.offset_bottom = 0
	_bg.modulate.a = 1.0
	_bg.rotation = 0.0
	_set_blur(_bg, 0.0)
	if file == "" or file == "none":
		_bg.texture = null
		_bg.visible = false
		return
	var core := WebgalCore.instance
	if core == null:
		return
	var tex := core.assets.load_texture(file, "background")
	if tex:
		_bg.texture = tex
		_bg.visible = true
		var t: Variant = _get_arg(args, "transform")
		if t != null:
			_apply_bg_transform(t)
	# if placeholder texture (1x1), wait for actual texture
	if tex != null and tex.get_width() == 1 and tex.get_height() == 1:
		var resolved := core.assets.resolve(file, "background")
		var arr := _waiting_replacements.get(resolved, [])
		arr.append(_bg)
		_waiting_replacements[resolved] = arr


func _set_figure(file: String, args: Array) -> void:
	var core := WebgalCore.instance
	if core == null:
		return
	var fig_id = _get_arg(args, "id", "center")
	var node: TextureRect = _get_figure_node(fig_id)
	if node == null:
		node = _create_figure_node(fig_id)
	if file == "" or file == "none":
		node.texture = null
		node.visible = false
		_set_blur(node, 0.0)
		return
	var tex := core.assets.load_texture(file, "figure")
	node.texture = tex
	node.visible = tex != null
	# if placeholder, wait for replacement
	if tex != null and tex.get_width() == 1 and tex.get_height() == 1:
		var resolved := core.assets.resolve(file, "figure")
		var arr := _waiting_replacements.get(resolved, [])
		arr.append(node)
		_waiting_replacements[resolved] = arr
	var zi: Variant = _get_arg(args, "zIndex")
	if zi != null:
		node.z_index = int(zi)
	var t: Variant = _get_arg(args, "transform")
	if t != null:
		_apply_transform_to_node(node, t)
	if _get_arg(args, "left") == true:
		_apply_transform_to_node(node, '{"position":{"x":-400,"y":0}}')
	if _get_arg(args, "right") == true:
		_apply_transform_to_node(node, '{"position":{"x":400,"y":0}}')


func _play_bgm(file: String, args: Array) -> void:
	_bgm_path = file
	if file == "" or file == "none":
		_stop_bgm()
		return
	var core := WebgalCore.instance
	if core == null:
		return
	var vol := float(_get_arg(args, "volume", 80.0))
	var enter_ms := float(_get_arg(args, "enter", 0))
	var stream := core.assets.load_audio(file, "bgm")
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
	if enter_ms > 0:
		var target_vol := p.volume_db
		p.volume_db = -80.0
		p.play()
		var t := create_tween()
		t.tween_property(p, "volume_db", target_vol, enter_ms / 1000.0)
	else:
		p.play()

func _stop_bgm() -> void:
	if has_node("BGMPlayer"):
		(get_node("BGMPlayer") as AudioStreamPlayer).stop()

func _show_intro(content: String) -> void:
	_intro.visible = true
	_intro_label.text = "\n".join(content.split("|"))

func _play_effect(file: String) -> void:
	var core := WebgalCore.instance
	if core == null:
		return
	var stream := core.assets.load_audio(file, "vocal")
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


func _show_choose(content: String, args: Array) -> void:
	_clear_children(_choose_box)
	var raw_pairs := content.split("|")
	for pr in raw_pairs:
		var label := pr
		var target := ""
		var cond_hit := true
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
		_state = State.RUNNING
		_idx += 1
		_continue()
		return
	_choose_box.visible = true

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
	var core := WebgalCore.instance
	if core != null and varname != "":
		core.vars.set_var(varname, default_val)
	_state = State.RUNNING
	_idx += 1
	_continue()


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
	if t.has("blur") and node is TextureRect and _blur_shader:
		_set_blur(node, float(t["blur"]))

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
	if t.has("blur") and _blur_shader:
		_set_blur(_bg, float(t["blur"]))

func _set_transform(content: String, args: Array) -> void:
	var target_id = _get_arg(args, "target", "center")
	var node: Control = _get_figure_node(target_id)
	if node == null:
		if target_id == "black" or target_id == "white":
			_curtain.color = Color.BLACK if target_id == "black" else Color.WHITE
			_curtain.modulate.a = 0.0
			_curtain.visible = true
			_apply_transform_tween(_curtain, content, float(_get_arg(args, "duration", 0)) / 1000.0)
			return
		var tr := TextureRect.new()
		tr.name = target_id
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate.a = 0.0
		_figure_container.add_child(tr)
		_figures[target_id] = tr
		node = tr
	var transform_str := content.strip_edges()
	if transform_str == "":
		transform_str = str(_get_arg(args, "transform", ""))
	if transform_str == "":
		transform_str = _build_transform_from_args(args)
	if transform_str == "":
		return
	if not transform_str.begins_with("{"):
		return
	var duration := float(_get_arg(args, "duration", 0)) / 1000.0
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	_apply_transform_tween(node, transform_str, duration)

func _build_transform_from_args(args: Array) -> String:
	var parts: Array = []
	for a in args:
		var k = str(a.get("key", ""))
		var v = a.get("value", null)
		if v == null:
			continue
		match k:
			"alpha":
				parts.push_back('"alpha":%s' % v)
			"position_x", "x":
				parts.push_back('"position":{"x":%s,"y":0}' % v)
			"position_y", "y":
				parts.push_back('"position":{"x":0,"y":%s}' % v)
			"scale_x":
				parts.push_back('"scale":{"x":%s,"y":1}' % v)
			"scale_y":
				parts.push_back('"scale":{"x":1,"y":%s}' % v)
			"scale":
				parts.push_back('"scale":{"x":%s,"y":%s}' % [v, v])
			"rotation":
				parts.push_back('"rotation":%s' % v)
			"blur":
				parts.push_back('"blur":%s' % v)
	if parts.is_empty():
		return ""
	return "{" + ",".join(parts) + "}"

func _set_animation(content: String, args: Array) -> void:
	var target_id = _get_arg(args, "target", "center")
	var node = _get_figure_node(target_id)
	if node == null:
		return
	var core := WebgalCore.instance
	if core == null:
		return
	# Use assets.load_json to resolve and read animation JSON
	var anim_data = core.assets.load_json("exit/" + content + ".json", "animation")
	if anim_data == null:
		push_warning("WebGAL: 动画文件不存在或无法解析: exit/" + content + ".json -> 跳过动画")
		return
	if typeof(anim_data) != TYPE_ARRAY:
		push_warning("WebGAL: 动画 JSON 不是数组: exit/" + content + ".json -> 跳过动画")
		return
	var frames: Array = anim_data
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	for frame in frames:
		var dur := float(frame.get("duration", 0)) / 1000.0
		if dur <= 0.0:
			_apply_transform_to_node(node, frame)
			continue
		var easing := String(frame.get("easing", "linear"))
		var tween_type := _tween_easing(easing)
		var t := _current_tween.parallel()
		_apply_transform_tween_to(node, t, frame, dur, tween_type)

func _apply_transform_tween(node: Control, json_data, duration: float) -> void:
	if _current_tween == null:
		return
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
	if t.is_empty():
		return
	if duration <= 0.0:
		_apply_transform_to_node(node, t)
		return
	_apply_transform_tween_to(node, _current_tween, t, duration, Tween.EASE_IN_OUT)

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
	if t.has("blur") and node is TextureRect and _blur_shader:
		_set_blur(node, float(t["blur"]))

func _set_blur(node: TextureRect, amount: float) -> void:
	if amount <= 0.0:
		if node.material != null and node.material is ShaderMaterial:
			var sm := node.material as ShaderMaterial
			if sm.shader == _blur_shader:
				node.material = null
		return
	if node.material == null or not (node.material is ShaderMaterial):
		var sm := ShaderMaterial.new()
		sm.shader = _blur_shader
		node.material = sm
	var smat := node.material as ShaderMaterial
	if smat.shader != _blur_shader:
		smat = ShaderMaterial.new()
		smat.shader = _blur_shader
		node.material = smat
	smat.set_shader_parameter("blur_amount", amount)

func _tween_easing(easing: String) -> int:
	match easing.to_lower():
		"ease-in", "ease_in", "in":      return Tween.EASE_IN
		"ease-out", "ease_out", "out":    return Tween.EASE_OUT
		"ease-in-out", "ease_in_out":     return Tween.EASE_IN_OUT
		_:                                 return Tween.EASE_IN_OUT


func _eval_when(s: Dictionary) -> bool:
	for a in s.get("args", []):
		if a.get("key", "") == "when":
			return _eval_condition(str(a.get("value", "")))
	return true

func _eval_condition(expr: String) -> bool:
	var core := WebgalCore.instance
	if core == null:
		return true
	return WebgalStrIf.evaluate(expr, core.vars)


func _jump_to_label_internal(label: String) -> bool:
	for i in _sentences.size():
		var s: Dictionary = _sentences[i]
		if s.get("command", -1) == WebgalModels.Cmd.LABEL and s.get("content", "") == label:
			_idx = i
			return true
	push_warning("WebGAL: 未找到标签 ", label)
	return false


func _set_var(content: String, args: Array) -> void:
	var core := WebgalCore.instance
	if core == null:
		return
	var eq := content.find("=")
	if eq < 0:
		return
	var key := content.substr(0, eq).strip_edges()
	var val := content.substr(eq + 1).strip_edges()
	core.vars.set_var(key, core.vars.evaluate_value(val))


func _pixi_init(content: String, args: Array) -> void:
	_pixi_layer.visible = true
	_pixi_layer.color = Color(0, 0, 0, 0)

func _pixi_effect(content: String, args: Array) -> void:
	pass


func _show_dialog(speaker: String, text: String, args: Array) -> void:
	_dlg_speaker.text = speaker
	_dlg_text.text = text
	_dialog.visible = true
	dialog_shown.emit(speaker, text)


func _get_arg(args: Array, key: String, default = null):
	for a in args:
		if a.get("key", "") == key:
			return a.get("value", default)
	return default

func _advance_flag(args: Array) -> int:
	# ponytail: 视觉效果命令（changeBg/changeFigure/setTransform）总是推进
	# -next 表示"不等演出完成"，暂不实现，留作扩展
	return 1

func _clear_screen() -> void:
	_bg.texture = null
	_bg.visible = false
	_bg.position = Vector2.ZERO
	_bg.scale = Vector2.ONE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.modulate.a = 1.0
	_bg.rotation = 0.0
	_set_blur(_bg, 0.0)
	_clear_children(_figure_container)
	_figures.clear()
	_dialog.visible = false
	_intro.visible = false
	_choose_box.visible = false
	_curtain.visible = false
	_pixi_layer.visible = false
	_pixi_layer.color = Color(0, 0, 0, 0)
	_figure_container.visible = true

func _hide_all_gameplay() -> void:
	_bg.visible = false
	_dialog.visible = false
	_intro.visible = false
	_choose_box.visible = false
	_figure_container.visible = false
	_curtain.visible = false

func _show_menu_bar() -> void:
	_menu_bar.visible = true

func _clear_children(node: Control) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _get_figure_node(fig_id: String) -> TextureRect:
	return _figures.get(fig_id, null)

func _create_figure_node(fig_id: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = fig_id
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure_container.add_child(tr)
	_figures[fig_id] = tr
	return tr

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

func _load_texture_safe(path: String, type: String) -> Texture2D:
	var core := WebgalCore.instance
	if core == null:
		return null
	return core.assets.load_texture(path, type)

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()

func _has_any_save() -> bool:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".save"):
			dir.list_dir_end()
			return true
		f = dir.get_next()
	dir.list_dir_end()
	return false

func _end_game() -> void:
	_state = State.ENDED
	game_ended.emit()

func _end_game_direct() -> void:
	_end_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _state == State.WAITING_INPUT:
			_state = State.RUNNING
			_idx += 1
			_continue()
			get_viewport().set_input_as_handled()
		elif _state == State.CHOOSING:
			get_viewport().set_input_as_handled()
		elif _state == State.WAITING_TIMER:
			_wait_left = 0.0
			_state = State.RUNNING
			_idx += 1
			_continue()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _state == State.WAITING_TIMER:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_state = State.RUNNING
			_idx += 1
			_continue()
	elif _state == State.RUNNING:
		_continue()
	elif _state == State.WAITING_INPUT:
		pass


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	_figure_container = Control.new()
	_figure_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_figure_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_figure_container)

	_curtain = ColorRect.new()
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.color = Color.BLACK
	_curtain.modulate.a = 0.0
	_curtain.mouse_filter = Control.MOUSE_FILTER_PASS
	_curtain.visible = false
	_root.add_child(_curtain)

	_pixi_layer = ColorRect.new()
	_pixi_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pixi_layer.color = Color(0, 0, 0, 0)
	_pixi_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixi_layer.visible = false
	_root.add_child(_pixi_layer)

	_dialog = Panel.new()
	_dialog.visible = false
	_dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_top = -200
	_dialog.offset_bottom = 0
	_dialog.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_dialog)

	_dlg_speaker = Label.new()
	_dlg_speaker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dlg_speaker.offset_left = 20
	_dlg_speaker.offset_top = 10
	_dlg_speaker.add_theme_font_size_override("font_size", 22)
	_dlg_speaker.modulate = Color(0.9, 0.9, 1.0)
	_dialog.add_child(_dlg_speaker)

	_dlg_text = Label.new()
	_dlg_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dlg_text.offset_left = 20
	_dlg_text.offset_top = 40
	_dlg_text.offset_right = -20
	_dlg_text.offset_bottom = -10
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dlg_text.add_theme_font_size_override("font_size", 20)
	_dialog.add_child(_dlg_text)

	_intro = ColorRect.new()
	_intro.visible = false
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.color = Color(0, 0, 0, 0.7)
	_intro.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_intro)

	_intro_label = Label.new()
	_intro_label.set_anchors_preset(Control.PRESET_CENTER)
	_intro_label.add_theme_font_size_override("font_size", 36)
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(_intro_label)

	_choose_box = VBoxContainer.new()
	_choose_box.visible = false
	_choose_box.set_anchors_preset(Control.PRESET_CENTER)
	_choose_box.offset_top = -100
	_choose_box.offset_bottom = 100
	_choose_box.offset_left = -200
	_choose_box.offset_right = 200
