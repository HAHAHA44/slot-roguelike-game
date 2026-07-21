# 主运行界面 / 人生模拟流程编排器（M1）：
# - 持有 ContentRegistry / RunSession / RingBoardService / ZodiacService /
#   LifeStageService / SettlementService。
# - 跑 yearly loop：出生（发起始 token 池）→ 洗牌投 12 格 → 真实 cascade 结算
#   → stub event（跳过，M2 实装）→ age++ → 寿命到顶自然死。
# - UI 层：HUD（出生/当年/年龄+寿命/精神/阶段/本命年标志）+ 12 格 ZodiacRing +
#   年度日志 ItemList + 「下一年 / 重新开始」按钮。
# - autoplay 路径保留（smoke test 用），默认关闭；玩家走主菜单进来时点按钮逐年推进。
extends Control

const RunSessionScript := preload("res://autoload/run_session.gd")
const ContentRegistryScript := preload("res://autoload/content_registry.gd")
const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")
const ZodiacServiceScript := preload("res://scripts/core/services/zodiac_service.gd")
const LifeStageServiceScript := preload("res://scripts/core/services/life_stage_service.gd")
const SettlementServiceScript := preload("res://scripts/core/services/settlement_service.gd")

# 起始 token 池的 id。池子构成在 content/run_start/default_pool.tres 里调，不在这里。
const DEFAULT_POOL_ID := "default_pool"
const DEFAULT_BIRTH_ZODIAC := "tiger"
const DEFAULT_LIFESPAN := 80
const LIFESPAN_MIN := 60
const LIFESPAN_MAX := 110
# 防止寿命设置错误时 autoplay 死循环；远高于人生模拟器最大寿命 110。
const AUTOPLAY_SAFETY_YEARS := 200

var run_session
var _content_registry
var _ring_board
var _zodiac_service
var _life_stage_service
var _settlement_service
var _yearly_log: Array[String] = []
var _alive: bool = false
# 最近一年的 CascadeReport。T1.6 的顺序点亮 / 数字弹跳会逐条回放它的 steps。
var _last_cascade_report = null

# 测试通过 _spawn() 显式置 true 跑 autoplay；玩家从主菜单进入时保持 false，等点按钮推进。
var autoplay_on_ready: bool = false

@onready var _birth_label: Label = %BirthLabel
@onready var _year_label: Label = %YearLabel
@onready var _age_label: Label = %AgeLabel
@onready var _sanity_label: Label = %SanityLabel
@onready var _stage_label: Label = %StageLabel
@onready var _birth_year_tag: Label = %BirthYearTag
@onready var _zodiac_ring = %ZodiacRing
@onready var _log_list: ItemList = %YearlyLogList
@onready var _step_button: Button = %StepButton
@onready var _death_label: Label = %DeathLabel

func _ready() -> void:
	_content_registry = ContentRegistryScript.new()
	_content_registry.load_all()
	_ring_board = RingBoardServiceScript.new()
	_zodiac_service = ZodiacServiceScript.new(_content_registry.zodiacs.values())
	_life_stage_service = LifeStageServiceScript.new(_content_registry.life_stages.values())
	_settlement_service = SettlementServiceScript.new(_content_registry.tokens)
	run_session = RunSessionScript.new()

	_zodiac_ring.bind_zodiac_service(_zodiac_service)
	_step_button.pressed.connect(_on_step_pressed)

	begin_run(DEFAULT_BIRTH_ZODIAC, DEFAULT_LIFESPAN)
	if autoplay_on_ready:
		autoplay_until_death(AUTOPLAY_SAFETY_YEARS)
	_refresh_all()

# -- public API（smoke test 依赖，签名不动） ---------------------------------

func begin_run(zodiac_birth: String, lifespan: int) -> void:
	run_session.age = 0
	run_session.lifespan = lifespan
	run_session.zodiac_birth = zodiac_birth
	run_session.sanity = 50
	run_session.stage_idx = 0
	run_session.stats = {}
	run_session.karma_in_run = 0
	run_session.token_pool = _draw_starting_pool()
	_alive = true
	_last_cascade_report = null
	_yearly_log.clear()
	_ring_board.clear_all()
	_log("出生：生肖 %s，寿命 %d 年，人生碎片 %d 张" %
		[zodiac_birth, lifespan, run_session.token_pool.size()])
	_refresh_all()

