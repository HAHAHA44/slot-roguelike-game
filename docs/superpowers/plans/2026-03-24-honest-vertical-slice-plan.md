# Playable Honest Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前 Reelbound 原型收敛为“可实际游玩、规则真实、主循环闭环、可验证”的 Vertical Slice，并确保每个任务完成后游戏仍可启动和游玩。

**Architecture:** 保持“纯服务层决定规则，UI 只消费结果”的方向不变，但实现顺序改为 playable-first。所有改动都必须以“保留一条可运行、可操作、可结算的主线”为前提，优先采用兼容层、渐进替换和 smoke test 护栏，避免在中间任务中把当前可玩原型拆散。

**Tech Stack:** Godot 4.6.1-stable, GDScript, GUT, Godot State Charts

**Execution Status (2026-03-25):**
- Task 0 is complete.
- The settlement autoplay gap is closed, so `Settle -> offer -> event -> next turn` is now playable.
- Task 3A reward mutation is complete.
- Task 3B contract lifecycle is complete.
- The next planned implementation step after this document update is Task 4.

---

## 1. Working File Map

### New Files
- Create: `scripts/core/services/run_snapshot_builder.gd`
- Create: `scripts/core/services/run_progression_service.gd`
- Create: `tests/unit/core/test_run_snapshot_builder.gd`
- Create: `tests/unit/core/test_run_progression_service.gd`

### Existing Files To Modify
- Modify: `scripts/core/services/trigger_scanner.gd`
- Modify: `scripts/core/services/settlement_resolver.gd`
- Modify: `scripts/core/services/reward_offer_service.gd`
- Modify: `scripts/core/services/event_draft_service.gd`
- Modify: `scripts/core/services/contract_service.gd`
- Modify: `scripts/core/services/run_modifier_service.gd`
- Modify: `scripts/core/services/endless_service.gd`
- Modify: `autoload/run_session.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `scenes/run/run_screen.tscn`
- Modify: `scenes/endless/endless_summary_panel.tscn`
- Modify: `tests/unit/core/test_trigger_scanner.gd`
- Modify: `tests/unit/core/test_settlement_resolver.gd`
- Modify: `tests/unit/core/test_reward_offer_service.gd`
- Modify: `tests/unit/core/test_event_draft_service.gd`
- Modify: `tests/unit/core/test_contract_service.gd`
- Modify: `tests/unit/core/test_difficulty_modifiers.gd`
- Modify: `tests/unit/core/test_endless_service.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`
- Modify: `README.md`
- Modify: `docs/engineering/content-schema.md`

## 2. Scope

### In Scope
- 用真实棋盘与 Token 数据构造 `RunSnapshot`
- 让结算结果来自规则，而不是 UI 伪造
- 接入真实 reward offer、contract 生命周期、checkpoint 判定
- 接入失败、标准通关和 Endless 入口
- 修正 hero / difficulty / event draft 的权重联动
- 用单元测试和集成测试覆盖新闭环

### Out Of Scope
- 大规模内容扩容
- 新的 Meta progression 流程
- Save/Load 深度整合
- 美术和动效升级
- 超过当前资源池所需的复杂多格规则扩展

## 3. Delivery Rules

### Playable-First Rule
- 每个任务结束时，游戏必须仍然可启动，并能进入主运行界面
- 每个任务结束时，玩家至少还能完成一条基础游玩路径：
  - 进入 `RunScreen`
  - 放置 Token
  - 触发结算
  - 看到 reward / event 流程中的下一步
- 不允许出现“测试更对了，但当前构建无法实际游玩”的长时间中间态

### Allowed Temporary Red State
- 单个任务内部允许短暂出现 failing test
- 但在任务结束、提交前，必须恢复到：
  - targeted tests 通过
  - playable smoke flow 通过

### Required Smoke Check After Every Task
- 启动主场景
- 完成一次最小操作链：
  - 放置至少 1 个 Token
  - 触发一次结算
  - 进入下一步 UI 状态
- 如果某任务修改了 checkpoint / fail / clear / endless，也必须额外验证对应状态至少 1 条主路径

## 4. Acceptance Criteria

- 放置后的结算结果来自 `BoardService + TriggerScanner + ContentRegistry`，不再由 `RunScreen` 直接伪造数值
- 选择 `add_token / remove_token / random_token` 会真实改变当前 run
- Contract 具备倒计时、成功、失败、奖励与惩罚执行
- 每 `N` 轮触发 checkpoint，并能产生 `advance / failed / cleared / endless` 结果
- Ascension 会真实影响 draft，Hero 会真实影响契约或标签权重
- `RunScreen` 集成测试可以覆盖一条完整的“放置 -> 结算 -> 领奖励 -> 事件 -> 合约推进 -> checkpoint -> fail/clear”流程
- 每个任务完成后都保留一条可启动、可操作、可结算的可玩路径

## 5. Implementation Tasks

### Task 0: Add Playability Guardrails Before Replacing Core Logic

**Files:**
- Modify: `tests/integration/test_run_screen_flow.gd`
- Modify: `README.md`

- [x] **Step 1: Add a dedicated smoke-path integration test that represents “the game is still playable”**

```gdscript
func test_smoke_playable_path_still_works() -> void:
	var scene = await _spawn_run_screen()
	if scene == null:
		return

	var board_grid: Node = scene.get_node("%BoardGrid")
	var settle_button := scene.get_node("MainMargin/MainLayout/ContentRow/Sidebar/TurnControls/SettleButton") as Button

	var cell := board_grid.get_child(0) as Button
	cell.emit_signal("pressed")
	settle_button.emit_signal("pressed")

	assert_true(scene.get_active_state_name() in ["settling", "offer_choice", "event_draft", "player_turn"])
