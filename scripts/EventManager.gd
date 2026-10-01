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
signal season_changed(new_season: GameManager.Season, season_name: String)
signal strike_started
signal strike_resolved
signal breakdown_started(vehicle_pos: Vector2)
signal breakdown_resolved
signal police_arrived
signal police_resolved
signal repair_progress(status: String)

@export var field_fsm: FieldFSM

# Сезоны
var season_timer: float = 0.0
var season_duration: float = 90.0

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

# Полиция
var is_police_active: bool = false
var police_timer: float = 0.0
const POLICE_AUTO_RESOLVE_TIME: float = 45.0

# Визуальные объекты
var strike_poster: Sprite2D
var strike_button: Button
var repair_pickup: Sprite2D

var police_car: Sprite2D
var police_officer: Sprite2D
var police_btn_fine: Button
var police_btn_bribe: Button

func _ready() -> void:
	_create_crisis_visuals()

func _create_crisis_visuals() -> void:
	var tex_crisis: Texture2D = AssetGenerator.get_texture("crisis_objects.png")
	var tex_pickup: Texture2D = AssetGenerator.get_texture("pickup_repair.png")
	var tex_police_car: Texture2D = AssetGenerator.get_texture("police_car.png")
	var tex_police_officer: Texture2D = AssetGenerator.get_texture("police_officer.png")

	# Плакат забастовки
	strike_poster = Sprite2D.new()
	strike_poster.texture = tex_crisis
	strike_poster.region_enabled = true
	strike_poster.region_rect = Rect2(0, 0, 16, 16)
	strike_poster.scale = Vector2(2.0, 2.0)
	strike_poster.centered = false
	strike_poster.visible = false

	# Кнопка урегулирования забастовки прямо на поле над рабочими
	strike_button = Button.new()
	strike_button.text = "🚨 Премия (50 🪙)"
	strike_button.add_theme_color_override("font_color", Color("fbf236"))
	strike_button.custom_minimum_size = Vector2(130, 26)
	strike_button.visible = false
	strike_button.pressed.connect(func():
		resolve_strike(true)
	)

	# Пикап аварийной службы (ставим centered = false, чтобы колеса ехали ровно по земле)
	repair_pickup = Sprite2D.new()
	repair_pickup.texture = tex_pickup
	repair_pickup.hframes = 2
	repair_pickup.scale = Vector2(2.0, 2.0)
	repair_pickup.centered = false
	repair_pickup.visible = false

	# Патрульная машина полиции
	police_car = Sprite2D.new()
	police_car.texture = tex_police_car
	police_car.hframes = 4
	police_car.scale = Vector2(2.0, 2.0)
	police_car.centered = false
	police_car.visible = false

	# Офицер полиции
	police_officer = Sprite2D.new()
	police_officer.texture = tex_police_officer
	police_officer.hframes = 4
	police_officer.scale = Vector2(2.0, 2.0)
	police_officer.centered = false
	police_officer.visible = false

	# Кнопки взаимодействия с полицией на поле
	police_btn_fine = Button.new()
	police_btn_fine.text = "📋 Штраф (80 🪙)"
	police_btn_fine.add_theme_color_override("font_color", Color("cbdbfc"))
	police_btn_fine.custom_minimum_size = Vector2(120, 26)
	police_btn_fine.visible = false
	police_btn_fine.pressed.connect(func():
		resolve_police_fine(false)
	)

	police_btn_bribe = Button.new()
	police_btn_bribe.text = "🤝 Взятка (10%)"
	police_btn_bribe.add_theme_color_override("font_color", Color("fbf236"))
	police_btn_bribe.custom_minimum_size = Vector2(120, 26)
	police_btn_bribe.visible = false
	police_btn_bribe.pressed.connect(func():
		resolve_police_bribe()
	)

	if field_fsm != null:
		field_fsm.add_child(strike_poster)
		field_fsm.add_child(strike_button)
		field_fsm.add_child(repair_pickup)
		field_fsm.add_child(police_car)
		field_fsm.add_child(police_officer)
		field_fsm.add_child(police_btn_fine)
		field_fsm.add_child(police_btn_bribe)
	else:
		add_child(strike_poster)
		add_child(strike_button)
		add_child(repair_pickup)
		add_child(police_car)
		add_child(police_officer)
		add_child(police_btn_fine)
		add_child(police_btn_bribe)