func step_year() -> void:
	if not _alive:
		return
	var year: int = run_session.age
	var current_zodiac = _zodiac_service.current_year_zodiac(year)
	var current_id: String = String(current_zodiac.id) if current_zodiac != null else ""
	var birth_hit: bool = _zodiac_service.is_birth_year(year, run_session.zodiac_birth)
	_populate_board()
	var report = _settlement_service.settle(_ring_board)
	_last_cascade_report = report
	for warning in report.warnings:
		push_warning("cascade（年 %d）：%s" % [year, warning])
	_stub_event_skip()
	_log("年 %d：当年生肖 %s，本命年命中: %s，cascade=%d，连击 %d" %
		[year, current_id, str(birth_hit), report.total_score, report.chain_count])
	run_session.age += 1
	if run_session.lifespan > 0 and run_session.age >= run_session.lifespan:
		_alive = false
		_log("自然死，享年 %d" % run_session.age)
	_refresh_all()

func autoplay_until_death(max_years: int) -> void:
	var safety: int = max_years
	while _alive and safety > 0:
		step_year()
		safety -= 1
	if _alive:
		push_warning("autoplay_until_death 触发 safety 上限 %d，未到自然死亡" % max_years)

func is_alive() -> bool:
	return _alive

func get_yearly_log() -> Array[String]:
	return _yearly_log.duplicate()

func get_current_age() -> int:
	return run_session.age

func get_ring_board():
	return _ring_board

func get_zodiac_service():
	return _zodiac_service

# 最近一年的 CascadeReport（未结算过则为 null）。T1.6 的顺序点亮回放从这里取 steps。
func get_last_cascade_report():
	return _last_cascade_report

# -- UI refresh --------------------------------------------------------------

func _refresh_all() -> void:
	# @onready 变量在 _ready body 执行前已绑定，因此即便从 _ready 内的 begin_run() 进来也安全。
	# 唯一不安全的路径是 begin_run 在 add_child 之前被调；那种情况下 _zodiac_service 也是 null，
	# 不只是 UI 出问题，由 caller 负责保证调用顺序。
	if _step_button == null:
		return
	_refresh_hud()
	_refresh_ring()
	_refresh_log()
	_refresh_button()

func _refresh_hud() -> void:
	var birth_z = _zodiac_service.get_by_id(run_session.zodiac_birth) if not run_session.zodiac_birth.is_empty() else null
	var birth_name: String = birth_z.get_display_name() if birth_z != null else "—"
	_birth_label.text = L10n.format_text("ui.run.hud.birth", {"zodiac": birth_name},
		"出生：%s" % birth_name)

	var current_year_index: int = run_session.age
	# 死亡后 age 已 ++，再渲染会越过寿命；clamp 在 lifespan-1 用作"最后一年"显示。
	if not _alive and current_year_index > 0:
		current_year_index = max(0, current_year_index - 1)
	var current_z = _zodiac_service.current_year_zodiac(current_year_index)
	var current_name: String = current_z.get_display_name() if current_z != null else "—"
	_year_label.text = L10n.format_text("ui.run.hud.year",
		{"age": current_year_index, "zodiac": current_name},
		"第 %d 年 · %s" % [current_year_index, current_name])

	_age_label.text = L10n.format_text("ui.run.hud.age",
		{"age": run_session.age, "lifespan": run_session.lifespan},
		"年龄 %d / 寿 %d" % [run_session.age, run_session.lifespan])

	_sanity_label.text = L10n.format_text("ui.run.hud.sanity",
		{"sanity": run_session.sanity},
		"精神 %d/100" % run_session.sanity)

	var stage = _life_stage_service.stage_for_age(run_session.age) if _life_stage_service != null else null
	var stage_name: String = stage.get_display_name() if stage != null else "—"
	_stage_label.text = L10n.format_text("ui.run.hud.stage", {"stage": stage_name},
		"阶段：%s" % stage_name)

	var birth_hit: bool = _zodiac_service.is_birth_year(current_year_index, run_session.zodiac_birth)
	_birth_year_tag.text = L10n.text("ui.run.hud.birth_year", "★ 本命年 ★") if birth_hit else ""

