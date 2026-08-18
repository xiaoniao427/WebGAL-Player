# plugin.gd - WebGAL for Godot 编辑器插件入口
# 功能：定义一个编辑器脚本容器，便于把 WebgalPlayer 拖进场景。
# 运行时完全由 webgal_player.gd 承担。
@tool
extends EditorPlugin


func _enter_tree() -> void:
	# 自定义类型可拖入编辑器；图标传 null 表示无图标。
	add_custom_type("WebgalPlayer", "Node", preload("src/webgal_player.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("WebgalPlayer")