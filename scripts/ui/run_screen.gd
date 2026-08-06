# 主运行界面 / 人生模拟流程编排器。
#
# 一年的顺序（两条路径共用同一批 _year_* 私有方法，只是模态开不开）：
#   1 三选一抽碎片（可跳过）→ 自动合成升星
#   2 洗牌投 12 格 → cascade 结算 → 记年收益、算购买力
#   3 道具商店（每 12 年一次，见 is_shop_year）
#   4 年末事件：流水年滚一行金句 / 转折年弹窗做选择
#   5 属性漂移 → age++ → 阶段边界（考核 + 传承）→ 死亡判定
#
# 两条路径：
#   step_year()               同步全自动，autoplay 与测试走这条，决策用 _auto_* 策略
#   _advance_year_interactive() 协程，玩家路径，同样的顺序但每步开模态
# 保持两条路径共用 _year_* 是刻意的——让「测试跑的」和「玩家玩的」永远是同一段逻辑。
#
# 玩家路径上三选一**不在这条协程里**：它在上一年收尾后（或出生后）就自己弹出来，
# 玩家选完，「下一年」按下去直接开转。让抽牌先于按钮，是因为它是**决策**，
# 而按钮是**确认**——把决策塞进确认之后，玩家会觉得自己只是在点下一步。
#
# 本文件是 orchestrator：所有规则都在 services 里，这里只负责按顺序调用与呈现。
extends Control

const RunSessionScript := preload("res://autoload/run_session.gd")
const ContentRegistryScript := preload("res://autoload/content_registry.gd")
const RingBoardServiceScript := preload("res://scripts/core/services/ring_board_service.gd")
const ZodiacServiceScript := preload("res://scripts/core/services/zodiac_service.gd")
const LifeStageServiceScript := preload("res://scripts/core/services/life_stage_service.gd")
const SettlementServiceScript := preload("res://scripts/core/services/settlement_service.gd")
const AttributeServiceScript := preload("res://scripts/core/services/attribute_service.gd")
const BuffServiceScript := preload("res://scripts/core/services/buff_service.gd")
const DeckServiceScript := preload("res://scripts/core/services/deck_service.gd")
const DraftServiceScript := preload("res://scripts/core/services/draft_service.gd")
const MergeServiceScript := preload("res://scripts/core/services/merge_service.gd")
const EconomyServiceScript := preload("res://scripts/core/services/economy_service.gd")
const ShopServiceScript := preload("res://scripts/core/services/shop_service.gd")
const YearModifierServiceScript := preload("res://scripts/core/services/year_modifier_service.gd")
const SpiritServiceScript := preload("res://scripts/core/services/spirit_service.gd")
const EventDraftServiceScript := preload("res://scripts/core/services/event_draft_service.gd")
const EventResolverServiceScript := preload("res://scripts/core/services/event_resolver_service.gd")
const AgeServiceScript := preload("res://scripts/core/services/age_service.gd")
const DeathServiceScript := preload("res://scripts/core/services/death_service.gd")
const DeckPanelScript := preload("res://scripts/ui/deck_panel.gd")
const ShopPanelScript := preload("res://scripts/ui/shop_panel.gd")
const ModalChoicePanelScript := preload("res://scripts/ui/modal_choice_panel.gd")
const UiThemeScript := preload("res://scripts/ui/ui_theme.gd")

# 起始命盘的构成在 content/run_start/default_pool.tres 里调，不在这里。
const DEFAULT_POOL_ID := "default_pool"
const DEFAULT_BIRTH_ZODIAC := "tiger"
const DEFAULT_LIFESPAN := 80
const LIFESPAN_MIN := 60
const LIFESPAN_MAX := 110
# 一个人生阶段多少年。12 = 一次生肖轮回 = 一副命盘的抽取次数（ADR-0003 的四个 12 对齐）。
const STAGE_LENGTH := 12
const LAST_STAGE_ORDER := 6
# 阶段考核没过扣多少精神力。这是「业绩不达标」唯一的后果——
# 它不直接杀人，只是把死亡轮盘拧开一格（见 growth-loop-design 第 Q8 条）。
const STAGE_FAIL_SPIRIT_PENALTY := -4
const STAGE_PASS_SPIRIT_REWARD := 1
# 防止寿命设置错误时 autoplay 死循环；远高于最大寿命 110。
const AUTOPLAY_SAFETY_YEARS := 200

# -- 自动轮的节奏（秒） -------------------------------------------------------
# cascade 是本作最高优先级的视听事件（fun-axes P1/P2），它得**看得清**：
# 一格一格点亮时玩家要来得及读出是哪张碎片在连谁。这几个数是整条播放的总闸，
# 想整体快/慢只改这里，别散到各处 create_timer 里去。
const SPIN_SECONDS := 1.2
const CASCADE_STEP_SECONDS := 0.5
const CASCADE_HOLD_SECONDS := 1.0
const SCORE_FADE_SECONDS := 0.5

