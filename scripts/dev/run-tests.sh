#!/usr/bin/env bash
# GUT 测试 / 截图统一入口（macOS / Linux / WSL）。
#
# 用法：
#   scripts/dev/run-tests.sh unit          # 所有 unit 测试
#   scripts/dev/run-tests.sh integration   # 所有 integration 测试
#   scripts/dev/run-tests.sh smoke         # 仅 smoke test
#   scripts/dev/run-tests.sh one <res 路径> # 跑单个测试文件
#   scripts/dev/run-tests.sh shot <scene>  # 截图指定场景到 screenshots/
#
# 依赖：
#   - $GODOT_BIN 指向 Godot 4.7.x（默认 ~/.local/bin/godot；
#     macOS 用 /Applications/Godot.app/Contents/MacOS/Godot）
#   - GUT 9.6.0 在 addons/gut
#   - 截图需要 display（WSL 走 WSLg；macOS / Linux 用桌面会话）

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-$HOME/.local/bin/godot}"
if [[ ! -x "$GODOT" ]]; then
    echo "ERROR: 找不到 Godot 可执行文件 ($GODOT)" >&2
    echo "       设置 GODOT_BIN 或把 Godot 放到 ~/.local/bin/godot" >&2
    exit 127
fi

GUT_BASE=(--headless --path . -d -s addons/gut/gut_cmdln.gd -ginclude_subdirs -gexit)

cmd="${1:-}"
shift || true

case "$cmd" in
    unit)
        exec "$GODOT" "${GUT_BASE[@]}" -gdir=res://tests/unit
        ;;
    integration)
        exec "$GODOT" "${GUT_BASE[@]}" -gdir=res://tests/integration
        ;;
    smoke)
        exec "$GODOT" --headless --path . -d -s addons/gut/gut_cmdln.gd \
            -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
        ;;
    one)
        target="${1:-}"
        if [[ -z "$target" ]]; then
            echo "用法: run-tests.sh one res://tests/path/to/test_xxx.gd" >&2
            exit 2
        fi
        exec "$GODOT" --headless --path . -d -s addons/gut/gut_cmdln.gd \
            -gtest="$target" -gexit
        ;;
    shot)
        scene="${1:-}"
        if [[ -z "$scene" ]]; then
            echo "用法: run-tests.sh shot res://scenes/xxx.tscn [输出文件名]" >&2
            exit 2
        fi
        out="${2:-screenshots/$(date +%Y%m%d-%H%M%S).png}"
        mkdir -p "$(dirname "$out")"
        # 不带 --headless，借 WSLg 渲染
        exec "$GODOT" --path . -s tests/tools/screenshot.gd -- \
            "--scene=$scene" "--out=$out" "--frames=4"
        ;;
    ""|help|-h|--help)
        sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "未知子命令: $cmd" >&2
        sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' >&2
        exit 2
        ;;
esac
