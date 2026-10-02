class_name WorkerManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const PositiveEventManager = preload("res://scripts/PositiveEventManager.gd")

const MAX_WORKERS: int = 8
const MAX_LEVEL: int = 20

const PROF_SOWER: String = "sower"
const PROF_IRRIGATOR: String = "irrigator"
const PROF_HARVESTER: String = "harvester"
const PROF_DRIVER: String = "driver"
const PROF_AGRONOMIST: String = "agronomist"

const PROFESSION_ORDER: Array[String] = [
	PROF_SOWER,
	PROF_IRRIGATOR,
	PROF_HARVESTER,
	PROF_DRIVER,
	PROF_AGRONOMIST
]

const PROFESSION_DATA: Dictionary = {
	"sower": {
		"name": "Сеятель",
		"icon": "🌱",
		"salary": 6,
		"hire_cost": 180,
		"phase": "sowing",
		"bonus_per_level": 0.03,
		"description": "+3% к скорости сева за уровень"
	},
	"irrigator": {
		"name": "Оператор полива",
		"icon": "💧",
		"salary": 5,
		"hire_cost": 200,
		"phase": "watering",
		"bonus_per_level": 0.03,
		"description": "+3% к скорости полива за уровень"
	},
	"harvester": {
		"name": "Комбайнёр",
		"icon": "🌾",
		"salary": 7,
		"hire_cost": 240,
		"phase": "harvesting",
		"bonus_per_level": 0.03,
		"description": "+3% к скорости уборки и +0.5% к урожаю за уровень"
	},
	"driver": {
		"name": "Водитель",
		"icon": "🚚",
		"salary": 6,
		"hire_cost": 210,
		"phase": "hauling",
		"bonus_per_level": 0.03,
		"description": "+3% к скорости вывоза за уровень"
	},
	"agronomist": {
		"name": "Агроном",
		"icon": "🧪",
		"salary": 8,
		"hire_cost": 320,
		"phase": "growing",
		"bonus_per_level": 0.02,
		"description": "+2% к скорости роста и +1% к урожаю за уровень"
	}
}

const NAME_POOL: Array[String] = [
	"Алексей", "Илья", "Сергей", "Михаил", "Антон", "Дмитрий",
	"Олег", "Николай", "Андрей", "Виктор", "Павел", "Роман",
	"Мария", "Анна", "Елена", "Ольга", "Наталья", "Ирина"
]

static var workers: Dictionary = {}
static var next_worker_id: int = 1
static var initialized: bool = false
static var total_hired: int = 0
static var total_levels_gained: int = 0

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func init_from_settings() -> void:
	_rng.randomize()
	var saved_workers: Variant = SettingsManager.config.get_value("workers", "roster", {})
	next_worker_id = max(1, int(SettingsManager.config.get_value("workers", "next_worker_id", 1)))
	total_hired = max(0, int(SettingsManager.config.get_value("workers", "total_hired", 0)))
	total_levels_gained = max(0, int(SettingsManager.config.get_value("workers", "total_levels_gained", 0)))

	if typeof(saved_workers) == TYPE_DICTIONARY and not saved_workers.is_empty():
		workers = saved_workers.duplicate(true)
		_normalize_worker_schema()
	else:
		workers = {}
		_add_worker_internal("Алексей", PROF_SOWER, 1)
		_add_worker_internal("Илья", PROF_IRRIGATOR, 1)
		_add_worker_internal("Сергей", PROF_HARVESTER, 1)
		_add_worker_internal("Михаил", PROF_DRIVER, 1)

	initialized = true
	save_to_settings()

static func write_to_config() -> void:
	SettingsManager.config.set_value("workers", "roster", workers)
	SettingsManager.config.set_value("workers", "next_worker_id", next_worker_id)
	SettingsManager.config.set_value("workers", "total_hired", total_hired)
	SettingsManager.config.set_value("workers", "total_levels_gained", total_levels_gained)

static func save_to_settings() -> void:
	if not initialized:
		return
	write_to_config()
	SettingsManager.save_settings()

static func get_worker_count() -> int:
	return workers.size()

static func get_workers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for worker_id in workers:
		result.append(workers[worker_id].duplicate(true))
	return result

