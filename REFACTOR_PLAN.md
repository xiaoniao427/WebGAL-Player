# WebGAL-Player 完全重构计划（写入 main 分支）

说明：你要求直接在 main 分支上提交，不修改历史。依据此，我先把重构计划写入一个文件（REFACTOR_PLAN.md），作为后续一系列小而可审核提交的起点。之后会按你同意的逐步提交实现代码（你已要求“完全重构”）。

目标摘要
- 将现有 Godot 插件完全重构为与 OpenWebGAL 兼容的现代化实现，模块化、支持异步资源加载、提供 Pixi 指令映射并提高可维护性与可测试性。

高层架构（最终文件/模块）
- src/core/
  - webgal_core.gd           # 全局单例，模块注册与初始化
  - parser/
    - script_parser.gd       # 单行脚本解析（重写）
    - scene_parser.gd        # 从 scene_data.json 构建运行时句子结构
  - assets/
    - assets.gd              # 资源定位 & 同步加载 + 缓存
    - async_loader.gd       # 可选：异步加载队列（线程读取 -> 主线程创建纹理）
  - scene_manager/
    - scene_manager.gd      # 场景栈（call/return/change）
  - stage/
    - stage_state_manager.gd# 舞台状态机（calculation/view + commit）
  - perform/
    - perform_controller.gd # 演出控制（Tween/AnimationPlayer 封装）
  - pixi_adapter/
    - pixi_adapter.gd      # Pixi 指令到 Godot 映射层（fade/shake/flash 等）
  - controller/
    - 各 gameScripts（ChangeBg/ChangeFigure/Bgm/...）
- src/ui/
  - webgal_player.gd        # UI 构建与高层控制（对话、背景、立绘）
- compiler/
  - compiler.gd             # 已支持 template.json（将保留）
  - tests/                  # parser 单元测试样例
- plugin.gd                 # 编辑器插件入口，增加模板选择与编译按钮
- docs/examples/            # 示例 game_root、template.json、说明文档
- .github/workflows/ci.yml  # CI：运行 parser tests + 编译器校验

分阶段交付（小步提交）
- 阶段 0（今日提交）
  - REFACTOR_PLAN.md（本文件）—— 已提交
- 阶段 1（核心骨架）
  - webgal_core.gd, minimal parser, assets (同步), scene_manager + simple webgal_player.gd
  - 验证：能加载 OpenWebGAL 编译的 scene_data.json，运行基础指令（say/changeBg/changeFigure/choose）
- 阶段 2（演出/动画）
  - perform_controller.gd, pixi_adapter.gd，支持 tween/skip/fast-forward
- 阶段 3（异步 & Editor）
  - async_loader.gd, plugin UI（模板选择/编译并预览），parser tests + CI
- 阶段 4（完善与发布）
  - 文档、示例、Android/Windows/HTML5 兼容性修复、发布说明

提交策略与变更可审查性
- 每个阶段我会把实现拆成小的、可 review 的提交（保持 main 分支上直接提交的原则：每次提交尽量粒度小，便于你回滚或审查）。

权限与下一步请求
- 我已经按要求在 main 分支写入此重构计划文件。
- 请在此对话确认是否允许我按计划开始提交阶段 1 的实现（我会从 webgal_core.gd 与 minimal parser 开始，随后提交 assets/scene_manager/webgal_player 的初版）。

如需我立即开始阶段 1 的第一个提交，请回复：“开始阶段1”。如果有任何偏好（例如先实现异步 loader、或优先支持某些 Pixi 特效），请一并说明。
