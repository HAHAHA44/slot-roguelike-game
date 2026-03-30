# 异常内容定义：
# - 描述一个会改变后续回合规则的特殊内容块，例如临时扩盘、额外列、双格生成等。
# - 只是数据容器，不直接执行逻辑；真正应用异常的逻辑应放在 service 里。
# - 典型联动：`ContentRegistry` 载入后，`EndlessService` 或未来的异常系统读取这些资源并把它们转成运行时上下文变化。
class_name AnomalyDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var anomaly_type: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var rules: Dictionary = {}
