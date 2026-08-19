# WebGAL 脚本语法参考（本插件实现）

> 基于本插件解析器（`script_parser.gd`）和场景文件实际使用情况整理。
> 引擎：Godot 4.x | 插件：WebGAL 运行时解释器

---

## 一、基本格式

每行一条语句，支持以下格式：

```
命令:内容 -参数名=参数值 -参数名=参数值
```

**规则：**
- `:` 分隔命令名与内容（第一个冒号）
- ` -` 后为参数段（空格+短横线）
- `;` 是行尾注释起点（`\;` 转义）
- `//` 或 `;` 开头为注释行

---

## 二、命令列表

### 1. 对话 —— `SAY`

```
说话人:对话内容 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `speaker` | 字符串 | 显式指定说话人 |
| `fontSize` | `default`/`small`/`medium`/`large` | 字号 |
| `center` | `true` | 居中显示 |
| `say` | `true` | 连续对话标记（无说话人时） |

**示例：**
```
厝述:“唉，又是这样...” -fontSize=default;
:你注视着她和她的电脑，什么也没说，什么也没想。”
```

---

### 2. 切换背景 —— `changeBg`

```
changeBg:图片路径 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `transform` | JSON 字符串 | 运镜参数（见下方 Transform 格式） |
| `next` | `true` | 不阻塞，继续执行下一条 |
| `unlockname` | 字符串 | 图鉴解锁名 |

**说明：** 背景使用 `PRESET_FULL_RECT + STRETCH_KEEP_ASPECT_COVERED` 全屏铺满。
transform 只取 `alpha` 和 `rotation`，忽略 `position` 和 `scale`（防止溢出屏幕）。

**示例：**
```
changeBg:校园/校园-上午.png -transform={"position":{"x":-800,"y":-600},"scale":{"x":2,"y":2}} -next;
changeBg:gtx/我或许会拥有的人生片段其二/我或许会拥有的人生片段其二-o.png -next;
changeBg:none;
```

---

### 3. 切换立绘 —— `changeFigure`

```
changeFigure:图片路径 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `id` | 字符串 | 立绘标识（默认 `center`） |
| `transform` | JSON 字符串 | 运镜参数 |
| `zIndex` | 整数 | 层级（越大越靠上） |
| `left` | `true` | 快速左移（`position:{"x":-400,"y":0}`） |
| `right` | `true` | 快速右移（`position:{"x":400,"y":0}`） |
| `next` | `true` | 不阻塞 |

**说明：** 图片路径为空时仅更新 transform 不换图。
`id` 相同的立绘复用已有节点，`changeFigure:none -id=xxx` 移除立绘。

**示例：**
```
changeFigure:cm/cm1-n.png -id=cm -next -zIndex=2;
changeFigure: -id=jm -transform={"position":{"x":0,"y":400},"scale":{"x":1.5,"y":1.5}} -next -zIndex=4;
changeFigure:none -id=cpzA -next;
```

---

### 4. 背景音乐 —— `bgm`

```
bgm:音频文件路径 -参数
bgm:（空 = 停止）
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `enter` | 毫秒 | 淡入时间 |
| `volume` | 0-100 | 音量（默认 80） |
| `next` | `true` | 不阻塞 |

**示例：**
```
bgm:开花太阳.mp3 -enter=5400 -next;
bgm: -enter=5400 -next;
```

---

### 5. 音效 —— `playEffect`

```
playEffect:音频文件路径 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `id` | 字符串 | 音效标识 |
| `volume` | 0-100 | 音量 |
| `next` | `true` | 不阻塞 |

---

### 6. 运镜 —— `setTransform`

```
setTransform:JSON -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `target` | 字符串 | 目标节点（figure id、`black`/`white` 等） |
| `duration` | 毫秒 | 过渡时长 |
| `next` | `true` | 不阻塞 |

**Transform JSON 格式：**
```json
{
  "position": {"x": 0, "y": 0},     // 位置（设计分辨率坐标，自动缩放）
  "scale": {"x": 1.5, "y": 1.5},    // 缩放
  "alpha": 0.33,                      // 透明度（0~1）
  "rotation": 10,                     // 旋转角度
  "blur": 50                          // 模糊（未实现，忽略）
}
```

**特殊 target：**
- `black` / `white`：使用专用 `_curtain` 层（最顶层，可点击消失）
- 其他非 figure 名称：创建临时透明节点

**示例：**
```
setTransform:{"alpha":1} -target=black -duration=1200 -next;
setTransform:{"position":{"x":500,"y":1600},"scale":{"x":3.5,"y":3.5},"alpha":0.33} -target=cm -duration=300 -next;
setTransform:{"scale":{"x":-1}} -target=jm -duration=600;
```

---

### 7. 动画 —— `setAnimation`

