class_name TrayManager
extends Node

const WindowManager = preload("res://scripts/WindowManager.gd")
const SettingsManager = preload("res://scripts/SettingsManager.gd")

signal open_farm_hq_requested
signal toggle_pause_requested
signal monitor_changed(screen_index: int)
signal graphics_mode_changed(mode: String)
signal fps_changed(fps: int)
signal quit_requested
signal resolve_strike_requested
signal call_mechanic_requested

var status_indicator: StatusIndicator
var context_menu: PopupMenu
var monitor_submenu: PopupMenu
var graphics_submenu: PopupMenu
var is_paused: bool = false

# Динамическое состояние кризисов для контекстного меню
var is_strike_active: bool = false
var is_breakdown_active: bool = false
var weather_string: String = "Ясно ☀"

func _ready() -> void:
	_create_context_menu()
	_create_status_indicator()

func _create_status_indicator() -> void:
	status_indicator = StatusIndicator.new()
	status_indicator.tooltip = "Farm Idle Companion"
	status_indicator.icon = _generate_tractor_tray_icon()
	status_indicator.pressed.connect(_on_indicator_pressed)
	add_child(status_indicator)

func _create_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.name = "TrayContextMenu"
	add_child(context_menu)

	# 1. Штаб фермы
	context_menu.add_item("🌾 Штаб фермы (Магазин / Гараж)", 100)
	context_menu.add_separator()

	# 2. Статус погоды
	context_menu.add_item("🌤 Погода: " + weather_string, 110)
	context_menu.set_item_disabled(context_menu.get_item_index(110), true)

	# 3. Пауза
	context_menu.add_check_item("⏸ Пауза", 101)

	# 4. Подменю Мониторов
	monitor_submenu = PopupMenu.new()
	monitor_submenu.name = "MonitorSubmenu"
	context_menu.add_child(monitor_submenu)
	_update_monitor_submenu()
	monitor_submenu.id_pressed.connect(_on_monitor_selected)
	context_menu.add_submenu_node_item("🖥 Выбор монитора", monitor_submenu, 102)

	# 5. Подменю Графики
	graphics_submenu = PopupMenu.new()
	graphics_submenu.name = "GraphicsSubmenu"
	context_menu.add_child(graphics_submenu)
	graphics_submenu.add_radio_check_item("32-bit Native (Мягкий цвет)", 201)
	graphics_submenu.add_radio_check_item("16-bit Retro Dithered", 202)
	_update_graphics_submenu()
	graphics_submenu.id_pressed.connect(_on_graphics_selected)
	context_menu.add_submenu_node_item("🎨 Графика", graphics_submenu, 103)

	context_menu.add_separator()
	# 6. Выход
	context_menu.add_item("❌ Выход", 999)

	context_menu.id_pressed.connect(_on_context_menu_item_pressed)

func _rebuild_context_menu() -> void:
	context_menu.clear()

	# 1. Штаб фермы
	context_menu.add_item("🌾 Штаб фермы (Магазин / Гараж)", 100)

	# Кризисные кнопки если активны
	if is_strike_active:
		context_menu.add_item("🚨 Выплатить премию забастовщикам (50 🪙)", 300)
	if is_breakdown_active:
		context_menu.add_item("🔧 Вызвать аварийный ремонт (30 🪙)", 301)

	context_menu.add_separator()
	context_menu.add_item("🌤 Погода: " + weather_string, 110)
	context_menu.set_item_disabled(context_menu.get_item_index(110), true)

	# Пауза
	context_menu.add_check_item("⏸ Пауза", 101)
	context_menu.set_item_checked(context_menu.get_item_index(101), is_paused)

	# Мониторы и Графика
	_update_monitor_submenu()
	_update_graphics_submenu()
	context_menu.add_submenu_node_item("🖥 Выбор монитора", monitor_submenu, 102)
	context_menu.add_submenu_node_item("🎨 Графика", graphics_submenu, 103)

	context_menu.add_separator()
	context_menu.add_item("❌ Выход", 999)

func _update_monitor_submenu() -> void:
	if monitor_submenu == null:
		return
	monitor_submenu.clear()
	var current_screen: int = SettingsManager.get_screen_index()
	var options: Array[Dictionary] = WindowManager.get_monitor_options()

	for opt in options:
		var opt_id: int = opt.id
		var menu_item_id: int = 500 if opt_id == WindowManager.SCREEN_ALL_MONITORS else (501 + opt_id)
		monitor_submenu.add_radio_check_item(opt.title, menu_item_id)
		var is_active: bool = (opt_id == current_screen)
		monitor_submenu.set_item_checked(monitor_submenu.get_item_index(menu_item_id), is_active)

func _update_graphics_submenu() -> void:
	if graphics_submenu == null:
		return
	var mode: String = SettingsManager.get_graphics_mode()
	graphics_submenu.set_item_checked(graphics_submenu.get_item_index(201), mode == "32bit")
	graphics_submenu.set_item_checked(graphics_submenu.get_item_index(202), mode == "16bit")

func _on_indicator_pressed(mouse_button: int, screen_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		open_farm_hq_requested.emit()
	elif mouse_button == MOUSE_BUTTON_RIGHT:
		_rebuild_context_menu()
		context_menu.position = screen_position
		context_menu.popup()

func _on_context_menu_item_pressed(id: int) -> void:
	match id:
		100:
			open_farm_hq_requested.emit()
		101:
			is_paused = !is_paused
			toggle_pause_requested.emit(is_paused)
		300:
			resolve_strike_requested.emit()
		301:
			call_mechanic_requested.emit()
		999:
			quit_requested.emit()
			get_tree().quit()

func _on_monitor_selected(menu_item_id: int) -> void:
	var screen_idx: int = WindowManager.SCREEN_ALL_MONITORS if menu_item_id == 500 else (menu_item_id - 501)
	SettingsManager.set_screen_index(screen_idx)
	_update_monitor_submenu()
	monitor_changed.emit(screen_idx)

func _on_graphics_selected(id: int) -> void:
	var mode: String = "32bit" if id == 201 else "16bit"
	SettingsManager.set_graphics_mode(mode)
	_update_graphics_submenu()
	graphics_mode_changed.emit(mode)

func _generate_tractor_tray_icon() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var c_body: Color = Color("e53935")
	var c_cab: Color = Color("81d4fa")
	var c_tire: Color = Color("212121")
	var c_rim: Color = Color("fbc02d")
	var c_pipe: Color = Color("424242")

	img.set_pixel(11, 2, c_pipe)
	img.set_pixel(11, 3, c_pipe)

	for x in range(3, 8):
		for y in range(4, 8):
			img.set_pixel(x, y, c_cab)

	for x in range(2, 14):
		for y in range(8, 12):
			img.set_pixel(x, y, c_body)

	for x in range(8, 14):
		for y in range(6, 8):
			img.set_pixel(x, y, c_body)

	for x in range(2, 7):
		for y in range(10, 15):
			img.set_pixel(x, y, c_tire)
	img.set_pixel(4, 12, c_rim)

	for x in range(10, 14):
		for y in range(11, 15):
			img.set_pixel(x, y, c_tire)
	img.set_pixel(12, 13, c_rim)

	return ImageTexture.create_from_image(img)
