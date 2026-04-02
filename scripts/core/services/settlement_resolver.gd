# 结算解析器：
# - 对外暴露 `resolve_board(board, registry)`，内部先构建 RunSnapshot，再按 phase 展开成 SettlementReport。
# - `build_snapshot(board, registry)` 也作为公开方法，供 EventDraftService 等只需要快照的调用方使用。
# - 它是纯规则层：不碰 UI，不直接改 RunSession，具备保护阈值避免死循环。
class_name SettlementResolver
extends RefCounted

const PHASES: Array[String] = [
	"base_output",
	"item_bonus",
	"adjacency",
	"row_column",
	"conditional",
	"copy_amplify",
	"cleanup",
]

const MAX_ITERATION_DEPTH := 32
const MAX_TRIGGER_COUNT_PER_TOKEN := 16
const EMPTY_TOKEN_ID := "empty_token"

# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

func resolve_board(board: BoardService, registry: ContentRegistry, active_item_defs: Array = []) -> SettlementReport:
	var snapshot := build_snapshot(board, registry, active_item_defs)
	return resolve(snapshot)

func build_snapshot(board: BoardService, registry: ContentRegistry, active_item_defs: Array = []) -> RunSnapshot:
	var tokens_with_pos: Array = []  # Array of {token, pos}
	var board_tags: Dictionary = {}

	for row in board.height:
		for column in board.width:
			var pos := Vector2i(column, row)
			if board.has_token(pos):
				var token = board.get_token(pos)
				tokens_with_pos.append({"token": token, "pos": pos})
				for tag in token.tags:
					board_tags[tag] = int(board_tags.get(tag, 0)) + 1

	var phase_effects: Dictionary = {}
	phase_effects["board_tags"] = board_tags

	# base_output：每个非空 token 贡献 base_value 分
	var base_effects: Array = []
	for entry in tokens_with_pos:
		var token = entry["token"]
		var pos: Vector2i = entry["pos"]
		if token.definition_id == EMPTY_TOKEN_ID:
			continue
		var definition: TokenDefinition = registry.tokens.get(token.definition_id)
		var base_val: int = definition.base_value if definition else 1
		var name: String = definition.name if definition else token.definition_id
		base_effects.append(_make_effect(token.definition_id, "base_output", base_val, pos, name))
	if base_effects.size() > 0:
		phase_effects["base_output"] = base_effects

	# item_bonus：被动道具对对应元素每个 token +1
	var item_bonus_effects: Array = _build_item_bonus_effects(board, registry, active_item_defs)
	if item_bonus_effects.size() > 0:
		phase_effects["item_bonus"] = item_bonus_effects

	# row_column：元素联动触发（火/水/土/风）
	var element_effects: Array = _build_element_effects(board, registry)
	if element_effects.size() > 0:
		phase_effects["row_column"] = element_effects

	phase_effects["cleanup"] = [_make_effect("system", "cleanup", 0)]

	return RunSnapshot.new(phase_effects)

func resolve(snapshot: RunSnapshot) -> SettlementReport:
	var report := SettlementReport.new()
	var sequence_index := 0
	var trigger_counts: Dictionary = {}

	report.phases = PHASES.duplicate()

	for phase in PHASES:
		var phase_steps: Array = snapshot.get_phase_effects(phase)
		for effect in phase_steps:
			if sequence_index >= MAX_ITERATION_DEPTH:
				report.warnings.append("settlement stopped at MAX_ITERATION_DEPTH")
				return report

			var source_token := String(effect.get("source_token", ""))
			var trigger_count := int(trigger_counts.get(source_token, 0))
			if trigger_count >= MAX_TRIGGER_COUNT_PER_TOKEN:
				report.warnings.append("token %s exceeded MAX_TRIGGER_COUNT_PER_TOKEN" % source_token)
				continue

			trigger_counts[source_token] = trigger_count + 1

			var step := SettlementStep.new(
				sequence_index,
				source_token,
				phase,
				int(effect.get("score_delta", 0)),
				String(effect.get("target_token", "")),
				String(effect.get("message_key", "")),
				effect.get("pos", Vector2i(-1, -1)),
				String(effect.get("token_name", "")),
			)
			report.steps.append(step)
			report.total_score_delta += step.score_delta
			sequence_index += 1

	if report.steps.size() < _count_requested_steps(snapshot):
		report.warnings.append("settlement stopped early because a trigger limit was hit")

	return report

# ---------------------------------------------------------------------------
# 私有辅助
# ---------------------------------------------------------------------------

