# variables.gd - WebGAL 变量系统
# 覆盖：setVar 存变量、{var} 插值、简单算术求值。
# 对齐原版：变量都是字符串，setVar 值可为 {其他变量} 拼接、数字表达式。
# Godot 的 Expression 类只做纯数学运算，安全（不执行任意脚本）。
class_name WebgalVariables

var _vars := {}

func set_var(key: String, value) -> void:
	_vars[key] = value

func get_var(key: String, default = "") -> String:
	return str(_vars.get(key, default))

func has(key: String) -> bool:
	return _vars.has(key)

## 把文本里的 {key} 全部替换为变量值；未定义变量替换为空串。
func interpolate(text: String) -> String:
	var out := text
	while out.find("{") >= 0:
		var s := out.find("{")
		var e := out.find("}")
		if e < 0 or e <= s:
			# 只有裸 { 无配对 } 视为普通字符
			break
		var name := out.substr(s + 1, e - s - 1).strip_edges()
		var repl := str(_vars.get(name, ""))
		out = out.replace("{" + name + "}", repl)
	return out

## 解析 setVar 的右值：
##   先做 {var} 插值，再尝试纯数学求值（Expression，仅数学），失败则返回原字符串。
func evaluate_value(raw: String):
	var interpolated := interpolate(raw)
	# 尝试数学表达式求值（仅当看起来像数字表达式）
	if _is_math_expr(interpolated):
		var expr := Expression.new()
		var err := expr.parse(interpolated)
		if err == OK:
			var res = expr.execute()
			if not expr.has_execute_failed():
				# 整数表达式返回整数，浮点返回浮点
				if interpolated.is_valid_int():
					return int(res)
				return res
	return interpolated

## 判断是否像数学表达式（含运算符或纯数字），避免对普通字符串误求值
func _is_math_expr(s: String) -> bool:
	s = s.strip_edges()
	if s == "":
		return false
	# 纯数字或数字+运算符+括号
	for ch in s:
		if not (ch in "0123456789.+-*/() "):
			return false
	return true