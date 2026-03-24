# Reelbound Godot MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Godot + GDScript 做出一个可测试、可扩展的 5x5 Slot Roguelike 纵切原型，并按 PRD 路径演进到 MVP。

**Architecture:** 核心玩法逻辑放在纯数据、可重复执行的 GDScript 模拟层，UI/动画/音效只消费模拟结果，不直接决定结算。内容定义优先使用 `Resource` 数据资产，事件、角色、难度、局外成长都通过统一标签和规则接口挂接到同一套结算管线。

**Tech Stack:** Godot 4.6.1-stable（固定版本），GDScript，GUT（单元/集成测试），Godot State Charts（高层流程状态机），可选 Locker（存档版本化与多存档位，进入 Meta 阶段后再接入）

---

## 0. Engine / Plugin Decision

### Engine Pin
- 2026-03-24 时 Godot 官方归档同时列出：
  - `4.6.1-stable`，发布日期 `2026-02-16`
  - `4.5.2-stable`，发布日期 `2026-03-19`
- 本计划先固定到 `Godot 4.6.1-stable`，理由：
  - Godot 官方归档里它是当前最新 stable 主线
  - GUT 仓库当前列出的 `9.6.0` 对应 `Godot 4.6.x`
  - `Godot State Charts` 仍在持续发布，最新 release 为 `v0.22.3 (2026-02-20)`，适合作为高层流程插件
  - 目标是优先保证“稳定版本 + 已验证插件版本”的组合

### Plugin Policy
- 立即采用：
  - `GUT`：测试框架，覆盖纯逻辑层与关键场景流程
  - `Godot State Charts`：只管理高层流程状态，不介入具体分数计算
- 延后采用：
  - `Locker`：等 Meta Progression / 多存档 / 存档版本迁移成为实际需求后再接入
- 不用插件硬套的区域：
  - 棋盘状态
  - 结算顺序
  - Tag / Token / Event 规则解释器
  - 分数目标曲线
- 原则：通用基础设施优先复用插件，核心玩法规则必须自己掌控。

## 1. Proposed Project Structure

### Root
- Create: `project.godot`
- Create: `.gitignore`
- Create: `.gutconfig.json`
- Create: `icon.svg`
- Create: `README.md`

### Addons
- Create: `addons/gut/`
- Create: `addons/godot_state_charts/`
- Create later: `addons/locker/`

### Runtime
- Create: `autoload/app_state.gd`
- Create: `autoload/content_registry.gd`
- Create: `autoload/run_session.gd`
- Create later: `autoload/save_service.gd`

### Core Simulation
- Create: `scripts/core/value_objects/board_pos.gd`
- Create: `scripts/core/value_objects/token_instance.gd`
- Create: `scripts/core/value_objects/run_snapshot.gd`
- Create: `scripts/core/value_objects/settlement_step.gd`
- Create: `scripts/core/value_objects/settlement_report.gd`
- Create: `scripts/core/services/board_service.gd`
- Create: `scripts/core/services/trigger_scanner.gd`
- Create: `scripts/core/services/settlement_resolver.gd`
- Create: `scripts/core/services/reward_offer_service.gd`
- Create: `scripts/core/services/event_draft_service.gd`
- Create: `scripts/core/services/contract_service.gd`
- Create later: `scripts/core/services/endless_service.gd`

### Content Definitions
- Create: `scripts/content/token_definition.gd`
- Create: `scripts/content/event_definition.gd`
- Create: `scripts/content/hero_definition.gd`
- Create: `scripts/content/difficulty_modifier.gd`
- Create: `scripts/content/meta_unlock_definition.gd`
- Create: `scripts/content/anomaly_definition.gd`
- Create: `scripts/content/content_definition_validator.gd`
- Create: `content/tokens/`
- Create: `content/events/`
- Create: `content/heroes/`
- Create: `content/difficulty/`
- Create: `content/meta/`
- Create: `content/anomalies/`

### Scenes / UI
- Create: `scenes/app/app_root.tscn`
- Create: `scenes/run/run_screen.tscn`
- Create: `scenes/run/board_grid.tscn`
- Create: `scenes/run/token_cell.tscn`
- Create: `scenes/run/turn_controls.tscn`
- Create: `scenes/run/settlement_log_panel.tscn`
- Create: `scenes/run/event_draft_panel.tscn`
- Create later: `scenes/meta/meta_screen.tscn`
- Create later: `scenes/endless/endless_summary_panel.tscn`

