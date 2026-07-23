# 窗口分辨率设置服务：
# - 两档：1K (1920×1080, 默认) / 2K (2560×1440)。
# - 配合 project.godot 的 base viewport 1280×720 + canvas_items 拉伸：切档 = 整体等比
#   放大 UI（1K=1.5× / 2K=2×），而不是只给更多留白，所以「画面太小」直接变大。
# - 选择持久化到 user://settings.cfg（ConfigFile）；启动时 app_root 读回并 apply。
# - 纯 RefCounted：数据映射 + DisplayServer 调用，无场景依赖。headless 下 apply 安全跳过。
class_name DisplaySettingsService
extends RefCounted

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "display"
const KEY := "resolution"

const DEFAULT_KEY := "1k"
const ORDERED_KEYS := ["1k", "2k"]
const RESOLUTIONS := {
	"1k": Vector2i(1920, 1080),
	"2k": Vector2i(2560, 1440),
}
const LABELS := {
	"1k": "1K (1920×1080)",
	"2k": "2K (2560×1440)",
}

func ordered_keys() -> Array:
	return ORDERED_KEYS.duplicate()

func is_valid(key: String) -> bool:
	return RESOLUTIONS.has(key)

func resolution_for(key: String) -> Vector2i:
	return RESOLUTIONS.get(key, RESOLUTIONS[DEFAULT_KEY])

func label_for(key: String) -> String:
	return LABELS.get(key, key)

# 读回上次选择；文件缺失 / 值非法都退默认 1K。
func load_choice() -> String:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return DEFAULT_KEY
	var key := String(config.get_value(SECTION, KEY, DEFAULT_KEY))
	return key if is_valid(key) else DEFAULT_KEY

func save_choice(key: String) -> void:
	if not is_valid(key):
		push_error("DisplaySettingsService.save_choice: 未知分辨率档 %s" % key)
		return
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)  # 保留其它设置；文件不存在也无妨，从空开始
	config.set_value(SECTION, KEY, key)
	if config.save(CONFIG_PATH) != OK:
		push_error("DisplaySettingsService.save_choice: 写入 %s 失败" % CONFIG_PATH)

# 把主窗口设成该档尺寸并居中到当前屏幕。headless / 无窗口时安全跳过。
func apply(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var res := resolution_for(key)
	var window_id := DisplayServer.MAIN_WINDOW_ID
	DisplayServer.window_set_size(res, window_id)
	var screen := DisplayServer.window_get_current_screen(window_id)
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_pos + (screen_size - res) / 2, window_id)