# 模态当前在演谁。三选一是**常驻连接 + 看这个开关**，事件走 _first_of 临时连接；
# 两者共用一个面板，不靠这个标记就会互相截胡对方的信号。
const MODAL_NONE := ""
const MODAL_DRAFT := "draft"
const MODAL_EVENT := "event"

var run_session
var _content_registry
var _ring_board
var _zodiac_service
var _life_stage_service
var _settlement_service
var _attribute_service
var _buff_service
var _deck_service
var _draft_service
var _merge_service
var _economy_service
var _shop_service
var _year_modifier_service
var _spirit_service
var _event_draft_service
var _event_resolver
var _age_service
var _death_service

# 按 polarity 分好的开局 Buff/Debuff 候选 id 池（_ready 里从 registry 分）。
var _buff_pool_ids: Array[String] = []
var _debuff_pool_ids: Array[String] = []
# 命盘不满 12 张时的补位碎片 id，出生时从起始池定义读进来（内容，不是常量）。
var _filler_token_id: String = ""
# 最近一年的 CascadeReport，UI 逐条回放它的 steps。
var _last_cascade_report = null
# 最近一次年度属性漂移结果 {"key","delta"}，供 UI 闪一下。
var _last_stat_drift: Dictionary = {}
# 本年的三选一候选 / 商店货架 / 待处理事件，交互路径与测试都读它们。
var _current_offer: Array = []
var _current_stock: Array = []
# 与 _current_stock 平行的「这格已经买走了」标记。买掉的货**留在架上置灰**，
# 不是抽走——架子塌下来玩家会以为自己看错了，也就再想不起这轮到底放弃了什么。
var _stock_sold: Array[bool] = []
var _pending_event = null
# 见 MODAL_* 常量。
var _modal_mode: String = MODAL_NONE
var _yearly_log: Array[String] = []
var _alive: bool = false
# 播放动画中：挡住重复点按；autoplay/测试路径永不进这里。
var _animating: bool = false

# 光效浮层（_ready 里代码建，盖在盘面上）。
var _score_pop: Label
var _chain_banner: Label
var _flash_rect: ColorRect
# 模态面板（代码建，盖在最上层）。
var _deck_panel
var _shop_panel
var _modal_panel

# 测试通过 _spawn() 显式置 true 跑 autoplay；玩家从主菜单进入时保持 false。
var autoplay_on_ready: bool = false

@onready var _bg_gradient: TextureRect = %BgGradient
@onready var _birth_label: Label = %BirthLabel
@onready var _year_label: Label = %YearLabel
@onready var _age_label: Label = %AgeLabel
@onready var _stage_label: Label = %StageLabel
@onready var _birth_year_tag: Label = %BirthYearTag
@onready var _zodiac_ring = %ZodiacRing
@onready var _status_panel = %StatusPanel
@onready var _log_list: ItemList = %YearlyLogList
@onready var _step_button: Button = %StepButton
@onready var _death_label: Label = %DeathLabel
@onready var _deck_button: Button = %BackpackButton

func _ready() -> void:
	_content_registry = ContentRegistryScript.new()
	_content_registry.load_all()
	_ring_board = RingBoardServiceScript.new()
	_zodiac_service = ZodiacServiceScript.new(_content_registry.zodiacs.values())
	_life_stage_service = LifeStageServiceScript.new(_content_registry.life_stages.values())
	_settlement_service = SettlementServiceScript.new(_content_registry.tokens)
	_attribute_service = AttributeServiceScript.new()
	_buff_service = BuffServiceScript.new()
	_deck_service = DeckServiceScript.new()
	_draft_service = DraftServiceScript.new()
	_merge_service = MergeServiceScript.new()
	_economy_service = EconomyServiceScript.new()
	_shop_service = ShopServiceScript.new()
	_year_modifier_service = YearModifierServiceScript.new()
	_spirit_service = SpiritServiceScript.new()
	_event_draft_service = EventDraftServiceScript.new()
	_event_resolver = EventResolverServiceScript.new(_deck_service)
	_age_service = AgeServiceScript.new()
	_death_service = DeathServiceScript.new()
	_split_buff_pools()
	run_session = RunSessionScript.new()

	theme = UiThemeScript.build()
	if _bg_gradient != null:
		_bg_gradient.texture = UiThemeScript.background_gradient()

	_zodiac_ring.bind_content(_zodiac_service, _content_registry.tokens)
	if _status_panel != null:
		_status_panel.bind_content(_content_registry.buffs)
	_build_fx_overlays()
	_build_modals()
	_step_button.pressed.connect(_on_step_pressed)
	_deck_button.pressed.connect(_on_deck_pressed)

	begin_run(DEFAULT_BIRTH_ZODIAC, DEFAULT_LIFESPAN)
	if autoplay_on_ready:
		autoplay_until_death(AUTOPLAY_SAFETY_YEARS)
	else:
		# 玩家路径：出生完第一件事就是抽牌，不用先点一下按钮才等到选择。
		open_year_draft()
	_refresh_all()

# -- public API --------------------------------------------------------------

