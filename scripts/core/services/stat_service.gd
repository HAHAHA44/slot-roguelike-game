# 属性服务：
# - RunSession.stats: Dictionary<String, int>，键如 "int"/"body"/"charm"/"wealth"（PRD 第 34 行）。
# - 不强约束键白名单；调用方负责传合法 key。
# - soft_gate 是 M4 软门槛接口；本批先实现 0/1 二值占位，M4 平滑到 sigmoid 之类。
class_name StatService
extends RefCounted

func add(session, key: String, delta: int) -> int:
	if session == null:
		push_error("StatService.add: session 为 null")
		return 0
	if key.is_empty():
		push_error("StatService.add: key 为空")
		return 0
	var current: int = int(session.stats.get(key, 0))
	var next_value := current + delta
	session.stats[key] = next_value
	return next_value

func get_value(session, key: String) -> int:
	if session == null:
		return 0
	return int(session.stats.get(key, 0))

func set_value(session, key: String, v: int) -> int:
	if session == null:
		push_error("StatService.set_value: session 为 null")
		return 0
	if key.is_empty():
		push_error("StatService.set_value: key 为空")
		return 0
	session.stats[key] = v
	return v

# M4 占位：当前属性 >= 门槛返回 1.0，否则 0.0。
# M4 实装时会换成 sigmoid / clamp 之类的平滑曲线。
func soft_gate(session, key: String, threshold: int) -> float:
	if get_value(session, key) >= threshold:
		return 1.0
	return 0.0
