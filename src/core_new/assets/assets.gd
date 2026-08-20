# assets.gd - resource resolution & loading (core_new)
# Non-invasive new assets manager. Class name ends with New to avoid colliding.
extends Node
class_name WebgalAssetsNew

## 游戏根目录（绝对路径或 res:// 路径），确保带尾部/
var game_root: String = "res://"

const _DIRS := {
	"background": "background",
	"bgm": "bgm",
	"figure": "figure",
	"scene": "scene",
	"vocal": "vocal",
	"video": "video",
	"tex": "tex",
}

var _texture_cache: Dictionary = {}

func _init() -> void:
	# nothing for now
	pass

## 把 WebGAL 相对路径解析为完整可访问路径（带扩展名）。
func resolve(file_name: String, type_name: String) -> String:
	if file_name == null:
		return ""
	file_name = str(file_name)
	if file_name == "" or file_name == "none":
		return ""
	if file_name.begins_with("http://") or file_name.begins_with("https://"):
		# remote URLs are not supported by default in this stage
		return file_name
	if file_name.begins_with("res://") or file_name.begins_with("user://"):
		return file_name
	var dir := _DIRS.get(type_name, "")
	var ret := game_root
	if not ret.ends_with("/"):
		ret += "/"
	if dir != "":
		ret += dir + "/"
	ret += file_name
	return ret

## 加载图片 texture（同步）。失败返回 null。
func load_texture(file_name: String, type_name: String = "background") -> Texture2D:
	if file_name == null:
		return null
	if file_name == "" or file_name == "none":
		return null
	var p := resolve(file_name, type_name)
	if p == "":
		return null
	# http(s) not implemented here
	if p.begins_with("http://") or p.begins_with("https://"):
		push_warning("WebGAL Assets: remote URLs not supported yet: " + p)
		return null

	# cache key is the resolved path
	if _texture_cache.has(p):
		return _texture_cache[p]

	# res:// path prefer ResourceLoader
	if p.begins_with("res://"):
		var tex_res := ResourceLoader.load(p, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
		if tex_res:
			_texture_cache[p] = tex_res
			return tex_res

	# For non-res paths, check file existence
	if not FileAccess.file_exists(p):
		push_warning("WebGAL Assets: file not found: " + p)
		return null

	# Load image from file and create ImageTexture on main thread
	var img := Image.new()
	var err := img.load(p)
	if err != OK:
		push_warning("WebGAL Assets: failed to load image: " + p + " (err=" + str(err) + ")")
		return null
	var tex := ImageTexture.create_from_image(img)
	if tex:
		_texture_cache[p] = tex
		return tex
	push_warning("WebGAL Assets: failed to create texture from image: " + p)
	return null

## 清理缓存（可按路径或全部）
func clear_texture_cache(path: String = "") -> void:
	if path == "":
		_texture_cache.clear()
		return
	if _texture_cache.has(path):
		_texture_cache.erase(path)

## 预加载多个纹理（同步）。返回已加载路径数量
func preload_textures(list: Array, type_name: String = "figure") -> int:
	var count := 0
	for f in list:
		var t := load_texture(str(f), type_name)
		if t != null:
			count += 1
	return count

## 简单 helper：判断是否为 cached
func is_texture_cached(file_name: String, type_name: String = "figure") -> bool:
	var p := resolve(file_name, type_name)
	return p != "" and _texture_cache.has(p)