func begin_run(zodiac_birth: String, lifespan: int) -> void:
	run_session = RunSessionScript.new()
	run_session.lifespan = lifespan
	run_session.zodiac_birth = zodiac_birth
	# 婴儿出生：10 点随机撒到六维，精神力另加出生基线。
	_attribute_service.roll_initial(run_session)
	_last_stat_drift = {}
	# 起始命盘：内容在 content/run_start/，这里只负责取。
	_draw_starting_pool()
	# 开局按运气抽 Buff/Debuff，然后**当场结算**（它们是出生条件，不是常驻被动）。
	var luck: int = run_session.stat(AttributeServiceScript.LUCK_KEY)
	_buff_service.roll(run_session, luck, _buff_pool_ids, _debuff_pool_ids)
	var buff_notes: Array = _buff_service.apply(run_session, _content_registry.buffs, _deck_service)
	_merge_service.auto_merge(run_session)

	_alive = true
	_last_cascade_report = null
	_current_offer = []
	_current_stock = []
	_stock_sold = []
	_pending_event = null
	_yearly_log.clear()
	_ring_board.clear_all()
	_log("出生：生肖 %s，寿命 %d 年，命盘 %d 张" %
		[zodiac_birth, run_session.lifespan, run_session.board_cards.size()])
	if not buff_notes.is_empty():
		_log("投胎携带：%s" % "、".join(buff_notes))
	_close_all_modals()
	_refresh_all()

# 同步跑完一整年。autoplay 与测试走这条，所有决策用 _auto_* 策略。
func step_year() -> void:
	if not _alive:
		return
	_year_draft(true)
	_year_cascade()
	_year_shop(true)
	_year_event(true)
	_year_close()
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

func get_last_cascade_report():
	return _last_cascade_report

func get_deck_panel():
	return _deck_panel

func get_shop_panel():
	return _shop_panel

func get_modal_panel():
	return _modal_panel

func get_current_offer() -> Array:
	return _current_offer.duplicate()

func get_current_stock() -> Array:
	return _current_stock.duplicate()

# 与 get_current_stock() 平行的「已购入」标记。
func get_stock_sold() -> Array[bool]:
	return _stock_sold.duplicate()

func get_pending_event():
	return _pending_event

func get_filler_token_id() -> String:
	return _filler_token_id

func get_stage_order() -> int:
	@warning_ignore("integer_division")
	var order: int = int(run_session.age) / STAGE_LENGTH
	return mini(order, LAST_STAGE_ORDER)

func get_stage_id() -> String:
	var stage = _life_stage_service.get_by_order(get_stage_order())
	return String(stage.id) if stage != null else ""

func get_stage_threshold() -> int:
	return _economy_service.threshold_for_stage(get_stage_order())

func get_spirit_bucket() -> String:
	return _spirit_service.bucket(run_session)

# -- 年循环各步（两条路径共用） ----------------------------------------------

# 1 三选一。auto=true 时按策略自动取舍；否则只准备候选，等模态回调。
func _year_draft(auto: bool) -> void:
	_current_offer = _draft_service.roll_offer(run_session, _content_registry.tokens, get_stage_id())
	if auto:
		var index := _auto_pick_draft()
		if index >= 0:
			_take_draft(index)

# 真正拿一张。命盘和行囊都满时拿不了——调用方应先让玩家弃牌。
func _take_draft(index: int) -> bool:
	if index < 0 or index >= _current_offer.size():
		return false
	var definition_id := String(_current_offer[index])
	if not _deck_service.acquire(run_session, definition_id):
		return false
	var merges: Array = _merge_service.auto_merge(run_session)
	var def = _content_registry.tokens.get(definition_id, null)
	var display: String = def.get_display_name() if def != null else definition_id
	if merges.is_empty():
		_log("获得碎片：%s" % display)
	else:
		var last: Dictionary = merges[merges.size() - 1]
		_log("获得碎片：%s → 合成 %d 星！" % [display, int(last["to_star"])])
	_current_offer = []
	return true

# 2 投盘 + 结算。
func _year_cascade() -> void:
	var year: int = run_session.age
	var current_zodiac = _zodiac_service.current_year_zodiac(year)
	var birth_hit: bool = _zodiac_service.is_birth_year(year, run_session.zodiac_birth)
	_ring_board.fill_from_board_cards(run_session.board_cards, _filler_token_id)
	var mods = _year_modifier_service.build(run_session, current_zodiac, birth_hit,
		_content_registry.items)
	var report = _settlement_service.settle(_ring_board, mods)
	_last_cascade_report = report
	for warning in report.warnings:
		push_warning("cascade（年 %d）：%s" % [year, warning])

	run_session.stage_income.append(int(report.total_score))
	run_session.purchasing_power += _economy_service.purchasing_power(
		int(report.total_score), get_stage_threshold())

	var zodiac_id: String = String(current_zodiac.id) if current_zodiac != null else ""
	var rule_name: String = String(current_zodiac.get_rule_name()) if current_zodiac != null else ""
	_log("年 %d：%s%s，cascade=%d，连击 %d" % [year, zodiac_id,
		("（%s）" % rule_name) if not rule_name.is_empty() else "",
		report.total_score, report.chain_count])
	if birth_hit:
		_log("★ 本命年：同生肖联动翻倍，年收益 ×1.5")

