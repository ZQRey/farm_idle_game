class_name EventManager
extends Node

const GameManager = preload("res://scripts/GameManager.gd")
const FieldFSM = preload("res://scripts/FieldFSM.gd")
const AssetGenerator = preload("res://tools/AssetGenerator.gd")

enum Weather {
	CLEAR, # 0. Ясно
	RAIN,  # 1. Дождь (буксование в грязи, укрытие под навесом)
	HAIL,  # 2. Град (нужен навес, иначе повреждения)
	SNOW,  # 3. Снег (-30% к скорости)
	WIND,  # 4. Сильный ветер (-50% к скорости сева)
	NIGHT  # 5. Ночь (лагерь у костра)
}

signal weather_changed(new_weather: Weather, weather_name: String)
signal strike_started
signal strike_resolved
signal breakdown_started(vehicle_pos: Vector2)
signal breakdown_resolved
signal repair_progress(status: String)

@export var field_fsm: FieldFSM

var current_weather: Weather = Weather.CLEAR
var weather_timer: float = 0.0
var weather_duration: float = 40.0

var event_check_timer: float = 0.0
var event_check_interval: float = 25.0

var is_strike_active: bool = false
var strike_timer: float = 0.0
const STRIKE_AUTO_RESOLVE_TIME: float = 90.0

var is_breakdown_active: bool = false
var is_repairing: bool = false
var repair_timer: float = 0.0

# Визуальные объекты
var strike_poster: Sprite2D
var repair_pickup: Sprite2D

func _ready() -> void:
	_create_crisis_visuals()

func _create_crisis_visuals() -> void:
	var tex_crisis: Texture2D = AssetGenerator.get_texture("crisis_objects.png")
	var tex_pickup: Texture2D = AssetGenerator.get_texture("pickup_repair.png")

	# Плакат забастовки
	strike_poster = Sprite2D.new()
	strike_poster.texture = tex_crisis
	strike_poster.region_enabled = true
	strike_poster.region_rect = Rect2(0, 0, 16, 16)
	strike_poster.scale = Vector2(2.0, 2.0)
	strike_poster.visible = false
	add_child(strike_poster)

	# Пикап аварийной службы
	repair_pickup = Sprite2D.new()
	repair_pickup.texture = tex_pickup
	repair_pickup.hframes = 2
	repair_pickup.scale = Vector2(2.0, 2.0)
	repair_pickup.visible = false
	add_child(repair_pickup)

func _process(delta: float) -> void:
	_process_weather(delta)
	_process_events_timer(delta)
	_process_active_strike(delta)
	_process_repair_service(delta)

# ------------------------------------------------------------------------------
# ПОГОДА И ЦИКЛЫ (Ясно, Дождь, Град, Снег, Ветер, Ночь)
# ------------------------------------------------------------------------------
func _process_weather(delta: float) -> void:
	weather_timer += delta
	if weather_timer >= weather_duration:
		weather_timer = 0.0
		_roll_new_weather()

func _roll_new_weather() -> void:
	var roll: float = randf()

	# Смена погоды
	if roll < 0.30:
		current_weather = Weather.CLEAR
	elif roll < 0.50:
		current_weather = Weather.RAIN
	elif roll < 0.65:
		current_weather = Weather.WIND
	elif roll < 0.80:
		current_weather = Weather.SNOW
	elif roll < 0.90:
		current_weather = Weather.HAIL
	else:
		current_weather = Weather.NIGHT

	_apply_weather_effects()

