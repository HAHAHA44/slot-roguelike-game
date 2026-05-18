# 主运行界面 / 人生模拟流程编排器（M0+）：
# - 持有 ContentRegistry / RunSession / RingBoardService / ZodiacService。
# - 当前只跑 stub yearly loop：出生 → 12 格生肖盘 stub 投放 → stub cascade（返回 0）
#   → stub event（跳过）→ age++ → 寿命到顶自然死。没有 UI 反馈，全靠 console + 日志数组。
# - 5×5 bag-roll path 已退役（M0 拆除）；旧的 settlement / reward / event / board_roll
#   服务文件仍保留在 scripts/core/services/ 作为 M1+ cascade 实现的参考蓝本。
# - run_screen.tscn 的旧 UI 节点（BoardGrid / TurnControls / EventDraftPanel ...）暂时无人
#   绑定；M1 起会被 cascade 视觉 + 精神条 + 年龄/寿命标识取代。
extends Control

const RunSessionScript := preload("res://autoload/run_session.gd")
const ContentRegistryScript := preload("res://autoload/content_registry.gd")
const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")
const ZodiacServiceScript := preload("res://scripts/core/services/zodiac_service.gd")

const DEFAULT_BIRTH_ZODIAC := "tiger"
const DEFAULT_LIFESPAN := 80
# 防止寿命设置错误时 autoplay 死循环；远高于人生模拟器最大寿命 110。
const AUTOPLAY_SAFETY_YEARS := 200

var run_session
var _content_registry
var _ring_board
var _zodiac_service
var _yearly_log: Array[String] = []
var _alive: bool = false

# 测试可以 set 此标志为 false 来阻止 _ready 自动跑完一生，改用 step_year() 手动驱动。
var autoplay_on_ready: bool = true

func _ready() -> void:
	_content_registry = ContentRegistryScript.new()
	_content_registry.load_all()
	_ring_board = RingBoardServiceScript.new()
	_zodiac_service = ZodiacServiceScript.new(_content_registry.zodiacs.values())
	run_session = RunSessionScript.new()
	begin_run(DEFAULT_BIRTH_ZODIAC, DEFAULT_LIFESPAN)
	if autoplay_on_ready:
		autoplay_until_death(AUTOPLAY_SAFETY_YEARS)

# -- public API ---------------------------------------------------------------

func begin_run(zodiac_birth: String, lifespan: int) -> void:
	run_session.age = 0
	run_session.lifespan = lifespan
	run_session.zodiac_birth = zodiac_birth
	run_session.sanity = 50
	run_session.stage_idx = 0
	run_session.stats = {}
	run_session.karma_in_run = 0
	_alive = true
	_yearly_log.clear()
	_ring_board.clear_all()
	_log("出生：生肖 %s，寿命 %d 年" % [zodiac_birth, lifespan])

func step_year() -> void:
	if not _alive:
		return
	var year: int = run_session.age
	var current_zodiac = _zodiac_service.current_year_zodiac(year)
	var current_id: String = String(current_zodiac.id) if current_zodiac != null else ""
	var birth_hit: bool = _zodiac_service.is_birth_year(year, run_session.zodiac_birth)
	_populate_board_stub()
	var cascade_score: int = _stub_cascade()
	_stub_event_skip()
	_log("年 %d：当年生肖 %s，本命年命中: %s，cascade=%d" %
		[year, current_id, str(birth_hit), cascade_score])
	run_session.age += 1
	if run_session.lifespan > 0 and run_session.age >= run_session.lifespan:
		_alive = false
		_log("自然死，享年 %d" % run_session.age)

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

# -- stub internals (M1+ 会替换为真实实现) ------------------------------------

func _populate_board_stub() -> void:
	# stub：把 12 生肖按 order 各放一格。M1 真实实现：从 RunSession.token_pool
	# 抽 12 张（含 padding empty）洗牌投放。
	_ring_board.clear_all()
	for slot in 12:
		var z = _zodiac_service.get_by_order(slot)
		if z == null:
			continue
		_ring_board.place(slot, String(z.id))

func _stub_cascade() -> int:
	# stub：M1 实现 SettlementService cascade min-score-first。
	return 0

func _stub_event_skip() -> void:
	# stub：M2 加 EventDraftService（sanity 加权）+ EventResolverService。
	pass

func _log(line: String) -> void:
	_yearly_log.append(line)
	print("[Reelbound] %s" % line)
