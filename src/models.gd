# models.gd - WebGAL 数据模型
# 纯数据类，无场景依赖。用字典保存语句/场景，便于在脚本间传递且不引入 Object 引用泄漏。
class_name WebgalModels

## 命令类型常量（对应 WebGAL parser 的 commandType 枚举，取核心子集 + 占位）
enum Cmd {
	SAY,            ## 对话
	CHANGE_BG,      ## 切换背景
	CHANGE_FIGURE,  ## 切换/加载立绘
	BGM,            ## 背景音乐
	VIDEO,          ## 播放视频
	INTRO,          ## 黑幕文字
	MINI_AVATAR,    ## 小头像
	CHANGE_SCENE,   ## 切换场景（重置栈）
	CALL_SCENE,     ## 调用子场景（入栈）
	CHOOSE,         ## 分支选择
	END,            ## 结束
	LABEL,          ## 标签
	JUMP_LABEL,     ## 跳转标签
	SET_VAR,        ## 设置变量
	SHOW_VARS,      ## 显示变量面板（v1 空实现）
	FILM_MODE,      ## 特写
	SET_TEXTBOX,    ## 文本框换肤
	SET_ANIMATION,  ## 设置常驻动画
	PLAY_EFFECT,    ## 播放音效
	SET_TEMP_ANIMATION, ## 临时动画
	COMMENT,        ## 注释/空行
	SET_TRANSFORM,  ## 运镜
	SET_TRANSITION, ## 转场
	GET_USER_INPUT, ## 获取输入
	APPLY_STYLE,    ## 样式
	WAIT,           ## 等待
	RETURN,         ## 从子场景返回
	UNLOCK_CG,      ## 解锁CG（图鉴）
	UNLOCK_BGM,     ## 解锁BGM（图鉴）
	PIXI,           ## pixi演出特效
	PIXI_INIT,      ## pixi初始化
	CALL_STEAM,     ## Steam回调
	DUMMY,          ## 未识别命令占位（不崩溃）
}

## 资源定位规则：fileType -> 相对 game 根目录的子目录
const RESOURCE_DIRS := {
	"background": "background",
	"bgm": "bgm",
	"figure": "figure",
	"scene": "scene",
	"vocal": "vocal",
	"video": "video",
	"tex": "tex",
}

## 构造一条语句（字典）。
static func make_sentence(command: int, content: String, args: Array, raw := "") -> Dictionary:
	return {
		"command": command,
		"content": content,
		"args": args,       # Array[Dictionary]: {key, value}
		"raw": raw,
		"sub_scenes": [],   # 子场景引用（filesystem path），用于预加载
	}

static func make_arg(p_key: String, p_value) -> Dictionary:
	return {"key": p_key, "value": p_value}