func _apply_weather_effects() -> void:
	if field_fsm == null:
		return

	field_fsm.current_weather_id = current_weather
	field_fsm.is_night_active = (current_weather == Weather.NIGHT)

	# Сброс застревания в грязи если дождь закончился
	if current_weather != Weather.RAIN:
		field_fsm.is_stuck_in_mud = false
		GameManager.is_stuck_in_mud = false

	# Настройка погодных частиц
	var wp: CPUParticles2D = field_fsm.particles_weather

	match current_weather:
		Weather.CLEAR:
			field_fsm.weather_speed_mod = 1.0
			wp.emitting = false

		Weather.RAIN:
			field_fsm.weather_speed_mod = 1.20 # +20% к росту
			wp.emitting = true
			wp.amount = 80
			wp.color = Color("5fcde4")
			wp.direction = Vector2(-0.2, 1.0)
			wp.initial_velocity_min = 250.0
			wp.initial_velocity_max = 350.0
			# Шанс застрять в грязи во время дождя
			if randf() < 0.35 and not field_fsm.is_stuck_in_mud:
				_trigger_mud_stuck()

		Weather.HAIL:
			wp.emitting = true
			wp.amount = 50
			wp.color = Color("cbdbfc")
			wp.direction = Vector2(-0.3, 1.0)
			wp.initial_velocity_min = 350.0
			wp.initial_velocity_max = 450.0
			# Если нет навеса — техника и люди получают урон (-30% к скорости)
			if GameManager.canopy_count == 0:
				field_fsm.weather_speed_mod = 0.70
				print("[EventManager] 🌨 Град бьет по технике и людям! Скорость -30% (постройте навес!)")
			else:
				field_fsm.weather_speed_mod = 1.0
				print("[EventManager] ☂ Рабочие и техника укрылись под навесом от града!")

		Weather.SNOW:
			field_fsm.weather_speed_mod = 0.70 # -30% к скорости
			wp.emitting = true
			wp.amount = 45
			wp.color = Color("ffffff")
			wp.direction = Vector2(-0.4, 0.6)
			wp.initial_velocity_min = 40.0
			wp.initial_velocity_max = 80.0

		Weather.WIND:
			field_fsm.weather_speed_mod = 0.50 # -50% к скорости сева
			wp.emitting = true
			wp.amount = 35
			wp.color = Color("8ab060")
			wp.direction = Vector2(1.0, 0.1)
			wp.initial_velocity_min = 200.0
			wp.initial_velocity_max = 350.0
			print("[EventManager] 💨 Сильный порывистый ветер затрудняет работу! (-50% скорости)")

		Weather.NIGHT:
			field_fsm.weather_speed_mod = 0.0
			wp.emitting = false
			print("[EventManager] 🌙 Наступила ночь. Рабочие и техника греются у костра.")

	var w_name: String = get_weather_name()
	print("[EventManager] Погода: ", w_name)
	weather_changed.emit(current_weather, w_name)

func _trigger_mud_stuck() -> void:
	if field_fsm != null:
		field_fsm.is_stuck_in_mud = true
		GameManager.is_stuck_in_mud = true
		print("[EventManager] 🌧 ТЕХНИКА ЗАСТРЯЛА В ГРЯЗИ! КОЛЕСА БУКСУЮТ!")

func get_weather_name() -> String:
	match current_weather:
		Weather.CLEAR:
			return "Ясно ☀"
		Weather.RAIN:
			return "Ливень 🌧 (+20% рост, лужи)"
		Weather.HAIL:
			return "Град 🌨 (требуется навес)"
		Weather.SNOW:
			return "Снегопад ❄ (-30% скорость)"
		Weather.WIND:
			return "Штормовой ветер 💨 (-50% сев)"
		Weather.NIGHT:
			return "Ночь 🌙 (отдых у костра)"
	return "Ясно ☀"

# ------------------------------------------------------------------------------
# СЛУЧАЙНЫЕ СОБЫТИЯ
# ------------------------------------------------------------------------------
func _process_events_timer(delta: float) -> void:
	event_check_timer += delta
	if event_check_timer >= event_check_interval:
		event_check_timer = 0.0
		if not is_strike_active and not is_breakdown_active and not GameManager.is_stuck_in_mud:
			_try_trigger_random_event()

func _try_trigger_random_event() -> void:
	if field_fsm == null or current_weather == Weather.NIGHT:
		return

	var roll: float = randf()

	if roll < 0.20:
		# Вороны (не замораживают игру!)
		field_fsm.spawn_crows_event()
		print("[EventManager] 🦅 Стая ворон прилетела на поле!")
	elif roll < 0.35 and field_fsm.current_state == FieldFSM.State.SOWING and not GameManager.has_seeder_tractor:
		trigger_strike()
	elif roll < 0.50:
		trigger_breakdown()