```
setAnimation:动画文件路径 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `target` | 字符串 | 目标节点 ID |
| `next` | `true` | 不阻塞 |

**说明：** 动画文件位于 `animation/` 目录下，JSON 格式，包含关键帧序列。

---

### 8. 分支选择 —— `choose`

```
choose:选项1:目标场景1|选项2:目标场景2|选项3:目标场景3
```

**选项格式：**
- `(条件)->标签:目标` （条件满足时才显示）
- 目标可以是 `.txt` 场景文件或 `label` 名
- 空目标 = 跳过（继续执行下一条）

**示例：**
```
choose:(FirstPlay==1)->（我是初次游玩）:初次|[jm<6]->（再次游玩）:再次|(jm==6)[jm=-1]->（时机以至）;
choose:厝述:第三章/csx/csx第三章第一节.txt|平潵:第三章/psx/psx第三章第一节.txt;
choose:0.1π（天）| 整整一个太阳日|三次迎接夕阳;
```

---

### 9. 场景切换 —— `changeScene` / `callScene`

```
changeScene:场景文件路径
callScene:场景文件路径
```

- `changeScene`：清空场景栈，进入新场景
- `callScene`：保留当前场景栈，进入子场景，`return` 返回

---

### 10. 标签与跳转 —— `label` / `jumpLabel`

```
label:标签名
jumpLabel:标签名 -when=条件
```

---

### 11. 变量操作 —— `setVar`

```
setVar:变量名=值 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `global` | `true` | 全局变量 |
| `when` | 条件表达式 | 条件满足才执行 |

**变量插值：** 对话/内容中用 `{变量名}` 引用变量

**示例：**
```
setVar:jm=0 -global;
setVar:FirstPlay=0 -global -when=FirstPlay==1;
setVar:jm={jm}+1 -when=Gcs==0 -global;
```

---

### 12. 等待 —— `wait`

```
wait:秒数
```

---

### 13. 黑幕文字 —— `intro`

```
intro:文字内容
intro:标题|副标题
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `fontSize` | 字符串 | 字号 |
| `backgroundColor` | rgba | 背景色（未实现） |
| `fontColor` | rgba | 字体色（未实现） |
| `animation` | 字符串 | 动画（未实现） |
| `delayTime` | 毫秒 | 延迟（未实现） |

---

### 14. 文本框控制 —— `setTextbox`

```
setTextbox:on
setTextbox:hide
```

---

### 15. 结束游戏 —— `end`

```
end;
```

---

### 16. 返回 —— `return`

```
return;
```

（从 `callScene` 的子场景返回）

---

### 17. 解锁 CG / BGM —— `unlockCg` / `unlockBgm`

```
unlockCg:图片路径 -name=名称 -next;
unlockBgm:音频路径 -next;
```

---

### 18. 获取用户输入 —— `getUserInput`

```
getUserInput:变量名 -参数
```

**参数：**
| 参数 | 值 | 说明 |
|------|----|------|
| `defaultValue` | 字符串 | 默认值 |
| `placeholder` | 字符串 | 占位提示 |

---

### 19. Pixi 特效 —— `pixiInit` / `pixi` / `pixiPerform`

```
pixiInit:参数;
pixi:fadeIn -duration=1000 -color=black;
pixi:fadeOut -duration=1000 -color=black;
pixi:flash -duration=500;
pixi:shake -duration=800 -intensity=8;
pixi:blur;
```

---

## 三、通用参数

| 参数 | 适用范围 | 说明 |
|------|---------|------|
| `-next` | 所有可阻塞命令 | 标记为不阻塞，继续执行下一条 |
| `-when` | 大部分命令 | 条件表达式，满足才执行 |

**条件表达式语法：**
```
变量名==值
变量名!=值
变量名<值
变量名>值
变量名<=值
变量名>=值
```

---

## 四、Transform 坐标系统

- **设计分辨率**：1920 × 1080
- **实际坐标**：自动按 `窗口尺寸 / 1920×1080` 缩放
- **背景图**：`changeBg` 的 transform 忽略 `position` 和 `scale`（只取 `alpha`/`rotation`）
- **立绘节点**：`PRESET_FULL_RECT` 锚点 + `STRETCH_KEEP_ASPECT_CENTERED` 拉伸
- **立绘 position**：相对于父容器 `_figure_container` 的偏移（已缩放）

---

## 五、图层顺序（z_index）

| 层 | z_index | 说明 |
|----|---------|------|
| 背景 `_bg` | 0 | 默认 |
| 立绘容器 `_figure_container` | 1 |  |
| 普通遮罩 `_intro` / `_pixi_layer` | 2 |  |
| 聊天框 `_dialog` | 3 |  |
| 选项 `_choose_box` / 输入框 `_input_dialog` | 4 |  |
| 菜单栏 `_menu_bar` | 5 |  |
| 存档界面 `_sl_menu` | 6 |  |
| 标题界面 `_title_screen` | 8 |  |
| 黑色幕布 `_curtain` | 10 | 最顶层，点击消失 |

---

## 六、备注

- 所有布尔参数（如 `-next`）在场景文件中写作 `-next`（无值），解析器将其处理为 `key=true`
- 资源文件路径相对于 `game_root`（`res://`），按类型自动查找：
  - `background/` → 背景图片
  - `figure/` → 立绘
  - `bgm/` → 背景音乐
  - `vocal/` → 音效
  - `scene/` → 场景脚本
  - `animation/` → 动画 JSON
  - `tex/` → 纹理
- 不支持的命令静默跳过（不崩溃）：`miniAvatar`、`filmMode`、`applyStyle`、`callSteam`、`showVars`、`video`、`setTempAnimation`