# 3 商店。每 12 年才开一次（见 is_shop_year），auto=true 时自动买到买不动为止。
func _year_shop(auto: bool) -> void:
	_current_stock = []
	_stock_sold = []
	if not is_shop_year():
		return
	_current_stock = _shop_service.roll_stock(run_session, _content_registry.items, get_stage_order())
	# 一件都上不了架（全买满上限了）就当今年没开门：没得挑，就不该没收攒下的购买力。
	if _current_stock.is_empty():
		return
	_stock_sold.resize(_current_stock.size())
	if not auto:
		return
	var guard := 0
	while guard < ShopServiceScript.OFFER_SIZE:
		var index := _auto_pick_purchase()
		if index < 0:
			break
		_buy_from_stock(index)
		guard += 1
	_end_shopping()

# 商店年 = 一个人生阶段的最后一年。购买力这十二年一直在攒，开在末尾才买得动；
# 而且这一年买下的道具，接下来整个阶段都在生效。
func is_shop_year() -> bool:
	return run_session.age % STAGE_LENGTH == STAGE_LENGTH - 1

func _buy_from_stock(index: int) -> bool:
	if index < 0 or index >= _current_stock.size():
		return false
	if bool(_stock_sold[index]):
		return false
	var def = _current_stock[index]
	if not _shop_service.buy(run_session, def):
		return false
	_log("购入道具：%s（%s）" % [def.get_display_name(), def.describe_effect()])
	_stock_sold[index] = true
	return true

# 逛完就走：剩余购买力作废。攒钱在这个游戏里没有叙事意义（你攒的是「这些年过得
# 好不好」，攒不到下辈子），作废逼玩家在这一次里把取舍做完。
func _end_shopping() -> void:
	run_session.purchasing_power = 0.0

# 4 年末事件。流水年只滚金句；转折年抽事件，auto=true 时自动选一个非致死选项。
func _year_event(auto: bool) -> void:
	_pending_event = null
	var bucket := get_spirit_bucket()
	var stage_id := get_stage_id()
	var flavor = _event_draft_service.pick_flavor(_content_registry.flavor_lines, stage_id, bucket)
	if flavor != null:
		_log(flavor.get_display_text())

	var birth_hit: bool = _zodiac_service.is_birth_year(run_session.age, run_session.zodiac_birth)
	if not _event_draft_service.should_trigger(bucket, birth_hit):
		return
	var current_zodiac = _zodiac_service.current_year_zodiac(run_session.age)
	var zodiac_id: String = String(current_zodiac.id) if current_zodiac != null else ""
	_pending_event = _event_draft_service.draft_event(_content_registry.events, stage_id,
		bucket, zodiac_id, birth_hit)
	if _pending_event != null and auto:
		_resolve_event(_auto_pick_choice(_pending_event))

func _resolve_event(choice_index: int) -> void:
	if _pending_event == null:
		return
	var event = _pending_event
	_pending_event = null
	var outcome: Dictionary = _event_resolver.resolve(run_session, event, choice_index)
	var notes: Array = outcome["notes"]
	var suffix: String = ("（%s）" % "，".join(notes)) if not notes.is_empty() else ""
	_log("· %s%s" % [event.get_display_name(), suffix])
	if bool(outcome["lethal"]):
		_die(_death_service.cause_name(DeathServiceScript.Cause.LETHAL_EVENT),
			"死于：%s" % event.get_display_name())

# 5 收尾：属性漂移 → age++ → 阶段边界 → 寿命判定。
func _year_close() -> void:
	if not _alive:
		return
	_last_stat_drift = _attribute_service.apply_yearly_drift(run_session, run_session.age)
	_age_service.advance(run_session)
	if run_session.age % STAGE_LENGTH == 0:
		_close_stage()
	if _alive and _age_service.is_natural_death(run_session):
		_die(_death_service.cause_name(DeathServiceScript.Cause.NATURAL),
			"自然死，享年 %d" % run_session.age)

# 阶段边界：先考核（没过扣精神力），再传承（满星者进化），最后清空当期碎片。
func _close_stage() -> void:
	@warning_ignore("integer_division")
	var elapsed_stages: int = int(run_session.age) / STAGE_LENGTH
	var finished_order: int = mini(elapsed_stages - 1, LAST_STAGE_ORDER)
	var review: Dictionary = _economy_service.stage_review(run_session, finished_order)
	if bool(review["passed"]):
		_spirit_service.add(run_session, STAGE_PASS_SPIRIT_REWARD)
		_log("阶段考核通过：%d / %d" % [int(review["income"]), int(review["threshold"])])
	else:
		_spirit_service.add(run_session, STAGE_FAIL_SPIRIT_PENALTY)
		_log("阶段考核未过：%d / %d，精神力 %d" %
			[int(review["income"]), int(review["threshold"]), STAGE_FAIL_SPIRIT_PENALTY])

	var ascensions: Array = _deck_service.end_stage(run_session, _content_registry.tokens)
	for ascension in ascensions:
		var into_def = _content_registry.tokens.get(String(ascension["into"]), null)
		var into_name: String = into_def.get_display_name() if into_def != null else String(ascension["into"])
		_log("传承：在%s上有所建树 → %s（第 %d 环）" %
			[L10n.text("ui.domain.%s" % ascension["domain"], String(ascension["domain"])),
			into_name, int(ascension["ring"])])
	run_session.stage_income.clear()
	run_session.stage_idx = get_stage_order()

