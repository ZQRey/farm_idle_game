class_name WindowManager
extends RefCounted

const SettingsManager = preload("res://scripts/SettingsManager.gd")

const BAR_HEIGHT: int = 120
const SCREEN_ALL_MONITORS: int = -1

## Применяет параметры окна-полосы компаньона
static func setup_companion_window(window: Window, screen_index: int = -999) -> void:
	if screen_index == -999:
		# По умолчанию берем primary экран или сохраненный
		screen_index = SettingsManager.get_screen_index()

	# 1. Свойства окна в Godot (фоновое положение как обои)
	window.transparent_bg = true
	window.borderless = true
	window.always_on_top = false
	window.unfocusable = true

	# 2. Флаги окна через DisplayServer
	var main_win_id: int = DisplayServer.MAIN_WINDOW_ID
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, main_win_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false, main_win_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, main_win_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, main_win_id)

	# 3. Позиционирование полосы высотой 120 px
	apply_screen(window, screen_index)


## Перемещает и масштабирует окно компаньона на указанный экран или на все экраны одновременно
static func apply_screen(window: Window, screen_index: int) -> void:
	var screen_count: int = DisplayServer.get_screen_count()
	var main_win_id: int = DisplayServer.MAIN_WINDOW_ID

	if screen_index == SCREEN_ALL_MONITORS and screen_count > 1 and not supports_single_window_all_monitors():
		push_warning("[WindowManager] Мониторы имеют разную нижнюю границу. Режим одного окна на все экраны небезопасен; используется основной монитор.")
		screen_index = DisplayServer.get_primary_screen()

	var target_pos: Vector2i
	var target_size: Vector2i

	if screen_index == SCREEN_ALL_MONITORS or screen_count <= 1 and screen_index < 0:
		# РЕЖИМ: ОТОБРАЖЕНИЕ НА ВСЕХ МОНИТОРАХ ОДНОВРЕМЕННО
		var min_x: int = 2147483647
		var max_x: int = -2147483648
		var target_y: int = 0

		for i in range(screen_count):
			var usable: Rect2i = DisplayServer.screen_get_usable_rect(i)
			min_x = min(min_x, usable.position.x)
			max_x = max(max_x, usable.position.x + usable.size.x)
			target_y = max(target_y, usable.position.y + usable.size.y - BAR_HEIGHT)

		target_size = Vector2i(max_x - min_x, BAR_HEIGHT)
		target_pos = Vector2i(min_x, target_y)
		SettingsManager.set_screen_index(SCREEN_ALL_MONITORS)
	else:
		# РЕЖИМ: ВЫБРАННЫЙ МОНИТОР
		if screen_index < 0 or screen_index >= screen_count:
			screen_index = DisplayServer.get_primary_screen()

		var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
		var win_width: int = usable_rect.size.x
		var win_height: int = BAR_HEIGHT
		var win_x: int = usable_rect.position.x
		var win_y: int = usable_rect.position.y + usable_rect.size.y - win_height

		target_size = Vector2i(win_width, win_height)
		target_pos = Vector2i(win_x, win_y)
		SettingsManager.set_screen_index(screen_index)

	# Применяем геометрию окна
	window.size = target_size
	window.position = target_pos
	DisplayServer.window_set_size(target_size, main_win_id)
	DisplayServer.window_set_position(target_pos, main_win_id)

	# Настраиваем прокликиваемость: сброс маски обрезки SetWindowRgn
	setup_mouse_passthrough(target_size.x, target_size.y, main_win_id)

	# Применяем системные стили фонового окна (HWND_BOTTOM + WS_EX_TRANSPARENT)
	apply_desktop_styles()

	print("[WindowManager] Window positioned at: ", target_pos, " size: ", target_size, " (screen_index: ", screen_index, ")")


## Настраивает полигон мыши для полной прозрачности
static func setup_mouse_passthrough(_width: int, _height: int, window_id: int = 0) -> void:
	# Сброс маски обрезки SetWindowRgn: окно рендерится кристально прозрачно без черных полос
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), window_id)


static func supports_single_window_all_monitors() -> bool:
	var count: int = DisplayServer.get_screen_count()
	if count <= 1:
		return true
	var first_rect: Rect2i = DisplayServer.screen_get_usable_rect(0)
	var baseline_bottom: int = first_rect.position.y + first_rect.size.y
	for i in range(1, count):
		var rect: Rect2i = DisplayServer.screen_get_usable_rect(i)
		var bottom: int = rect.position.y + rect.size.y
		if abs(bottom - baseline_bottom) > 2:
			return false
	return true

## Возвращает список названий мониторов + опцию "Все мониторы одновременно"
static func get_monitor_options() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	
	var count: int = DisplayServer.get_screen_count()
	var bonus_str: String = " (Прибыль x%d 💰)" % count if count >= 2 else ""

	# Одно широкое окно корректно работает только у экранов с общей нижней границей.
	var all_supported: bool = supports_single_window_all_monitors()
	list.append({
		"id": SCREEN_ALL_MONITORS,
		"title": ("🌐 Все мониторы одновременно%s" % bonus_str) if all_supported else "🌐 Все мониторы — недоступно для разноуровневой раскладки",
		"enabled": all_supported
	})
	var primary: int = DisplayServer.get_primary_screen()

	for i in range(count):
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(i)
		var is_prim: String = " [Основной]" if i == primary else ""
		list.append({
			"id": i,
			"title": "🖥 Монитор %d (%dx%d)%s" % [i + 1, usable.size.x, usable.size.y, is_prim],
			"enabled": true
		})

	return list


## Применяет через Win32 API фоновый Z-порядок (HWND_BOTTOM) и прозрачность для мыши (WS_EX_TRANSPARENT)
static func apply_desktop_styles() -> void:
	if OS.get_name() != "Windows":
		return

	var source_path: String = "res://tools/window_helper.ps1"
	if not FileAccess.file_exists(source_path):
		push_warning("[WindowManager] window_helper.ps1 отсутствует в export.")
		return

	# В release res:// может находиться внутри embedded PCK, а PowerShell -File
	# требует реальный файловый путь. Извлекаем helper в user://.
	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		push_warning("[WindowManager] Не удалось прочитать window_helper.ps1 из res://.")
		return
	var helper_text: String = source.get_as_text()
	source.close()

	var user_script_path: String = "user://window_helper_runtime.ps1"
	var target: FileAccess = FileAccess.open(user_script_path, FileAccess.WRITE)
	if target == null:
		push_warning("[WindowManager] Не удалось создать runtime PowerShell helper.")
		return
	target.store_string(helper_text)
	target.close()

	var pid: int = OS.get_process_id()
	var script_path: String = ProjectSettings.globalize_path(user_script_path)
	var args: PackedStringArray = [
		"-NoProfile",
		"-WindowStyle", "Hidden",
		"-ExecutionPolicy", "Bypass",
		"-File", script_path,
		"-ProcessId", str(pid)
	]
	OS.create_process("powershell.exe", args)