```

- [x] **Step 2: Run the smoke test and verify the current build passes it**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS on the existing prototype before deeper refactors begin.

- [x] **Step 3: Update `README.md` with a short “playable smoke check” section**

- Add:
  - unit test command
  - integration test command
  - short note that every task in this phase must keep the smoke path green

- [x] **Step 4: Re-run the smoke test after doc edits**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS.

- [x] **Step 5: Commit**

```powershell
git add tests/integration/test_run_screen_flow.gd README.md
git commit -m "test: add playable smoke guardrail for vertical slice work"
```

### Task 1: Replace Synthetic Snapshot Assembly With A Real Board Snapshot Builder

**Files:**
- Create: `scripts/core/services/run_snapshot_builder.gd`
- Modify: `scripts/core/services/trigger_scanner.gd`
- Modify: `scripts/ui/run_screen.gd`
- Create: `tests/unit/core/test_run_snapshot_builder.gd`
- Modify: `tests/unit/core/test_trigger_scanner.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [ ] **Step 1: Write the failing snapshot-builder tests**

```gdscript
extends GutTest

func test_builder_emits_board_tags_and_phase_effects() -> void:
	var board := BoardService.new(5, 5)
	board.place_token(Vector2i(0, 0), TokenInstance.new("pulse_seed", PackedStringArray(["Grow", "Charge"])))
	board.place_token(Vector2i(1, 0), TokenInstance.new("anchor_glyph", PackedStringArray(["Guard"])))

	var builder := RunSnapshotBuilder.new()
	var snapshot := builder.build(board, {})

	assert_eq(snapshot.phase_effects["board_tags"]["Grow"], 1)
	assert_true(snapshot.phase_effects.has("base_output"))
	assert_true(snapshot.phase_effects.has("adjacency"))
```

