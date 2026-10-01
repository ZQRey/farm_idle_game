class_name ProgressionManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

const MAX_LEVEL: int = 50

const CROP_LEVELS: Dictionary = {
	"wheat": 1,
	"corn": 3,
	"sunflower": 6,
	"carrot": 10
}

const FEATURE_LEVELS: Dictionary = {
	"scarecrow": 2,
	"canopy": 3,
	"barn": 4,
	"windmill": 5,
	"seeder": 6,
	"guard_dog": 7,
	"heavy_tractor": 8,
	"greenhouse": 9,
	"road_train": 10,
	"super_harvester": 12
}

const HARVEST_XP: Dictionary = {
	"wheat": 18,
	"corn": 28,
	"sunflower": 42,
	"carrot": 60
}

static var farm_level: int = 1
static var xp: int = 0
static var reputation: int = 0
static var lifetime_xp: int = 0

static func init_from_settings() -> void:
	farm_level = int(SettingsManager.config.get_value("progression", "farm_level", 1))
	xp = int(SettingsManager.config.get_value("progression", "xp", 0))
	reputation = int(SettingsManager.config.get_value("progression", "reputation", 0))
	lifetime_xp = int(SettingsManager.config.get_value("progression", "lifetime_xp", 0))
	_normalize_state()

static func write_to_config() -> void:
	SettingsManager.config.set_value("progression", "farm_level", farm_level)
	SettingsManager.config.set_value("progression", "xp", xp)
	SettingsManager.config.set_value("progression", "reputation", reputation)
	SettingsManager.config.set_value("progression", "lifetime_xp", lifetime_xp)

static func save_to_settings() -> void:
	write_to_config()
	SettingsManager.save_settings()

static func _normalize_state() -> void:
	farm_level = clampi(farm_level, 1, MAX_LEVEL)
	xp = max(0, xp)
	reputation = max(0, reputation)
	lifetime_xp = max(0, lifetime_xp)

	if farm_level >= MAX_LEVEL:
		farm_level = MAX_LEVEL
		xp = 0
		return

	while xp >= get_xp_required_for_level(farm_level) and farm_level < MAX_LEVEL:
		xp -= get_xp_required_for_level(farm_level)
		farm_level += 1

	if farm_level >= MAX_LEVEL:
		farm_level = MAX_LEVEL
		xp = 0

static func get_xp_required_for_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return 100 + max(0, level - 1) * 50

static func get_xp_required_for_current_level() -> int:
	return get_xp_required_for_level(farm_level)

static func get_progress_percent() -> float:
	if farm_level >= MAX_LEVEL:
		return 1.0
	var required: int = get_xp_required_for_current_level()
	if required <= 0:
		return 1.0
	return clampf(float(xp) / float(required), 0.0, 1.0)

static func add_xp(amount: int, reputation_gain: int = 0) -> Dictionary:
	var gained: int = max(0, amount)
	var rep_gained: int = max(0, reputation_gain)
	var old_level: int = farm_level

	lifetime_xp += gained
	reputation += rep_gained

	if farm_level < MAX_LEVEL:
		xp += gained
		while farm_level < MAX_LEVEL:
			var required: int = get_xp_required_for_level(farm_level)
			if required <= 0 or xp < required:
				break
			xp -= required
			farm_level += 1

		if farm_level >= MAX_LEVEL:
			farm_level = MAX_LEVEL
			xp = 0

	save_to_settings()
	return {
		"xp_gained": gained,
		"reputation_gained": rep_gained,
		"old_level": old_level,
		"new_level": farm_level,
		"levels_gained": farm_level - old_level,
		"leveled_up": farm_level > old_level
	}

static func add_harvest_progress(crop_id: String) -> Dictionary:
	var gained: int = int(HARVEST_XP.get(crop_id, 18))
	return add_xp(gained, 1)

static func get_crop_required_level(crop_id: String) -> int:
	return int(CROP_LEVELS.get(crop_id, 1))

static func can_unlock_crop(crop_id: String) -> bool:
	return farm_level >= get_crop_required_level(crop_id)

static func get_feature_required_level(feature_id: String) -> int:
	return int(FEATURE_LEVELS.get(feature_id, 1))

static func can_access_feature(feature_id: String) -> bool:
	return farm_level >= get_feature_required_level(feature_id)

static func get_reputation_title() -> String:
	if reputation >= 250:
		return "Легенда аграриев"
	if reputation >= 120:
		return "Хозяин региона"
	if reputation >= 60:
		return "Уважаемый фермер"
	if reputation >= 25:
		return "Надёжный поставщик"
	if reputation >= 10:
		return "Перспективная ферма"
	return "Начинающий фермер"

static func get_next_unlock_text() -> String:
	var candidates: Array[Dictionary] = [
		{"level": 2, "text": "Пугало"},
		{"level": 3, "text": "Кукуруза и навес"},
		{"level": 4, "text": "Большой амбар"},
		{"level": 5, "text": "Ветряная мельница"},
		{"level": 6, "text": "Подсолнух и тракторная сеялка"},
		{"level": 7, "text": "Сторожевой пёс"},
		{"level": 8, "text": "Кировец К-7М"},
		{"level": 9, "text": "Теплицы"},
		{"level": 10, "text": "Морковь и КАМАЗ-автопоезд"},
		{"level": 12, "text": "CLAAS Lexion 8900"}
	]
	for item in candidates:
		var level: int = int(item["level"])
		if level > farm_level:
			return "Ур. %d: %s" % [level, str(item["text"])]
	return "Все базовые открытия получены"
