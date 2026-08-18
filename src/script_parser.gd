# script_parser.gd - 单行脚本解析
# 对应 WebGAL packages/parser/src/scriptParser/*.ts
# 输入：一行 WebGAL 原文
# 输出：{command:int, content:String, args:Array[{key,value}], raw:String} 或 {}
# 规则（对齐原版）：
#   - 行首以 ; 或 // 开头 -> 注释（返回 {}）
#   - `;` 是行尾注释起点（`\;` 转义），取分号前部分
#   - 第一个`:`分隔命令/说话人与内容
#   - ` -` 后是参数字段
# 注：内容里的资源路径转换在运行时按 command 类型做，解析器只负责切分。
class_name WebgalScriptParser

const Cmd := WebgalModels.Cmd

## 判定空行/纯注释
static func is_empty_or_comment(line: String) -> bool:
	var t := line.strip_edges()
	return t == "" or t.begins_with(";") or t.begins_with("//")

## 解析一行。返回 Sentence(dictionary)，空/注释返回 {}。
func parse_line(line: String) -> Dictionary:
	var t := line.strip_edges()
	if t == "" or t.begins_with(";") or t.begins_with("//"):
		return {}
	# 去行尾注释
	var semi := _find_unescaped(t, ";")
	if semi >= 0:
		t = t.substr(0, semi).strip_edges()
		if t == "":
			return {}
	# 第一个冒号
	var colon := _find_unescaped(t, ":")
	var head := ""
	var content := ""
	var args: Array = []
	if colon >= 0:
		head = t.substr(0, colon).strip_edges()
		t = t.substr(colon + 1)
	# 分离参数字段（" -"）
	var arg_sub := ""
	var dash := t.find(" -")
	if dash >= 0:
		arg_sub = t.substr(dash + 2)
		t = t.substr(0, dash)
	content = t.strip_edges()

	# 确定命令与隐式参数
	var command: int = Cmd.SAY
	if colon >= 0 and head != "":
		command = WebgalCommands.to_cmd(head)
		if command == Cmd.SAY:
			# 不是已知命令：把 head 当作说话人
			args.append(WebgalModels.make_arg("speaker", head))
		elif head == "say":
			args.append(WebgalModels.make_arg("say", true))
	elif colon >= 0:
		# 冒号但空 head（如 ":台詞"） -> 连续对话
		args.append(WebgalModels.make_arg("say", true))
	else:
		# 无冒号：可能是单命令（end; pixiInit;）也可能是连续对话。
		# 原版 commandParser 会拿整行去匹配命令表。
		var maybe_cmd := WebgalCommands.to_cmd(t)
		if maybe_cmd != Cmd.SAY:
			command = maybe_cmd
		else:
			args.append(WebgalModels.make_arg("say", true))

	# 解析参数
	for raw_arg in _split_args(arg_sub):
		var a := _parse_arg(raw_arg)
		if a != null:
			args.append(a)

	return WebgalModels.make_sentence(command, content, args, line)


## 找到第一个未转义字符索引，找不到 -1
func _find_unescaped(s: String, c: String) -> int:
	var i := 0
	while i < s.length():
		if s[i] == "\\":
			i += 2
			continue
		if s[i] == c[0]:
			return i
		i += 1
	return -1


## 拆分参数段（原版 split(" -")）
func _split_args(s: String) -> Array:
	if s.strip_edges() == "":
		return []
	var out: Array = []
	for p in s.split(" -", false):
		var trimmed := p.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out


## 解析单个参数字段 -> arg {key,value}
func _parse_arg(raw: String) -> Dictionary:
	var eq := raw.find("=")
	var key: String
	var value
	if eq >= 0:
		key = raw.substr(0, eq).strip_edges()
		var vs := raw.substr(eq + 1).strip_edges()
		if vs == "true":
			value = true
		elif vs == "false":
			value = false
		elif vs.is_valid_int():
			value = int(vs)
		elif vs.is_valid_float():
			value = float(vs)
		else:
			value = vs
	else:
		key = raw.strip_edges()
		value = true

	# 语音参数：音频后缀作为独立 flag 或 vocal=file
	var lower := key.to_lower()
	if lower.ends_with(".ogg") or lower.ends_with(".mp3") or lower.ends_with(".wav") or lower.ends_with(".opus"):
		return WebgalModels.make_arg("vocal", key)
	if key == "vocal" and typeof(value) == TYPE_STRING:
		return WebgalModels.make_arg("vocal", value)

	return WebgalModels.make_arg(key, value)