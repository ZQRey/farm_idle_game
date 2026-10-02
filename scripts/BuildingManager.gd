class_name BuildingManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

const MAX_LEVEL: int = 3
const BUILDING_ORDER: Array[String] = [
	"workshop",
	"fuel_station",
	"silo",
	"spare_parts",
	"barn_upgrade",
	"agronomy_lab"
]

const BUILDINGS: Dictionary = {
	"workshop": {
		"name": "Мастерская",
		"icon": "🔧",
		"base_cost": 550,
		"description": "-10% стоимость ТО и -5% износ техники за уровень"
	},
	"fuel_station": {
		"name": "Фермерская АЗС",
		"icon": "⛽",
		"base_cost": 650,
		"description": "-8% стоимость топлива и +20 л к баку фермы за уровень"
	},
	"silo": {
		"name": "Силос",
		"icon": "🏗",
		"base_cost": 700,
		"description": "+1000 кг к вместимости склада за уровень"
	},
	"spare_parts": {
		"name": "Склад запчастей",
		"icon": "🧰",
		"base_cost": 500,
		"description": "-8% стоимость ремонта и +1.5% надёжность техники за уровень"
	},
	"barn_upgrade": {
		"name": "Расширение амбара",
		"icon": "🏚",
		"base_cost": 600,
		"description": "+750 кг к складу и +5% к цене продажи за уровень"
	},
	"agronomy_lab": {
		"name": "Лаборатория агронома",
		"icon": "🧪",
		"base_cost": 850,
		"description": "+3% к скорости роста и +2% к урожайности за уровень"
	}
}

static var levels: Dictionary = {}
static var total_invested: int = 0
static var initialized: bool = false

static func init_from_settings() -> void:
	var saved_levels: Variant = SettingsManager.config.get_value("buildings_v2", "levels", {})
	levels = _default_levels()
	if typeof(saved_levels) == TYPE_DICTIONARY:
		for building_id in BUILDING_ORDER:
			levels[building_id] = clampi(int(saved_levels.get(building_id, 0)), 0, MAX_LEVEL)
	total_invested = max(0, int(SettingsManager.config.get_value("buildings_v2", "total_invested", 0)))
	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("buildings_v2", "levels", levels)
	SettingsManager.config.set_value("buildings_v2", "total_invested", total_invested)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_level(building_id: String) -> int:
	return clampi(int(levels.get(building_id, 0)), 0, MAX_LEVEL)

static func can_upgrade(building_id: String) -> bool:
	return initialized and BUILDINGS.has(building_id) and get_level(building_id) < MAX_LEVEL

static func get_upgrade_cost(building_id: String) -> int:
	if not can_upgrade(building_id):
		return 0
	var info: Dictionary = BUILDINGS[building_id]
	var current: int = get_level(building_id)
	return max(1, int(round(float(info.get("base_cost", 500)) * pow(1.75, current))))

static func upgrade(building_id: String) -> bool:
	if not can_upgrade(building_id):
		return false
	var cost: int = get_upgrade_cost(building_id)
	levels[building_id] = get_level(building_id) + 1
	total_invested += cost
	save_to_settings()
	return true

static func get_storage_bonus_kg() -> float:
	return float(get_level("silo")) * 1000.0 + float(get_level("barn_upgrade")) * 750.0

static func get_sale_multiplier() -> float:
	return 1.0 + float(get_level("barn_upgrade")) * 0.05

static func get_growth_multiplier() -> float:
	return 1.0 + float(get_level("agronomy_lab")) * 0.03

static func get_yield_multiplier() -> float:
	return 1.0 + float(get_level("agronomy_lab")) * 0.02

static func get_fuel_price_multiplier() -> float:
	return max(0.65, 1.0 - float(get_level("fuel_station")) * 0.08)

static func get_extra_fuel_capacity() -> float:
	return float(get_level("fuel_station")) * 20.0

static func get_repair_cost_multiplier() -> float:
	var reduction: float = float(get_level("workshop")) * 0.10 + float(get_level("spare_parts")) * 0.08
	return max(0.45, 1.0 - reduction)

static func get_wear_multiplier() -> float:
	return max(0.70, 1.0 - float(get_level("workshop")) * 0.05)

static func get_reliability_bonus() -> float:
	return float(get_level("spare_parts")) * 0.015

static func reset_all() -> void:
	levels = _default_levels()
	total_invested = 0
	save_to_settings()

static func _default_levels() -> Dictionary:
	return {
		"workshop": 0,
		"fuel_station": 0,
		"silo": 0,
		"spare_parts": 0,
		"barn_upgrade": 0,
		"agronomy_lab": 0
	}
