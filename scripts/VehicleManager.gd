class_name VehicleManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

const ROLE_TRACTOR: String = "tractor"
const ROLE_TANKER: String = "tanker"
const ROLE_HARVESTER: String = "harvester"
const ROLE_TRUCK: String = "truck"
const ROLES: Array[String] = [ROLE_TRACTOR, ROLE_TANKER, ROLE_HARVESTER, ROLE_TRUCK]

const CATALOG: Dictionary = {
	"tractor_basic": {
		"name": "МТЗ-82",
		"role": ROLE_TRACTOR,
		"class": "standard",
		"speed_mult": 1.00,
		"fuel_mult": 1.00,
		"reliability": 0.88,
		"capacity_mult": 1.00,
		"purchase_cost": 0
	},
	"tractor_heavy": {
		"name": "Кировец К-7М",
		"role": ROLE_TRACTOR,
		"class": "heavy",
		"speed_mult": 1.60,
		"fuel_mult": 1.35,
		"reliability": 0.93,
		"capacity_mult": 1.00,
		"purchase_cost": 800
	},
	"tanker_basic": {
		"name": "ЗИЛ-130 АЦ",
		"role": ROLE_TANKER,
		"class": "standard",
		"speed_mult": 1.00,
		"fuel_mult": 1.00,
		"reliability": 0.86,
		"capacity_mult": 1.00,
		"purchase_cost": 0
	},
	"harvester_basic": {
		"name": "ДОН-1500",
		"role": ROLE_HARVESTER,
		"class": "standard",
		"speed_mult": 0.90,
		"fuel_mult": 1.00,
		"reliability": 0.85,
		"capacity_mult": 1.00,
		"purchase_cost": 0
	},
	"harvester_super": {
		"name": "CLAAS Lexion 8900",
		"role": ROLE_HARVESTER,
		"class": "premium",
		"speed_mult": 1.60,
		"fuel_mult": 1.30,
		"reliability": 0.95,
		"capacity_mult": 1.15,
		"purchase_cost": 1200
	},
	"truck_basic": {
		"name": "ГАЗ-53",
		"role": ROLE_TRUCK,
		"class": "standard",
		"speed_mult": 1.10,
		"fuel_mult": 1.00,
		"reliability": 0.84,
		"capacity_mult": 1.00,
		"purchase_cost": 0
	},
	"truck_road_train": {
		"name": "КАМАЗ Автопоезд",
		"role": ROLE_TRUCK,
		"class": "heavy",
		"speed_mult": 1.90,
		"fuel_mult": 1.45,
		"reliability": 0.92,
		"capacity_mult": 1.20,
		"purchase_cost": 950
	}
}

static var vehicles: Dictionary = {}
static var active_by_role: Dictionary = {}
static var next_vehicle_id: int = 1
static var initialized: bool = false

static func init_from_settings(legacy_flags: Dictionary = {}, legacy_conditions: Dictionary = {}) -> void:
	var saved_vehicles: Variant = SettingsManager.config.get_value("garage2", "vehicles", {})
	var saved_active: Variant = SettingsManager.config.get_value("garage2", "active_by_role", {})
	next_vehicle_id = max(1, int(SettingsManager.config.get_value("garage2", "next_vehicle_id", 1)))

	if typeof(saved_vehicles) == TYPE_DICTIONARY and not saved_vehicles.is_empty():
		vehicles = saved_vehicles.duplicate(true)
		active_by_role = saved_active.duplicate(true) if typeof(saved_active) == TYPE_DICTIONARY else {}
	else:
		vehicles = {}
		active_by_role = {}
		_add_vehicle_internal("tractor_basic", float(legacy_conditions.get("tractor", 100.0)), true)
		_add_vehicle_internal("tanker_basic", float(legacy_conditions.get("tanker", 100.0)), true)
		_add_vehicle_internal("harvester_basic", float(legacy_conditions.get("harvester", 100.0)), true)
		_add_vehicle_internal("truck_basic", float(legacy_conditions.get("truck", 100.0)), true)

		if bool(legacy_flags.get("heavy_tractor", false)):
			_add_vehicle_internal("tractor_heavy", float(legacy_conditions.get("tractor", 100.0)), true)
		if bool(legacy_flags.get("super_harvester", false)):
			_add_vehicle_internal("harvester_super", float(legacy_conditions.get("harvester", 100.0)), true)
		if bool(legacy_flags.get("road_train", false)):
			_add_vehicle_internal("truck_road_train", float(legacy_conditions.get("truck", 100.0)), true)

	initialized = true
	_repair_invalid_active_refs()
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("garage2", "vehicles", vehicles)
	SettingsManager.config.set_value("garage2", "active_by_role", active_by_role)
	SettingsManager.config.set_value("garage2", "next_vehicle_id", next_vehicle_id)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func owns_model(model_id: String) -> bool:
	for vehicle_id in vehicles:
		var v: Dictionary = vehicles[vehicle_id]
		if str(v.get("model_id", "")) == model_id:
			return true
	return false

static func purchase_model(model_id: String) -> bool:
	if not initialized or not CATALOG.has(model_id) or owns_model(model_id):
		return false
	_add_vehicle_internal(model_id, 100.0, true)
	save_to_settings()
	return true

static func get_active_vehicle(role: String) -> Dictionary:
	var id: String = str(active_by_role.get(role, ""))
	if id != "" and vehicles.has(id):
		return vehicles[id]
	return {}

