# Reelbound 阶段报告

## 文档信息
- 日期：`2026-03-24`
- 范围：对照 `docs/` 里的 PRD、brainstorm log、MVP plan 与当前仓库代码
- 结论用途：界定当前真实阶段，收敛后续实现优先级

## 1. 结论摘要

项目当前已经完成了“可玩原型 + Vertical Slice 骨架”，但还没有达到 PRD 定义下的 MVP。

更准确地说，当前状态介于以下两者之间：
- 已超过纯工程脚手架阶段：核心资源类、基础服务、测试目录、主运行界面都已经存在
- 尚未达到真实闭环阶段：主循环里仍有明显占位逻辑，多个系统只存在于资源、服务或测试层，尚未真正接入玩家流程

建议把当前阶段名称定为：

`Playable Prototype / Early Vertical Slice`

而不是：

`MVP`

## 2. 当前已落地内容

### 2.1 工程与基础设施
- Godot 工程、插件、基础目录结构已建立
- GUT 单元测试与集成测试目录已建立
- `README`、插件决策文档、内容结构文档、平衡检查清单已建立

### 2.2 内容与数据层
- Token / Event / Hero / Difficulty / Meta / Anomaly 六类 `Resource` 定义已存在
- `ContentRegistry` 已能扫描 `content/` 目录并按类型建索引
- 首批内容资源已经具备基础样例池

当前内容量统计：
- Token：`6`
- Event：`12`
- Hero：`3`
- Difficulty：`3`
- Meta unlock：`3`
- Anomaly：`3`

### 2.3 规则与服务层
- 棋盘模型、Token 实例、快照、结算步骤与结算报告等值对象已存在
- `BoardService`、`TriggerScanner`、`SettlementResolver`、`RewardOfferService`、`EventDraftService`、`ContractService`、`EndlessService`、`MetaProgressionService` 等基础服务已存在
- 角色与难度修正已经有独立服务层，不是直接写死在 UI

### 2.4 场景与可玩流程
- 主场景已能进入 `RunScreen`
- `RunScreen` 已具备：
  - 5x5 棋盘
  - 放置与删除基础交互
  - 结算日志回放
  - offer 面板
  - event draft 面板
  - 基于 Godot State Charts 的基础状态流转

## 3. 当前没有闭环的部分

以下内容已经“有结构”，但还没有形成真实的玩法闭环：

### 3.1 结算仍是占位实现
- 当前 `RunScreen` 会根据“前 3 个已放置 Token”生成固定的 `base_output / adjacency / row_column` 分值
- 这说明 UI 已经能回放结算顺序
- 但这还不是从 Token 定义、棋盘关系、标签规则真实推导出的结算

### 3.2 回合奖励三选一仍是占位实现
- 当前奖励面板有 `add_token / remove_token / random_token` 三种 offer
- 但选择 offer 后并不会真正发放对应奖励，只会继续推进事件草案流程

### 3.3 Risk Contract 只有数据壳
- 当前能生成 contract、显示 contract 摘要
- 但没有：
  - 回合推进
  - 契约倒计时
  - 达成判定
  - 失败惩罚执行
  - 奖励兑现

### 3.4 周期目标、失败、通关、Endless 未接入主循环
- `RunSession` 中已有阶段目标字段
- 但当前流程没有在结算后做真实的目标检查
- `run_failed` / `run_cleared` 状态存在，但没有接入完整跳转
- Endless 相关服务和面板存在，但仍是孤立能力，不是玩家已可达到的系统

### 3.5 Meta / Save 还未接入实际游玩流程
- Meta progression service 和 save service 已存在
- Meta 界面也已占位
- 但 run 结束后的解锁写回、读取、回流到主流程尚未形成用户可见闭环

## 4. 文档与代码的实际偏差

### 4.1 当前项目阶段被文档高估
- PRD 的 MVP 范围要求：
  - 基础 Token 放置 / 删除 / 随机获取
  - Event Draft
  - 即时 / 持续 / 危机事件
  - 3 名主角原型
  - 基础局外解锁
  - Ascension 前 3 层
  - 标准通关 + Endless 模式
- 当前代码只部分满足这些要求
- 尤其是“标准通关 + Endless 模式”“真实奖励闭环”“真实契约闭环”还没有落到主玩家流程

