class_name FieldFSM
extends Node2D

const GameManager = preload("res://scripts/GameManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const SettingsManager = preload("res://scripts/SettingsManager.gd")
const AssetGenerator = preload("res://tools/AssetGenerator.gd")
const WindowManager = preload("res://scripts/WindowManager.gd")

enum State {
	IDLE,
	PLOWING,    # 1. Трактор пашет сухую землю в борозды
	SOWING,     # 2. Сеятели/сеялка разбрасывают семена
	WATERING,   # 3. Цистерна поливает землю
	GROWING,    # 4. Рост культур, покачивание колосьев
	HARVESTING, # 5. Комбайн срезает урожай, оставляя стерню
	HAULING     # 6. Грузовик забирает зерно и начисляет монеты
}

# Сигналы машины состояний
signal state_changed(new_state: State)
signal harvest_completed(coins_earned: int)
signal event_strike_started
signal event_breakdown_started(vehicle_pos: Vector2)
signal event_crows_arrived

# Текущее состояние
var current_state: State = State.IDLE
var state_timer: float = 0.0

# Размеры поля и координатная сетка
var screen_width: int = 1920
const GROUND_Y: float = 84.0      # Поверхность земли для колес и ног
const TILE_SIZE: int = 32         # 16 px * 2x масштаб
var segment_count: int = 60
var soil_segments: Array[int] = [] # Состояния тайлов: 0=сухая, 1=борозды, 2=влажная, 3=стерня
var crop_stages: Array[int] = []   # Стадии растений: -1=нет, 0..3

# Текстуры
var tex_soil: Texture2D
var tex_crops: Texture2D
var tex_tractor: Texture2D
var tex_tractor_v2: Texture2D
var tex_tractor_seeder: Texture2D
var tex_worker: Texture2D
var tex_tanker: Texture2D
var tex_harvester: Texture2D
var tex_harvester_v2: Texture2D
var tex_truck: Texture2D
var tex_truck_v2: Texture2D
var tex_crisis: Texture2D
var tex_pickup: Texture2D
var tex_smoke_fire: Texture2D
var tex_campfire: Texture2D
var tex_canopy: Texture2D
var tex_mud_splash: Texture2D
var tex_workers_rest: Texture2D
var tex_windmill: Texture2D
var tex_barn: Texture2D
var tex_decorations: Texture2D
var tex_weather_parts: Texture2D
var tex_seasons_decor: Texture2D
var tex_greenhouse: Texture2D
var tex_greenhouse_crops: Texture2D
var tex_greenhouse_worker: Texture2D
var tex_volunteer: Texture2D

# Объекты сцены
var vehicle_sprite: Sprite2D
var seeder_workers: Array[Sprite2D] = []
var smoke_fire_sprite: Sprite2D
var mud_splash_sprite: Sprite2D
var campfire_sprite: Sprite2D
var resting_workers: Array[Sprite2D] = []
var active_crows: Array[Sprite2D] = []
var greenhouse_workers: Array[Sprite2D] = []
var volunteer_workers: Array[Sprite2D] = []

# Сезоны, теплицы и волонтёры
var current_season: int = GameManager.Season.SPRING
var greenhouse_timer: float = 0.0

# Частицы
var particles_soil: CPUParticles2D
var particles_water: CPUParticles2D
var particles_seed: CPUParticles2D
var particles_weather: CPUParticles2D
var floating_label: Label

# Позиции техники и анимации
var vehicle_x: float = -100.0
var vehicle_speed: float = 120.0
var truck_fill_stage: int = 0
var anim_timer: float = 0.0

# Флаги кризисных событий
var is_strike_active: bool = false
var is_breakdown_active: bool = false
var is_stuck_in_mud: bool = false
var is_night_active: bool = false

# Погода (управляется EventManager)
var current_weather_id: int = 0 # 0=clear, 1=rain, 2=hail, 3=snow, 4=wind, 5=night
var weather_speed_mod: float = 1.0

func _ready() -> void:
	_load_textures()
	_update_screen_bounds()
	_create_particles()
	_create_visual_nodes()
	
	# Восстанавливаем сохраненное состояние или запускаем новый цикл
	if not restore_field_state():
		change_state(State.PLOWING)

func _update_screen_bounds() -> void:
	var screen_idx: int = SettingsManager.get_screen_index()
	if screen_idx == WindowManager.SCREEN_ALL_MONITORS:
		var total_w: int = 0
		var screen_cnt: int = DisplayServer.get_screen_count()
		for i in range(screen_cnt):
			total_w += DisplayServer.screen_get_usable_rect(i).size.x
		screen_width = max(total_w, 1920)
	else:
		var screen_cnt: int = DisplayServer.get_screen_count()
		if screen_idx < 0 or screen_idx >= screen_cnt:
			screen_idx = DisplayServer.get_primary_screen()
		var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
		screen_width = max(rect.size.x, 800)

	segment_count = int(ceil(float(screen_width) / float(TILE_SIZE))) + 1
	if soil_segments.size() != segment_count:
		var old_size: int = soil_segments.size()
		soil_segments.resize(segment_count)
		for i in range(old_size, segment_count):
			soil_segments[i] = 0
	if crop_stages.size() != segment_count:
		var old_size: int = crop_stages.size()
		crop_stages.resize(segment_count)
		for i in range(old_size, segment_count):
			crop_stages[i] = -1

func _load_textures() -> void:
	tex_soil = AssetGenerator.get_texture("soil_tiles.png")
	tex_crops = AssetGenerator.get_texture("crops_sheet.png")
	tex_tractor = AssetGenerator.get_texture("tractor.png")
	tex_tractor_v2 = AssetGenerator.get_texture("tractor_v2.png")
	tex_tractor_seeder = AssetGenerator.get_texture("tractor_seeder.png")
	tex_worker = AssetGenerator.get_texture("worker_sower.png")
	tex_tanker = AssetGenerator.get_texture("water_tanker.png")
	tex_harvester = AssetGenerator.get_texture("harvester.png")
	tex_harvester_v2 = AssetGenerator.get_texture("harvester_v2.png")
	tex_truck = AssetGenerator.get_texture("truck_sheet.png")
	tex_truck_v2 = AssetGenerator.get_texture("truck_v2.png")
	tex_crisis = AssetGenerator.get_texture("crisis_objects.png")
	tex_pickup = AssetGenerator.get_texture("pickup_repair.png")
	tex_smoke_fire = AssetGenerator.get_texture("smoke_fire_sheet.png")
	tex_campfire = AssetGenerator.get_texture("campfire.png")
	tex_canopy = AssetGenerator.get_texture("canopy.png")
	tex_mud_splash = AssetGenerator.get_texture("mud_splash.png")
	tex_workers_rest = AssetGenerator.get_texture("workers_rest.png")
	tex_windmill = AssetGenerator.get_texture("windmill.png")
	tex_barn = AssetGenerator.get_texture("barn.png")
	tex_decorations = AssetGenerator.get_texture("decorations.png")
	tex_weather_parts = AssetGenerator.get_texture("weather_particles.png")
	tex_seasons_decor = AssetGenerator.get_texture("seasons_decorations.png")
	tex_greenhouse = AssetGenerator.get_texture("greenhouse.png")
	tex_greenhouse_crops = AssetGenerator.get_texture("greenhouse_crops.png")
	tex_greenhouse_worker = AssetGenerator.get_texture("greenhouse_worker.png")
	tex_volunteer = AssetGenerator.get_texture("volunteer.png")

func _create_particles() -> void:
	# Частицы земли / пыли
	particles_soil = CPUParticles2D.new()
	particles_soil.emitting = false
	particles_soil.amount = 16
	particles_soil.lifetime = 0.5
	particles_soil.color = Color("8f563b")
	particles_soil.direction = Vector2(-1, -0.5)
	particles_soil.spread = 35.0
	particles_soil.gravity = Vector2(0, 180)
	particles_soil.initial_velocity_min = 30.0
	particles_soil.initial_velocity_max = 70.0
	add_child(particles_soil)

	# Частицы полива
	particles_water = CPUParticles2D.new()
	particles_water.emitting = false
	particles_water.amount = 32
	particles_water.lifetime = 0.4
	particles_water.color = Color("5fcde4")
	particles_water.direction = Vector2(-1, 0.8)
	particles_water.spread = 40.0
	particles_water.gravity = Vector2(0, 150)
	particles_water.initial_velocity_min = 40.0
	particles_water.initial_velocity_max = 90.0
	add_child(particles_water)

	# Частицы семян
	particles_seed = CPUParticles2D.new()
	particles_seed.emitting = false
	particles_seed.amount = 12
	particles_seed.lifetime = 0.4
	particles_seed.color = Color("fbf236")
	particles_seed.direction = Vector2(0.5, 1.0)
	particles_seed.spread = 30.0
	particles_seed.gravity = Vector2(0, 160)
	particles_seed.initial_velocity_min = 20.0
	particles_seed.initial_velocity_max = 50.0
	add_child(particles_seed)

	# Погодные частицы (снег, град, дождь, ветер)
	particles_weather = CPUParticles2D.new()
	particles_weather.emitting = false
	particles_weather.amount = 64
	particles_weather.lifetime = 1.2
	particles_weather.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles_weather.emission_rect_extents = Vector2(1920, 10)
	particles_weather.position = Vector2(960, 0)
	add_child(particles_weather)

func _create_visual_nodes() -> void:
	# Основной спрайт техники
	vehicle_sprite = Sprite2D.new()
	vehicle_sprite.scale = Vector2(2.0, 2.0)
	vehicle_sprite.centered = false
	add_child(vehicle_sprite)

	# Спрайт брызг грязи при буксовании
	mud_splash_sprite = Sprite2D.new()
	mud_splash_sprite.texture = tex_mud_splash
	mud_splash_sprite.hframes = 4
	mud_splash_sprite.scale = Vector2(2.0, 2.0)
	mud_splash_sprite.centered = false
	mud_splash_sprite.visible = false
	add_child(mud_splash_sprite)

	# Спрайт дыма и огня поломки (4 кадра 16x32)
	smoke_fire_sprite = Sprite2D.new()
	smoke_fire_sprite.texture = tex_smoke_fire
	smoke_fire_sprite.hframes = 4
	smoke_fire_sprite.scale = Vector2(2.0, 2.0)
	smoke_fire_sprite.centered = false
	smoke_fire_sprite.visible = false
	add_child(smoke_fire_sprite)

	# Спрайт костра для ночи
	campfire_sprite = Sprite2D.new()
	campfire_sprite.texture = tex_campfire
	campfire_sprite.hframes = 4
	campfire_sprite.scale = Vector2(2.0, 2.0)
	campfire_sprite.centered = false
	campfire_sprite.visible = false
	add_child(campfire_sprite)

	# 3 рабочих-сеятеля
	for i in range(3):
		var w: Sprite2D = Sprite2D.new()
		w.texture = tex_worker
		w.hframes = 4
		w.scale = Vector2(2.0, 2.0)
		w.centered = false
		w.visible = false
		add_child(w)
		seeder_workers.append(w)

	# 3 рабочих на отдыхе (ночь / навес)
	for i in range(3):
		var rw: Sprite2D = Sprite2D.new()
		rw.texture = tex_workers_rest
		rw.hframes = 4
		rw.scale = Vector2(2.0, 2.0)
		rw.centered = false
		rw.visible = false
		add_child(rw)
		resting_workers.append(rw)

	# Стая ворон (5 птиц)
	for i in range(5):
		var crow: Sprite2D = Sprite2D.new()
		crow.texture = tex_crisis
		crow.region_enabled = true
		crow.region_rect = Rect2(48, 0, 16, 16) # сидящая ворона
		crow.scale = Vector2(2.0, 2.0)
		crow.centered = false
		crow.visible = false
		add_child(crow)
		active_crows.append(crow)

	# Работники теплиц (до 2 работников)
	for i in range(2):
		var gw: Sprite2D = Sprite2D.new()
		gw.texture = tex_greenhouse_worker
		gw.hframes = 4
		gw.scale = Vector2(2.0, 2.0)
		gw.centered = false
		gw.visible = false
		add_child(gw)
		greenhouse_workers.append(gw)

	# Волонтёры (2 добровольца в ярких жилетах)
	for i in range(2):
		var v: Sprite2D = Sprite2D.new()
		v.texture = tex_volunteer
		v.hframes = 4
		v.scale = Vector2(2.0, 2.0)
		v.centered = false
		v.visible = false
		add_child(v)
		volunteer_workers.append(v)

	# Всплывающий лейбл начисления денег
	floating_label = Label.new()
	floating_label.visible = false
	floating_label.add_theme_color_override("font_color", Color("fbf236"))
	floating_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	floating_label.add_theme_constant_override("shadow_offset_x", 1)
	floating_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(floating_label)

func _process(delta: float) -> void:
	anim_timer += delta
	_update_crows_interaction(delta)
	_update_greenhouses(delta)
	_update_volunteers_visuals(delta)
	_update_fsm(delta)
	queue_redraw()

func set_season(s: int) -> void:
	current_season = s
	queue_redraw()

func _update_greenhouses(delta: float) -> void:
	if GameManager.greenhouse_count <= 0:
		for gw in greenhouse_workers:
			gw.visible = false
		return

	var gh_data: Dictionary = GameManager.get_current_greenhouse_data()
	var growth_time: float = float(gh_data.get("growth_time", 25.0))
	var speed_mod: float = 1.70 if GameManager.is_volunteers_active else 1.0
	greenhouse_timer += delta * speed_mod

	if greenhouse_timer >= growth_time:
		greenhouse_timer = 0.0
		var earned: int = GameManager.harvest_greenhouse()
		if earned > 0:
			_show_floating_coins(earned, " (%s)" % gh_data.get("name", "Теплица"))

	# Анимация работников теплиц
	for i in range(greenhouse_workers.size()):
		var gw: Sprite2D = greenhouse_workers[i]
		if i < GameManager.greenhouse_count:
			gw.visible = true
			var gh_x: float = 110.0 if i == 0 else (screen_width - 240.0)
			gw.position = Vector2(gh_x + 22.0, GROUND_Y - 32.0)
			gw.frame = int(anim_timer * 4.0 + i) % 4
		else:
			gw.visible = false

func _update_volunteers_visuals(_delta: float) -> void:
	if not GameManager.is_volunteers_active:
		for v in volunteer_workers:
			v.visible = false
		return

	for i in range(volunteer_workers.size()):
		var v: Sprite2D = volunteer_workers[i]
		v.visible = true
		var wander_center: float = (screen_width * 0.35) if i == 0 else (screen_width * 0.70)
		var wander_offset: float = sin(anim_timer * 1.5 + i * 2.0) * 120.0
		v.position = Vector2(wander_center + wander_offset, GROUND_Y - 32.0)
		v.flip_h = cos(anim_timer * 1.5 + i * 2.0) < 0
		v.frame = int(anim_timer * 6.0 + i) % 4

func _update_fsm(delta: float) -> void:
	# 1. НОЧЬ: вся работа останавливается, сеятели и техника собираются у костра
	if is_night_active:
		_process_night_camp(delta)
		return
	else:
		campfire_sprite.visible = false
		for rw in resting_workers:
			rw.visible = false

	# 2. ПОЛОМКА ТЕХНИКИ: идет черный дым и пламя (только когда на поле работает техника)
	var has_active_vehicle: bool = (current_state != State.GROWING and current_state != State.WATERING)
	if current_state == State.SOWING and not GameManager.has_seeder_tractor:
		has_active_vehicle = false

	if is_breakdown_active and has_active_vehicle:
		smoke_fire_sprite.visible = true
		smoke_fire_sprite.position = Vector2(vehicle_x + 12.0, GROUND_Y - 56.0)
		smoke_fire_sprite.frame = int(anim_timer * 8.0) % 4
		return
	else:
		smoke_fire_sprite.visible = false

	# 3. БУКСОВАНИЕ В ГРЯЗИ ВО ВРЕМЯ ДОЖДЯ
	if is_stuck_in_mud:
		mud_splash_sprite.visible = true
		mud_splash_sprite.position = Vector2(vehicle_x - 16.0, GROUND_Y - 26.0)
		mud_splash_sprite.frame = int(anim_timer * 10.0) % 4
		# Колеса техники крутятся на месте
		return
	else:
		mud_splash_sprite.visible = false

	# 4. ЗАБАСТОВКА СЕЯТЕЛЕЙ
	if is_strike_active:
		return

	# Расход бензина работающей техникой
	if has_active_vehicle:
		GameManager.consume_fuel(delta * 0.75)

	# Коэффициенты скорости: топливо, износ, волонтёры
	var fuel_speed_mod: float = 1.0 if GameManager.fuel_level > 0.0 else 0.25
	var avg_cond: float = GameManager.get_machinery_average_condition()
	var durability_speed_mod: float = 1.0
	if avg_cond < 30.0:
		durability_speed_mod = 0.65
	elif avg_cond < 60.0:
		durability_speed_mod = 0.85

	var volunteer_speed_mod: float = 1.70 if GameManager.is_volunteers_active else 1.0

	# Стандартное движение FSM
	var effective_speed: float = vehicle_speed * GameManager.speed_multiplier * weather_speed_mod * fuel_speed_mod * durability_speed_mod * volunteer_speed_mod

	match current_state:
		State.PLOWING:
			_process_plowing(delta, effective_speed)
		State.SOWING:
			_process_sowing(delta, effective_speed)
		State.WATERING:
			_process_watering(delta, effective_speed)
		State.GROWING:
			_process_growing(delta)
		State.HARVESTING:
			_process_harvesting(delta, effective_speed)
		State.HAULING:
			_process_hauling(delta, effective_speed)

# ------------------------------------------------------------------------------
# НОЧНОЙ ЛАГЕРЬ У КОСТРА
# ------------------------------------------------------------------------------
func _process_night_camp(_delta: float) -> void:
	campfire_sprite.visible = true
	var camp_x: float = clamp(vehicle_x + 40.0, 160.0, screen_width - 200.0)
	campfire_sprite.position = Vector2(camp_x, GROUND_Y - 28.0)
	campfire_sprite.frame = int(anim_timer * 6.0) % 4

	# Сеятели сидят у костра
	for i in range(resting_workers.size()):
		var rw: Sprite2D = resting_workers[i]
		rw.visible = true
		var offset_dir: float = -32.0 if i == 0 else (28.0 + (i - 1) * 24.0)
		rw.position = Vector2(camp_x + offset_dir, GROUND_Y - 30.0)
		rw.frame = i % 4

	# Скрываем идущих рабочих
	for w in seeder_workers:
		w.visible = false

func set_weather(w_id: int) -> void:
	current_weather_id = w_id
	is_night_active = (w_id == 5)
	match w_id:
		0: # CLEAR
			weather_speed_mod = 1.0
		1: # RAIN
			weather_speed_mod = 0.55 # -45% скорости техники и людей в дождь
		2: # HAIL
			weather_speed_mod = 0.45 if GameManager.canopy_count == 0 else 0.85
		3: # SNOW
			weather_speed_mod = 0.65
		4: # WIND
			weather_speed_mod = 0.60
		5: # NIGHT
			weather_speed_mod = 0.0

# ------------------------------------------------------------------------------
# ВЗАИМОДЕЙСТВИЕ С ВОРОНАМИ (ОНИ ПРИЛЕТАЮТ СВЕРХУ, ПУГАЮТСЯ СЕЯТЕЛЕЙ И УЛЕТАЮТ)
# ------------------------------------------------------------------------------
func spawn_crows_event() -> void:
	for i in range(active_crows.size()):
		var crow: Sprite2D = active_crows[i]
		
		# Завершаем любой предыдущий твин
		if crow.has_meta("active_tween"):
			var prev_tw = crow.get_meta("active_tween")
			if prev_tw != null and prev_tw.is_valid():
				prev_tw.kill()

		crow.visible = true
		crow.set_meta("flying", true)
		crow.set_meta("landing", true)

		# Целевая точка приземления на поле
		var target_x: float = randf_range(140.0, screen_width - 140.0)
		var target_y: float = GROUND_Y - 26.0

		# Стартовая точка прилета в небе (сверху за пределами экрана)
		var fly_from_left: bool = (randf() > 0.5)
		var start_x: float = target_x - randf_range(160.0, 260.0) if fly_from_left else target_x + randf_range(160.0, 260.0)
		var start_y: float = -45.0 - randf_range(0.0, 30.0)
		crow.position = Vector2(start_x, start_y)
		crow.region_rect = Rect2(16, 0, 16, 16) # полет (крылья вверх)
		crow.flip_h = not fly_from_left

		# Твин плавного прилета птицы на поле (стаей с небольшой задержкой)
		var flight_duration: float = randf_range(1.2, 1.6)
		var delay: float = i * 0.22
		
		var tw: Tween = create_tween()
		crow.set_meta("active_tween", tw)
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(crow, "position", Vector2(target_x, target_y), flight_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func(c: Sprite2D = crow):
			c.set_meta("flying", false)
			c.set_meta("landing", false)
			c.region_rect = Rect2(48, 0, 16, 16) # села на землю
		)

func _update_crows_interaction(_delta: float) -> void:
	# Собираем все текущие источники опасности (координаты X)
	var danger_sources: Array[float] = []

	# 1. Техника (трактор, комбайн, грузовик), если она на поле
	if vehicle_sprite != null and vehicle_sprite.visible and vehicle_x > -50.0 and vehicle_x < screen_width + 50.0:
		danger_sources.append(vehicle_x + 20.0)

	# 2. Сеятели (проверяем каждого отдельного рабочего-сеятеля на поле)
	if current_state == State.SOWING and not GameManager.has_seeder_tractor:
		for w in seeder_workers:
			if w != null and w.visible and w.position.x > -40.0 and w.position.x < screen_width + 40.0:
				danger_sources.append(w.position.x + 12.0)

	# 3. Собака охраны
	if GameManager.has_guard_dog and seeder_workers.size() > 0:
		var dog_pos_x: float = seeder_workers[0].position.x if (current_state == State.SOWING and not GameManager.has_seeder_tractor) else screen_width * 0.5
		danger_sources.append(dog_pos_x)

	for i in range(active_crows.size()):
		var crow: Sprite2D = active_crows[i]
		if not crow.visible:
			continue

		var is_flying: bool = crow.has_meta("flying") and bool(crow.get_meta("flying"))

		if is_flying:
			# Анимация махов крыльев в воздухе (кадры 16 и 32)
			var wing_frame: int = 16 if (int(anim_timer * 9.0 + i) % 2 == 0) else 32
			crow.region_rect = Rect2(wing_frame, 0, 16, 16)
			continue

		# Анимация клевания на земле (кадры 48 и 64)
		var ground_frame: int = 48 if (int(anim_timer * 3.5 + i) % 2 == 0) else 64
		crow.region_rect = Rect2(ground_frame, 0, 16, 16)

		# 1. Проверка пугал
		if GameManager.scarecrow_count > 0:
			for s in range(GameManager.scarecrow_count):
				var scarecrow_x: float = (screen_width / float(GameManager.scarecrow_count + 1)) * (s + 1)
				if abs(crow.position.x - scarecrow_x) < 150.0:
					_scare_crow_away(crow, scarecrow_x)
					break

		if crow.has_meta("flying") and bool(crow.get_meta("flying")):
			continue

		# 2. Проверка приближения сеятелей или техники
		for threat_x in danger_sources:
			var dist: float = abs(crow.position.x - threat_x)
			if dist < 120.0:
				_scare_crow_away(crow, threat_x)
				break

func _scare_crow_away(crow: Sprite2D, threat_x: float = -9999.0) -> void:
	var is_flying: bool = crow.has_meta("flying") and bool(crow.get_meta("flying"))
	var is_landing: bool = crow.has_meta("landing") and bool(crow.get_meta("landing"))
	if is_flying and not is_landing:
		return # уже улетает

	if crow.has_meta("active_tween"):
		var prev_tw = crow.get_meta("active_tween")
		if prev_tw != null and prev_tw.is_valid():
			prev_tw.kill()

	crow.set_meta("flying", true)
	crow.set_meta("landing", false)
	crow.region_rect = Rect2(16, 0, 16, 16) # полет
	
	# Улетает в сторону ОТ приближающегося человека/машины
	var fly_dir: float = 1.0
	if threat_x != -9999.0:
		fly_dir = 1.0 if crow.position.x >= threat_x else -1.0
	else:
		fly_dir = 1.0 if randf() > 0.5 else -1.0
		
	crow.flip_h = (fly_dir < 0.0)
	
	var flight_x: float = crow.position.x + fly_dir * randf_range(180.0, 340.0)
	var flight_y: float = -60.0 - randf_range(0.0, 25.0)
	
	var tw: Tween = create_tween()
	crow.set_meta("active_tween", tw)
	tw.tween_property(crow, "position", Vector2(flight_x, flight_y), randf_range(1.1, 1.5)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(c: Sprite2D = crow):
		c.visible = false
		c.set_meta("flying", false)
		c.set_meta("landing", false)
	)

# ------------------------------------------------------------------------------
# 1. PLOWING: Трактор вспахивает землю
# ------------------------------------------------------------------------------
func _start_plowing() -> void:
	vehicle_sprite.visible = true
	if GameManager.has_heavy_tractor:
		vehicle_sprite.texture = tex_tractor_v2
		vehicle_sprite.hframes = 2
		vehicle_sprite.frame = 0
		vehicle_sprite.modulate = Color.WHITE
		vehicle_x = -96.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 40.0)
	else:
		vehicle_sprite.texture = tex_tractor
		vehicle_sprite.hframes = 1
		vehicle_sprite.frame = 0
		vehicle_sprite.modulate = GameManager.tractor_color
		vehicle_x = -70.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
	particles_soil.emitting = true

