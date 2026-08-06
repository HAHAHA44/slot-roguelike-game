# 本局运行状态（一条人生）：
# - 时间：age / lifespan / stage_idx。每年 age +1，到 lifespan 自然死。
# - 牌：board_cards（命盘，≤12，参与结算）+ bench_cards（行囊，≤6，不参与结算）。
#   两者都装 CardInstance，不是裸 id——升星让同名碎片有了不同强度，见 card_instance.gd。
# - 人：stats（六维，精神力是其中一维 "spr"，不再有独立的 sanity 字段）、
#   active_buffs / active_debuffs（出生时一次性结算，见 BuffService.apply）。
# - 钱：stage_income（本阶段各年收益，阶段末考核用）、owned_items（已购道具 id）。
# - 传承：legacy_domains 记录已经在哪些领域建过树，供投注池加权与传承链续接。
#
# 5×5 bag-roll 时代的字段（current_score / token_pool / token_cursor / phase_* /
# operation_history）已随对应服务一并删除，考古去 git history（2026-07 之前）。
class_name RunSession
extends RefCounted

const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

const SCHEMA_VERSION := 2
const BOARD_CAPACITY := 12
const BENCH_CAPACITY := 6

# -- 时间 --------------------------------------------------------------------
var age: int = 0
var lifespan: int = 0
var stage_idx: int = 0
var zodiac_birth: String = ""

# -- 牌 ----------------------------------------------------------------------
# 命盘：每年洗牌投上 12 格结算。容量恒为 BOARD_CAPACITY，不足部分投盘时由「凡庸」补位。
var board_cards: Array = []
# 行囊：材料区与备选区共用。不参与结算，可在投盘前与命盘互换。
var bench_cards: Array = []

# -- 人 ----------------------------------------------------------------------
# 六维：str / int / agi / end / spr / luck。见 AttributeService.ORDERED_KEYS。
var stats: Dictionary = {}
var active_buffs: Array[String] = []
var active_debuffs: Array[String] = []
# NPC 关系表：{npc_id -> {"kind": String, "score": int}}；kind ∈ {family, friend, lover}。
var relationships: Dictionary = {}

# -- 经济 --------------------------------------------------------------------
# 本阶段每一年的年收益，阶段切换时清空。阶段考核读它的最后一项。
var stage_income: Array = []
# 已购道具 id → 份数。道具跨阶段累积，不随阶段清空。
var owned_items: Dictionary = {}
# 当年可花的购买力（年收益 / 阶段门槛），每年年初重算。
var purchasing_power: float = 0.0

# -- 传承 --------------------------------------------------------------------
# 已建树的领域 → 最高环数。投注池按它给同领域碎片加权，传承链按它续接。
var legacy_domains: Dictionary = {}

# -- 结局 --------------------------------------------------------------------
var karma_in_run: int = 0
# "" = 还活着；否则是死因 id（natural / lethal_event / ...）。
var death_cause: String = ""

# -- 六维便捷读写（stats 是裸 Dictionary，这两个方法避免调用方到处写 get(key, 0)）----

func stat(key: String) -> int:
	return int(stats.get(key, 0))

func set_stat(key: String, value: int) -> void:
	stats[key] = value

# -- 牌堆操作 ----------------------------------------------------------------

func board_is_full() -> bool:
	return board_cards.size() >= BOARD_CAPACITY

func bench_is_full() -> bool:
	return bench_cards.size() >= BENCH_CAPACITY

# 所有持有的碎片（命盘 + 行囊），合成与投注池加权都要看全量。
func all_cards() -> Array:
	var result: Array = []
	result.append_array(board_cards)
	result.append_array(bench_cards)
	return result

func total_card_count() -> int:
	return board_cards.size() + bench_cards.size()

# -- 序列化 ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"age": age,
		"lifespan": lifespan,
		"stage_idx": stage_idx,
		"zodiac_birth": zodiac_birth,
		"board_cards": _cards_to_array(board_cards),
		"bench_cards": _cards_to_array(bench_cards),
		"stats": stats.duplicate(true),
		"active_buffs": active_buffs.duplicate(),
		"active_debuffs": active_debuffs.duplicate(),
		"relationships": relationships.duplicate(true),
		"stage_income": stage_income.duplicate(),
		"owned_items": owned_items.duplicate(true),
		"purchasing_power": purchasing_power,
		"legacy_domains": legacy_domains.duplicate(true),
		"karma_in_run": karma_in_run,
		"death_cause": death_cause,
	}

static func from_dict(data: Dictionary) -> RunSession:
	var session := RunSession.new()
	session.age = int(data.get("age", 0))
	session.lifespan = int(data.get("lifespan", 0))
	session.stage_idx = int(data.get("stage_idx", 0))
	session.zodiac_birth = String(data.get("zodiac_birth", ""))
	session.board_cards = _cards_from_array(data.get("board_cards", []))
	session.bench_cards = _cards_from_array(data.get("bench_cards", []))
	var incoming_stats = data.get("stats", {})
	session.stats = (incoming_stats as Dictionary).duplicate(true) if incoming_stats is Dictionary else {}
	session.active_buffs = []
	for buff_id in data.get("active_buffs", []):
		session.active_buffs.append(String(buff_id))
	session.active_debuffs = []
	for debuff_id in data.get("active_debuffs", []):
		session.active_debuffs.append(String(debuff_id))
	var incoming_relationships = data.get("relationships", {})
	session.relationships = (incoming_relationships as Dictionary).duplicate(true) \
		if incoming_relationships is Dictionary else {}
	session.stage_income = []
	for income in data.get("stage_income", []):
		session.stage_income.append(int(income))
	var incoming_items = data.get("owned_items", {})
	session.owned_items = (incoming_items as Dictionary).duplicate(true) if incoming_items is Dictionary else {}
	session.purchasing_power = float(data.get("purchasing_power", 0.0))
	var incoming_legacy = data.get("legacy_domains", {})
	session.legacy_domains = (incoming_legacy as Dictionary).duplicate(true) \
		if incoming_legacy is Dictionary else {}
	session.karma_in_run = int(data.get("karma_in_run", 0))
	session.death_cause = String(data.get("death_cause", ""))
	return session

static func _cards_to_array(cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		if card != null:
			result.append(card.to_dict())
	return result

static func _cards_from_array(raw: Array) -> Array:
	var result: Array = []
	for entry in raw:
		if entry is Dictionary:
			result.append(CardInstanceScript.from_dict(entry))
	return result
