# ScriptableEffect 基类：
# - token / event / item 可挂载的 effect 单元；以 Resource 形式嵌入 .tres。
# - 具体 effect（M1 起：AddSelfScore / ModifyNeighbor / TriggerZodiacChain 等）
#   继承本类并 override `execute(context)`。
# - context 的字段形状由各阶段（cascade / event resolver / item hook）按需扩展，
#   本基类不强制结构，保持向前兼容。
class_name ScriptableEffect
extends Resource

# 由具体 effect 子类 override。基类默认空实现。
func execute(_context) -> void:
	pass