func _die(cause: String, message: String) -> void:
	_alive = false
	run_session.death_cause = cause
	_log(message)

# -- 自动决策策略（autoplay / 测试；玩家路径不经过这里） -----------------------

# 优先补齐能凑星的同名碎片，其次挑进盘分最高的。装不下就跳过。
func _auto_pick_draft() -> int:
	if _current_offer.is_empty() or not _deck_service.has_room(run_session):
		return -1
	var best_index := -1
	var best_score := -1.0
	for i in _current_offer.size():
		var def = _content_registry.tokens.get(String(_current_offer[i]), null)
		if def == null:
			continue
		var score := float(def.base_score)
		if _owned_count(String(_current_offer[i])) > 0:
			score += 100.0  # 凑星的价值远高于单张分数
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _owned_count(definition_id: String) -> int:
	var count := 0
	for card in run_session.all_cards():
		if card != null and String(card.definition_id) == definition_id:
			count += 1
	return count

# 买得起的里面挑最贵的：贵的乘区大，而购买力离开时作废，留着没有意义。
func _auto_pick_purchase() -> int:
	var best_index := -1
	var best_price := -1.0
	for i in _current_stock.size():
		if bool(_stock_sold[i]):
			continue
		var def = _current_stock[i]
		if not _shop_service.can_afford(run_session, def):
			continue
		if float(def.price) > best_price:
			best_price = float(def.price)
			best_index = i
	return best_index

# 挑第一个非致死选项；全是致死（真正的绝境事件）才选 0。
func _auto_pick_choice(event) -> int:
	for i in event.choices.size():
		if not bool(event.choices[i].lethal):
			return i
	return 0

# -- 玩家交互路径（协程） ----------------------------------------------------

func _on_step_pressed() -> void:
	if _animating:
		return
	if _alive:
		_advance_year_interactive()
	else:
		_start_next_life()

# 「下一年」按下去 = 直接开转。三选一在这之前就选完了（出生后 / 上一年收尾时弹的），
# 所以这条协程从投盘开始，一路演到年末。
func _advance_year_interactive() -> void:
	_animating = true
	_set_controls_enabled(false)
	# 玩家没理会三选一就按了下一年 —— 当作「都不要」，别把选择窗留到下一年。
	if _modal_mode == MODAL_DRAFT:
		_close_draft()

	_year_cascade()
	_refresh_all()
	await _zodiac_ring.play_spin(SPIN_SECONDS)
	await _play_cascade_fx(_last_cascade_report)

	_year_shop(false)
	if not _current_stock.is_empty():
		await _await_shop()

	_year_event(false)
	if _pending_event != null:
		await _await_event_choice()

	_year_close()
	_animating = false
	_set_controls_enabled(true)
	_refresh_all()
	# 下一年的三选一立刻摆上来，玩家一抬头就在做下一个决定。
	if _alive:
		open_year_draft()

# -- 三选一（不走协程：它不是年循环里的一步，是年与年之间的那个决定） ----------
#
# 用「常驻信号连接 + _modal_mode 开关」而不是 await：await 会在 begin_run 打断时
# 留下一条永远停在等信号处的协程，下次玩家一点选项，新旧两条一起醒过来。
# 三选一恰恰是最容易被打断的那个（重开一局就打断了），所以它必须是无状态的回调。
func open_year_draft() -> void:
	if not _alive or _modal_panel == null:
		return
	_year_draft(false)
	if _current_offer.is_empty():
		return
	var has_room: bool = _deck_service.has_room(run_session)
	var options: Array = []
	for definition_id in _current_offer:
		options.append(_draft_option(String(definition_id), has_room))
	var skip_text: String = L10n.text("ui.draft.skip", "都不要")
	if not has_room:
		skip_text = L10n.text("ui.draft.full", "命盘与行囊都满了——只能跳过")
	_modal_mode = MODAL_DRAFT
	_modal_panel.open_with(L10n.text("ui.draft.title", "三选一"),
		L10n.text("ui.draft.body", "拿一张，或者什么都不要。"), options, skip_text)

