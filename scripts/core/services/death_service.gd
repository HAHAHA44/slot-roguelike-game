# 死亡服务：
# - 统一构造"死亡报告" Dictionary（cause / age / reason）。
# - 不 mutate session、不切 _alive 状态——这两件事由 RunScreen 在收到报告后自行决定。
# - M4 扩展 cause 枚举（PEACEFUL / LONELY / ILLNESS）；本批只放 M2 的两种。
class_name DeathService
extends RefCounted

enum Cause {
	NATURAL,
	LETHAL_EVENT,
}

func build_report(session, cause: int, reason: String = "") -> Dictionary:
	var age_value: int = 0
	if session != null:
		age_value = int(session.age)
	return {
		"cause": cause,
		"age": age_value,
		"reason": reason,
	}

func cause_name(cause: int) -> String:
	match cause:
		Cause.NATURAL:
			return "natural"
		Cause.LETHAL_EVENT:
			return "lethal_event"
		_:
			return "unknown"
