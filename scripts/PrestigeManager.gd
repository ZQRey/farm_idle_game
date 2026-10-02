class_name PrestigeManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const SpecializationManager = preload("res://scripts/SpecializationManager.gd")
const MultiFieldManager = preload("res://scripts/MultiFieldManager.gd")
const LivestockManager = preload("res://scripts/LivestockManager.gd")
const ProcessingManager = preload("res://scripts/ProcessingManager.gd")

const MAX_PRESTIGE_RANK: int = 10

static var prestige_rank: int = 0
static var total_prestiges: int = 0
static var last_prestige_at: int = 0
static var initialized: bool = false

static func init_from_settings() -> void:
	prestige_rank = clampi(int(SettingsManager.config.get_value("prestige", "rank", 0)), 0, MAX_PRESTIGE_RANK)
	total_prestiges = max(0, int(SettingsManager.config.get_value("prestige", "total_prestiges", prestige_rank)))
	last_prestige_at = max(0, int(SettingsManager.config.get_value("prestige", "last_prestige_at", 0)))
	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("prestige", "rank", prestige_rank)
	SettingsManager.config.set_value("prestige", "total_prestiges", total_prestiges)
	SettingsManager.config.set_value("prestige", "last_prestige_at", last_prestige_at)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func can_prestige() -> bool:
	if not initialized or prestige_rank >= MAX_PRESTIGE_RANK:
		return false
	if ProgressionManager.farm_level < ProgressionManager.MAX_LEVEL:
		return false
	if SpecializationManager.unlocked_tier < SpecializationManager.MAX_TIER:
		return false
	if not MultiFieldManager.is_unlocked("field_2") or not MultiFieldManager.is_unlocked("field_3"):
		return false
	if LivestockManager.coop_level < LivestockManager.MAX_BUILDING_LEVEL:
		return false
	if LivestockManager.barn_level < LivestockManager.MAX_BUILDING_LEVEL:
		return false
	for facility_id in ProcessingManager.FACILITY_ORDER:
		if ProcessingManager.get_facility_level(facility_id) < 2:
			return false
	return true

static func get_missing_requirements() -> Array[String]:
	var missing: Array[String] = []
	if prestige_rank >= MAX_PRESTIGE_RANK:
		missing.append("Достигнут максимальный Prestige %d" % MAX_PRESTIGE_RANK)
	if ProgressionManager.farm_level < ProgressionManager.MAX_LEVEL:
		missing.append("Ферма: уровень %d/%d" % [ProgressionManager.farm_level, ProgressionManager.MAX_LEVEL])
	if SpecializationManager.unlocked_tier < SpecializationManager.MAX_TIER:
		missing.append("Специализация: %d/%d" % [SpecializationManager.unlocked_tier, SpecializationManager.MAX_TIER])
	if not MultiFieldManager.is_unlocked("field_2"):
		missing.append("Открыть Северный участок")
	if not MultiFieldManager.is_unlocked("field_3"):
		missing.append("Открыть Дальний участок")
	if LivestockManager.coop_level < LivestockManager.MAX_BUILDING_LEVEL:
		missing.append("Курятник MAX")
	if LivestockManager.barn_level < LivestockManager.MAX_BUILDING_LEVEL:
		missing.append("Коровник MAX")
	for facility_id in ProcessingManager.FACILITY_ORDER:
		if ProcessingManager.get_facility_level(facility_id) < 2:
			var info: Dictionary = ProcessingManager.FACILITIES[facility_id]
			missing.append("%s минимум ур. 2" % str(info.get("name", facility_id)))
	return missing

static func award_prestige() -> bool:
	if not can_prestige():
		return false
	prestige_rank = min(MAX_PRESTIGE_RANK, prestige_rank + 1)
	total_prestiges += 1
	last_prestige_at = int(Time.get_unix_time_from_system())
	save_to_settings()
	return true

static func get_yield_multiplier() -> float:
	return 1.0 + float(prestige_rank) * 0.03

static func get_sale_multiplier() -> float:
	return 1.0 + float(prestige_rank) * 0.02

static func get_offline_efficiency_bonus() -> float:
	return float(prestige_rank) * 0.01

static func get_starting_coins() -> int:
	return 100 + prestige_rank * 50

static func get_summary() -> String:
	return "Prestige %d/%d | урожай +%d%% | продажа +%d%% | offline +%d%% | старт +%d 🪙" % [
		prestige_rank,
		MAX_PRESTIGE_RANK,
		prestige_rank * 3,
		prestige_rank * 2,
		prestige_rank,
		prestige_rank * 50
	]
