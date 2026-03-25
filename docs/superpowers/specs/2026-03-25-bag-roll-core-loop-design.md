# Bag-Roll Core Loop Design

Date: 2026-03-25
Status: Draft for review
Scope: Replace the current manual-placement default loop with the real bag-roll loop while preserving debug/manual controls as a side path.

## 1. Problem Statement

The current playable slice still treats token placement as the default player action. That model is wrong for the intended game.

The actual baseline loop is:

1. Reward and event resolution finish.
2. The player clicks a next-turn arrow button.
3. The game fills the token pool to 25 entries using empty tokens.
4. The 25 entries are shuffled and laid out across the whole board.
5. Settlement runs automatically.
6. The game pauses on a settlement-result page.
7. The player clicks through to the next reward page.

Manual placement is not the default gameplay. It should survive only as:

- a debug/development path
- a future extensibility path for limited intervention abilities

This design corrects the core loop without throwing away the current playable branch.

## 2. Player-Facing Goals

The player experience for the baseline mode should be:

- The board is rebuilt every round from the current pool.
- The player does not manually place all tokens.
- Rewards and events matter because they change future rounds, not a single next placement.
- Contracts create pressure across rounds and resolve from real scored turns.
- The game has a clear cadence:
  - result
  - reward
  - event
  - next-turn arrow
  - board roll
  - auto settlement
  - result

The design must also preserve room for future player intervention such as:

- swap
- lock
- partial reroll
- limited manual placement abilities

These abilities are not part of the baseline implementation for this step.

## 3. Core Rules

### 3.1 Token Pool Model

`token_pool` is a multiset represented as concrete entries, not weights.

Example:

- `pulse_seed`
- `pulse_seed`
- `relay_prism`
- `empty`
- `empty`

Each entry represents one real token copy that can appear on the board for that round.

This is explicitly not a weighted random draw model.

### 3.2 Empty Token Model

The empty token is a formal token entry.

Rules:

- it is added before each round if the pool has fewer than 25 entries
- it participates in shuffle and placement like every other token
- it participates in settlement
- it should therefore exist as a normal content definition or a special-case token definition with explicit rule behavior

The empty token is not just an unoccupied cell marker.

### 3.3 Round Generation Model

At round start:

1. Read the persistent `token_pool`.
2. Create a temporary round pool.
3. Add empty tokens until the round pool length is 25.
4. Shuffle the 25 concrete entries.
5. Fill the full board from that shuffled pool.

The board is fully regenerated every round. Tokens do not persist on the board across rounds.

### 3.4 Reward Timing

Rewards and events apply immediately after the current round finishes and before the next round is rolled.

That means a reward changes the persistent pool and therefore affects the next 25-entry round pool.

### 3.5 Contract Timing

Contracts are long-lived run state. They are not tied to a single board instance.

Each round:

- the board is generated
- settlement runs
- contract progress advances from that round result
- if resolved, reward or penalty is applied

## 4. Default State Machine

The default playable state machine should become:

`reward_choice -> event_draft -> roll_board -> settling -> settlement_result -> reward_choice`

### 4.1 `reward_choice`

Responsibilities:

- show reward options from the previous completed round
- apply the chosen reward to the persistent run state

### 4.2 `event_draft`

Responsibilities:

- show event options
- create or update the active contract and other run modifiers

### 4.3 `roll_board`

Responsibilities:

- respond to the next-turn arrow button
- fill the round pool with empty tokens
- shuffle and build the full board
- hand off immediately to settlement

This can be a very short transition state, but it should exist as a distinct orchestration step.

### 4.4 `settling`

Responsibilities:

- run settlement automatically
- play settlement steps and score deltas
- advance contract progress from the resulting score

The player should not need to press a separate settle button in the baseline loop.

### 4.5 `settlement_result`

Responsibilities:

- hold on the completed result screen
- show the board, total score delta, and contract outcome/progress
- provide the button that enters the next reward page

This state is important because the player needs a readable pause between auto settlement and reward selection.

## 5. Runtime Boundaries

### 5.1 `RunSession`

`RunSession` should own only persistent run state, including:

- current score
- turn index
- phase index
- persistent token pool
- active contract
- active modifiers
- operation/event history

It should not own the current board as a long-lived concept because the board is rebuilt every round.

### 5.2 Board Roll Service

Introduce a dedicated service responsible for round generation.

