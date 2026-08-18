# commands.gd - 命令字符串 -> Cmd 枚举
# 对照 WebGAL webgal/src/Core/parser/sceneParser.ts 的 SCRIPT_TAG_MAP。
# WebGAL 把「带 -next 的语句」和「可无 command 的连续对话」区分开，
# 本插件统一：能识别就识别，识别不了进 DUMMY，保证不炸。
class_name WebgalCommands

const MAP := {
	"say": WebgalModels.Cmd.SAY,
	"changeBg": WebgalModels.Cmd.CHANGE_BG,
	"changeFigure": WebgalModels.Cmd.CHANGE_FIGURE,
	"bgm": WebgalModels.Cmd.BGM,
	"playVideo": WebgalModels.Cmd.VIDEO,
	"intro": WebgalModels.Cmd.INTRO,
	"miniAvatar": WebgalModels.Cmd.MINI_AVATAR,
	"changeScene": WebgalModels.Cmd.CHANGE_SCENE,
	"callScene": WebgalModels.Cmd.CALL_SCENE,
	"choose": WebgalModels.Cmd.CHOOSE,
	"end": WebgalModels.Cmd.END,
	"label": WebgalModels.Cmd.LABEL,
	"jumpLabel": WebgalModels.Cmd.JUMP_LABEL,
	"setVar": WebgalModels.Cmd.SET_VAR,
	"showVars": WebgalModels.Cmd.SHOW_VARS,
	"filmMode": WebgalModels.Cmd.FILM_MODE,
	"setTextbox": WebgalModels.Cmd.SET_TEXTBOX,
	"setAnimation": WebgalModels.Cmd.SET_ANIMATION,
	"playEffect": WebgalModels.Cmd.PLAY_EFFECT,
	"setTempAnimation": WebgalModels.Cmd.SET_TEMP_ANIMATION,
	"setTransform": WebgalModels.Cmd.SET_TRANSFORM,
	"setTransition": WebgalModels.Cmd.SET_TRANSITION,
	"getUserInput": WebgalModels.Cmd.GET_USER_INPUT,
	"applyStyle": WebgalModels.Cmd.APPLY_STYLE,
	"wait": WebgalModels.Cmd.WAIT,
	"return": WebgalModels.Cmd.RETURN,
	"unlockCg": WebgalModels.Cmd.UNLOCK_CG,
	"unlockBgm": WebgalModels.Cmd.UNLOCK_BGM,
	"pixiInit": WebgalModels.Cmd.PIXI_INIT,
	"pixiPerform": WebgalModels.Cmd.PIXI,
	"pixi": WebgalModels.Cmd.PIXI,
	"callSteam": WebgalModels.Cmd.CALL_STEAM,
}

static func to_cmd(raw: String) -> int:
	return MAP.get(raw, WebgalModels.Cmd.SAY)

## 枚举 -> 命令字符串名（用于日志）
static func name_of(cmd: int) -> String:
	for k in MAP:
		if MAP[k] == cmd:
			return k
	return "unknown(%d)" % cmd