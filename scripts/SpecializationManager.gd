class_name SpecializationManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")

const PATH_NONE: String = "none"
const PATH_CROPS: String = "crops"
const PATH_LIVESTOCK: String = "livestock"
const PATH_PROCESSING: String = "processing"

const PATH_ORDER: Array[String] = [PATH_CROPS, PATH_LIVESTOCK, PATH_PROCESSING]
const MAX_TIER: int = 3
const POINT_LEVELS: Array[int] = [20, 25, 30]

const PATHS: Dictionary = {
	PATH_CROPS: {
		"name": "Растениевод",
		"icon": "🌾",
		"description": "Больше урожая, выше качество и быстрее автономные участки.",
		"tiers": {
			1: {"name": "Точные посевы", "description": "+8% урожайности полевых культур"},
			2: {"name": "Агрономическая школа", "description": "ещё +5% урожайности и +4 к quality score"},
			3: {"name": "Интенсивное земледелие", "description": "ещё +7% урожайности и -10% времени автономных участков"}
		}
	},
	PATH_LIVESTOCK: {
		"name": "Животновод",
		"icon": "🐄",
		"description": "Экономнее корм и больше яиц/молока.",
		"tiers": {
			1: {"name": "Рацион", "description": "-8% расход корма"},
			2: {"name": "Селекция", "description": "ещё -4% корма и +15% продукции"},
			3: {"name": "Племенное хозяйство", "description": "ещё +20% продукции"}
		}
	},
	PATH_PROCESSING: {
		"name": "Переработчик",
		"icon": "🏭",
		"description": "Больше выхода готовой продукции и выше её стоимость.",
		"tiers": {
			1: {"name": "Технологические карты", "description": "+10% выхода переработки"},
			2: {"name": "Контроль линии", "description": "ещё +10% выхода и +5% цены готовой продукции"},
			3: {"name": "Глубокая переработка", "description": "ещё +15% выхода и +7% цены готовой продукции"}
		}
	}
}

static var selected_path: String = PATH_NONE
static var unlocked_tier: int = 0
static var initialized: bool = false

static func init_from_settings() -> void:
	selected_path = str(SettingsManager.config.get_value("specialization", "selected_path", PATH_NONE))
	if selected_path != PATH_NONE and not PATHS.has(selected_path):
		selected_path = PATH_NONE
	unlocked_tier = clampi(int(SettingsManager.config.get_value("specialization", "unlocked_tier", 0)), 0, MAX_TIER)
	if selected_path == PATH_NONE:
		unlocked_tier = 0
	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("specialization", "selected_path", selected_path)
	SettingsManager.config.set_value("specialization", "unlocked_tier", unlocked_tier)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_total_points() -> int:
	var points: int = 0
	for level in POINT_LEVELS:
		if ProgressionManager.farm_level >= level:
			points += 1
	return points

static func get_spent_points() -> int:
	return unlocked_tier

static func get_available_points() -> int:
	return max(0, get_total_points() - get_spent_points())

static func can_choose_path(path_id: String) -> bool:
	return initialized and PATHS.has(path_id) and selected_path == PATH_NONE and get_available_points() > 0

static func choose_path(path_id: String) -> bool:
	if not can_choose_path(path_id):
		return false
	selected_path = path_id
	unlocked_tier = 1
	save_to_settings()
	return true

static func can_unlock_next_tier() -> bool:
	return initialized and selected_path != PATH_NONE and unlocked_tier < MAX_TIER and get_available_points() > 0

static func unlock_next_tier() -> bool:
	if not can_unlock_next_tier():
		return false
	unlocked_tier += 1
	save_to_settings()
	return true

static func get_path_name(path_id: String = "") -> String:
	var id: String = selected_path if path_id == "" else path_id
	if not PATHS.has(id):
		return "Без специализации"
	return "%s %s" % [str(PATHS[id].get("icon", "")), str(PATHS[id].get("name", id))]

static func get_tier_info(path_id: String, tier: int) -> Dictionary:
	if not PATHS.has(path_id):
		return {}
	var tiers: Dictionary = PATHS[path_id].get("tiers", {})
	return tiers.get(tier, {}).duplicate(true)

static func has_path(path_id: String, minimum_tier: int = 1) -> bool:
	return selected_path == path_id and unlocked_tier >= minimum_tier

static func get_crop_yield_multiplier() -> float:
	if not has_path(PATH_CROPS):
		return 1.0
	match unlocked_tier:
		1:
			return 1.08
		2:
			return 1.13
		3:
			return 1.20
	return 1.0

static func get_crop_quality_bonus() -> float:
	if has_path(PATH_CROPS, 2):
		return 4.0
	return 0.0

static func get_aux_field_cycle_multiplier() -> float:
	if has_path(PATH_CROPS, 3):
		return 0.90
	return 1.0

static func get_livestock_feed_multiplier() -> float:
	if not has_path(PATH_LIVESTOCK):
		return 1.0
	match unlocked_tier:
		1:
			return 0.92
		2, 3:
			return 0.88
	return 1.0

static func get_livestock_output_multiplier() -> float:
	if not has_path(PATH_LIVESTOCK, 2):
		return 1.0
	if unlocked_tier >= 3:
		return 1.35
	return 1.15

static func get_processing_output_multiplier() -> float:
	if not has_path(PATH_PROCESSING):
		return 1.0
	match unlocked_tier:
		1:
			return 1.10
		2:
			return 1.20
		3:
			return 1.35
	return 1.0

static func get_processing_sale_multiplier() -> float:
	if not has_path(PATH_PROCESSING, 2):
		return 1.0
	if unlocked_tier >= 3:
		return 1.12
	return 1.05

static func reset_all() -> void:
	selected_path = PATH_NONE
	unlocked_tier = 0
	save_to_settings()