func _process_plowing(delta: float, speed: float) -> void:
	var plowing_speed: float = speed * (1.6 if GameManager.has_heavy_tractor else 1.0)
	vehicle_x += plowing_speed * delta
	var spr_y: float = GROUND_Y - 40.0 if GameManager.has_heavy_tractor else GROUND_Y - 32.0
	vehicle_sprite.position = Vector2(vehicle_x, spr_y)
	particles_soil.position = Vector2(vehicle_x + 10, GROUND_Y - 4.0)

	if GameManager.has_heavy_tractor:
		vehicle_sprite.frame = int(anim_timer * 6.0) % 2

	var plow_x: float = vehicle_x + (16.0 if GameManager.has_heavy_tractor else 8.0)
	var seg_idx: int = int(plow_x / float(TILE_SIZE))
	for i in range(max(0, seg_idx - 1), min(segment_count, seg_idx + 2)):
		if soil_segments[i] == 0:
			soil_segments[i] = 1

	if vehicle_x > screen_width + 80:
		particles_soil.emitting = false
		change_state(State.SOWING)

# ------------------------------------------------------------------------------
# 2. SOWING: Сев семян
# ------------------------------------------------------------------------------
func _start_sowing() -> void:
	# Закупка партии семян на каждый цикл сева
	var crop_data: Dictionary = GameManager.get_current_crop_data()
	var seed_cost: int = int(crop_data.get("seed_cost", 10))
	if GameManager.spend_coins(seed_cost):
		_show_floating_coins(-seed_cost, " (Семена %s)" % crop_data.get("name", ""))
	else:
		# Если монет не хватает на текущую культуру, переключаемся на базовую пшеницу (5 монет)
		if GameManager.spend_coins(5):
			GameManager.current_crop = "wheat"
			_show_floating_coins(-5, " (Семена Пшеница)")
		else:
			# Если в казне 0 монет - выдается аварийный пакет семян (0 монет) для предотвращения софтлока
			GameManager.current_crop = "wheat"

	if GameManager.has_seeder_tractor:
		vehicle_sprite.visible = true
		vehicle_sprite.texture = tex_tractor_seeder
		vehicle_sprite.hframes = 1
		vehicle_sprite.modulate = GameManager.tractor_color
		vehicle_x = -70.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
		particles_seed.emitting = true
	else:
		vehicle_sprite.visible = false
		for i in range(seeder_workers.size()):
			var w: Sprite2D = seeder_workers[i]
			w.visible = true
			w.flip_h = false
			if w.has_meta("resume_x"):
				w.remove_meta("resume_x")
			w.position = Vector2(-40.0 - i * 36.0, GROUND_Y - 32.0)
		particles_seed.emitting = true

