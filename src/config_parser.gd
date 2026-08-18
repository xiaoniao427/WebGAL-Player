# config_parser.gd - 解析 WebGAL config.txt
# 格式（每行一个配置项）：
#   Key:value;       键值
#   Key:值A|值B;      （未用到的多值语法，webgal parser 支持）
#   支持行内注释（原版解析到分号前）
# 注意 config.txt 中键值大小写敏感，且不存在引号包裹，值到分号结束。
class_name WebgalConfigParser

## 解析 config.txt 文本 -> Dictionary(键->值, 值类型 String|bool|Array of string)
## 常用键：Game_name, Game_key, Title_img, Title_bgm, Game_Logo,
##        Enable_Appreciation, Enable_Continue, Enable_flowchart
static func parse(text: String) -> Dictionary:
	var result := {}
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l == "":
			continue
		# 原版 configParser 以分号结尾；这里去掉行内注释
		var semi := l.find(";")
		if semi >= 0:
			l = l.substr(0, semi).strip_edges()
		if l == "":
			continue
		var colon := l.find(":")
		if colon < 0:
			continue
		var key := l.substr(0, colon).strip_edges()
		var val := l.substr(colon + 1).strip_edges()
		result[key] = _coerce(val)
	return result

## 值转合理类型：true/false->bool，数字->float，含|->Array，否则 String
static func _coerce(val: String):
	if val == "true":
		return true
	if val == "false":
		return false
	if val.find("|") >= 0:
		return val.split("|")
	var f := float(val)
	if val.is_valid_float():
		return f
	return val

## 便捷取字符串（无则返回默认）
static func get_str(cfg: Dictionary, key: String, def := "") -> String:
	var v = cfg.get(key, def)
	if v == null:
		return def
	return String(v)