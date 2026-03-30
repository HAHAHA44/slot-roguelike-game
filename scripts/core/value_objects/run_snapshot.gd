# 结算快照：
# - 表示“一次结算所需要读取的全部输入”，核心就是 `phase_effects`。
# - 它应该尽量保持只读，方便 `SettlementResolver` 重复计算、测试和回放。
# - 当前 `RunScreen` 会在结算前组装它，未来更适合由独立的 snapshot builder / scanner 服务生成。
# - 典型联动：`RunScreen` 组装，`SettlementResolver` 消费，`EventDraftService` 也会读取其中的 `board_tags`。
class_name RunSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var phase_effects: Dictionary

func _init(initial_phase_effects: Dictionary = {}) -> void:
	phase_effects = initial_phase_effects.duplicate(true)

func get_phase_effects(phase: String) -> Array:
	return phase_effects.get(phase, [])

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"phase_effects": phase_effects.duplicate(true),
	}

static func from_dict(data: Dictionary) -> RunSnapshot:
	return RunSnapshot.new(data.get("phase_effects", {}))
