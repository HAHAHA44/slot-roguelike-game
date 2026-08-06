# 精神力服务：
# - 精神力是**六维之一**（stats["spr"]），不是独立的一条状态条。见 CONTEXT.md。
# - 它同时控制两件事：转折年的触发密度、以及恶性/致死事件的权重。
#   低精神力即 fun-axes P3 说的「死亡轮盘开启」。
#
# 量纲说明：六维出生只分 10 点，摊到六维每维期望才 1.7 —— 那样所有人一出生就在
# 「低精神」档，死亡轮盘从童年就开着，显然不对。所以精神力在出生时额外自带
# BIRTH_BASELINE 点心力底子（一个人不会生下来就精神崩溃），实际范围 0..MAX_VALUE。
# 这条基线由 AttributeService.roll_initial 施加，本服务只负责读写与分档。
class_name SpiritService
extends RefCounted

const KEY := "spr"
const MIN_VALUE := 0
const MAX_VALUE := 20
# 出生自带的心力底子，见上文。
const BIRTH_BASELINE := 5
const DEFAULT_HIGH := 9
const DEFAULT_LOW := 4

var _high_threshold: int
var _low_threshold: int

# 参数名不叫 high_threshold / low_threshold：那会遮蔽同名的两个访问器方法，
# GDScript 会报 shadowed_variable 警告，而本项目把警告当测试错误。
func _init(high: int = DEFAULT_HIGH, low: int = DEFAULT_LOW) -> void:
	if high <= low:
		push_warning("SpiritService 阈值错配：high=%d <= low=%d；改用默认 %d/%d"
			% [high, low, DEFAULT_HIGH, DEFAULT_LOW])
		_high_threshold = DEFAULT_HIGH
		_low_threshold = DEFAULT_LOW
	else:
		_high_threshold = high
		_low_threshold = low

func clamp_value(v: int) -> int:
	return clampi(v, MIN_VALUE, MAX_VALUE)

# "high" / "mid" / "low"。事件抽取与 UI 配色都认这三个字符串。
func bucket_of(v: int) -> String:
	var clamped := clamp_value(v)
	if clamped >= _high_threshold:
		return "high"
	if clamped <= _low_threshold:
		return "low"
	return "mid"

func value(session) -> int:
	if session == null:
		return 0
	return clamp_value(session.stat(KEY))

func bucket(session) -> String:
	return bucket_of(value(session))

func add(session, delta: int) -> int:
	if session == null:
		push_error("SpiritService.add: session 为 null")
		return 0
	var next_value := clamp_value(session.stat(KEY) + delta)
	session.set_stat(KEY, next_value)
	return next_value

func set_value(session, v: int) -> int:
	if session == null:
		push_error("SpiritService.set_value: session 为 null")
		return 0
	var clamped := clamp_value(v)
	session.set_stat(KEY, clamped)
	return clamped

func high_threshold() -> int:
	return _high_threshold

func low_threshold() -> int:
	return _low_threshold