func _draft_option(definition_id: String, has_room: bool) -> Dictionary:
	var def = _content_registry.tokens.get(definition_id, null)
	if def == null:
		return {"text": definition_id, "subtext": ""}
	var progress: Dictionary = _merge_service.progress_for(run_session, definition_id)
	var merge_hint: String = ""
	if not progress.is_empty():
		merge_hint = L10n.format_text("ui.draft.merge_hint",
			{"have": progress["have"], "need": progress["need"]},
			"（已有 %d/%d）" % [progress["have"], progress["need"]])
	return {
		"text": "%s%s" % [def.get_display_name(), merge_hint],
		"subtext": "%s · 基础分 %d · %s" % [def.get_display_domain(), def.base_score,
			_effects_summary(def)],
		"disabled": not has_room,
		"icon": def.icon,
	}

func _close_draft() -> void:
	_modal_mode = MODAL_NONE
	_current_offer = []
	if _modal_panel != null:
		_modal_panel.close()

# 面板的两个信号是常驻连接的，事件模态也走同一个面板——所以这里必须先认模式，
# 不是三选一就交给 _first_of 那边处理。
func _on_modal_chosen(index: int) -> void:
	if _modal_mode != MODAL_DRAFT:
		return
	_take_draft(index)
	_close_draft()
	_refresh_all()

func _on_modal_skipped() -> void:
	if _modal_mode != MODAL_DRAFT:
		return
	_close_draft()
	_refresh_all()

func _await_shop() -> void:
	_shop_panel.open(_current_stock, run_session.purchasing_power, _stock_sold)
	while true:
		var index: int = await _await_shop_action()
		if index < 0:
			break
		_buy_from_stock(index)
		_shop_panel.refresh(_current_stock, run_session.purchasing_power, _stock_sold)
		_refresh_all()
	_shop_panel.close()
	_end_shopping()
	_refresh_all()

func _await_event_choice() -> void:
	var event = _pending_event
	var options: Array = []
	for choice in event.choices:
		options.append({"text": choice.get_display_text(), "subtext": ""})
	var skip_text := "" if not event.choices.is_empty() else L10n.text("ui.event.ack", "知道了")
	_modal_mode = MODAL_EVENT
	_modal_panel.open_with(event.get_display_name(), event.get_display_description(),
		options, skip_text)
	var index: int = await _await_modal()
	_modal_mode = MODAL_NONE
	_modal_panel.close()
	_resolve_event(index)
	_refresh_all()

# 等模态回一个下标；跳过回 -1。两个信号只会有一个先到。
func _await_modal() -> int:
	var chosen_index: int = await _first_of(_modal_panel.chosen, _modal_panel.skipped)
	return chosen_index

func _await_shop_action() -> int:
	return await _first_of(_shop_panel.buy_requested, _shop_panel.closed)

# 等两个信号中先到的那个：带参数的返回其参数，不带参数的返回 -1。
#
# 状态放在一个数组里而不是两个局部变量，是**必须**的：GDScript 的 lambda
# 按值捕获局部变量，在 lambda 里写 `done = true` 改不动外层那个 done，
# 下面的 while 会永远转下去。数组是引用类型，改它才穿得透。
func _first_of(with_arg: Signal, without_arg: Signal) -> int:
	var state: Array = [false, -1]   # [是否已收到, 返回值]
	var on_arg := func(value: int) -> void:
		if not bool(state[0]):
			state[0] = true
			state[1] = value
	var on_plain := func() -> void:
		if not bool(state[0]):
			state[0] = true
			state[1] = -1
	with_arg.connect(on_arg)
	without_arg.connect(on_plain)
	while not bool(state[0]):
		await get_tree().process_frame
	with_arg.disconnect(on_arg)
	without_arg.disconnect(on_plain)
	return int(state[1])

func _effects_summary(def) -> String:
	var parts: Array[String] = []
	for effect in def.effects:
		if effect == null:
			continue
		var line := String(effect.describe())
		if not line.is_empty():
			parts.append(line)
	if parts.is_empty():
		return L10n.text("ui.draft.no_effect", "无联动")
	return "；".join(parts)

func _start_next_life() -> void:
	var zodiac_ids: Array = []
	for z in _content_registry.zodiacs.values():
		zodiac_ids.append(String(z.id))
	zodiac_ids.sort()
	var next_zodiac: String = zodiac_ids[randi() % zodiac_ids.size()] \
		if not zodiac_ids.is_empty() else DEFAULT_BIRTH_ZODIAC
	begin_run(next_zodiac, randi_range(LIFESPAN_MIN, LIFESPAN_MAX))
	open_year_draft()

func _on_deck_pressed() -> void:
	if _deck_panel == null:
		return
	if _deck_panel.is_open():
		_deck_panel.close()
	else:
		_deck_panel.open(run_session)

func _set_controls_enabled(enabled: bool) -> void:
	_step_button.disabled = not enabled
	_deck_button.disabled = not enabled

# -- 出生 --------------------------------------------------------------------

func _split_buff_pools() -> void:
	_buff_pool_ids = []
	_debuff_pool_ids = []
	for buff in _content_registry.buffs.values():
		if buff == null:
			continue
		if buff.is_buff():
			_buff_pool_ids.append(String(buff.id))
		else:
			_debuff_pool_ids.append(String(buff.id))

