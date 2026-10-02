class_name MarketManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

const CROP_IDS: Array[String] = ["wheat", "corn", "sunflower", "carrot"]
const PRICE_TICK_SECONDS: int = 300
const HISTORY_LIMIT: int = 24
const MIN_MULTIPLIER: float = 0.70
const MAX_MULTIPLIER: float = 1.40
const EVENT_CHANCE_PER_TICK: float = 0.18

const EVENT_CATALOG: Array[Dictionary] = [
	{"id": "local_fair", "title": "🎪 Сельскохозяйственная ярмарка", "scope": "all", "multiplier": 1.15, "duration": 900},
	{"id": "export_order", "title": "🚢 Крупный экспортный заказ", "scope": "crop", "multiplier": 1.35, "duration": 900},
	{"id": "shortage", "title": "📈 Дефицит на рынке", "scope": "crop", "multiplier": 1.30, "duration": 1200},
	{"id": "oversupply", "title": "📉 Переизбыток продукции", "scope": "crop", "multiplier": 0.75, "duration": 900}
]

static var crop_multipliers: Dictionary = {
	"wheat": 1.0,
	"corn": 1.0,
	"sunflower": 1.0,
	"carrot": 1.0
}

static var price_history: Dictionary = {
	"wheat": [],
	"corn": [],
	"sunflower": [],
	"carrot": []
}

static var auto_sell_rules: Dictionary = {
	"wheat": {"enabled": false, "min_price": 0},
	"corn": {"enabled": false, "min_price": 0},
	"sunflower": {"enabled": false, "min_price": 0},
	"carrot": {"enabled": false, "min_price": 0}
}

static var active_event: Dictionary = {}
static var total_auto_sold_kg: float = 0.0
static var total_auto_sale_gross: int = 0
static var last_tick_at: int = 0
static var next_tick_at: int = 0
static var initialized: bool = false

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func init_from_settings() -> void:
	_rng.randomize()

	var saved_multipliers: Variant = SettingsManager.config.get_value("market", "crop_multipliers", {})
	for crop_id in CROP_IDS:
		var loaded_mult: float = 1.0
		if typeof(saved_multipliers) == TYPE_DICTIONARY:
			loaded_mult = float(saved_multipliers.get(crop_id, 1.0))
		crop_multipliers[crop_id] = clampf(loaded_mult, MIN_MULTIPLIER, MAX_MULTIPLIER)

	var saved_history: Variant = SettingsManager.config.get_value("market", "price_history", {})
	price_history = _empty_history()
	if typeof(saved_history) == TYPE_DICTIONARY:
		for crop_id in CROP_IDS:
			var entries: Variant = saved_history.get(crop_id, [])
			if typeof(entries) == TYPE_ARRAY:
				price_history[crop_id] = entries.duplicate(true)
				while price_history[crop_id].size() > HISTORY_LIMIT:
					price_history[crop_id].pop_front()

	var saved_rules: Variant = SettingsManager.config.get_value("market", "auto_sell_rules", {})
	auto_sell_rules = _default_rules()
	if typeof(saved_rules) == TYPE_DICTIONARY:
		for crop_id in CROP_IDS:
			var rule: Variant = saved_rules.get(crop_id, {})
			if typeof(rule) == TYPE_DICTIONARY:
				auto_sell_rules[crop_id] = {
					"enabled": bool(rule.get("enabled", false)),
					"min_price": max(0, int(rule.get("min_price", 0)))
				}

	var saved_event: Variant = SettingsManager.config.get_value("market", "active_event", {})
	active_event = saved_event.duplicate(true) if typeof(saved_event) == TYPE_DICTIONARY else {}
	total_auto_sold_kg = max(0.0, float(SettingsManager.config.get_value("market", "total_auto_sold_kg", 0.0)))
	total_auto_sale_gross = max(0, int(SettingsManager.config.get_value("market", "total_auto_sale_gross", 0)))

	last_tick_at = max(0, int(SettingsManager.config.get_value("market", "last_tick_at", 0)))
	next_tick_at = max(0, int(SettingsManager.config.get_value("market", "next_tick_at", 0)))
	initialized = true

	var now: int = _now()
	if last_tick_at <= 0:
		last_tick_at = now
		next_tick_at = now + PRICE_TICK_SECONDS
		_record_history(now)
	else:
		# Имитируем ограниченное количество пропущенных рыночных шагов после перезапуска.
		var elapsed_ticks: int = int(max(0, now - last_tick_at) / PRICE_TICK_SECONDS)
		var catchup_ticks: int = min(elapsed_ticks, 12)
		for i in range(catchup_ticks):
			_run_price_tick(last_tick_at + PRICE_TICK_SECONDS)
		if next_tick_at <= now:
			next_tick_at = now + PRICE_TICK_SECONDS

	_expire_event_if_needed(now)
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("market", "crop_multipliers", crop_multipliers)
	SettingsManager.config.set_value("market", "price_history", price_history)
	SettingsManager.config.set_value("market", "auto_sell_rules", auto_sell_rules)
	SettingsManager.config.set_value("market", "active_event", active_event)
	SettingsManager.config.set_value("market", "total_auto_sold_kg", total_auto_sold_kg)
	SettingsManager.config.set_value("market", "total_auto_sale_gross", total_auto_sale_gross)
	SettingsManager.config.set_value("market", "last_tick_at", last_tick_at)
	SettingsManager.config.set_value("market", "next_tick_at", next_tick_at)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func update_market(force: bool = false) -> bool:
	if not initialized:
		return false

	var now: int = _now()
	var had_event: bool = not active_event.is_empty()
	_expire_event_if_needed(now)
	var event_expired: bool = had_event and active_event.is_empty()

	if not force and now < next_tick_at:
		if event_expired:
			save_to_settings()
		return event_expired

	_run_price_tick(now)
	save_to_settings()
	return true

