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
	InventoryManager.storage_level = 1
	InventoryManager.auto_sell_on_harvest = false
	InventoryManager.total_harvest_stored_kg = 0.0
	InventoryManager.total_overflow_kg = 0.0

	var deposit_a: Dictionary = InventoryManager.deposit_crop("wheat", 400.0)
	assert(is_equal_approx(float(deposit_a.get("stored_kg", 0.0)), 400.0), "400 кг пшеницы должны полностью поместиться")
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

	print("\n🎉 ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ! СИСТЕМА ПОЛНОСТЬЮ ИСПРАВНА!")
	quit(0)
