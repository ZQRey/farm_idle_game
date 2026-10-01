@tool
extends SceneTree

const SettingsManager = preload("res://scripts/SettingsManager.gd")
const WindowManager = preload("res://scripts/WindowManager.gd")
const GameManager = preload("res://scripts/GameManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const FieldFSM = preload("res://scripts/FieldFSM.gd")
const EventManager = preload("res://scripts/EventManager.gd")

func _init() -> void:
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ НОВЫХ ФУНКЦИЙ ---")
	SettingsManager.load_settings()
	GameManager.init_from_settings()

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

	print("\n🎉 ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ! СИСТЕМА ПОЛНОСТЬЮ ИСПРАВНА!")
	quit(0)