Suggested name:

- `board_roll_service.gd`

Responsibilities:

- accept the persistent token pool
- add empty tokens until the round pool reaches board capacity
- shuffle the entries
- build a full `BoardService` state or equivalent board snapshot input

Non-responsibilities:

- reward logic
- contract resolution
- UI flow

This keeps board generation isolated and testable.

### 5.3 Settlement Services

Settlement logic should continue to live below the UI layer.

Responsibilities remain:

- scan the board
- build settlement input
- resolve settlement steps

The only model change is that the board now comes from the round-roll service rather than manual placement.

### 5.4 `RunScreen`

`RunScreen` should be reduced to orchestration:

- button handling
- state transitions
- service calls
- playback and labels

It should not own the rules for:

- how empty tokens are injected
- how round shuffle works
- how contracts progress
- how rewards change the persistent token pool

### 5.5 Debug / Ability Side Path

The current manual controls should be preserved behind a side path, not the main loop.

Recommended framing:

- debug controls during development
- future intervention ability hook in shipped gameplay

This means `place/remove/settle` may remain in code, but the default player flow must not depend on them.

## 6. Transition Strategy

The migration should happen in a way that keeps the branch playable after every step.

### Step A: Introduce round-roll generation

- add empty token support
- add a service that builds a full round board from the persistent pool
- keep the existing debug placement path alive

Exit condition:

- the branch can still boot and reach a settlement

### Step B: Move the default loop to bag-roll flow

- add next-turn arrow entry
- make the default loop use round generation instead of manual placement
- add settlement-result state

Exit condition:

- the player can complete:
  - reward
  - event
  - next turn
  - auto roll
  - auto settlement
  - settlement result

### Step C: Rebind reward and contract semantics fully to the pool

- rewards update persistent pool entries
- contract progression comes from completed round settlement
- run history reflects round-level generation and resolution instead of manual placement

Exit condition:

- reward and contract both affect future rounds in the correct model

### Step D: Preserve extension hooks

Without implementing the abilities yet, add clear hook points for:

- before roll
- after roll before settle
- after settle before reward

These hook points are where future swap/lock/reroll/manual-placement abilities should attach.

## 7. Testing Strategy

Tests should shift from manual cell input as the main path to round-generation flow as the main path.

### Required tests

- unit test: filling the round pool with empty tokens to board capacity
- unit test: shuffling and laying out concrete token copies without changing counts
- unit test: rewards mutate the persistent pool
- unit test: contracts advance from per-round score
- integration test: reward -> event -> next-turn arrow -> rolled board -> auto settlement -> settlement result
- integration test: debug placement still works when explicitly invoked

### Compatibility rule

During migration, the smoke path remains mandatory.

The smoke path should change from:

- place
- settle
- reward

to:

- reward/event completion
- next-turn arrow
- auto board roll
- auto settlement
- result page

## 8. Recommended Immediate Plan Changes

The existing implementation plan should be reordered.

Recommended next task order:

1. Add empty token content and round-roll generation service.
2. Introduce next-turn arrow and settlement-result state.
3. Switch default run flow to bag-roll generation.
4. Rebind reward changes from "next placement token" to persistent pool mutation.
5. Keep manual placement only as debug/ability scaffolding.
6. Continue with hero/difficulty/event-draft integration on top of the corrected loop.

## 9. Risks

### Risk 1: Mixed models in one UI

If manual placement remains visible as if it were default gameplay, the codebase will keep drifting back to the wrong model.

Mitigation:

- default to bag-roll flow
- explicitly label manual controls as debug or disabled ability controls

### Risk 2: Empty token treated as UI-only placeholder

If empty tokens are not real pool entries, later settlement behavior will diverge from the intended game.

Mitigation:

- model empty token as a formal token definition

### Risk 3: Run state and board state get tangled

If the persistent session owns temporary board details, future reroll/lock/swap features will be harder to reason about.

Mitigation:

- keep board generation as a per-round service output
- keep session focused on persistent run data

## 10. Decision Summary

Approved design assumptions:

- the board is fully regenerated every round
- token pool is a concrete multiset, not a weighted draw table
- empty token is a real token that participates in settlement
- reward and event changes apply to the next round by mutating the persistent pool
- the default player loop is auto-roll plus auto-settle
- manual placement survives only as debug or future ability infrastructure
