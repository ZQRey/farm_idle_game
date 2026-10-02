class_name GameManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const WindowManager = preload("res://scripts/WindowManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const MarketManager = preload("res://scripts/MarketManager.gd")
const VehicleManager = preload("res://scripts/VehicleManager.gd")
const WorkerManager = preload("res://scripts/WorkerManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")

signal bankruptcy_declared
signal season_changed(new_season: Season, season_name: String)
signal volunteer_status_changed(is_active: bool)

# Времена года
enum Season { SPRING, SUMMER, AUTUMN, WINTER }
static var current_season: Season = Season.SPRING

# Описания полевых культур (seed_cost = стоимость партии семян на 1 цикл сева)
static var CROPS: Dictionary = {
	"wheat": {
		"id": "wheat",
		"name": "Пшеница",
		"row_index": 0,
		"seed_cost": 10,
		"growth_time": 7.0,
		"base_reward": 40,
		"unlocked": true
	},
	"corn": {
		"id": "corn",
		"name": "Кукуруза",
		"row_index": 1,
		"seed_cost": 35,
		"growth_time": 10.0,
		"base_reward": 95,
		"unlocked": false
	},
	"sunflower": {
		"id": "sunflower",
		"name": "Подсолнух",
		"row_index": 2,
		"seed_cost": 80,
		"growth_time": 14.0,
		"base_reward": 230,
		"unlocked": false
	},
	"carrot": {
		"id": "carrot",
		"name": "Морковь",
		"row_index": 3,
		"seed_cost": 160,
		"growth_time": 18.0,
		"base_reward": 560,
		"unlocked": false
	}
}

# Тепличные экзотические культуры (круглогодичный урожай)
const GREENHOUSE_CROPS: Dictionary = {
	"bananas": {
		"id": "bananas",
		"name": "🍌 Бананы",
		"seed_cost": 30,
		"growth_time": 20.0,
		"reward": 90,
		"frame": 0
	},
	"oranges": {
		"id": "oranges",
		"name": "🍊 Апельсины",
		"seed_cost": 50,
		"growth_time": 26.0,
		"reward": 160,
		"frame": 1
	},
	"walnuts": {
		"id": "walnuts",
		"name": "🥜 Грецкие орехи",
		"seed_cost": 80,
		"growth_time": 34.0,
		"reward": 260,
		"frame": 2
	},
	"mango": {
		"id": "mango",
		"name": "🥭 Манго",
		"seed_cost": 120,
		"growth_time": 42.0,
		"reward": 400,
		"frame": 3
	}
}

# Текущее состояние экономики
static var coins: int = 100
static var current_crop: String = "wheat"
static var speed_multiplier: float = 1.0
static var has_seeder_tractor: bool = false
static var has_guard_dog: bool = false
static var tractor_color: Color = Color("ac3232")

# Топливная система техники (0..100 л)
static var fuel_level: float = 100.0
static var max_fuel: float = 100.0
static var auto_refuel: bool = true

# Износ техники и зданий (100% = новое, <40% = требует ремонта)
static var tractor_condition: float = 100.0
static var tanker_condition: float = 100.0
static var harvester_condition: float = 100.0
static var truck_condition: float = 100.0

static var windmill_condition: float = 100.0
static var barn_condition: float = 100.0
static var canopy_condition: float = 100.0
static var greenhouse_condition: float = 100.0

# Система помощи волонтёров (1 раз в час, +70% к скорости на 3 минуты)
const VOLUNTEER_COOLDOWN: int = 3600
const VOLUNTEER_DURATION: float = 180.0
static var last_volunteer_timestamp: int = 0
static var volunteer_timer: float = 0.0
static var is_volunteers_active: bool = false

# Теплицы
static var greenhouse_count: int = 0 # максимум 2
static var greenhouse_crop: String = "bananas"

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

# Статус аварийного состояния и событий
static var is_broken_down: bool = false
static var is_stuck_in_mud: bool = false
static var is_repairing: bool = false
static var is_strike_active: bool = false
static var is_police_active: bool = false

# Статистика сессии
static var total_harvested: int = 0
static var total_coins_earned: int = 0
static var total_strikes_resolved: int = 0
static var total_repairs_done: int = 0
static var total_bankruptcies: int = 0
static var total_salaries_paid: int = 0
static var total_fuel_spent: int = 0
static var total_greenhouse_earned: int = 0
static var total_fines_paid: int = 0

static func get_max_scarecrows() -> int:
	var screens: int = max(1, DisplayServer.get_screen_count())
	return screens * 3

static func get_total_debt() -> int:
	return subsidy_debt + loan_debt

## Множитель прибыли от количества используемых мониторов:
## Если 2 монитора используются для посева (все мониторы) - x2, если 3 - x3 и т.д.
static func get_monitor_profit_multiplier() -> float:
	var screen_idx: int = SettingsManager.get_screen_index()
	if screen_idx == WindowManager.SCREEN_ALL_MONITORS:
		var count: int = DisplayServer.get_screen_count()
		return float(max(1, count))
	return 1.0

# ==============================================================================
# СЕЗОНЫ И РЫНОЧНЫЕ ЦЕНЫ
# ==============================================================================
static func get_season_name(s: Season = current_season) -> String:
	match s:
		Season.SPRING:
			return "Весна 🌸"
		Season.SUMMER:
			return "Лето ☀️"
		Season.AUTUMN:
			return "Осень 🍂"
		Season.WINTER:
			return "Зима ❄️"
	return "Весна 🌸"

## Зимой дефицит еды — самая высокая цена на урожай!
static func get_season_price_multiplier(s: Season = current_season) -> float:
	match s:
		Season.WINTER:
			return 1.85 # Самая высокая цена зимой (+85%)
		Season.SPRING:
			return 1.20 # Весна (+20%)
		Season.SUMMER:
			return 1.00 # Лето (базовая цена)
		Season.AUTUMN:
			return 0.85 # Осень (сезон массового сбора, переизбыток)
	return 1.0

# ==============================================================================
# СОХРАНЕНИЕ И ЗАГРУЗКА
# ==============================================================================
static func init_from_settings() -> void:
	ProgressionManager.init_from_settings()
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

	# Топливо, износ, теплицы, волонтеры
	fuel_level = float(SettingsManager.config.get_value("mechanics", "fuel_level", 100.0))
	auto_refuel = bool(SettingsManager.config.get_value("mechanics", "auto_refuel", true))
	tractor_condition = float(SettingsManager.config.get_value("durability", "tractor_condition", 100.0))
	tanker_condition = float(SettingsManager.config.get_value("durability", "tanker_condition", 100.0))
	harvester_condition = float(SettingsManager.config.get_value("durability", "harvester_condition", 100.0))
	truck_condition = float(SettingsManager.config.get_value("durability", "truck_condition", 100.0))

	WorkerManager.init_from_settings()
	BuildingManager.init_from_settings()
	refresh_infrastructure_effects()
	VehicleManager.init_from_settings(
		{
			"heavy_tractor": has_heavy_tractor,
			"super_harvester": has_super_harvester,
			"road_train": has_road_train
		},
		{
			"tractor": tractor_condition,
			"tanker": tanker_condition,
			"harvester": harvester_condition,
			"truck": truck_condition
		}
	)
	_sync_legacy_vehicle_state()

	windmill_condition = float(SettingsManager.config.get_value("durability", "windmill_condition", 100.0))
	barn_condition = float(SettingsManager.config.get_value("durability", "barn_condition", 100.0))
	canopy_condition = float(SettingsManager.config.get_value("durability", "canopy_condition", 100.0))
	greenhouse_condition = float(SettingsManager.config.get_value("durability", "greenhouse_condition", 100.0))

	last_volunteer_timestamp = int(SettingsManager.config.get_value("volunteers", "last_timestamp", 0))
	is_volunteers_active = bool(SettingsManager.config.get_value("volunteers", "is_active", false))
	volunteer_timer = float(SettingsManager.config.get_value("volunteers", "timer", 0.0))

	greenhouse_count = int(SettingsManager.config.get_value("greenhouses", "count", 0))
	greenhouse_crop = str(SettingsManager.config.get_value("greenhouses", "crop", "bananas"))

	subsidy_debt = int(SettingsManager.config.get_value("finances", "subsidy_debt", 0))
	loan_debt = int(SettingsManager.config.get_value("finances", "loan_debt", 0))
	current_season = int(SettingsManager.config.get_value("game", "current_season", int(Season.SPRING))) as Season

	var unlocked_crops = SettingsManager.config.get_value("game", "unlocked_crops", ["wheat"])
	for crop_id in unlocked_crops:
		if CROPS.has(crop_id):
			CROPS[crop_id]["unlocked"] = true

	# Миграция старых сохранений: уже купленный контент не должен выглядеть как ферма 1 уровня.
	var legacy_min_level: int = 1
	for crop_id in CROPS:
		if bool(CROPS[crop_id]["unlocked"]):
			legacy_min_level = max(legacy_min_level, ProgressionManager.get_crop_required_level(str(crop_id)))
	if scarecrow_count > 0:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("scarecrow"))
	if canopy_count > 0:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("canopy"))
	if has_barn:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("barn"))
	if has_windmill:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("windmill"))
	if has_seeder_tractor:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("seeder"))
	if has_guard_dog:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("guard_dog"))
	if has_heavy_tractor:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("heavy_tractor"))
	if greenhouse_count > 0:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("greenhouse"))
	if has_road_train:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("road_train"))
	if has_super_harvester:
		legacy_min_level = max(legacy_min_level, ProgressionManager.get_feature_required_level("super_harvester"))
	ProgressionManager.ensure_minimum_level(legacy_min_level)

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

	_sync_legacy_vehicle_state()
	SettingsManager.config.set_value("game", "has_heavy_tractor", has_heavy_tractor)
	SettingsManager.config.set_value("game", "has_super_harvester", has_super_harvester)
	SettingsManager.config.set_value("game", "has_road_train", has_road_train)
	VehicleManager.write_to_config()
	WorkerManager.write_to_config()
	BuildingManager.write_to_config()

	SettingsManager.config.set_value("mechanics", "fuel_level", fuel_level)
	SettingsManager.config.set_value("mechanics", "auto_refuel", auto_refuel)
	SettingsManager.config.set_value("durability", "tractor_condition", tractor_condition)
	SettingsManager.config.set_value("durability", "tanker_condition", tanker_condition)
	SettingsManager.config.set_value("durability", "harvester_condition", harvester_condition)
	SettingsManager.config.set_value("durability", "truck_condition", truck_condition)
	SettingsManager.config.set_value("durability", "windmill_condition", windmill_condition)
	SettingsManager.config.set_value("durability", "barn_condition", barn_condition)
	SettingsManager.config.set_value("durability", "canopy_condition", canopy_condition)
	SettingsManager.config.set_value("durability", "greenhouse_condition", greenhouse_condition)

	SettingsManager.config.set_value("volunteers", "last_timestamp", last_volunteer_timestamp)
	SettingsManager.config.set_value("volunteers", "is_active", is_volunteers_active)
	SettingsManager.config.set_value("volunteers", "timer", volunteer_timer)

	SettingsManager.config.set_value("greenhouses", "count", greenhouse_count)
	SettingsManager.config.set_value("greenhouses", "crop", greenhouse_crop)
	SettingsManager.config.set_value("game", "current_season", int(current_season))

	SettingsManager.config.set_value("finances", "subsidy_debt", subsidy_debt)
	SettingsManager.config.set_value("finances", "loan_debt", loan_debt)
	SettingsManager.config.set_value("finances", "total_bankruptcies", total_bankruptcies)

	var unlocked_list: Array[String] = []
	for cid in CROPS:
		if CROPS[cid]["unlocked"]:
			unlocked_list.append(cid)
	SettingsManager.config.set_value("game", "unlocked_crops", unlocked_list)
	ProgressionManager.write_to_config()
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