static func _run_price_tick(timestamp: int) -> void:
	for crop_id in CROP_IDS:
		var current: float = float(crop_multipliers.get(crop_id, 1.0))
		# Мягкий возврат к базовой цене + небольшой случайный рыночный шум.
		var reverted: float = 1.0 + (current - 1.0) * 0.82
		var shock: float = _rng.randf_range(-0.08, 0.08)
		crop_multipliers[crop_id] = clampf(reverted + shock, MIN_MULTIPLIER, MAX_MULTIPLIER)

	_expire_event_if_needed(timestamp)
	if active_event.is_empty() and _rng.randf() < EVENT_CHANCE_PER_TICK:
		_start_random_event(timestamp)

	last_tick_at = timestamp
	next_tick_at = timestamp + PRICE_TICK_SECONDS
	_record_history(timestamp)

static func get_crop_multiplier(crop_id: String) -> float:
	return clampf(float(crop_multipliers.get(crop_id, 1.0)), MIN_MULTIPLIER, MAX_MULTIPLIER)

static func get_event_multiplier(crop_id: String) -> float:
	if active_event.is_empty():
		return 1.0
	if int(active_event.get("ends_at", 0)) <= _now():
		return 1.0

	var event_crop: String = str(active_event.get("crop_id", "all"))
	if event_crop != "all" and event_crop != crop_id:
		return 1.0
	return max(0.1, float(active_event.get("multiplier", 1.0)))

static func get_effective_multiplier(crop_id: String) -> float:
	if not initialized:
		return 1.0
	return get_crop_multiplier(crop_id) * get_event_multiplier(crop_id)

static func get_seconds_to_next_tick() -> int:
	if not initialized:
		return PRICE_TICK_SECONDS
	return max(0, next_tick_at - _now())

static func get_active_event_text() -> String:
	if active_event.is_empty() or int(active_event.get("ends_at", 0)) <= _now():
		return "Рынок спокоен"
	var crop_id: String = str(active_event.get("crop_id", "all"))
	var target: String = "все культуры" if crop_id == "all" else crop_id
	var percent: int = int(round((float(active_event.get("multiplier", 1.0)) - 1.0) * 100.0))
	var sign_text: String = "+%d%%" % percent if percent >= 0 else "%d%%" % percent
	return "%s — %s %s" % [str(active_event.get("title", "Рыночное событие")), target, sign_text]

static func get_event_seconds_left() -> int:
	if active_event.is_empty():
		return 0
	return max(0, int(active_event.get("ends_at", 0)) - _now())

static func get_history(crop_id: String) -> Array:
	var entries: Variant = price_history.get(crop_id, [])
	return entries.duplicate(true) if typeof(entries) == TYPE_ARRAY else []

static func get_trend(crop_id: String) -> int:
	var history: Array = get_history(crop_id)
	if history.size() < 2:
		return 0
	var prev: float = float(history[history.size() - 2].get("multiplier", 1.0))
	var curr: float = float(history[history.size() - 1].get("multiplier", 1.0))
	if curr > prev + 0.01:
		return 1
	if curr < prev - 0.01:
		return -1
	return 0

