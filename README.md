# WebGAL Player for Godot 4

Godot 4.x 编辑器插件，用于在 Godot 中直接运行 [WebGAL](https://github.com/OpenWebGAL/WebGAL) 原生游戏。无需修改游戏文件，选择游戏目录即可运行。

## 工作原理

插件读取 WebGAL 标准游戏目录结构（`scene/`、`background/`、`figure/`、`bgm/`、`vocal/`、`config.txt`、`animation/` 等），在 Godot 运行时中逐条解析并执行 WebGAL 脚本。所有 UI 层（对话、背景、立绘、选择分支、标题界面、存档界面）均由 Godot Control 节点构造，不依赖浏览器或 WebView。

## 架构

插件采用 **Core 模块化架构**，与 WebGAL 原项目（TypeScript）文件级代码对应：

```
addons/webgal/src/
├── webgal_player.gd        # 薄 Node 包装器：UI 构建 + 委托给 Core
├── models.gd                # 数据模型（命令枚举 WebgalModels.Cmd）
├── commands.gd              # 命令字符串 ↔ 枚举映射
├── script_parser.gd         # 单行/全文 WebGAL 脚本解析器
├── config_parser.gd         # config.txt 解析器
├── variables.gd             # 变量系统（插值、数学求值）
├── assets.gd                # 资源定位与加载（图片、音频）
└── Core/                    # 对应 WebGAL 的 packages/webgal/src/Core/
    ├── WebGAL.gd            # 全局单例 WebgalCore，持有所有模块引用
    ├── constants.gd         # 常量（设计尺寸、默认时长等）
    ├── Modules/
    │   ├── SceneManager.gd      # 场景栈（最大 64 层）
    │   ├── GamePlay.gd          # 运行时状态（自动/快进）
    │   ├── StageStateManager.gd # 双层状态机（calculation/view）
    │   └── PerformController.gd # 演出控制
    ├── controller/
    │   ├── ScriptExecutor.gd    # 语句执行器（when/插值/跳转）
    │   ├── RunScript.gd         # 命令分发（match cmd → gameScript）
    │   ├── StrIf.gd             # 条件表达式求值
    │   ├── PlayBgm.gd           # BGM 播放
    │   ├── NextSentence.gd      # 推进语句
    │   ├── AutoPlay.gd          # 自动播放
    │   ├── BackToTitle.gd       # 返回标题
    │   ├── ResetStage.gd        # 舞台重置
    │   └── StopAllPerform.gd    # 停止所有演出
    └── gameScripts/            # 20 个命令文件
        Say/ChangeBg/ChangeFigure/Bgm/Intro/Choose/End/
        SetVar/Wait/PlayEffect/ChangeScene/CallScene/Return/
        JumpLabel/SetTransform/SetAnimation/GetUserInput/
        Pixi/PixiInit/SetTextbox/UnlockCg/UnlockBgm
```

## 快速开始

### 安装

1. 将 `addons/webgal` 目录复制到你的 Godot 项目的 `addons/` 下
2. 在 Godot 编辑器中打开 **项目设置 → 插件**，启用 **WebGAL Player**
3. 将 `webgal.tscn` 拖入你的主场景，或直接创建 `WebgalPlayer` 节点（自定义类型，位于 Node 下）

### 配置

选中 `WebgalPlayer` 节点，在 Inspector 中设置导出参数：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `auto_start` | bool | `true` | 启动时自动进入游戏 |
| `export_root` | String | `""` | WebGAL 游戏根目录的完整路径。留空则使用 `res://`（游戏文件放在 Godot 项目内） |
| `start_scene` | String | `"start.txt"` | 入口场景文件名 |
| `title_bg_custom` | String | `""` | 自定义标题背景图（覆盖 `config.txt` 配置） |

### 在 Android 上使用

在 Android 上运行 WebGAL 游戏时，需要将游戏目录（例如 `/storage/emulated/0/.../game/`）通过 `export_root` 指定：

1. 将 `WebgalPlayer` 节点拖入场景
2. 在 Inspector 中设置 `export_root` 为游戏目录的完整路径，例如：
   ```
   /storage/emulated/0/Documents/MyWebgalGame/
   ```
3. 确保游戏目录包含标准的 WebGAL 结构（见下方「目录结构」）

插件会自动以全屏模式运行，`canvas_items` 拉伸模式自动适配屏幕比例。

## 目录结构

插件期望游戏目录遵循 WebGAL 标准结构，并增加编译缓存：

```
game_root/
├── config.txt              # 游戏配置（标题、背景、BGM 等）
├── start.txt               # 起始场景（可由 start_scene 参数修改）
├── scene/                  # 场景脚本文件（.txt）— 源码
│   ├── start.txt
│   └── ...
├── ...
└── addons/webgal/
    ├── dist/
    │   └── scene_data.json  # 编译产物（自动生成，勿手动编辑）
    ├── compiler/
    │   ├── compiler.gd      # 编译器核心
    │   └── compile.gd       # EditorScript（手动触发）
    └── ...
```

## 编译工作流

本插件采用 **形态 1 架构**：编译器在 Godot 编辑器内运行，产出 JSON 缓存，运行时零解析。

### 工作方式

| 阶段 | 行为 |
|------|------|
| 开发期 | 编辑 `scene/*.txt` 后，重启游戏 → 自动检测文件变更 → 自动重编译 → 加载最新编译结果 |
| 编辑器 | 点击工具栏 **「编译 WebGAL」** 按钮手动触发编译 |
| 打包 | 预编译产物 `dist/scene_data.json` 随 APK 打包，运行时直接加载，零解析开销 |

### 优先级

1. 如果 `dist/scene_data.json` 存在 → 加载缓存（**优先**）
2. 如果缓存不存在 → 运行时逐行解析（**向下兼容**，旧工作流不变）

### 自动重编译触发条件

- 仅在编辑器内（`Engine.is_editor_hint()`）
- 任意 `scene/*.txt` 的 mtime 比 `dist/scene_data.json` 新
- 重编译后自动重新加载缓存，无需手动操作

## 已支持的命令

### 核心功能（已实现）

| 命令 | 说明 |
|------|------|
| `say` / 对话 | 显示说话人 + 文本，带语音播放 |
| `changeBg` | 切换背景图片，支持 transform 运镜 |
| `changeFigure` | 切换/加载立绘，支持 `id`、`zIndex`、`left`/`right`、`transform` |
| `bgm` | 播放/停止背景音乐，支持 `volume` |
| `intro` | 黑幕文字显示 |
| `choose` | 分支选择，支持条件表达式 `(条件)` |
| `changeScene` | 切换场景（重置场景栈） |
| `callScene` / `return` | 子场景调用与返回 |
| `label` / `jumpLabel` | 标签跳转 |
| `setVar` | 变量设置与数学表达式求值 |
| `setTransform` | 立绘/节点运镜（position/scale/alpha/rotation），支持 Tween 动画 |
| `setTransition` | 同 `setTransform`，仅别名 |
| `setAnimation` | 从 JSON 动画文件播放关键帧动画 |
| `playEffect` | 播放音效 |
| `wait` | 等待指定秒数 |
| `end` | 结束游戏 |
| `getUserInput` | 获取输入（当前仅做默认值赋值） |
| `pixi` / `pixiInit` | 简单画面特效（fadeIn/fadeOut 等） |
| `setTextbox` | 显示/隐藏对话框：`setTextbox:on` / `setTextbox:hide` |
| `unlockCg` | 解锁 CG（日志记录，无图鉴界面） |
| `unlockBgm` | 解锁 BGM（日志记录，无图鉴界面） |

### 未实现（静默跳过）

`miniAvatar`、`filmMode`、`applyStyle`、`setTempAnimation`、`callSteam`、`video`、`showVars` 等命令会被识别但静默跳过，不会触发运行时错误。

## 游戏操作

| 操作 | 效果 |
|------|------|
| 点击/触摸屏幕 | 推进对话/跳过等待 |
| 按 Esc / 返回键 | 切换菜单栏显示/隐藏 |
| 菜单栏按钮 | 存档、读档、倍速、自动播放、返回标题 |

- **倍速**：1x / 2x / 3x 循环切换
- **自动播放**：切换自动模式，每 2 秒自动推进
- **存档/读档**：9 个存档位，带缩略图预览

## 存档格式

存档保存在 `user://webgal_saves/` 目录下：

- `save_X.json`：存档数据（场景、索引、变量、立绘状态等）
- `save_X.png`：存档缩略图

## 文件结构

```
addons/webgal/
├── plugin.cfg              # 插件元数据
├── plugin.gd               # 编辑器插件入口（注册 WebgalPlayer 类型 + 编译按钮）
├── webgal.tscn             # 预置场景（可直接拖入）
├── README.md               # 本文件
├── shaders/
│   └── blur.gdshader       # 背景模糊着色器（9-tap box blur）
├── dist/
│   └── scene_data.json     # 编译产物（自动生成）
├── compiler/
│   ├── compiler.gd         # 编译器核心（class_name WebgalCompiler）
│   └── compile.gd          # EditorScript：右键 → Run 手动编译
└── src/
    ├── webgal_player.gd    # 薄 Node 包装器（UI 构建 + 委托给 Core）
    ├── models.gd            # 数据模型（WebgalModels.Cmd 枚举等）
    ├── commands.gd          # 命令字符串 ↔ 枚举映射
    ├── script_parser.gd     # WebGAL 脚本解析器（单行/全文）
    ├── config_parser.gd     # config.txt 解析器
    ├── variables.gd         # 变量系统（插值、数学求值）
    ├── assets.gd            # 资源定位与加载（图片、音频）
    └── Core/                # 与 WebGAL 原项目文件级对应
        ├── WebGAL.gd        # 全局单例 WebgalCore
        ├── constants.gd     # 常量（设计尺寸、默认时长等）
        ├── Modules/
        │   ├── SceneManager.gd
        │   ├── GamePlay.gd
        │   ├── StageStateManager.gd
        │   └── PerformController.gd
        ├── controller/
        │   ├── ScriptExecutor.gd
        │   ├── RunScript.gd
        │   ├── StrIf.gd
        │   ├── PlayBgm.gd
        │   ├── ResetStage.gd
        │   ├── NextSentence.gd
        │   ├── AutoPlay.gd
        │   ├── BackToTitle.gd
        │   └── StopAllPerform.gd
        └── gameScripts/    # 20 个命令文件
            ├── Say.gd
            ├── ChangeBg.gd
            ├── ChangeFigure.gd
            ├── Bgm.gd
            ├── Intro.gd
            ├── Choose.gd
            ├── End.gd
            ├── SetVar.gd
            ├── Wait.gd
            ├── PlayEffect.gd
            ├── ChangeScene.gd
            ├── CallScene.gd
            ├── Return.gd
            ├── JumpLabel.gd
            ├── SetTransform.gd
            ├── SetAnimation.gd
            ├── GetUserInput.gd
            ├── Pixi.gd / PixiInit.gd
            ├── SetTextbox.gd
            ├── UnlockCg.gd
            └── UnlockBgm.gd
```

## 已知限制

- **Ogg/Opus 音频**：当前不支持（Godot 4 无 `load_from_file` API），`mp3` 和 `wav` 正常工作
- **Pixi 特效 / Live2D**：Pixi 基础 fadeIn/fadeOut 已实现，复杂粒子特效未实现；Live2D 未实现
- **`setAnimation` 关键帧插值**：仅做线性 Tween，未实现 WebGAL 原版贝塞尔曲线
- **`getUserInput` 输入框**：当前仅做默认值赋值，未弹出 UI 输入框
- **图鉴系统**：`unlockCg` / `unlockBgm` 仅日志记录，无实际图鉴界面
- **视频播放**：`video` 命令未实现
- **`setTransform` 参数式写法**：`setTransform: -target=xxx -alpha=0.33`（无 JSON content）当前不被解析，仅支持 content 内嵌 JSON 或 `-transform` 参数
- **编译器**：`compiler/compiler.gd` 使用与运行时相同的 `script_parser.gd` 解析器，语法兼容性取决于 parser 实现。编译器本身不依赖 Node 工具链，完全在 Godot 编辑器内运行。

## 许可证

本项目基于 WebGAL 社区协议。WebGAL 是 [@OpenWebGAL](https://github.com/OpenWebGAL) 的开源项目。