func _refresh_ring() -> void:
	if _zodiac_ring == null:
		return
	var current_slot: int = _zodiac_service.reward_slot_index(run_session.age) if _alive else -1
	if not _alive and run_session.age > 0:
		current_slot = _zodiac_service.reward_slot_index(run_session.age - 1)
	var birth_z = _zodiac_service.get_by_id(run_session.zodiac_birth)
	var birth_slot: int = int(birth_z.order) if birth_z != null else -1
	_zodiac_ring.refresh(_ring_board, current_slot, birth_slot)

func _refresh_log() -> void:
	_log_list.clear()
	for entry in _yearly_log:
		_log_list.add_item(entry)
	if _log_list.item_count > 0:
		_log_list.ensure_current_is_visible()
		_log_list.select(_log_list.item_count - 1)
		_log_list.ensure_current_is_visible()

func _refresh_button() -> void:
	if _alive:
		_step_button.text = L10n.text("ui.run.button.next_year", "下一年")
		_death_label.visible = false
		_death_label.text = ""
	else:
		_step_button.text = L10n.text("ui.run.button.restart", "重新开始")
		_death_label.text = L10n.format_text("ui.run.death.natural",
			{"age": run_session.age},
			"自然死，享年 %d。重新开始？" % run_session.age)
		_death_label.visible = true

# -- input handlers ----------------------------------------------------------

func _on_step_pressed() -> void:
	if _alive:
		step_year()
	else:
		_start_next_life()

func _start_next_life() -> void:
	# 重新开始：随机生肖 + 随机寿命（60-110），让每条人生有差异。
	var zodiac_ids: Array = []
	for z in _content_registry.zodiacs.values():
		zodiac_ids.append(String(z.id))
	zodiac_ids.sort()
	var next_zodiac: String = zodiac_ids[randi() % zodiac_ids.size()] if not zodiac_ids.is_empty() else DEFAULT_BIRTH_ZODIAC
	var next_lifespan: int = randi_range(LIFESPAN_MIN, LIFESPAN_MAX)
	begin_run(next_zodiac, next_lifespan)

# -- 投盘 --------------------------------------------------------------------

# 出生时发牌：把起始池的 token_ids 拷进 RunSession.token_pool。
# 池子构成是内容（content/run_start/），不是代码；这里只负责取。
func _draw_starting_pool() -> Array[String]:
	var pool: Array[String] = []
	var definition = _content_registry.starting_pools.get(DEFAULT_POOL_ID, null)
	if definition == null:
		# 内容缺失不该静默变成空盘——那会让每年 cascade=0，看起来像结算坏了。
		push_error("找不到起始 token 池「%s」，本局将没有任何人生碎片" % DEFAULT_POOL_ID)
		return pool
	for token_id in definition.token_ids:
		pool.append(String(token_id))
	return pool

# 每年把池子洗牌投上 12 格。池子多于 12 张时只投前 12 张，少于 12 张时剩余槽位留空
# （SettlementService 会跳过空槽）。M3 事件经济接管后池子才会在一生中增减。
func _populate_board() -> void:
	_ring_board.clear_all()
	var shuffled: Array = run_session.token_pool.duplicate()
	shuffled.shuffle()
	var count: int = mini(shuffled.size(), RingBoardServiceScript.RING_SIZE)
	for slot in count:
		_ring_board.place(slot, String(shuffled[slot]))

func _stub_event_skip() -> void:
	# stub：M2 加 EventDraftService（sanity 加权）+ EventResolverService。
	pass

func _log(line: String) -> void:
	_yearly_log.append(line)
	print("[Reelbound] %s" % line)