# 1. ЗАБАСТОВКА
func trigger_strike() -> void:
	if GameManager.has_seeder_tractor:
		return
	is_strike_active = true
	strike_timer = 0.0
	if field_fsm != null:
		field_fsm.is_strike_active = true
		if field_fsm.seeder_workers.size() > 0:
			var lead = field_fsm.seeder_workers[0]
			strike_poster.visible = true
			strike_poster.position = Vector2(lead.position.x + 10, lead.position.y - 18)
	print("[EventManager] 🚨 СЕЯТЕЛИ ОБЪЯВИЛИ ЗАБАСТОВКУ!")
	strike_started.emit()

func resolve_strike(by_player: bool = true) -> void:
	if not is_strike_active:
		return
	if by_player:
		GameManager.spend_coins(50)
		GameManager.total_strikes_resolved += 1
	is_strike_active = false
	strike_poster.visible = false
	if field_fsm != null:
		field_fsm.is_strike_active = false
	print("[EventManager] Забастовка урегулирована!")
	strike_resolved.emit()

func _process_active_strike(delta: float) -> void:
	if not is_strike_active:
		return
	strike_timer += delta
	if strike_timer >= STRIKE_AUTO_RESOLVE_TIME:
		resolve_strike(false)

# 2. ПОЛОМКА ТЕХНИКИ ИЛИ ВЫТАСКИВАНИЕ ИЗ ГРЯЗИ
func trigger_breakdown() -> void:
	if is_breakdown_active:
		return
	is_breakdown_active = true
	GameManager.is_broken_down = true
	if field_fsm != null:
		field_fsm.is_breakdown_active = true
		breakdown_started.emit(field_fsm.vehicle_sprite.position)
	print("[EventManager] ⚙ ТЕХНИКА СЛОМАЛАСЬ! ВАЛИТ ЧЕРНЫЙ ДЫМ И ПЛАМЯ!")

func call_mechanic() -> void:
	if is_repairing:
		return
	if not is_breakdown_active and not GameManager.is_stuck_in_mud:
		return

	if GameManager.spend_coins(30):
		is_repairing = true
		repair_timer = 0.0
		repair_pickup.visible = true
		repair_pickup.position = Vector2(-70.0, FieldFSM.GROUND_Y - 32.0)
		print("[EventManager] 🚑 Вызвана аварийная служба ремонта!")

func _process_repair_service(delta: float) -> void:
	if not is_repairing or field_fsm == null:
		return
	repair_timer += delta

	# Движение пикапа к сломанной/застрявшей технике
	var target_x: float = field_fsm.vehicle_x - 45.0
	if repair_pickup.position.x < target_x:
		repair_pickup.position.x += 160.0 * delta
		repair_pickup.frame = int(repair_timer * 8.0) % 2
	else:
		# Ремонт техники
		repair_pickup.frame = int(repair_timer * 10.0) % 2
		if repair_timer >= 4.0:
			is_repairing = false
			is_breakdown_active = false
			GameManager.is_broken_down = false
			field_fsm.is_breakdown_active = false
			field_fsm.is_stuck_in_mud = false
			GameManager.is_stuck_in_mud = false
			GameManager.total_repairs_done += 1

			# Пикап уезжает вперед
			var tw: Tween = create_tween()
			tw.tween_property(repair_pickup, "position:x", field_fsm.screen_width + 80.0, 1.4)
			tw.tween_callback(func(): repair_pickup.visible = false)
			print("[EventManager] Техника полностью отремонтирована и возвращена в строй!")
			breakdown_resolved.emit()

func reset_all_events() -> void:
	is_strike_active = false
	strike_timer = 0.0
	if strike_poster != null:
		strike_poster.visible = false
	is_breakdown_active = false
	is_repairing = false
	repair_timer = 0.0
	if repair_pickup != null:
		repair_pickup.visible = false
	current_weather = Weather.CLEAR
	weather_timer = 0.0
	weather_changed.emit(Weather.CLEAR, "Ясно ☀️")

