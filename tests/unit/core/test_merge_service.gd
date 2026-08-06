# MergeService 契约：三张同名一星 → 二星；两张同名二星 → 满星。自动触发。
extends GutTest

const MergeServiceScript := preload("res://scripts/core/services/merge_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")
const CardInstanceScript := preload("res://scripts/core/value_objects/card_instance.gd")

var _service
var _session

func before_each() -> void:
	_service = MergeServiceScript.new()
	_session = RunSessionScript.new()

func _add_board(definition_id: String, count: int, star: int = 1) -> void:
	for _i in count:
		_session.board_cards.append(CardInstanceScript.new(definition_id, star))

func _stars_of(definition_id: String) -> Array:
	var result: Array = []
	for card in _session.all_cards():
		if String(card.definition_id) == definition_id:
			result.append(int(card.star))
	result.sort()
	return result

# -- 基础合成 ----------------------------------------------------------------

func test_two_copies_do_not_merge() -> void:
	_add_board("abacus", 2)
	assert_eq(_service.auto_merge(_session).size(), 0)
	assert_eq(_stars_of("abacus"), [1, 1])

func test_three_copies_merge_into_two_star() -> void:
	_add_board("abacus", 3)
	var events: Array = _service.auto_merge(_session)
	assert_eq(events.size(), 1)
	assert_eq(int(events[0]["to_star"]), 2)
	assert_eq(_stars_of("abacus"), [2], "三张变一张二星，净少两张")

func test_leftovers_stay_at_one_star() -> void:
	_add_board("abacus", 4)
	_service.auto_merge(_session)
	assert_eq(_stars_of("abacus"), [1, 2], "多出来的那张留着继续凑")

func test_six_copies_cascade_all_the_way_to_max_star() -> void:
	# 三张→二星，再三张→二星，两个二星→满星。一趟扫描会漏掉最后那步，
	# 所以 auto_merge 必须循环到没得合为止。
	_add_board("abacus", 6)
	var events: Array = _service.auto_merge(_session)
	assert_eq(events.size(), 3, "两次三合一 + 一次二合一")
	assert_eq(_stars_of("abacus"), [3])

func test_max_star_does_not_merge_further() -> void:
	_add_board("abacus", 2, CardInstanceScript.MAX_STAR)
	assert_eq(_service.auto_merge(_session).size(), 0, "满星封顶，不该再往上合")
	assert_eq(_stars_of("abacus"), [3, 3])

func test_different_ids_never_merge() -> void:
	_add_board("abacus", 2)
	_add_board("crayon", 2)
	assert_eq(_service.auto_merge(_session).size(), 0, "同名才合，异名是配方的事")

# -- 跨容器 ------------------------------------------------------------------

func test_merges_across_board_and_bench() -> void:
	# 行囊是材料区：攒着的两张 + 命盘上的一张应该能凑成。
	_add_board("abacus", 1)
	_session.bench_cards.append(CardInstanceScript.new("abacus"))
	_session.bench_cards.append(CardInstanceScript.new("abacus"))
	_service.auto_merge(_session)
	assert_eq(_stars_of("abacus"), [2])

func test_result_lands_on_board_when_a_board_card_was_consumed() -> void:
	# 命盘上的牌升星后还该在命盘上，玩家不用重新配阵。
	_add_board("abacus", 1)
	_session.bench_cards.append(CardInstanceScript.new("abacus"))
	_session.bench_cards.append(CardInstanceScript.new("abacus"))
	_service.auto_merge(_session)
	assert_eq(_session.board_cards.size(), 1)
	assert_eq(_session.bench_cards.size(), 0)

func test_bench_only_merge_stays_on_bench() -> void:
	for _i in 3:
		_session.bench_cards.append(CardInstanceScript.new("abacus"))
	_service.auto_merge(_session)
	assert_eq(_session.board_cards.size(), 0, "本来就在行囊里的，合完还在行囊")
	assert_eq(_session.bench_cards.size(), 1)

func test_merging_frees_slots() -> void:
	_add_board("abacus", 3)
	_add_board("crayon", 3)
	_service.auto_merge(_session)
	assert_eq(_session.total_card_count(), 2, "六张变两张——空出来的格子交给补位碎片")

# -- 进度查询（UI 的 2/3 提示） ----------------------------------------------

func test_progress_reports_have_and_need() -> void:
	_add_board("abacus", 2)
	var progress: Dictionary = _service.progress_for(_session, "abacus")
	assert_eq(int(progress["star"]), 1)
	assert_eq(int(progress["have"]), 2)
	assert_eq(int(progress["need"]), 3)

func test_progress_is_empty_for_unheld_card() -> void:
	assert_true(_service.progress_for(_session, "nothing").is_empty())

func test_progress_reports_two_star_stack() -> void:
	_add_board("abacus", 1, 2)
	var progress: Dictionary = _service.progress_for(_session, "abacus")
	assert_eq(int(progress["star"]), 2)
	assert_eq(int(progress["need"]), 2, "两张二星合满星")

func test_progress_for_null_session_is_empty() -> void:
	assert_true(_service.progress_for(null, "abacus").is_empty())
