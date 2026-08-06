# 一次性内容生成器（开发工具，不参与游戏运行）。
#
# 为什么存在：本轮设计要铺 ~84 张阶段碎片 + 15 件传承物 + 12 条生肖年度规则 +
# 20 件道具 + 数十个事件 + 上百条金句。手写 .tres 既慢又容易在格式上出错，
# 而 ResourceSaver 保存出来的格式一定是引擎认的。
#
# **生成之后 .tres 就是唯一事实源**：要改一张碎片的数值，直接改它的 .tres，
# 不要回来改这个脚本再重跑（重跑会覆盖手改）。这个脚本的价值只在第一次铺量。
#
# 用法（仓库根目录）：
#   godot --headless --path . -s scripts/dev/generate_content.gd
extends SceneTree

const TablesScript := preload("res://scripts/dev/content_tables.gd")

const AddSelfScoreScript := preload("res://scripts/core/effects/add_self_score.gd")
const ModifyNeighborScript := preload("res://scripts/core/effects/modify_neighbor.gd")
const TriggerZodiacChainScript := preload("res://scripts/core/effects/trigger_zodiac_chain.gd")
const TokenDefinitionScript := preload("res://scripts/content/token_definition.gd")
const ItemDefinitionScript := preload("res://scripts/content/item_definition.gd")
const ZodiacDefinitionScript := preload("res://scripts/content/zodiac_definition.gd")
const BuffDefinitionScript := preload("res://scripts/content/buff_definition.gd")
const EventDefinitionScript := preload("res://scripts/content/event_definition.gd")
const EventChoiceScript := preload("res://scripts/content/event_choice.gd")
const FlavorLineScript := preload("res://scripts/content/flavor_line_definition.gd")
const StartingPoolScript := preload("res://scripts/content/starting_pool_definition.gd")

const TOKEN_DIR := "res://content/tokens"
const ITEM_DIR := "res://content/items"
const ZODIAC_DIR := "res://content/zodiac"
const BUFF_DIR := "res://content/buffs"
const EVENT_DIR := "res://content/events"
const FLAVOR_DIR := "res://content/flavor"
const RUN_START_DIR := "res://content/run_start"

# 每个阶段用 6 个生肖、每个生肖 2 张碎片——同生肖联动才有可能凑得起来。
# 12 张各配一个不同生肖的话，玩家几乎永远触发不了红线。
const ZODIAC_ORDER := ["rat", "ox", "tiger", "rabbit", "dragon", "snake",
	"horse", "goat", "monkey", "rooster", "dog", "pig"]
const DOMAINS := ["sport", "study", "art", "social", "wealth"]
const LEGACY_AFFINITY := {
	"sport": "tiger", "study": "dragon", "art": "rabbit",
	"social": "goat", "wealth": "rat",
}

var _written := 0

func _initialize() -> void:
	_ensure_dirs()
	_write_zodiacs()
	_write_tokens()
	_write_legacy_tokens()
	_write_filler_token()
	_write_items()
	_write_buffs()
	_write_events()
	_write_flavor_lines()
	_write_starting_pool()
	print("[generate_content] 共写出 %d 个 .tres" % _written)
	quit(0)

func _ensure_dirs() -> void:
	for dir_path in [TOKEN_DIR, ITEM_DIR, ZODIAC_DIR, BUFF_DIR, EVENT_DIR, FLAVOR_DIR, RUN_START_DIR]:
		DirAccess.make_dir_recursive_absolute(dir_path)

func _save(resource: Resource, dir_path: String, file_id: String) -> void:
	var path := "%s/%s.tres" % [dir_path, file_id]
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_error("写入失败 %s: %s" % [path, err])
		return
	_written += 1

# -- effect 解析 -------------------------------------------------------------

