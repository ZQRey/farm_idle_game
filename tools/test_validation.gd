@tool
extends SceneTree

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const WindowManager = preload("res://scripts/WindowManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const ContractManager = preload("res://scripts/ContractManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const MarketManager = preload("res://scripts/MarketManager.gd")
const VehicleManager = preload("res://scripts/VehicleManager.gd")
const WorkerManager = preload("res://scripts/WorkerManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const QualityManager = preload("res://scripts/QualityManager.gd")
const PositiveEventManager = preload("res://scripts/PositiveEventManager.gd")
const AchievementManager = preload("res://scripts/AchievementManager.gd")
const OfflineProgressManager = preload("res://scripts/OfflineProgressManager.gd")
const LivestockManager = preload("res://scripts/LivestockManager.gd")
const ProcessingManager = preload("res://scripts/ProcessingManager.gd")
const MultiFieldManager = preload("res://scripts/MultiFieldManager.gd")
const SpecializationManager = preload("res://scripts/SpecializationManager.gd")
const PrestigeManager = preload("res://scripts/PrestigeManager.gd")
const FieldFSM = preload("res://scripts/FieldFSM.gd")
const EventManager = preload("res://scripts/EventManager.gd")

func _init() -> void:
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ НОВЫХ ФУНКЦИЙ ---")
	SettingsManager.load_settings()
	GameManager.init_from_settings()
	ContractManager.init_from_settings()
	InventoryManager.init_from_settings()
	MarketManager.init_from_settings()

	# 1. Тест: Множитель прибыли от мониторов
	print("\n[ТЕСТ 1] Проверка множителя прибыли от мониторов:")
	SettingsManager.set_screen_index(0)
	var mult_single: float = GameManager.get_monitor_profit_multiplier()
	print("  - Один монитор (индекс 0): множитель = ", mult_single)
	assert(mult_single == 1.0, "Одиночный монитор должен давать множитель 1.0")

	SettingsManager.set_screen_index(WindowManager.SCREEN_ALL_MONITORS)
	var mult_all: float = GameManager.get_monitor_profit_multiplier()
	var screen_count: int = max(1, DisplayServer.get_screen_count())
	print("  - Все мониторы (индекс -1, найдено экранов %d): множитель = %f" % [screen_count, mult_all])
	assert(mult_all == float(screen_count), "Множитель для всех мониторов должен равняться количеству экранов")
	print("  ✔ ТЕСТ 1 УСПЕШНО ПРОЙДЕН!")

	# 2. Тест: Сохранение и восстановление состояния поля
	print("\n[ТЕСТ 2] Проверка сохранения и восстановления состояния поля (FieldFSM):")
	var field: FieldFSM = FieldFSM.new()
	field.set_process(false)
	root.add_child(field)
	
	# Задаем тестовое состояние поля
	field.current_state = FieldFSM.State.HARVESTING
	field.state_timer = 12.5
	field.vehicle_x = 520.0
	field.truck_fill_stage = 2
	field.greenhouse_timer = 15.0
	field._update_screen_bounds()
	field.soil_segments.fill(2)
	field.crop_stages.fill(3)

	# Сохраняем состояние поля
	field.save_field_state()
	print("  - Состояние поля сохранено: state=HARVESTING, x=520, timer=12.5")

	# Намеренно сбиваем значения
	field.current_state = FieldFSM.State.PLOWING
	field.vehicle_x = -50.0
	field.state_timer = 0.0
	field.truck_fill_stage = 0
	field.soil_segments.fill(0)
	field.crop_stages.fill(-1)

	# Восстанавливаем состояние
	var restored_field: bool = field.restore_field_state()
	assert(restored_field, "restore_field_state должно вернуть true")
	assert(field.current_state == FieldFSM.State.HARVESTING, "Состояние должно восстановиться до HARVESTING")
	assert(is_equal_approx(field.vehicle_x, 520.0), "vehicle_x должно равняться 520.0")
	assert(is_equal_approx(field.state_timer, 12.5), "state_timer должно равняться 12.5")
	assert(field.truck_fill_stage == 2, "truck_fill_stage должно равняться 2")
	print("DEBUG: field.soil_segments[0] = ", field.soil_segments[0], " saved_soil from cfg = ", SettingsManager.config.get_value("field_state", "soil_segments", []))
	assert(field.soil_segments[0] == 2, "soil_segments должны быть восстановлены")
	assert(field.crop_stages[0] == 3, "crop_stages должны быть восстановлены")
	print("  ✔ ТЕСТ 2 УСПЕШНО ПРОЙДЕН!")

	# 3. Тест: Сохранение и восстановление состояния событий (EventManager)
	print("\n[ТЕСТ 3] Проверка сохранения и восстановления состояния событий (EventManager):")
	var event_mgr: EventManager = EventManager.new()
	event_mgr.field_fsm = field
	root.add_child(event_mgr)

	event_mgr.current_weather = EventManager.Weather.RAIN
	event_mgr.weather_timer = 18.0
	event_mgr.season_timer = 45.0
	event_mgr.is_strike_active = true
	event_mgr.strike_timer = 10.0
	event_mgr.is_breakdown_active = true
	event_mgr.is_repairing = true
	event_mgr.repair_timer = 2.5

	# Сохраняем события
	event_mgr.save_event_state()
	print("  - Состояние событий сохранено: weather=RAIN, strike=true, breakdown=true, repairing=true")

	# Намеренно сбиваем
	event_mgr.current_weather = EventManager.Weather.CLEAR
	event_mgr.weather_timer = 0.0
	event_mgr.season_timer = 0.0
	event_mgr.is_strike_active = false
	event_mgr.strike_timer = 0.0
	event_mgr.is_breakdown_active = false
	event_mgr.is_repairing = false
	event_mgr.repair_timer = 0.0

	# Восстанавливаем
	var restored_events: bool = event_mgr.restore_event_state()
	assert(restored_events, "restore_event_state должно вернуть true")
	assert(event_mgr.current_weather == EventManager.Weather.RAIN, "Погода должна восстановиться до RAIN")
	assert(is_equal_approx(event_mgr.weather_timer, 18.0), "weather_timer должно равняться 18.0")
	assert(is_equal_approx(event_mgr.season_timer, 45.0), "season_timer должно равняться 45.0")
	assert(event_mgr.is_strike_active == true, "Забастовка должна быть активна")
	assert(event_mgr.is_breakdown_active == true, "Поломка должна быть активна")
	assert(event_mgr.is_repairing == true, "Ремонт должен быть активен")
	print("  ✔ ТЕСТ 3 УСПЕШНО ПРОЙДЕН!")

	# 4. Тест: Сохранение и восстановление сезона в GameManager
	print("\n[ТЕСТ 4] Проверка сохранения и восстановления сезона (GameManager):")
	GameManager.current_season = GameManager.Season.WINTER
	GameManager.save_to_settings()
	GameManager.current_season = GameManager.Season.SPRING
	GameManager.init_from_settings()
	assert(GameManager.current_season == GameManager.Season.WINTER, "Сезон должен восстановиться до WINTER")
	print("  ✔ ТЕСТ 4 УСПЕШНО ПРОЙДЕН!")

	# 5. Тест: Проверка конфигурации project.godot
	print("\n[ТЕСТ 5] Проверка настроек фонового окна в project.godot:")
	var f: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	assert(content.contains("window/size/always_on_top=false"), "В project.godot должно быть window/size/always_on_top=false")
	print("  ✔ ТЕСТ 5 УСПЕШНО ПРОЙДЕН!")

	# 6. Тест: Уровни фермы, XP, репутация и сохранение прогрессии
	print("\n[ТЕСТ 6] Проверка долгосрочной прогрессии фермы:")
	var old_level: int = ProgressionManager.farm_level
	var old_xp: int = ProgressionManager.xp
	var old_rep: int = ProgressionManager.reputation
	var old_lifetime_xp: int = ProgressionManager.lifetime_xp

	ProgressionManager.farm_level = 1
	ProgressionManager.xp = 0
	ProgressionManager.reputation = 0
	ProgressionManager.lifetime_xp = 0
	var progress_result: Dictionary = ProgressionManager.add_xp(180, 3)

	assert(ProgressionManager.farm_level == 2, "180 XP с первого уровня должны повысить ферму до уровня 2")
	assert(ProgressionManager.xp == 80, "После повышения уровня должно остаться 80 XP")
	assert(ProgressionManager.reputation == 3, "Репутация должна увеличиться на 3")
	assert(bool(progress_result.get("leveled_up", false)), "Результат должен сообщить о повышении уровня")
	assert(not ProgressionManager.can_unlock_crop("corn"), "Кукуруза должна требовать уровень 3")

	ProgressionManager.farm_level = 3
	assert(ProgressionManager.can_unlock_crop("corn"), "Кукуруза должна открываться на уровне 3")
	ProgressionManager.save_to_settings()

	ProgressionManager.farm_level = 1
	ProgressionManager.xp = 0
	ProgressionManager.reputation = 0
	ProgressionManager.init_from_settings()
	assert(ProgressionManager.farm_level == 3, "Уровень фермы должен восстанавливаться из сохранения")
	assert(ProgressionManager.xp == 80, "XP должен восстанавливаться из сохранения")
	assert(ProgressionManager.reputation == 3, "Репутация должна восстанавливаться из сохранения")

	# Возвращаем исходный прогресс пользователя после теста.
	ProgressionManager.farm_level = old_level
	ProgressionManager.xp = old_xp
	ProgressionManager.reputation = old_rep
	ProgressionManager.lifetime_xp = old_lifetime_xp
	ProgressionManager.save_to_settings()
	print("  ✔ ТЕСТ 6 УСПЕШНО ПРОЙДЕН!")

	# 7. Тест: принятие, прогресс, сохранение и завершение контракта
	print("\n[ТЕСТ 7] Проверка системы контрактов:")
	var old_offers: Array = ContractManager.offers.duplicate(true)
	var old_active: Array = ContractManager.active_contracts.duplicate(true)
	var old_refresh_at: int = ContractManager.board_refresh_at
	var old_next_id: int = ContractManager.next_contract_id
	var old_completed: int = ContractManager.total_completed
	var old_failed: int = ContractManager.total_failed
	var old_contract_coins: int = ContractManager.total_contract_coins

	var now: int = int(Time.get_unix_time_from_system())
	ContractManager.offers = [{
		"id": "TEST001",
		"tier": "standard",
		"title": "📦 Тестовый заказ",
		"crop_id": "wheat",
		"crop_name": "Пшеница",
		"target": 2,
		"progress": 0,
		"reward_coins": 120,
		"reward_xp": 30,
		"reward_rep": 2,
		"expires_at": now + 3600,
		"created_at": now
	}]
	ContractManager.active_contracts = []
	ContractManager.board_refresh_at = now + 1800

	assert(ContractManager.accept_contract("TEST001"), "Тестовый контракт должен приниматься")
	assert(ContractManager.active_contracts.size() == 1, "После принятия должен быть один активный контракт")

	var first_rewards: Array = ContractManager.record_harvest("wheat")
	assert(first_rewards.is_empty(), "После первого из двух урожаев контракт ещё не должен завершаться")
	assert(int(ContractManager.active_contracts[0].get("progress", 0)) == 1, "Прогресс контракта должен стать 1/2")

	ContractManager.save_to_settings()
	ContractManager.offers = []
	ContractManager.active_contracts = []
	ContractManager.init_from_settings()
	assert(ContractManager.active_contracts.size() == 1, "Активный контракт должен восстановиться после загрузки")
	assert(int(ContractManager.active_contracts[0].get("progress", 0)) == 1, "Прогресс 1/2 должен восстановиться")

	var second_rewards: Array = ContractManager.record_harvest("wheat")
	assert(second_rewards.size() == 1, "Второй урожай должен завершить контракт")
	assert(int(second_rewards[0].get("coins", 0)) == 120, "Награда тестового контракта должна быть 120 монет")
	assert(ContractManager.active_contracts.is_empty(), "Выполненный контракт должен удаляться из активных")
	print("  ✔ ТЕСТ 7 УСПЕШНО ПРОЙДЕН!")

	# Возвращаем контрактное состояние пользователя.
	ContractManager.offers = old_offers
	ContractManager.active_contracts = old_active
	ContractManager.board_refresh_at = old_refresh_at
	ContractManager.next_contract_id = old_next_id
	ContractManager.total_completed = old_completed
	ContractManager.total_failed = old_failed
	ContractManager.total_contract_coins = old_contract_coins
	ContractManager.save_to_settings()

	# 8. Тест: склад, переполнение и persistence
	print("\n[ТЕСТ 8] Проверка склада урожая:")
	var old_stock: Dictionary = InventoryManager.stock.duplicate(true)
	var old_quality_stock: Dictionary = InventoryManager.quality_stock.duplicate(true)
	var old_storage_level: int = InventoryManager.storage_level
	var old_auto_sell: bool = InventoryManager.auto_sell_on_harvest
	var old_total_stored: float = InventoryManager.total_harvest_stored_kg
	var old_total_overflow: float = InventoryManager.total_overflow_kg

	InventoryManager.stock = {
		"wheat": 0.0,
		"corn": 0.0,
		"sunflower": 0.0,
		"carrot": 0.0
	}
	InventoryManager.quality_stock = {
		"wheat": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"corn": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"sunflower": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"carrot": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	}
	InventoryManager.storage_level = 1
	InventoryManager.auto_sell_on_harvest = false
	InventoryManager.total_harvest_stored_kg = 0.0
	InventoryManager.total_overflow_kg = 0.0

	var deposit_a: Dictionary = InventoryManager.deposit_crop("wheat", 400.0, "A")
	assert(is_equal_approx(float(deposit_a.get("stored_kg", 0.0)), 400.0), "400 кг пшеницы должны полностью поместиться")
	assert(is_equal_approx(InventoryManager.get_stock_by_quality("wheat", "A"), 400.0), "Пшеница должна храниться как класс A")
	assert(is_equal_approx(InventoryManager.get_total_stock(), 400.0), "На складе должно быть 400 кг")

	var deposit_b: Dictionary = InventoryManager.deposit_crop("corn", 200.0)
	assert(is_equal_approx(float(deposit_b.get("stored_kg", 0.0)), 100.0), "При ёмкости 500 кг должно сохраниться только 100 кг кукурузы")
	assert(is_equal_approx(float(deposit_b.get("overflow_kg", 0.0)), 100.0), "Оставшиеся 100 кг должны считаться переполнением")
	assert(is_equal_approx(InventoryManager.get_total_stock(), 500.0), "Склад должен быть заполнен ровно до 500 кг")

	var removed_kg: float = InventoryManager.remove_crop("wheat", 100.0)
	assert(is_equal_approx(removed_kg, 100.0), "Должно продаваться/изыматься 100 кг")
	assert(is_equal_approx(InventoryManager.get_stock("wheat"), 300.0), "После изъятия должно остаться 300 кг пшеницы")
	assert(is_equal_approx(InventoryManager.get_free_capacity(), 100.0), "После изъятия должно освободиться 100 кг ёмкости")

	InventoryManager.save_to_settings()
	InventoryManager.stock = {}
	InventoryManager.storage_level = 4
	InventoryManager.init_from_settings()
	assert(InventoryManager.storage_level == 1, "Уровень склада должен восстановиться до 1")
	assert(is_equal_approx(InventoryManager.get_stock("wheat"), 300.0), "Запас пшеницы должен восстановиться")
	assert(is_equal_approx(InventoryManager.get_stock("corn"), 100.0), "Запас кукурузы должен восстановиться")
	print("  ✔ ТЕСТ 8 УСПЕШНО ПРОЙДЕН!")

	# Возвращаем складское состояние пользователя.
	InventoryManager.stock = old_stock
	InventoryManager.quality_stock = old_quality_stock
	InventoryManager.storage_level = old_storage_level
	InventoryManager.auto_sell_on_harvest = old_auto_sell
	InventoryManager.total_harvest_stored_kg = old_total_stored
	InventoryManager.total_overflow_kg = old_total_overflow
	InventoryManager.save_to_settings()

	# 9. Тест: динамический рынок, история и правила автопродажи
	print("\n[ТЕСТ 9] Проверка динамического рынка:")
	var old_market_multipliers: Dictionary = MarketManager.crop_multipliers.duplicate(true)
	var old_market_history: Dictionary = MarketManager.price_history.duplicate(true)
	var old_market_rules: Dictionary = MarketManager.auto_sell_rules.duplicate(true)
	var old_market_event: Dictionary = MarketManager.active_event.duplicate(true)
	var old_auto_sold_kg: float = MarketManager.total_auto_sold_kg
	var old_auto_sale_gross: int = MarketManager.total_auto_sale_gross
	var old_last_tick: int = MarketManager.last_tick_at
	var old_next_tick: int = MarketManager.next_tick_at

	MarketManager.crop_multipliers = {
		"wheat": 1.25,
		"corn": 0.90,
		"sunflower": 1.10,
		"carrot": 1.00
	}
	MarketManager.active_event = {}
	MarketManager.price_history = {
		"wheat": [],
		"corn": [],
		"sunflower": [],
		"carrot": []
	}
	MarketManager.set_auto_sell_rule("wheat", true, 55)
	assert(is_equal_approx(MarketManager.get_effective_multiplier("wheat"), 1.25), "Пшеница должна иметь рыночный коэффициент 1.25")
	assert(MarketManager.should_auto_sell("wheat", 55), "Автопродажа должна сработать при достижении порога")
	assert(not MarketManager.should_auto_sell("wheat", 54), "Автопродажа не должна сработать ниже порога")

	MarketManager.record_current_prices({
		"wheat": 60,
		"corn": 90,
		"sunflower": 250,
		"carrot": 560
	})
	assert(MarketManager.get_history("wheat").size() == 1, "История рынка должна получить точку цены")
	assert(int(MarketManager.get_history("wheat")[0].get("price", 0)) == 60, "В истории должна сохраниться цена 60")

	MarketManager.save_to_settings()
	MarketManager.crop_multipliers["wheat"] = 0.70
	MarketManager.auto_sell_rules["wheat"] = {"enabled": false, "min_price": 1}
	MarketManager.init_from_settings()
	assert(is_equal_approx(MarketManager.get_crop_multiplier("wheat"), 1.25), "Рыночный коэффициент должен восстановиться")
	var restored_rule: Dictionary = MarketManager.get_auto_sell_rule("wheat")
	assert(bool(restored_rule.get("enabled", false)), "Правило автопродажи должно восстановиться")
	assert(int(restored_rule.get("min_price", 0)) == 55, "Порог автопродажи должен восстановиться")
	print("  ✔ ТЕСТ 9 УСПЕШНО ПРОЙДЕН!")

	# Возвращаем рыночное состояние пользователя.
	MarketManager.crop_multipliers = old_market_multipliers
	MarketManager.price_history = old_market_history
	MarketManager.auto_sell_rules = old_market_rules
	MarketManager.active_event = old_market_event
	MarketManager.total_auto_sold_kg = old_auto_sold_kg
	MarketManager.total_auto_sale_gross = old_auto_sale_gross
	MarketManager.last_tick_at = old_last_tick
	MarketManager.next_tick_at = old_next_tick
	MarketManager.save_to_settings()

	# 10. Тест: Garage 2.0 — экземпляры, выбор активной техники, пробег и persistence
	print("\n[ТЕСТ 10] Проверка Garage 2.0:")
	var old_vehicles: Dictionary = VehicleManager.vehicles.duplicate(true)
	var old_active_fleet: Dictionary = VehicleManager.active_by_role.duplicate(true)
	var old_next_vehicle_id: int = VehicleManager.next_vehicle_id

	VehicleManager.vehicles = {}
	VehicleManager.active_by_role = {}
	VehicleManager.next_vehicle_id = 1
	VehicleManager.initialized = true
	VehicleManager.reset_to_defaults()

	assert(VehicleManager.vehicles.size() == 4, "Стартовый гараж должен содержать 4 машины")
	assert(VehicleManager.get_active_model_id(VehicleManager.ROLE_TRACTOR) == "tractor_basic", "Стартовый активный трактор должен быть МТЗ-82")
	assert(not VehicleManager.owns_model("tractor_heavy"), "Кировец не должен принадлежать новому гаражу")

	assert(VehicleManager.purchase_model("tractor_heavy"), "Кировец должен добавляться как отдельный экземпляр")
	assert(VehicleManager.owns_model("tractor_heavy"), "После покупки Кировец должен находиться в гараже")
	assert(VehicleManager.get_active_model_id(VehicleManager.ROLE_TRACTOR) == "tractor_heavy", "Новая улучшенная модель должна становиться активной")

	assert(VehicleManager.set_active_model(VehicleManager.ROLE_TRACTOR, "tractor_basic"), "Должна быть возможность вернуть МТЗ активным")
	assert(is_equal_approx(VehicleManager.get_speed_multiplier(VehicleManager.ROLE_TRACTOR), 1.0), "МТЗ должен иметь скорость x1.0")

	VehicleManager.set_active_model(VehicleManager.ROLE_TRACTOR, "tractor_heavy")
	var before_mileage: float = VehicleManager.get_active_mileage(VehicleManager.ROLE_TRACTOR)
	var before_condition: float = VehicleManager.get_active_condition(VehicleManager.ROLE_TRACTOR)
	VehicleManager.add_cycle_usage(VehicleManager.ROLE_TRACTOR, 4.0, 2.5)
	assert(VehicleManager.get_active_mileage(VehicleManager.ROLE_TRACTOR) > before_mileage, "Пробег активной машины должен расти")
	assert(VehicleManager.get_active_condition(VehicleManager.ROLE_TRACTOR) < before_condition, "Состояние активной машины должно ухудшаться")

	VehicleManager.save_to_settings()
	VehicleManager.vehicles = {}
	VehicleManager.active_by_role = {}
	VehicleManager.init_from_settings()
	assert(VehicleManager.owns_model("tractor_heavy"), "Кировец должен восстановиться после загрузки")
	assert(VehicleManager.get_active_model_id(VehicleManager.ROLE_TRACTOR) == "tractor_heavy", "Активная модель должна восстановиться")
	assert(VehicleManager.get_active_mileage(VehicleManager.ROLE_TRACTOR) >= 4.0, "Пробег должен сохраняться")
	print("  ✔ ТЕСТ 10 УСПЕШНО ПРОЙДЕН!")

	# 11. Тест: тюнинг конкретного экземпляра техники
	print("\n[ТЕСТ 11] Проверка тюнинга техники:")
	var active_tractor: Dictionary = VehicleManager.get_active_vehicle(VehicleManager.ROLE_TRACTOR)
	var active_tractor_id: String = str(active_tractor.get("id", ""))
	assert(active_tractor_id != "", "Активный трактор должен иметь ID")

	var base_speed: float = VehicleManager.get_speed_multiplier(VehicleManager.ROLE_TRACTOR)
	var base_fuel: float = VehicleManager.get_fuel_multiplier(VehicleManager.ROLE_TRACTOR)
	var base_reliability: float = VehicleManager.get_active_reliability(VehicleManager.ROLE_TRACTOR)

	var first_engine_cost: int = VehicleManager.get_upgrade_cost(active_tractor_id, "engine")
	assert(first_engine_cost > 0, "Первый уровень двигателя должен иметь стоимость")
	assert(VehicleManager.apply_upgrade(active_tractor_id, "engine"), "Улучшение двигателя должно применяться")
	assert(VehicleManager.get_upgrade_level(active_tractor_id, "engine") == 1, "Двигатель должен стать уровня 1")
	assert(VehicleManager.get_speed_multiplier(VehicleManager.ROLE_TRACTOR) > base_speed, "Двигатель должен увеличить скорость")

	assert(VehicleManager.apply_upgrade(active_tractor_id, "fuel_system"), "Топливная система должна улучшаться")
	assert(VehicleManager.apply_upgrade(active_tractor_id, "transmission"), "Трансмиссия должна улучшаться")
	assert(VehicleManager.get_fuel_multiplier(VehicleManager.ROLE_TRACTOR) < base_fuel, "Тюнинг топлива/трансмиссии должен снизить расход")

	assert(VehicleManager.apply_upgrade(active_tractor_id, "electronics"), "GPS и свет должны улучшаться")
	assert(VehicleManager.get_active_reliability(VehicleManager.ROLE_TRACTOR) > base_reliability, "Электроника должна повысить надёжность")

	var second_engine_cost: int = VehicleManager.get_upgrade_cost(active_tractor_id, "engine")
	assert(second_engine_cost > first_engine_cost, "Следующий уровень двигателя должен быть дороже")

	VehicleManager.save_to_settings()
	VehicleManager.vehicles = {}
	VehicleManager.active_by_role = {}
	VehicleManager.init_from_settings()
	var restored_tractor: Dictionary = VehicleManager.get_active_vehicle(VehicleManager.ROLE_TRACTOR)
	var restored_tractor_id: String = str(restored_tractor.get("id", ""))
	assert(VehicleManager.get_upgrade_level(restored_tractor_id, "engine") == 1, "Уровень двигателя должен сохраниться")
	assert(VehicleManager.get_upgrade_level(restored_tractor_id, "fuel_system") == 1, "Уровень топливной системы должен сохраниться")
	assert(VehicleManager.get_upgrade_level(restored_tractor_id, "electronics") == 1, "Уровень электроники должен сохраниться")
	print("  ✔ ТЕСТ 11 УСПЕШНО ПРОЙДЕН!")

	# 12. Тест: постоянные работники, профессии, уровни и persistence
	print("\n[ТЕСТ 12] Проверка системы работников:")
	var old_workers: Dictionary = WorkerManager.workers.duplicate(true)
	var old_next_worker_id: int = WorkerManager.next_worker_id
	var old_total_hired: int = WorkerManager.total_hired
	var old_total_levels: int = WorkerManager.total_levels_gained

	WorkerManager.initialized = true
	WorkerManager.reset_to_defaults()
	assert(WorkerManager.get_worker_count() == 4, "Стартовый штат должен содержать 4 работников")
	assert(WorkerManager.get_workers_by_profession(WorkerManager.PROF_SOWER).size() == 1, "В штате должен быть сеятель")
	assert(WorkerManager.get_phase_speed_multiplier("sowing") > 1.0, "Сеятель должен ускорять фазу сева")

	var salary_before_hire: int = WorkerManager.get_total_salary_per_cycle()
	var agronomist: Dictionary = WorkerManager.hire_worker(WorkerManager.PROF_AGRONOMIST)
	assert(not agronomist.is_empty(), "Агроном должен успешно наниматься")
	assert(WorkerManager.get_worker_count() == 5, "После найма должно быть 5 работников")
	assert(WorkerManager.get_total_salary_per_cycle() > salary_before_hire, "Найм должен увеличить фонд оплаты труда")
	assert(WorkerManager.get_phase_speed_multiplier("growing") > 1.0, "Агроном должен ускорять рост")
	assert(WorkerManager.get_yield_multiplier() > 1.0, "Специалисты должны повышать урожайность")

	var agronomist_id: String = str(agronomist.get("id", ""))
	for i in range(7):
		WorkerManager.record_cycle_completion()
	var agronomist_after: Dictionary = WorkerManager.workers.get(agronomist_id, {})
	assert(int(agronomist_after.get("level", 1)) >= 2, "Агроном должен повышать уровень от завершённых циклов")

	WorkerManager.save_to_settings()
	WorkerManager.workers = {}
	WorkerManager.init_from_settings()
	assert(WorkerManager.get_worker_count() == 5, "Состав работников должен восстановиться")
	var restored_agronomists: Array[Dictionary] = WorkerManager.get_workers_by_profession(WorkerManager.PROF_AGRONOMIST)
	assert(restored_agronomists.size() == 1, "Агроном должен восстановиться после загрузки")
	assert(int(restored_agronomists[0].get("level", 1)) >= 2, "Уровень агронома должен сохраниться")
	print("  ✔ ТЕСТ 12 УСПЕШНО ПРОЙДЕН!")

	# 13. Тест: инфраструктура фермы, уровни, эффекты и persistence
	print("\n[ТЕСТ 13] Проверка инфраструктуры фермы:")
	var old_building_levels: Dictionary = BuildingManager.levels.duplicate(true)
	var old_building_invested: int = BuildingManager.total_invested
	var old_max_fuel: float = GameManager.max_fuel

	BuildingManager.initialized = true
	BuildingManager.reset_all()
	GameManager.refresh_infrastructure_effects()

	var base_capacity: float = InventoryManager.get_capacity()
	var base_fuel_capacity: float = GameManager.max_fuel
	var base_repair_mult: float = BuildingManager.get_repair_cost_multiplier()
	var base_growth_mult: float = BuildingManager.get_growth_multiplier()
	var base_yield_mult: float = BuildingManager.get_yield_multiplier()

	assert(BuildingManager.upgrade("silo"), "Силос должен улучшаться")
	assert(InventoryManager.get_capacity() >= base_capacity + 1000.0, "Силос должен добавить минимум 1000 кг склада")

	assert(BuildingManager.upgrade("fuel_station"), "АЗС должна улучшаться")
	GameManager.refresh_infrastructure_effects()
	assert(GameManager.max_fuel > base_fuel_capacity, "АЗС должна увеличить максимальный запас топлива")
	assert(BuildingManager.get_fuel_price_multiplier() < 1.0, "АЗС должна снизить стоимость топлива")

	assert(BuildingManager.upgrade("workshop"), "Мастерская должна улучшаться")
	assert(BuildingManager.upgrade("spare_parts"), "Склад запчастей должен улучшаться")
	assert(BuildingManager.get_repair_cost_multiplier() < base_repair_mult, "Инфраструктура должна удешевить ремонт")
	assert(BuildingManager.get_wear_multiplier() < 1.0, "Мастерская должна снижать износ")
	assert(BuildingManager.get_reliability_bonus() > 0.0, "Запчасти должны повышать надёжность")

	assert(BuildingManager.upgrade("agronomy_lab"), "Лаборатория агронома должна улучшаться")
	assert(BuildingManager.get_growth_multiplier() > base_growth_mult, "Лаборатория должна ускорять рост")
	assert(BuildingManager.get_yield_multiplier() > base_yield_mult, "Лаборатория должна повышать урожайность")

	assert(BuildingManager.upgrade("barn_upgrade"), "Расширение амбара должно улучшаться")
	assert(BuildingManager.get_sale_multiplier() > 1.0, "Расширение амбара должно повышать цену продажи")

	BuildingManager.save_to_settings()
	BuildingManager.levels = {}
	BuildingManager.total_invested = 0
	BuildingManager.init_from_settings()
	assert(BuildingManager.get_level("silo") == 1, "Уровень силоса должен сохраниться")
	assert(BuildingManager.get_level("fuel_station") == 1, "Уровень АЗС должен сохраниться")
	assert(BuildingManager.get_level("agronomy_lab") == 1, "Уровень лаборатории должен сохраниться")
	print("  ✔ ТЕСТ 13 УСПЕШНО ПРОЙДЕН!")

	# 14. Тест: классы качества C/B/A/S, цена, склад и persistence
	print("\n[ТЕСТ 14] Проверка качества урожая:")
	var old_quality_totals: Dictionary = QualityManager.total_by_grade.duplicate(true)
	var old_quality_last: Dictionary = QualityManager.last_quality_by_crop.duplicate(true)
	var old_quality_best: Dictionary = QualityManager.best_grade_by_crop.duplicate(true)

	assert(QualityManager.grade_from_score(40.0) == "C", "40 баллов должны давать класс C")
	assert(QualityManager.grade_from_score(60.0) == "B", "60 баллов должны давать класс B")
	assert(QualityManager.grade_from_score(80.0) == "A", "80 баллов должны давать класс A")
	assert(QualityManager.grade_from_score(95.0) == "S", "95 баллов должны давать класс S")
	assert(QualityManager.get_price_multiplier("S") > QualityManager.get_price_multiplier("A"), "S должен стоить дороже A")
	assert(QualityManager.get_price_multiplier("A") > QualityManager.get_price_multiplier("B"), "A должен стоить дороже B")
	assert(QualityManager.get_price_multiplier("C") < QualityManager.get_price_multiplier("B"), "C должен стоить дешевле B")
	assert(QualityManager.meets_minimum("S", "A"), "S должен удовлетворять требованию A")
	assert(not QualityManager.meets_minimum("B", "A"), "B не должен удовлетворять требованию A")

	var clear_quality: Dictionary = QualityManager.calculate_quality("wheat", 0)
	var hail_quality: Dictionary = QualityManager.calculate_quality("wheat", 2)
	assert(float(clear_quality.get("score", 0.0)) > float(hail_quality.get("score", 0.0)), "Ясная погода должна давать качество выше града")

	QualityManager.total_by_grade = {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	QualityManager.last_quality_by_crop = {}
	QualityManager.best_grade_by_crop = {}
	QualityManager.register_harvest("wheat", "A", 125.0)
	assert(is_equal_approx(QualityManager.get_total_kg_for_grade("A"), 125.0), "Статистика A должна учитывать 125 кг")
	assert(QualityManager.get_last_grade("wheat") == "A", "Последний класс пшеницы должен быть A")
	assert(QualityManager.get_best_grade("wheat") == "A", "Лучший класс пшеницы должен быть A")

	QualityManager.save_to_settings()
	QualityManager.total_by_grade = {}
	QualityManager.last_quality_by_crop = {}
	QualityManager.best_grade_by_crop = {}
	QualityManager.init_from_settings()
	assert(is_equal_approx(QualityManager.get_total_kg_for_grade("A"), 125.0), "Статистика качества должна восстановиться")
	assert(QualityManager.get_last_grade("wheat") == "A", "Последний класс должен сохраниться")
	print("  ✔ ТЕСТ 14 УСПЕШНО ПРОЙДЕН!")

	# 15. Тест: позитивные и редкие события, эффекты и persistence
	print("\n[ТЕСТ 15] Проверка позитивных событий:")
	var old_positive_event: Dictionary = PositiveEventManager.active_event.duplicate(true)
	var old_positive_total: int = PositiveEventManager.total_triggered
	var old_positive_rare: int = PositiveEventManager.rare_triggered

	PositiveEventManager.initialized = true
	PositiveEventManager.active_event = {}
	PositiveEventManager.total_triggered = 0
	PositiveEventManager.rare_triggered = 0

	var help_event: Dictionary = PositiveEventManager.start_event("community_help")
	assert(not help_event.is_empty(), "Событие помощи соседей должно запускаться")
	assert(PositiveEventManager.get_speed_multiplier() > 1.0, "Помощь соседей должна ускорять работы")
	assert(PositiveEventManager.get_seconds_left() > 0, "У события должно оставаться время")
	PositiveEventManager.clear_active_event()

	var lucky_event: Dictionary = PositiveEventManager.start_event("lucky_season")
	assert(not lucky_event.is_empty(), "Редкое событие удачного сезона должно запускаться")
	assert(PositiveEventManager.rare_triggered == 1, "Редкое событие должно учитываться в статистике")
	assert(PositiveEventManager.get_yield_multiplier() > 1.0, "Удачный сезон должен повышать урожай")
	assert(PositiveEventManager.get_growth_multiplier() > 1.0, "Удачный сезон должен ускорять рост")
	assert(PositiveEventManager.get_sale_multiplier() > 1.0, "Удачный сезон должен повышать цену")
	assert(PositiveEventManager.get_quality_bonus() > 0.0, "Удачный сезон должен повышать качество")

	PositiveEventManager.save_to_settings()
	PositiveEventManager.active_event = {}
	PositiveEventManager.total_triggered = 0
	PositiveEventManager.rare_triggered = 0
	PositiveEventManager.init_from_settings()
	assert(str(PositiveEventManager.get_active_event().get("id", "")) == "lucky_season", "Активное событие должно восстановиться")
	assert(PositiveEventManager.total_triggered == 2, "Статистика событий должна восстановиться")
	assert(PositiveEventManager.rare_triggered == 1, "Статистика редких событий должна восстановиться")
	print("  ✔ ТЕСТ 15 УСПЕШНО ПРОЙДЕН!")

	# Возвращаем позитивное событие пользователя.
	PositiveEventManager.active_event = old_positive_event
	PositiveEventManager.total_triggered = old_positive_total
	PositiveEventManager.rare_triggered = old_positive_rare
	PositiveEventManager.initialized = true
	PositiveEventManager.save_to_settings()

	# Возвращаем статистику качества пользователя.
	QualityManager.total_by_grade = old_quality_totals
	QualityManager.last_quality_by_crop = old_quality_last
	QualityManager.best_grade_by_crop = old_quality_best
	QualityManager.initialized = true
	QualityManager.save_to_settings()

	# Возвращаем инфраструктуру пользователя.
	BuildingManager.levels = old_building_levels
	BuildingManager.total_invested = old_building_invested
	BuildingManager.initialized = true
	BuildingManager.save_to_settings()
	GameManager.max_fuel = old_max_fuel

	# Возвращаем штат пользователя.
	WorkerManager.workers = old_workers
	WorkerManager.next_worker_id = old_next_worker_id
	WorkerManager.total_hired = old_total_hired
	WorkerManager.total_levels_gained = old_total_levels
	WorkerManager.initialized = true
	WorkerManager.save_to_settings()

	# Возвращаем автопарк пользователя.
	VehicleManager.vehicles = old_vehicles
	VehicleManager.active_by_role = old_active_fleet
	VehicleManager.next_vehicle_id = old_next_vehicle_id
	VehicleManager.initialized = true
	VehicleManager.save_to_settings()
	GameManager._sync_legacy_vehicle_state()
	GameManager.save_to_settings()

	# 16. Тест: достижения, косметические титулы и persistence
	print("\n[ТЕСТ 16] Проверка достижений:")
	var old_achievement_unlocked: Array[String] = AchievementManager.unlocked.duplicate()
	var old_achievement_times: Dictionary = AchievementManager.unlocked_at.duplicate(true)
	var old_achievement_title: String = AchievementManager.active_title
	var old_achievement_points: int = AchievementManager.total_points
	var ach_old_harvests: int = GameManager.total_harvested
	var ach_old_coins: int = GameManager.total_coins_earned
	var ach_old_farm_level: int = ProgressionManager.farm_level
	var ach_old_reputation: int = ProgressionManager.reputation
	var ach_old_contracts: int = ContractManager.total_completed
	var ach_old_quality_s: float = QualityManager.get_total_kg_for_grade("S")
	var ach_old_rare: int = PositiveEventManager.rare_triggered

	AchievementManager.initialized = true
	AchievementManager.unlocked = []
	AchievementManager.unlocked_at = {}
	AchievementManager.active_title = "Фермер"
	AchievementManager.total_points = 0

	GameManager.total_harvested = 100
	GameManager.total_coins_earned = 10000
	ProgressionManager.farm_level = max(10, ProgressionManager.farm_level)
	ProgressionManager.reputation = max(60, ProgressionManager.reputation)
	ContractManager.total_completed = max(10, ContractManager.total_completed)
	QualityManager.total_by_grade["S"] = max(100.0, QualityManager.get_total_kg_for_grade("S"))
	PositiveEventManager.rare_triggered = max(3, PositiveEventManager.rare_triggered)

	var unlocked_now: Array[Dictionary] = AchievementManager.evaluate_all()
	assert(not unlocked_now.is_empty(), "Должны автоматически открыться достижения")
	assert(AchievementManager.is_unlocked("first_harvest"), "Первый урожай должен быть открыт")
	assert(AchievementManager.is_unlocked("harvest_100"), "100 урожаев должны быть открыты")
	assert(AchievementManager.is_unlocked("farm_level_10"), "10 уровень фермы должен быть открыт")
	assert(AchievementManager.is_unlocked("contracts_10"), "10 контрактов должны быть открыты")
	assert(AchievementManager.is_unlocked("quality_s_100"), "100 кг S-класса должны быть открыты")
	assert(AchievementManager.is_unlocked("rare_events_3"), "3 редких события должны быть открыты")
	assert(AchievementManager.is_unlocked("coins_10000"), "10 000 заработанных монет должны быть открыты")
	assert(AchievementManager.total_points > 0, "За достижения должны начисляться achievement points")
	assert(AchievementManager.get_available_titles().has("Хозяин полей"), "Титул «Хозяин полей» должен быть доступен")
	assert(AchievementManager.set_active_title("Хозяин полей"), "Открытый титул должен выбираться")

	AchievementManager.save_to_settings()
	AchievementManager.unlocked = []
	AchievementManager.unlocked_at = {}
	AchievementManager.active_title = "Фермер"
	AchievementManager.total_points = 0
	AchievementManager.init_from_settings()
	assert(AchievementManager.is_unlocked("harvest_100"), "Достижение должно восстановиться")
	assert(AchievementManager.active_title == "Хозяин полей", "Выбранный титул должен сохраниться")
	print("  ✔ ТЕСТ 16 УСПЕШНО ПРОЙДЕН!")

	# Возвращаем пользовательские значения после теста достижений.
	GameManager.total_harvested = ach_old_harvests
	GameManager.total_coins_earned = ach_old_coins
	ProgressionManager.farm_level = ach_old_farm_level
	ProgressionManager.reputation = ach_old_reputation
	ContractManager.total_completed = ach_old_contracts
	QualityManager.total_by_grade["S"] = ach_old_quality_s
	PositiveEventManager.rare_triggered = ach_old_rare
	AchievementManager.unlocked = old_achievement_unlocked
	AchievementManager.unlocked_at = old_achievement_times
	AchievementManager.active_title = old_achievement_title
	AchievementManager.total_points = old_achievement_points
	AchievementManager.initialized = true
	AchievementManager.save_to_settings()
	GameManager.save_to_settings()
	ProgressionManager.save_to_settings()
	ContractManager.save_to_settings()
	QualityManager.save_to_settings()
	PositiveEventManager.save_to_settings()
	assert(int(SettingsManager.config.get_value("statistics", "total_harvested", -1)) == ach_old_harvests, "Lifetime-статистика урожаев должна persistиться")
	assert(int(SettingsManager.config.get_value("statistics", "total_coins_earned", -1)) == ach_old_coins, "Lifetime-статистика монет должна persistиться")

	# 17. Тест: offline progress, cap, эффективность и защита от временных бонусов
	print("\n[ТЕСТ 17] Проверка offline progress:")
	var old_offline_last_seen: int = OfflineProgressManager.last_seen_at
	var old_offline_report: Dictionary = OfflineProgressManager.last_report.duplicate(true)
	var old_offline_seconds: int = OfflineProgressManager.lifetime_offline_seconds
	var old_offline_cycles: int = OfflineProgressManager.lifetime_offline_cycles
	var old_positive_for_offline: Dictionary = PositiveEventManager.active_event.duplicate(true)
	var old_positive_total_for_offline: int = PositiveEventManager.total_triggered
	var old_positive_rare_for_offline: int = PositiveEventManager.rare_triggered

	var ten_hours: Dictionary = OfflineProgressManager.calculate_offline_window(1000, 1000 + 10 * 3600)
	assert(int(ten_hours.get("raw_seconds", 0)) == 10 * 3600, "Должно определиться 10 часов отсутствия")
	assert(int(ten_hours.get("credited_seconds", 0)) == OfflineProgressManager.MAX_OFFLINE_SECONDS, "Офлайн должен ограничиваться 8 часами")
	assert(bool(ten_hours.get("was_capped", false)), "Для 10 часов должен сработать cap")
	assert(int(ten_hours.get("possible_cycles", 0)) == 17, "8 часов × 65% должны дать 17 полных 18-минутных циклов")

	var short_window: Dictionary = OfflineProgressManager.calculate_offline_window(1000, 1030)
	assert(int(short_window.get("possible_cycles", 0)) == 0, "30 секунд не должны давать полный цикл")
	assert(OfflineProgressManager.get_efficiency_percent() == 65, "Эффективность offline должна быть 65%")
	assert(OfflineProgressManager.get_max_offline_hours() == 8, "Лимит offline должен быть 8 часов")

	PositiveEventManager.active_event = {}
	PositiveEventManager.total_triggered = 0
	PositiveEventManager.rare_triggered = 0
	PositiveEventManager.initialized = true
	PositiveEventManager.start_event("farm_fair")
	var online_sale: int = GameManager.calculate_crop_sale_value("wheat", 100.0, "B", true)
	var offline_sale: int = GameManager.calculate_crop_sale_value("wheat", 100.0, "B", false)
	assert(online_sale > offline_sale, "Фермерская ярмарка должна усиливать онлайн-продажу, но не offline")

	OfflineProgressManager.initialized = true
	OfflineProgressManager.last_seen_at = 123456
	OfflineProgressManager.lifetime_offline_seconds = 7200
	OfflineProgressManager.lifetime_offline_cycles = 4
	OfflineProgressManager.last_report = {"cycles_completed": 4}
	OfflineProgressManager.save_to_settings()
	assert(int(SettingsManager.config.get_value("offline", "last_seen_at", 0)) == 123456, "last_seen_at должен persistиться")
	assert(int(SettingsManager.config.get_value("offline", "lifetime_offline_cycles", 0)) == 4, "Счётчик offline-циклов должен persistиться")
	print("  ✔ ТЕСТ 17 УСПЕШНО ПРОЙДЕН!")

	OfflineProgressManager.last_seen_at = old_offline_last_seen
	OfflineProgressManager.last_report = old_offline_report
	OfflineProgressManager.lifetime_offline_seconds = old_offline_seconds
	OfflineProgressManager.lifetime_offline_cycles = old_offline_cycles
	OfflineProgressManager.initialized = true
	OfflineProgressManager.save_to_settings()
	PositiveEventManager.active_event = old_positive_for_offline
	PositiveEventManager.total_triggered = old_positive_total_for_offline
	PositiveEventManager.rare_triggered = old_positive_rare_for_offline
	PositiveEventManager.initialized = true
	PositiveEventManager.save_to_settings()

	# 18. Тест: животноводство, кормовые цепочки, продукция и persistence
	print("\n[ТЕСТ 18] Проверка животноводства:")
	var old_livestock_state: Dictionary = {
		"coop_level": LivestockManager.coop_level,
		"barn_level": LivestockManager.barn_level,
		"chickens": LivestockManager.chickens,
		"cows": LivestockManager.cows,
		"eggs": LivestockManager.eggs,
		"milk_l": LivestockManager.milk_l,
		"auto_sell_products": LivestockManager.auto_sell_products,
		"total_eggs_produced": LivestockManager.total_eggs_produced,
		"total_milk_produced": LivestockManager.total_milk_produced,
		"total_product_coins": LivestockManager.total_product_coins,
		"last_tick_at": LivestockManager.last_tick_at
	}
	var old_livestock_coins: int = GameManager.coins
	var old_livestock_stock: Dictionary = InventoryManager.stock.duplicate(true)
	var old_livestock_quality_stock: Dictionary = InventoryManager.quality_stock.duplicate(true)

	LivestockManager.initialized = true
	LivestockManager.coop_level = 1
	LivestockManager.barn_level = 1
	LivestockManager.chickens = 2
	LivestockManager.cows = 1
	LivestockManager.eggs = 0.0
	LivestockManager.milk_l = 0.0
	LivestockManager.auto_sell_products = false
	LivestockManager.total_eggs_produced = 0.0
	LivestockManager.total_milk_produced = 0.0
	LivestockManager.total_product_coins = 0

	InventoryManager.stock = {
		"wheat": 100.0,
		"corn": 100.0,
		"sunflower": 0.0,
		"carrot": 0.0
	}
	InventoryManager.quality_stock = {
		"wheat": {"C": 0.0, "B": 100.0, "A": 0.0, "S": 0.0},
		"corn": {"C": 0.0, "B": 100.0, "A": 0.0, "S": 0.0},
		"sunflower": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"carrot": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	}
	var wheat_before: float = InventoryManager.get_stock("wheat")
	var corn_before: float = InventoryManager.get_stock("corn")
	var livestock_report: Dictionary = LivestockManager.process_ticks(1)
	assert(float(livestock_report.get("eggs", 0.0)) == 6.0, "2 курицы должны произвести 6 яиц за тик")
	assert(float(livestock_report.get("milk_l", 0.0)) == 5.0, "1 корова должна произвести 5 л молока за тик")
	assert(InventoryManager.get_stock("wheat") < wheat_before, "Животные должны расходовать пшеницу")
	assert(InventoryManager.get_stock("corn") < corn_before, "Животные должны расходовать кукурузу")
	assert(LivestockManager.eggs == 6.0, "Яйца должны храниться на livestock-складе")
	assert(LivestockManager.milk_l == 5.0, "Молоко должно храниться на livestock-складе")

	var coins_before_products: int = GameManager.coins
	var livestock_sale: int = LivestockManager.sell_all_products()
	assert(livestock_sale > 0, "Продажа продукции должна приносить монеты")
	assert(GameManager.coins > coins_before_products, "Казна должна увеличиться после продажи продукции")
	assert(LivestockManager.eggs == 0.0 and LivestockManager.milk_l == 0.0, "После продажи склад продукции должен очиститься")

	LivestockManager.coop_level = 2
	LivestockManager.barn_level = 1
	LivestockManager.chickens = 3
	LivestockManager.cows = 1
	LivestockManager.auto_sell_products = true
	LivestockManager.save_to_settings()
	LivestockManager.coop_level = 0
	LivestockManager.barn_level = 0
	LivestockManager.chickens = 0
	LivestockManager.cows = 0
	LivestockManager.auto_sell_products = false
	LivestockManager.init_from_settings()
	assert(LivestockManager.coop_level == 2, "Уровень курятника должен сохраниться")
	assert(LivestockManager.barn_level == 1, "Уровень коровника должен сохраниться")
	assert(LivestockManager.chickens == 3, "Количество кур должно сохраниться")
	assert(LivestockManager.cows == 1, "Количество коров должно сохраниться")
	assert(LivestockManager.auto_sell_products, "Режим автопродажи должен сохраниться")
	print("  ✔ ТЕСТ 18 УСПЕШНО ПРОЙДЕН!")

	LivestockManager.coop_level = int(old_livestock_state["coop_level"])
	LivestockManager.barn_level = int(old_livestock_state["barn_level"])
	LivestockManager.chickens = int(old_livestock_state["chickens"])
	LivestockManager.cows = int(old_livestock_state["cows"])
	LivestockManager.eggs = float(old_livestock_state["eggs"])
	LivestockManager.milk_l = float(old_livestock_state["milk_l"])
	LivestockManager.auto_sell_products = bool(old_livestock_state["auto_sell_products"])
	LivestockManager.total_eggs_produced = float(old_livestock_state["total_eggs_produced"])
	LivestockManager.total_milk_produced = float(old_livestock_state["total_milk_produced"])
	LivestockManager.total_product_coins = int(old_livestock_state["total_product_coins"])
	LivestockManager.last_tick_at = int(old_livestock_state["last_tick_at"])
	LivestockManager.initialized = true
	LivestockManager.save_to_settings()
	GameManager.coins = old_livestock_coins
	InventoryManager.stock = old_livestock_stock
	InventoryManager.quality_stock = old_livestock_quality_stock
	InventoryManager.save_to_settings()
	GameManager.save_to_settings()

	# 19. Тест: переработка, производственные цепочки, продажа и persistence
	print("\n[ТЕСТ 19] Проверка переработки:")
	var old_processing_levels: Dictionary = ProcessingManager.facility_levels.duplicate(true)
	var old_processing_products: Dictionary = ProcessingManager.products.duplicate(true)
	var old_processing_lifetime: Dictionary = ProcessingManager.lifetime_output.duplicate(true)
	var old_processing_auto_sell: bool = ProcessingManager.auto_sell_products
	var old_processing_batches: int = ProcessingManager.total_batches
	var old_processing_coins: int = ProcessingManager.total_product_coins
	var old_processing_tick: int = ProcessingManager.last_tick_at
	var old_processing_game_coins: int = GameManager.coins
	var old_processing_total_earned: int = GameManager.total_coins_earned
	var old_processing_subsidy: int = GameManager.subsidy_debt
	var old_processing_loan: int = GameManager.loan_debt
	var old_processing_stock: Dictionary = InventoryManager.stock.duplicate(true)
	var old_processing_quality_stock: Dictionary = InventoryManager.quality_stock.duplicate(true)
	var old_processing_milk: float = LivestockManager.milk_l

	ProcessingManager.initialized = true
	ProcessingManager.facility_levels = {"flour_mill": 1, "oil_press": 1, "dairy": 1}
	ProcessingManager.products = {"flour": 0.0, "oil": 0.0, "cheese": 0.0}
	ProcessingManager.lifetime_output = {"flour": 0.0, "oil": 0.0, "cheese": 0.0}
	ProcessingManager.auto_sell_products = false
	ProcessingManager.total_batches = 0
	ProcessingManager.total_product_coins = 0
	GameManager.subsidy_debt = 0
	GameManager.loan_debt = 0

	InventoryManager.stock = {
		"wheat": 120.0,
		"corn": 0.0,
		"sunflower": 60.0,
		"carrot": 0.0
	}
	InventoryManager.quality_stock = {
		"wheat": {"C": 0.0, "B": 120.0, "A": 0.0, "S": 0.0},
		"corn": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"sunflower": {"C": 0.0, "B": 60.0, "A": 0.0, "S": 0.0},
		"carrot": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	}
	LivestockManager.milk_l = 25.0

	var processing_report: Dictionary = ProcessingManager.process_ticks(1)
	assert(int(processing_report.get("batches", 0)) == 3, "Три цеха первого уровня должны выполнить 3 партии")
	assert(is_equal_approx(ProcessingManager.get_product_amount("flour"), 70.0), "100 кг пшеницы должны дать 70 кг муки")
	assert(is_equal_approx(ProcessingManager.get_product_amount("oil"), 18.0), "50 кг подсолнечника должны дать 18 л масла")
	assert(is_equal_approx(ProcessingManager.get_product_amount("cheese"), 5.0), "20 л молока должны дать 5 кг сыра")
	assert(is_equal_approx(InventoryManager.get_stock("wheat"), 20.0), "Мукомольный цех должен списать 100 кг пшеницы")
	assert(is_equal_approx(InventoryManager.get_stock("sunflower"), 10.0), "Маслопресс должен списать 50 кг подсолнечника")
	assert(is_equal_approx(LivestockManager.milk_l, 5.0), "Молочный цех должен списать 20 л молока")
	assert(ProcessingManager.total_batches == 3, "Lifetime-счётчик партий должен увеличиться")

	var processing_coins_before_sale: int = GameManager.coins
	var processing_sale: int = ProcessingManager.sell_all_products()
	assert(processing_sale > 0, "Продажа переработанной продукции должна приносить монеты")
	assert(GameManager.coins > processing_coins_before_sale, "Казна должна увеличиться после продажи переработанной продукции")
	assert(
		ProcessingManager.get_product_amount("flour") == 0.0
		and ProcessingManager.get_product_amount("oil") == 0.0
		and ProcessingManager.get_product_amount("cheese") == 0.0,
		"После продажи склад готовой продукции должен очиститься"
	)

	ProcessingManager.facility_levels = {"flour_mill": 2, "oil_press": 1, "dairy": 1}
	ProcessingManager.products = {"flour": 11.0, "oil": 2.0, "cheese": 1.0}
	ProcessingManager.auto_sell_products = false
	ProcessingManager.save_to_settings()
	ProcessingManager.facility_levels = {}
	ProcessingManager.products = {}
	ProcessingManager.auto_sell_products = true
	ProcessingManager.init_from_settings()
	assert(ProcessingManager.get_facility_level("flour_mill") == 2, "Уровень мукомольного цеха должен сохраниться")
	assert(ProcessingManager.get_facility_level("oil_press") == 1, "Уровень маслопресса должен сохраниться")
	assert(ProcessingManager.get_facility_level("dairy") == 1, "Уровень молочного цеха должен сохраниться")
	assert(is_equal_approx(ProcessingManager.get_product_amount("flour"), 11.0), "Запас муки должен сохраниться")
	assert(not ProcessingManager.auto_sell_products, "Режим автопродажи переработки должен сохраниться")
	print("  ✔ ТЕСТ 19 УСПЕШНО ПРОЙДЕН!")

	ProcessingManager.facility_levels = old_processing_levels
	ProcessingManager.products = old_processing_products
	ProcessingManager.lifetime_output = old_processing_lifetime
	ProcessingManager.auto_sell_products = old_processing_auto_sell
	ProcessingManager.total_batches = old_processing_batches
	ProcessingManager.total_product_coins = old_processing_coins
	ProcessingManager.last_tick_at = old_processing_tick
	ProcessingManager.initialized = true
	ProcessingManager.save_to_settings()
	GameManager.coins = old_processing_game_coins
	GameManager.total_coins_earned = old_processing_total_earned
	GameManager.subsidy_debt = old_processing_subsidy
	GameManager.loan_debt = old_processing_loan
	InventoryManager.stock = old_processing_stock
	InventoryManager.quality_stock = old_processing_quality_stock
	LivestockManager.milk_l = old_processing_milk
	InventoryManager.save_to_settings()
	LivestockManager.save_to_settings()
	GameManager.save_to_settings()

	# 20. Тест: несколько независимых участков, прогресс, монитор и persistence
	print("\n[ТЕСТ 20] Проверка нескольких участков:")
	var old_fields_state: Dictionary = MultiFieldManager.fields.duplicate(true)
	var old_fields_last_update: int = MultiFieldManager.last_update_at
	var old_fields_cycles: int = MultiFieldManager.total_aux_cycles
	var old_fields_harvest: float = MultiFieldManager.total_aux_harvest_kg
	var old_fields_coins: int = GameManager.coins
	var old_fields_total_earned: int = GameManager.total_coins_earned
	var old_fields_harvest_count: int = GameManager.total_harvested
	var old_fields_inventory_stock: Dictionary = InventoryManager.stock.duplicate(true)
	var old_fields_quality_stock: Dictionary = InventoryManager.quality_stock.duplicate(true)
	var old_fields_auto_sell: bool = InventoryManager.auto_sell_on_harvest
	var old_fields_quality_totals: Dictionary = QualityManager.total_by_grade.duplicate(true)
	var old_fields_quality_last: Dictionary = QualityManager.last_quality_by_crop.duplicate(true)
	var old_fields_quality_best: Dictionary = QualityManager.best_grade_by_crop.duplicate(true)
	var old_fields_level: int = ProgressionManager.farm_level
	var old_fields_xp: int = ProgressionManager.xp
	var old_fields_rep: int = ProgressionManager.reputation
	var old_fields_lifetime_xp: int = ProgressionManager.lifetime_xp
	var old_contract_offers: Array = ContractManager.offers.duplicate(true)
	var old_contract_active: Array = ContractManager.active_contracts.duplicate(true)
	var old_contract_completed: int = ContractManager.total_completed
	var old_contract_coins: int = ContractManager.total_contract_coins

	MultiFieldManager.initialized = true
	MultiFieldManager.fields = {
		"field_2": {
			"id": "field_2", "name": "Северный участок", "unlocked": true,
			"level": 1, "crop_id": "wheat", "monitor_index": 1,
			"progress_seconds": 0.0, "cycles_completed": 0, "total_harvest_kg": 0.0
		},
		"field_3": {
			"id": "field_3", "name": "Дальний участок", "unlocked": false,
			"level": 1, "crop_id": "wheat", "monitor_index": 2,
			"progress_seconds": 0.0, "cycles_completed": 0, "total_harvest_kg": 0.0
		}
	}
	MultiFieldManager.total_aux_cycles = 0
	MultiFieldManager.total_aux_harvest_kg = 0.0
	GameManager.coins = 5000
	InventoryManager.auto_sell_on_harvest = false
	InventoryManager.stock = {
		"wheat": 0.0, "corn": 0.0, "sunflower": 0.0, "carrot": 0.0
	}
	InventoryManager.quality_stock = {
		"wheat": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"corn": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"sunflower": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0},
		"carrot": {"C": 0.0, "B": 0.0, "A": 0.0, "S": 0.0}
	}
	ContractManager.offers = []
	ContractManager.active_contracts = []

	assert(MultiFieldManager.is_unlocked("field_2"), "Северный участок должен быть открыт")
	assert(not MultiFieldManager.is_unlocked("field_3"), "Дальний участок должен оставаться закрыт")
	assert(is_equal_approx(MultiFieldManager.get_cycle_seconds("field_2"), 1080.0), "Участок 1 уровня должен иметь 18-минутный цикл")
	assert(is_equal_approx(MultiFieldManager.get_yield_multiplier("field_2"), 1.0), "Участок 1 уровня должен иметь x1 урожайность")
	assert(MultiFieldManager.set_monitor("field_2", 0), "Должна сохраняться привязка участка к монитору")
	assert(int(MultiFieldManager.get_field("field_2").get("monitor_index", -1)) == 0, "Monitor assignment должен измениться")

	var partial_fields_report: Dictionary = MultiFieldManager.process_elapsed(540.0, 1.0)
	assert(int(partial_fields_report.get("cycles_completed", 0)) == 0, "Половина цикла не должна завершать урожай")
	assert(MultiFieldManager.get_progress_ratio("field_2") > 0.49, "Прогресс должен накопиться примерно до 50%")

	var coins_before_aux_cycle: int = GameManager.coins
	var complete_fields_report: Dictionary = MultiFieldManager.process_elapsed(540.0, 1.0)
	assert(int(complete_fields_report.get("cycles_completed", 0)) == 1, "Вторая половина должна завершить один автономный цикл")
	assert(InventoryManager.get_stock("wheat") > 0.0, "Урожай автономного участка должен попасть на общий склад")
	assert(GameManager.coins < coins_before_aux_cycle, "Автономный участок должен оплачивать эксплуатацию при ручном хранении")
	assert(MultiFieldManager.total_aux_cycles == 1, "Lifetime-счётчик автономных циклов должен увеличиться")

	MultiFieldManager.fields["field_2"]["level"] = 3
	assert(is_equal_approx(MultiFieldManager.get_cycle_seconds("field_2"), 720.0), "Участок 3 уровня должен иметь 12-минутный цикл")
	assert(MultiFieldManager.get_yield_multiplier("field_2") > 1.0, "Улучшенный участок должен повышать урожайность")
	MultiFieldManager.fields["field_2"]["crop_id"] = "sunflower"
	MultiFieldManager.save_to_settings()
	MultiFieldManager.fields = {}
	MultiFieldManager.init_from_settings()
	assert(MultiFieldManager.is_unlocked("field_2"), "Открытый участок должен восстановиться")
	assert(int(MultiFieldManager.get_field("field_2").get("level", 0)) == 3, "Уровень участка должен сохраниться")
	assert(str(MultiFieldManager.get_field("field_2").get("crop_id", "")) == "sunflower", "Культура участка должна сохраниться")
	assert(int(MultiFieldManager.get_field("field_2").get("monitor_index", -1)) == 0, "Монитор участка должен сохраниться")
	print("  ✔ ТЕСТ 20 УСПЕШНО ПРОЙДЕН!")

	MultiFieldManager.fields = old_fields_state
	MultiFieldManager.last_update_at = old_fields_last_update
	MultiFieldManager.total_aux_cycles = old_fields_cycles
	MultiFieldManager.total_aux_harvest_kg = old_fields_harvest
	MultiFieldManager.initialized = true
	MultiFieldManager.save_to_settings()
	GameManager.coins = old_fields_coins
	GameManager.total_coins_earned = old_fields_total_earned
	GameManager.total_harvested = old_fields_harvest_count
	InventoryManager.stock = old_fields_inventory_stock
	InventoryManager.quality_stock = old_fields_quality_stock
	InventoryManager.auto_sell_on_harvest = old_fields_auto_sell
	QualityManager.total_by_grade = old_fields_quality_totals
	QualityManager.last_quality_by_crop = old_fields_quality_last
	QualityManager.best_grade_by_crop = old_fields_quality_best
	ProgressionManager.farm_level = old_fields_level
	ProgressionManager.xp = old_fields_xp
	ProgressionManager.reputation = old_fields_rep
	ProgressionManager.lifetime_xp = old_fields_lifetime_xp
	ContractManager.offers = old_contract_offers
	ContractManager.active_contracts = old_contract_active
	ContractManager.total_completed = old_contract_completed
	ContractManager.total_contract_coins = old_contract_coins
	InventoryManager.save_to_settings()
	QualityManager.save_to_settings()
	ProgressionManager.save_to_settings()
	ContractManager.save_to_settings()
	GameManager.save_to_settings()

	# 21. Тест: специализации, взаимоисключение веток и persistence
	print("\n[ТЕСТ 21] Проверка специализаций:")
	var old_spec_path: String = SpecializationManager.selected_path
	var old_spec_tier: int = SpecializationManager.unlocked_tier
	var old_spec_level: int = ProgressionManager.farm_level
	var old_spec_xp: int = ProgressionManager.xp

	ProgressionManager.farm_level = 30
	ProgressionManager.xp = 0
	SpecializationManager.initialized = true
	SpecializationManager.selected_path = SpecializationManager.PATH_NONE
	SpecializationManager.unlocked_tier = 0

	assert(SpecializationManager.get_total_points() == 3, "На 30 уровне должно быть 3 очка специализации")
	assert(SpecializationManager.get_available_points() == 3, "До выбора все 3 очка должны быть свободны")
	assert(SpecializationManager.choose_path(SpecializationManager.PATH_CROPS), "Должна выбираться ветка растениеводства")
	assert(SpecializationManager.selected_path == SpecializationManager.PATH_CROPS, "Выбранная ветка должна сохраниться в состоянии")
	assert(SpecializationManager.unlocked_tier == 1, "Выбор ветки должен открыть первую ступень")
	assert(not SpecializationManager.can_choose_path(SpecializationManager.PATH_LIVESTOCK), "После выбора другие ветки должны блокироваться")
	assert(SpecializationManager.get_crop_yield_multiplier() > 1.0, "Первая ступень растениеводства должна повышать урожайность")

	assert(SpecializationManager.unlock_next_tier(), "Должна открыться вторая ступень")
	assert(SpecializationManager.unlocked_tier == 2, "Вторая ступень должна быть активна")
	assert(SpecializationManager.get_crop_quality_bonus() > 0.0, "Вторая ступень должна повышать качество")
	assert(SpecializationManager.unlock_next_tier(), "Должна открыться третья ступень")
	assert(SpecializationManager.unlocked_tier == 3, "Третья ступень должна быть активна")
	assert(SpecializationManager.get_crop_yield_multiplier() >= 1.20, "Третья ступень должна дать суммарный бонус урожайности")
	assert(SpecializationManager.get_aux_field_cycle_multiplier() < 1.0, "Третья ступень должна ускорять автономные участки")
	assert(SpecializationManager.get_available_points() == 0, "После трёх ступеней свободных очков не должно остаться")

	# Прямо проверяем эффекты двух остальных взаимоисключающих веток.
	SpecializationManager.selected_path = SpecializationManager.PATH_LIVESTOCK
	SpecializationManager.unlocked_tier = 3
	assert(SpecializationManager.get_livestock_feed_multiplier() < 0.90, "Животновод 3 ступени должен заметно снижать расход корма")
	assert(SpecializationManager.get_livestock_output_multiplier() >= 1.35, "Животновод 3 ступени должен повышать продукцию на 35%")

	SpecializationManager.selected_path = SpecializationManager.PATH_PROCESSING
	SpecializationManager.unlocked_tier = 3
	assert(SpecializationManager.get_processing_output_multiplier() >= 1.35, "Переработчик 3 ступени должен повышать выход на 35%")
	assert(SpecializationManager.get_processing_sale_multiplier() >= 1.12, "Переработчик 3 ступени должен повышать цену готовой продукции")

	# Persistence проверяем на исходно выбранной ветке растениеводства.
	SpecializationManager.selected_path = SpecializationManager.PATH_CROPS
	SpecializationManager.unlocked_tier = 3
	SpecializationManager.save_to_settings()
	SpecializationManager.selected_path = SpecializationManager.PATH_NONE
	SpecializationManager.unlocked_tier = 0
	SpecializationManager.init_from_settings()
	assert(SpecializationManager.selected_path == SpecializationManager.PATH_CROPS, "Выбранная специализация должна восстановиться")
	assert(SpecializationManager.unlocked_tier == 3, "Ступень специализации должна восстановиться")
	print("  ✔ ТЕСТ 21 УСПЕШНО ПРОЙДЕН!")

	SpecializationManager.selected_path = old_spec_path
	SpecializationManager.unlocked_tier = old_spec_tier
	SpecializationManager.initialized = true
	SpecializationManager.save_to_settings()
	ProgressionManager.farm_level = old_spec_level
	ProgressionManager.xp = old_spec_xp
	ProgressionManager.save_to_settings()

	# 22. Тест: Prestige endgame requirements, permanent bonuses и persistence
	print("\n[ТЕСТ 22] Проверка Prestige:")
	var old_prestige_rank: int = PrestigeManager.prestige_rank
	var old_prestige_total: int = PrestigeManager.total_prestiges
	var old_prestige_last: int = PrestigeManager.last_prestige_at
	var old_prestige_level: int = ProgressionManager.farm_level
	var old_prestige_spec_tier: int = int(SettingsManager.config.get_value("specialization", "unlocked_tier", 0))
	var old_prestige_fields: Variant = SettingsManager.config.get_value("multi_fields", "fields", {})
	var old_prestige_coop: int = int(SettingsManager.config.get_value("livestock", "coop_level", 0))
	var old_prestige_barn: int = int(SettingsManager.config.get_value("livestock", "barn_level", 0))
	var old_prestige_processing: Variant = SettingsManager.config.get_value("processing", "facility_levels", {})

	PrestigeManager.initialized = true
	PrestigeManager.prestige_rank = 0
	PrestigeManager.total_prestiges = 0
	PrestigeManager.last_prestige_at = 0
	ProgressionManager.farm_level = ProgressionManager.MAX_LEVEL
	SettingsManager.config.set_value("specialization", "unlocked_tier", 3)
	SettingsManager.config.set_value("multi_fields", "fields", {
		"field_2": {"unlocked": true},
		"field_3": {"unlocked": true}
	})
	SettingsManager.config.set_value("livestock", "coop_level", 3)
	SettingsManager.config.set_value("livestock", "barn_level", 3)
	SettingsManager.config.set_value("processing", "facility_levels", {
		"flour_mill": 2,
		"oil_press": 2,
		"dairy": 2
	})

	assert(PrestigeManager.can_prestige(), "При насыщенном endgame Prestige должен быть доступен")
	assert(PrestigeManager.get_missing_requirements().is_empty(), "При выполненных требованиях список недостающего должен быть пуст")
	assert(PrestigeManager.award_prestige(), "Prestige должен успешно начислиться")
	assert(PrestigeManager.prestige_rank == 1, "После первого Prestige ранг должен быть 1")
	assert(PrestigeManager.total_prestiges == 1, "Lifetime prestige counter должен увеличиться")
	assert(PrestigeManager.get_yield_multiplier() > 1.0, "Prestige должен давать постоянный yield bonus")
	assert(PrestigeManager.get_sale_multiplier() > 1.0, "Prestige должен давать постоянный sale bonus")
	assert(PrestigeManager.get_offline_efficiency_bonus() > 0.0, "Prestige должен улучшать offline efficiency")
	assert(PrestigeManager.get_starting_coins() == 150, "Первый Prestige должен давать 150 стартовых монет")

	PrestigeManager.save_to_settings()
	PrestigeManager.prestige_rank = 0
	PrestigeManager.total_prestiges = 0
	PrestigeManager.last_prestige_at = 0
	PrestigeManager.init_from_settings()
	assert(PrestigeManager.prestige_rank == 1, "Prestige rank должен восстановиться")
	assert(PrestigeManager.total_prestiges == 1, "Prestige lifetime counter должен восстановиться")

	SettingsManager.config.set_value("livestock", "barn_level", 2)
	assert(not PrestigeManager.can_prestige(), "Без MAX-коровника новый Prestige должен быть заблокирован")
	assert(not PrestigeManager.get_missing_requirements().is_empty(), "Должно отображаться недостающее требование")
	print("  ✔ ТЕСТ 22 УСПЕШНО ПРОЙДЕН!")

	PrestigeManager.prestige_rank = old_prestige_rank
	PrestigeManager.total_prestiges = old_prestige_total
	PrestigeManager.last_prestige_at = old_prestige_last
	PrestigeManager.initialized = true
	PrestigeManager.save_to_settings()
	ProgressionManager.farm_level = old_prestige_level
	SettingsManager.config.set_value("specialization", "unlocked_tier", old_prestige_spec_tier)
	SettingsManager.config.set_value("multi_fields", "fields", old_prestige_fields)
	SettingsManager.config.set_value("livestock", "coop_level", old_prestige_coop)
	SettingsManager.config.set_value("livestock", "barn_level", old_prestige_barn)
	SettingsManager.config.set_value("processing", "facility_levels", old_prestige_processing)
	SettingsManager.save_settings()
	ProgressionManager.save_to_settings()

	print("\n🎉 ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ! СИСТЕМА ПОЛНОСТЬЮ ИСПРАВНА!")
	quit(0)