## Текущая цена продажи со склада: базовая стоимость × инфраструктура × сезон × рынок.
static func calculate_crop_sale_value(crop_id: String, amount_kg: float) -> int:
	if amount_kg <= 0.0:
		return 0
	var data: Dictionary = CROPS.get(crop_id, CROPS["wheat"])
	var value: float = float(data.get("base_reward", 40)) * (amount_kg / 100.0)

	if has_barn:
		value *= 1.20
	if has_windmill:
		value *= 1.50
	value *= BuildingManager.get_sale_multiplier()
	value *= get_season_price_multiplier()
	value *= MarketManager.get_effective_multiplier(crop_id)
	return max(0, int(round(value)))

# ==============================================================================
# ТОПЛИВНАЯ СИСТЕМА
# ==============================================================================
static func consume_fuel(amount: float) -> bool:
	if fuel_level >= amount:
		fuel_level -= amount
		save_to_settings()
		return true
	fuel_level = 0.0
	save_to_settings()
	return false

static func refresh_infrastructure_effects() -> void:
	max_fuel = 100.0 + BuildingManager.get_extra_fuel_capacity()
	fuel_level = min(fuel_level, max_fuel)

static func calculate_refuel_cost(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return max(1, int(ceil(amount * 1.1 * BuildingManager.get_fuel_price_multiplier())))

static func refuel(amount: float, _legacy_cost: int = 0) -> bool:
	var cost: int = calculate_refuel_cost(amount)
	if spend_coins(cost):
		fuel_level = min(max_fuel, fuel_level + amount)
		total_fuel_spent += cost
		save_to_settings()
		return true
	return false

# ==============================================================================
# ИЗНОС И ТЕХОБСЛУЖИВАНИЕ (СТАРЕНИЕ)
# ==============================================================================
static func _sync_legacy_vehicle_state() -> void:
	if not VehicleManager.initialized:
		return
	has_heavy_tractor = VehicleManager.owns_model("tractor_heavy")
	has_super_harvester = VehicleManager.owns_model("harvester_super")
	has_road_train = VehicleManager.owns_model("truck_road_train")
	tractor_condition = VehicleManager.get_active_condition(VehicleManager.ROLE_TRACTOR)
	tanker_condition = VehicleManager.get_active_condition(VehicleManager.ROLE_TANKER)
	harvester_condition = VehicleManager.get_active_condition(VehicleManager.ROLE_HARVESTER)
	truck_condition = VehicleManager.get_active_condition(VehicleManager.ROLE_TRUCK)

static func degrade_durability() -> void:
	# Износ теперь применяется к реально активным экземплярам техники.
	var wear_mult: float = BuildingManager.get_wear_multiplier()
	VehicleManager.add_cycle_usage(VehicleManager.ROLE_TRACTOR, 4.0, 2.5 * wear_mult)
	VehicleManager.add_cycle_usage(VehicleManager.ROLE_TANKER, 2.0, 2.0 * wear_mult)
	VehicleManager.add_cycle_usage(VehicleManager.ROLE_HARVESTER, 5.0, 2.5 * wear_mult)
	VehicleManager.add_cycle_usage(VehicleManager.ROLE_TRUCK, 6.0, 2.0 * wear_mult)
	_sync_legacy_vehicle_state()

	if has_windmill:
		windmill_condition = max(10.0, windmill_condition - 1.2)
	if has_barn:
		barn_condition = max(10.0, barn_condition - 1.2)
	if canopy_count > 0:
		canopy_condition = max(10.0, canopy_condition - 1.2)
	if greenhouse_count > 0:
		greenhouse_condition = max(10.0, greenhouse_condition - 1.2)

	VehicleManager.save_to_settings()
	save_to_settings()

static func get_machinery_average_condition() -> float:
	if VehicleManager.initialized:
		return VehicleManager.get_average_active_condition()
	return (tractor_condition + tanker_condition + harvester_condition + truck_condition) / 4.0

static func get_machinery_repair_cost() -> int:
	return max(1, int(round(40.0 * BuildingManager.get_repair_cost_multiplier())))

static func get_building_repair_cost() -> int:
	return max(1, int(round(35.0 * BuildingManager.get_repair_cost_multiplier())))

static func repair_all_machinery() -> bool:
	var cost: int = get_machinery_repair_cost()
	if spend_coins(cost):
		if VehicleManager.initialized:
			VehicleManager.repair_all_owned()
			_sync_legacy_vehicle_state()
		else:
			tractor_condition = 100.0
			tanker_condition = 100.0
			harvester_condition = 100.0
			truck_condition = 100.0
		save_to_settings()
		return true
	return false

static func repair_all_buildings() -> bool:
	var cost: int = get_building_repair_cost()
	if spend_coins(cost):
		windmill_condition = 100.0
		barn_condition = 100.0
		canopy_condition = 100.0
		greenhouse_condition = 100.0
		save_to_settings()
		return true
	return false

# ==============================================================================
# ВОЛОНТЁРЫ (НЕ ЧАЩЕ 1 РАЗА В ЧАС, +70% СКОРОСТЬ)
# ==============================================================================
static func can_call_volunteers() -> bool:
	if is_volunteers_active:
		return false
	var now: int = int(Time.get_unix_time_from_system())
	return (now - last_volunteer_timestamp) >= VOLUNTEER_COOLDOWN

static func get_volunteer_cooldown_left() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	return max(0, VOLUNTEER_COOLDOWN - (now - last_volunteer_timestamp))

static func call_volunteers() -> bool:
	if not can_call_volunteers():
		return false
	last_volunteer_timestamp = int(Time.get_unix_time_from_system())
	is_volunteers_active = true
	volunteer_timer = VOLUNTEER_DURATION
	save_to_settings()
	return true

static func update_volunteers(delta: float) -> void:
	if not is_volunteers_active:
		return
	volunteer_timer -= delta
	if volunteer_timer <= 0.0:
		is_volunteers_active = false
		volunteer_timer = 0.0

# ==============================================================================
# ТЕПЛИЦЫ И ЭКЗОТИЧЕСКИЕ КУЛЬТУРЫ
# ==============================================================================
static func buy_greenhouse() -> bool:
	if greenhouse_count >= 2:
		return false
	var cost: int = 700
	if spend_coins(cost):
		greenhouse_count += 1
		greenhouse_condition = 100.0
		save_to_settings()
		return true
	return false

static func get_current_greenhouse_data() -> Dictionary:
	return GREENHOUSE_CROPS.get(greenhouse_crop, GREENHOUSE_CROPS["bananas"])

static func harvest_greenhouse() -> int:
	if greenhouse_count <= 0:
		return 0
	var data: Dictionary = get_current_greenhouse_data()
	var seed_c: int = int(data.get("seed_cost", 30)) * greenhouse_count
	var gross: int = int(data.get("reward", 90)) * greenhouse_count

	# Учитываем состояние теплицы
	var condition_mult: float = 1.0 if greenhouse_condition >= 40.0 else 0.7
	gross = int(gross * condition_mult)

	# Закупка партии семян
	if not spend_coins(seed_c):
		seed_c = 0

	var net: int = max(10, gross - seed_c)
	add_coins(net)
	total_greenhouse_earned += net
	return net

# ==============================================================================
# ФИНАНСОВЫЕ ОПЕРАЦИИ (СУБСИДИИ, КРЕДИТЫ, ВЫПЛАТЫ, БАНКРОТСТВО)
# ==============================================================================

## Взять государственную субсидию (+500 монет, долг 525 под 5%)
static func take_subsidy(amount: int = 500, percent: float = 5.0) -> bool:
	if subsidy_debt > 0:
		return false
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
		return false
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

## Производственные расходы одного завершённого цикла поля.
## Они списываются независимо от того, продан урожай сразу или оставлен на складе.
static func process_production_costs() -> Dictionary:
	var salary_payment: int = 0
	var fuel_payment: int = 0

	var base_salary: int = WorkerManager.get_total_salary_per_cycle() + (greenhouse_count * 8)
	# Зарплата является обязательным операционным расходом. При хранении урожая
	# казна может временно уйти в минус до последующей продажи запасов.
	salary_payment = base_salary
	coins -= salary_payment
	total_salaries_paid += salary_payment

	if auto_refuel and fuel_level < 25.0:
		var needed: float = max_fuel - fuel_level
		var fuel_cost: int = calculate_refuel_cost(needed)
		if coins >= fuel_cost:
			coins -= fuel_cost
			fuel_payment = fuel_cost
			fuel_level = max_fuel
			total_fuel_spent += fuel_cost

	degrade_durability()
	save_to_settings()
	return {
		"salary_paid": salary_payment,
		"fuel_paid": fuel_payment,
		"total_cost": salary_payment + fuel_payment
	}

## Обработка фактической продажи урожая: погашение долгов идёт только с реальной выручки.
static func process_sale_finances(gross_reward: int) -> Dictionary:
	var net_coins: int = max(0, gross_reward)
	var subsidy_payment: int = 0
	var loan_payment: int = 0

	if subsidy_debt > 0:
		subsidy_payment = min(subsidy_debt, int(gross_reward * 0.10))
		subsidy_debt -= subsidy_payment
		net_coins -= subsidy_payment

	if loan_debt > 0:
		loan_payment = min(loan_debt, int(gross_reward * 0.25))
		loan_debt -= loan_payment
		net_coins -= loan_payment

	net_coins = max(0, net_coins)
	add_coins(net_coins)
	save_to_settings()
	return {
		"gross_coins": gross_reward,
		"net_coins": net_coins,
		"subsidy_paid": subsidy_payment,
		"loan_paid": loan_payment,
		"total_debt_remaining": get_total_debt()
	}

## Совместимый wrapper для старых вызовов.
static func process_harvest_finances(gross_reward: int) -> Dictionary:
	var production: Dictionary = process_production_costs()
	var sale: Dictionary = process_sale_finances(gross_reward)
	return {
		"net_coins": int(sale.get("net_coins", 0)) - int(production.get("total_cost", 0)),
		"salary_paid": int(production.get("salary_paid", 0)),
		"subsidy_paid": int(sale.get("subsidy_paid", 0)),
		"loan_paid": int(sale.get("loan_paid", 0)),
		"fuel_paid": int(production.get("fuel_paid", 0)),
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
	greenhouse_count = 0
	has_heavy_tractor = false
	has_super_harvester = false
	has_road_train = false
	if VehicleManager.initialized:
		VehicleManager.reset_to_defaults()
		_sync_legacy_vehicle_state()
	active_decoration = "none"
	unlocked_decorations = ["none"]

	fuel_level = 100.0
	auto_refuel = true
	tractor_condition = 100.0
	tanker_condition = 100.0
	harvester_condition = 100.0
	truck_condition = 100.0
	windmill_condition = 100.0
	barn_condition = 100.0
	canopy_condition = 100.0
	greenhouse_condition = 100.0

	is_volunteers_active = false
	volunteer_timer = 0.0
	if WorkerManager.initialized:
		WorkerManager.reset_to_defaults()
	if BuildingManager.initialized:
		BuildingManager.reset_all()
		refresh_infrastructure_effects()

	# Блокировка платных культур
	for cid in CROPS:
		CROPS[cid]["unlocked"] = (cid == "wheat")

	is_broken_down = false
	is_stuck_in_mud = false
	is_repairing = false
	is_strike_active = false
	is_police_active = false
	current_season = Season.SPRING

	# Сброс сохраненных состояний поля и событий
	SettingsManager.config.set_value("field_state", "has_saved_state", false)
	SettingsManager.config.set_value("event_state", "has_saved_state", false)

	save_to_settings()
