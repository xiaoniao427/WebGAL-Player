# compiler.gd - WebGAL 场景编译器
# 输入：scene/*.txt → 输出：dist/scene_data.json
# 形态 1 核心：编译期解析，运行时零解析
class_name WebgalCompiler

## 编译全部场景。返回 场景数量(int) 或 错误信息(String)
func compile(game_root: String) -> Variant:
	var scene_dir := game_root + "scene/"
	var dist_dir := game_root + "addons/webgal/dist/"
	
	# 扫描场景文件
	var scene_files := _scan_scene_files(scene_dir)
	if scene_files.is_empty():
		return "未找到场景文件: " + scene_dir
	
	# 逐文件解析
	var parser := WebgalScriptParser.new()
	var scene_data := {}
	var scene_count := 0
	var errors := []
	
	for fpath in scene_files:
		var raw := _read_text(fpath)
		if raw == "":
			errors.append("无法读取: " + fpath)
			continue
		var sentences := _parse_scene(raw, parser)
		if sentences.is_empty():
			errors.append("无有效语句: " + fpath)
			continue
		# 取相对路径 scene/xxx.txt 作为 key
		var rel := _relative_path(fpath, scene_dir)
		scene_data[rel] = sentences
		scene_count += 1
	
	# 写入 JSON
	var output := {
		"version": 1,
		"scenes": scene_data
	}
	var json_str := JSON.stringify(output, "\t")
	
	# 确保 dist 目录存在
	var dir := DirAccess.open(dist_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(dist_dir)
	
	var f := FileAccess.open(dist_dir + "scene_data.json", FileAccess.WRITE)
	if f == null:
		return "无法写入: " + dist_dir + "scene_data.json"
	f.store_string(json_str)
	
	# 报告错误
	if not errors.is_empty():
		push_warning("WebGAL 编译: " + str(errors.size()) + " 个警告")
		for e in errors:
			push_warning("  " + e)
	
	return scene_count


## 扫描 scene/ 目录下所有 .txt 文件（递归）
func _scan_scene_files(scene_dir: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(scene_dir)
	if dir == null:
		return out
	_scan_dir(dir, scene_dir, out)
	return out


func _scan_dir(dir: DirAccess, base: String, out: Array) -> void:
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f == "." or f == "..":
			f = dir.get_next()
			continue
		var full := base + f
		if dir.current_is_dir():
			var sub := DirAccess.open(full + "/")
			if sub:
				_scan_dir(sub, full + "/", out)
		elif f.ends_with(".txt"):
			out.append(full)
		f = dir.get_next()
	dir.list_dir_end()


## 解析场景文本为句子数组（同运行时 _parse_scene）
func _parse_scene(raw: String, parser: WebgalScriptParser) -> Array:
	var out: Array = []
	for line in raw.split("\n"):
		var l := line.strip_edges()
		if l == "" or l.begins_with(";") or l.begins_with("//"):
			continue
		var s := parser.parse_line(l)
		if not s.is_empty():
			out.append(s)
	return out


## 取相对路径
func _relative_path(full: String, base: String) -> String:
	if full.begins_with(base):
		return full.substr(base.length())
	return full.get_file()


func _read_text(fullpath: String) -> String:
	var f := FileAccess.open(fullpath, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()