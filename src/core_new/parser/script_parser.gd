# script_parser.gd - robust single-line parser (core_new)
# Non-intrusive replacement parser placed under src/core_new/parser/
# NOTE: class name is WebgalScriptParserNew to avoid colliding with existing class_name
extends Node
class_name WebgalScriptParserNew

const Cmd := WebgalModels.Cmd

static func is_empty_or_comment(line: String) -> bool:
	var t := line.strip_edges()
	return t == "" or t.begins_with(";") or t.begins_with("//")

func parse(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		var s := parse_line(line)
		if not s.is_empty():
			out.append(s)
	return out

func parse_line(line: String) -> Dictionary:
	var t := line.strip_edges()
	if t == "" or t.begins_with(";") or t.begins_with("//"):
		return {}
	# strip trailing comment (unescaped ';')
	var semi := _find_unescaped(t, ";")
	if semi >= 0:
		t = t.substr(0, semi).strip_edges()
		if t == "":
			return {}

	# normalize some full-width punctuation commonly found in scripts
	t = t.replace("：", ":")
	t = t.replace("－", "-")
	t = t.replace("，", ",")
	t = t.replace("；", ";")
	t = t.replace("→", "->")

	# find first unescaped ':' as head/content separator
	var colon := _find_unescaped(t, ":")
	var head := ""
	var content := ""
	var args: Array = []
	if colon >= 0:
		head = t.substr(0, colon).strip_edges()
		t = t.substr(colon + 1)

	# split args region at first top-level ' -' or leading '-' (outside quotes/brackets)
	var arg_sub := ""
	var dash_index := _find_arg_split_index(t)
	if dash_index >= 0:
		arg_sub = t.substr(dash_index + 1).strip_edges()
		t = t.substr(0, dash_index)
	content = t.strip_edges()

	var command: int = Cmd.SAY
	if colon >= 0 and head != "":
		command = WebgalCommands.to_cmd(head)
		if command == Cmd.SAY:
			args.append(WebgalModels.make_arg("speaker", head))
		elif head == "say":
			args.append(WebgalModels.make_arg("say", true))
	elif colon >= 0:
		args.append(WebgalModels.make_arg("say", true))
	else:
		var maybe_cmd := WebgalCommands.to_cmd(t)
		if maybe_cmd != Cmd.SAY:
			command = maybe_cmd
		else:
			args.append(WebgalModels.make_arg("say", true))

	for raw_arg in _split_args(arg_sub):
		var a := _parse_arg(raw_arg)
		if a != null:
			args.append(a)

	return WebgalModels.make_sentence(command, content, args, line)


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


func _find_arg_split_index(s: String) -> int:
	var in_single := false
	var in_double := false
	var paren := 0
	var brace := 0
	var bracket := 0
	var i := 0
	while i < s.length():
		var ch := s[i]
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
			if ch == ' ' and i + 1 < s.length() and s[i + 1] == '-' and paren == 0 and brace == 0 and bracket == 0:
				return i + 1
		i += 1
	if s.length() > 0 and s[0] == '-' and paren == 0 and brace == 0 and bracket == 0 and not in_single and not in_double:
		return 0
	return -1


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
			if ch == ' ' and i + 1 < s.length() and s[i + 1] == '-' and paren == 0 and brace == 0 and bracket == 0:
				out_s += buf + delim
				buf = ""
				i += 1
				while i + 1 < s.length() and s[i + 1] == ' ':
					i += 1
				continue
		buf += ch
		i += 1
	if out_s == "" and s.strip_edges().begins_with("-"):
		pass
	else:
		if buf != "":
			out_s += buf
	var parts := out_s.split(delim, false)
	var out := []
	for p in parts:
		var trimmed := p.strip_edges()
		if trimmed != "":
			if trimmed.begins_with("-"):
				trimmed = trimmed.substr(1).strip_edges()
			out.append(trimmed)
	return out


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

	var lower := key.to_lower()
	if lower.ends_with(".ogg") or lower.ends_with(".mp3") or lower.ends_with(".wav") or lower.ends_with(".opus"):
		return WebgalModels.make_arg("vocal", key)
	if key == "vocal" and typeof(value) == TYPE_STRING:
		return WebgalModels.make_arg("vocal", value)

	return WebgalModels.make_arg(key, value)
