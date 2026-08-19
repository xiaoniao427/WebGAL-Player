# assets.gd - WebGAL 资源定位与加载
# 游戏根目录(game_root)下的资源用「文件名相对 game 根」定位：
#   background/<name>, figure/<name>, bgm/<name>, vocal/<name>, scene/<name> ...
# 运行时从任意文件系统路径加载（WebGAL 原生结构，不依赖 Godot 的 import 流程）。
class_name WebgalAssets

## 游戏根目录（绝对路径或 res:// 路径），负责加个尾部/。
var game_root := ""

## 类型名 -> 子目录名（对齐 RESOURCE_DIRS）
const _DIRS := {
	"background": "background",
	"bgm": "bgm",
	"figure": "figure",
	"scene": "scene",
	"vocal": "vocal",
	"video": "video",
	"tex": "tex",
}

# 纹理缓存：避免重复创建 ImageTexture 导致 GPU 内存抖动/不断创建的问题
var _texture_cache := {}

func _init() -> void:
	pass


## 把 WebGAL 相对路径解析为完整可访问路径（带扩展名）。
## 例: resolve("bg.png", "background") -> "<root>/background/bg.png"
func resolve(file_name: String, type_name: String) -> String:
	if file_name.begins_with("http://") or file_name.begins_with("https://"):
		return file_name
	if file_name.begins_with("res://") or file_name.begins_with("user://"):
		return file_name
	var dir := _DIRS.get(type_name, "")
	var ret := game_root
	if not ret.ends_with("/"):
		ret += "/"
	ret += dir
	if dir != "":
		ret += "/"
	ret += file_name
	return ret

## 加载图片 texture。失败返回 null。
func load_texture(file_name: String, type_name := "background") -> Texture2D:
	if file_name == "" or file_name == "none":
		return null
	var p := resolve(file_name, type_name)

	# 先查缓存
	if _texture_cache.has(p):
		return _texture_cache[p]

	# ponytail: res:// 路径优先用 ResourceLoader（导出后 pck 内可用），
	# 非 res:// 路径或未导入的 res:// 资源走 Image.load_from_file fallback
	if p.begins_with("res://"):
		var tex := ResourceLoader.load(p, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
		if tex:
			_texture_cache[p] = tex
			return tex

	# 检查文件存在性：在移动平台上路径/大小写/权限常导致间歇性不可读
	if not FileAccess.file_exists(p):
		push_warning("WebGAL: 图片文件不存在或无法访问: " + p)
		return null

	var img := Image.load_from_file(p)
	if img == null:
		push_warning("WebGAL: 无法加载图片 " + p)
		return null

	# 在主线程创建 GPU 纹理；此处调用是同步的（确保从主线程调用本函数）
	var tex2 := ImageTexture.create_from_image(img)
	if tex2 == null:
		push_warning("WebGAL: ImageTexture.create_from_image 返回 null: " + p)
		return null

	_texture_cache[p] = tex2
	return tex2

## 加载音频流。返回 null 表示失败/空。
func load_audio(file_name: String, type_name := "bgm") -> AudioStream:
	if file_name == "" or file_name == "none":
		return null
	var p := resolve(file_name, type_name)
	var lower := p.to_lower()
	if lower.ends_with(".mp3"):
		var s := AudioStreamMP3.load_from_file(p)
		if s == null:
			push_warning("WebGAL: 无法加载 mp3 " + p)
		return s
	elif lower.ends_with(".ogg") or lower.ends_with(".opus"):
		# ponytail: Godot4 无 AudioStreamOggVorbis.load_from_file；跳过不支持。
		# 事实：demo 用 mp3 做 BGM、wav 做语音/音效，已覆盖。Ogg 走 upgrade。
		push_warning("WebGAL[todo]: ogg/opus 音频暂不支持: " + p)
		return null
	elif lower.ends_with(".wav"):
		return _load_wav(p)
	push_warning("WebGAL: 未知音频格式 " + p)
	return null

## 手动读取 WAV 转 AudioStreamWAV（WebGAL vocal 常用 wav）。
## ponytail: 只支持标准 8/16-bit PCM；浮点/压缩/A-law 走 upgrade 路径。
func _load_wav(p: String) -> AudioStream:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_warning("WebGAL: 无法打开 wav " + p)
		return null
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		f.close()
		push_warning("WebGAL: 非 RIFF wav " + p)
		return null
	f.seek(16)
	var audio_format: int = f.get_16()
	var channels: int = f.get_16()
	var sample_rate: int = f.get_32()
	var bits_per_sample: int = f.get_16()
	# 定位 data 块
	f.seek(12)
	var data_offset := -1
	var data_len := 0
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size: int = f.get_32()
		if id == "data":
			data_offset = f.get_position()
			data_len = size
			break
		f.seek(f.get_position() + size)
	if data_offset < 0:
		f.close()
		push_warning("WebGAL: wav 缺少 data 块 " + p)
		return null
	# 只支持 PCM
	if audio_format != 1:
		f.close()
		push_warning("WebGAL: 非 PCM wav " + p)
		return null
	f.seek(data_offset)
	var data := f.get_buffer(data_len)
	f.close()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = (channels == 2)
	stream.data = data
	return stream