# 元素联动：扫描棋盘，按元素规则生成 row_column 阶段效果列表。
# - 火（fire_above_stack）：每个火token，统计其上方（row更小）其他火token数量N，获得 N*(N+1)/2 加分。
# - 水（water_below_stack）：每个水token，统计其下方（row更大）其他水token数量N，获得 N*(N+1)/2 加分。
# - 土（earth_row_bonus）：每个土token，同一行每有一个其他土token，+1。
# - 风（wind_col_bonus）：每个风token，同一列每有一个其他风token，+1。
func _build_element_effects(board: BoardService, registry: ContentRegistry) -> Array:
	var fire_positions: Array[Vector2i] = []
	var water_positions: Array[Vector2i] = []
	var earth_positions: Array[Vector2i] = []
	var wind_positions: Array[Vector2i] = []
	var pos_to_def_id: Dictionary = {}
	var pos_to_name: Dictionary = {}

	for row in board.height:
		for column in board.width:
			var pos := Vector2i(column, row)
			if not board.has_token(pos):
				continue
			var token = board.get_token(pos)
			if token.definition_id == EMPTY_TOKEN_ID:
				continue
			var def: TokenDefinition = registry.tokens.get(token.definition_id)
			if def == null:
				continue
			pos_to_def_id[pos] = token.definition_id
			pos_to_name[pos] = def.name
			var rules: Dictionary = def.trigger_rules
			if rules.get("fire_above_stack", false):
				fire_positions.append(pos)
			elif rules.get("water_below_stack", false):
				water_positions.append(pos)
			elif rules.get("earth_row_bonus", false):
				earth_positions.append(pos)
			elif rules.get("wind_col_bonus", false):
				wind_positions.append(pos)

	var effects: Array = []

	# 火：同列上方火token越多，累加奖励越高（三角数）
	for pos in fire_positions:
		var n := 0
		for other in fire_positions:
			if other.x == pos.x and other.y < pos.y:
				n += 1
		if n > 0:
			effects.append(_make_effect(pos_to_def_id[pos], "fire_above_stack", n * (n + 1) / 2, pos, pos_to_name[pos]))

	# 水：同列下方水token越多，累加奖励越高（三角数）
	for pos in water_positions:
		var n := 0
		for other in water_positions:
			if other.x == pos.x and other.y > pos.y:
				n += 1
		if n > 0:
			effects.append(_make_effect(pos_to_def_id[pos], "water_below_stack", n * (n + 1) / 2, pos, pos_to_name[pos]))

	# 土：同一行每有一个其他土token，+1
	for pos in earth_positions:
		var n := 0
		for other in earth_positions:
			if other != pos and other.y == pos.y:
				n += 1
		if n > 0:
			effects.append(_make_effect(pos_to_def_id[pos], "earth_row_bonus", n, pos, pos_to_name[pos]))

	# 风：同一列每有一个其他风token，+1
	for pos in wind_positions:
		var n := 0
		for other in wind_positions:
			if other != pos and other.x == pos.x:
				n += 1
		if n > 0:
			effects.append(_make_effect(pos_to_def_id[pos], "wind_col_bonus", n, pos, pos_to_name[pos]))

	return effects

# 被动道具效果：对每个符合元素类型的 token +1 分。
# active_item_defs 为 ItemDefinition 数组，只处理 effect_type == "passive" 的道具。
func _build_item_bonus_effects(board: BoardService, registry: ContentRegistry, active_item_defs: Array) -> Array:
	var effects: Array = []
	# 元素 → trigger_rules 键名映射
	const ELEMENT_RULE := {
		"fire":  "fire_above_stack",
		"water": "water_below_stack",
		"earth": "earth_row_bonus",
		"wind":  "wind_col_bonus",
	}
	for item_def in active_item_defs:
		if String(item_def.effect_type) != "passive":
			continue
		var element := String(item_def.effect_data.get("element", ""))
		var rule_key: String = ELEMENT_RULE.get(element, "")
		if rule_key.is_empty():
			continue
		for row in board.height:
			for col in board.width:
				var pos := Vector2i(col, row)
				if not board.has_token(pos):
					continue
				var token = board.get_token(pos)
				if token.definition_id == EMPTY_TOKEN_ID:
					continue
				var def: TokenDefinition = registry.tokens.get(token.definition_id)
				if def == null:
					continue
				if def.trigger_rules.get(rule_key, false):
					effects.append(_make_effect(token.definition_id, "item_bonus", 1, pos, def.name))
	return effects

func _make_effect(source_token: String, phase_name: String, score_delta: int, pos: Vector2i = Vector2i(-1, -1), token_name: String = "") -> Dictionary:
	return {
		"source_token": source_token,
		"target_token": source_token,
		"score_delta": score_delta,
		"message_key": phase_name,
		"pos": pos,
		"token_name": token_name,
	}

func _count_requested_steps(snapshot: RunSnapshot) -> int:
	var total := 0
	for phase in PHASES:
		total += snapshot.get_phase_effects(phase).size()
	return total
