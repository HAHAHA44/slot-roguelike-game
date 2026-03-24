# Plugin Decisions

## Pinned Versions

| Plugin | Version | Source | Why now |
| --- | --- | --- | --- |
| GUT | `9.6.0` | `https://github.com/bitwes/Gut` | Required immediately for unit and integration tests on Godot `4.6.x`. |
| Godot State Charts | `0.22.3` | `https://github.com/derkork/godot-statecharts` | Approved for later run-flow state management; installed now to keep the project baseline stable. |
| Locker | not installed | TBD when Task 9 starts | Deferred until save-versioning and multiple save slots become real requirements. |

## Installation Policy

- Third-party addons are vendored into `addons/` instead of added as nested git repositories.
- Each plugin version is pinned to a tag that matches the implementation plan.
- Plugin activation is declared in `project.godot` so editor state does not depend on a local machine.

## Upgrade Strategy

1. Upgrade one plugin at a time.
2. Record the new tag, release date, and compatibility target in this document.
3. Re-run headless GUT tests before and after the upgrade.
4. Reject the upgrade if it forces core gameplay architecture changes outside the plugin's responsibility.
