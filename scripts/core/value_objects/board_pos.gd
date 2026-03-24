class_name BoardPos
extends RefCounted

var x: int
var y: int

func _init(initial_x: int = 0, initial_y: int = 0) -> void:
	x = initial_x
	y = initial_y

func to_vector2i() -> Vector2i:
	return Vector2i(x, y)

