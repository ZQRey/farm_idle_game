class_name LivestockManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")

const TICK_SECONDS: int = 300
const MAX_BUILDING_LEVEL: int = 3
const ANIMALS_PER_LEVEL: int = 4

const COOP_BUILD_COSTS: Dictionary = {1: 450, 2: 750, 3: 1200}
const BARN_BUILD_COSTS: Dictionary = {1: 900, 2: 1400, 3: 2100}
const CHICKEN_COST: int = 90
const COW_COST: int = 280

const CHICKEN_WHEAT_KG: float = 2.0
const CHICKEN_CORN_KG: float = 1.0
const EGGS_PER_CHICKEN: float = 3.0
const EGG_PRICE: int = 3

const COW_WHEAT_KG: float = 3.0
const COW_CORN_KG: float = 4.0
const MILK_L_PER_COW: float = 5.0
const MILK_PRICE: int = 5

static var coop_level: int = 0
static var barn_level: int = 0
static var chickens: int = 0
static var cows: int = 0
static var eggs: float = 0.0
static var milk_l: float = 0.0
static var auto_sell_products: bool = true
static var total_eggs_produced: float = 0.0
static var total_milk_produced: float = 0.0
static var total_product_coins: int = 0
static var last_tick_at: int = 0
static var initialized: bool = false

static func init_from_settings() -> void:
	coop_level = clampi(int(SettingsManager.config.get_value("livestock", "coop_level", 0)), 0, MAX_BUILDING_LEVEL)
	barn_level = clampi(int(SettingsManager.config.get_value("livestock", "barn_level", 0)), 0, MAX_BUILDING_LEVEL)
	chickens = clampi(int(SettingsManager.config.get_value("livestock", "chickens", 0)), 0, get_chicken_capacity())
	cows = clampi(int(SettingsManager.config.get_value("livestock", "cows", 0)), 0, get_cow_capacity())
	eggs = max(0.0, float(SettingsManager.config.get_value("livestock", "eggs", 0.0)))
	milk_l = max(0.0, float(SettingsManager.config.get_value("livestock", "milk_l", 0.0)))
	auto_sell_products = bool(SettingsManager.config.get_value("livestock", "auto_sell_products", true))
	total_eggs_produced = max(0.0, float(SettingsManager.config.get_value("livestock", "total_eggs_produced", 0.0)))
	total_milk_produced = max(0.0, float(SettingsManager.config.get_value("livestock", "total_milk_produced", 0.0)))
	total_product_coins = max(0, int(SettingsManager.config.get_value("livestock", "total_product_coins", 0)))
	last_tick_at = max(0, int(SettingsManager.config.get_value("livestock", "last_tick_at", 0)))
	if last_tick_at <= 0:
		last_tick_at = _now()
	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("livestock", "coop_level", coop_level)
	SettingsManager.config.set_value("livestock", "barn_level", barn_level)
	SettingsManager.config.set_value("livestock", "chickens", chickens)
	SettingsManager.config.set_value("livestock", "cows", cows)
	SettingsManager.config.set_value("livestock", "eggs", eggs)
	SettingsManager.config.set_value("livestock", "milk_l", milk_l)
	SettingsManager.config.set_value("livestock", "auto_sell_products", auto_sell_products)
	SettingsManager.config.set_value("livestock", "total_eggs_produced", total_eggs_produced)
	SettingsManager.config.set_value("livestock", "total_milk_produced", total_milk_produced)
	SettingsManager.config.set_value("livestock", "total_product_coins", total_product_coins)
	SettingsManager.config.set_value("livestock", "last_tick_at", last_tick_at)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_chicken_capacity() -> int:
	return coop_level * ANIMALS_PER_LEVEL

static func get_cow_capacity() -> int:
	return barn_level * ANIMALS_PER_LEVEL

static func get_coop_upgrade_cost() -> int:
	if coop_level >= MAX_BUILDING_LEVEL:
		return 0
	return int(COOP_BUILD_COSTS.get(coop_level + 1, 0))

static func get_barn_upgrade_cost() -> int:
	if barn_level >= MAX_BUILDING_LEVEL:
		return 0
	return int(BARN_BUILD_COSTS.get(barn_level + 1, 0))

static func upgrade_coop() -> bool:
	var cost: int = get_coop_upgrade_cost()
	if cost <= 0 or not GameManager.spend_coins(cost):
		return false
	coop_level += 1
	save_to_settings()
	return true

