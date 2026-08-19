# plugin.gd - WebGAL for Godot 编辑器插件入口
# 功能：自定义类型 + 编译工具按钮
@tool
extends EditorPlugin

var _compile_btn: Button


func _enter_tree() -> void:
	add_custom_type("WebgalPlayer", "Node", preload("src/webgal_player.gd"), null)
	_add_compile_button()


func _exit_tree() -> void:
	remove_custom_type("WebgalPlayer")
	_remove_compile_button()


func _add_compile_button() -> void:
	_compile_btn = Button.new()
	_compile_btn.text = "编译 WebGAL"
	_compile_btn.flat = true
	_compile_btn.pressed.connect(_on_compile)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _compile_btn)


func _remove_compile_button() -> void:
	if _compile_btn:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _compile_btn)
		_compile_btn.queue_free()
		_compile_btn = null


func _on_compile() -> void:
	var compiler := WebgalCompiler.new()
	var result := compiler.compile("res://")
	if result is int:
		print("✅ WebGAL 编译完成: ", result, " 个场景 → addons/webgal/dist/scene_data.json")
	elif result is String:
		push_error("❌ WebGAL 编译失败: ", result)