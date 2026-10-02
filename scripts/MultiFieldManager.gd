class_name MultiFieldManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const QualityManager = preload("res://scripts/QualityManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const ContractManager = preload("res://scripts/ContractManager.gd")
const SpecializationManager = preload("res://scripts/SpecializationManager.gd")
const PrestigeManager = preload("res://scripts/PrestigeManager.gd")

const AUX_FIELD_IDS: Array[String] = ["field_2", "field_3"]
const MAX_LEVEL: int = 3
const BASE_CYCLE_SECONDS: float = 18.0 * 60.0
const FIELD_UNLOCK_COSTS: Dictionary = {"field_2": 1800, "field_3": 3500}
const FIELD_UPGRADE_COSTS: Dictionary = {2: 900, 3: 1800}
const FIELD_REQUIRED_LEVELS: Dictionary = {"field_2": 18, "field_3": 22}
const FIELD_NAMES: Dictionary = {
	"field_2": "Северный участок",
	"field_3": "Дальний участок"
}
const FIELD_QUALITY_GRADE: String = "B"

static var fields: Dictionary = {}
static var last_update_at: int = 0
static var total_aux_cycles: int = 0
static var total_aux_harvest_kg: float = 0.0
static var initialized: bool = false

static func init_from_settings() -> void:
	fields = _default_fields()
	var saved_fields: Variant = SettingsManager.config.get_value("multi_fields", "fields", {})
	if typeof(saved_fields) == TYPE_DICTIONARY:
		for field_id in AUX_FIELD_IDS:
			if saved_fields.has(field_id) and typeof(saved_fields[field_id]) == TYPE_DICTIONARY:
				fields[field_id] = _normalize_field(field_id, saved_fields[field_id])

	last_update_at = max(0, int(SettingsManager.config.get_value("multi_fields", "last_update_at", 0)))
	if last_update_at <= 0:
		last_update_at = _now()
	total_aux_cycles = max(0, int(SettingsManager.config.get_value("multi_fields", "total_aux_cycles", 0)))
	total_aux_harvest_kg = max(0.0, float(SettingsManager.config.get_value("multi_fields", "total_aux_harvest_kg", 0.0)))
	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("multi_fields", "fields", fields)
	SettingsManager.config.set_value("multi_fields", "last_update_at", last_update_at)
	SettingsManager.config.set_value("multi_fields", "total_aux_cycles", total_aux_cycles)
	SettingsManager.config.set_value("multi_fields", "total_aux_harvest_kg", total_aux_harvest_kg)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_field(field_id: String) -> Dictionary:
	return fields.get(field_id, {}).duplicate(true)

static func is_unlocked(field_id: String) -> bool:
	return bool(fields.get(field_id, {}).get("unlocked", false))

static func get_required_level(field_id: String) -> int:
	return int(FIELD_REQUIRED_LEVELS.get(field_id, 1))

static func get_unlock_cost(field_id: String) -> int:
	return int(FIELD_UNLOCK_COSTS.get(field_id, 0))

static func unlock_field(field_id: String) -> bool:
	if not fields.has(field_id) or is_unlocked(field_id):
		return false
	if ProgressionManager.farm_level < get_required_level(field_id):
		return false
	var cost: int = get_unlock_cost(field_id)
	if cost <= 0 or not GameManager.spend_coins(cost):
		return false
	var field: Dictionary = fields[field_id]
	field["unlocked"] = true
	field["level"] = 1
	field["progress_seconds"] = 0.0
	fields[field_id] = field
	save_to_settings()
	return true

static func get_upgrade_cost(field_id: String) -> int:
	if not is_unlocked(field_id):
		return 0
	var level: int = int(fields[field_id].get("level", 1))
	if level >= MAX_LEVEL:
		return 0
	return int(FIELD_UPGRADE_COSTS.get(level + 1, 0))

static func upgrade_field(field_id: String) -> bool:
	var cost: int = get_upgrade_cost(field_id)
	if cost <= 0 or not GameManager.spend_coins(cost):
		return false
	var field: Dictionary = fields[field_id]
	field["level"] = clampi(int(field.get("level", 1)) + 1, 1, MAX_LEVEL)
	fields[field_id] = field
	save_to_settings()
	return true

static func set_crop(field_id: String, crop_id: String) -> bool:
	if not is_unlocked(field_id) or not GameManager.CROPS.has(crop_id):
		return false
	if not ProgressionManager.can_unlock_crop(crop_id):
		return false
	var field: Dictionary = fields[field_id]
	field["crop_id"] = crop_id
	fields[field_id] = field
	save_to_settings()
	return true

static func set_monitor(field_id: String, monitor_index: int) -> bool:
	if not fields.has(field_id):
		return false
	var field: Dictionary = fields[field_id]
	field["monitor_index"] = monitor_index
	fields[field_id] = field
	save_to_settings()
	return true

static func get_cycle_seconds(field_id: String) -> float:
	var level: int = clampi(int(fields.get(field_id, {}).get("level", 1)), 1, MAX_LEVEL)
	var base_seconds: float = BASE_CYCLE_SECONDS
	match level:
		2:
			base_seconds = 15.0 * 60.0
		3:
			base_seconds = 12.0 * 60.0
	return base_seconds * SpecializationManager.get_aux_field_cycle_multiplier()

static func get_yield_multiplier(field_id: String) -> float:
	var level: int = clampi(int(fields.get(field_id, {}).get("level", 1)), 1, MAX_LEVEL)
	match level:
		2:
			return 1.15
		3:
			return 1.30
	return 1.0

static func get_progress_ratio(field_id: String) -> float:
	if not is_unlocked(field_id):
		return 0.0
	var field: Dictionary = fields[field_id]
	var cycle: float = get_cycle_seconds(field_id)
	return clampf(float(field.get("progress_seconds", 0.0)) / max(1.0, cycle), 0.0, 1.0)

static func process_due_time(max_elapsed_seconds: int = 600) -> Dictionary:
	var now: int = _now()
	var elapsed: int = min(max_elapsed_seconds, max(0, now - last_update_at))
	if elapsed <= 0:
		return _empty_report()
	var report: Dictionary = process_elapsed(float(elapsed), 1.0)
	last_update_at = now
	save_to_settings()
	return report

static func process_offline_seconds(credited_seconds: int, efficiency: float) -> Dictionary:
	var report: Dictionary = process_elapsed(float(max(0, credited_seconds)), clampf(efficiency, 0.0, 1.0))
	last_update_at = _now()
	save_to_settings()
	return report

static func process_elapsed(seconds: float, efficiency: float = 1.0) -> Dictionary:
	var effective_seconds: float = max(0.0, seconds) * clampf(efficiency, 0.0, 1.0)
	var report: Dictionary = _empty_report()

	for field_id in AUX_FIELD_IDS:
		if not is_unlocked(field_id):
			continue
		var field: Dictionary = fields[field_id]
		field["progress_seconds"] = max(0.0, float(field.get("progress_seconds", 0.0)) + effective_seconds)
		var cycle_seconds: float = get_cycle_seconds(field_id)

		while float(field.get("progress_seconds", 0.0)) + 0.001 >= cycle_seconds:
			var cycle_result: Dictionary = _complete_cycle(field_id, field)
			if not bool(cycle_result.get("completed", false)):
				report["stopped_fields"].append(field_id)
				break

			field["progress_seconds"] = max(0.0, float(field.get("progress_seconds", 0.0)) - cycle_seconds)
			field["cycles_completed"] = int(field.get("cycles_completed", 0)) + 1
			field["total_harvest_kg"] = float(field.get("total_harvest_kg", 0.0)) + float(cycle_result.get("harvested_kg", 0.0))
			report["cycles_completed"] = int(report["cycles_completed"]) + 1
			report["harvested_kg"] = float(report["harvested_kg"]) + float(cycle_result.get("harvested_kg", 0.0))
			report["net_coins"] = int(report["net_coins"]) + int(cycle_result.get("net_coins", 0))
			total_aux_cycles += 1
			total_aux_harvest_kg += float(cycle_result.get("harvested_kg", 0.0))

		fields[field_id] = field

	save_to_settings()
	return report

static func reset_all() -> void:
	fields = _default_fields()
	last_update_at = _now()
	total_aux_cycles = 0
	total_aux_harvest_kg = 0.0
	save_to_settings()

static func _complete_cycle(field_id: String, field: Dictionary) -> Dictionary:
	var crop_id: String = str(field.get("crop_id", "wheat"))
	if not GameManager.CROPS.has(crop_id):
		crop_id = "wheat"
	var crop: Dictionary = GameManager.CROPS[crop_id]
	var level: int = clampi(int(field.get("level", 1)), 1, MAX_LEVEL)
	var operating_cost: int = int(crop.get("seed_cost", 10)) + level * 8
	if GameManager.coins < operating_cost or not GameManager.spend_coins(operating_cost):
		return {"completed": false}

	var harvest_kg: float = InventoryManager.calculate_harvest_kg(1.0, false)
	harvest_kg *= get_yield_multiplier(field_id)
	harvest_kg *= BuildingManager.get_yield_multiplier()
	harvest_kg *= SpecializationManager.get_crop_yield_multiplier()
	harvest_kg *= PrestigeManager.get_yield_multiplier()
	QualityManager.register_harvest(crop_id, FIELD_QUALITY_GRADE, harvest_kg)

	var deposit: Dictionary = InventoryManager.deposit_crop(crop_id, harvest_kg, FIELD_QUALITY_GRADE)
	var stored_kg: float = float(deposit.get("stored_kg", 0.0))
	var overflow_kg: float = float(deposit.get("overflow_kg", 0.0))
	var net_coins: int = -operating_cost

	if stored_kg > 0.0 and InventoryManager.auto_sell_on_harvest:
		var sold: Dictionary = InventoryManager.remove_crop_with_quality(crop_id, stored_kg)
		var gross: int = GameManager.calculate_quality_breakdown_sale_value(crop_id, sold, false)
		var sale: Dictionary = GameManager.process_sale_finances(gross)
		net_coins += int(sale.get("net_coins", 0))

	if overflow_kg > 0.0:
		var overflow_factor: float = 1.0 if InventoryManager.auto_sell_on_harvest else 0.70
		var overflow_gross: int = int(round(
			float(GameManager.calculate_crop_sale_value(crop_id, overflow_kg, FIELD_QUALITY_GRADE, false)) * overflow_factor
		))
		var overflow_sale: Dictionary = GameManager.process_sale_finances(overflow_gross)
		net_coins += int(overflow_sale.get("net_coins", 0))

	GameManager.total_harvested += 1
	ProgressionManager.add_harvest_progress(crop_id)
	var contract_rewards: Array = ContractManager.record_harvest(crop_id, FIELD_QUALITY_GRADE)
	for reward in contract_rewards:
		if reward is Dictionary:
			var coins: int = int(reward.get("coins", 0))
			var xp: int = int(reward.get("xp", 0))
			var rep: int = int(reward.get("reputation", 0))
			if coins > 0:
				GameManager.add_coins(coins)
				net_coins += coins
			if xp > 0 or rep > 0:
				ProgressionManager.add_xp(xp, rep)

	return {
		"completed": true,
		"harvested_kg": harvest_kg,
		"net_coins": net_coins
	}

static func _default_fields() -> Dictionary:
	return {
		"field_2": {
			"id": "field_2",
			"name": str(FIELD_NAMES["field_2"]),
			"unlocked": false,
			"level": 1,
			"crop_id": "wheat",
			"monitor_index": 1,
			"progress_seconds": 0.0,
			"cycles_completed": 0,
			"total_harvest_kg": 0.0
		},
		"field_3": {
			"id": "field_3",
			"name": str(FIELD_NAMES["field_3"]),
			"unlocked": false,
			"level": 1,
			"crop_id": "wheat",
			"monitor_index": 2,
			"progress_seconds": 0.0,
			"cycles_completed": 0,
			"total_harvest_kg": 0.0
		}
	}

static func _normalize_field(field_id: String, raw: Dictionary) -> Dictionary:
	var base: Dictionary = _default_fields()[field_id]
	var crop_id: String = str(raw.get("crop_id", "wheat"))
	if not GameManager.CROPS.has(crop_id):
		crop_id = "wheat"
	base["unlocked"] = bool(raw.get("unlocked", false))
	base["level"] = clampi(int(raw.get("level", 1)), 1, MAX_LEVEL)
	base["crop_id"] = crop_id
	base["monitor_index"] = int(raw.get("monitor_index", base["monitor_index"]))
	base["progress_seconds"] = max(0.0, float(raw.get("progress_seconds", 0.0)))
	base["cycles_completed"] = max(0, int(raw.get("cycles_completed", 0)))
	base["total_harvest_kg"] = max(0.0, float(raw.get("total_harvest_kg", 0.0)))
	return base

static func _empty_report() -> Dictionary:
	return {
		"cycles_completed": 0,
		"harvested_kg": 0.0,
		"net_coins": 0,
		"stopped_fields": []
	}

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
