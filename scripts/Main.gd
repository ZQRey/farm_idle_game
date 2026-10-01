class_name Main
extends Node2D

const WindowManager = preload("res://scripts/WindowManager.gd")
const SettingsManager = preload("res://scripts/SettingsManager.gd")
const TrayManager = preload("res://scripts/TrayManager.gd")
const AssetGenerator = preload("res://tools/AssetGenerator.gd")
const GameManager = preload("res://scripts/GameManager.gd")
const ContractManager = preload("res://scripts/ContractManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const FieldFSM = preload("res://scripts/FieldFSM.gd")
const EventManager = preload("res://scripts/EventManager.gd")
const FarmHQ = preload("res://scripts/FarmHQ.gd")

@onready var tray_manager: TrayManager = $TrayManager
@onready var field: FieldFSM = $Field
@onready var event_manager: EventManager = $EventManager
@onready var farm_hq: FarmHQ = $FarmHQ

var shader_material: ShaderMaterial

func _ready() -> void:
	# 0. Процедурная генерация ассетов при первом старте
	AssetGenerator.generate_all_assets(false)

	# 1. Загрузка настроек и экономики
	SettingsManager.load_settings()
	GameManager.init_from_settings()
	ContractManager.init_from_settings()
	InventoryManager.init_from_settings()
	if GameManager.has_barn:
		InventoryManager.ensure_minimum_level(2)
	farm_hq._update_ui()

	# 2. Ограничение FPS (по умолчанию 30 FPS для минимальной нагрузки)
	var fps_limit: int = SettingsManager.get_fps_limit()
	Engine.max_fps = fps_limit

	# 3. Настройка чистого прозрачного фона
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	get_tree().root.transparent_bg = true

	# 4. Настройка окна-компаньона
	var current_screen: int = SettingsManager.get_screen_index()
	WindowManager.setup_companion_window(get_tree().root, current_screen)

	# 5. Настройка шейдера 16-бит / 32-бит
	_init_graphics_shader()

	# 6. Подключение сигналов системного трея
	tray_manager.monitor_changed.connect(_on_monitor_changed)
	tray_manager.toggle_pause_requested.connect(_on_toggle_pause)
	tray_manager.open_farm_hq_requested.connect(_on_open_farm_hq)
	tray_manager.graphics_mode_changed.connect(_on_graphics_mode_changed)
	tray_manager.resolve_strike_requested.connect(_on_resolve_strike)
	tray_manager.call_mechanic_requested.connect(_on_call_mechanic)
	tray_manager.police_fine_requested.connect(_on_police_fine)
	tray_manager.police_bribe_requested.connect(_on_police_bribe)
	tray_manager.quit_requested.connect(_on_quit_requested)

	# 7. Подключение сигналов окна «Штаб фермы»
	farm_hq.monitor_selected.connect(_on_monitor_changed)
	farm_hq.graphics_mode_selected.connect(_on_graphics_mode_changed)
	farm_hq.tractor_color_changed.connect(_on_tractor_color_changed)
	farm_hq.fps_selected.connect(_on_fps_changed)
	farm_hq.repair_requested.connect(_on_call_mechanic)
	farm_hq.strike_resolve_requested.connect(_on_resolve_strike)
	farm_hq.bankruptcy_requested.connect(_on_bankruptcy_requested)
	farm_hq.police_fine_requested.connect(_on_police_fine)
	farm_hq.police_bribe_requested.connect(_on_police_bribe)

	# 8. Подключение сигналов поля и событий
	field.harvest_completed.connect(_on_harvest_completed)
	event_manager.weather_changed.connect(_on_weather_changed)
	event_manager.season_changed.connect(_on_season_changed)
	event_manager.strike_started.connect(func():
		tray_manager.is_strike_active = true
		farm_hq._update_ui()
	)
	event_manager.strike_resolved.connect(func():
		tray_manager.is_strike_active = false
		farm_hq._update_ui()
	)
	event_manager.breakdown_started.connect(func(_pos):
		tray_manager.is_breakdown_active = true
		farm_hq._update_ui()
	)
	event_manager.breakdown_resolved.connect(func():
		tray_manager.is_breakdown_active = false
		farm_hq._update_ui()
	)
	event_manager.police_arrived.connect(func():
		tray_manager.is_police_active = true
		farm_hq._update_ui()
	)
	event_manager.police_resolved.connect(func():
		tray_manager.is_police_active = false
		farm_hq._update_ui()
	)
	# 9. Таймер периодического автосохранения каждые 10 секунд
	var autosave_timer: Timer = Timer.new()
	autosave_timer.wait_time = 10.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(save_all_state)
	add_child(autosave_timer)

	print("[Main] Farm Idle Companion fully operational!")

func _init_graphics_shader() -> void:
	if field != null and field.material is ShaderMaterial:
		shader_material = field.material as ShaderMaterial
		var is_16bit: bool = (SettingsManager.get_graphics_mode() == "16bit")
		shader_material.set_shader_parameter("enabled", is_16bit)

func _on_monitor_changed(screen_index: int) -> void:
	WindowManager.apply_screen(get_tree().root, screen_index)
	field._update_screen_bounds()
	field.queue_redraw()
	print("[Main] Switched to screen: ", screen_index)

func _on_toggle_pause(is_paused: bool) -> void:
	get_tree().paused = is_paused

func _on_open_farm_hq() -> void:
	farm_hq.open_hq()

func _on_graphics_mode_changed(mode: String) -> void:
	var is_16bit: bool = (mode == "16bit")
	if shader_material != null:
		shader_material.set_shader_parameter("enabled", is_16bit)
	print("[Main] Graphics shader mode: ", mode)

func _on_fps_changed(fps: int) -> void:
	Engine.max_fps = fps
	print("[Main] Engine FPS set to: ", fps)

func _on_tractor_color_changed(color: Color) -> void:
	if field.vehicle_sprite != null and field.current_state == FieldFSM.State.PLOWING:
		field.vehicle_sprite.modulate = color

func _on_harvest_completed(_coins_earned: int) -> void:
	farm_hq._update_ui()

func _on_weather_changed(w_enum: int, w_name: String) -> void:
	tray_manager.weather_string = w_name
	if field != null:
		field.set_weather(w_enum)

func _on_resolve_strike() -> void:
	event_manager.resolve_strike(true)
	farm_hq._update_ui()

func _on_call_mechanic() -> void:
	event_manager.call_mechanic()
	farm_hq._update_ui()

func _on_bankruptcy_requested() -> void:
	field.reset_field_to_start()
	event_manager.reset_all_events()
	ContractManager.reset_all_contracts()
	InventoryManager.reset_all()
	farm_hq._refresh_contracts_ui()
	farm_hq._refresh_storage_ui()
	farm_hq._update_ui()
	print("[Main] Ферма объявила банкротство: долги списаны, поле и техника сброшены!")

func _on_season_changed(_season: GameManager.Season, season_name: String) -> void:
	tray_manager.season_string = season_name
	if field != null:
		field.set_season(int(_season))
	farm_hq._update_ui()

func _on_police_fine() -> void:
	event_manager.resolve_police_fine(false)
	farm_hq._update_ui()

func _on_police_bribe() -> void:
	event_manager.resolve_police_bribe()
	farm_hq._update_ui()

func save_all_state() -> void:
	GameManager.save_to_settings()
	ContractManager.save_to_settings()
	InventoryManager.save_to_settings()
	if field != null:
		field.save_field_state()
	if event_manager != null:
		event_manager.save_event_state()
	print("[Main] Текущее состояние игры успешно сохранено.")

func _on_quit_requested() -> void:
	save_all_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_all_state()