func _process(delta: float) -> void:
	_process_season(delta)
	_process_weather(delta)
	_process_events_timer(delta)
	_process_active_strike(delta)
	_process_repair_service(delta)
	_process_police(delta)
	GameManager.update_volunteers(delta)

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
			field_fsm.weather_speed_mod = 0.55 # -45% к скорости техники и сева
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
			# Если нет навеса — техника и люди получают урон (-55% к скорости)
			if GameManager.canopy_count == 0:
				field_fsm.weather_speed_mod = 0.45
				print("[EventManager] 🌨 Град бьет по технике и людям! Скорость -55% (постройте навес!)")
			else:
				field_fsm.weather_speed_mod = 0.85
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
# СЕЗОНЫ ГОДА (Весна, Лето, Осень, Зима)
# ------------------------------------------------------------------------------
func _process_season(delta: float) -> void:
	season_timer += delta
	if season_timer >= season_duration:
		season_timer = 0.0
		var next_val = (int(GameManager.current_season) + 1) % 4
		GameManager.current_season = next_val as GameManager.Season
		var s_name = GameManager.get_season_name()
		print("[EventManager] 🗓 СМЕНА СЕЗОНА: ", s_name)
		if field_fsm != null:
			field_fsm.set_season(GameManager.current_season)
		season_changed.emit(GameManager.current_season, s_name)

# ------------------------------------------------------------------------------
# СЛУЧАЙНЫЕ СОБЫТИЯ
# ------------------------------------------------------------------------------
func _process_events_timer(delta: float) -> void:
	event_check_timer += delta
	if event_check_timer >= event_check_interval:
		event_check_timer = 0.0
		if not is_strike_active and not is_breakdown_active and not is_police_active and not GameManager.is_stuck_in_mud:
			_try_trigger_random_event()

func can_breakdown_occur() -> bool:
	if field_fsm == null:
		return false
	match field_fsm.current_state:
		FieldFSM.State.PLOWING:
			return true
		FieldFSM.State.SOWING:
			# Только если на поле работает трактор с сеялкой! Сеятели-люди не ломаются!
			return GameManager.has_seeder_tractor
		FieldFSM.State.HARVESTING:
			return true
		FieldFSM.State.HAULING:
			return true
		_:
			return false

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
	elif roll < 0.50 and can_breakdown_occur():
		trigger_breakdown()
	elif roll < 0.65 and can_breakdown_occur() and not is_police_active:
		trigger_police()

# 1. ЗАБАСТОВКА
func trigger_strike() -> void:
	if GameManager.has_seeder_tractor:
		return
	is_strike_active = true
	GameManager.is_strike_active = true
	strike_timer = 0.0
	if field_fsm != null:
		field_fsm.is_strike_active = true
		if field_fsm.seeder_workers.size() > 0:
			var lead = field_fsm.seeder_workers[0]
			if strike_poster != null:
				strike_poster.visible = true
				strike_poster.position = Vector2(lead.position.x + 10, lead.position.y - 18)
			if strike_button != null:
				strike_button.visible = true
				strike_button.position = Vector2(lead.position.x - 20, FieldFSM.GROUND_Y - 56.0)
	print("[EventManager] 🚨 СЕЯТЕЛИ ОБЪЯВИЛИ ЗАБАСТОВКУ!")
	strike_started.emit()

func resolve_strike(by_player: bool = true) -> void:
	if not is_strike_active:
		return
	if by_player:
		if not GameManager.spend_coins(50):
			print("[EventManager] Недостаточно монет для выплаты премии сеятелям!")
			return
		GameManager.total_strikes_resolved += 1
	is_strike_active = false
	GameManager.is_strike_active = false
	if strike_poster != null:
		strike_poster.visible = false
	if strike_button != null:
		strike_button.visible = false
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
	if is_breakdown_active or not can_breakdown_occur():
		return
	is_breakdown_active = true
	GameManager.is_broken_down = true
	if field_fsm != null:
		field_fsm.is_breakdown_active = true
		var vpos = field_fsm.vehicle_sprite.position if field_fsm.vehicle_sprite != null else Vector2.ZERO
		breakdown_started.emit(vpos)
	print("[EventManager] ⚙ ТЕХНИКА СЛОМАЛАСЬ! ВАЛИТ ЧЕРНЫЙ ДЫМ И ПЛАМЯ!")

func call_mechanic() -> void:
	if is_repairing or GameManager.is_repairing:
		return
	if not is_breakdown_active and not GameManager.is_stuck_in_mud:
		return

	if GameManager.spend_coins(30):
		is_repairing = true
		GameManager.is_repairing = true
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
	repair_pickup.position.y = FieldFSM.GROUND_Y - 32.0
	if repair_pickup.position.x < target_x:
		repair_pickup.position.x += 160.0 * delta
		repair_pickup.frame = int(repair_timer * 8.0) % 2
	else:
		# Ремонт техники
		repair_pickup.frame = int(repair_timer * 10.0) % 2
		if repair_timer >= 4.0:
			is_repairing = false
			GameManager.is_repairing = false
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