# "self:4" / "adj:2/60/1" / "zod:0/70"，多个用 | 连接。
func _parse_effects(spec: String) -> Array[ScriptableEffect]:
	var result: Array[ScriptableEffect] = []
	if spec.strip_edges().is_empty():
		return result
	for part in spec.split("|"):
		var chunk := String(part).strip_edges()
		if chunk.is_empty():
			continue
		var head := chunk.split(":")
		var kind := String(head[0])
		var args := String(head[1]).split("/") if head.size() > 1 else PackedStringArray()
		match kind:
			"self":
				var e := AddSelfScoreScript.new()
				e.amount = int(args[0])
				result.append(e)
			"adj":
				var e := ModifyNeighborScript.new()
				e.amount = int(args[0])
				e.percent = int(args[1]) if args.size() > 1 else 0
				e.radius = int(args[2]) if args.size() > 2 else 1
				result.append(e)
			"zod":
				var e := TriggerZodiacChainScript.new()
				e.amount = int(args[0])
				e.percent = int(args[1]) if args.size() > 1 else 0
				result.append(e)
			_:
				push_error("未知 effect 类型：%s" % kind)
	return result

# -- 生肖（含年度规则） ------------------------------------------------------

func _write_zodiacs() -> void:
	for entry in TablesScript.ZODIACS:
		var def := ZodiacDefinitionScript.new()
		def.id = String(entry["id"])
		def.display_name = String(entry["name"])
		def.order = int(entry["order"])
		def.rule_name = String(entry["rule_name"])
		def.rule_description = String(entry["rule_desc"])
		for key in entry.get("rule", {}):
			def.set(String(key), entry["rule"][key])
		_save(def, ZODIAC_DIR, def.id)

# -- 阶段碎片 ----------------------------------------------------------------

func _write_tokens() -> void:
	for stage_index in TablesScript.STAGE_IDS.size():
		var stage_id := String(TablesScript.STAGE_IDS[stage_index])
		var rows: Array = TablesScript.STAGE_TOKENS[stage_index]
		for i in rows.size():
			var row: Array = rows[i]
			var def := TokenDefinitionScript.new()
			def.id = String(row[0])
			def.name = String(row[1])
			def.description = String(row[2])
			def.domain = String(row[3])
			def.rarity = String(row[4])
			def.base_score = int(row[5])
			def.effects = _parse_effects(String(row[6]))
			def.stage_id = stage_id
			def.draft_weight = 1.0
			# 每个阶段用 6 个生肖、每肖 2 张：i/2 决定用第几个，阶段间错开 6 位。
			@warning_ignore("integer_division")
			var affinity_index: int = (stage_index * 6 + i / 2) % ZODIAC_ORDER.size()
			def.zodiac_affinity = String(ZODIAC_ORDER[affinity_index])
			if not def.domain.is_empty():
				def.legacy_into = "legacy_%s_1" % def.domain
			def.tags = PackedStringArray([def.domain] if not def.domain.is_empty() else [])
			_save(def, TOKEN_DIR, def.id)

# -- 传承物（每领域三环） ----------------------------------------------------

func _write_legacy_tokens() -> void:
	for domain in DOMAINS:
		var rings: Array = TablesScript.LEGACY_CHAINS[domain]
		for ring_index in rings.size():
			var row: Array = rings[ring_index]
			var ring := ring_index + 1
			var def := TokenDefinitionScript.new()
			def.id = "legacy_%s_%d" % [domain, ring]
			def.name = String(row[0])
			def.description = String(row[1])
			def.domain = String(domain)
			def.rarity = "Legendary"
			def.base_score = int(row[2])
			def.effects = _parse_effects(String(row[3]))
			def.stage_id = ""          # 传承物不属于任何阶段，所以不会被阶段清空
			def.is_legacy = true
			def.draft_weight = 0.0     # 也抽不到——只能靠练满星换来
			def.zodiac_affinity = String(LEGACY_AFFINITY[domain])
			# 三环封顶：最后一环没有下一环，链到此为止。
			def.legacy_into = "legacy_%s_%d" % [domain, ring + 1] if ring < rings.size() else ""
			def.tags = PackedStringArray([domain, "legacy"])
			_save(def, TOKEN_DIR, def.id)

