# Content Schema

## Resource Classes

### `TokenDefinition`

Required fields:
- `id`
- `name`
- `rarity`
- `type`
- `tags`
- `base_value`
- `trigger_rules`
- `state_fields`
- `spawn_rules`
- `remove_rules`

Allowed `rarity` values:
- `Common`
- `Uncommon`
- `Rare`
- `Legendary`

### `EventDefinition`

Required fields:
- `id`
- `name`
- `type`
- `tags_affected`
- `duration`
- `contract_template`
- `reward_bundle`
- `penalty_bundle`

Allowed `type` values:
- `instant`
- `lasting`
- `crisis`

### `HeroDefinition`

Required fields:
- `id`
- `name`
- `starting_passive`
- `attribute_bias`
- `event_weight_modifiers`

Allowed `attribute_bias` values:
- `Insight`
- `Resolve`
- `Flux`
- `Greed`

### `empty_token` (System Token)

A formal `TokenDefinition` with `id = "empty_token"`, `base_value = 0`, no tags, and `spawn_rules = {"weight": 0.0}`.

- Injected automatically each round to fill the board to capacity (25 cells).
- Excluded from all reward offer pools (zero spawn weight).
- Participates fully in board generation and settlement but contributes 0 score.
- Do not include it in manual content lists or weighted spawn pools.

## Registry Rules

- `ContentRegistry` scans `res://content/tokens/*.tres` and indexes resources by `id`.
- `id` values must be globally unique within the loaded content set.
- `spawn_rules.weight == 0` tokens are treated as system-only and excluded from player-facing reward offers.

## Bag-Roll Core Loop

### Persistent Token Pool

`RunSession.token_pool` is a concrete **multiset** (`Array[String]`).  Duplicates are allowed and meaningful — two entries of `relay_prism` mean two copies appear in the rolled board every round.

- `pool_add(id)` — appends one entry unconditionally.
- `pool_remove(id)` — removes one entry (first match).
- `pool_count(id)` — counts copies of an entry.

### Per-Round Board Generation

Each round, `BoardRollService.build_round_pool()`:
1. Copies the persistent pool.
2. Appends `empty_token` entries until the pool reaches board capacity (25).
3. Fisher-Yates shuffles the round pool.
4. If the persistent pool already exceeds capacity, it keeps a shuffled 25-entry sample and adds no empties.
5. Returns the shuffled 25-entry pool; `pool_to_board_map()` translates it to `Vector2i → token_id`.

The persistent pool is **never mutated** during board generation.

### Default Player Flow

```
reward_choice → event_draft → roll_board → settling → settlement_result → reward_choice
```

Manual placement (`player_turn`) is a formal **set mode** branch.
- Default flow stays automatic.
- The header mode toggle switches future turns between `event_draft -> roll_board` and `event_draft -> player_turn`.
- `debug_enter_player_turn()` remains available only as a test/debug shortcut.
- Invalid resources are rejected during load and are not inserted into the registry.

## Naming And Rename Discipline

- Keep resource filenames aligned with `id`, for example `pulse_seed.tres` uses `id = "pulse_seed"`.
- Treat `id` as the stable primary key. Renaming display `name` is safe; renaming `id` is a migration.
- When renaming exported script fields, migrate existing `.tres` files in the same change. Godot can otherwise drop unmatched serialized fields silently.
- Prefer additive schema changes over field replacement. If a field must be removed, first copy data into the replacement field and resave all affected resources.
