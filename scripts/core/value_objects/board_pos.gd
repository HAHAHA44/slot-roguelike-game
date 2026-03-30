# 棋盘坐标值对象：
# - 用来把 `x/y` 封装成可序列化、可传递的轻量对象。
# - 当前大量系统仍直接使用 `Vector2i`，但这个类适合存档、事件消息或未来需要明确语义的地方。
# - 它不持有任何棋盘逻辑，只负责坐标表示和转换。
class_name BoardPos
extends RefCounted

var x: int
var y: int

func _init(initial_x: int = 0, initial_y: int = 0) -> void:
	x = initial_x
	y = initial_y

func to_vector2i() -> Vector2i:
	return Vector2i(x, y)