# 补位碎片：命盘不满 12 张时顶上的那张。不属于任何阶段、抽不到、分低。
func _write_filler_token() -> void:
	var def := TokenDefinitionScript.new()
	def.id = "mundane"
	def.name = "凡庸"
	def.description = "无事发生的一格。"
	def.rarity = "Common"
	def.base_score = 1
	def.draft_weight = 0.0
	def.stage_id = ""
	def.tags = PackedStringArray(["mundane"])
	_save(def, TOKEN_DIR, def.id)

# -- 道具 --------------------------------------------------------------------

func _write_items() -> void:
	for row in TablesScript.ITEMS:
		var def := ItemDefinitionScript.new()
		def.id = String(row[0])
		def.name = String(row[1])
		def.description = String(row[2])
		def.domain = String(row[3])
		def.rarity = String(row[4])
		def.price = float(row[5])
		def.min_stage_order = int(row[6])
		def.max_stack = int(row[7])
		for key in row[8]:
			def.set(String(key), row[8][key])
		_save(def, ITEM_DIR, def.id)

# -- 开局 Buff / Debuff ------------------------------------------------------

func _write_buffs() -> void:
	for row in TablesScript.BUFFS:
		var def := BuffDefinitionScript.new()
		def.id = String(row[0])
		def.display_name = String(row[1])
		def.description = String(row[2])
		def.polarity = String(row[3])
		for key in row[4]:
			def.set(String(key), row[4][key])
		_save(def, BUFF_DIR, def.id)

# -- 事件 --------------------------------------------------------------------

func _write_events() -> void:
	for entry in TablesScript.EVENTS:
		var def := EventDefinitionScript.new()
		def.id = String(entry["id"])
		def.name = String(entry["name"])
		def.description = String(entry["desc"])
		def.kind = String(entry["kind"])
		def.stage_id = String(entry.get("stage", ""))
		def.birth_year_only = bool(entry.get("birth_year", false))
		def.spirit_weights = entry["weights"]
		def.karma_delta = int(entry.get("karma", 0))
		# 直接 append 到已定型的 def.choices：本脚本首次运行时 EventChoice 这个
		# class_name 还没进全局类缓存，写 Array[EventChoice] 会解析失败。
		def.choices.clear()
		for choice_entry in entry.get("choices", []):
			var choice = EventChoiceScript.new()
			choice.text = String(choice_entry["text"])
			for key in choice_entry:
				if key == "text":
					continue
				choice.set(String(key), choice_entry[key])
			def.choices.append(choice)
		_save(def, EVENT_DIR, def.id)

# -- 流水年金句 --------------------------------------------------------------

func _write_flavor_lines() -> void:
	for stage_index in TablesScript.STAGE_IDS.size():
		var stage_id := String(TablesScript.STAGE_IDS[stage_index])
		var buckets: Dictionary = TablesScript.FLAVOR[stage_index]
		for bucket in buckets:
			var lines: Array = buckets[bucket]
			for i in lines.size():
				var def := FlavorLineScript.new()
				def.id = "flavor_%s_%s_%d" % [stage_id, bucket, i]
				def.text = String(lines[i])
				def.stage_id = stage_id
				def.spirit_bucket = String(bucket)
				def.weight = 1.0
				_save(def, FLAVOR_DIR, def.id)

# -- 起始命盘 ----------------------------------------------------------------

func _write_starting_pool() -> void:
	var def := StartingPoolScript.new()
	def.id = "default_pool"
	def.display_name = "寻常人家"
	# 只发三张：童年头几年命盘几乎全是「凡庸」是有意的，那是成长曲线的起点。
	def.token_ids = PackedStringArray(["piggy_bank", "playmate", "picture_book"])
	def.filler_token_id = "mundane"
	_save(def, RUN_START_DIR, def.id)