func _process_sowing(delta: float, speed: float) -> void:
	if GameManager.has_seeder_tractor:
		vehicle_x += speed * 1.2 * delta
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
		particles_seed.position = Vector2(vehicle_x + 16, GROUND_Y - 10.0)

		var seeder_x: float = vehicle_x + 20.0
		var seg: int = int(seeder_x / float(TILE_SIZE))
		if seg >= 0 and seg < segment_count:
			crop_stages[seg] = 0

		if vehicle_x > screen_width + 50:
			particles_seed.emitting = false
			change_state(State.WATERING)
	else:
		var is_raining: bool = (current_weather_id == 1) # Weather.RAIN

		if is_raining:
			particles_seed.emitting = false
			var run_speed: float = vehicle_speed * 1.5

			if GameManager.canopy_count > 0:
				# Сеятели бегут под ближайший навес
				for i in range(seeder_workers.size()):
					var w: Sprite2D = seeder_workers[i]
					w.visible = true
					if not w.has_meta("resume_x"):
						w.set_meta("resume_x", w.position.x)

					# Найти ближайший навес
					var best_canopy_center: float = 240.0 + 28.0
					var min_dist: float = 999999.0
					for c in range(GameManager.canopy_count):
						var cx: float = 240.0 + c * 400.0 + 28.0
						var d: float = abs(w.position.x - cx)
						if d < min_dist:
							min_dist = d
							best_canopy_center = cx

					var target_x: float = best_canopy_center - 14.0 + i * 14.0
					if abs(w.position.x - target_x) > 4.0:
						var dir: float = sign(target_x - w.position.x)
						w.position.x += dir * run_speed * delta
						w.flip_h = (dir < 0)
						w.frame = int(anim_timer * 9.0 + i) % 4
					else:
						w.position.x = target_x
						w.flip_h = false
						w.frame = 0 # Укрылись под навесом, стоят спокойно
			else:
				# Навеса нет — сеятели убегают с карты влево, пока дождь не закончится
				for i in range(seeder_workers.size()):
					var w: Sprite2D = seeder_workers[i]
					if not w.has_meta("resume_x"):
						w.set_meta("resume_x", w.position.x)

					var target_x: float = -60.0 - i * 30.0
					if w.position.x > target_x:
						w.position.x -= run_speed * delta
						w.flip_h = true
						w.frame = int(anim_timer * 9.0 + i) % 4
						if w.position.x <= -35.0:
							w.visible = false
					else:
						w.position.x = target_x
						w.visible = false
		else:
			# Дождь не идет: возвращение и нормальный сев
			var all_finished: bool = true
			var lead_x: float = 0.0
			particles_seed.emitting = true

			for i in range(seeder_workers.size()):
				var w: Sprite2D = seeder_workers[i]
				w.visible = true

				# Если рабочий возвращается из укрытия на точку сева
				if w.has_meta("resume_x"):
					var res_x: float = float(w.get_meta("resume_x"))
					if abs(w.position.x - res_x) > 6.0:
						var dir: float = sign(res_x - w.position.x)
						w.position.x += dir * vehicle_speed * 1.3 * delta
						w.flip_h = (dir < 0)
						w.frame = int(anim_timer * 8.0 + i) % 4
						all_finished = false
						lead_x = max(lead_x, w.position.x)
						continue
					else:
						w.remove_meta("resume_x")
						w.flip_h = false

				w.flip_h = false
				w.position.x += speed * 0.7 * delta
				w.frame = int(anim_timer * 5.0 + i) % 4
				lead_x = max(lead_x, w.position.x)

				var seg: int = int((w.position.x + 24.0) / float(TILE_SIZE))
				if seg >= 0 and seg < segment_count:
					crop_stages[seg] = 0

				if w.position.x < screen_width + 40:
					all_finished = false

			particles_seed.position = Vector2(lead_x + 10, GROUND_Y - 10.0)

			if all_finished:
				for w in seeder_workers:
					w.visible = false
					if w.has_meta("resume_x"):
						w.remove_meta("resume_x")
					w.flip_h = false
				particles_seed.emitting = false
				change_state(State.WATERING)