static func set_auto_sell_rule(crop_id: String, enabled: bool, min_price: int) -> void:
	if not CROP_IDS.has(crop_id):
		return
	auto_sell_rules[crop_id] = {
		"enabled": enabled,
		"min_price": max(0, min_price)
	}
	save_to_settings()

static func get_auto_sell_rule(crop_id: String) -> Dictionary:
	var rule: Variant = auto_sell_rules.get(crop_id, {"enabled": false, "min_price": 0})
	if typeof(rule) != TYPE_DICTIONARY:
		return {"enabled": false, "min_price": 0}
	return rule.duplicate(true)

static func should_auto_sell(crop_id: String, current_price_per_100kg: int) -> bool:
	if not initialized:
		return false
	var rule: Dictionary = get_auto_sell_rule(crop_id)
	return bool(rule.get("enabled", false)) and current_price_per_100kg >= int(rule.get("min_price", 0))

static func record_current_prices(prices: Dictionary) -> void:
	if not initialized:
		return
	for crop_id in CROP_IDS:
		var entries: Array = price_history.get(crop_id, [])
		if entries.is_empty():
			entries.append({
				"timestamp": _now(),
				"multiplier": get_crop_multiplier(crop_id),
				"effective_multiplier": get_effective_multiplier(crop_id),
				"price": max(0, int(prices.get(crop_id, 0)))
			})
		else:
			var last_entry: Dictionary = entries[entries.size() - 1]
			last_entry["price"] = max(0, int(prices.get(crop_id, 0)))
			last_entry["effective_multiplier"] = get_effective_multiplier(crop_id)
			entries[entries.size() - 1] = last_entry
		price_history[crop_id] = entries
	save_to_settings()

static func register_auto_sale(crop_id: String, amount_kg: float, gross_coins: int) -> void:
	if not initialized or not CROP_IDS.has(crop_id):
		return
	total_auto_sold_kg += max(0.0, amount_kg)
	total_auto_sale_gross += max(0, gross_coins)
	save_to_settings()

static func reset_all() -> void:
	if not initialized:
		return
	crop_multipliers = {
		"wheat": 1.0,
		"corn": 1.0,
		"sunflower": 1.0,
		"carrot": 1.0
	}
	price_history = _empty_history()
	auto_sell_rules = _default_rules()
	active_event = {}
	total_auto_sold_kg = 0.0
	total_auto_sale_gross = 0
	last_tick_at = _now()
	next_tick_at = last_tick_at + PRICE_TICK_SECONDS
	_record_history(last_tick_at)
	save_to_settings()

static func _start_random_event(timestamp: int) -> void:
	if EVENT_CATALOG.is_empty():
		return
	var template: Dictionary = EVENT_CATALOG[_rng.randi_range(0, EVENT_CATALOG.size() - 1)]
	var crop_id: String = "all"
	if str(template.get("scope", "all")) == "crop":
		crop_id = CROP_IDS[_rng.randi_range(0, CROP_IDS.size() - 1)]

	active_event = {
		"id": str(template.get("id", "event")),
		"title": str(template.get("title", "Рыночное событие")),
		"crop_id": crop_id,
		"multiplier": float(template.get("multiplier", 1.0)),
		"started_at": timestamp,
		"ends_at": timestamp + int(template.get("duration", 900))
	}

static func _expire_event_if_needed(timestamp: int) -> void:
	if not active_event.is_empty() and int(active_event.get("ends_at", 0)) <= timestamp:
		active_event = {}

static func _record_history(timestamp: int) -> void:
	for crop_id in CROP_IDS:
		if not price_history.has(crop_id):
			price_history[crop_id] = []
		var entries: Array = price_history[crop_id]
		entries.append({
			"timestamp": timestamp,
			"multiplier": get_crop_multiplier(crop_id),
			"effective_multiplier": get_crop_multiplier(crop_id) * get_event_multiplier(crop_id)
		})
		while entries.size() > HISTORY_LIMIT:
			entries.pop_front()
		price_history[crop_id] = entries

static func _empty_history() -> Dictionary:
	return {
		"wheat": [],
		"corn": [],
		"sunflower": [],
		"carrot": []
	}

static func _default_rules() -> Dictionary:
	return {
		"wheat": {"enabled": false, "min_price": 0},
		"corn": {"enabled": false, "min_price": 0},
		"sunflower": {"enabled": false, "min_price": 0},
		"carrot": {"enabled": false, "min_price": 0}
	}

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