- [ ] **Step 2: Run targeted tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_run_snapshot_builder.gd -gexit
```

Expected: FAIL because `RunSnapshotBuilder` does not exist yet.

- [ ] **Step 3: Implement `RunSnapshotBuilder` and extend `TriggerScanner` behind a compatible path**

- `RunSnapshotBuilder` responsibilities:
  - read all occupied cells from `BoardService`
  - build `board_tags`
  - emit deterministic phase buckets for `base_output / adjacency / row_column / conditional / cleanup`
- `TriggerScanner` responsibilities:
  - expose neighbor, row, column, tag-count helpers
  - return plain data structures usable by tests and services
- Important rule:
  - unsupported token rule = explicit no-op
  - never fabricate score just to keep UI moving

- [ ] **Step 4: Wire `RunScreen` to call the builder without breaking the existing playable path**

- Keep settlement playback UI unchanged
- If some token rule is still unsupported, fall back to deterministic no-op effects, not broken transitions
- Replace the placeholder assembly path only when the smoke test still passes

- [ ] **Step 5: Re-run unit tests plus the playable smoke flow, then commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_run_snapshot_builder.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS, and the game remains launchable and playable after the snapshot swap.

```powershell
git add scripts/core/services/run_snapshot_builder.gd scripts/core/services/trigger_scanner.gd scripts/ui/run_screen.gd tests/unit/core/test_run_snapshot_builder.gd tests/unit/core/test_trigger_scanner.gd tests/integration/test_run_screen_flow.gd
git commit -m "feat: replace synthetic snapshot assembly with board-driven builder"
```

### Task 2: Add Deterministic Run Progression And Checkpoint Resolution

**Files:**
- Create: `scripts/core/services/run_progression_service.gd`
- Modify: `autoload/run_session.gd`
- Modify: `scripts/core/services/endless_service.gd`
- Create: `tests/unit/core/test_run_progression_service.gd`
- Modify: `tests/unit/core/test_endless_service.gd`

- [ ] **Step 1: Write failing tests for phase checkpoint outcomes**

```gdscript
extends GutTest

func test_checkpoint_failure_when_score_below_target() -> void:
	var service := RunProgressionService.new()
	var result := service.resolve_checkpoint({
		"current_score": 8,
		"phase_target": 10,
		"phase_index": 0,
		"cleared_phases": 0,
	})

	assert_eq(result["outcome"], "failed")
```

- [ ] **Step 2: Run targeted tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_run_progression_service.gd -gexit
```

Expected: FAIL because `RunProgressionService` does not exist yet.

- [ ] **Step 3: Implement `RunProgressionService` and extend `RunSession` without forcing a hard cutover**

- Add to `RunSession`:
  - `turns_per_checkpoint`
  - `cleared_phases`
  - `is_endless`
  - `run_outcome`
- `RunProgressionService` must answer:
  - whether current turn is a checkpoint
  - whether run failed
  - whether phase advanced
  - whether standard clear happened
  - whether endless should begin
- Keep existing non-checkpoint turns flowing exactly as before until checkpoint integration is green

- [ ] **Step 4: Update `EndlessService` to take the handoff from a standard clear instead of existing as an isolated helper**

- Ensure loop target generation is driven by a `loop_index`
- Keep anomaly application deterministic and data-only

- [ ] **Step 5: Re-run progression tests plus the playable smoke flow, then commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_run_progression_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_endless_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS, including failure / advance / clear / endless handoff cases, while the baseline playable path still works.

```powershell
git add scripts/core/services/run_progression_service.gd autoload/run_session.gd scripts/core/services/endless_service.gd tests/unit/core/test_run_progression_service.gd tests/unit/core/test_endless_service.gd
git commit -m "feat: add deterministic checkpoint progression and endless handoff"
```

### Task 3A: Make Reward Offers Mutate Real Run State

**Files:**
- Modify: `scripts/core/services/reward_offer_service.gd`
- Modify: `autoload/run_session.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `tests/unit/core/test_reward_offer_service.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [x] **Step 1: Write failing tests for reward application**