# ------------------------------------------------------------------------------
# 3. WATERING: Полив
# ------------------------------------------------------------------------------
func _start_watering() -> void:
	for w in seeder_workers:
		w.visible = false

	if current_weather_id == 1: # Дождь
		for i in range(segment_count):
			soil_segments[i] = 2
		change_state(State.GROWING)
		return

	vehicle_sprite.visible = true
	vehicle_sprite.texture = tex_tanker
	vehicle_sprite.hframes = 1
	vehicle_sprite.modulate = Color.WHITE
	vehicle_x = -70.0
	vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
	particles_water.emitting = true

func _process_watering(delta: float, speed: float) -> void:
	vehicle_x += speed * delta
	vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
	particles_water.position = Vector2(vehicle_x + 4.0, GROUND_Y - 12.0)

	var pipe_x: float = vehicle_x + 8.0
	var seg: int = int(pipe_x / float(TILE_SIZE))
	for i in range(max(0, seg - 1), min(segment_count, seg + 2)):
		soil_segments[i] = 2

	if vehicle_x > screen_width + 50:
		particles_water.emitting = false
		change_state(State.GROWING)

# ------------------------------------------------------------------------------
# 4. GROWING: Рост культур
# ------------------------------------------------------------------------------
func _start_growing() -> void:
	vehicle_sprite.visible = false
	particles_water.emitting = false
	state_timer = 0.0