### Tests
- Create: `tests/unit/core/test_board_service.gd`
- Create: `tests/unit/core/test_trigger_scanner.gd`
- Create: `tests/unit/core/test_settlement_resolver.gd`
- Create: `tests/unit/core/test_reward_offer_service.gd`
- Create: `tests/unit/core/test_event_draft_service.gd`
- Create: `tests/unit/core/test_contract_service.gd`
- Create: `tests/unit/core/test_content_definition_validator.gd`
- Create: `tests/integration/test_run_screen_flow.gd`
- Create later: `tests/integration/test_meta_save_load.gd`

### Docs
- Create: `docs/engineering/plugin-decisions.md`
- Create: `docs/engineering/content-schema.md`
- Create later: `docs/engineering/balance-checklist.md`

## 2. Delivery Phases

### Phase A: Foundation Prototype
- 目标：完成可跑的 5x5 盘面、基础回合、固定结算、基础选项三选一
- 不含：完整局外成长、异常事件、多格 Token

### Phase B: Vertical Slice
- 目标：加入 Event Draft、Risk Contract、3 名主角原型、首轮可玩内容池
- 输出：单局 10~25 分钟的最小可玩体验

### Phase C: MVP
- 目标：Meta、Ascension 1~3、标准通关、Endless、2~4 个异常事件
- 说明：`6x6` 扩盘属于 Phase C 的可选高光项，不应阻塞 MVP 稳定性交付

## 3. Implementation Tasks

### Task 1: Bootstrap Godot Project And Tooling

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `.gutconfig.json`
- Create: `README.md`
- Create: `docs/engineering/plugin-decisions.md`
- Create: `tests/unit/core/test_project_bootstrap.gd`
- Install: `addons/gut/`
- Install: `addons/godot_state_charts/`

- [x] **Step 1: 写一个会失败的项目启动测试**

```gdscript
extends GutTest

func test_project_name_is_configured() -> void:
	assert_true(ProjectSettings.has_setting("application/config/name"))
```

- [x] **Step 2: 运行测试并确认当前失败**

Run:

```powershell
$env:GODOT_BIN="C:\Tools\Godot\Godot_v4.6.1-stable_win64.exe"
& $env:GODOT_BIN --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 失败，原因是项目尚未初始化或 `project.godot` / `addons/gut` 尚不存在。

- [x] **Step 3: 初始化工程、目录和插件**
- 建立标准 Godot 工程
- 安装并启用 `GUT`
- 安装并启用 `Godot State Charts`
- 写明插件版本、来源、升级策略到 `docs/engineering/plugin-decisions.md`

- [x] **Step 4: 再次运行测试**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: `test_project_name_is_configured` PASS

- [x] **Step 5: Commit**

```powershell
git init
git add .
git commit -m "chore: bootstrap godot project and tooling"
```

### Task 2: Define Content Schema And Registry

**Files:**
- Create: `scripts/content/token_definition.gd`
- Create: `scripts/content/event_definition.gd`
- Create: `scripts/content/hero_definition.gd`
- Create: `scripts/content/difficulty_modifier.gd`
- Create: `scripts/content/meta_unlock_definition.gd`
- Create: `scripts/content/anomaly_definition.gd`
- Create: `scripts/content/content_definition_validator.gd`
- Create: `autoload/content_registry.gd`
- Create: `content/tokens/pulse_seed.tres`
- Create: `content/tokens/relay_prism.tres`
- Create: `content/tokens/hollow_shell.tres`
- Create: `content/tokens/anchor_glyph.tres`
- Create: `content/tokens/wild_signal.tres`
- Create: `content/tokens/twin_monolith.tres`
- Create: `docs/engineering/content-schema.md`
- Test: `tests/unit/core/test_content_registry.gd`
- Test: `tests/unit/core/test_content_definition_validator.gd`

- [x] **Step 1: 为资源注册写失败测试**

```gdscript
extends GutTest

func test_registry_loads_seed_tokens() -> void:
	var registry := ContentRegistry.new()
	registry.load_all()
	assert_eq(registry.tokens.size(), 6)
```

- [x] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_content_registry.gd -gexit
```

