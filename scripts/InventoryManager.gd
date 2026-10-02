class_name InventoryManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const QualityManager = preload("res://scripts/QualityManager.gd")

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

static var quality_stock: Dictionary = {}

static var storage_level: int = 1
static var auto_sell_on_harvest: bool = true
static var total_harvest_stored_kg: float = 0.0
static var total_overflow_kg: float = 0.0
static var initialized: bool = false

static func init_from_settings() -> void:
	var saved_stock: Variant = SettingsManager.config.get_value("inventory", "stock", {})
	var saved_quality_stock: Variant = SettingsManager.config.get_value("inventory", "quality_stock", {})
	stock = _empty_stock()
	quality_stock = _empty_quality_stock()

	if typeof(saved_quality_stock) == TYPE_DICTIONARY and not saved_quality_stock.is_empty():
		for crop_id in CROP_IDS:
			var crop_quality: Variant = saved_quality_stock.get(crop_id, {})
			if typeof(crop_quality) == TYPE_DICTIONARY:
				for grade in QualityManager.GRADES:
					quality_stock[crop_id][grade] = max(0.0, float(crop_quality.get(grade, 0.0)))
		_rebuild_aggregate_stock()
	elif typeof(saved_stock) == TYPE_DICTIONARY:
		# Миграция старого склада: урожай без качества становится нейтральным классом B.
		for crop_id in CROP_IDS:
			var amount: float = max(0.0, float(saved_stock.get(crop_id, 0.0)))
			quality_stock[crop_id]["B"] = amount
			stock[crop_id] = amount

	storage_level = clampi(int(SettingsManager.config.get_value("inventory", "storage_level", 1)), 1, MAX_STORAGE_LEVEL)
	auto_sell_on_harvest = bool(SettingsManager.config.get_value("inventory", "auto_sell_on_harvest", true))
	total_harvest_stored_kg = max(0.0, float(SettingsManager.config.get_value("inventory", "total_harvest_stored_kg", 0.0)))
	total_overflow_kg = max(0.0, float(SettingsManager.config.get_value("inventory", "total_overflow_kg", 0.0)))
	initialized = true
	_clamp_stock_to_capacity()
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("inventory", "stock", stock)
	SettingsManager.config.set_value("inventory", "quality_stock", quality_stock)
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

static func get_stock_by_quality(crop_id: String, grade: String) -> float:
	if not quality_stock.has(crop_id):
		return 0.0
	var bucket: Dictionary = quality_stock[crop_id]
	return max(0.0, float(bucket.get(QualityManager.normalize_grade(grade), 0.0)))

static func get_quality_breakdown(crop_id: String) -> Dictionary:
	var result: Dictionary = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	if not quality_stock.has(crop_id):
		return result
	var bucket: Dictionary = quality_stock[crop_id]
	for grade in QualityManager.GRADES:
		result[grade] = max(0.0, float(bucket.get(grade, 0.0)))
	return result

static func calculate_harvest_kg(monitor_multiplier: float = 1.0, super_harvester: bool = false) -> float:
	var amount: float = BASE_HARVEST_KG * max(1.0, monitor_multiplier)
	if super_harvester:
		amount *= 1.15
	return amount

static func deposit_crop(crop_id: String, amount_kg: float, quality_grade: String = "B") -> Dictionary:
	if not initialized or not stock.has(crop_id):
		return {"stored_kg": 0.0, "overflow_kg": max(0.0, amount_kg), "grade": QualityManager.normalize_grade(quality_grade)}

	var requested: float = max(0.0, amount_kg)
	var stored_amount: float = min(requested, get_free_capacity())
	var overflow_amount: float = max(0.0, requested - stored_amount)
	var grade: String = QualityManager.normalize_grade(quality_grade)

	if not quality_stock.has(crop_id):
		quality_stock[crop_id] = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	var bucket: Dictionary = quality_stock[crop_id]
	bucket[grade] = max(0.0, float(bucket.get(grade, 0.0)) + stored_amount)
	quality_stock[crop_id] = bucket
	stock[crop_id] = get_stock(crop_id) + stored_amount

	total_harvest_stored_kg += stored_amount
	total_overflow_kg += overflow_amount
	save_to_settings()

	return {
		"stored_kg": stored_amount,
		"overflow_kg": overflow_amount,
		"grade": grade
	}

static func remove_crop_with_quality(crop_id: String, amount_kg: float) -> Dictionary:
	var result: Dictionary = {"total_kg": 0.0, "C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	if not initialized or not stock.has(crop_id):
		return result

	var remaining: float = min(get_stock(crop_id), max(0.0, amount_kg))
	# При обычной продаже сначала уходит более низкий класс: ценный урожай сохраняется дольше.
	for grade in QualityManager.GRADES:
		if remaining <= 0.0:
			break
		var available: float = get_stock_by_quality(crop_id, grade)
		var take: float = min(available, remaining)
		if take <= 0.0:
			continue
		var bucket: Dictionary = quality_stock[crop_id]
		bucket[grade] = max(0.0, available - take)
		quality_stock[crop_id] = bucket
		result[grade] = take
		result["total_kg"] = float(result["total_kg"]) + take
		remaining -= take

	_rebuild_crop_aggregate(crop_id)
	save_to_settings()
	return result

static func remove_crop(crop_id: String, amount_kg: float) -> float:
	return float(remove_crop_with_quality(crop_id, amount_kg).get("total_kg", 0.0))

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
	quality_stock = _empty_quality_stock()
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

	# При миграции повреждённого/старого save пропорционально уменьшаем все
	# качественные партии, затем заново строим агрегированный stock.
	var factor: float = capacity / total
	for crop_id in CROP_IDS:
		if not quality_stock.has(crop_id):
			continue
		var bucket: Dictionary = quality_stock[crop_id]
		for grade in QualityManager.GRADES:
			bucket[grade] = max(0.0, float(bucket.get(grade, 0.0)) * factor)
		quality_stock[crop_id] = bucket
	_rebuild_aggregate_stock()

static func _rebuild_crop_aggregate(crop_id: String) -> void:
	var total: float = 0.0
	if quality_stock.has(crop_id):
		var bucket: Dictionary = quality_stock[crop_id]
		for grade in QualityManager.GRADES:
			total += max(0.0, float(bucket.get(grade, 0.0)))
	stock[crop_id] = total

static func _rebuild_aggregate_stock() -> void:
	for crop_id in CROP_IDS:
		_rebuild_crop_aggregate(crop_id)

static func _empty_quality_stock() -> Dictionary:
	var result: Dictionary = {}
	for crop_id in CROP_IDS:
		result[crop_id] = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	return result

static func _empty_stock() -> Dictionary:
	return {
		"wheat": 0.0,
		"corn": 0.0,
		"sunflower": 0.0,
		"carrot": 0.0
	}
