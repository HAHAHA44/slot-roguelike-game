# Bag-Roll Core Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current manual-placement default loop with the real bag-roll core loop while keeping the branch playable after every task.

**Architecture:** The default player path becomes `reward_choice -> event_draft -> roll_board -> settling -> settlement_result -> reward_choice`. `RunSession` owns persistent run state, `BoardRollService` owns per-round board generation from a concrete token multiset, and `RunScreen` becomes an orchestration layer. Manual placement survives only as a debug or future ability side path.

**Tech Stack:** Godot 4.6.1-stable, GDScript, GUT, Godot State Charts

---

## 1. Working File Map

### New Files
- Create: `scripts/core/services/board_roll_service.gd`
- Create: `tests/unit/core/test_board_roll_service.gd`
- Create: `content/tokens/empty_token.tres`

### Existing Files To Modify
- Modify: `autoload/run_session.gd`
- Modify: `scripts/core/services/reward_offer_service.gd`
- Modify: `scripts/core/services/contract_service.gd`
- Modify: `scripts/core/services/settlement_resolver.gd`
- Modify: `scripts/core/services/trigger_scanner.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `scenes/run/run_screen.tscn`
- Modify: `tests/integration/test_run_screen_flow.gd`
- Modify: `tests/unit/core/test_reward_offer_service.gd`
- Modify: `tests/unit/core/test_contract_service.gd`
- Modify: `README.md`
- Modify: `docs/engineering/content-schema.md`

## 2. Scope

### In Scope
- Persistent `token_pool` becomes a concrete multiset
- Empty token is a real token definition and is injected before each round roll
- Board generation becomes whole-board shuffle and fill
- Default loop uses next-turn arrow plus auto settlement
- Reward semantics change from "next placement token" to persistent pool mutation
- Manual placement is retained only as debug / future ability scaffolding

### Out Of Scope
- Implementing swap / lock / reroll abilities
- Major visual redesign
- Full checkpoint / clear / endless overhaul in the same change set
- Reworking every settlement rule beyond what is needed to support the corrected loop

## 3. Delivery Rules

### Playable-First Rule
- Every task must leave one playable mainline path:
  - finish reward / event
  - trigger next turn
  - auto roll a board
  - auto settle
  - reach settlement result
  - continue to reward
- Debug placement may remain available, but the default path must progressively move to bag-roll.

### Verification Rule
- Use TDD for each task.
- Before each commit, run the targeted tests for that task and the `run_screen` integration flow.
- If GUT again runs the whole suite instead of the requested file, record the whole-suite result and continue only if it is green.

## 4. Acceptance Criteria

- `token_pool` stores concrete entries, not a "next token" pointer
- Empty tokens are added before each round until board capacity is reached
- The board is fully regenerated every round from a shuffled 25-entry round pool
- Default player flow no longer depends on manual placement or manual settle
- Reward choices mutate the persistent pool and affect the next rolled board
- Contracts continue to advance and resolve correctly in the new loop
- Manual placement still exists only as debug / ability scaffolding

## 5. Implementation Tasks

### Task 1: Introduce Empty Token And Whole-Board Roll Service

**Files:**
- Create: `content/tokens/empty_token.tres`
- Create: `scripts/core/services/board_roll_service.gd`
- Create: `tests/unit/core/test_board_roll_service.gd`
- Modify: `autoload/run_session.gd`

- [ ] **Step 1: Write the failing board-roll tests**

```gdscript
extends GutTest

func test_round_pool_is_filled_with_empty_tokens_to_board_capacity() -> void:
	var service := BoardRollService.new()
	var rolled := service.build_round_pool(["pulse_seed", "relay_prism"], 25, "empty_token", RandomNumberGenerator.new())
	assert_eq(rolled.size(), 25)
	assert_eq(rolled.count("empty_token"), 23)

