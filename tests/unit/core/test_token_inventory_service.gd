extends GutTest

const TokenInventoryServiceScript := preload("res://scripts/core/services/token_inventory_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

var _service
var _session

func before_each() -> void:
	_service = TokenInventoryServiceScript.new()
	_session = RunSessionScript.new()
	var pool: Array[String] = ["a", "b", "c"]
	_session.token_pool = pool
	_session.token_cursor = 0
	_session.token_delete_charges = 2

func test_charges_reads_session() -> void:
	assert_eq(_service.charges(_session), 2)

func test_charges_null_session_is_zero() -> void:
	assert_eq(_service.charges(null), 0)

func test_delete_at_removes_entry_and_spends_one_charge() -> void:
	assert_true(_service.delete_at(_session, 1))
	assert_eq(_session.token_pool, ["a", "c"], "应删掉下标 1 的那张")
	assert_eq(_session.token_delete_charges, 1, "删一张扣一次")

# 池子允许重复（4 张勤勉）。按下标删才能删掉玩家真正点的那张，
# 按 id 删会删成第一张——这条断言就是在钉死这个区别。
func test_delete_at_removes_the_selected_duplicate_not_the_first() -> void:
	var pool: Array[String] = ["dup", "dup", "keep"]
	_session.token_pool = pool
	assert_true(_service.delete_at(_session, 1))
	assert_eq(_session.token_pool, ["dup", "keep"])

func test_delete_at_rejects_when_no_charges_left() -> void:
	_session.token_delete_charges = 0
	assert_false(_service.delete_at(_session, 0))
	assert_eq(_session.token_pool, ["a", "b", "c"], "次数不足时池子不该被改")

func test_delete_at_rejects_out_of_range_index() -> void:
	assert_false(_service.delete_at(_session, 3))
	assert_false(_service.delete_at(_session, -1))
	assert_eq(_session.token_delete_charges, 2, "越界不该扣次数")

# 删到空池是合法终局：盘面会整圈铺补位 token，不需要「至少保留一张」的下限。
func test_delete_at_can_empty_the_pool() -> void:
	_session.token_delete_charges = 5
	var pool: Array[String] = ["only"]
	_session.token_pool = pool
	assert_true(_service.delete_at(_session, 0))
	assert_eq(_session.token_pool.size(), 0)

# 5×5 遗留不变量：token_cursor 必须始终落在池内，否则 get_active_token_id 越界。
func test_delete_at_keeps_token_cursor_in_range() -> void:
	_session.token_cursor = 2
	assert_true(_service.delete_at(_session, 0))
	assert_lt(_session.token_cursor, _session.token_pool.size())

func test_can_delete_at_matches_delete_outcome() -> void:
	assert_true(_service.can_delete_at(_session, 0))
	assert_false(_service.can_delete_at(_session, 9))
	_session.token_delete_charges = 0
	assert_false(_service.can_delete_at(_session, 0))

func test_grant_charges_adds_and_floors_at_zero() -> void:
	assert_eq(_service.grant_charges(_session, 3), 5)
	assert_eq(_service.grant_charges(_session, -99), 0, "次数不该变成负数")

func test_delete_charges_survive_serialization() -> void:
	_session.token_delete_charges = 4
	var restored = RunSessionScript.from_dict(_session.to_dict())
	assert_eq(restored.token_delete_charges, 4)