Expected: FAIL，`ContentRegistry` 或资源文件不存在。

- [x] **Step 3: 实现最小内容模型**
- `TokenDefinition` 至少包含 PRD 约束字段：`id/name/rarity/type/tags/base_value/trigger_rules/state_fields/spawn_rules/remove_rules`
- `EventDefinition` 至少包含：`id/name/type/tags_affected/duration/contract_template/reward_bundle/penalty_bundle`
- `HeroDefinition` 至少包含：`id/name/starting_passive/attribute_bias/event_weight_modifiers`
- `ContentRegistry` 负责扫描 `content/` 下资源并建立索引
- `ContentDefinitionValidator` 在加载时检查核心字段完整性，至少覆盖：
  - `id` 非空
  - `id` 全局唯一
  - 必填枚举字段合法
  - 关键数组字段非 `null`
- `docs/engineering/content-schema.md` 必须补充 Resource 命名与重命名规范，避免 `.tres` 因脚本字段改名静默丢数

- [x] **Step 4: 补齐首批样例资源并让测试通过**
- 增加字段完整性与坏数据拒载测试

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_content_registry.gd -gexit
```

Expected: PASS，且日志显示成功加载 6 个基础 Token 原型

- [x] **Step 5: Commit**

```powershell
git add scripts/content autoload/content_registry.gd content docs/engineering/content-schema.md tests/unit/core/test_content_registry.gd tests/unit/core/test_content_definition_validator.gd
git commit -m "feat: add content schema and registry"
```

### Task 3: Build Deterministic Board Model And Trigger Scanner

**Files:**
- Create: `scripts/core/value_objects/board_pos.gd`
- Create: `scripts/core/value_objects/token_instance.gd`
- Create: `scripts/core/services/board_service.gd`
- Create: `scripts/core/services/trigger_scanner.gd`
- Test: `tests/unit/core/test_board_service.gd`
- Test: `tests/unit/core/test_trigger_scanner.gd`

- [x] **Step 1: 先写棋盘与邻接扫描失败测试**

```gdscript
extends GutTest

func test_cardinal_neighbors_on_5x5_board() -> void:
	var board := BoardService.new(5, 5)
	assert_eq(board.get_neighbors(Vector2i(2, 2)).size(), 4)
```

- [x] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_board_service.gd -gexit
```

Expected: FAIL，`BoardService` 未实现。

- [x] **Step 3: 实现确定性棋盘层**
- `BoardService` 只负责坐标、占格、放置、删除、替换、快照
- `TriggerScanner` 只负责：
  - 四向相邻
  - 行列范围
  - 标签统计
  - 条件触发输入上下文
- 不允许把分数计算写进扫描器

- [x] **Step 4: 增加边界与占格测试并跑通**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/core -ginclude_subdirs -gexit
```

Expected: `BoardService` / `TriggerScanner` 相关测试全部 PASS

- [x] **Step 5: Commit**

```powershell
git add scripts/core/value_objects scripts/core/services tests/unit/core
git commit -m "feat: add deterministic board model and trigger scanner"
```

### Task 4: Implement Settlement Pipeline

**Files:**
- Create: `scripts/core/value_objects/settlement_step.gd`
- Create: `scripts/core/value_objects/run_snapshot.gd`
- Create: `scripts/core/value_objects/settlement_report.gd`
- Create: `scripts/core/services/settlement_resolver.gd`
- Test: `tests/unit/core/test_settlement_resolver.gd`

- [x] **Step 1: 按 PRD 结算顺序写失败测试**

```gdscript
extends GutTest

func test_settlement_order_matches_prd() -> void:
	var resolver := SettlementResolver.new()
	var report := resolver.resolve(_fixture_snapshot())
	assert_eq(report.phases, [
		"base_output",
		"adjacency",
		"row_column",
		"conditional",
		"copy_amplify",
		"cleanup"
	])
```

- [x] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_settlement_resolver.gd -gexit
```

Expected: FAIL，`SettlementResolver` 未实现。

- [x] **Step 3: 实现最小结算解析器**
- 输入是不可变 `run_snapshot`
- 输出是结构化 `settlement_report`
- 每个 `settlement_step` 要记录：
  - `sequence_index`，用于严格回放顺序
  - 来源 Token
  - 触发阶段
  - 增减分
  - 目标 Token
  - 可视化文案 key
