# RunScript.gd — 对应 WebGAL Core/controller/gamePlay/runScript.ts
# 语句调用器：根据 command 分发到对应 gameScript 函数
extends Node
class_name WebgalRunScript


func run(script: Dictionary) -> void:
	var core = WebgalCore.instance
	if core == null:
		return
	
	var cmd: int = script.get("command", WebgalModels.Cmd.SAY)
	var content: String = script.get("content", "")
	var args: Array = script.get("args", [])
	
	match cmd:
		WebgalModels.Cmd.SAY:
			WebgalSay.execute(content, args)
		WebgalModels.Cmd.CHANGE_BG:
			WebgalChangeBg.execute(content, args)
		WebgalModels.Cmd.CHANGE_FIGURE:
			WebgalChangeFigure.execute(content, args)
		WebgalModels.Cmd.BGM:
			WebgalBgm.execute(content, args)
		WebgalModels.Cmd.INTRO:
			WebgalIntro.execute(content, args)
		WebgalModels.Cmd.CHOOSE:
			WebgalChoose.execute(content, args)
		WebgalModels.Cmd.END:
			WebgalEnd.execute()
		WebgalModels.Cmd.LABEL:
			pass
		WebgalModels.Cmd.JUMP_LABEL:
			WebgalJumpLabel.execute(content)
		WebgalModels.Cmd.SET_VAR:
			WebgalSetVar.execute(content, args)
		WebgalModels.Cmd.CHANGE_SCENE:
			WebgalChangeScene.execute(content)
		WebgalModels.Cmd.CALL_SCENE:
			WebgalCallScene.execute(content)
		WebgalModels.Cmd.RETURN:
			WebgalReturn.execute()
		WebgalModels.Cmd.WAIT:
			WebgalWait.execute(content)
		WebgalModels.Cmd.PLAY_EFFECT:
			WebgalPlayEffect.execute(content)
		WebgalModels.Cmd.SET_TRANSFORM:
			WebgalSetTransform.execute(content, args)
		WebgalModels.Cmd.SET_ANIMATION:
			WebgalSetAnimation.execute(content, args)
		WebgalModels.Cmd.GET_USER_INPUT:
			WebgalGetUserInput.execute(content, args)
		WebgalModels.Cmd.PIXI:
			WebgalPixi.execute(content, args)
		WebgalModels.Cmd.PIXI_INIT:
			WebgalPixiInit.execute(content, args)
		WebgalModels.Cmd.SET_TEXTBOX:
			WebgalSetTextbox.execute(content, args)
		WebgalModels.Cmd.UNLOCK_CG:
			WebgalUnlockCg.execute(content, args)
		WebgalModels.Cmd.UNLOCK_BGM:
			WebgalUnlockBgm.execute(content, args)
		WebgalModels.Cmd.SET_TRANSITION:
			# ponytail: setTransition 同 setTransform，仅别名
			WebgalSetTransform.execute(content, args)
		_: # 未实现命令静默跳过
			pass