func _process_growing(delta: float) -> void:
	var growth_rate: float = 1.30 if current_weather_id == 1 else weather_speed_mod
	state_timer += delta * growth_rate
	var crop_data: Dictionary = GameManager.get_current_crop_data()
	var total_time: float = float(crop_data.get("growth_time", 8.0))

	var progress: float = clamp(state_timer / total_time, 0.0, 1.0)
	var stage: int = int(progress * 3.99)
	for i in range(segment_count):
		crop_stages[i] = stage

	if progress >= 1.0:
		change_state(State.HARVESTING)

# ------------------------------------------------------------------------------
# 5. HARVESTING: Жатва
# ------------------------------------------------------------------------------
func _start_harvesting() -> void:
	vehicle_sprite.visible = true
	if GameManager.has_super_harvester:
		vehicle_sprite.texture = tex_harvester_v2
		vehicle_sprite.hframes = 4
		vehicle_sprite.frame = 0
		vehicle_x = -100.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 48.0)
	else:
		vehicle_sprite.texture = tex_harvester
		vehicle_sprite.hframes = 3
		vehicle_sprite.frame = 0
		vehicle_x = -80.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 40.0)
	vehicle_sprite.modulate = Color.WHITE

func _process_harvesting(delta: float, speed: float) -> void:
	var harv_speed: float = speed * (1.6 if GameManager.has_super_harvester else 0.9)
	vehicle_x += harv_speed * delta
	var spr_y: float = GROUND_Y - 48.0 if GameManager.has_super_harvester else GROUND_Y - 40.0
	vehicle_sprite.position = Vector2(vehicle_x, spr_y)
	if GameManager.has_super_harvester:
		vehicle_sprite.frame = int(anim_timer * 8.0) % 4
	else:
		vehicle_sprite.frame = int(anim_timer * 9.0) % 3

	var cutter_x: float = vehicle_x + (54.0 if GameManager.has_super_harvester else 48.0)
	var seg: int = int(cutter_x / float(TILE_SIZE))
	for i in range(max(0, seg - 1), min(segment_count, seg + 2)):
		if crop_stages[i] != -1:
			crop_stages[i] = -1
			soil_segments[i] = 3

	if vehicle_x > screen_width + 80:
		change_state(State.HAULING)

