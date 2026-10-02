class_name AchievementManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const ContractManager = preload("res://scripts/ContractManager.gd")
const VehicleManager = preload("res://scripts/VehicleManager.gd")
const WorkerManager = preload("res://scripts/WorkerManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const QualityManager = preload("res://scripts/QualityManager.gd")
const PositiveEventManager = preload("res://scripts/PositiveEventManager.gd")

const ACHIEVEMENT_ORDER: Array[String] = [
	"first_harvest",
	"harvest_25",
	"harvest_100",
	"farm_level_10",
	"reputation_60",
	"contracts_10",
	"quality_s_100",
	"fleet_6",
	"tuning_master",
	"worker_level_10",
	"infrastructure_started",
	"rare_events_3",
	"coins_10000"
]

const ACHIEVEMENTS: Dictionary = {
	"first_harvest": {
		"title": "Первый урожай",
		"description": "Завершить первый полный производственный цикл.",
		"icon": "🌾",
		"metric": "harvests",
		"target": 1.0,
		"points": 10,
		"reward_title": "Начинающий фермер"
	},
	"harvest_25": {
		"title": "Рабочий ритм",
		"description": "Собрать 25 урожаев.",
		"icon": "🚜",
		"metric": "harvests",
		"target": 25.0,
		"points": 20,
		"reward_title": "Полевод"
	},
	"harvest_100": {
		"title": "Хозяин полей",
		"description": "Собрать 100 урожаев.",
		"icon": "🏆",
		"metric": "harvests",
		"target": 100.0,
		"points": 50,
		"reward_title": "Хозяин полей"
	},
	"farm_level_10": {
		"title": "Ферма растёт",
		"description": "Достичь 10 уровня фермы.",
		"icon": "⭐",
		"metric": "farm_level",
		"target": 10.0,
		"points": 25,
		"reward_title": "Управляющий"
	},
	"reputation_60": {
		"title": "Уважаемый хозяин",
		"description": "Набрать 60 репутации.",
		"icon": "🤝",
		"metric": "reputation",
		"target": 60.0,
		"points": 30,
		"reward_title": "Уважаемый фермер"
	},
	"contracts_10": {
		"title": "Надёжный поставщик",
		"description": "Выполнить 10 контрактов.",
		"icon": "📦",
		"metric": "contracts",
		"target": 10.0,
		"points": 30,
		"reward_title": "Поставщик"
	},
	"quality_s_100": {
		"title": "Отборный урожай",
		"description": "Произвести 100 кг урожая класса S.",
		"icon": "💎",
		"metric": "quality_s_kg",
		"target": 100.0,
		"points": 40,
		"reward_title": "Мастер качества"
	},
	"fleet_6": {
		"title": "Серьёзный автопарк",
		"description": "Иметь 6 единиц техники.",
		"icon": "🚛",
		"metric": "vehicle_count",
		"target": 6.0,
		"points": 30,
		"reward_title": "Механизатор"
	},
	"tuning_master": {
		"title": "Тюнинг-мастер",
		"description": "Довести любой узел любой машины до максимального уровня.",
		"icon": "⚙",
		"metric": "max_tuning",
		"target": 5.0,
		"points": 35,
		"reward_title": "Инженер"
	},
	"worker_level_10": {
		"title": "Сильная команда",
		"description": "Развить любого работника до 10 уровня.",
		"icon": "👨‍🌾",
		"metric": "max_worker_level",
		"target": 10.0,
		"points": 30,
		"reward_title": "Наставник"
	},
	"infrastructure_started": {
		"title": "Крепкое хозяйство",
		"description": "Построить хотя бы 1 уровень каждого инфраструктурного объекта.",
		"icon": "🏗",
		"metric": "developed_buildings",
		"target": 6.0,
		"points": 40,
		"reward_title": "Хозяйственник"
	},
	"rare_events_3": {
		"title": "Редкая удача",
		"description": "Пережить 3 редких позитивных события.",
		"icon": "✨",
		"metric": "rare_events",
		"target": 3.0,
		"points": 35,
		"reward_title": "Счастливчик"
	},
	"coins_10000": {
		"title": "Оборот набирает силу",
		"description": "Заработать суммарно 10 000 монет.",
		"icon": "🪙",
		"metric": "lifetime_coins",
		"target": 10000.0,
		"points": 50,
		"reward_title": "Предприниматель"
	}
}

static var unlocked: Array[String] = []
static var unlocked_at: Dictionary = {}
static var active_title: String = "Фермер"
static var total_points: int = 0
static var initialized: bool = false

static func init_from_settings() -> void:
	var saved_unlocked: Variant = SettingsManager.config.get_value("achievements", "unlocked", [])
	unlocked = []
	if typeof(saved_unlocked) == TYPE_ARRAY:
		for achievement_id in saved_unlocked:
			var aid: String = str(achievement_id)
			if ACHIEVEMENTS.has(aid) and not unlocked.has(aid):
				unlocked.append(aid)

	var saved_times: Variant = SettingsManager.config.get_value("achievements", "unlocked_at", {})
	unlocked_at = saved_times.duplicate(true) if typeof(saved_times) == TYPE_DICTIONARY else {}
	active_title = str(SettingsManager.config.get_value("achievements", "active_title", "Фермер"))
	total_points = _calculate_total_points()
	initialized = true

	# Старый прогресс тоже должен автоматически открыть уже выполненные цели.
	evaluate_all()
	_validate_active_title()
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("achievements", "unlocked", unlocked.duplicate())
	SettingsManager.config.set_value("achievements", "unlocked_at", unlocked_at.duplicate(true))
	SettingsManager.config.set_value("achievements", "active_title", active_title)
	SettingsManager.config.set_value("achievements", "total_points", total_points)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func evaluate_all() -> Array[Dictionary]:
	if not initialized:
		return []

	var newly_unlocked: Array[Dictionary] = []
	for achievement_id in ACHIEVEMENT_ORDER:
		if unlocked.has(achievement_id):
			continue
		var definition: Dictionary = ACHIEVEMENTS[achievement_id]
		var target: float = float(definition.get("target", 1.0))
		var current: float = get_metric_value(str(definition.get("metric", "")))
		if current + 0.0001 < target:
			continue

		unlocked.append(achievement_id)
		unlocked_at[achievement_id] = int(Time.get_unix_time_from_system())
		newly_unlocked.append({
			"id": achievement_id,
			"title": str(definition.get("title", achievement_id)),
			"icon": str(definition.get("icon", "🏆")),
			"reward_title": str(definition.get("reward_title", "")),
			"points": int(definition.get("points", 0))
		})

	if not newly_unlocked.is_empty():
		total_points = _calculate_total_points()
		save_to_settings()

	return newly_unlocked

static func get_metric_value(metric: String) -> float:
	match metric:
		"harvests":
			return float(GameManager.total_harvested)
		"farm_level":
			return float(ProgressionManager.farm_level)
		"reputation":
			return float(ProgressionManager.reputation)
		"contracts":
			return float(ContractManager.total_completed)
		"quality_s_kg":
			return QualityManager.get_total_kg_for_grade("S")
		"vehicle_count":
			return float(VehicleManager.vehicles.size())
		"max_tuning":
			return float(_get_max_tuning_level())
		"max_worker_level":
			return float(_get_max_worker_level())
		"developed_buildings":
			return float(_get_developed_building_count())
		"rare_events":
			return float(PositiveEventManager.rare_triggered)
		"lifetime_coins":
			return float(GameManager.total_coins_earned)
	return 0.0

static func get_progress(achievement_id: String) -> Dictionary:
	if not ACHIEVEMENTS.has(achievement_id):
		return {"current": 0.0, "target": 1.0, "ratio": 0.0, "unlocked": false}
	var definition: Dictionary = ACHIEVEMENTS[achievement_id]
	var current: float = get_metric_value(str(definition.get("metric", "")))
	var target: float = max(0.0001, float(definition.get("target", 1.0)))
	return {
		"current": current,
		"target": target,
		"ratio": clampf(current / target, 0.0, 1.0),
		"unlocked": unlocked.has(achievement_id)
	}

static func get_unlocked_count() -> int:
	return unlocked.size()

static func get_available_titles() -> Array[String]:
	var titles: Array[String] = ["Фермер"]
	for achievement_id in ACHIEVEMENT_ORDER:
		if not unlocked.has(achievement_id):
			continue
		var title: String = str(ACHIEVEMENTS[achievement_id].get("reward_title", ""))
		if title != "" and not titles.has(title):
			titles.append(title)
	return titles

static func set_active_title(title: String) -> bool:
	if not get_available_titles().has(title):
		return false
	active_title = title
	save_to_settings()
	return true

static func is_unlocked(achievement_id: String) -> bool:
	return unlocked.has(achievement_id)

static func _get_max_tuning_level() -> int:
	var max_level: int = 0
	for vehicle_id in VehicleManager.vehicles:
		for upgrade_id in VehicleManager.UPGRADE_ORDER:
			max_level = max(max_level, VehicleManager.get_upgrade_level(str(vehicle_id), upgrade_id))
	return max_level

static func _get_max_worker_level() -> int:
	var max_level: int = 0
	for worker in WorkerManager.get_workers():
		max_level = max(max_level, int(worker.get("level", 1)))
	return max_level

static func _get_developed_building_count() -> int:
	var count: int = 0
	for building_id in BuildingManager.BUILDING_ORDER:
		if BuildingManager.get_level(building_id) >= 1:
			count += 1
	return count

static func _calculate_total_points() -> int:
	var points: int = 0
	for achievement_id in unlocked:
		if ACHIEVEMENTS.has(achievement_id):
			points += int(ACHIEVEMENTS[achievement_id].get("points", 0))
	return points

static func _validate_active_title() -> void:
	if not get_available_titles().has(active_title):
		active_title = "Фермер"
