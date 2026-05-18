# 业力服务：
# - RunSession.karma_in_run 累加本局福报/恶报（事件 karma_delta、长寿奖励、关系奖励 - 罪孽）。
# - consume(session) 在死亡结算时被调用：返回当前 karma_in_run 并清零，
#   调用方再把它累加进跨局的 total_karma（M6 MetaProgressionService 持久化）。
# - 不签 signal、不动 scene。
class_name KarmaService
extends RefCounted

func add_to_run(session, delta: int) -> int:
	if session == null:
		push_error("KarmaService.add_to_run: session 为 null")
		return 0
	session.karma_in_run = int(session.karma_in_run) + delta
	return session.karma_in_run

func consume(session) -> int:
	if session == null:
		push_error("KarmaService.consume: session 为 null")
		return 0
	var snapshot: int = int(session.karma_in_run)
	session.karma_in_run = 0
	return snapshot

func current(session) -> int:
	if session == null:
		return 0
	return int(session.karma_in_run)