static func upgrade_barn() -> bool:
	var cost: int = get_barn_upgrade_cost()
	if cost <= 0 or not GameManager.spend_coins(cost):
		return false
	barn_level += 1
	save_to_settings()
	return true

static func buy_chicken() -> bool:
	if chickens >= get_chicken_capacity() or not GameManager.spend_coins(CHICKEN_COST):
		return false
	chickens += 1
	save_to_settings()
	return true

static func buy_cow() -> bool:
	if cows >= get_cow_capacity() or not GameManager.spend_coins(COW_COST):
		return false
	cows += 1
	save_to_settings()
	return true

static func can_feed_chickens() -> bool:
	return chickens > 0 		and InventoryManager.get_stock("wheat") >= CHICKEN_WHEAT_KG * chickens 		and InventoryManager.get_stock("corn") >= CHICKEN_CORN_KG * chickens

static func can_feed_cows() -> bool:
	return cows > 0 		and InventoryManager.get_stock("wheat") >= COW_WHEAT_KG * cows 		and InventoryManager.get_stock("corn") >= COW_CORN_KG * cows

static func process_due_ticks(max_ticks: int = 12) -> Dictionary:
	var now: int = _now()
	var elapsed: int = max(0, now - last_tick_at)
	var due: int = min(max_ticks, int(elapsed / TICK_SECONDS))
	if due <= 0:
		return _empty_report()
	var report: Dictionary = process_ticks(due)
	last_tick_at = now
	save_to_settings()
	return report

static func process_ticks(tick_count: int) -> Dictionary:
	var report: Dictionary = _empty_report()
	for _i in range(max(0, tick_count)):
		var one: Dictionary = _process_single_tick()
		report["ticks"] = int(report["ticks"]) + 1
		report["eggs"] = float(report["eggs"]) + float(one["eggs"])
		report["milk_l"] = float(report["milk_l"]) + float(one["milk_l"])
		report["coins"] = int(report["coins"]) + int(one["coins"])
		report["chicken_fed"] = int(report["chicken_fed"]) + int(one["chicken_fed"])
		report["cow_fed"] = int(report["cow_fed"]) + int(one["cow_fed"])
	save_to_settings()
	return report

static func sell_all_products() -> int:
	var gross: int = int(round(eggs * EGG_PRICE + milk_l * MILK_PRICE))
	if gross <= 0:
		return 0
	eggs = 0.0
	milk_l = 0.0
	var sale: Dictionary = GameManager.process_sale_finances(gross)
	var net: int = int(sale.get("net_coins", 0))
	total_product_coins += net
	save_to_settings()
	return net

static func set_auto_sell(enabled: bool) -> void:
	auto_sell_products = enabled
	save_to_settings()

static func reset_all() -> void:
	coop_level = 0
	barn_level = 0
	chickens = 0
	cows = 0
	eggs = 0.0
	milk_l = 0.0
	auto_sell_products = true
	total_eggs_produced = 0.0
	total_milk_produced = 0.0
	total_product_coins = 0
	last_tick_at = _now()
	save_to_settings()

static func _process_single_tick() -> Dictionary:
	var produced_eggs: float = 0.0
	var produced_milk: float = 0.0
	var chicken_fed: int = 0
	var cow_fed: int = 0

	if can_feed_chickens():
		InventoryManager.remove_crop("wheat", CHICKEN_WHEAT_KG * chickens)
		InventoryManager.remove_crop("corn", CHICKEN_CORN_KG * chickens)
		produced_eggs = EGGS_PER_CHICKEN * chickens
		eggs += produced_eggs
		total_eggs_produced += produced_eggs
		chicken_fed = chickens

	if can_feed_cows():
		InventoryManager.remove_crop("wheat", COW_WHEAT_KG * cows)
		InventoryManager.remove_crop("corn", COW_CORN_KG * cows)
		produced_milk = MILK_L_PER_COW * cows
		milk_l += produced_milk
		total_milk_produced += produced_milk
		cow_fed = cows

	var coins: int = 0
	if auto_sell_products and (eggs > 0.0 or milk_l > 0.0):
		coins = sell_all_products()

	return {
		"eggs": produced_eggs,
		"milk_l": produced_milk,
		"coins": coins,
		"chicken_fed": chicken_fed,
		"cow_fed": cow_fed
	}

static func _empty_report() -> Dictionary:
	return {
		"ticks": 0,
		"eggs": 0.0,
		"milk_l": 0.0,
		"coins": 0,
		"chicken_fed": 0,
		"cow_fed": 0
	}

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
