# Headless-friendly* screenshot helper.
#
# * Godot 不能在 --headless 下产出像素（无渲染管线），因此本脚本必须
#   在带 display 的会话里跑（WSL2 下用 WSLg 即可，无需额外配置）。
#
# 用法（从仓库根目录）：
#   godot --path . -s tests/tools/screenshot.gd -- \
#       --scene=res://scenes/run/run_screen.tscn \
#       --out=screenshots/run_screen.png \
#       --frames=4 \
#       --size=1280x720
#
# 参数：
#   --scene=<res 路径>    要加载的 PackedScene（必填）
#   --out=<文件路径>       PNG 输出，路径相对项目根（必填）
#   --frames=<int>        渲染多少帧后再截图，默认 2，给 UI 一点稳定时间
#   --size=<W>x<H>        视口尺寸，默认 1280x720
#
# 退出码：
#   0 = 截图成功；非 0 = 失败（参数缺失、场景加载失败、保存失败）。

extends SceneTree


const DEFAULT_FRAMES := 2
const DEFAULT_WIDTH := 1280
const DEFAULT_HEIGHT := 720


func _initialize() -> void:
	var args := _parse_cli_args()
	var scene_path: String = args.get("scene", "")
	var out_path: String = args.get("out", "")
	var frames: int = int(args.get("frames", DEFAULT_FRAMES))
	var size_str: String = args.get("size", "%dx%d" % [DEFAULT_WIDTH, DEFAULT_HEIGHT])

	if scene_path == "" or out_path == "":
		push_error("screenshot.gd: --scene 和 --out 都是必填项")
		quit(2)
		return

	var size := _parse_size(size_str)
	var root_window := get_root()
	root_window.size = size
	root_window.content_scale_size = size

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("screenshot.gd: 无法加载场景 %s" % scene_path)
		quit(3)
		return

	var instance := packed.instantiate()
	root_window.add_child(instance)

	# 等指定帧数，让 _ready / _process / layout 跑完
	for i in range(max(1, frames)):
		await process_frame

	var image: Image = root_window.get_texture().get_image()
	if image == null:
		push_error("screenshot.gd: viewport texture 为空（是否在 --headless 下运行？）")
		quit(4)
		return

	var dir := out_path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := image.save_png(out_path)
	if err != OK:
		push_error("screenshot.gd: 保存 PNG 失败 err=%s 路径=%s" % [err, out_path])
		quit(5)
		return

	print("screenshot.gd: 已写入 %s (%dx%d)" % [out_path, size.x, size.y])
	quit(0)


func _parse_cli_args() -> Dictionary:
	var result := {}
	var argv := OS.get_cmdline_user_args()
	for raw in argv:
		var s: String = raw
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var eq := s.find("=")
		if eq == -1:
			result[s] = "true"
		else:
			result[s.substr(0, eq)] = s.substr(eq + 1)
	return result


func _parse_size(s: String) -> Vector2i:
	var parts := s.split("x")
	if parts.size() != 2:
		return Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)
	return Vector2i(int(parts[0]), int(parts[1]))