- `settlement_report` 额外记录：
  - phase 边界
  - 最终总分变化
  - 可供 UI 逐步消费的有序 step 列表
- `SettlementResolver` 必须加入硬保护：
  - `MAX_ITERATION_DEPTH`
  - `MAX_TRIGGER_COUNT_PER_TOKEN`
  - 超限后写入警告并安全终止本次结算
- 为复制、成长、次数上限留钩子

- [x] **Step 4: 加入回归测试**
- 覆盖：
  - 相邻优先于行列
  - 条件触发晚于行列
  - 复制类效果有每轮上限
  - 清理类效果最后执行
  - `sequence_index` 单调递增，满足 UI 回放
  - 循环触发场景会被 `MAX_ITERATION_DEPTH` 截断而非卡死

- [x] **Step 5: Commit**

```powershell
git add scripts/core/value_objects scripts/core/services/settlement_resolver.gd tests/unit/core/test_settlement_resolver.gd
git commit -m "feat: add deterministic settlement pipeline"
```

### Task 5: Implement Turn Loop And Reward Offers

**Files:**
- Create: `scripts/core/services/reward_offer_service.gd`
- Create: `autoload/run_session.gd`
- Create: `tests/unit/core/test_reward_offer_service.gd`
- Modify later: `content/tokens/*.tres`

- [x] **Step 1: 为三选一回合奖励写失败测试**

```gdscript
extends GutTest

func test_turn_offer_contains_add_remove_random() -> void:
	var offers := RewardOfferService.new().build_turn_offer(_fixture_run_state())
	assert_eq(offers.map(func(it): return it.kind), ["add_token", "remove_token", "random_token"])
```

- [x] **Step 2: 跑测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_reward_offer_service.gd -gexit
```

Expected: FAIL

- [x] **Step 3: 实现回合主循环**
- `RunSession` 维护：
  - 当前回合
  - 当前阶段目标
  - 当前分数
  - 操作历史
  - 活跃事件 / 契约 / 角色修正
- `RunSession`、`run_snapshot`、`token_instance` 在这一阶段就定义稳定的序列化边界：
  - `to_dict()`
  - `from_dict()`
  - `schema_version`
- `RewardOfferService` 固定输出：
  - 新 Token
  - 删除
  - 随机 Token
- 随机不直接从全池抽，必须经过 rarity / tag / phase 权重

- [x] **Step 4: 增加周期结算测试并跑通**
- 覆盖：
  - 每 `N` 轮触发目标检查
  - 不达标失败
  - 达标进入下一阶段
  - `to_dict()/from_dict()` 往返后运行态不变

- [x] **Step 5: Commit**

```powershell
git add autoload/run_session.gd scripts/core/services/reward_offer_service.gd tests/unit/core/test_reward_offer_service.gd
git commit -m "feat: add turn loop and reward offers"
```

### Task 6: Build Playable Board UI And Run Flow

**Files:**
- Create: `scenes/app/app_root.tscn`
- Create: `scenes/run/run_screen.tscn`
- Create: `scenes/run/board_grid.tscn`
- Create: `scenes/run/token_cell.tscn`
- Create: `scenes/run/turn_controls.tscn`
- Create: `scenes/run/settlement_log_panel.tscn`
- Create: `scripts/ui/run_screen.gd`
- Create: `tests/integration/test_run_screen_flow.gd`

- [x] **Step 1: 先写一个集成测试，验证主界面能展示 5x5 棋盘**

```gdscript
extends GutTest

func test_run_screen_builds_25_cells() -> void:
	var scene := load("res://scenes/run/run_screen.tscn").instantiate()
	add_child_autofree(scene)
	assert_eq(scene.get_node("%BoardGrid").get_child_count(), 25)
