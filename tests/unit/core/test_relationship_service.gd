# RelationshipService 契约：
# - relationships[npc_id] = {"kind": "family"|"friend"|"lover", "score": int}
# - add_npc 幂等：重复 add 同 npc 不覆盖；kind 不一致只 warn
# - adjust 累加 score；未知 npc 警告且返回 0
# - list_by_kind / total_by_kind 按 kind 过滤
extends GutTest

const RelationshipServiceScript := preload("res://scripts/core/services/relationship_service.gd")
const RunSessionScript := preload("res://autoload/run_session.gd")

func _make_service():
	return RelationshipServiceScript.new()

func _make_session():
	return RunSessionScript.new()

func test_add_npc_inserts_entry_with_kind_and_zero_score() -> void:
	var session = _make_session()
	_make_service().add_npc(session, "mom", "family")
	assert_true(session.relationships.has("mom"))
	assert_eq(String(session.relationships["mom"]["kind"]), "family")
	assert_eq(int(session.relationships["mom"]["score"]), 0)

func test_add_npc_accepts_initial_score() -> void:
	var session = _make_session()
	_make_service().add_npc(session, "wife", "lover", 30)
	assert_eq(int(session.relationships["wife"]["score"]), 30)

func test_add_npc_idempotent_does_not_overwrite_score() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_npc(session, "buddy", "friend", 10)
	svc.add_npc(session, "buddy", "friend", 99)
	assert_eq(int(session.relationships["buddy"]["score"]), 10, "重复 add 不覆盖 score")

func test_adjust_returns_new_score_and_mutates() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_npc(session, "dad", "family", 5)
	assert_eq(svc.adjust(session, "dad", 3), 8)
	assert_eq(int(session.relationships["dad"]["score"]), 8)

func test_adjust_handles_negative_delta() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_npc(session, "rival", "friend", 5)
	assert_eq(svc.adjust(session, "rival", -10), -5)

func test_adjust_on_unknown_npc_returns_zero() -> void:
	var session = _make_session()
	assert_eq(_make_service().adjust(session, "ghost", 5), 0)

func test_score_of_unknown_npc_is_zero() -> void:
	var session = _make_session()
	assert_eq(_make_service().score_of(session, "ghost"), 0)

func test_kind_of_unknown_npc_is_empty_string() -> void:
	var session = _make_session()
	assert_eq(_make_service().kind_of(session, "ghost"), "")

func test_list_by_kind_filters_correctly() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_npc(session, "mom", "family")
	svc.add_npc(session, "dad", "family")
	svc.add_npc(session, "buddy", "friend")
	var fam: Array = svc.list_by_kind(session, "family")
	assert_eq(fam.size(), 2)
	assert_true(fam.has("mom"))
	assert_true(fam.has("dad"))

func test_list_by_kind_empty_for_no_match() -> void:
	var session = _make_session()
	_make_service().add_npc(session, "mom", "family")
	assert_eq(_make_service().list_by_kind(session, "lover").size(), 0)

func test_total_by_kind_sums_scores() -> void:
	var session = _make_session()
	var svc = _make_service()
	svc.add_npc(session, "mom", "family", 10)
	svc.add_npc(session, "dad", "family", 15)
	svc.add_npc(session, "buddy", "friend", 7)
	assert_eq(svc.total_by_kind(session, "family"), 25)
	assert_eq(svc.total_by_kind(session, "friend"), 7)
	assert_eq(svc.total_by_kind(session, "lover"), 0)

func test_relationships_default_empty_on_new_session() -> void:
	var session = _make_session()
	assert_eq(session.relationships.size(), 0, "新 RunSession 的 relationships 应当为空字典")
