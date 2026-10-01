class_name SettingsManager
extends RefCounted

const CONFIG_PATH: String = "user://settings.cfg"

static var config: ConfigFile = ConfigFile.new()

static func load_settings() -> void:
	var err: Error = config.load(CONFIG_PATH)
	if err != OK:
		# Настройки по умолчанию
		var primary: int = DisplayServer.get_primary_screen()
		config.set_value("display", "screen_index", primary)
		config.set_value("display", "graphics_mode", "32bit")
		config.set_value("display", "fps_limit", 30)
		config.set_value("game", "coins", 100)
		config.set_value("game", "current_crop", "wheat")
		config.set_value("game", "speed_multiplier", 1.0)
		config.set_value("game", "has_seeder_tractor", false)
		config.set_value("game", "has_scarecrow", false)
		config.set_value("game", "has_guard_dog", false)
		config.set_value("game", "tractor_color", Color(0.85, 0.2, 0.2, 1.0))
		save_settings()

static func save_settings() -> void:
	config.save(CONFIG_PATH)

static func get_screen_index() -> int:
	return int(config.get_value("display", "screen_index", 0))

static func set_screen_index(idx: int) -> void:
	config.set_value("display", "screen_index", idx)
	save_settings()

static func get_graphics_mode() -> String:
	return str(config.get_value("display", "graphics_mode", "32bit"))

static func set_graphics_mode(mode: String) -> void:
	config.set_value("display", "graphics_mode", mode)
	save_settings()

static func get_fps_limit() -> int:
	return int(config.get_value("display", "fps_limit", 30))

static func set_fps_limit(val: int) -> void:
	config.set_value("display", "fps_limit", val)
	Engine.max_fps = val
	save_settings()
