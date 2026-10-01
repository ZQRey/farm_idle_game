class_name ContractManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")

const OFFER_COUNT: int = 3
const MAX_ACTIVE_CONTRACTS: int = 3
const BOARD_REFRESH_SECONDS: int = 1800

const CROP_DATA: Dictionary = {
	"wheat": {"name": "Пшеница", "base_value": 40},
	"corn": {"name": "Кукуруза", "base_value": 95},
	"sunflower": {"name": "Подсолнух", "base_value": 230},
	"carrot": {"name": "Морковь", "base_value": 560}
}

const TIER_ORDER: Array[String] = ["standard", "profitable", "urgent"]
const TIER_DATA: Dictionary = {
	"standard": {
		"title": "Обычный заказ",
		"icon": "📦",
		"target_min": 2,
		"target_max": 3,
		"coin_mult": 1.35,
		"xp_base": 25,
		"rep": 2,
		"ttl": 14400
	},
	"profitable": {
		"title": "Выгодный контракт",
		"icon": "💰",
		"target_min": 3,
		"target_max": 5,
		"coin_mult": 1.70,
		"xp_base": 45,
		"rep": 4,
		"ttl": 7200
	},
	"urgent": {
		"title": "Срочный заказ",
		"icon": "⏱",
		"target_min": 1,
		"target_max": 2,
		"coin_mult": 2.20,
		"xp_base": 60,
		"rep": 5,
		"ttl": 2700
	}
}

static var offers: Array = []
static var active_contracts: Array = []
static var board_refresh_at: int = 0
static var next_contract_id: int = 1
static var total_completed: int = 0
static var total_failed: int = 0
static var total_contract_coins: int = 0
static var initialized: bool = false

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func init_from_settings() -> void:
	_rng.randomize()

	var saved_offers: Variant = SettingsManager.config.get_value("contracts", "offers", [])
	var saved_active: Variant = SettingsManager.config.get_value("contracts", "active", [])
	offers = saved_offers.duplicate(true) if typeof(saved_offers) == TYPE_ARRAY else []
	active_contracts = saved_active.duplicate(true) if typeof(saved_active) == TYPE_ARRAY else []

	board_refresh_at = int(SettingsManager.config.get_value("contracts", "board_refresh_at", 0))
	next_contract_id = max(1, int(SettingsManager.config.get_value("contracts", "next_id", 1)))
	total_completed = max(0, int(SettingsManager.config.get_value("contracts", "total_completed", 0)))
	total_failed = max(0, int(SettingsManager.config.get_value("contracts", "total_failed", 0)))
	total_contract_coins = max(0, int(SettingsManager.config.get_value("contracts", "total_contract_coins", 0)))

	initialized = true
	_expire_active_contracts()
	refresh_board(false)

static func write_to_config() -> void:
	SettingsManager.config.set_value("contracts", "offers", offers)
	SettingsManager.config.set_value("contracts", "active", active_contracts)
	SettingsManager.config.set_value("contracts", "board_refresh_at", board_refresh_at)
	SettingsManager.config.set_value("contracts", "next_id", next_contract_id)
	SettingsManager.config.set_value("contracts", "total_completed", total_completed)
	SettingsManager.config.set_value("contracts", "total_failed", total_failed)
	SettingsManager.config.set_value("contracts", "total_contract_coins", total_contract_coins)

static func save_to_settings() -> void:
	write_to_config()
	SettingsManager.save_settings()

static func refresh_board(force: bool = false) -> bool:
	if not initialized:
		return false
	var now: int = _now()
	_expire_active_contracts()

	if not force and board_refresh_at > now:
		return false

	offers.clear()
	for tier_id in TIER_ORDER:
		offers.append(_generate_contract(tier_id, now))

	board_refresh_at = now + BOARD_REFRESH_SECONDS
	save_to_settings()
	return true

static func accept_contract(contract_id: String) -> bool:
	if not initialized:
		return false
	_expire_active_contracts()
	if active_contracts.size() >= MAX_ACTIVE_CONTRACTS:
		return false

	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		if str(offer.get("id", "")) != contract_id:
			continue

		var accepted: Dictionary = offer.duplicate(true)
		accepted["accepted_at"] = _now()
		accepted["progress"] = 0
		active_contracts.append(accepted)
		offers.remove_at(i)
		save_to_settings()
		return true

	return false