# 出生发牌：把起始池的碎片放进命盘。池子构成是内容，不是代码。
func _draw_starting_pool() -> void:
	_filler_token_id = ""
	var definition = _content_registry.starting_pools.get(DEFAULT_POOL_ID, null)
	if definition == null:
		push_error("找不到起始池「%s」，本局将从空命盘开始" % DEFAULT_POOL_ID)
		return
	_filler_token_id = String(definition.filler_token_id)
	for token_id in definition.token_ids:
		_deck_service.acquire(run_session, String(token_id))

# -- UI refresh --------------------------------------------------------------

func _refresh_all() -> void:
	if _step_button == null:
		return
	_refresh_hud()
	_refresh_ring()
	_refresh_status_panel()
	_refresh_log()
	_refresh_button()
	_refresh_deck_button()

func _refresh_hud() -> void:
	var birth_z = _zodiac_service.get_by_id(run_session.zodiac_birth) \
		if not run_session.zodiac_birth.is_empty() else null
	var birth_name: String = birth_z.get_display_name() if birth_z != null else "—"
	_birth_label.text = L10n.format_text("ui.run.hud.birth", {"zodiac": birth_name},
		"出生：%s" % birth_name)

	var current_year_index: int = run_session.age
	# 死亡后 age 已 ++，再渲染会越过寿命；clamp 在最后一年。
	if not _alive and current_year_index > 0:
		current_year_index = max(0, current_year_index - 1)
	var current_z = _zodiac_service.current_year_zodiac(current_year_index)
	var current_name: String = current_z.get_display_name() if current_z != null else "—"
	# 规则名形如「狗·守夜」，本身已含生肖字，所以有规则时不再重复写生肖名。
	var rule_name: String = String(current_z.get_rule_name()) if current_z != null else ""
	var year_tag: String = rule_name if not rule_name.is_empty() else current_name
	_year_label.text = L10n.format_text("ui.run.hud.year",
		{"age": current_year_index, "rule": year_tag},
		"第 %d 年 · %s" % [current_year_index, year_tag])

	_age_label.text = L10n.format_text("ui.run.hud.age",
		{"age": run_session.age, "lifespan": run_session.lifespan},
		"年龄 %d / 寿 %d" % [run_session.age, run_session.lifespan])

	var stage = _life_stage_service.stage_for_age(run_session.age)
	var stage_name: String = stage.get_display_name() if stage != null else "—"
	var last_income: int = int(run_session.stage_income[run_session.stage_income.size() - 1]) \
		if not run_session.stage_income.is_empty() else 0
	_stage_label.text = L10n.format_text("ui.run.hud.stage",
		{"stage": stage_name, "income": last_income, "threshold": get_stage_threshold()},
		"%s · 考核 %d/%d" % [stage_name, last_income, get_stage_threshold()])

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

func _refresh_status_panel() -> void:
	if _status_panel == null:
		return
	_status_panel.refresh(run_session)

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
		_death_label.text = L10n.format_text("ui.run.death.summary",
			{"age": run_session.age},
			"享年 %d。重新开始？" % run_session.age)
		_death_label.visible = true

func _refresh_deck_button() -> void:
	if _deck_button == null:
		return
	_deck_button.text = L10n.format_text("ui.run.button.deck",
		{"board": run_session.board_cards.size(), "bench": run_session.bench_cards.size()},
		"命盘 %d · 行囊 %d" % [run_session.board_cards.size(), run_session.bench_cards.size()])
	if _deck_panel != null and _deck_panel.is_open():
		_deck_panel.refresh(run_session)

# -- 模态与光效浮层 ----------------------------------------------------------

func _build_modals() -> void:
	_deck_panel = DeckPanelScript.new()
	add_child(_deck_panel)
	_deck_panel.bind_content(_content_registry.tokens, _merge_service, _content_registry.items)
	_deck_panel.swap_requested.connect(_on_swap_requested)
	_deck_panel.promote_requested.connect(_on_promote_requested)
	_deck_panel.demote_requested.connect(_on_demote_requested)

	_shop_panel = ShopPanelScript.new()
	add_child(_shop_panel)

	_modal_panel = ModalChoicePanelScript.new()
	add_child(_modal_panel)
	# 三选一常驻接这两个信号；事件模态期间靠 _modal_mode 让它们让路。
	_modal_panel.chosen.connect(_on_modal_chosen)
	_modal_panel.skipped.connect(_on_modal_skipped)

func _close_all_modals() -> void:
	_modal_mode = MODAL_NONE
	if _deck_panel != null:
		_deck_panel.close()
	if _shop_panel != null:
		_shop_panel.close()
	if _modal_panel != null:
		_modal_panel.close()

func _on_swap_requested(board_index: int, bench_index: int) -> void:
	if _deck_service.swap(run_session, board_index, bench_index):
		_refresh_all()

func _on_promote_requested(bench_index: int) -> void:
	if _deck_service.promote(run_session, bench_index):
		_refresh_all()

