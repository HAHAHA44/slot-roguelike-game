# 人生碎片实例：
# - 「某张碎片在这条人生里的一次具体存在」，区别于 TokenDefinition（静态内容）。
# - 一张碎片的身份 = definition_id + star。三张同名合二星，两张二星合满星（见 MergeService）。
# - 为什么需要实例而不是裸 id：升星让同名碎片有了不同强度，池子里的「第 3 张勤勉」
#   和「那张二星勤勉」不是同一个东西。裸 id 表达不了这个差别。
# - 星级同时放大基础分和 effect 的一切数值（见 CascadeContext.begin_card）——
#   满星碎片不是「分高一点」，是整条联动链一起变粗，这是 fun-axes P2 要的形状。
class_name CardInstance
extends RefCounted

const MAX_STAR := 3
# 各星级的数值倍率。索引 = star - 1。
#
# 这两个数不是拍脑袋的，有可计算的下限：合成会让命盘变稀疏，空出的格子由「凡庸」
# （base 1）补上，所以升星必须补回丢掉的格子才划算。
#   三张一星（base 3 各占一格 = 9）→ 一张二星 + 两格凡庸(2) ⇒ 二星需 > 2.33×
#   六张一星（= 18）→ 一张满星 + 五格凡庸(5) ⇒ 满星需 > 4.33×
# 取 2.5 / 7.0：二星只是微赚（逼玩家想清楚要不要合），满星显著赚（专精该有回报）。
const STAR_MULTIPLIER := [1.0, 2.5, 7.0]

var definition_id: String
var star: int = 1

func _init(initial_definition_id: String = "", initial_star: int = 1) -> void:
	definition_id = initial_definition_id
	star = clampi(initial_star, 1, MAX_STAR)

func multiplier() -> float:
	return STAR_MULTIPLIER[clampi(star - 1, 0, MAX_STAR - 1)]

func is_max_star() -> bool:
	return star >= MAX_STAR

func duplicate_card() -> CardInstance:
	return CardInstance.new(definition_id, star)

func to_dict() -> Dictionary:
	return {"definition_id": definition_id, "star": star}

static func from_dict(data: Dictionary) -> CardInstance:
	return CardInstance.new(String(data.get("definition_id", "")), int(data.get("star", 1)))

# 便捷构造：把 id 列表批量变成一星实例，起始池 / 测试都用得上。
static func make_many(definition_ids: Array, star_level: int = 1) -> Array:
	var result: Array = []
	for id in definition_ids:
		result.append(CardInstance.new(String(id), star_level))
	return result
