class_name ProcessingManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const LivestockManager = preload("res://scripts/LivestockManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")

const TICK_SECONDS: int = 300
const MAX_LEVEL: int = 3

const FACILITY_ORDER: Array[String] = ["flour_mill", "oil_press", "dairy"]

const FACILITIES: Dictionary = {
	"flour_mill": {
		"name": "Мукомольный цех",
		"icon": "🌾",
		"costs": {1: 850, 2: 1300, 3: 2000},
		"input_kind": "crop",
		"input_id": "wheat",
		"input_amount": 100.0,
		"output_id": "flour",
		"output_amount": 70.0,
		"description": "100 кг пшеницы → 70 кг муки"
	},
	"oil_press": {
		"name": "Маслопресс",
		"icon": "🌻",
		"costs": {1: 1000, 2: 1550, 3: 2350},
		"input_kind": "crop",
		"input_id": "sunflower",
		"input_amount": 50.0,
		"output_id": "oil",
		"output_amount": 18.0,
		"description": "50 кг подсолнечника → 18 л масла"
	},
	"dairy": {
		"name": "Молочный цех",
		"icon": "🧀",
		"costs": {1: 1200, 2: 1800, 3: 2700},
		"input_kind": "livestock",
		"input_id": "milk",
		"input_amount": 20.0,
		"output_id": "cheese",
		"output_amount": 5.0,
		"description": "20 л молока → 5 кг сыра"
	}
}

const PRODUCT_ORDER: Array[String] = ["flour", "oil", "cheese"]
const PRODUCTS: Dictionary = {
	"flour": {"name": "Мука", "icon": "🌾", "unit": "кг", "price": 1},
	"oil": {"name": "Подсолнечное масло", "icon": "🫗", "unit": "л", "price": 8},
	"cheese": {"name": "Сыр", "icon": "🧀", "unit": "кг", "price": 28}
}

static var facility_levels: Dictionary = {}
static var products: Dictionary = {}
static var auto_sell_products: bool = true
static var total_batches: int = 0
static var total_product_coins: int = 0
static var lifetime_output: Dictionary = {}
static var last_tick_at: int = 0
static var initialized: bool = false

static func init_from_settings() -> void:
	facility_levels = _empty_facilities()
	var saved_levels: Variant = SettingsManager.config.get_value("processing", "facility_levels", {})
	if typeof(saved_levels) == TYPE_DICTIONARY:
		for facility_id in FACILITY_ORDER:
			facility_levels[facility_id] = clampi(int(saved_levels.get(facility_id, 0)), 0, MAX_LEVEL)

	products = _empty_products()
	var saved_products: Variant = SettingsManager.config.get_value("processing", "products", {})
	if typeof(saved_products) == TYPE_DICTIONARY:
		for product_id in PRODUCT_ORDER:
			products[product_id] = max(0.0, float(saved_products.get(product_id, 0.0)))

	lifetime_output = _empty_products()
	var saved_lifetime: Variant = SettingsManager.config.get_value("processing", "lifetime_output", {})
	if typeof(saved_lifetime) == TYPE_DICTIONARY:
		for product_id in PRODUCT_ORDER:
			lifetime_output[product_id] = max(0.0, float(saved_lifetime.get(product_id, 0.0)))

	auto_sell_products = bool(SettingsManager.config.get_value("processing", "auto_sell_products", true))
	total_batches = max(0, int(SettingsManager.config.get_value("processing", "total_batches", 0)))
	total_product_coins = max(0, int(SettingsManager.config.get_value("processing", "total_product_coins", 0)))
	last_tick_at = max(0, int(SettingsManager.config.get_value("processing", "last_tick_at", 0)))
	if last_tick_at <= 0:
		last_tick_at = _now()

	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("processing", "facility_levels", facility_levels)
	SettingsManager.config.set_value("processing", "products", products)
	SettingsManager.config.set_value("processing", "lifetime_output", lifetime_output)
	SettingsManager.config.set_value("processing", "auto_sell_products", auto_sell_products)
	SettingsManager.config.set_value("processing", "total_batches", total_batches)
	SettingsManager.config.set_value("processing", "total_product_coins", total_product_coins)
	SettingsManager.config.set_value("processing", "last_tick_at", last_tick_at)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_facility_level(facility_id: String) -> int:
	return clampi(int(facility_levels.get(facility_id, 0)), 0, MAX_LEVEL)

static func get_upgrade_cost(facility_id: String) -> int:
	if not FACILITIES.has(facility_id) or get_facility_level(facility_id) >= MAX_LEVEL:
		return 0
	var info: Dictionary = FACILITIES[facility_id]
	var costs: Dictionary = info.get("costs", {})
	return int(costs.get(get_facility_level(facility_id) + 1, 0))