# ------------------------------------------------------------------------------
# 3. СОБЫТИЕ ПОЛИЦИЯ (ПРОВЕРКА ТЕХНИКИ, ШТРАФ ИЛИ ВЗЯТКА 10%)
# ------------------------------------------------------------------------------
func trigger_police() -> void:
	if is_police_active or field_fsm == null:
		return
	is_police_active = true
	GameManager.is_police_active = true
	police_timer = 0.0

	var target_x: float = clamp(field_fsm.vehicle_x + 60.0, 180.0, field_fsm.screen_width - 180.0)
	if police_car != null:
		police_car.visible = true
		police_car.position = Vector2(-70.0, FieldFSM.GROUND_Y - 32.0)
	if police_officer != null:
		police_officer.visible = false
		police_officer.position = Vector2(target_x + 36.0, FieldFSM.GROUND_Y - 32.0)

	var fine_cost: int = 40 if GameManager.has_guard_dog else 80
	var bribe_amount: int = max(10, int(GameManager.coins * 0.10))

	if police_btn_fine != null:
		police_btn_fine.text = "📋 Штраф (%d 🪙)" % fine_cost
		police_btn_fine.visible = true
		police_btn_fine.position = Vector2(target_x - 30.0, FieldFSM.GROUND_Y - 60.0)
	if police_btn_bribe != null:
		police_btn_bribe.text = "🤝 Взятка (%d 🪙)" % bribe_amount
		police_btn_bribe.visible = true
		police_btn_bribe.position = Vector2(target_x + 95.0, FieldFSM.GROUND_Y - 60.0)

	print("[EventManager] 🚨 ПОЛИЦИЯ ПРИБЫЛА НА ФЕРМУ! Проверка техники: штраф %d 🪙 или взятка %d 🪙" % [fine_cost, bribe_amount])
	police_arrived.emit()

func _process_police(delta: float) -> void:
	if not is_police_active or field_fsm == null or police_car == null:
		return
	police_timer += delta

	# Стробоскоп мигалки на крыше
	police_car.frame = int(police_timer * 8.0) % 4

	var target_x: float = clamp(field_fsm.vehicle_x + 60.0, 180.0, field_fsm.screen_width - 180.0)
	if police_car.position.x < target_x:
		police_car.position.x += 180.0 * delta
		if police_officer != null:
			police_officer.visible = false
	else:
		police_car.position.x = target_x
		if police_officer != null:
			police_officer.visible = true
			police_officer.position = Vector2(target_x + 36.0, FieldFSM.GROUND_Y - 32.0)
			police_officer.frame = int(police_timer * 4.0) % 4

	# Автоматическое урегулирование по истечению времени (официальный штраф)
	if police_timer >= POLICE_AUTO_RESOLVE_TIME:
		resolve_police_fine(true)

func resolve_police_fine(auto: bool = false) -> void:
	if not is_police_active:
		return
	var fine_cost: int = 40 if GameManager.has_guard_dog else 80
	GameManager.spend_coins(fine_cost)
	GameManager.total_fines_paid += fine_cost
	_dismiss_police()
	if auto:
		print("[EventManager] 📋 Время истекло! Списан официальный штраф полиции: %d 🪙" % fine_cost)
	else:
		print("[EventManager] 📋 Оплачен официальный штраф полиции: %d 🪙" % fine_cost)
	police_resolved.emit()

func resolve_police_bribe() -> void:
	if not is_police_active:
		return
	var bribe_amount: int = max(10, int(GameManager.coins * 0.10))
	GameManager.spend_coins(bribe_amount)
	_dismiss_police()
	print("[EventManager] 🤝 Инспектор принял 'пожертвование' 10%% (%d 🪙) и уехал довольным!" % bribe_amount)
	police_resolved.emit()

func _dismiss_police() -> void:
	is_police_active = false
	GameManager.is_police_active = false
	if police_btn_fine != null:
		police_btn_fine.visible = false
	if police_btn_bribe != null:
		police_btn_bribe.visible = false
	if police_officer != null:
		police_officer.visible = false
	if police_car != null and field_fsm != null:
		var tw: Tween = create_tween()
		tw.tween_property(police_car, "position:x", field_fsm.screen_width + 80.0, 1.4)
		tw.tween_callback(func(): police_car.visible = false)

func reset_all_events() -> void:
	is_strike_active = false
	GameManager.is_strike_active = false
	strike_timer = 0.0
	if strike_poster != null:
		strike_poster.visible = false
	if strike_button != null:
		strike_button.visible = false
	is_breakdown_active = false
	GameManager.is_broken_down = false
	is_repairing = false
	GameManager.is_repairing = false
	repair_timer = 0.0
	if repair_pickup != null:
		repair_pickup.visible = false

	# Сброс полиции
	is_police_active = false
	GameManager.is_police_active = false
	police_timer = 0.0
	if police_btn_fine != null:
		police_btn_fine.visible = false
	if police_btn_bribe != null:
		police_btn_bribe.visible = false
	if police_officer != null:
		police_officer.visible = false
	if police_car != null:
		police_car.visible = false

	current_weather = Weather.CLEAR
	weather_timer = 0.0
	weather_changed.emit(Weather.CLEAR, "Ясно ☀️")

