# 精神力服务：
# - 维护 RunSession.sanity（0..100），并把它分成三档（高/中/低）。
# - 三档阈值在 _init 注入；默认 <=30 = low, >=70 = high, 中间 = mid。
# - M2 EventDraftService 用 bucket() 选事件权重；M2 UI 用 bucket() 画环形条配色。
# - 纯数据 API，不签 signal、不动 scene。
class_name SanityService
extends RefCounted

const MIN_VALUE := 0
const MAX_VALUE := 100
const DEFAULT_HIGH := 70
const DEFAULT_LOW := 30

var _high_threshold: int
var _low_threshold: int

# 参数名不叫 high_threshold / low_threshold：那会遮蔽同名的两个访问器方法，
# GDScript 会报 shadowed_variable 警告，而本项目把警告当测试错误。
func _init(high: int = DEFAULT_HIGH, low: int = DEFAULT_LOW) -> void:
	if high <= low:
		push_warning("SanityService 阈值错配：high=%d <= low=%d；改用默认 %d/%d"
			% [high, low, DEFAULT_HIGH, DEFAULT_LOW])
		_high_threshold = DEFAULT_HIGH
		_low_threshold = DEFAULT_LOW
	else:
		_high_threshold = high
		_low_threshold = low

func clamp_value(v: int) -> int:
	return clampi(v, MIN_VALUE, MAX_VALUE)

func bucket(v: int) -> String:
	var clamped := clamp_value(v)
	if clamped >= _high_threshold:
		return "high"
	if clamped <= _low_threshold:
		return "low"
	return "mid"

func add(session, delta: int) -> int:
	if session == null:
		push_error("SanityService.add: session 为 null")
		return 0
	session.sanity = clamp_value(int(session.sanity) + delta)
	return session.sanity

func set_value(session, v: int) -> int:
	if session == null:
		push_error("SanityService.set_value: session 为 null")
		return 0
	session.sanity = clamp_value(v)
	return session.sanity

func high_threshold() -> int:
	return _high_threshold

func low_threshold() -> int:
	return _low_threshold