```gdscript
extends GutTest

func test_random_offer_returns_a_real_token_candidate() -> void:
	var offers := RewardOfferService.new().build_turn_offer(RunSession.new(), ContentRegistry.new())
	assert_true(offers[2].has("token_candidates"))
```

- [x] **Step 2: Run targeted tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_reward_offer_service.gd -gexit
```

Expected: FAIL because offers do not include real content yet.

- [x] **Step 3: Implement reward resolution in an additive order**

- `RewardOfferService` must:
  - accept `ContentRegistry`
  - pick concrete token candidates
  - preserve the fixed three-choice shape
- `RunScreen` must:
  - apply chosen reward
  - mutate session state in a player-visible way
  - keep at least one safe reward path usable even before richer reward logic is complete
- Playable constraint for this step:
  - reward selection changes the active placement token
  - the next placement after the event flow must reflect the rewarded token
  - the turn loop must remain `settle -> offer -> event -> player_turn`

**Exit condition for Task 3A:** PASS, and the integration flow shows reward selection changing actual run state without breaking the smoke path.

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_reward_offer_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

### Task 3B: Implement Contract Lifecycle

**Files:**
- Modify: `scripts/core/services/contract_service.gd`
- Modify: `autoload/run_session.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `tests/unit/core/test_contract_service.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [x] **Step 1: Write failing tests for contract advancement**

```gdscript
extends GutTest

func test_contract_turns_tick_down_and_fail_cleanly() -> void:
	var service := ContractService.new()
	var contract := service.build_contract({
		"id": "grow_surge",
		"contract_template": {"goal_type": "reach_score", "goal_value": 12, "turns_remaining": 2},
		"reward_bundle": {"score_bonus": 4},
		"penalty_bundle": {"score_penalty": 2},
	})
	var advanced := service.advance_contract(contract, {"score_gained": 3})
	assert_eq(advanced["turns_remaining"], 1)
```

- [x] **Step 2: Run targeted tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_contract_service.gd -gexit
```

Expected: FAIL because contracts do not advance yet.

- [x] **Step 3: Implement contract lifecycle**

- `ContractService` must support:
  - `advance_contract()`
  - `resolve_contract_success()`
  - `resolve_contract_failure()`
- Failure cannot instantly end the run unless explicitly configured
- Reward and penalty execution must be deterministic and testable
- If a contract is unsupported in a given intermediate build, it must degrade to a safe no-op summary instead of breaking the turn loop

- [x] **Step 4: Re-run contract/reward tests plus the playable smoke flow, then commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_reward_offer_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_contract_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS, and the integration flow keeps reward mutation while contracts also advance cleanly.

```powershell
git add scripts/core/services/contract_service.gd scripts/ui/run_screen.gd tests/unit/core/test_contract_service.gd tests/integration/test_run_screen_flow.gd docs/superpowers/plans/2026-03-24-honest-vertical-slice-plan.md
git commit -m "feat: add contract lifecycle to playable run loop"
```

### Task 4: Fix Hero / Difficulty / Event Draft Integration And Close The Main Loop

**Files:**
- Modify: `scripts/core/services/event_draft_service.gd`
- Modify: `scripts/core/services/run_modifier_service.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `scenes/run/run_screen.tscn`
- Modify: `scenes/endless/endless_summary_panel.tscn`
- Modify: `tests/unit/core/test_event_draft_service.gd`
- Modify: `tests/unit/core/test_difficulty_modifiers.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [ ] **Step 1: Write failing tests for difficulty-aware event draft and run clear/endless entry**

```gdscript
extends GutTest

func test_ascension_biases_crisis_events_in_draft() -> void:
	var service := EventDraftService.new(_fixture_registry())
	var draft := service.build_offer(_fixture_snapshot(), {}, {"crisis_weight_bonus": 1.0})
	assert_true(draft["options"].any(func(event): return event.get("type", "") == "crisis"))
```

