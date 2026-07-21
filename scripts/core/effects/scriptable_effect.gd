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

# 给玩家看的一句话机制说明（背包面板逐条列出）。
# 由子类 override，从自己的 @export 字段现算——不写死在 l10n 文案里。
# 这样调数值时说明自动跟着变，不会出现「文案写 +3、实际 +4」的漂移。
func describe() -> String:
	return ""

# 把「定额 + 百分比」两种加成拼成一段可读文本，供子类复用。
static func format_gain(amount: int, percent: int) -> String:
	if amount != 0 and percent != 0:
		return L10n.format_text("effect.gain.both", {"amount": amount, "percent": percent},
			"+%d 再 +%d%%" % [amount, percent])
	if percent != 0:
		return L10n.format_text("effect.gain.percent", {"percent": percent}, "+%d%%" % percent)
	return L10n.format_text("effect.gain.flat", {"amount": amount}, "+%d" % amount)
