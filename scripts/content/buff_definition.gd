# Buff/Debuff 内容定义（预留）：
# - 描述一个开局可能携带的增益(buff)或减益(debuff)。
# - 本批只做「数据 + 展示」：实际对属性 / cascade / 事件的加成留到后续设计，
#   这里只有 polarity（好/坏）+ magnitude（强度占位）+ 文案。
# - 与其它 *Definition 一样由 ContentRegistry 按 id 索引；开局抽取走 BuffService。
class_name BuffDefinition
extends Resource

const ALLOWED_POLARITIES := ["buff", "debuff"]

@export var id: String = ""
# l10n key，例如 "content.buff.lucky_star.name"
@export var display_name: String = ""
# l10n key，一句 flavor 描述；空串表示无描述。
@export var description: String = ""
# "buff"=增益 / "debuff"=减益。BuffService 按它分两池抽取。
@export var polarity: String = "buff"
# 强度占位：后续设计具体效果时消费（正数=更强的增益 / 更狠的减益）。本批不参与计算。
@export var magnitude: int = 1
@export var tags: PackedStringArray = PackedStringArray()

func get_display_name() -> String:
	return L10n.text(display_name, id)

func get_display_description() -> String:
	if description.is_empty():
		return ""
	return L10n.text(description)

func is_buff() -> bool:
	return polarity == "buff"