func test_board_roll_preserves_exact_token_counts() -> void:
	var service := BoardRollService.new()
	var rolled := service.build_round_pool(["pulse_seed", "pulse_seed", "relay_prism"], 5, "empty_token", RandomNumberGenerator.new())
	assert_eq(rolled.count("pulse_seed"), 2)
	assert_eq(rolled.count("relay_prism"), 1)
	assert_eq(rolled.count("empty_token"), 2)
```

- [ ] **Step 2: Run the test to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_board_roll_service.gd -gexit
```

Expected: FAIL because the service and empty token do not exist yet.

- [ ] **Step 3: Implement empty token content and `BoardRollService`**

- `empty_token.tres` must be a formal token definition
- `BoardRollService` must:
  - accept a concrete pool array
  - append empty tokens until board capacity
  - shuffle the resulting round pool
  - expose a helper that can translate the round pool into board positions

- [ ] **Step 4: Extend `RunSession` to own a persistent concrete `token_pool`**

- Replace the current "next placement token" mental model
- Add helpers for:
  - pool mutation
  - pool serialization
  - safe defaults for legacy saves

- [ ] **Step 5: Re-run tests and commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_board_roll_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS, and the old debug flow is still intact.

```powershell
git add content/tokens/empty_token.tres scripts/core/services/board_roll_service.gd tests/unit/core/test_board_roll_service.gd autoload/run_session.gd
git commit -m "feat: add bag-roll service and empty token support"
```

### Task 2: Add The New Mainline Turn States

**Files:**
- Modify: `scripts/ui/run_screen.gd`
- Modify: `scenes/run/run_screen.tscn`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [ ] **Step 1: Write the failing integration test for next-turn arrow to settlement result**

```gdscript
func test_next_turn_arrow_rolls_board_and_stops_on_settlement_result() -> void:
	var scene = await _spawn_run_screen()
	scene.debug_force_reward_event_complete()
	scene.get_node("%NextTurnButton").emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	assert_eq(scene.get_board_token_count(), 25)
```

- [ ] **Step 2: Run the integration test to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: FAIL because the default mainline states do not exist yet.

- [ ] **Step 3: Add `roll_board` and `settlement_result` states to `RunScreen`**

- `roll_board` must:
  - consume the persistent pool
  - ask `BoardRollService` for a round board
  - build the board UI
  - transition immediately to settlement
- `settlement_result` must:
  - hold after auto settlement
  - expose a button that enters reward

- [ ] **Step 4: Add the next-turn arrow and result-to-reward button to the scene**

- Keep existing debug controls present but visually or logically separate from the default mainline

- [ ] **Step 5: Re-run integration flow and commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS, and the default path becomes reward/event -> next turn -> auto settlement -> settlement result.

```powershell
git add scripts/ui/run_screen.gd scenes/run/run_screen.tscn tests/integration/test_run_screen_flow.gd
git commit -m "feat: add bag-roll mainline turn states"
```

### Task 3: Rebind Reward Semantics To Persistent Pool Mutation

**Files:**
- Modify: `scripts/core/services/reward_offer_service.gd`
- Modify: `autoload/run_session.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `tests/unit/core/test_reward_offer_service.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [ ] **Step 1: Write failing tests for reward changing the persistent pool**

```gdscript
func test_add_token_reward_appends_a_real_token_to_pool() -> void:
	var session := RunSession.new()
	var registry := ContentRegistry.new()
	registry.load_all()
	var offers := RewardOfferService.new().build_turn_offer(session, registry)
	var result := RewardOfferService.new().apply_offer(session, offers[0])
	assert_gt(session.token_pool.size(), 0)
	assert_true(result["changed"])
```

