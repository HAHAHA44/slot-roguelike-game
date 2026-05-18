# 年龄服务：
# - 每年 step_year 末尾调 advance(session) 把 age++（M2 接入后替换 RunScreen 里的 inline age++）。
# - is_natural_death() 在 advance 后判断；lifespan=0 视为未设定，永远不自然死。
# - 不签 signal；调用方收到布尔后再决定 _alive 状态。
class_name AgeService
extends RefCounted

func advance(session) -> int:
	if session == null:
		push_error("AgeService.advance: session 为 null")
		return 0
	session.age = int(session.age) + 1
	return session.age

func is_natural_death(session) -> bool:
	if session == null:
		return false
	var lifespan: int = int(session.lifespan)
	if lifespan <= 0:
		return false
	return int(session.age) >= lifespan
