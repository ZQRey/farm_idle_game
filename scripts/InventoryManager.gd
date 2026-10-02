class_name InventoryManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")

const CROP_IDS: Array[String] = ["wheat", "corn", "sunflower", "carrot"]
const BASE_HARVEST_KG: float = 100.0
const MAX_STORAGE_LEVEL: int = 4

const CAPACITY_BY_LEVEL: Dictionary = {
	1: 500.0,
	2: 1000.0,
	3: 2500.0,
	4: 5000.0
}

const UPGRADE_COST_BY_LEVEL: Dictionary = {
	2: 300,
	3: 750,
	4: 1600
}

static var stock: Dictionary = {
	"wheat": 0.0,
	"corn": 0.0,
	"sunflower": 0.0,
	"carrot": 0.0
}

static var storage_level: int = 1
static var auto_sell_on_harvest: bool = true
static var total_harvest_stored_kg: float = 0.0
static var total_overflow_kg: float = 0.0
static var initialized: bool = false

static func init_from_settings() -> void:
	var saved_stock: Variant = SettingsManager.config.get_value("inventory", "stock", {})
	stock = _empty_stock()
	if typeof(saved_stock) == TYPE_DICTIONARY:
		for crop_id in CROP_IDS:
			stock[crop_id] = max(0.0, float(saved_stock.get(crop_id, 0.0)))

	storage_level = clampi(int(SettingsManager.config.get_value("inventory", "storage_level", 1)), 1, MAX_STORAGE_LEVEL)
	auto_sell_on_harvest = bool(SettingsManager.config.get_value("inventory", "auto_sell_on_harvest", true))
	total_harvest_stored_kg = max(0.0, float(SettingsManager.config.get_value("inventory", "total_harvest_stored_kg", 0.0)))
	total_overflow_kg = max(0.0, float(SettingsManager.config.get_value("inventory", "total_overflow_kg", 0.0)))
	initialized = true
	_clamp_stock_to_capacity()
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("inventory", "stock", stock)
	SettingsManager.config.set_value("inventory", "storage_level", storage_level)
	SettingsManager.config.set_value("inventory", "auto_sell_on_harvest", auto_sell_on_harvest)
	SettingsManager.config.set_value("inventory", "total_harvest_stored_kg", total_harvest_stored_kg)
	SettingsManager.config.set_value("inventory", "total_overflow_kg", total_overflow_kg)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_capacity() -> float:
	return float(CAPACITY_BY_LEVEL.get(storage_level, 500.0)) + BuildingManager.get_storage_bonus_kg()

static func get_total_stock() -> float:
	var total: float = 0.0
	for crop_id in CROP_IDS:
		total += float(stock.get(crop_id, 0.0))
	return total

static func get_free_capacity() -> float:
	return max(0.0, get_capacity() - get_total_stock())

static func get_fill_ratio() -> float:
	var capacity: float = get_capacity()
	if capacity <= 0.0:
		return 0.0
	return clampf(get_total_stock() / capacity, 0.0, 1.0)

static func get_stock(crop_id: String) -> float:
	return max(0.0, float(stock.get(crop_id, 0.0)))

static func calculate_harvest_kg(monitor_multiplier: float = 1.0, super_harvester: bool = false) -> float:
	var amount: float = BASE_HARVEST_KG * max(1.0, monitor_multiplier)
	if super_harvester:
		amount *= 1.15
	return amount

static func deposit_crop(crop_id: String, amount_kg: float) -> Dictionary:
	if not initialized or not stock.has(crop_id):
		return {"stored_kg": 0.0, "overflow_kg": max(0.0, amount_kg)}

	var requested: float = max(0.0, amount_kg)
	var stored_amount: float = min(requested, get_free_capacity())
	var overflow_amount: float = max(0.0, requested - stored_amount)

	stock[crop_id] = get_stock(crop_id) + stored_amount
	total_harvest_stored_kg += stored_amount
	total_overflow_kg += overflow_amount
	save_to_settings()

	return {
		"stored_kg": stored_amount,
		"overflow_kg": overflow_amount
	}

static func remove_crop(crop_id: String, amount_kg: float) -> float:
	if not initialized or not stock.has(crop_id):
		return 0.0
	var available: float = get_stock(crop_id)
	var removed: float = min(available, max(0.0, amount_kg))
	stock[crop_id] = max(0.0, available - removed)
	save_to_settings()
	return removed

static func set_auto_sell(enabled: bool) -> void:
	auto_sell_on_harvest = enabled
	save_to_settings()

static func ensure_minimum_level(minimum_level: int) -> bool:
	if not initialized:
		return false
	var target: int = clampi(minimum_level, 1, MAX_STORAGE_LEVEL)
	if storage_level >= target:
		return false
	storage_level = target
	save_to_settings()
	return true

static func can_upgrade() -> bool:
	return storage_level < MAX_STORAGE_LEVEL

static func get_next_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	return int(UPGRADE_COST_BY_LEVEL.get(storage_level + 1, 0))

static func upgrade_capacity() -> bool:
	if not initialized or not can_upgrade():
		return false
	storage_level += 1
	save_to_settings()
	return true

static func reset_all() -> void:
	if not initialized:
		return
	stock = _empty_stock()
	storage_level = 1
	auto_sell_on_harvest = true
	total_harvest_stored_kg = 0.0
	total_overflow_kg = 0.0
	save_to_settings()

static func _clamp_stock_to_capacity() -> void:
	var capacity: float = get_capacity()
	var total: float = get_total_stock()
	if total <= capacity or total <= 0.0:
		return

	# При миграции повреждённого/старого save пропорционально уменьшаем запас до ёмкости.
	var factor: float = capacity / total
	for crop_id in CROP_IDS:
		stock[crop_id] = get_stock(crop_id) * factor

static func _empty_stock() -> Dictionary:
	return {
		"wheat": 0.0,
		"corn": 0.0,
		"sunflower": 0.0,
		"carrot": 0.0
	}