# ------------------------------------------------------------------------------
# 6. HAULING: Вывоз и продажа (с учетом Мельницы и Амбара)
# ------------------------------------------------------------------------------
func _start_hauling() -> void:
	vehicle_sprite.visible = true
	if GameManager.has_road_train:
		vehicle_sprite.texture = tex_truck_v2
		vehicle_sprite.hframes = 4
		vehicle_sprite.frame = 0
		vehicle_x = -100.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 40.0)
	else:
		vehicle_sprite.texture = tex_truck
		vehicle_sprite.hframes = 4
		vehicle_sprite.frame = 0
		vehicle_x = -70.0
		vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
	vehicle_sprite.modulate = Color.WHITE
	truck_fill_stage = 0

func _process_hauling(delta: float, speed: float) -> void:
	var haul_speed: float = speed * (1.9 if GameManager.has_road_train else 1.1)
	vehicle_x += haul_speed * delta
	var spr_y: float = GROUND_Y - 40.0 if GameManager.has_road_train else GROUND_Y - 32.0
	vehicle_sprite.position = Vector2(vehicle_x, spr_y)

	var frac: float = clamp(vehicle_x / float(screen_width), 0.0, 1.0)
	truck_fill_stage = int(frac * 3.0)
	vehicle_sprite.frame = truck_fill_stage

	if vehicle_x > screen_width + 80:
		_finish_hauling_cycle()

func _finish_hauling_cycle() -> void:
	var crop_data: Dictionary = GameManager.get_current_crop_data()
	var base_reward: int = int(crop_data.get("base_reward", 35))
	
	# Бонус супер-комбайна (+15% к урожайности)
	if GameManager.has_super_harvester:
		base_reward = int(base_reward * 1.15)

	# Бонус амбара (+20%)
	if GameManager.has_barn:
		base_reward = int(base_reward * 1.20)

	# Бонус мельницы (+50% за помол муки)
	var final_reward: int = base_reward
	var bonus_text: String = ""
	if GameManager.has_windmill:
		var flour_bonus: int = int(base_reward * 0.50)
		final_reward += flour_bonus
		bonus_text = " (Мука +%d)" % flour_bonus

	# Сезонные цены (зимой дефицит и самая высокая цена +85%, весной +15%, осенью спад цен)
	var season_mult: float = GameManager.get_season_price_multiplier()
	final_reward = int(final_reward * season_mult)
	if season_mult > 1.05:
		bonus_text += " [Зима +%d%%]" % int((season_mult - 1.0) * 100.0)
	elif season_mult < 0.95:
		bonus_text += " [Осень -%d%%]" % int((1.0 - season_mult) * 100.0)

	# Множитель прибыли от количества используемых мониторов (x2 для 2 мониторов, x3 для 3 и т.д.)
	var mon_mult: float = GameManager.get_monitor_profit_multiplier()
	if mon_mult > 1.0:
		final_reward = int(final_reward * mon_mult)
		bonus_text += " [x%d Монитора]" % int(mon_mult)

	# Обработка финансов и выплат по долгам
	var fin_res: Dictionary = GameManager.process_harvest_finances(final_reward)
	GameManager.total_harvested += 1

	# Долгосрочная прогрессия фермы: опыт и репутация за каждый полный цикл поля
	var progression_result: Dictionary = ProgressionManager.add_harvest_progress(GameManager.current_crop)
	var xp_gained: int = int(progression_result.get("xp_gained", 0))
	if xp_gained > 0:
		bonus_text += " [XP +%d]" % xp_gained
	if bool(progression_result.get("leveled_up", false)):
		bonus_text += " [Ур. %d!]" % ProgressionManager.farm_level

	var debt_paid: int = fin_res.subsidy_paid + fin_res.loan_paid
	if debt_paid > 0:
		bonus_text += " [Долг: -%d]" % debt_paid

	_show_floating_coins(fin_res.net_coins, bonus_text)

	soil_segments.fill(0)
	crop_stages.fill(-1)

	harvest_completed.emit(fin_res.net_coins)
	change_state(State.PLOWING)

func reset_field_to_start() -> void:
	soil_segments.fill(0)
	crop_stages.fill(-1)
	for w in seeder_workers:
		w.visible = false
		w.flip_h = false
		if w.has_meta("resume_x"):
			w.remove_meta("resume_x")
	for rw in resting_workers:
		rw.visible = false
	smoke_fire_sprite.visible = false
	mud_splash_sprite.visible = false
	campfire_sprite.visible = false
	change_state(State.PLOWING)
	queue_redraw()

func _show_floating_coins(amount: int, extra_text: String = "") -> void:
	if floating_label == null:
		return
	var sign_prefix = "+" if amount >= 0 else ""
	floating_label.text = "%s%d 🪙%s" % [sign_prefix, amount, extra_text]
	floating_label.position = Vector2(screen_width - 240, GROUND_Y - 50)
	floating_label.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(floating_label, "position:y", GROUND_Y - 80, 1.6)
	tw.parallel().tween_property(floating_label, "modulate:a", 0.0, 1.6)
	tw.tween_callback(func():
		floating_label.visible = false
		floating_label.modulate.a = 1.0
	)

func change_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0
	state_changed.emit(new_state)

	match new_state:
		State.PLOWING:
			_start_plowing()
		State.SOWING:
			_start_sowing()
		State.WATERING:
			_start_watering()
		State.GROWING:
			_start_growing()
		State.HARVESTING:
			_start_harvesting()
		State.HAULING:
			_start_hauling()