func _on_demote_requested(board_index: int) -> void:
	if _deck_service.demote(run_session, board_index):
		_refresh_all()

# 连击 banner 从 3 连击起常驻显示，5 / 10 / 20 / 50 各跨一档。
const COMBO_MIN := 3
const COMBO_TIERS := [
	{"min": 3, "color": Color("4cd98c"), "pop": 1.28, "font": 28, "flash": 0.0},
	{"min": 5, "color": Color("6be5ff"), "pop": 1.42, "font": 33, "flash": 0.18},
	{"min": 10, "color": Color("ffd23f"), "pop": 1.58, "font": 38, "flash": 0.26},
	{"min": 20, "color": Color("ff8a3d"), "pop": 1.74, "font": 43, "flash": 0.34},
	{"min": 50, "color": Color("ff3b3b"), "pop": 1.92, "font": 48, "flash": 0.5},
]

func _build_fx_overlays() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 0.95, 0.75, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)

	_score_pop = Label.new()
	_score_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_pop.add_theme_font_size_override("font_size", 46)
	_score_pop.add_theme_color_override("font_color", UiThemeScript.GOLD)
	_score_pop.visible = false
	add_child(_score_pop)

	_chain_banner = Label.new()
	_chain_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chain_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_banner.add_theme_font_size_override("font_size", 28)
	_chain_banner.add_theme_color_override("font_color", UiThemeScript.TEAL)
	_chain_banner.visible = false
	add_child(_chain_banner)

func _play_cascade_fx(report) -> void:
	var steps: Array = report.steps if report != null else []
	var total: int = int(report.total_score) if report != null else 0
	if steps.is_empty():
		return
	_position_fx_over_ring()
	_score_pop.visible = true
	_score_pop.modulate = Color(1, 1, 1, 1)
	_chain_banner.visible = false
	var count := steps.size()
	var shown_combo := 0
	var shown_tier := -1
	for i in count:
		var step = steps[i]
		_zodiac_ring.highlight_step(step)
		_set_score_pop(int(round(float(total) * float(i + 1) / float(count))))
		var chain_after := int(step.chain_count_after)
		if chain_after >= COMBO_MIN and chain_after > shown_combo:
			shown_combo = chain_after
			var tier := _combo_tier_index(chain_after)
			_show_chain_banner(chain_after, tier)
			if tier > shown_tier:
				var flash_amt: float = float(COMBO_TIERS[tier]["flash"])
				if flash_amt > 0.0:
					_flash(flash_amt)
				shown_tier = tier
		await get_tree().create_timer(CASCADE_STEP_SECONDS).timeout
	_set_score_pop(total)
	_zodiac_ring.clear_highlight()
	await get_tree().create_timer(CASCADE_HOLD_SECONDS).timeout
	await _fade_out(_score_pop, SCORE_FADE_SECONDS)
	if _chain_banner.visible:
		await _fade_out(_chain_banner, SCORE_FADE_SECONDS)

func _combo_tier_index(count: int) -> int:
	var idx := 0
	for i in COMBO_TIERS.size():
		if count >= int(COMBO_TIERS[i]["min"]):
			idx = i
	return idx

func _position_fx_over_ring() -> void:
	var ring_rect: Rect2 = _zodiac_ring.get_global_rect()
	var c: Vector2 = ring_rect.get_center()
	_score_pop.size = Vector2(320, 72)
	_score_pop.pivot_offset = _score_pop.size * 0.5
	_score_pop.position = c - _score_pop.size * 0.5
	_chain_banner.size = Vector2(360, 64)
	_chain_banner.pivot_offset = _chain_banner.size * 0.5
	_chain_banner.position = c - _chain_banner.size * 0.5 + Vector2(0, ring_rect.size.y * 0.32)

func _set_score_pop(value: int) -> void:
	_score_pop.text = str(value)
	_score_pop.scale = Vector2(1.18, 1.18)
	var tw := create_tween()
	tw.tween_property(_score_pop, "scale", Vector2.ONE, 0.22)

func _show_chain_banner(count: int, tier: int) -> void:
	var style: Dictionary = COMBO_TIERS[tier]
	_chain_banner.text = L10n.format_text("ui.run.fx.combo", {"count": count}, "%d 连击！" % count)
	_chain_banner.add_theme_font_size_override("font_size", int(style["font"]))
	_chain_banner.add_theme_color_override("font_color", style["color"])
	_chain_banner.visible = true
	_chain_banner.modulate = Color(1, 1, 1, 1)
	var pop: float = float(style["pop"])
	_chain_banner.scale = Vector2(pop, pop)
	var tw := create_tween()
	tw.tween_property(_chain_banner, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _flash(intensity: float = 0.22) -> void:
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", intensity, 0.06)
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.28)

func _fade_out(node: CanvasItem, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, duration)
	await tw.finished
	node.visible = false
	node.modulate = Color(1, 1, 1, 1)

func _log(line: String) -> void:
	_yearly_log.append(line)
	print("[Reelbound] %s" % line)