static func get_active_model_id(role: String) -> String:
	var v: Dictionary = get_active_vehicle(role)
	return str(v.get("model_id", ""))

static func set_active_vehicle(role: String, vehicle_id: String) -> bool:
	if not vehicles.has(vehicle_id):
		return false
	var v: Dictionary = vehicles[vehicle_id]
	if str(v.get("role", "")) != role:
		return false
	active_by_role[role] = vehicle_id
	save_to_settings()
	return true

static func set_active_model(role: String, model_id: String) -> bool:
	for vehicle_id in vehicles:
		var v: Dictionary = vehicles[vehicle_id]
		if str(v.get("role", "")) == role and str(v.get("model_id", "")) == model_id:
			return set_active_vehicle(role, str(vehicle_id))
	return false

static func get_owned_for_role(role: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for vehicle_id in vehicles:
		var v: Dictionary = vehicles[vehicle_id].duplicate(true)
		if str(v.get("role", "")) == role:
			result.append(v)
	return result

static func get_speed_multiplier(role: String) -> float:
	var v: Dictionary = get_active_vehicle(role)
	return max(0.1, float(v.get("speed_mult", 1.0)))

static func get_fuel_multiplier(role: String) -> float:
	var v: Dictionary = get_active_vehicle(role)
	return max(0.1, float(v.get("fuel_mult", 1.0)))

static func get_capacity_multiplier(role: String) -> float:
	var v: Dictionary = get_active_vehicle(role)
	return max(0.1, float(v.get("capacity_mult", 1.0)))

static func get_active_condition(role: String) -> float:
	var v: Dictionary = get_active_vehicle(role)
	return clampf(float(v.get("condition", 100.0)), 0.0, 100.0)

static func get_active_reliability(role: String) -> float:
	var v: Dictionary = get_active_vehicle(role)
	return clampf(float(v.get("reliability", 0.85)), 0.05, 1.0)

static func get_active_mileage(role: String) -> float:
	var v: Dictionary = get_active_vehicle(role)
	return max(0.0, float(v.get("mileage_km", 0.0)))

static func add_cycle_usage(role: String, mileage_km: float, condition_loss: float) -> void:
	var vehicle_id: String = str(active_by_role.get(role, ""))
	if vehicle_id == "" or not vehicles.has(vehicle_id):
		return
	var v: Dictionary = vehicles[vehicle_id]
	v["mileage_km"] = max(0.0, float(v.get("mileage_km", 0.0)) + max(0.0, mileage_km))
	var reliability: float = clampf(float(v.get("reliability", 0.85)), 0.05, 1.0)
	var adjusted_loss: float = max(0.0, condition_loss) * (1.15 - reliability * 0.30)
	v["condition"] = max(5.0, float(v.get("condition", 100.0)) - adjusted_loss)
	vehicles[vehicle_id] = v

static func repair_all_owned() -> void:
	for vehicle_id in vehicles:
		var v: Dictionary = vehicles[vehicle_id]
		v["condition"] = 100.0
		vehicles[vehicle_id] = v
	save_to_settings()

static func get_average_active_condition() -> float:
	var total: float = 0.0
	var count: int = 0
	for role in ROLES:
		if not get_active_vehicle(role).is_empty():
			total += get_active_condition(role)
			count += 1
	return 100.0 if count == 0 else total / float(count)

static func get_active_fleet_summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for role in ROLES:
		var v: Dictionary = get_active_vehicle(role)
		if not v.is_empty():
			result.append(v.duplicate(true))
	return result

static func reset_to_defaults() -> void:
	vehicles = {}
	active_by_role = {}
	next_vehicle_id = 1
	_add_vehicle_internal("tractor_basic", 100.0, true)
	_add_vehicle_internal("tanker_basic", 100.0, true)
	_add_vehicle_internal("harvester_basic", 100.0, true)
	_add_vehicle_internal("truck_basic", 100.0, true)
	save_to_settings()

static func _add_vehicle_internal(model_id: String, condition: float, make_active: bool) -> String:
	if not CATALOG.has(model_id):
		return ""
	var data: Dictionary = CATALOG[model_id]
	var role: String = str(data.get("role", ""))
	var vehicle_id: String = "V%06d" % next_vehicle_id
	next_vehicle_id += 1
	vehicles[vehicle_id] = {
		"id": vehicle_id,
		"model_id": model_id,
		"name": str(data.get("name", model_id)),
		"role": role,
		"class": str(data.get("class", "standard")),
		"speed_mult": float(data.get("speed_mult", 1.0)),
		"fuel_mult": float(data.get("fuel_mult", 1.0)),
		"reliability": float(data.get("reliability", 0.85)),
		"capacity_mult": float(data.get("capacity_mult", 1.0)),
		"condition": clampf(condition, 5.0, 100.0),
		"mileage_km": 0.0
	}
	if make_active or not active_by_role.has(role):
		active_by_role[role] = vehicle_id
	return vehicle_id

static func _repair_invalid_active_refs() -> void:
	for role in ROLES:
		var active_id: String = str(active_by_role.get(role, ""))
		if active_id != "" and vehicles.has(active_id):
			continue
		for vehicle_id in vehicles:
			var v: Dictionary = vehicles[vehicle_id]
			if str(v.get("role", "")) == role:
				active_by_role[role] = vehicle_id
				break
