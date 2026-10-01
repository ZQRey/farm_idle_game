class_name GameManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

# Описания доступных сельскохозяйственных культур
static var CROPS: Dictionary = {
	"wheat": {
		"id": "wheat",
		"name": "Пшеница",
		"row_index": 0,
		"seed_cost": 0,
		"growth_time": 7.0,
		"base_reward": 35,
		"unlocked": true
	},
	"corn": {
		"id": "corn",
		"name": "Кукуруза",
		"row_index": 1,
		"seed_cost": 150,
		"growth_time": 10.0,
		"base_reward": 80,
		"unlocked": false
	},
	"sunflower": {
		"id": "sunflower",
		"name": "Подсолнух",
		"row_index": 2,
		"seed_cost": 400,
		"growth_time": 14.0,
		"base_reward": 220,
		"unlocked": false
	},
	"carrot": {
		"id": "carrot",
		"name": "Морковь",
		"row_index": 3,
		"seed_cost": 900,
		"growth_time": 18.0,
		"base_reward": 550,
		"unlocked": false
	}
}

# Текущее состояние экономики
static var coins: int = 100
static var current_crop: String = "wheat"
static var speed_multiplier: float = 1.0
static var has_seeder_tractor: bool = false
static var has_guard_dog: bool = false
static var tractor_color: Color = Color("ac3232")

# Новые улучшения фермы
static var scarecrow_count: int = 0      # До 3 шт на каждый монитор
static var has_windmill: bool = false     # Мельница (+50% к доходу за помол муки)
static var has_barn: bool = false         # Амбар (сохранение урожая и вместимость)
static var canopy_count: int = 0          # Навесы от дождя и града (до 2 шт)
static var active_decoration: String = "none" # "none", "fence_wood", "fence_white", "lamps", "flowers", "trees"
static var unlocked_decorations: Array = ["none"]

# Статус аварийного состояния
static var is_broken_down: bool = false
static var is_stuck_in_mud: bool = false

# Статистика сессии
static var total_harvested: int = 0
static var total_coins_earned: int = 0
static var total_strikes_resolved: int = 0
static var total_repairs_done: int = 0

static func get_max_scarecrows() -> int:
	var screens: int = max(1, DisplayServer.get_screen_count())
	return screens * 3

static func init_from_settings() -> void:
	coins = int(SettingsManager.config.get_value("game", "coins", 100))
	current_crop = str(SettingsManager.config.get_value("game", "current_crop", "wheat"))
	speed_multiplier = float(SettingsManager.config.get_value("game", "speed_multiplier", 1.0))
	has_seeder_tractor = bool(SettingsManager.config.get_value("game", "has_seeder_tractor", false))
	has_guard_dog = bool(SettingsManager.config.get_value("game", "has_guard_dog", false))
	tractor_color = SettingsManager.config.get_value("game", "tractor_color", Color("ac3232"))

	# Новые параметры
	scarecrow_count = int(SettingsManager.config.get_value("game", "scarecrow_count", 0))
	has_windmill = bool(SettingsManager.config.get_value("game", "has_windmill", false))
	has_barn = bool(SettingsManager.config.get_value("game", "has_barn", false))
	canopy_count = int(SettingsManager.config.get_value("game", "canopy_count", 0))
	active_decoration = str(SettingsManager.config.get_value("game", "active_decoration", "none"))
	unlocked_decorations = SettingsManager.config.get_value("game", "unlocked_decorations", ["none"])

	# Восстановление открытых культур
	var unlocked_crops = SettingsManager.config.get_value("game", "unlocked_crops", ["wheat"])
	for crop_id in unlocked_crops:
		if CROPS.has(crop_id):
			CROPS[crop_id]["unlocked"] = true

static func save_to_settings() -> void:
	SettingsManager.config.set_value("game", "coins", coins)
	SettingsManager.config.set_value("game", "current_crop", current_crop)
	SettingsManager.config.set_value("game", "speed_multiplier", speed_multiplier)
	SettingsManager.config.set_value("game", "has_seeder_tractor", has_seeder_tractor)
	SettingsManager.config.set_value("game", "has_guard_dog", has_guard_dog)
	SettingsManager.config.set_value("game", "tractor_color", tractor_color)

	SettingsManager.config.set_value("game", "scarecrow_count", scarecrow_count)
	SettingsManager.config.set_value("game", "has_windmill", has_windmill)
	SettingsManager.config.set_value("game", "has_barn", has_barn)
	SettingsManager.config.set_value("game", "canopy_count", canopy_count)
	SettingsManager.config.set_value("game", "active_decoration", active_decoration)
	SettingsManager.config.set_value("game", "unlocked_decorations", unlocked_decorations)

	var unlocked_list: Array[String] = []
	for cid in CROPS:
		if CROPS[cid]["unlocked"]:
			unlocked_list.append(cid)
	SettingsManager.config.set_value("game", "unlocked_crops", unlocked_list)
	SettingsManager.save_settings()

static func add_coins(amount: int) -> void:
	coins += amount
	total_coins_earned += amount
	save_to_settings()

static func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		save_to_settings()
		return true
	return false

static func get_current_crop_data() -> Dictionary:
	return CROPS.get(current_crop, CROPS["wheat"])
