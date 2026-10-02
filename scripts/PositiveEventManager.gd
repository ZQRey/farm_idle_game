class_name PositiveEventManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

const EVENT_DEFS: Dictionary = {
	"community_help": {
		"title": "Соседи пришли помочь",
		"icon": "🤝",
		"rarity": "common",
		"duration": 600,
		"speed_mult": 1.20,
		"description": "+20% к скорости полевых работ"
	},
	"fertile_soil": {
		"title": "Плодородная полоса",
		"icon": "🌱",
		"rarity": "common",
		"duration": 900,
		"yield_mult": 1.20,
		"description": "+20% к урожайности"
	},
	"golden_weather": {
		"title": "Идеальная погода",
		"icon": "☀️",
		"rarity": "uncommon",
		"duration": 720,
		"growth_mult": 1.18,
		"quality_bonus": 8.0,
		"description": "+18% к росту и +8 к качеству"
	},
	"farm_fair": {
		"title": "Фермерская ярмарка",
		"icon": "🎪",
		"rarity": "uncommon",
		"duration": 900,
		"sale_mult": 1.18,
		"description": "+18% к цене продажи"
	},
	"mentor_visit": {
		"title": "Опытный наставник",
		"icon": "🎓",
		"rarity": "rare",
		"duration": 900,
		"worker_xp_mult": 2.0,
		"description": "x2 опыт работников"
	},
	"lucky_season": {
		"title": "Удачный сезон",
		"icon": "✨",
		"rarity": "rare",
		"duration": 1200,
		"yield_mult": 1.15,
		"growth_mult": 1.15,
		"quality_bonus": 10.0,
		"sale_mult": 1.10,
		"description": "Комплексный редкий бонус фермы"
	}
}

static var active_event: Dictionary = {}
static var total_triggered: int = 0
static var rare_triggered: int = 0
static var initialized: bool = false
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func init_from_settings() -> void:
	_rng.randomize()
	var saved: Variant = SettingsManager.config.get_value("positive_events", "active_event", {})
	active_event = saved.duplicate(true) if typeof(saved) == TYPE_DICTIONARY else {}
	total_triggered = max(0, int(SettingsManager.config.get_value("positive_events", "total_triggered", 0)))
	rare_triggered = max(0, int(SettingsManager.config.get_value("positive_events", "rare_triggered", 0)))
	initialized = true
	_expire_if_needed()
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("positive_events", "active_event", active_event)
	SettingsManager.config.set_value("positive_events", "total_triggered", total_triggered)
	SettingsManager.config.set_value("positive_events", "rare_triggered", rare_triggered)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func try_start_random_event() -> Dictionary:
	if not initialized:
		return {}
	_expire_if_needed()
	if not active_event.is_empty():
		return {}

	var event_id: String = _pick_event_id()
	return start_event(event_id)

static func start_event(event_id: String) -> Dictionary:
	if not initialized or not EVENT_DEFS.has(event_id):
		return {}
	_expire_if_needed()
	if not active_event.is_empty():
		return {}

	var def: Dictionary = EVENT_DEFS[event_id]
	var now: int = _now()
	active_event = def.duplicate(true)
	active_event["id"] = event_id
	active_event["started_at"] = now
	active_event["ends_at"] = now + int(def.get("duration", 600))
	total_triggered += 1
	if str(def.get("rarity", "common")) == "rare":
		rare_triggered += 1
	save_to_settings()
	return active_event.duplicate(true)

static func clear_active_event() -> void:
	active_event = {}
	save_to_settings()

static func has_active_event() -> bool:
	_expire_if_needed()
	return not active_event.is_empty()

static func get_active_event() -> Dictionary:
	_expire_if_needed()
	return active_event.duplicate(true)

static func get_active_event_text() -> String:
	_expire_if_needed()
	if active_event.is_empty():
		return "Нет активного позитивного события"
	return "%s %s — %s" % [
		str(active_event.get("icon", "✨")),
		str(active_event.get("title", "Событие")),
		str(active_event.get("description", ""))
	]

static func get_seconds_left() -> int:
	_expire_if_needed()
	if active_event.is_empty():
		return 0
	return max(0, int(active_event.get("ends_at", 0)) - _now())

static func get_speed_multiplier() -> float:
	return float(_get_effect("speed_mult", 1.0))

static func get_growth_multiplier() -> float:
	return float(_get_effect("growth_mult", 1.0))

static func get_yield_multiplier() -> float:
	return float(_get_effect("yield_mult", 1.0))

static func get_sale_multiplier() -> float:
	return float(_get_effect("sale_mult", 1.0))

static func get_worker_xp_multiplier() -> float:
	return float(_get_effect("worker_xp_mult", 1.0))

static func get_quality_bonus() -> float:
	return float(_get_effect("quality_bonus", 0.0))

static func reset_all() -> void:
	active_event = {}
	total_triggered = 0
	rare_triggered = 0
	save_to_settings()

static func _get_effect(key: String, default_value: float) -> float:
	_expire_if_needed()
	if active_event.is_empty():
		return default_value
	return float(active_event.get(key, default_value))

static func _pick_event_id() -> String:
	var roll: float = _rng.randf()
	var pool: Array[String] = []
	if roll < 0.12:
		pool = ["mentor_visit", "lucky_season"]
	elif roll < 0.42:
		pool = ["golden_weather", "farm_fair"]
	else:
		pool = ["community_help", "fertile_soil"]
	return pool[_rng.randi_range(0, pool.size() - 1)]

static func _expire_if_needed() -> void:
	if active_event.is_empty():
		return
	if int(active_event.get("ends_at", 0)) <= _now():
		active_event = {}
		if initialized:
			write_to_config()
			SettingsManager.save_settings()

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
