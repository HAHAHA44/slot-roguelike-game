# 道具商店服务：
# - 每年年末摆出若干件道具，玩家用当年购买力（年收益 / 阶段门槛）购买。
# - 剩余购买力**作废**，不跨年留存。攒钱在这个游戏里没有叙事意义
#   （你攒的是「这些年过得好不好」，攒不到下辈子），作废逼玩家每年都做决定。
# - 已买满 max_stack 的道具不再上架；未解锁阶段的道具也不上架。
# - 纯 RefCounted：进 session + 道具表，出候选/结果。
class_name ShopService
extends RefCounted

# 每年上架几件。4 件足够产生取舍，又不至于让每年的商店变成一场阅读理解。
const OFFER_SIZE := 4

# 摆出本年的货架，返回 ItemDefinition 数组（可能少于 OFFER_SIZE）。
func roll_stock(session, items: Dictionary, stage_order: int) -> Array:
	var pool: Array = []
	for item_id in items:
		var def = items[item_id]
		if def == null:
			continue
		if int(def.min_stage_order) > stage_order:
			continue
		if _owned_count(session, String(item_id)) >= int(def.max_stack):
			continue
		if float(def.shop_weight) <= 0.0:
			continue
		pool.append(def)
	pool.sort_custom(func(a, b): return String(a.id) < String(b.id))

	var stock: Array = []
	while stock.size() < OFFER_SIZE and not pool.is_empty():
		var picked_index := _pick_weighted_index(pool)
		stock.append(pool[picked_index])
		pool.remove_at(picked_index)
	return stock

# 买一件。购买力不足 / 已达上限都返回 false 且不改任何状态。
func buy(session, item_def) -> bool:
	if session == null or item_def == null:
		return false
	var price := float(item_def.price)
	if session.purchasing_power < price:
		return false
	if _owned_count(session, String(item_def.id)) >= int(item_def.max_stack):
		return false
	session.purchasing_power -= price
	session.owned_items[String(item_def.id)] = _owned_count(session, String(item_def.id)) + 1
	return true

func can_afford(session, item_def) -> bool:
	if session == null or item_def == null:
		return false
	return session.purchasing_power >= float(item_def.price) \
		and _owned_count(session, String(item_def.id)) < int(item_def.max_stack)

func _owned_count(session, item_id: String) -> int:
	if session == null:
		return 0
	return int(session.owned_items.get(item_id, 0))

func _pick_weighted_index(pool: Array) -> int:
	var total: float = 0.0
	for def in pool:
		total += maxf(float(def.shop_weight), 0.0)
	if total <= 0.0:
		return randi() % pool.size()
	var roll: float = randf() * total
	for i in pool.size():
		roll -= maxf(float(pool[i].shop_weight), 0.0)
		if roll <= 0.0:
			return i
	return pool.size() - 1
