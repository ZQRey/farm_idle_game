class_name GameManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

signal bankruptcy_declared

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

# Улучшения фермы
static var scarecrow_count: int = 0
static var has_windmill: bool = false
static var has_barn: bool = false
static var canopy_count: int = 0
static var active_decoration: String = "none"
static var unlocked_decorations: Array = ["none"]

# Модернизация автопарка (новая техника лучших моделей)
static var has_heavy_tractor: bool = false   # Кировец К-7М (+60% скорость вспашки, 800 🪙)
static var has_super_harvester: bool = false # CLAAS Lexion (+60% уборка, +15% урожай, 1200 🪙)
static var has_road_train: bool = false      # КАМАЗ Автопоезд (+80% вывоз зерна, 950 🪙)

# Финансовая система (Субсидии, Кредиты, Долги)
static var subsidy_debt: int = 0 # Долг по субсидии (льготная ставка 5%)
static var loan_debt: int = 0    # Долг по банковскому кредиту (ставка 20%)

# Статус аварийного состояния
static var is_broken_down: bool = false
static var is_stuck_in_mud: bool = false
static var is_repairing: bool = false
static var is_strike_active: bool = false

# Статистика сессии
static var total_harvested: int = 0
static var total_coins_earned: int = 0
static var total_strikes_resolved: int = 0
static var total_repairs_done: int = 0
static var total_bankruptcies: int = 0

static func get_max_scarecrows() -> int:
	var screens: int = max(1, DisplayServer.get_screen_count())
	return screens * 3

static func get_total_debt() -> int:
	return subsidy_debt + loan_debt

static func init_from_settings() -> void:
	coins = int(SettingsManager.config.get_value("game", "coins", 100))
	current_crop = str(SettingsManager.config.get_value("game", "current_crop", "wheat"))
	speed_multiplier = float(SettingsManager.config.get_value("game", "speed_multiplier", 1.0))
	has_seeder_tractor = bool(SettingsManager.config.get_value("game", "has_seeder_tractor", false))
	has_guard_dog = bool(SettingsManager.config.get_value("game", "has_guard_dog", false))
	tractor_color = SettingsManager.config.get_value("game", "tractor_color", Color("ac3232"))

	scarecrow_count = int(SettingsManager.config.get_value("game", "scarecrow_count", 0))
	has_windmill = bool(SettingsManager.config.get_value("game", "has_windmill", false))
	has_barn = bool(SettingsManager.config.get_value("game", "has_barn", false))
	canopy_count = int(SettingsManager.config.get_value("game", "canopy_count", 0))
	active_decoration = str(SettingsManager.config.get_value("game", "active_decoration", "none"))
	unlocked_decorations = SettingsManager.config.get_value("game", "unlocked_decorations", ["none"])

	has_heavy_tractor = bool(SettingsManager.config.get_value("game", "has_heavy_tractor", false))
	has_super_harvester = bool(SettingsManager.config.get_value("game", "has_super_harvester", false))
	has_road_train = bool(SettingsManager.config.get_value("game", "has_road_train", false))

	subsidy_debt = int(SettingsManager.config.get_value("finances", "subsidy_debt", 0))
	loan_debt = int(SettingsManager.config.get_value("finances", "loan_debt", 0))
	total_bankruptcies = int(SettingsManager.config.get_value("finances", "total_bankruptcies", 0))

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

	SettingsManager.config.set_value("game", "has_heavy_tractor", has_heavy_tractor)
	SettingsManager.config.set_value("game", "has_super_harvester", has_super_harvester)
	SettingsManager.config.set_value("game", "has_road_train", has_road_train)

	SettingsManager.config.set_value("finances", "subsidy_debt", subsidy_debt)
	SettingsManager.config.set_value("finances", "loan_debt", loan_debt)
	SettingsManager.config.set_value("finances", "total_bankruptcies", total_bankruptcies)

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

# ==============================================================================
# ФИНАНСОВЫЕ ОПЕРАЦИИ (СУБСИДИИ, КРЕДИТЫ, ВЫПЛАТЫ, БАНКРОТСТВО)
# ==============================================================================

## Взять государственную субсидию (+500 монет, долг 525 под 5%)
static func take_subsidy(amount: int = 500, percent: float = 5.0) -> bool:
	if subsidy_debt > 0:
		return false # Уже есть активная субсидия
	subsidy_debt = int(amount * (1.0 + percent / 100.0))
	add_coins(amount)
	return true

## Досрочно погасить субсидию
static func repay_subsidy_early() -> bool:
	if subsidy_debt <= 0:
		return false
	if spend_coins(subsidy_debt):
		subsidy_debt = 0
		save_to_settings()
		return true
	return false

## Взять коммерческий кредит в банке (+1000 монет, долг 1200 под 20%)
static func take_bank_loan(amount: int = 1000, percent: float = 20.0) -> bool:
	if loan_debt > 0:
		return false # Уже есть непогашенный кредит
	loan_debt = int(amount * (1.0 + percent / 100.0))
	add_coins(amount)
	return true

## Досрочно погасить банковский кредит
static func repay_loan_early() -> bool:
	if loan_debt <= 0:
		return false
	if spend_coins(loan_debt):
		loan_debt = 0
		save_to_settings()
		return true
	return false

## Автоматическое удержание части дохода урожая в счет погашения долгов
static func process_harvest_finances(gross_reward: int) -> Dictionary:
	var net_coins: int = gross_reward
	var subsidy_payment: int = 0
	var loan_payment: int = 0

	# 10% с выручки на субсидию
	if subsidy_debt > 0:
		subsidy_payment = min(subsidy_debt, int(gross_reward * 0.10))
		subsidy_debt -= subsidy_payment
		net_coins -= subsidy_payment

	# 25% с выручки на банковский кредит
	if loan_debt > 0:
		loan_payment = min(loan_debt, int(gross_reward * 0.25))
		loan_debt -= loan_payment
		net_coins -= loan_payment

	add_coins(net_coins)
	save_to_settings()

	return {
		"net_coins": net_coins,
		"subsidy_paid": subsidy_payment,
		"loan_paid": loan_payment,
		"total_debt_remaining": get_total_debt()
	}

## Процедура банкротства (Сброс игры с начала и списание долгов)
static func declare_bankruptcy() -> void:
	print("[GameManager] 🚨 ОБЪЯВЛЕНО БАНКРОТСТВО! Сброс фермы до стартовых параметров...")
	
	total_bankruptcies += 1
	coins = 100
	subsidy_debt = 0
	loan_debt = 0

	current_crop = "wheat"
	speed_multiplier = 1.0
	has_seeder_tractor = false
	has_guard_dog = false
	scarecrow_count = 0
	has_windmill = false
	has_barn = false
	canopy_count = 0
	has_heavy_tractor = false
	has_super_harvester = false
	has_road_train = false
	active_decoration = "none"
	unlocked_decorations = ["none"]

	# Блокировка платных культур
	for cid in CROPS:
		CROPS[cid]["unlocked"] = (cid == "wheat")

	is_broken_down = false
	is_stuck_in_mud = false
	is_repairing = false
	is_strike_active = false

	save_to_settings()
