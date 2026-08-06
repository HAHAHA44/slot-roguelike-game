# ShopService 契约：每年上架若干道具，用当年购买力购买。
extends GutTest

const ShopServiceScript := preload("res://scripts/core/services/shop_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

var _service
var _session
var _items: Dictionary

func before_each() -> void:
	_service = ShopServiceScript.new()
	_session = RunSessionScript.new()
	_items = {}

func _item(id: String, price: float = 0.5, min_stage: int = 0, max_stack: int = 1,
		weight: float = 1.0):
	var def := ItemDefinition.new()
	def.id = id
	def.name = id
	def.price = price
	def.min_stage_order = min_stage
	def.max_stack = max_stack
	def.shop_weight = weight
	_items[id] = def
	return def

func _ids(stock: Array) -> Array:
	var result: Array = []
	for def in stock:
		result.append(String(def.id))
	return result

# -- 上架 --------------------------------------------------------------------

func test_stock_size_is_capped() -> void:
	for i in 10:
		_item("i%d" % i)
	assert_eq(_service.roll_stock(_session, _items, 0).size(), ShopServiceScript.OFFER_SIZE)

func test_stock_has_no_duplicates() -> void:
	for i in 10:
		_item("i%d" % i)
	var ids := _ids(_service.roll_stock(_session, _items, 0))
	var seen: Dictionary = {}
	for id in ids:
		assert_false(seen.has(id), "同一件道具不该在货架上出现两次")
		seen[id] = true

func test_stock_shrinks_when_catalogue_is_small() -> void:
	_item("only_one")
	assert_eq(_service.roll_stock(_session, _items, 0).size(), 1)

func test_locked_items_do_not_appear_early() -> void:
	# 强力道具后期才上架，构成内容梯度。
	_item("early", 0.5, 0)
	_item("late", 2.0, 4)
	assert_eq(_ids(_service.roll_stock(_session, _items, 0)), ["early"])
	assert_eq(_ids(_service.roll_stock(_session, _items, 4)).size(), 2)

func test_maxed_items_leave_the_shelf() -> void:
	_item("charm", 0.5, 0, 1)
	_session.owned_items["charm"] = 1
	assert_eq(_service.roll_stock(_session, _items, 0).size(), 0, "买满上限就不再上架")

func test_stackable_item_stays_until_capped() -> void:
	_item("charm", 0.5, 0, 3)
	_session.owned_items["charm"] = 2
	assert_eq(_service.roll_stock(_session, _items, 0).size(), 1)
	_session.owned_items["charm"] = 3
	assert_eq(_service.roll_stock(_session, _items, 0).size(), 0)

func test_zero_weight_items_never_stock() -> void:
	_item("hidden", 0.5, 0, 1, 0.0)
	assert_eq(_service.roll_stock(_session, _items, 0).size(), 0)

# -- 购买 --------------------------------------------------------------------

func test_buy_spends_purchasing_power() -> void:
	var def = _item("charm", 0.6)
	_session.purchasing_power = 1.0
	assert_true(_service.buy(_session, def))
	assert_almost_eq(_session.purchasing_power, 0.4, 0.001)
	assert_eq(int(_session.owned_items["charm"]), 1)

func test_buy_fails_without_enough_power() -> void:
	var def = _item("charm", 0.6)
	_session.purchasing_power = 0.5
	assert_false(_service.buy(_session, def))
	assert_almost_eq(_session.purchasing_power, 0.5, 0.001, "失败不该扣钱")
	assert_false(_session.owned_items.has("charm"))

func test_buy_respects_max_stack() -> void:
	var def = _item("charm", 0.1, 0, 2)
	_session.purchasing_power = 10.0
	assert_true(_service.buy(_session, def))
	assert_true(_service.buy(_session, def))
	assert_false(_service.buy(_session, def), "第三份超过上限")
	assert_eq(int(_session.owned_items["charm"]), 2)

func test_can_afford_matches_buy() -> void:
	var def = _item("charm", 0.6)
	_session.purchasing_power = 0.5
	assert_false(_service.can_afford(_session, def))
	_session.purchasing_power = 0.6
	assert_true(_service.can_afford(_session, def))

func test_buy_rejects_nulls() -> void:
	assert_false(_service.buy(null, _item("charm")))
	assert_false(_service.buy(_session, null))
	assert_false(_service.can_afford(null, null))
