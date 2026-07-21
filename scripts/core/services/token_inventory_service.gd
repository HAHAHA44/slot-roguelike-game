# 背包服务（M1）：
# - 管 RunSession.token_pool 的玩家侧增删，以及删牌次数 token_delete_charges。
# - 删牌是「按位置删」而不是「按 id 删」：池子里允许重复（4 张勤勉），
#   玩家在背包里点的是第几张，不是哪个 id——按 id 删会删掉不是他选的那张。
# - 删到空池是合法终局：盘面会整圈铺补位 token（见 RingBoardService.fill_from_pool），
#   所以这里不设「至少保留一张」的下限。
# - 不签 signal、不动 scene；UI 只负责把选中的下标传进来。
class_name TokenInventoryService
extends RefCounted

func charges(session) -> int:
	if session == null:
		return 0
	return int(session.token_delete_charges)

func grant_charges(session, count: int) -> int:
	if session == null:
		push_error("TokenInventoryService.grant_charges: session 为 null")
		return 0
	session.token_delete_charges = maxi(0, int(session.token_delete_charges) + count)
	return session.token_delete_charges

func can_delete_at(session, index: int) -> bool:
	if session == null:
		return false
	if int(session.token_delete_charges) <= 0:
		return false
	return index >= 0 and index < session.token_pool.size()

# 删掉池中第 index 张并扣一次次数。次数不足 / 下标越界都返回 false 且不改任何状态。
func delete_at(session, index: int) -> bool:
	if not can_delete_at(session, index):
		return false
	session.token_pool.remove_at(index)
	session.token_delete_charges = int(session.token_delete_charges) - 1
	# 5×5 遗留：token_cursor 必须始终落在池内，否则 get_active_token_id 会越界。
	session.token_cursor = clampi(int(session.token_cursor), 0, maxi(0, session.token_pool.size() - 1))
	return true
