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

## Registry Rules

- `ContentRegistry` scans `res://content/tokens/*.tres` and indexes resources by `id`.
- `id` values must be globally unique within the loaded content set.
- Invalid resources are rejected during load and are not inserted into the registry.

## Naming And Rename Discipline

- Keep resource filenames aligned with `id`, for example `pulse_seed.tres` uses `id = "pulse_seed"`.
- Treat `id` as the stable primary key. Renaming display `name` is safe; renaming `id` is a migration.
- When renaming exported script fields, migrate existing `.tres` files in the same change. Godot can otherwise drop unmatched serialized fields silently.
- Prefer additive schema changes over field replacement. If a field must be removed, first copy data into the replacement field and resave all affected resources.
