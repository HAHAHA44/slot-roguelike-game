# 运行时 Token 实例：
# - 表示“某个 token 在当前棋盘上的一次具体出现”，不是内容资源本身。
# - 与 `TokenDefinition` 的区别是：定义是静态内容，实例是运行时携带的 `definition_id / tags / state`。
# - `BoardService` 存的是这种实例，`SettlementResolver` 和 UI 也是读它。
# - 典型联动：`RunScreen._make_token_instance_for_id()` 从 `ContentRegistry` 读取定义，再实例化成 `TokenInstance` 放进棋盘。
class_name TokenInstance
extends RefCounted

const SCHEMA_VERSION := 1

var definition_id: String
var tags: PackedStringArray
var state: Dictionary

func _init(initial_definition_id: String = "", initial_tags: PackedStringArray = PackedStringArray(), initial_state: Dictionary = {}) -> void:
	definition_id = initial_definition_id
	tags = initial_tags
	state = initial_state.duplicate(true)

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"definition_id": definition_id,
		"tags": tags,
		"state": state.duplicate(true),
	}

static func from_dict(data: Dictionary) -> TokenInstance:
	return TokenInstance.new(
		String(data.get("definition_id", "")),
		data.get("tags", PackedStringArray()),
		data.get("state", {}),
	)