- [ ] **Step 2: Run targeted tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_event_draft_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: FAIL because difficulty semantics do not currently line up with draft scoring, and the UI loop does not yet close into fail/clear/endless.

- [ ] **Step 3: Normalize modifier semantics**

- `RunModifierService` should return one consistent modifier shape for:
  - tag bias
  - event type bias
  - stability bias
  - penalty multipliers
- `EventDraftService` should score against that unified shape instead of mixing unrelated key names

- [ ] **Step 4: Close the UI loop while preserving a playable happy path**

- `RunScreen` must:
  - check checkpoint outcome after settlement
  - enter `run_failed` on failure
  - enter `run_cleared` on standard clear
  - show endless summary and continue with `EndlessService` after clear
- Keep state-chart transitions explicit and testable
- Do not gate the only playable path behind unfinished endless or checkpoint UX

- [ ] **Step 5: Re-run draft tests, checkpoint flow tests, and the playable smoke flow, then commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_event_draft_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_difficulty_modifiers.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS, including a real fail or clear path through the run-state chart, while the normal turn loop still feels playable.

```powershell
git add scripts/core/services/event_draft_service.gd scripts/core/services/run_modifier_service.gd scripts/ui/run_screen.gd scenes/run/run_screen.tscn scenes/endless/endless_summary_panel.tscn tests/unit/core/test_event_draft_service.gd tests/unit/core/test_difficulty_modifiers.gd tests/integration/test_run_screen_flow.gd
git commit -m "feat: fix draft modifiers and close the main run loop"
```

### Task 5: Align Documentation With The Real Architecture And Test Flow

**Files:**
- Modify: `README.md`
- Modify: `docs/engineering/content-schema.md`
- Modify: `docs/status/2026-03-24-stage-report.md`

- [ ] **Step 1: Write a failing documentation checklist in the task notes**

Checklist:
- README explains how to run unit and integration tests
- Content schema reflects actual `EventDefinition` fields
- Stage report can be updated from “Early Vertical Slice” to “Vertical Slice” only if acceptance criteria are met

- [ ] **Step 2: Verify the current docs are stale before editing**

- Confirm `README.md` only documents unit test command
- Confirm `content-schema.md` omits `primary_tag / stability / weight / description`
- Confirm stage report lists the now-resolved gaps

- [ ] **Step 3: Update docs after code lands**

- `README.md`:
  - add unit and integration test commands
  - add playable smoke check command
  - add short gameplay loop description
- `content-schema.md`:
  - document actual event fields
  - document registry behavior truthfully
- `stage-report.md`:
  - update status and resolved issues

- [ ] **Step 4: Run the relevant tests one more time after doc-adjacent refactors**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/core -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
```

Expected: PASS, with docs now describing the code that actually exists.

- [ ] **Step 5: Commit**

```powershell
git add README.md docs/engineering/content-schema.md docs/status/2026-03-24-stage-report.md
git commit -m "docs: align architecture and testing docs with vertical slice loop"
```

## 6. Verification Checklist For This Phase

- Settlement no longer depends on hardcoded per-slot synthetic values
- Reward offer selection mutates real run state
- Contracts tick, resolve, and apply consequences
- Checkpoints can fail, advance, clear, and enter endless
- Difficulty changes actual event draft outcomes
- Integration test covers at least one full honest loop
- Docs describe the real architecture instead of the aspirational one
- After every task, the game still boots and supports one minimal playable path

## 7. Execution Notes

- Do not expand the content pool until Task 1 through Task 4 are stable
- Prefer adding focused services over pushing more flow logic into `RunScreen`
- Keep unsupported token rules explicit and deterministic; do not reintroduce fake score placeholders
- Preserve the PRD-required fixed phase order even if a phase has zero effects
- If a refactor risks breaking the only playable path, stage it behind a compatibility layer and remove the old path only after the smoke flow is green