```

- [x] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: FAIL，场景或节点不存在。

- [x] **Step 3: 实现场景与状态联动**
- 用 `Godot State Charts` 管理：
  - `boot`
  - `player_turn`
  - `settling`
  - `offer_choice`
  - `event_draft`
  - `run_failed`
  - `run_cleared`
- 不用它管理 Token 内部效果
- UI 只订阅 `RunSession` 和 `settlement_report`
- UI 结算表现必须按 `settlement_report.steps` 的 `sequence_index` 逐条播放，而不是一次性跳总分

- [x] **Step 4: 补充交互回归测试**
- 覆盖：
  - 点击格子放置
  - 删除模式下删除
  - 结算后日志面板显示阶段顺序
  - 结算表现按序逐步推进，前一 step 未消费时不会提前播放后一 step

- [x] **Step 5: Commit**

```powershell
git add scenes scripts/ui tests/integration/test_run_screen_flow.gd
git commit -m "feat: add playable board ui and run flow"
```

### Task 7: Implement Event Draft And Risk Contract

**Files:**
- Create: `scripts/core/services/event_draft_service.gd`
- Create: `scripts/core/services/contract_service.gd`
- Create: `scenes/run/event_draft_panel.tscn`
- Create: `content/events/`
- Test: `tests/unit/core/test_event_draft_service.gd`
- Test: `tests/unit/core/test_contract_service.gd`

- [ ] **Step 1: 写失败测试，确保事件三选一按盘面标签加权**

```gdscript
extends GutTest

func test_event_draft_biases_towards_board_tags() -> void:
	var draft := EventDraftService.new(_fixture_registry()).build_offer(_grow_heavy_snapshot())
	assert_true(draft.options.any(func(event): return event.primary_tag == "Grow"))
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_event_draft_service.gd -gexit
```

Expected: FAIL

- [ ] **Step 3: 实现事件系统 MVP**
- 支持：
  - `instant`
  - `lasting`
  - `crisis`
- 每次 Draft 提供 3 选 1
- 至少 1 个稳健选项
- `ContractService` 负责：
  - 附加目标
  - 剩余轮次
  - 奖励
  - 失败惩罚
- 失败惩罚不能直接结束本局

- [ ] **Step 4: 做首批 12~15 个事件内容并跑通测试**
- 每类事件至少 4 个
- 覆盖 Grow / Break / Link / Guard / Wild 标签倾向

- [ ] **Step 5: Commit**

```powershell
git add scripts/core/services scenes/run/event_draft_panel.tscn content/events tests/unit/core
git commit -m "feat: add event draft and risk contracts"
```

### Task 8: Add Hero System And Difficulty Modifiers

**Files:**
- Modify: `scripts/content/hero_definition.gd`
- Create: `content/heroes/`
- Create: `content/difficulty/ascension_1.tres`
- Create: `content/difficulty/ascension_2.tres`
- Create: `content/difficulty/ascension_3.tres`
- Create: `tests/unit/core/test_hero_modifiers.gd`
- Create: `tests/unit/core/test_difficulty_modifiers.gd`

- [ ] **Step 1: 写失败测试，确认主角会影响事件权重或保底**

```gdscript
extends GutTest

func test_resolve_hero_reduces_crisis_penalty() -> void:
	var result := _apply_hero("resolve_specialist", _fixture_crisis_penalty())
	assert_lt(result.modified_penalty, result.base_penalty)
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_hero_modifiers.gd -gexit
```

Expected: FAIL

- [ ] **Step 3: 实现 3 名主角原型**
- `Insight` 倾向：提高信息质量与可见性
- `Resolve` 倾向：降低危机惩罚，强化保底稳定性
- `Flux` 倾向：提高随机收益与异常事件权重

- [ ] **Step 4: 接入 Ascension 1~3**
- 每层只增加 1~2 条明确修正
- 难度修正走数据层，不写死在 UI

- [ ] **Step 5: Commit**

```powershell
git add content/heroes content/difficulty scripts/content tests/unit/core
git commit -m "feat: add heroes and ascension modifiers"
```

### Task 9: Add Meta Progression And Save System

**Files:**
- Create: `autoload/save_service.gd`
- Create: `scripts/meta/meta_progression_service.gd`
- Create: `content/meta/`
- Create: `scenes/meta/meta_screen.tscn`
- Create: `tests/integration/test_meta_save_load.gd`
- Install later: `addons/locker/`

- [ ] **Step 1: 写失败测试，确认一次 run 结果能解锁局外节点**

```gdscript
extends GutTest

