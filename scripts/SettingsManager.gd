class_name SettingsManager
extends RefCounted

const CONFIG_PATH: String = "user://settings.cfg"
const BACKUP_PATH: String = "user://settings.backup.cfg"
const CURRENT_SCHEMA_VERSION: int = 3
const MIN_SAVE_INTERVAL_MSEC: int = 1500

static var config: ConfigFile = ConfigFile.new()
static var _dirty: bool = false
static var _last_disk_save_msec: int = 0
static var last_load_used_backup: bool = false
static var last_load_error: int = OK

static func load_settings() -> void:
	config = ConfigFile.new()
	last_load_used_backup = false
	last_load_error = int(config.load(CONFIG_PATH))

	if last_load_error != OK:
		var backup: ConfigFile = ConfigFile.new()
		var backup_err: Error = backup.load(BACKUP_PATH)
		if backup_err == OK:
			config = backup
			last_load_used_backup = true
			print("[SettingsManager] ⚠ Основной save повреждён/недоступен. Загружен backup.")
		else:
			config = ConfigFile.new()
			_apply_defaults()
			print("[SettingsManager] ℹ Создан новый save с настройками по умолчанию.")

	_run_migrations()
	_validate_critical_values()
	_dirty = true
	flush_pending(true)

static func save_settings(force: bool = false) -> void:
	_dirty = true
	if force or _can_write_now():
		flush_pending(force)

static func flush_pending(force: bool = false) -> bool:
	if not _dirty and not force:
		return true
	if not force and not _can_write_now():
		return false

	_write_backup_from_current_disk()

	config.set_value("meta", "schema_version", CURRENT_SCHEMA_VERSION)
	config.set_value("meta", "last_saved_unix", int(Time.get_unix_time_from_system()))
	var err: Error = config.save(CONFIG_PATH)
	if err != OK:
		push_error("[SettingsManager] Не удалось сохранить settings.cfg, error=%d" % int(err))
		return false

	_dirty = false
	_last_disk_save_msec = Time.get_ticks_msec()
	return true

static func get_schema_version() -> int:
	return int(config.get_value("meta", "schema_version", 0))

static func has_pending_save() -> bool:
	return _dirty

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
	var safe: int = clampi(val, 15, 240)
	config.set_value("display", "fps_limit", safe)
	Engine.max_fps = safe
	save_settings()

static func _can_write_now() -> bool:
	if _last_disk_save_msec <= 0:
		return true
	return Time.get_ticks_msec() - _last_disk_save_msec >= MIN_SAVE_INTERVAL_MSEC

static func _write_backup_from_current_disk() -> void:
	var previous: ConfigFile = ConfigFile.new()
	if previous.load(CONFIG_PATH) != OK:
		return

	var previous_schema: int = int(previous.get_value("meta", "schema_version", 0))
	# Не перезаписываем хороший backup заведомо устаревшим/пустым save.
	if previous_schema < 0:
		return

	var err: Error = previous.save(BACKUP_PATH)
	if err != OK:
		push_warning("[SettingsManager] Не удалось обновить backup save, error=%d" % int(err))

static func _run_migrations() -> void:
	var version: int = max(0, int(config.get_value("meta", "schema_version", 0)))

	if version < 1:
		_migrate_to_v1()
		version = 1
	if version < 2:
		_migrate_to_v2()
		version = 2
	if version < 3:
		_migrate_to_v3()
		version = 3

	config.set_value("meta", "schema_version", CURRENT_SCHEMA_VERSION)

static func _migrate_to_v1() -> void:
	# Ранние версии не имели schema metadata и lifetime statistics.
	if not config.has_section_key("statistics", "total_bankruptcies"):
		var legacy_bankruptcies: int = int(config.get_value("finances", "total_bankruptcies", 0))
		config.set_value("statistics", "total_bankruptcies", max(0, legacy_bankruptcies))
	config.set_value("meta", "migrated_to_v1", true)

static func _migrate_to_v2() -> void:
	# Quality inventory появился позже агрегированного stock.
	# Сам InventoryManager выполнит точную миграцию партий, здесь фиксируем schema boundary.
	config.set_value("meta", "migrated_to_v2", true)

static func _migrate_to_v3() -> void:
	# v0.18 добавил specialization/prestige/meta progression.
	# Отсутствующие секции безопасно читаются менеджерами с defaults.
	if not config.has_section_key("specialization", "selected_path"):
		config.set_value("specialization", "selected_path", "none")
	if not config.has_section_key("specialization", "unlocked_tier"):
		config.set_value("specialization", "unlocked_tier", 0)
	if not config.has_section_key("prestige", "rank"):
		config.set_value("prestige", "rank", 0)
	if not config.has_section_key("prestige", "total_prestiges"):
		config.set_value("prestige", "total_prestiges", 0)
	config.set_value("meta", "migrated_to_v3", true)

static func _validate_critical_values() -> void:
	var primary: int = DisplayServer.get_primary_screen()
	var screen_count: int = max(1, DisplayServer.get_screen_count())
	var screen_idx: int = int(config.get_value("display", "screen_index", primary))
	if screen_idx < -1 or screen_idx >= screen_count:
		screen_idx = primary
	config.set_value("display", "screen_index", screen_idx)

	var graphics_mode: String = str(config.get_value("display", "graphics_mode", "32bit"))
	if graphics_mode != "16bit" and graphics_mode != "32bit":
		graphics_mode = "32bit"
	config.set_value("display", "graphics_mode", graphics_mode)

	var fps_limit: int = clampi(int(config.get_value("display", "fps_limit", 30)), 15, 240)
	config.set_value("display", "fps_limit", fps_limit)

	var coins: int = max(0, int(config.get_value("game", "coins", 100)))
	config.set_value("game", "coins", coins)

	var crop: String = str(config.get_value("game", "current_crop", "wheat"))
	if crop not in ["wheat", "corn", "sunflower", "carrot"]:
		crop = "wheat"
	config.set_value("game", "current_crop", crop)

	var speed: float = clampf(float(config.get_value("game", "speed_multiplier", 1.0)), 0.1, 10.0)
	config.set_value("game", "speed_multiplier", speed)

	var fuel: float = clampf(float(config.get_value("mechanics", "fuel_level", 100.0)), 0.0, 100.0)
	config.set_value("mechanics", "fuel_level", fuel)

	var schema: int = int(config.get_value("meta", "schema_version", CURRENT_SCHEMA_VERSION))
	if schema > CURRENT_SCHEMA_VERSION:
		push_warning("[SettingsManager] Save schema %d новее поддерживаемой %d. Данные загружены в режиме совместимости." % [schema, CURRENT_SCHEMA_VERSION])

static func _apply_defaults() -> void:
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
	config.set_value("meta", "schema_version", CURRENT_SCHEMA_VERSION)