static func upgrade_facility(facility_id: String) -> bool:
	var cost: int = get_upgrade_cost(facility_id)
	if cost <= 0 or not GameManager.spend_coins(cost):
		return false
	facility_levels[facility_id] = get_facility_level(facility_id) + 1
	save_to_settings()
	return true

static func get_product_amount(product_id: String) -> float:
	return max(0.0, float(products.get(product_id, 0.0)))

static func can_process_batch(facility_id: String) -> bool:
	if get_facility_level(facility_id) <= 0 or not FACILITIES.has(facility_id):
		return false
	var info: Dictionary = FACILITIES[facility_id]
	var input_kind: String = str(info.get("input_kind", "crop"))
	var input_id: String = str(info.get("input_id", ""))
	var input_amount: float = float(info.get("input_amount", 0.0))
	if input_kind == "crop":
		return InventoryManager.get_stock(input_id) >= input_amount
	if input_kind == "livestock" and input_id == "milk":
		return LivestockManager.milk_l >= input_amount
	return false

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

static func process_offline_seconds(credited_seconds: int, efficiency: float) -> Dictionary:
	var effective: float = float(max(0, credited_seconds)) * clampf(efficiency, 0.0, 1.0)
	var ticks: int = int(floor(effective / float(TICK_SECONDS)))
	var report: Dictionary = process_ticks(ticks)
	last_tick_at = _now()
	save_to_settings()
	return report

static func process_ticks(tick_count: int) -> Dictionary:
	var report: Dictionary = _empty_report()
	for _i in range(max(0, tick_count)):
		report["ticks"] = int(report["ticks"]) + 1
		for facility_id in FACILITY_ORDER:
			var level: int = get_facility_level(facility_id)
			for _batch in range(level):
				if not can_process_batch(facility_id):
					break
				var produced: Dictionary = _process_batch(facility_id)
				if produced.is_empty():
					break
				var product_id: String = str(produced.get("product_id", ""))
				var amount: float = float(produced.get("amount", 0.0))
				report["batches"] = int(report["batches"]) + 1
				report["outputs"][product_id] = float(report["outputs"].get(product_id, 0.0)) + amount

	if auto_sell_products:
		var coins: int = sell_all_products()
		report["coins"] = coins

	save_to_settings()
	return report

static func sell_all_products() -> int:
	var gross: int = 0
	for product_id in PRODUCT_ORDER:
		var amount: float = get_product_amount(product_id)
		if amount <= 0.0:
			continue
		var info: Dictionary = PRODUCTS[product_id]
		gross += int(round(amount * float(info.get("price", 0))))
	if gross <= 0:
		return 0

	for product_id in PRODUCT_ORDER:
		products[product_id] = 0.0

	var sale: Dictionary = GameManager.process_sale_finances(gross)
	var net: int = int(sale.get("net_coins", 0))
	total_product_coins += net
	save_to_settings()
	return net

static func set_auto_sell(enabled: bool) -> void:
	auto_sell_products = enabled
	save_to_settings()

static func reset_all() -> void:
	facility_levels = _empty_facilities()
	products = _empty_products()
	lifetime_output = _empty_products()
	auto_sell_products = true
	total_batches = 0
	total_product_coins = 0
	last_tick_at = _now()
	save_to_settings()

static func _process_batch(facility_id: String) -> Dictionary:
	if not can_process_batch(facility_id):
		return {}

	var info: Dictionary = FACILITIES[facility_id]
	var input_kind: String = str(info.get("input_kind", "crop"))
	var input_id: String = str(info.get("input_id", ""))
	var input_amount: float = float(info.get("input_amount", 0.0))
	var output_id: String = str(info.get("output_id", ""))
	var output_amount: float = float(info.get("output_amount", 0.0))

	if input_kind == "crop":
		var removed: float = InventoryManager.remove_crop(input_id, input_amount)
		if removed + 0.001 < input_amount:
			return {}
	elif input_kind == "livestock" and input_id == "milk":
		if not LivestockManager.consume_milk(input_amount):
			return {}
	else:
		return {}

	products[output_id] = get_product_amount(output_id) + output_amount
	lifetime_output[output_id] = max(0.0, float(lifetime_output.get(output_id, 0.0)) + output_amount)
	total_batches += 1
	return {"product_id": output_id, "amount": output_amount}

static func _empty_facilities() -> Dictionary:
	return {"flour_mill": 0, "oil_press": 0, "dairy": 0}

static func _empty_products() -> Dictionary:
	return {"flour": 0.0, "oil": 0.0, "cheese": 0.0}

static func _empty_report() -> Dictionary:
	return {
		"ticks": 0,
		"batches": 0,
		"outputs": _empty_products(),
		"coins": 0
	}

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