- [ ] **Step 2: Run targeted tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_reward_offer_service.gd -gexit
```

Expected: FAIL because reward logic still assumes "next placement token".

- [ ] **Step 3: Update reward application**

- `add_token` and `random_token` must append concrete entries to the persistent pool
- `remove_token` must remove an entry from the persistent pool, not from the current board
- the next rolled board must reflect the changed pool

- [ ] **Step 4: Update integration flow to verify next-round effect**

- The integration test must assert the changed pool affects the next rolled board, not a manual placement action

- [ ] **Step 5: Re-run tests and commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_reward_offer_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS.

```powershell
git add scripts/core/services/reward_offer_service.gd autoload/run_session.gd scripts/ui/run_screen.gd tests/unit/core/test_reward_offer_service.gd tests/integration/test_run_screen_flow.gd
git commit -m "feat: make rewards mutate the persistent bag-roll pool"
```

### Task 4: Adapt Contract Progress To The New Round Model

**Files:**
- Modify: `scripts/core/services/contract_service.gd`
- Modify: `scripts/ui/run_screen.gd`
- Modify: `tests/unit/core/test_contract_service.gd`
- Modify: `tests/integration/test_run_screen_flow.gd`

- [ ] **Step 1: Write failing tests for contract progress after a rolled round**

```gdscript
func test_contract_ticks_after_a_completed_rolled_round() -> void:
	var scene = await _spawn_run_screen()
	scene.debug_force_active_contract()
	scene.get_node("%NextTurnButton").emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	assert_eq(scene.get_active_contract_data()["turns_remaining"], 2)
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_contract_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: FAIL because contract tests still assume the old manual-turn model.

- [ ] **Step 3: Rewire contract advancement to settlement-result completion**

- advance contracts from the rolled round score
- keep the current success/failure semantics
- make the contract summary visible on the settlement-result page

- [ ] **Step 4: Re-run tests and commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_contract_service.gd -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS.

```powershell
git add scripts/core/services/contract_service.gd scripts/ui/run_screen.gd tests/unit/core/test_contract_service.gd tests/integration/test_run_screen_flow.gd
git commit -m "feat: adapt contracts to bag-roll rounds"
```

### Task 5: Demote Manual Placement To Debug / Ability Scaffolding

**Files:**
- Modify: `scripts/ui/run_screen.gd`
- Modify: `scenes/run/run_screen.tscn`
- Modify: `README.md`

- [ ] **Step 1: Add a failing integration assertion that the mainline path no longer depends on manual placement**

```gdscript
func test_mainline_round_progresses_without_manual_place_or_settle() -> void:
	var scene = await _spawn_run_screen()
	scene.complete_reward_event_for_test()
	scene.get_node("%NextTurnButton").emit_signal("pressed")
	await _wait_for_state(scene, "settlement_result")
	assert_true(true)
```

- [ ] **Step 2: Run the integration test to verify failure or incompleteness**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: FAIL or expose that mainline still depends on manual controls.

- [ ] **Step 3: Gate manual controls behind debug / ability scaffolding**

- keep the code
- remove them from the default loop
- label them clearly in code and, if still visible, in UI

- [ ] **Step 4: Update README and commit**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

Expected: PASS.

```powershell
git add scripts/ui/run_screen.gd scenes/run/run_screen.tscn README.md
git commit -m "chore: demote manual placement to debug scaffolding"
```

### Task 6: Sync Architecture Docs With The Correct Loop

**Files:**
- Modify: `docs/engineering/content-schema.md`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-03-24-honest-vertical-slice-plan.md`

- [ ] **Step 1: Write doc updates for the bag-roll loop**

- describe empty token as formal content
- describe persistent pool vs. per-round board
- describe default auto-roll / auto-settle flow

- [ ] **Step 2: Re-read the spec and docs side-by-side**

Check:

- spec: `docs/superpowers/specs/2026-03-25-bag-roll-core-loop-design.md`
- plan: this file
- engineering docs: `docs/engineering/content-schema.md`

- [ ] **Step 3: Commit**

```powershell
git add docs/engineering/content-schema.md README.md docs/superpowers/plans/2026-03-24-honest-vertical-slice-plan.md docs/superpowers/plans/2026-03-25-bag-roll-core-loop-plan.md
git commit -m "docs: align plans and architecture with bag-roll loop"
```
