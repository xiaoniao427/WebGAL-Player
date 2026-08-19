# script_parser.gd - 单行脚本解析
# 对应 WebGAL packages/parser/src/scriptParser/*.ts
# 输入：一行 WebGAL 原文
# 输出：{command:int, content:String, args:Array[{key,value}], raw:String} 或 {}
# 规则（对齐原版）：
#   - 行首以 ; 或 // 开头 -> 注释（返回 {})
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

## 解析完整脚本（多行文本）。返回 Sentence 数组，跳过空行和注释。
func parse(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		var s := parse_line(line)
		if not s.is_empty():
			out.append(s)
	return out

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

	# 兼容全角标点：把常见全角符号规范化为半角，减少脚本中中文标点导致的解析失败
	# 注意：仅做字符替换，不改变转义逻辑（转义字符仍为 ASCII 反斜杠）
	t = t.replace("：", ":")
	t = t.replace("－", "-")
	t = t.replace("，", ",")
	t = t.replace("；", ";")
	t = t.replace("→", "->")

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
	# 我们需要在不处于括号/中括号/花括号/引号内的情况下拆分参数，
	# 因为 transform 的 JSON 字符串可能包含空格和减号。
	var dash_index := _find_arg_split_index(t)
	if dash_index >= 0:
		arg_sub = t.substr(dash_index + 1).strip_edges()
		t = t.substr(0, dash_index)
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

	# 解析参数：使用更稳健的拆分函数，避免在 JSON/[]/() 中误拆分
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


## 在外层（未进入引号/括号/中括号/花括号）查找参数区分的起始索引（第一个前导 '-'）
func _find_arg_split_index(s: String) -> int:
	var in_single := false
	var in_double := false
	var paren := 0
	var brace := 0
	var bracket := 0
	var i := 0
	while i < s.length():
		var ch := s[i]
		# 处理转义
		if ch == "\\":
			i += 2
			continue
		if ch == "'" and not in_double:
			in_single = not in_single
		elif ch == '"' and not in_single:
			in_double = not in_double
		elif not in_single and not in_double:
			if ch == '(':
				paren += 1
			elif ch == ')':
				paren = max(paren - 1, 0)
			elif ch == '{':
				brace += 1
			elif ch == '}':
				brace = max(brace - 1, 0)
			elif ch == '[':
				bracket += 1
			elif ch == ']':
				bracket = max(bracket - 1, 0)
			# 当遇到空格后紧跟 '-' 且不在任何括号/引号内，认为是参数段的开始
			if ch == ' ' and i + 1 < s.length() and s[i + 1] == '-' and paren == 0 and brace == 0 and bracket == 0:
				return i + 1
		i += 1
	# 也支持以 '-' 开头的参数（无前导空格），但必须在外层
	if s.length() > 0 and s[0] == '-' and paren == 0 and brace == 0 and bracket == 0 and not in_single and not in_double:
		return 0
	return -1


## 拆分参数段（更稳健）：在外层以 " -" 或行首的 '-' 作为分隔符
func _split_args(s: String) -> Array:
	if s.strip_edges() == "":
		return []
	var delim := "|~ARG~|"
	var buf := ""
	var out_s := ""
	var in_single := false
	var in_double := false
	var paren := 0
	var brace := 0
	var bracket := 0
	var i := 0
	while i < s.length():
		var ch := s[i]
		# 处理转义
		if ch == "\\":
			buf += ch
			i += 1
			if i < s.length():
				buf += s[i]
				i += 1
			continue
		if ch == "'" and not in_double:
			in_single = not in_single
		elif ch == '"' and not in_single:
			in_double = not in_double
		elif not in_single and not in_double:
			if ch == '(':
				paren += 1
			elif ch == ')':
				paren = max(paren - 1, 0)
			elif ch == '{':
				brace += 1
			elif ch == '}':
				brace = max(brace - 1, 0)
			elif ch == '[':
				bracket += 1
			elif ch == ']':
				bracket = max(bracket - 1, 0)
			# 在外层检测到空格 + '-' 作为参数起始
			if ch == ' ' and i + 1 < s.length() and s[i + 1] == '-' and paren == 0 and brace == 0 and bracket == 0:
				out_s += buf + delim
				buf = ""
				i += 1 # skip the '-'
				# 跳过后续空格
				while i + 1 < s.length() and s[i + 1] == ' ':
					i += 1
				continue
		buf += ch
		i += 1
	# 行首直接以 '-' 开头，也当作第一个参数起点
	if out_s == "" and s.strip_edges().begins_with("-"):
		# 不需要特殊处理，buf 已包含全部
		pass
	else:
		if buf != "":
			out_s += buf
	# 最后按 delim 拆分
	var parts := out_s.split(delim, false)
	var out := []
	for p in parts:
		var trimmed := p.strip_edges()
		if trimmed != "":
			# 如果参数以 '-' 开头，去掉它
			if trimmed.begins_with("-"):
				trimmed = trimmed.substr(1).strip_edges()
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
