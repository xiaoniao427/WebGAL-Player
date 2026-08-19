# compile.gd - EditorScript：手动触发场景编译
# 在 Godot 编辑器中：右键 → Run As Script
# 或绑定到插件菜单（后续可加）
@tool
extends EditorScript


func _run() -> void:
	var compiler := WebgalCompiler.new()
	var result := compiler.compile("res://")
	
	if result is int:
		print("✅ WebGAL 编译完成: ", result, " 个场景 → addons/webgal/dist/scene_data.json")
	elif result is String:
		push_error("❌ WebGAL 编译失败: ", result)