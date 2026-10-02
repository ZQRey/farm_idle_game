class_name OfflineProgressManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const VehicleManager = preload("res://scripts/VehicleManager.gd")
const WorkerManager = preload("res://scripts/WorkerManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const QualityManager = preload("res://scripts/QualityManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const ContractManager = preload("res://scripts/ContractManager.gd")

const MAX_OFFLINE_SECONDS: int = 8 * 60 * 60
const OFFLINE_EFFICIENCY: float = 0.65
const NOMINAL_CYCLE_SECONDS: float = 18.0 * 60.0
const MIN_OFFLINE_SECONDS: int = 60
const BASE_FUEL_PER_CYCLE: float = 16.0
const OFFLINE_QUALITY_GRADE: String = "B"

static var last_seen_at: int = 0
static var last_report: Dictionary = {}
static var lifetime_offline_seconds: int = 0
static var lifetime_offline_cycles: int = 0
static var initialized: bool = false

static func init_and_apply() -> Dictionary:
	var now: int = _now()
	last_seen_at = max(0, int(SettingsManager.config.get_value("offline", "last_seen_at", 0)))
	lifetime_offline_seconds = max(0, int(SettingsManager.config.get_value("offline", "lifetime_offline_seconds", 0)))
	lifetime_offline_cycles = max(0, int(SettingsManager.config.get_value("offline", "lifetime_offline_cycles", 0)))
	initialized = true

	if last_seen_at <= 0:
		last_seen_at = now
		last_report = _empty_report()
		save_to_settings()
		return last_report.duplicate(true)

	var window: Dictionary = calculate_offline_window(last_seen_at, now)
	last_seen_at = now

	if int(window.get("credited_seconds", 0)) < MIN_OFFLINE_SECONDS:
		last_report = _empty_report()
		save_to_settings()
		return last_report.duplicate(true)

	last_report = _simulate_offline_window(window)
	lifetime_offline_seconds += int(last_report.get("credited_seconds", 0))
	lifetime_offline_cycles += int(last_report.get("cycles_completed", 0))
	save_to_settings()
	return last_report.duplicate(true)

static func calculate_offline_window(previous_timestamp: int, current_timestamp: int) -> Dictionary:
	var raw_seconds: int = max(0, current_timestamp - max(0, previous_timestamp))
	var credited_seconds: int = min(raw_seconds, MAX_OFFLINE_SECONDS)
	var effective_seconds: float = float(credited_seconds) * OFFLINE_EFFICIENCY
	var possible_cycles: int = int(floor(effective_seconds / NOMINAL_CYCLE_SECONDS))
	return {
		"raw_seconds": raw_seconds,
		"credited_seconds": credited_seconds,
		"effective_seconds": effective_seconds,
		"possible_cycles": max(0, possible_cycles),
		"was_capped": raw_seconds > MAX_OFFLINE_SECONDS
	}

static func write_to_config() -> void:
	SettingsManager.config.set_value("offline", "last_seen_at", last_seen_at)
	SettingsManager.config.set_value("offline", "lifetime_offline_seconds", lifetime_offline_seconds)
	SettingsManager.config.set_value("offline", "lifetime_offline_cycles", lifetime_offline_cycles)
	SettingsManager.config.set_value("offline", "last_report", last_report)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func mark_active_now() -> void:
	if not initialized:
		return
	last_seen_at = _now()
	write_to_config()

static func get_last_report() -> Dictionary:
	return last_report.duplicate(true)

static func get_efficiency_percent() -> int:
	return int(round(OFFLINE_EFFICIENCY * 100.0))

static func get_max_offline_hours() -> int:
	return int(MAX_OFFLINE_SECONDS / 3600)

static func _simulate_offline_window(window: Dictionary) -> Dictionary:
	var requested_cycles: int = max(0, int(window.get("possible_cycles", 0)))
	var crop_id: String = GameManager.current_crop
	if not GameManager.CROPS.has(crop_id):
		crop_id = "wheat"

	var report: Dictionary = {
		"raw_seconds": int(window.get("raw_seconds", 0)),
		"credited_seconds": int(window.get("credited_seconds", 0)),
		"effective_seconds": float(window.get("effective_seconds", 0.0)),
		"was_capped": bool(window.get("was_capped", false)),
		"cycles_requested": requested_cycles,
		"cycles_completed": 0,
		"crop_id": crop_id,
		"quality_grade": OFFLINE_QUALITY_GRADE,
		"harvested_kg": 0.0,
		"stored_kg": 0.0,
		"sold_kg": 0.0,
		"gross_coins": 0,
		"net_coins": 0,
		"operating_costs": 0,
		"stopped_for_fuel": false
	}

	for _i in range(requested_cycles):
		var fuel_needed: float = _estimate_fuel_per_cycle()
		if GameManager.fuel_level + 0.001 < fuel_needed and not GameManager.auto_refuel:
			report["stopped_for_fuel"] = true
			break

		if GameManager.fuel_level + 0.001 < fuel_needed and GameManager.auto_refuel:
			var refill_amount: float = GameManager.max_fuel - GameManager.fuel_level
			var refill_cost: int = GameManager.calculate_refuel_cost(refill_amount)
			if refill_amount > 0.0 and GameManager.coins >= refill_cost:
				GameManager.refuel(refill_amount)
			else:
				report["stopped_for_fuel"] = true
				break

		GameManager.consume_fuel(min(fuel_needed, GameManager.fuel_level))

		var harvest_kg: float = InventoryManager.calculate_harvest_kg(GameManager.get_monitor_profit_multiplier(), false)
		harvest_kg *= VehicleManager.get_capacity_multiplier(VehicleManager.ROLE_HARVESTER)
		harvest_kg *= WorkerManager.get_yield_multiplier()
		harvest_kg *= BuildingManager.get_yield_multiplier()

		QualityManager.register_harvest(crop_id, OFFLINE_QUALITY_GRADE, harvest_kg)
		var deposit: Dictionary = InventoryManager.deposit_crop(crop_id, harvest_kg, OFFLINE_QUALITY_GRADE)
		var stored_kg: float = float(deposit.get("stored_kg", 0.0))
		var overflow_kg: float = float(deposit.get("overflow_kg", 0.0))

		var production: Dictionary = GameManager.process_production_costs()
		var cycle_net: int = -int(production.get("total_cost", 0))
		report["operating_costs"] = int(report["operating_costs"]) + int(production.get("total_cost", 0))

		if stored_kg > 0.0 and InventoryManager.auto_sell_on_harvest:
			var sold_breakdown: Dictionary = InventoryManager.remove_crop_with_quality(crop_id, stored_kg)
			var sold_kg: float = float(sold_breakdown.get("total_kg", 0.0))
			var gross: int = GameManager.calculate_quality_breakdown_sale_value(crop_id, sold_breakdown)
			var sale: Dictionary = GameManager.process_sale_finances(gross)
			report["sold_kg"] = float(report["sold_kg"]) + sold_kg
			report["gross_coins"] = int(report["gross_coins"]) + gross
			cycle_net += int(sale.get("net_coins", 0))
		else:
			report["stored_kg"] = float(report["stored_kg"]) + stored_kg

		if overflow_kg > 0.0:
			var overflow_factor: float = 1.0 if InventoryManager.auto_sell_on_harvest else 0.70
			var overflow_gross: int = int(round(float(GameManager.calculate_crop_sale_value(crop_id, overflow_kg, OFFLINE_QUALITY_GRADE)) * overflow_factor))
			var overflow_sale: Dictionary = GameManager.process_sale_finances(overflow_gross)
			report["sold_kg"] = float(report["sold_kg"]) + overflow_kg
			report["gross_coins"] = int(report["gross_coins"]) + overflow_gross
			cycle_net += int(overflow_sale.get("net_coins", 0))

		GameManager.total_harvested += 1
		GameManager.degrade_durability()
		WorkerManager.record_cycle_completion()
		ProgressionManager.add_harvest_progress(crop_id)

		var contract_rewards: Array = ContractManager.record_harvest(crop_id, OFFLINE_QUALITY_GRADE)
		for reward in contract_rewards:
			if reward is Dictionary:
				var reward_coins: int = int(reward.get("coins", 0))
				var reward_xp: int = int(reward.get("xp", 0))
				var reward_rep: int = int(reward.get("reputation", 0))
				if reward_coins > 0:
					GameManager.add_coins(reward_coins)
					cycle_net += reward_coins
				if reward_xp > 0 or reward_rep > 0:
					ProgressionManager.add_xp(reward_xp, reward_rep)

		report["harvested_kg"] = float(report["harvested_kg"]) + harvest_kg
		report["cycles_completed"] = int(report["cycles_completed"]) + 1
		report["net_coins"] = int(report["net_coins"]) + cycle_net

	return report

static func _estimate_fuel_per_cycle() -> float:
	var mult_sum: float = 0.0
	mult_sum += VehicleManager.get_fuel_multiplier(VehicleManager.ROLE_TRACTOR)
	mult_sum += VehicleManager.get_fuel_multiplier(VehicleManager.ROLE_TANKER)
	mult_sum += VehicleManager.get_fuel_multiplier(VehicleManager.ROLE_HARVESTER)
	mult_sum += VehicleManager.get_fuel_multiplier(VehicleManager.ROLE_TRUCK)
	var average_mult: float = mult_sum / 4.0
	return max(4.0, BASE_FUEL_PER_CYCLE * average_mult)

static func _empty_report() -> Dictionary:
	return {
		"raw_seconds": 0,
		"credited_seconds": 0,
		"effective_seconds": 0.0,
		"was_capped": false,
		"cycles_requested": 0,
		"cycles_completed": 0,
		"crop_id": GameManager.current_crop,
		"quality_grade": OFFLINE_QUALITY_GRADE,
		"harvested_kg": 0.0,
		"stored_kg": 0.0,
		"sold_kg": 0.0,
		"gross_coins": 0,
		"net_coins": 0,
		"operating_costs": 0,
		"stopped_for_fuel": false
	}

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