func test_win_result_unlocks_meta_node() -> void:
	var service := MetaProgressionService.new()
	service.apply_run_result(_fixture_win_result())
	assert_true(service.is_unlocked("hero_flux"))
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_meta_save_load.gd -gexit
```

Expected: FAIL

- [ ] **Step 3: 接入 Meta 与存档**
- 先做抽象接口 `SaveService`
- 若纯 JSON 存档已经足够，先自己实现极简版
- 当出现以下任一条件，再接入 `Locker`：
  - 多存档位
  - 存档版本迁移
  - 异步大数据写入
  - 难度/角色/解锁跨版本兼容

- [ ] **Step 4: 做存档回归测试**
- 覆盖：
  - 新档创建
  - Run 结束写回
  - 解锁节点保留
  - 版本号变更后的向前兼容

- [ ] **Step 5: Commit**

```powershell
git add autoload/save_service.gd scripts/meta scenes/meta content/meta tests/integration/test_meta_save_load.gd
git commit -m "feat: add meta progression and save flow"
```

### Task 10: Endless, Spatial Anomaly, And Balancing Pass

**Files:**
- Create: `scripts/core/services/endless_service.gd`
- Create: `content/anomalies/temporary_6x6.tres`
- Create: `content/anomalies/bonus_column.tres`
- Create: `content/anomalies/twin_slot_spawn.tres`
- Create: `scenes/endless/endless_summary_panel.tscn`
- Create: `docs/engineering/balance-checklist.md`
- Create: `tests/unit/core/test_endless_service.gd`
- Create: `tests/unit/core/test_anomaly_rules.gd`

- [ ] **Step 1: 写失败测试，确认 Endless 难度会继续抬升**

```gdscript
extends GutTest

func test_endless_target_increases_predictably() -> void:
	var service := EndlessService.new()
	assert_gt(service.get_target_for_loop(2), service.get_target_for_loop(1))
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_endless_service.gd -gexit
```

Expected: FAIL

- [ ] **Step 3: 实现后期系统**
- Endless：标准通关后沿用当前盘面继续抬压
- 异常事件：
  - 临时扩展列
  - `2x1` 双格 Token 原型
- 可选高光项：
  - 临时 `6x6`
- 所有异常规则必须走模块化声明，不污染基础 5x5 实现

- [ ] **Step 4: 做平衡专项回归**
- 覆盖：
  - 复制闭环上限
  - 永久成长上限
  - 危机事件保底路线
  - Wild Token 不成为所有流派通吃件
  - 多格 Token 不直接成为最优解

- [ ] **Step 5: Commit**

```powershell
git add scripts/core/services/endless_service.gd content/anomalies scenes/endless docs/engineering/balance-checklist.md tests/unit/core
git commit -m "feat: add endless mode anomalies and balancing safeguards"
```

## 4. Plugin Adoption Order

1. `GUT`
   - 第一时间接入
   - 用于规则层与界面流程回归
2. `Godot State Charts`
   - 在 Task 6 接入
   - 只用于 run 生命周期与界面状态流转
3. `Locker`
   - 在 Task 9 评估并决定是否接入
   - 若前期只有单存档与少量局外数据，不急着引入

## 5. Non-Goals During Prototype

- 不做复杂剧情系统
- 不做联网与排行榜
- 不做大规模换皮系统
- 不做超过 `2x1` 的复杂多格 Token
- 不在原型阶段引入过多 Editor 插件，避免项目骨架先被插件绑死

## 6. Verification Checklist Per Milestone

- Milestone 1 `Prototype`
  - 能完成 5x5 摆放、删除、随机奖励、固定结算
  - 至少 20 个 Token 可加载并参与结算
  - GUT 核心测试常驻通过
  - 结算报告可被 UI 逐步回放
- Milestone 2 `Vertical Slice`
  - Event Draft、Risk Contract、3 名主角原型可玩
  - 玩家失败原因可通过日志回看
  - 至少 4 条可成型构筑方向
- Milestone 3 `MVP`
  - Meta / Ascension 1~3 / Endless / 2~4 异常事件齐备
  - 单局时长验证在 10~25 分钟
  - 核心系统均可通过数据资源扩展
  - `6x6` 只在不破坏稳定性的前提下进入版本

## 7. Execution Notes

- 先做 Task 1~4，形成“可测试结算核心”
- 再做 Task 5~7，形成“可玩的局内循环”
- 最后做 Task 8~10，补齐角色、局外、后期系统
- 任意时刻若插件开始反向限制玩法结构，应立即退回原生实现
