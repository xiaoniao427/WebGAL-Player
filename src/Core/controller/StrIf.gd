# StrIf.gd — 对应 WebGAL Core/controller/gamePlay/strIf.ts
# 简单条件表达式求值
extends Node
class_name WebgalStrIf


static func evaluate(expr: String, vars: WebgalVariables) -> bool:
	expr = expr.strip_edges()
	if expr == "":
		return true
	var interp := vars.interpolate(expr)
	var ops := ["!=", "==", "<=", ">=", "<", ">"]
	for o in ops:
		var idx := interp.find(o)
		if idx >= 0:
			var left := interp.substr(0, idx).strip_edges()
			var right := interp.substr(idx + o.length()).strip_edges()
			return _compare(left, right, o)
	var v := interp.strip_edges()
	return not (v == "" or v == "0" or v == "false")


static func _compare(left: String, right: String, op: String) -> bool:
	var is_num := left.is_valid_float() and right.is_valid_float()
	var lf := float(left)
	var rf := float(right)
	match op:
		"==":
			return left == right if not is_num else lf == rf
		"!=":
			return left != right if not is_num else lf != rf
		"<":
			return lf < rf if is_num else false
		">":
			return lf > rf if is_num else false
		"<=":
			return lf <= rf if is_num else false
		">=":
			return lf >= rf if is_num else false
	return true