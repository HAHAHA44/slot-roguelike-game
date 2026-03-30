# Meta 解锁定义：
# - 用来描述局外成长节点、解锁项或商店/升级项等长期内容。
# - 当前阶段主要作为数据骨架，为 `MetaProgressionService` 和 `SaveService` 提供统一格式。
# - 它本身不负责解锁判定，只是“解锁后会得到什么”的配置容器。
class_name MetaUnlockDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var unlock_type: String = ""
@export var cost: int = 0
@export var rewards: Dictionary = {}
