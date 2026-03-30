# 内容注册表：
# - 启动时扫描 `content/` 下的各类 `.tres` 资源，并按 `id` 建立索引。
# - 是整个项目的内容入口，`RunScreen` 和各个 service 都通过它读取 token、事件、英雄、难度等配置。
# - 自己不负责玩法计算，只负责“加载、校验、查表、缓存”。
# - 依赖 `ContentDefinitionValidator` 过滤非法资源，坏数据会被跳过并报错，而不是直接写进运行时状态。
# - 典型用法：`RunScreen._ready()` 调 `load_all()`，后续 reward/event/难度逻辑都从这里取资源。
class_name ContentRegistry
extends RefCounted

const TOKEN_PATH := "res://content/tokens"
const EVENT_PATH := "res://content/events"
const HERO_PATH := "res://content/heroes"
const DIFFICULTY_PATH := "res://content/difficulty"
const META_PATH := "res://content/meta"
const ANOMALY_PATH := "res://content/anomalies"

var tokens: Dictionary = {}
var events: Dictionary = {}
var heroes: Dictionary = {}
var difficulty_modifiers: Dictionary = {}
var meta_unlocks: Dictionary = {}
var anomalies: Dictionary = {}
var validator := ContentDefinitionValidator.new()

func load_all() -> void:
	tokens.clear()
	events.clear()
	heroes.clear()
	difficulty_modifiers.clear()
	meta_unlocks.clear()
	anomalies.clear()
	_load_resources_from_dir(TOKEN_PATH, tokens)
	_load_resources_from_dir(EVENT_PATH, events)
	_load_resources_from_dir(HERO_PATH, heroes)
	_load_resources_from_dir(DIFFICULTY_PATH, difficulty_modifiers)
	_load_resources_from_dir(META_PATH, meta_unlocks)
	_load_resources_from_dir(ANOMALY_PATH, anomalies)

func _load_resources_from_dir(dir_path: String, target_index: Dictionary) -> void:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		push_error("Failed to open content directory: %s" % dir_path)
		return

	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name.is_empty():
			break
		if directory.current_is_dir():
			continue
		if not file_name.ends_with(".tres"):
			continue

		var resource_path := "%s/%s" % [dir_path, file_name]
		var resource := load(resource_path)
		if resource == null:
			push_error("Failed to load content resource: %s" % resource_path)
			continue

		var errors := validator.validate_definition(resource, target_index)
		if not errors.is_empty():
			push_error("Invalid content resource %s: %s" % [resource_path, "; ".join(errors)])
			continue

		target_index[resource.id] = resource
	directory.list_dir_end()
