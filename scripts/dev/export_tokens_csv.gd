# 碎片总表导出器（开发工具，不参与游戏运行）。
#
# 把 content/tokens/ 下的每个 .tres 读出来，摊成一张 CSV 交给表格软件看。
# 用途是**配平**：84 张阶段碎片分散在 84 个文件里，"童年到暮年基础分梯度对不对"
# "五个领域的 effect 分工是否失衡" 这类问题在文件树里看不出来，在一张表里一眼就有。
#
# **方向是单向的：.tres → csv。** CSV 是只读视图，改它不会影响游戏。
# 要改数值就改 .tres，然后重跑本脚本刷新表。（双向同步见 import_tokens_csv.gd——
# 如果哪天真做了的话。）
#
# 用法（仓库根目录）：
#   godot --headless --path . -s scripts/dev/export_tokens_csv.gd
#   godot --headless --path . -s scripts/dev/export_tokens_csv.gd -- --out=/tmp/t.csv
extends SceneTree

const TOKEN_DIR := "res://content/tokens"
const LOCALE_PATH := "res://locale/messages.csv"
const DEFAULT_OUT := "res://docs/content/tokens.csv"

# 列顺序 = 看表的顺序：先认它是谁（id/名字/阶段/领域），再看它多强（分数/效果），
# 最后才是抽取与传承这些系统字段。
const HEADER := ["id", "name", "stage_id", "domain", "rarity", "base_score",
	"zodiac_affinity", "effects", "draft_weight", "is_legacy", "legacy_into",
	"has_icon", "description"]

# 阶段排序用。表按「阶段 → 领域 → 基础分」排，梯度才看得出来。
const STAGE_ORDER := ["childhood", "adolescence", "youth", "prime", "midlife",
	"senior", "twilight"]

var _locale: Dictionary = {}


func _initialize() -> void:
	var out_path := _out_path()
	_load_locale()
	var rows := _collect_rows()
	if rows.is_empty():
		push_error("export_tokens_csv: %s 下没有读到任何碎片" % TOKEN_DIR)
		quit(1)
		return
	if not _write_csv(out_path, rows):
		quit(2)
		return
	print("[export_tokens_csv] %d 张碎片 → %s" % [rows.size(), out_path])
	quit(0)


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			return String(arg).substr(6)
	return DEFAULT_OUT


# 显示名存的是 l10n key，表里要看得懂的中文，所以直接读 messages.csv 的 zh_CN 列。
# 不走 L10n autoload：这个脚本要能在没起游戏的情况下跑。
func _load_locale() -> void:
	var file := FileAccess.open(LOCALE_PATH, FileAccess.READ)
	if file == null:
		push_warning("export_tokens_csv: 读不到 %s，名字列将退回 l10n key" % LOCALE_PATH)
		return
	var first := true
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 2:
			continue
		if first:
			first = false      # 表头 keys,zh_CN,en
			continue
		_locale[String(line[0])] = String(line[1])
	file.close()


func _collect_rows() -> Array:
	var rows: Array = []
	var dir := DirAccess.open(TOKEN_DIR)
	if dir == null:
		push_error("export_tokens_csv: 打不开 %s" % TOKEN_DIR)
		return rows
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		# 导出后的项目里 .tres 会变成 .tres.remap，两种都认。
		var clean := String(file_name).trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var def = load("%s/%s" % [TOKEN_DIR, clean])
		if def == null:
			push_warning("export_tokens_csv: 加载失败 %s" % clean)
			continue
		rows.append(_row_for(def))
	rows.sort_custom(_compare_rows)
	return rows


func _row_for(def) -> Array:
	return [
		String(def.id),
		_display_name(def),
		String(def.stage_id),
		String(def.domain),
		String(def.rarity),
		str(int(def.base_score)),
		String(def.zodiac_affinity),
		_effects_spec(def.effects),
		"%.2f" % float(def.draft_weight),
		"true" if bool(def.is_legacy) else "false",
		String(def.legacy_into),
		"true" if def.icon != null else "false",
		_display_text(String(def.description)),
	]


func _display_name(def) -> String:
	var key := String(def.name)
	return String(_locale.get(key, key if not key.is_empty() else String(def.id)))


func _display_text(key: String) -> String:
	if key.is_empty():
		return ""
	return String(_locale.get(key, key))


# effect 用与 generate_content.gd 完全相同的紧凑语法写回：
#   self:N | adj:定额/百分比/半径 | zod:定额/百分比
# 保持同一套语法，是为了这张表将来能反向喂回生成器；换个写法就断了这条路。
func _effects_spec(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if effect == null:
			continue
		if effect is AddSelfScore:
			parts.append("self:%d" % int(effect.amount))
		elif effect is ModifyNeighbor:
			parts.append("adj:%d/%d/%d" % [int(effect.amount), int(effect.percent),
				int(effect.radius)])
		elif effect is TriggerZodiacChain:
			parts.append("zod:%d/%d" % [int(effect.amount), int(effect.percent)])
		else:
			# 新增 effect 类型时这里会自曝，而不是在表里静默丢一列数据。
			push_warning("export_tokens_csv: 未知 effect 类型 %s" % effect.get_class())
			parts.append("?:%s" % effect.get_script().resource_path.get_file())
	return "|".join(parts)


# 阶段 → 领域 → 基础分：一屏之内就能读出七个阶段的梯度与五个领域的分工。
func _compare_rows(a: Array, b: Array) -> bool:
	var stage_a := STAGE_ORDER.find(String(a[2]))
	var stage_b := STAGE_ORDER.find(String(b[2]))
	# 跨阶段碎片（传承物、凡庸）stage_id 为空，排在所有阶段之后。
	if stage_a < 0:
		stage_a = STAGE_ORDER.size()
	if stage_b < 0:
		stage_b = STAGE_ORDER.size()
	if stage_a != stage_b:
		return stage_a < stage_b
	if String(a[3]) != String(b[3]):
		return String(a[3]) < String(b[3])
	if int(a[5]) != int(b[5]):
		return int(a[5]) < int(b[5])
	return String(a[0]) < String(b[0])


func _write_csv(path: String, rows: Array) -> bool:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("export_tokens_csv: 写不了 %s（错误 %d）" % [path, FileAccess.get_open_error()])
		return false
	file.store_csv_line(PackedStringArray(HEADER))
	for row in rows:
		file.store_csv_line(PackedStringArray(row))
	file.close()
	return true
