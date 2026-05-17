# Content Schema

## Resource Classes

### `TokenDefinition`

Fields:
- `id`
- `name` (translation key)
- `description` (translation key)
- `rarity`
- `type` (element: `fire` / `water` / `earth` / `wind`, or `""` for system)
- `tags`
- `base_value`
- `trigger_rules`
- `state_fields`
- `spawn_rules`
- `remove_rules`

Allowed `rarity` values: `Common`, `Uncommon`, `Rare`, `Legendary`.

### `ItemDefinition`

Fields: `id`, `name`, `description`, `effect_type`, `effect_data`.

`effect_type` is `passive` (stays in the inventory and grants `item_bonus` every settlement) or `instant` (applied immediately, never enters the inventory). `effect_data` shape depends on the type:

- `passive` → `{"element": "fire" | "water" | "earth" | "wind"}` — adds `+1` per matching-element token on the board.
- `instant` upgrade → `{"action": "upgrade_random"}` — pick one pool token, swap it for the next rarity of the same element.
- `instant` delete → `{"action": "delete_random", "count": N}` — remove `N` non-empty tokens from the pool.

### `EventDefinition`

Fields: `id`, `name`, `type`, `tags_affected`, `duration`, `contract_template`, `reward_bundle`, `penalty_bundle`. `type` ∈ `{instant, lasting, crisis}`.

> **Status note:** `EventDraftService` currently generates events procedurally (random copy / delete / item) and does **not** read `content/events/*.tres`. The `.tres` files are kept for the future weighted-draft pass but are unused right now.

### `HeroDefinition`

Fields: `id`, `name`, `starting_passive`, `attribute_bias`, `event_weight_modifiers`.

Allowed `attribute_bias` values: `Insight`, `Resolve`, `Flux`, `Greed`.

> **Status note:** `RunModifierService` ingests these but no settlement / draft path consumes the resulting modifiers yet.

### `empty_token` (system token)

A regular `TokenDefinition` with `id = "empty_token"`, `base_value = 0`, no tags, `spawn_rules = {"weight": 0.0}`.

- Injected automatically each round to fill the board to 25 cells.
- Excluded from every reward pool (zero spawn weight).
- Participates in board generation and settlement but contributes 0 score.
- Never list it in manual content lists or weighted spawn pools.

## Registry Rules

`ContentRegistry.load_all()` walks each `content/<kind>/` directory once at startup and indexes resources by `id`:

| Index | Directory |
|-------|-----------|
| `tokens` | `res://content/tokens/` |
| `events` | `res://content/events/` |
| `items` | `res://content/items/` |
| `heroes` | `res://content/heroes/` |
| `difficulty_modifiers` | `res://content/difficulty/` |
| `meta_unlocks` | `res://content/meta/` |
| `anomalies` | `res://content/anomalies/` |

- `id` values must be unique within their kind.
- Every loaded resource is run through `ContentDefinitionValidator`; invalid resources are dropped with a `push_error` rather than silently merged into runtime state.
- `spawn_rules.weight == 0` tokens are excluded from player-facing reward offers.

## Bag-Roll Core Loop

### Persistent token pool

`RunSession.token_pool` is a concrete **multiset** (`Array[String]`). Duplicates are allowed and meaningful — two entries of `fire_common` mean two copies appear in every rolled board.

- `pool_add(id)` — append unconditionally.
- `pool_remove(id)` — remove one entry (first match).
- `pool_count(id)` — count copies.

### Per-round board generation

Each round, `BoardRollService.build_round_pool()`:

1. Copies the persistent pool.
2. Appends `empty_token` entries until the pool reaches board capacity (25).
3. Fisher-Yates shuffles the round pool.
4. If the persistent pool already exceeds capacity, it keeps a shuffled 25-entry sample and adds no empties.
5. Returns the shuffled 25-entry pool; `pool_to_board_map()` translates it into `Vector2i → token_id`.

The persistent pool is **never mutated** during board generation.

### Settlement phases (in order)

`base_output → item_bonus → adjacency → row_column → conditional → copy_amplify → cleanup`

Only `base_output`, `item_bonus`, `row_column`, and `cleanup` are populated by current rules; the rest are reserved phase slots.

### State flow

```
offer_choice → event_draft → roll_board → settling → settlement_result → offer_choice
```

Manual placement (`player_turn`) is **debug-only** scaffolding kept behind `debug_enter_player_turn()`. It is not part of the default flow and no UI affordance enters it.

## Naming And Rename Discipline

- Keep resource filenames aligned with `id`, e.g. `fire_common.tres` uses `id = "fire_common"`.
- Treat `id` as the stable primary key. Renaming display `name` is safe; renaming `id` is a migration.
- When renaming exported script fields, migrate existing `.tres` files in the same change — Godot silently drops unmatched serialized fields.
- Prefer additive schema changes over field replacement. If a field must be removed, first copy data into its replacement and resave every affected resource.