# ==============================================================================
# ОТРИСОВКА ПОЛЯ, УЛУЧШЕНИЙ, ДЕКОРАЦИЙ И АНИМАЦИЙ
# ==============================================================================
func _draw() -> void:
	if tex_soil == null or tex_crops == null:
		return

	# 1. Сезонный пейзаж (деревья, листва, снег, цветы)
	_draw_seasonal_landscape()

	# 2. Пользовательские декорации (забор, цветы, фонари)
	_draw_decorations()

	# 3. Постройки: Мельница, Амбар, Навесы, Теплицы
	_draw_buildings()

	# 4. Полоса земли
	for i in range(segment_count):
		var sx: float = i * TILE_SIZE
		var state_val: int = soil_segments[i]
		var src_rect: Rect2 = Rect2(state_val * 16, 0, 16, 16)
		var dst_rect: Rect2 = Rect2(sx, GROUND_Y, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(tex_soil, dst_rect, src_rect)

	# Зимняя кромка снега на поверхности почвы
	if current_season == GameManager.Season.WINTER:
		draw_rect(Rect2(0, GROUND_Y - 2.0, screen_width, 4.0), Color(0.92, 0.96, 1.0, 0.90), true)
	elif current_season == GameManager.Season.AUTUMN:
		# Осенняя опавшая листва вдоль кромки поля
		var leaf_x: float = 20.0
		while leaf_x < screen_width:
			draw_rect(Rect2(leaf_x, GROUND_Y + 1.0, 3, 2), Color("df7126"), true)
			draw_rect(Rect2(leaf_x + 14.0, GROUND_Y + 2.0, 3, 2), Color("d9a066"), true)
			leaf_x += 42.0

	# 5. Растения
	var crop_data: Dictionary = GameManager.get_current_crop_data()
	var row_idx: int = int(crop_data.get("row_index", 0))

	for i in range(segment_count):
		var stage: int = crop_stages[i]
		if stage >= 0 and stage <= 3:
			var px: float = i * TILE_SIZE
			var sway: float = 0.0
			# Покачивание от ветра
			var wind_factor: float = 3.5 if current_weather_id == 4 else 1.0
			if stage >= 2 or current_weather_id == 4:
				sway = sin(anim_timer * (3.5 * wind_factor) + i * 0.4) * (2.0 * wind_factor)

			var src_crop: Rect2 = Rect2(stage * 16, row_idx * 16, 16, 16)
			var dst_crop: Rect2 = Rect2(px + sway, GROUND_Y - TILE_SIZE + 4.0, TILE_SIZE, TILE_SIZE)
			draw_texture_rect_region(tex_crops, dst_crop, src_crop)

	# 6. Пугала (до 3 шт на монитор, расставляются равномерно)
	if GameManager.scarecrow_count > 0 and tex_crisis != null:
		var count: int = GameManager.scarecrow_count
		for s in range(count):
			var scare_x: float = (screen_width / float(count + 1)) * (s + 1)
			var scare_rect: Rect2 = Rect2(80, 0, 16, 16)
			draw_texture_rect_region(tex_crisis, Rect2(scare_x, GROUND_Y - 32.0, 32, 32), scare_rect)

	# 7. Сторожевой пес
	if GameManager.has_guard_dog and tex_crisis != null:
		var dog_frame: int = int(anim_timer * 4.0) % 2
		var dog_rect: Rect2 = Rect2(96 + dog_frame * 16, 0, 16, 16)
		draw_texture_rect_region(tex_crisis, Rect2(screen_width - 160.0, GROUND_Y - 30.0, 32, 32), dog_rect)

func _draw_seasonal_landscape() -> void:
	if tex_seasons_decor == null:
		return

	# Выбор текстуры дерева по текущему сезону (0=Весна, 1=Лето, 2=Осень, 3=Зима)
	var season_frame: int = int(current_season) % 4
	var tree_src: Rect2 = Rect2(season_frame * 32, 0, 32, 32)

	# Равномерно расставляем сезонные деревья на заднем плане
	var tree_step: float = 340.0
	var tree_x: float = 160.0
	while tree_x < screen_width - 160.0:
		# Небольшое покачивание ветвей
		var tree_sway: float = sin(anim_timer * 2.0 + tree_x * 0.05) * 1.5
		draw_texture_rect_region(tex_seasons_decor, Rect2(tree_x + tree_sway, GROUND_Y - 60.0, 48, 48), tree_src)
		tree_x += tree_step

func _draw_buildings() -> void:
	var is_winter: bool = (current_season == GameManager.Season.WINTER)

	# Мельница (слева на X = 40)
	if GameManager.has_windmill and tex_windmill != null:
		var mill_base: Rect2 = Rect2(0, 0, 32, 48)
		draw_texture_rect_region(tex_windmill, Rect2(40.0, GROUND_Y - 54.0, 36, 54), mill_base)
		var blade_frame: int = int(anim_timer * 4.0) % 2
		var blade_src: Rect2 = Rect2(32 + blade_frame * 32, 0, 32, 32)
		draw_texture_rect_region(tex_windmill, Rect2(42.0, GROUND_Y - 66.0, 32, 32), blade_src)
		if is_winter:
			draw_rect(Rect2(40.0, GROUND_Y - 55.0, 36, 4), Color(0.95, 0.98, 1.0, 0.92), true)

	# Амбар (справа на X = screen_width - 120)
	if GameManager.has_barn and tex_barn != null:
		var barn_src: Rect2 = Rect2(0, 0, 48, 36)
		draw_texture_rect_region(tex_barn, Rect2(screen_width - 110.0, GROUND_Y - 42.0, 56, 42), barn_src)
		if is_winter:
			draw_rect(Rect2(screen_width - 110.0, GROUND_Y - 43.0, 56, 4), Color(0.95, 0.98, 1.0, 0.92), true)

	# Навесы от дождя/града
	if GameManager.canopy_count > 0 and tex_canopy != null:
		for c in range(GameManager.canopy_count):
			var canopy_x: float = 240.0 + c * 400.0
			var canopy_src: Rect2 = Rect2(0, 0, 48, 32)
			draw_texture_rect_region(tex_canopy, Rect2(canopy_x, GROUND_Y - 38.0, 56, 38), canopy_src)
			if is_winter:
				draw_rect(Rect2(canopy_x, GROUND_Y - 39.0, 56, 4), Color(0.95, 0.98, 1.0, 0.92), true)

	# Теплицы (круглогодичный урожай, стоят на поле)
	if GameManager.greenhouse_count > 0 and tex_greenhouse != null:
		for g in range(GameManager.greenhouse_count):
			var gh_x: float = 110.0 if g == 0 else (screen_width - 240.0)
			# Конструкция теплицы
			draw_texture_rect_region(tex_greenhouse, Rect2(gh_x, GROUND_Y - 44.0, 68, 44), Rect2(0, 0, 56, 36))
			# Снежная шапка на арочной крыше зимой
			if is_winter:
				draw_rect(Rect2(gh_x + 6.0, GROUND_Y - 45.0, 56, 4), Color(0.94, 0.97, 1.0, 0.88), true)

			# Иконка текущей выращиваемой экзотической культуры над теплицей
			if tex_greenhouse_crops != null:
				var gh_info: Dictionary = GameManager.get_current_greenhouse_data()
				var c_frame: int = int(gh_info.get("frame", 0))
				draw_texture_rect_region(tex_greenhouse_crops, Rect2(gh_x + 24.0, GROUND_Y - 60.0, 20, 20), Rect2(c_frame * 16, 0, 16, 16))

func _draw_decorations() -> void:
	if GameManager.active_decoration == "none" or tex_decorations == null:
		return

	var dec_type: String = GameManager.active_decoration
	var src_r: Rect2
	var width_step: float = 32.0

	match dec_type:
		"fence_wood":
			src_r = Rect2(0, 16, 16, 16)
			width_step = 28.0
		"fence_white":
			src_r = Rect2(16, 16, 16, 16)
			width_step = 28.0
		"lamps":
			var lamp_x: float = 48 if is_night_active else 32
			src_r = Rect2(lamp_x, 0, 16, 32)
			width_step = 160.0
		"flowers":
			src_r = Rect2(64, 16, 16, 16)
			width_step = 64.0
		"trees":
			src_r = Rect2(80, 8, 24, 24)
			width_step = 200.0

	var x: float = 10.0
	while x < screen_width - 20.0:
		var dest_y: float = GROUND_Y - 26.0 if src_r.size.y == 16 else (GROUND_Y - 46.0)
		draw_texture_rect_region(tex_decorations, Rect2(x, dest_y, src_r.size.x * 1.6, src_r.size.y * 1.6), src_r)
		x += width_step


# ==============================================================================
# СОХРАНЕНИЕ И ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ ПОЛЯ
# ==============================================================================
func save_field_state() -> void:
	SettingsManager.config.set_value("field_state", "has_saved_state", true)
	SettingsManager.config.set_value("field_state", "current_state", int(current_state))
	SettingsManager.config.set_value("field_state", "state_timer", state_timer)
	SettingsManager.config.set_value("field_state", "vehicle_x", vehicle_x)
	SettingsManager.config.set_value("field_state", "truck_fill_stage", truck_fill_stage)

	var soil_arr: Array = []
	for s in soil_segments:
		soil_arr.append(int(s))
	var crop_arr: Array = []
	for c in crop_stages:
		crop_arr.append(int(c))
	SettingsManager.config.set_value("field_state", "soil_segments", soil_arr)
	SettingsManager.config.set_value("field_state", "crop_stages", crop_arr)

	SettingsManager.config.set_value("field_state", "greenhouse_timer", greenhouse_timer)
	SettingsManager.config.set_value("field_state", "current_season", int(current_season))
	SettingsManager.save_settings()

func restore_field_state() -> bool:
	if not bool(SettingsManager.config.get_value("field_state", "has_saved_state", false)):
		return false

	var saved_state_int: int = int(SettingsManager.config.get_value("field_state", "current_state", int(State.PLOWING)))
	var saved_timer: float = float(SettingsManager.config.get_value("field_state", "state_timer", 0.0))
	var saved_vx: float = float(SettingsManager.config.get_value("field_state", "vehicle_x", -80.0))
	var saved_truck_fill: int = int(SettingsManager.config.get_value("field_state", "truck_fill_stage", 0))
	var saved_gh_timer: float = float(SettingsManager.config.get_value("field_state", "greenhouse_timer", 0.0))
	var saved_season: int = int(SettingsManager.config.get_value("field_state", "current_season", int(GameManager.current_season)))

	var saved_soil = SettingsManager.config.get_value("field_state", "soil_segments", [])
	var saved_crops = SettingsManager.config.get_value("field_state", "crop_stages", [])

	_update_screen_bounds()

	if saved_soil != null and saved_soil.size() > 0:
		var fill_len: int = mini(saved_soil.size(), segment_count)
		for i in range(fill_len):
			soil_segments[i] = int(saved_soil[i])

	if saved_crops != null and saved_crops.size() > 0:
		var fill_len: int = mini(saved_crops.size(), segment_count)
		for i in range(fill_len):
			crop_stages[i] = int(saved_crops[i])

	greenhouse_timer = saved_gh_timer
	state_timer = saved_timer
	truck_fill_stage = saved_truck_fill
	vehicle_x = saved_vx
	set_season(saved_season)

	_resume_state_visuals(saved_state_int as State)
	queue_redraw()
	print("[FieldFSM] Состояние поля успешно восстановлено: ", State.keys()[saved_state_int], " (x=", vehicle_x, ")")
	return true

func _resume_state_visuals(target_state: State) -> void:
	current_state = target_state
	if particles_soil != null:
		particles_soil.emitting = false
	if particles_water != null:
		particles_water.emitting = false
	if particles_seed != null:
		particles_seed.emitting = false
	for w in seeder_workers:
		w.visible = false

	if vehicle_sprite == null:
		return

	match target_state:
		State.IDLE:
			change_state(State.PLOWING)
		State.PLOWING:
			vehicle_sprite.visible = true
			if GameManager.has_heavy_tractor:
				vehicle_sprite.texture = tex_tractor_v2
				vehicle_sprite.hframes = 2
				vehicle_sprite.frame = 0
				vehicle_sprite.modulate = Color.WHITE
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 40.0)
			else:
				vehicle_sprite.texture = tex_tractor
				vehicle_sprite.hframes = 1
				vehicle_sprite.frame = 0
				vehicle_sprite.modulate = GameManager.tractor_color
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
			if particles_soil != null:
				particles_soil.emitting = true
				particles_soil.position = Vector2(vehicle_x + 10, GROUND_Y - 4.0)
		State.SOWING:
			if GameManager.has_seeder_tractor:
				vehicle_sprite.visible = true
				vehicle_sprite.texture = tex_tractor_seeder
				vehicle_sprite.hframes = 1
				vehicle_sprite.modulate = GameManager.tractor_color
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
				if particles_seed != null:
					particles_seed.emitting = true
					particles_seed.position = Vector2(vehicle_x + 16, GROUND_Y - 10.0)
			else:
				vehicle_sprite.visible = false
				for i in range(seeder_workers.size()):
					var w: Sprite2D = seeder_workers[i]
					w.visible = true
					w.flip_h = false
					w.position = Vector2(vehicle_x - i * 36.0, GROUND_Y - 32.0)
				if particles_seed != null:
					particles_seed.emitting = true
		State.WATERING:
			vehicle_sprite.visible = true
			vehicle_sprite.texture = tex_tanker
			vehicle_sprite.hframes = 1
			vehicle_sprite.modulate = Color.WHITE
			vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
			if particles_water != null:
				particles_water.emitting = true
				particles_water.position = Vector2(vehicle_x + 14, GROUND_Y - 12.0)
		State.GROWING:
			vehicle_sprite.visible = false
		State.HARVESTING:
			vehicle_sprite.visible = true
			if GameManager.has_super_harvester:
				vehicle_sprite.texture = tex_harvester_v2
				vehicle_sprite.hframes = 4
				vehicle_sprite.frame = 0
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 48.0)
			else:
				vehicle_sprite.texture = tex_harvester
				vehicle_sprite.hframes = 3
				vehicle_sprite.frame = 0
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 40.0)
			vehicle_sprite.modulate = Color.WHITE
			if particles_soil != null:
				particles_soil.emitting = true
				particles_soil.position = Vector2(vehicle_x + 16, GROUND_Y - 6.0)
		State.HAULING:
			vehicle_sprite.visible = true
			if GameManager.has_road_train:
				vehicle_sprite.texture = tex_truck_v2
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 40.0)
			else:
				vehicle_sprite.texture = tex_truck
				vehicle_sprite.position = Vector2(vehicle_x, GROUND_Y - 32.0)
			vehicle_sprite.hframes = 4
			vehicle_sprite.frame = clampi(truck_fill_stage, 0, 3)
			vehicle_sprite.modulate = Color.WHITE