static func get_workers_by_profession(profession: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		if str(worker.get("profession", "")) == profession:
			result.append(worker.duplicate(true))
	return result

static func get_profession_name(profession: String) -> String:
	var data: Dictionary = PROFESSION_DATA.get(profession, {})
	return str(data.get("name", profession))

static func get_hire_cost(profession: String) -> int:
	var data: Dictionary = PROFESSION_DATA.get(profession, {})
	return int(data.get("hire_cost", 0))

static func can_hire(profession: String) -> bool:
	return initialized and PROFESSION_DATA.has(profession) and workers.size() < MAX_WORKERS

static func hire_worker(profession: String) -> Dictionary:
	if not can_hire(profession):
		return {}
	var worker_name: String = _pick_available_name()
	var id: String = _add_worker_internal(worker_name, profession, 1)
	total_hired += 1
	save_to_settings()
	return workers[id].duplicate(true)

static func dismiss_worker(worker_id: String) -> bool:
	if not workers.has(worker_id):
		return false
	# Не позволяем уволить последнего специалиста базовых четырёх профессий.
	var worker: Dictionary = workers[worker_id]
	var profession: String = str(worker.get("profession", ""))
	if profession in [PROF_SOWER, PROF_IRRIGATOR, PROF_HARVESTER, PROF_DRIVER]:
		if get_workers_by_profession(profession).size() <= 1:
			return false
	workers.erase(worker_id)
	save_to_settings()
	return true

static func get_total_salary_per_cycle() -> int:
	var total: int = 0
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		total += int(worker.get("salary", 0))
	return total

static func get_total_profession_level(profession: String) -> int:
	var total: int = 0
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		if str(worker.get("profession", "")) == profession:
			total += clampi(int(worker.get("level", 1)), 1, MAX_LEVEL)
	return total

static func get_phase_speed_multiplier(phase: String) -> float:
	if not initialized:
		return 1.0
	var bonus: float = 0.0
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		var profession: String = str(worker.get("profession", ""))
		var data: Dictionary = PROFESSION_DATA.get(profession, {})
		if str(data.get("phase", "")) != phase:
			continue
		var level: int = clampi(int(worker.get("level", 1)), 1, MAX_LEVEL)
		bonus += float(data.get("bonus_per_level", 0.0)) * float(level)
	return 1.0 + min(bonus, 0.75)

static func get_yield_multiplier() -> float:
	if not initialized:
		return 1.0
	var bonus: float = 0.0
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		var profession: String = str(worker.get("profession", ""))
		var level: int = clampi(int(worker.get("level", 1)), 1, MAX_LEVEL)
		if profession == PROF_HARVESTER:
			bonus += 0.005 * float(level)
		elif profession == PROF_AGRONOMIST:
			bonus += 0.01 * float(level)
	return 1.0 + min(bonus, 0.30)

static func record_cycle_completion() -> Dictionary:
	if not initialized:
		return {"xp_awarded": 0, "level_ups": []}

	var total_xp: int = 0
	var level_ups: Array = []
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		var profession: String = str(worker.get("profession", ""))
		var gained: int = int(round(float(_xp_for_profession(profession)) * PositiveEventManager.get_worker_xp_multiplier()))
		total_xp += gained
		var before_level: int = int(worker.get("level", 1))
		_add_worker_xp(worker_id, gained)
		var after_level: int = int(workers[worker_id].get("level", 1))
		if after_level > before_level:
			level_ups.append({
				"id": worker_id,
				"name": str(workers[worker_id].get("name", "Работник")),
				"level": after_level
			})

	save_to_settings()
	return {"xp_awarded": total_xp, "level_ups": level_ups}

static func get_worker_xp_required(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return 60 + level * 35

static func reset_to_defaults() -> void:
	workers = {}
	next_worker_id = 1
	total_hired = 0
	total_levels_gained = 0
	_add_worker_internal("Алексей", PROF_SOWER, 1)
	_add_worker_internal("Илья", PROF_IRRIGATOR, 1)
	_add_worker_internal("Сергей", PROF_HARVESTER, 1)
	_add_worker_internal("Михаил", PROF_DRIVER, 1)
	save_to_settings()

static func _add_worker_internal(worker_name: String, profession: String, level: int) -> String:
	if not PROFESSION_DATA.has(profession):
		return ""
	var data: Dictionary = PROFESSION_DATA[profession]
	var worker_id: String = "W%06d" % next_worker_id
	next_worker_id += 1
	workers[worker_id] = {
		"id": worker_id,
		"name": worker_name,
		"profession": profession,
		"level": clampi(level, 1, MAX_LEVEL),
		"xp": 0,
		"salary": int(data.get("salary", 5)),
		"cycles_worked": 0
	}
	return worker_id

static func _add_worker_xp(worker_id: String, amount: int) -> void:
	if not workers.has(worker_id):
		return
	var worker: Dictionary = workers[worker_id]
	var level: int = clampi(int(worker.get("level", 1)), 1, MAX_LEVEL)
	var xp: int = max(0, int(worker.get("xp", 0)) + max(0, amount))
	worker["cycles_worked"] = max(0, int(worker.get("cycles_worked", 0)) + 1)

	while level < MAX_LEVEL:
		var required: int = get_worker_xp_required(level)
		if required <= 0 or xp < required:
			break
		xp -= required
		level += 1
		total_levels_gained += 1

	if level >= MAX_LEVEL:
		xp = 0
	worker["level"] = level
	worker["xp"] = xp
	workers[worker_id] = worker

static func _xp_for_profession(profession: String) -> int:
	match profession:
		PROF_SOWER:
			return 14
		PROF_IRRIGATOR:
			return 12
		PROF_HARVESTER:
			return 16
		PROF_DRIVER:
			return 13
		PROF_AGRONOMIST:
			return 15
	return 10

static func _pick_available_name() -> String:
	var used: Dictionary = {}
	for worker_id in workers:
		used[str(workers[worker_id].get("name", ""))] = true
	var candidates: Array[String] = []
	for candidate in NAME_POOL:
		if not used.has(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return "Работник %d" % next_worker_id
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

static func _normalize_worker_schema() -> void:
	for worker_id in workers:
		var worker: Dictionary = workers[worker_id]
		var profession: String = str(worker.get("profession", PROF_SOWER))
		if not PROFESSION_DATA.has(profession):
			profession = PROF_SOWER
		var data: Dictionary = PROFESSION_DATA[profession]
		worker["id"] = str(worker.get("id", worker_id))
		worker["name"] = str(worker.get("name", "Работник"))
		worker["profession"] = profession
		worker["level"] = clampi(int(worker.get("level", 1)), 1, MAX_LEVEL)
		worker["xp"] = max(0, int(worker.get("xp", 0)))
		worker["salary"] = max(0, int(worker.get("salary", data.get("salary", 5))))
		worker["cycles_worked"] = max(0, int(worker.get("cycles_worked", 0)))
		workers[worker_id] = worker
