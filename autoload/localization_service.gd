extends Node

signal locale_changed(new_locale: String)

const DEFAULT_LOCALE := "zh_CN"
const SUPPORTED_LOCALES := ["zh_CN", "en"]
const TRANSLATION_FILES := [
	"res://locale/messages.csv",
]

var _loaded_translations: Array[Translation] = []

func _ready() -> void:
	_load_translations()
	set_locale(DEFAULT_LOCALE)

func set_locale(locale: String) -> void:
	var standardized := TranslationServer.standardize_locale(locale)
	var next_locale := standardized if standardized in SUPPORTED_LOCALES else DEFAULT_LOCALE
	TranslationServer.set_locale(next_locale)
	locale_changed.emit(next_locale)

func get_locale() -> String:
	return TranslationServer.get_locale()

func get_supported_locales() -> PackedStringArray:
	return PackedStringArray(SUPPORTED_LOCALES)

func cycle_locale() -> void:
	var current_locale := get_locale()
	var current_index := SUPPORTED_LOCALES.find(current_locale)
	var next_index := (current_index + 1) % SUPPORTED_LOCALES.size()
	set_locale(SUPPORTED_LOCALES[next_index])

func _load_translations() -> void:
	for path in TRANSLATION_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Failed to open translation source: %s" % path)
			continue
		var header := file.get_csv_line()
		if header.size() < 2:
			push_error("Translation source has no locale columns: %s" % path)
			continue

		var translations_by_locale: Dictionary = {}
		for index in range(1, header.size()):
			var locale := String(header[index]).strip_edges()
			if locale.is_empty() or locale.begins_with("_"):
				continue
			var translation := Translation.new()
			translation.locale = locale
			translations_by_locale[locale] = translation

		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.is_empty():
				continue
			var key := String(row[0]).strip_edges()
			if key.is_empty():
				continue

			for index in range(1, mini(row.size(), header.size())):
				var locale := String(header[index]).strip_edges()
				if not translations_by_locale.has(locale):
					continue
				var message := String(row[index])
				translations_by_locale[locale].add_message(key, message)

		for translation in translations_by_locale.values():
			TranslationServer.add_translation(translation)
			_loaded_translations.append(translation)