static func record_harvest(crop_id: String) -> Array:
	if not initialized:
		return []
	_expire_active_contracts()
	var completed_rewards: Array = []
	var changed: bool = false

	for i in range(active_contracts.size() - 1, -1, -1):
		var contract: Dictionary = active_contracts[i]
		if str(contract.get("crop_id", "")) != crop_id:
			continue

		var target: int = max(1, int(contract.get("target", 1)))
		var progress: int = min(target, int(contract.get("progress", 0)) + 1)
		contract["progress"] = progress
		active_contracts[i] = contract
		changed = true

		if progress >= target:
			var reward: Dictionary = {
				"id": str(contract.get("id", "")),
				"title": str(contract.get("title", "Контракт")),
				"tier": str(contract.get("tier", "standard")),
				"coins": int(contract.get("reward_coins", 0)),
				"xp": int(contract.get("reward_xp", 0)),
				"reputation": int(contract.get("reward_rep", 0))
			}
			total_completed += 1
			total_contract_coins += int(reward["coins"])
			completed_rewards.append(reward)
			active_contracts.remove_at(i)

	if changed:
		save_to_settings()

	return completed_rewards

static func abandon_contract(contract_id: String) -> bool:
	if not initialized:
		return false
	for i in range(active_contracts.size()):
		var contract: Dictionary = active_contracts[i]
		if str(contract.get("id", "")) == contract_id:
			active_contracts.remove_at(i)
			total_failed += 1
			save_to_settings()
			return true
	return false

static func reset_all_contracts() -> void:
	if not initialized:
		return
	offers.clear()
	active_contracts.clear()
	board_refresh_at = 0
	refresh_board(true)

static func get_board_refresh_seconds_left() -> int:
	return max(0, board_refresh_at - _now())

static func get_seconds_left(contract: Dictionary) -> int:
	return max(0, int(contract.get("expires_at", 0)) - _now())

static func get_tier_label(tier_id: String) -> String:
	var tier: Dictionary = TIER_DATA.get(tier_id, TIER_DATA["standard"])
	return "%s %s" % [str(tier.get("icon", "📦")), str(tier.get("title", "Контракт"))]

static func get_crop_name(crop_id: String) -> String:
	var data: Dictionary = CROP_DATA.get(crop_id, CROP_DATA["wheat"])
	return str(data.get("name", crop_id))

static func get_available_crop_ids() -> Array[String]:
	var result: Array[String] = ["wheat"]
	if ProgressionManager.can_unlock_crop("corn"):
		result.append("corn")
	if ProgressionManager.can_unlock_crop("sunflower"):
		result.append("sunflower")
	if ProgressionManager.can_unlock_crop("carrot"):
		result.append("carrot")
	return result

static func _generate_contract(tier_id: String, now: int) -> Dictionary:
	var tier: Dictionary = TIER_DATA.get(tier_id, TIER_DATA["standard"])
	var crops: Array[String] = get_available_crop_ids()
	var crop_id: String = crops[_rng.randi_range(0, crops.size() - 1)]
	var crop: Dictionary = CROP_DATA.get(crop_id, CROP_DATA["wheat"])

	var target_min: int = int(tier.get("target_min", 1))
	var target_max: int = int(tier.get("target_max", target_min))
	var target: int = _rng.randi_range(target_min, target_max)
	var base_value: int = int(crop.get("base_value", 40))
	var coin_mult: float = float(tier.get("coin_mult", 1.0))

	# Награда контракта дополняет обычную продажу урожая, а не заменяет её.
	var reward_coins: int = max(20, int(float(base_value * target) * coin_mult))
	var reward_xp: int = int(tier.get("xp_base", 20)) + target * 6
	var reward_rep: int = int(tier.get("rep", 1))
	var ttl: int = int(tier.get("ttl", 3600))

	var id: String = "C%06d" % next_contract_id
	next_contract_id += 1

	return {
		"id": id,
		"tier": tier_id,
		"title": get_tier_label(tier_id),
		"crop_id": crop_id,
		"crop_name": str(crop.get("name", crop_id)),
		"target": target,
		"progress": 0,
		"reward_coins": reward_coins,
		"reward_xp": reward_xp,
		"reward_rep": reward_rep,
		"expires_at": now + ttl,
		"created_at": now
	}

static func _expire_active_contracts() -> bool:
	var now: int = _now()
	var changed: bool = false
	for i in range(active_contracts.size() - 1, -1, -1):
		var contract: Dictionary = active_contracts[i]
		if int(contract.get("expires_at", 0)) > 0 and int(contract.get("expires_at", 0)) <= now:
			active_contracts.remove_at(i)
			total_failed += 1
			changed = true

	if changed:
		write_to_config()
		SettingsManager.save_settings()
	return changed

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