### 4.2 内容量与 PRD 推荐值差距明显
- PRD 推荐首批内容量为：
  - Token：`45~60`
  - Event：`20~30`
  - Hero：`3`
  - Meta unlock：`15~25`
  - Anomaly：`2~4`
- 当前只满足 Hero 和 Anomaly 的最低数量预期
- Token、Event、Meta unlock 仍明显低于 MVP 内容量

### 4.3 内容结构文档已经落后于代码
- `content-schema.md` 没有完整反映 `EventDefinition` 的实际字段
- 文档描述的 registry 规则与当前按类型分字典加载的实现也不一致

### 4.4 运行时架构与计划文档不一致
- MVP plan 把 `autoload/app_state.gd`、`autoload/content_registry.gd`、`autoload/run_session.gd` 列为 Runtime 层
- 当前实际情况是：
  - `autoload/app_state.gd` 不存在
  - `project.godot` 没有 autoload 配置
  - `run_screen.gd` 里通过 `new()` 手动创建 `RunSession` 与 `ContentRegistry`

### 4.5 部分“已完成任务”在文档里表达得过满
- Meta、Endless、Anomaly、Risk Contract 这些任务在计划文档中看起来像“功能已完成”
- 但代码里更准确的状态是：
  - 数据模型已到位
  - 服务壳已存在
  - 最小测试已存在
  - 玩家流程接入尚不完整

## 5. 当前代码层面的主要问题

### 5.1 主循环不够诚实
- UI 现在展示的是“可回放的结算样板”
- 不是“真实可推导的规则系统”
- 如果继续在这个基础上扩内容，会让后续问题从“实现缺口”变成“架构债务”

### 5.2 难度修正没有真正进入事件草案权重
- 难度修正服务与 Event Draft 服务之间的字段语义当前不一致
- 这意味着 Ascension 虽然有资源和测试，但未必真实影响玩家看到的 draft 结果

### 5.3 RunScreen 承担了过多流程职责
- 当前 `RunScreen` 同时负责：
  - 盘面交互
  - 会话状态
  - 快照拼装
  - 事件 draft 调用
  - contract 接入
  - 结算回放
  - UI 同步
- 继续往里堆功能会很快变成维护热点

### 5.4 测试通过不等于玩法完成
- 当前测试更多是在保证“壳子存在并能跑”
- 对真正玩法正确性的验证还不够
- 特别是：
  - 真实结算规则
  - 奖励实际发放
  - 契约成功 / 失败
  - 通关 / 失败 / Endless 切换

## 6. 建议的下一阶段目标

下一阶段不应该继续优先堆内容量，也不应该先做 Meta 扩展。

建议把下一阶段定义为：

`Honest Vertical Slice`

目标只有一个：

把当前原型从“流程演示”收敛为“规则真实、主循环闭环、能被测试证明正确”的 vertical slice。

这一阶段应优先解决：
- 用真实规则替代伪造结算
- 让 reward offer 真正改变 run 状态
- 让 contract 进入真实回合推进
- 接入阶段目标检查、失败、标准通关与 Endless 入口
- 修正 hero / difficulty / event draft 的权重联动

对应实现计划见：

`docs/superpowers/plans/2026-03-24-honest-vertical-slice-plan.md`

## 7. 本阶段完成判定建议

当以下条件全部满足时，才建议把项目状态从“Early Vertical Slice”更新为“Vertical Slice”：
- 棋盘结算来自真实规则而不是 UI 造数据
- 回合奖励选择能真实改变局面
- 合约能真实成功、失败、倒计时
- 周期目标能真实触发失败或推进阶段
- 标准通关后能进入 Endless
- 关键流程有单元测试和集成测试覆盖
- 文档与实现重新对齐

## 8. 验证说明

本报告基于仓库中的文档、脚本、场景、资源和测试文件进行静态对照整理。

当前环境下未完成一次新的 Godot/GUT 验证运行，原因是：
- `GODOT_BIN` 未设置
- 系统 PATH 中也没有可直接调用的 `godot` 可执行文件

因此，本报告对“功能是否已接入主循环”的判断依据是代码结构与调用关系，而不是一次最新测试跑批结果。
