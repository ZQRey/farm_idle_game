class_name QualityManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const WorkerManager = preload("res://scripts/WorkerManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const VehicleManager = preload("res://scripts/VehicleManager.gd")

const GRADES: Array[String] = ["C", "B", "A", "S"]
const GRADE_ORDER: Dictionary = {"C": 0, "B": 1, "A": 2, "S": 3}
const PRICE_MULTIPLIER: Dictionary = {
	"C": 0.85,
	"B": 1.00,
	"A": 1.18,
	"S": 1.45
}

static var total_by_grade: Dictionary = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
static var last_quality_by_crop: Dictionary = {}
static var best_grade_by_crop: Dictionary = {}
static var initialized: bool = false

static func init_from_settings() -> void:
	var saved_totals: Variant = SettingsManager.config.get_value("quality", "total_by_grade", {})
	total_by_grade = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	if typeof(saved_totals) == TYPE_DICTIONARY:
		for grade in GRADES:
			total_by_grade[grade] = max(0.0, float(saved_totals.get(grade, 0.0)))

	var saved_last: Variant = SettingsManager.config.get_value("quality", "last_quality_by_crop", {})
	last_quality_by_crop = saved_last.duplicate(true) if typeof(saved_last) == TYPE_DICTIONARY else {}

	var saved_best: Variant = SettingsManager.config.get_value("quality", "best_grade_by_crop", {})
	best_grade_by_crop = saved_best.duplicate(true) if typeof(saved_best) == TYPE_DICTIONARY else {}

	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("quality", "total_by_grade", total_by_grade)
	SettingsManager.config.set_value("quality", "last_quality_by_crop", last_quality_by_crop)
	SettingsManager.config.set_value("quality", "best_grade_by_crop", best_grade_by_crop)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func calculate_quality(crop_id: String, weather_id: int) -> Dictionary:
	var score: float = 66.0

	# Погода — основной риск для качества урожая.
	match weather_id:
		0: score += 8.0   # ясно
		1: score += 4.0   # дождь
		2: score -= 18.0  # град
		3: score -= 10.0  # снег
		4: score -= 8.0   # сильный ветер
		5: score += 0.0   # ночь

	# Состояние и надёжность комбайна.
	var condition: float = VehicleManager.get_active_condition(VehicleManager.ROLE_HARVESTER)
	var reliability: float = VehicleManager.get_active_reliability(VehicleManager.ROLE_HARVESTER)
	score += (condition - 70.0) * 0.18
	score += (reliability - 0.80) * 35.0

	# Агрономы и лаборатория помогают стабильно получать высокий класс.
	var agronomist_level: int = WorkerManager.get_total_profession_level(WorkerManager.PROF_AGRONOMIST)
	score += min(12.0, float(agronomist_level) * 1.25)
	score += float(BuildingManager.get_level("agronomy_lab")) * 4.0

	score = clampf(score, 0.0, 100.0)
	var grade: String = grade_from_score(score)
	return {
		"crop_id": crop_id,
		"score": score,
		"grade": grade,
		"price_multiplier": get_price_multiplier(grade)
	}

static func grade_from_score(score: float) -> String:
	if score >= 88.0:
		return "S"
	if score >= 72.0:
		return "A"
	if score >= 55.0:
		return "B"
	return "C"

static func get_price_multiplier(grade: String) -> float:
	return float(PRICE_MULTIPLIER.get(normalize_grade(grade), 1.0))

static func normalize_grade(grade: String) -> String:
	var g: String = grade.to_upper()
	return g if g in GRADES else "B"

static func meets_minimum(grade: String, minimum_grade: String) -> bool:
	return int(GRADE_ORDER.get(normalize_grade(grade), 0)) >= int(GRADE_ORDER.get(normalize_grade(minimum_grade), 0))

static func register_harvest(crop_id: String, grade: String, amount_kg: float) -> void:
	var normalized: String = normalize_grade(grade)
	total_by_grade[normalized] = max(0.0, float(total_by_grade.get(normalized, 0.0)) + max(0.0, amount_kg))
	last_quality_by_crop[crop_id] = normalized

	var previous: String = normalize_grade(str(best_grade_by_crop.get(crop_id, "C")))
	if meets_minimum(normalized, previous):
		best_grade_by_crop[crop_id] = normalized
	save_to_settings()

static func get_last_grade(crop_id: String) -> String:
	return normalize_grade(str(last_quality_by_crop.get(crop_id, "B")))

static func get_best_grade(crop_id: String) -> String:
	return normalize_grade(str(best_grade_by_crop.get(crop_id, "C")))

static func get_total_kg_for_grade(grade: String) -> float:
	return max(0.0, float(total_by_grade.get(normalize_grade(grade), 0.0)))

static func reset_all() -> void:
	total_by_grade = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	last_quality_by_crop = {}
	best_grade_by_crop = {}
	save_to_settings()
