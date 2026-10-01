class_name AssetGenerator
extends RefCounted

const OUTPUT_DIR: String = "res://assets/generated"

# Палитра DawnBringer 32 (DB32)
const DB32: Dictionary = {
	"black": Color("000000"),
	"dark_grey": Color("222034"),
	"deep_blue": Color("1f244b"),
	"grey": Color("4b5bab"),
	"light_blue": Color("639bff"),
	"cyan": Color("5fcde4"),
	"white": Color("cbdbfc"),
	"pure_white": Color("ffffff"),
	"light_grey": Color("9badb7"),
	"slate": Color("696a6a"),
	"charcoal": Color("323c39"),
	"dark_brown": Color("3f2817"),
	"brown": Color("663931"),
	"wood_brown": Color("8f563b"),
	"warm_brown": Color("df7126"),
	"sand": Color("d9a066"),
	"light_sand": Color("eec39a"),
	"yellow": Color("fbf236"),
	"gold": Color("d79b1e"),
	"dark_green": Color("103c26"),
	"forest_green": Color("37946e"),
	"green": Color("4b692f"),
	"lime": Color("524b24"),
	"bright_green": Color("8ab060"),
	"light_green": Color("a7f070"),
	"red": Color("ac3232"),
	"crimson": Color("761f26"),
	"pink": Color("d95763"),
	"orange": Color("df7126"),
	"purple": Color("76428a"),
	"lavender": Color("ac79af")
}

static var _texture_cache: Dictionary = {}

## Возвращает ImageTexture без зависимости от импорта редактора
static func get_texture(filename: String) -> Texture2D:
	if _texture_cache.has(filename):
		return _texture_cache[filename]

	var path: String = OUTPUT_DIR + "/" + filename
	if not FileAccess.file_exists(path):
		generate_all_assets(true)

	var img: Image = Image.load_from_file(path)
	if img != null:
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		_texture_cache[filename] = tex
		return tex

	return null

## Генерирует все ассеты при первом запуске или обновлении
static func generate_all_assets(force: bool = false) -> void:
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var check_file: String = OUTPUT_DIR + "/tractor_v2.png"
	if not force and FileAccess.file_exists(check_file):
		print("[AssetGenerator] Generated assets already exist.")
		return

	print("[AssetGenerator] Procedurally generating all game pixel assets...")
	
	_generate_tractor().save_png(OUTPUT_DIR + "/tractor.png")
	_generate_tractor_seeder().save_png(OUTPUT_DIR + "/tractor_seeder.png")
	_generate_worker_sower().save_png(OUTPUT_DIR + "/worker_sower.png")
	_generate_water_tanker().save_png(OUTPUT_DIR + "/water_tanker.png")
	_generate_harvester().save_png(OUTPUT_DIR + "/harvester.png")
	_generate_truck().save_png(OUTPUT_DIR + "/truck_sheet.png")
	_generate_pickup_repair().save_png(OUTPUT_DIR + "/pickup_repair.png")
	_generate_inspector_car().save_png(OUTPUT_DIR + "/inspector_car.png")
	_generate_soil_tiles().save_png(OUTPUT_DIR + "/soil_tiles.png")
	_generate_crisis_objects().save_png(OUTPUT_DIR + "/crisis_objects.png")
	_generate_particles().save_png(OUTPUT_DIR + "/particles.png")
	_generate_smoke_fire_sheet().save_png(OUTPUT_DIR + "/smoke_fire_sheet.png")
	_generate_campfire().save_png(OUTPUT_DIR + "/campfire.png")
	_generate_canopy().save_png(OUTPUT_DIR + "/canopy.png")
	_generate_mud_splash().save_png(OUTPUT_DIR + "/mud_splash.png")
	_generate_workers_rest().save_png(OUTPUT_DIR + "/workers_rest.png")
	_generate_windmill().save_png(OUTPUT_DIR + "/windmill.png")
	_generate_barn().save_png(OUTPUT_DIR + "/barn.png")
	_generate_decorations().save_png(OUTPUT_DIR + "/decorations.png")
	_generate_weather_particles().save_png(OUTPUT_DIR + "/weather_particles.png")

	# Новые улучшенные модели техники
	_generate_tractor_v2().save_png(OUTPUT_DIR + "/tractor_v2.png")
	_generate_harvester_v2().save_png(OUTPUT_DIR + "/harvester_v2.png")
	_generate_truck_v2().save_png(OUTPUT_DIR + "/truck_v2.png")

	print("[AssetGenerator] All assets successfully generated into: ", OUTPUT_DIR)


# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ РИСОВАНИЯ ПИКСЕЛЕЙ
# ==============================================================================

static func _safe_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)

static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			_safe_pixel(img, ix, iy, color)

static func _circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for x in range(cx - r, cx + r + 1):
		for y in range(cy - r, cy + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				_safe_pixel(img, x, y, color)


# ==============================================================================
# 1. ТРАКТОР (32x16)
# ==============================================================================
static func _generate_tractor() -> Image:
	var img: Image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Выхлопная труба
	_rect(img, 22, 1, 2, 4, DB32.slate)
	_rect(img, 23, 0, 2, 1, DB32.charcoal)

	# Кабина (стойки и остекление)
	_rect(img, 9, 3, 9, 7, DB32.light_blue)
	_rect(img, 8, 2, 11, 2, DB32.red)       # крыша кабины
	_rect(img, 8, 3, 2, 7, DB32.crimson)     # задняя стойка
	_rect(img, 17, 3, 2, 7, DB32.crimson)    # передняя стойка

	# Капот двигателя
	_rect(img, 18, 6, 9, 5, DB32.red)
	_rect(img, 26, 7, 2, 4, DB32.yellow)     # фара
	_rect(img, 19, 7, 7, 1, DB32.crimson)    # вентиляционная решетка
	_rect(img, 19, 9, 7, 1, DB32.crimson)

	# Плуг сзади (металлические зубья)
	_rect(img, 2, 10, 5, 2, DB32.slate)
	_rect(img, 0, 11, 3, 4, DB32.charcoal)
	_rect(img, 3, 12, 3, 3, DB32.charcoal)

	# Заднее большое колесо (диаметр ~10)
	_circle(img, 11, 11, 4, DB32.charcoal)
	_circle(img, 11, 11, 2, DB32.slate)
	_safe_pixel(img, 11, 11, DB32.yellow)       # ступица/диск
	# Протекторы
	_safe_pixel(img, 11, 7, DB32.dark_grey)
	_safe_pixel(img, 11, 15, DB32.dark_grey)
	_safe_pixel(img, 7, 11, DB32.dark_grey)
	_safe_pixel(img, 15, 11, DB32.dark_grey)

	# Переднее колесо (диаметр ~6)
	_circle(img, 24, 12, 3, DB32.charcoal)
	_circle(img, 24, 12, 1, DB32.slate)
	_safe_pixel(img, 24, 12, DB32.yellow)

	return img


# ==============================================================================
# 2. ТРАКТОР С СЕЯЛКОЙ (32x16)
# ==============================================================================
static func _generate_tractor_seeder() -> Image:
	var img: Image = _generate_tractor()
	# Заменяем плуг на бункер сеялки с трубками
	_rect(img, 0, 6, 7, 6, DB32.forest_green) # зеленый ящик для семян
	_rect(img, 1, 7, 5, 2, DB32.gold)         # семена внутри
	# Дисковые сошники сеялки
	_circle(img, 2, 13, 2, DB32.slate)
	_circle(img, 6, 13, 2, DB32.slate)
	return img


# ==============================================================================
# 3. РАБОЧИЕ-СЕЯТЕЛИ (64x16, 4 кадра по 16x16)
# ==============================================================================
static func _generate_worker_sower() -> Image:
	var img: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(4):
		var ox: int = frame * 16

		# Соломенная шляпа
		_rect(img, ox + 4, 1, 8, 2, DB32.sand)
		_rect(img, ox + 3, 2, 10, 1, DB32.warm_brown)

		# Лицо
		_rect(img, ox + 6, 3, 4, 3, DB32.light_sand)
		img.set_pixel(ox + 8, 4, DB32.dark_brown) # глаз

		# Комбинезон (синий джинс)
		_rect(img, ox + 5, 6, 6, 5, DB32.grey)
		_rect(img, ox + 6, 6, 4, 3, DB32.red)    # красная рубаха под лямками

		# Мешок с семенами через плечо
		_rect(img, ox + 4, 7, 3, 4, DB32.wood_brown)
		img.set_pixel(ox + 5, 7, DB32.gold)

		# Анимация ног и руки сева
		match frame:
			0: # Стойка/нейтральный шаг
				_rect(img, ox + 5, 11, 2, 4, DB32.deep_blue)
				_rect(img, ox + 9, 11, 2, 4, DB32.deep_blue)
				_rect(img, ox + 10, 7, 2, 3, DB32.light_sand)
			1: # Шаг вперед
				_rect(img, ox + 4, 11, 2, 4, DB32.deep_blue)
				_rect(img, ox + 10, 11, 3, 4, DB32.deep_blue)
				_rect(img, ox + 10, 8, 3, 2, DB32.light_sand)
			2: # Взмах сева (рука вперед)
				_rect(img, ox + 5, 11, 2, 4, DB32.deep_blue)
				_rect(img, ox + 8, 11, 2, 4, DB32.deep_blue)
				_rect(img, ox + 11, 6, 4, 2, DB32.light_sand) # вытянутая рука
				img.set_pixel(ox + 15, 6, DB32.gold)          # семена летят
				img.set_pixel(ox + 14, 8, DB32.gold)
			3: # Семена падают на землю
				_rect(img, ox + 6, 11, 2, 4, DB32.deep_blue)
				_rect(img, ox + 8, 11, 3, 4, DB32.deep_blue)
				_rect(img, ox + 11, 7, 2, 3, DB32.light_sand)
				img.set_pixel(ox + 13, 9, DB32.gold)
				img.set_pixel(ox + 15, 12, DB32.gold)

		# Ботинки
		_rect(img, ox + 4, 14, 3, 2, DB32.dark_brown)
		_rect(img, ox + 9, 14, 3, 2, DB32.dark_brown)

	return img


# ==============================================================================
# 4. ЦИСТЕРНА-ПОЛИВАЛКА (32x16)
# ==============================================================================
static func _generate_water_tanker() -> Image:
	var img: Image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Кабина тягача
	_rect(img, 20, 3, 10, 8, DB32.forest_green)
	_rect(img, 24, 4, 5, 4, DB32.cyan)      # лобовое стекло
	_rect(img, 29, 8, 2, 3, DB32.yellow)    # фара

	# Бак цистерны с водой
	_rect(img, 3, 3, 16, 8, DB32.cyan)
	_rect(img, 2, 4, 1, 6, DB32.light_blue)
	_rect(img, 4, 4, 14, 2, DB32.pure_white) # блик на баке
	_rect(img, 7, 2, 4, 2, DB32.slate)       # горловина залива

	# Распылительные сопла сзади
	_rect(img, 0, 8, 3, 2, DB32.charcoal)
	_rect(img, 0, 10, 2, 3, DB32.slate)     # распылитель вниз
	img.set_pixel(0, 13, DB32.light_blue)   # капли воды
	img.set_pixel(1, 14, DB32.light_blue)

	# Колеса
	_circle(img, 7, 12, 3, DB32.charcoal)
	_circle(img, 7, 12, 1, DB32.light_grey)
	_circle(img, 15, 12, 3, DB32.charcoal)
	_circle(img, 15, 12, 1, DB32.light_grey)
	_circle(img, 25, 12, 3, DB32.charcoal)
	_circle(img, 25, 12, 1, DB32.light_grey)

	return img


# ==============================================================================
# 5. ЗЕРНОУБОРОЧНЫЙ КОМБАЙН (96x20, 3 кадра по 32x20)
# ==============================================================================
static func _generate_harvester() -> Image:
	var img: Image = Image.create(96, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(3):
		var ox: int = frame * 32

		# Корпус комбайна (красно-бордовый мощный агрегат)
		_rect(img, ox + 6, 2, 18, 12, DB32.red)
		_rect(img, ox + 18, 3, 6, 6, DB32.cyan)      # панорамная кабина
		_rect(img, ox + 16, 1, 9, 2, DB32.pure_white)# крыша кабины
		_rect(img, ox + 8, 3, 9, 4, DB32.gold)       # бункер зерна сверху

		# Выгрузной шнек (наклонная труба назад)
		_rect(img, ox + 2, 2, 7, 2, DB32.slate)
		_rect(img, ox + 1, 1, 2, 3, DB32.charcoal)

		# Наклонная камера спереди
		_rect(img, ox + 23, 9, 5, 4, DB32.charcoal)

		# Вращающееся мотовило (Reel) спереди (3 кадра вращения)
		var rx: int = ox + 28
		var ry: int = 12
		_circle(img, rx, ry, 3, DB32.yellow)
		img.set_pixel(rx, ry, DB32.charcoal)
		match frame:
			0:
				_rect(img, rx - 3, ry, 7, 1, DB32.charcoal)
				_rect(img, rx, ry - 3, 1, 7, DB32.charcoal)
			1:
				img.set_pixel(rx - 2, ry - 2, DB32.charcoal)
				img.set_pixel(rx + 2, ry + 2, DB32.charcoal)
				img.set_pixel(rx - 2, ry + 2, DB32.charcoal)
				img.set_pixel(rx + 2, ry - 2, DB32.charcoal)
			2:
				_rect(img, rx - 3, ry, 7, 1, DB32.red)
				_rect(img, rx, ry - 3, 1, 7, DB32.red)

		# Мощное переднее ведущее колесо
		_circle(img, ox + 20, 15, 4, DB32.charcoal)
		_circle(img, ox + 20, 15, 2, DB32.yellow)

		# Заднее колесо
		_circle(img, ox + 10, 16, 3, DB32.charcoal)
		_circle(img, ox + 10, 16, 1, DB32.yellow)

	return img


# ==============================================================================
# 6. ГРУЗОВИК (128x16, 4 кадра по 32x16: пустой -> 33% -> 66% -> 100% зерна)
# ==============================================================================
static func _generate_truck() -> Image:
	var img: Image = Image.create(128, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(4):
		var ox: int = frame * 32

		# Кабина грузовика
		_rect(img, ox + 20, 4, 10, 8, DB32.deep_blue)
		_rect(img, ox + 24, 5, 5, 4, DB32.cyan)      # стекло
		_rect(img, ox + 29, 8, 2, 3, DB32.yellow)    # фара
		_rect(img, ox + 20, 2, 2, 3, DB32.charcoal)  # выхлоп вертикальный

		# Рама
		_rect(img, ox + 2, 11, 28, 2, DB32.dark_grey)

		# Бортовой кузов
		_rect(img, ox + 2, 6, 17, 6, DB32.wood_brown)
		_rect(img, ox + 2, 6, 1, 6, DB32.brown)
		_rect(img, ox + 18, 6, 1, 6, DB32.brown)

		# Динамически заполняющаяся горка зерна
		if frame >= 1:
			_rect(img, ox + 4, 9, 13, 2, DB32.gold)
		if frame >= 2:
			_rect(img, ox + 5, 7, 11, 2, DB32.yellow)
		if frame == 3:
			# Горка с верхом
			_rect(img, ox + 6, 5, 9, 2, DB32.yellow)
			_rect(img, ox + 8, 4, 5, 1, DB32.pure_white) # верхушка горки

		# Колеса
		_circle(img, ox + 6, 12, 3, DB32.charcoal)
		_circle(img, ox + 6, 12, 1, DB32.light_grey)
		_circle(img, ox + 13, 12, 3, DB32.charcoal)
		_circle(img, ox + 13, 12, 1, DB32.light_grey)
		_circle(img, ox + 24, 12, 3, DB32.charcoal)
		_circle(img, ox + 24, 12, 1, DB32.light_grey)

	return img


# ==============================================================================
# 7. СПЕЦТРАНСПОРТ: ПИКАП СЛУЖБЫ РЕМОНТА (64x16, 2 кадра мигалки)
# ==============================================================================
static func _generate_pickup_repair() -> Image:
	var img: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(2):
		var ox: int = frame * 32

		# Бело-оранжевый кузов
		_rect(img, ox + 6, 6, 22, 6, DB32.pure_white)
		_rect(img, ox + 6, 9, 22, 2, DB32.orange)      # сервисная полоса
		_rect(img, ox + 16, 3, 7, 4, DB32.pure_white)  # кабина
		_rect(img, ox + 19, 4, 4, 3, DB32.cyan)        # стекло

		# Инструментальный ящик в открытом кузове
		_rect(img, ox + 7, 4, 8, 3, DB32.slate)
		_rect(img, ox + 8, 5, 2, 1, DB32.yellow)       # гаечный ключ

		# Мигалка на крыше (анимация вспышки: оранжевый / белый)
		var beacon_color: Color = DB32.yellow if frame == 0 else DB32.orange
		_rect(img, ox + 18, 1, 3, 2, beacon_color)
		if frame == 0:
			img.set_pixel(ox + 19, 0, DB32.pure_white) # вспышка

		# Фары
		_rect(img, ox + 27, 8, 2, 2, DB32.yellow)

		# Колеса
		_circle(img, ox + 11, 12, 3, DB32.charcoal)
		_circle(img, ox + 11, 12, 1, DB32.light_grey)
		_circle(img, ox + 23, 12, 3, DB32.charcoal)
		_circle(img, ox + 23, 12, 1, DB32.light_grey)

	return img


# ==============================================================================
# 8. СПЕЦТРАНСПОРТ: ЧЕРНЫЙ СЕДАН ИНСПЕКТОРА (32x16)
# ==============================================================================
static func _generate_inspector_car() -> Image:
	var img: Image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Черный лакированный кузов
	_rect(img, 3, 6, 26, 6, DB32.dark_grey)
	_rect(img, 9, 3, 12, 4, DB32.dark_grey)

	# Тонированные стекла с бликом
	_rect(img, 11, 4, 9, 3, DB32.deep_blue)
	img.set_pixel(13, 4, DB32.pure_white)

	# Хромированные бамперы и молдинги
	_rect(img, 1, 9, 2, 2, DB32.pure_white)
	_rect(img, 28, 9, 2, 2, DB32.pure_white)
	_rect(img, 4, 11, 23, 1, DB32.light_grey)

	# Фары
	_rect(img, 27, 7, 2, 2, DB32.yellow)
	_rect(img, 2, 7, 1, 2, DB32.red)

	# Колеса с хромированными колпаками
	_circle(img, 8, 12, 3, DB32.black)
	_circle(img, 8, 12, 1, DB32.pure_white)
	_circle(img, 22, 12, 3, DB32.black)
	_circle(img, 22, 12, 1, DB32.pure_white)

	return img


# ==============================================================================
# 9. ПОЧВА (64x16, 4 состояния по 16x16)
# ==============================================================================
static func _generate_soil_tiles() -> Image:
	var img: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Состояние 0 (0..15): Гладкая сухая земля
	for x in range(0, 16):
		for y in range(0, 16):
			var c: Color = DB32.sand if (x + y * 3) % 5 == 0 else DB32.wood_brown
			img.set_pixel(x, y, c)
	# Верхняя кромка травы
	for x in range(0, 16):
		img.set_pixel(x, 0, DB32.bright_green if x % 2 == 0 else DB32.green)

	# Состояние 1 (16..31): Вспаханная бороздовая земля
	for x in range(16, 32):
		for y in range(0, 16):
			var in_furrow: bool = (y % 4) == 0 or (y % 4) == 1
			var c: Color = DB32.dark_brown if in_furrow else DB32.brown
			if (x + y) % 7 == 0:
				c = DB32.warm_brown
			img.set_pixel(x, y, c)

	# Состояние 2 (32..47): Темная влажная земля
	for x in range(32, 48):
		for y in range(0, 16):
			var c: Color = DB32.dark_brown if (x + y) % 3 != 0 else DB32.charcoal
			# Мокрый блеск
			if (x * 7 + y * 13) % 17 == 0:
				c = DB32.cyan
			img.set_pixel(x, y, c)

	# Состояние 3 (48..63): Стерня со срезанными стеблями
	for x in range(48, 64):
		for y in range(0, 16):
			img.set_pixel(x, y, DB32.brown)
	# Торчащие пеньки стеблей
	for x in range(49, 63, 3):
		img.set_pixel(x, 1, DB32.yellow)
		img.set_pixel(x, 2, DB32.yellow)
		img.set_pixel(x + 1, 2, DB32.gold)

	return img


# ==============================================================================
# 10. СТАДИИ РАСТЕНИЙ (64x64: 4 культуры x 4 стадии по 16x16)
# ==============================================================================
static func _generate_crops_sheet() -> Image:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Ряд 0: Пшеница (Wheat)
	_draw_crop_row(img, 0, [
		func(ox, oy): # Росток
			img.set_pixel(ox + 8, oy + 14, DB32.light_green)
			img.set_pixel(ox + 7, oy + 13, DB32.light_green)
			img.set_pixel(ox + 9, oy + 13, DB32.bright_green),
		func(ox, oy): # Стебель
			_rect(img, ox + 7, oy + 10, 2, 5, DB32.bright_green)
			img.set_pixel(ox + 6, oy + 11, DB32.light_green)
			img.set_pixel(ox + 9, oy + 11, DB32.light_green),
		func(ox, oy): # Цветение (зеленый колосок)
			_rect(img, ox + 7, oy + 7, 2, 8, DB32.bright_green)
			_rect(img, ox + 6, oy + 5, 4, 4, DB32.green)
			img.set_pixel(ox + 7, oy + 4, DB32.gold),
		func(ox, oy): # Золотой спелый колос
			_rect(img, ox + 7, oy + 6, 2, 9, DB32.gold)
			_rect(img, ox + 6, oy + 3, 4, 6, DB32.yellow)
			img.set_pixel(ox + 5, oy + 4, DB32.pure_white)
			img.set_pixel(ox + 9, oy + 6, DB32.pure_white)
			img.set_pixel(ox + 7, oy + 1, DB32.yellow)
	])

	# Ряд 1: Кукуруза (Corn)
	_draw_crop_row(img, 1, [
		func(ox, oy): # Росток
			_rect(img, ox + 7, oy + 13, 2, 2, DB32.lime)
			img.set_pixel(ox + 6, oy + 12, DB32.bright_green)
			img.set_pixel(ox + 9, oy + 12, DB32.bright_green),
		func(ox, oy): # Высокий стебель с листьями
			_rect(img, ox + 7, oy + 8, 2, 7, DB32.forest_green)
			_rect(img, ox + 4, oy + 10, 3, 2, DB32.bright_green)
			_rect(img, ox + 9, oy + 9, 3, 2, DB32.bright_green),
		func(ox, oy): # Початки
			_rect(img, ox + 7, oy + 5, 2, 10, DB32.forest_green)
			_rect(img, ox + 5, oy + 8, 2, 3, DB32.yellow)
			_rect(img, ox + 9, oy + 7, 2, 3, DB32.yellow),
		func(ox, oy): # Спелая кукуруза
			_rect(img, ox + 7, oy + 3, 2, 12, DB32.forest_green)
			_rect(img, ox + 5, oy + 6, 3, 5, DB32.yellow)
			_rect(img, ox + 9, oy + 7, 3, 4, DB32.gold)
			img.set_pixel(ox + 6, oy + 5, DB32.brown) # рыльца початка
			img.set_pixel(ox + 7, oy + 1, DB32.gold)  # метелка
	])

	# Ряд 2: Подсолнух (Sunflower)
	_draw_crop_row(img, 2, [
		func(ox, oy): # Росток
			_rect(img, ox + 7, oy + 13, 2, 2, DB32.green)
			_circle(img, ox + 8, oy + 12, 1, DB32.bright_green),
		func(ox, oy): # Стебель с бутоном
			_rect(img, ox + 7, oy + 7, 2, 8, DB32.green)
			_circle(img, ox + 8, oy + 6, 2, DB32.forest_green),
		func(ox, oy): # Раскрывающийся цветок
			_rect(img, ox + 7, oy + 5, 2, 10, DB32.green)
			_circle(img, ox + 8, oy + 4, 3, DB32.yellow)
			img.set_pixel(ox + 8, oy + 4, DB32.dark_brown),
		func(ox, oy): # Большой зрелый подсолнух
			_rect(img, ox + 7, oy + 5, 2, 10, DB32.forest_green)
			_circle(img, ox + 8, oy + 4, 4, DB32.yellow)
			_circle(img, ox + 8, oy + 4, 2, DB32.dark_brown)
			img.set_pixel(ox + 8, oy + 4, DB32.black)
	])

	# Ряд 3: Морковь (Carrot)
	_draw_crop_row(img, 3, [
		func(ox, oy): # Пучок
			img.set_pixel(ox + 8, oy + 14, DB32.bright_green),
		func(ox, oy): # Ботва
			_rect(img, ox + 7, oy + 11, 2, 4, DB32.bright_green)
			img.set_pixel(ox + 6, oy + 12, DB32.light_green)
			img.set_pixel(ox + 9, oy + 12, DB32.light_green),
		func(ox, oy): # Зелень и оранжевый носик
			_rect(img, ox + 6, oy + 8, 4, 5, DB32.bright_green)
			_rect(img, ox + 7, oy + 13, 2, 2, DB32.orange),
		func(ox, oy): # Крупная морковь
			_rect(img, ox + 5, oy + 6, 6, 6, DB32.bright_green)
			_rect(img, ox + 6, oy + 11, 4, 4, DB32.orange)
			_rect(img, ox + 7, oy + 13, 2, 2, DB32.warm_brown)
			img.set_pixel(ox + 7, oy + 12, DB32.yellow)
	])

	return img

static func _draw_crop_row(img: Image, row: int, stages: Array) -> void:
	var oy: int = row * 16
	for col in range(4):
		var ox: int = col * 16
		stages[col].call(ox, oy)


# ==============================================================================
# 11. ОБЪЕКТЫ КРИЗИСОВ И ЗАЩИТЫ (128x32)
# ==============================================================================
static func _generate_crisis_objects() -> Image:
	var img: Image = Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Плакат STRIKE (16x16 в [0, 0])
	_rect(img, 7, 7, 2, 9, DB32.wood_brown) # палка
	_rect(img, 1, 1, 14, 8, DB32.pure_white) # табличка
	_rect(img, 2, 2, 12, 6, DB32.white)
	# Пиксельный текст 'STRIKE' красным
	_rect(img, 3, 3, 2, 1, DB32.red)
	_rect(img, 6, 3, 2, 1, DB32.red)
	_rect(img, 9, 3, 2, 1, DB32.red)
	_rect(img, 3, 5, 10, 1, DB32.red)

	# 2. Ворона (4 кадра по 16x16 в [16..79, 0..15])
	# Кадр 0: полет крылья вверх
	var ox: int = 16
	_circle(img, ox + 7, 8, 2, DB32.charcoal)
	img.set_pixel(ox + 10, 8, DB32.gold) # клюв
	img.set_pixel(ox + 5, 5, DB32.black) # крылья вверх
	img.set_pixel(ox + 7, 4, DB32.black)

	# Кадр 1: полет крылья вниз
	ox = 32
	_circle(img, ox + 7, 8, 2, DB32.charcoal)
	img.set_pixel(ox + 10, 8, DB32.gold)
	img.set_pixel(ox + 5, 11, DB32.black) # крылья вниз
	img.set_pixel(ox + 7, 12, DB32.black)

	# Кадр 2: сидящая ворона
	ox = 48
	_rect(img, ox + 5, 8, 5, 4, DB32.charcoal)
	_circle(img, ox + 9, 7, 2, DB32.black)
	img.set_pixel(ox + 12, 7, DB32.gold)
	_rect(img, ox + 6, 12, 1, 2, DB32.slate)
	_rect(img, ox + 8, 12, 1, 2, DB32.slate)

	# Кадр 3: клюющая зерно
	ox = 64
	_rect(img, ox + 5, 9, 5, 3, DB32.charcoal)
	_circle(img, ox + 10, 10, 2, DB32.black)
	img.set_pixel(ox + 12, 12, DB32.gold) # клюв в землю
	_rect(img, ox + 6, 12, 1, 2, DB32.slate)

	# 3. Пугало (Scarecrow) (16x16 в [80, 0])
	ox = 80
	_rect(img, ox + 7, 2, 2, 14, DB32.wood_brown) # шест
	_rect(img, ox + 3, 5, 10, 2, DB32.wood_brown) # перекладина
	_circle(img, ox + 8, 4, 2, DB32.sand)         # голова из мешковины
	_rect(img, ox + 5, 2, 6, 1, DB32.warm_brown)  # шляпа
	_rect(img, ox + 4, 6, 8, 5, DB32.forest_green)# старая рубаха
	img.set_pixel(ox + 3, 7, DB32.yellow)         # солома из рукава
	img.set_pixel(ox + 12, 7, DB32.yellow)

	# 4. Собака (Dog) (2 кадра по 16x16 в [96..127, 0..15])
	ox = 96
	# Кадр 0: сидит/на страже
	_rect(img, ox + 5, 7, 6, 5, DB32.warm_brown)
	_circle(img, ox + 11, 6, 2, DB32.sand)
	img.set_pixel(ox + 12, 6, DB32.black) # нос
	img.set_pixel(ox + 10, 4, DB32.brown) # ухо
	_rect(img, ox + 5, 12, 2, 3, DB32.warm_brown)
	_rect(img, ox + 9, 12, 2, 3, DB32.warm_brown)
	img.set_pixel(ox + 3, 8, DB32.warm_brown) # хвост вверх

	# Кадр 1: бег/лай
	ox = 112
	_rect(img, ox + 4, 8, 7, 4, DB32.warm_brown)
	_circle(img, ox + 11, 7, 2, DB32.sand)
	img.set_pixel(ox + 13, 7, DB32.red)   # открытая пасть
	_rect(img, ox + 3, 11, 2, 3, DB32.warm_brown)
	_rect(img, ox + 10, 11, 2, 3, DB32.warm_brown)

	# 5. Дым и огонь поломки техники (ряд снизу, 4 кадра 16x16 в [0..63, 16..31])
	for f in range(4):
		var fx: int = f * 16
		var fy: int = 16
		# Клубы черного дыма
		_circle(img, fx + 8, fy + 6, 3 + (f % 2), DB32.charcoal)
		_circle(img, fx + 5, fy + 8, 2, DB32.slate)
		_circle(img, fx + 11, fy + 7, 2, DB32.slate)
		# Языки пламени у основания
		_circle(img, fx + 8, fy + 12, 2, DB32.red)
		img.set_pixel(fx + 8, fy + 11, DB32.yellow)
		img.set_pixel(fx + 7, fy + 12, DB32.orange)

	return img


# ==============================================================================
# 12. ЧАСТИЦЫ (32x32)
# ==============================================================================
static func _generate_particles() -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Капля воды (4x4 в [0, 0])
	img.set_pixel(1, 0, DB32.cyan)
	_rect(img, 0, 1, 3, 2, DB32.light_blue)
	img.set_pixel(1, 3, DB32.deep_blue)

	# Зернышко (3x3 в [8, 0])
	_rect(img, 8, 1, 3, 2, DB32.gold)
	img.set_pixel(9, 0, DB32.yellow)

	# Комок земли / пыль (4x4 в [16, 0])
	_circle(img, 18, 2, 2, DB32.wood_brown)
	img.set_pixel(17, 1, DB32.dark_brown)

	# Искра ремонта (шестеренка/крестик в [24, 0])
	img.set_pixel(26, 0, DB32.yellow)
	_rect(img, 24, 2, 5, 1, DB32.pure_white)
	img.set_pixel(26, 4, DB32.yellow)

	# Нота / сердечко (8x8 в [0, 8])
	_rect(img, 1, 9, 2, 2, DB32.pink)
	_rect(img, 4, 9, 2, 2, DB32.pink)
	_rect(img, 2, 11, 3, 2, DB32.red)
	img.set_pixel(3, 13, DB32.crimson)

	return img


# ==============================================================================
# 13. ПОЛНОЦЕННЫЙ ДЫМ И ОГОНЬ ПОЛОМКИ (64x32: 4 кадра по 16x32)
# ==============================================================================
static func _generate_smoke_fire_sheet() -> Image:
	var img: Image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for f in range(4):
		var ox: int = f * 16

		# Языки пламени внизу (y: 20..31)
		_circle(img, ox + 8, 26, 3, DB32.red)
		_circle(img, ox + 6 + (f % 2) * 3, 24, 2, DB32.orange)
		_circle(img, ox + 8, 23, 2, DB32.yellow)
		_safe_pixel(img, ox + 8, 21, DB32.pure_white)

		# Клубы черного и темно-серого дыма, поднимающиеся вверх (y: 0..20)
		var smoke_y: int = 16 - f * 3
		_circle(img, ox + 8, smoke_y, 4 + (f % 2), DB32.charcoal)
		_circle(img, ox + 5, smoke_y - 3, 3, DB32.slate)
		_circle(img, ox + 11, smoke_y - 2, 3, DB32.dark_grey)
		_circle(img, ox + 8, smoke_y - 6, 2, DB32.light_grey)

	return img


# ==============================================================================
# 14. КОСТЕР ДЛЯ НОЧИ (64x16: 4 кадра по 16x16)
# ==============================================================================
static func _generate_campfire() -> Image:
	var img: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for f in range(4):
		var ox: int = f * 16

		# Бревна и камни очага
		_rect(img, ox + 3, 13, 10, 2, DB32.wood_brown)
		_rect(img, ox + 5, 12, 6, 2, DB32.dark_brown)
		_safe_pixel(img, ox + 2, 14, DB32.slate)
		_safe_pixel(img, ox + 13, 14, DB32.slate)

		# Угли
		_rect(img, ox + 6, 12, 4, 1, DB32.red)

		# Пламя (анимированное 4 кадра)
		_circle(img, ox + 8, 9, 3, DB32.orange)
		match f:
			0:
				_rect(img, ox + 7, 5, 2, 4, DB32.yellow)
				_safe_pixel(img, ox + 7, 4, DB32.pure_white)
				_safe_pixel(img, ox + 9, 2, DB32.yellow) # искра
			1:
				_rect(img, ox + 6, 6, 3, 4, DB32.yellow)
				_safe_pixel(img, ox + 8, 3, DB32.pure_white)
				_safe_pixel(img, ox + 6, 2, DB32.yellow)
			2:
				_rect(img, ox + 7, 6, 3, 4, DB32.yellow)
				_safe_pixel(img, ox + 7, 4, DB32.pure_white)
				_safe_pixel(img, ox + 10, 3, DB32.yellow)
			3:
				_rect(img, ox + 8, 5, 2, 4, DB32.yellow)
				_safe_pixel(img, ox + 8, 3, DB32.pure_white)
				_safe_pixel(img, ox + 7, 1, DB32.yellow)

	return img


# ==============================================================================
# 15. НАВЕС ОТ НЕПОГОДЫ (48x32)
# ==============================================================================
static func _generate_canopy() -> Image:
	var img: Image = Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Деревянные опорные столбы
	_rect(img, 4, 10, 3, 22, DB32.wood_brown)
	_rect(img, 41, 10, 3, 22, DB32.wood_brown)
	_rect(img, 22, 10, 2, 22, DB32.dark_brown)

	# Скамейка внутри навеса
	_rect(img, 10, 24, 26, 3, DB32.sand)
	_rect(img, 12, 27, 2, 5, DB32.dark_brown)
	_rect(img, 32, 27, 2, 5, DB32.dark_brown)

	# Верхняя балка
	_rect(img, 2, 8, 44, 3, DB32.dark_brown)

	# Покатая крыша (черепица / доски)
	for y in range(0, 8):
		var indent: int = 7 - y
		_rect(img, indent, y, 48 - indent * 2, 1, DB32.red if y % 2 == 0 else DB32.crimson)
	_rect(img, 20, 0, 8, 2, DB32.yellow) # конек крыши

	return img


# ==============================================================================
# 16. БРЫЗГИ ГРЯЗИ ПРИ БУКСОВАНИИ (64x16: 4 кадра по 16x16)
# ==============================================================================
static func _generate_mud_splash() -> Image:
	var img: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for f in range(4):
		var ox: int = f * 16
		# Грязевая лужа у колеса
		_rect(img, ox + 3, 14, 11, 2, DB32.dark_brown)
		_rect(img, ox + 5, 13, 7, 1, DB32.brown)

		# Фонтан летящей грязи назад и вверх
		match f:
			0:
				_safe_pixel(img, ox + 2, 11, DB32.dark_brown)
				_safe_pixel(img, ox + 1, 9, DB32.brown)
				_safe_pixel(img, ox + 4, 10, DB32.wood_brown)
			1:
				_rect(img, ox + 1, 8, 2, 2, DB32.dark_brown)
				_safe_pixel(img, ox + 0, 6, DB32.brown)
				_safe_pixel(img, ox + 3, 7, DB32.wood_brown)
				_safe_pixel(img, ox + 5, 10, DB32.dark_brown)
			2:
				_rect(img, ox + 0, 5, 3, 2, DB32.dark_brown)
				_safe_pixel(img, ox + 2, 3, DB32.brown)
				_safe_pixel(img, ox + 4, 6, DB32.wood_brown)
				_safe_pixel(img, ox + 6, 9, DB32.dark_brown)
			3:
				_safe_pixel(img, ox + 1, 4, DB32.brown)
				_safe_pixel(img, ox + 3, 6, DB32.dark_brown)
				_safe_pixel(img, ox + 5, 8, DB32.wood_brown)
				_safe_pixel(img, ox + 7, 11, DB32.dark_brown)

	return img


# ==============================================================================
# 17. СЕЯТЕЛИ НА ОТДЫХЕ / ПОД НАВЕСОМ (64x16: 4 кадра по 16x16)
# ==============================================================================
static func _generate_workers_rest() -> Image:
	var img: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for f in range(4):
		var ox: int = f * 16

		# Шляпа и голова (сидящий персонаж)
		_rect(img, ox + 4, 3, 8, 2, DB32.sand)
		_rect(img, ox + 6, 5, 4, 3, DB32.light_sand)
		_safe_pixel(img, ox + 8, 6, DB32.dark_brown)

		# Сидящее тело в комбинезоне
		_rect(img, ox + 5, 8, 6, 5, DB32.grey)
		_rect(img, ox + 4, 12, 7, 3, DB32.deep_blue)
		_rect(img, ox + 9, 14, 3, 2, DB32.dark_brown) # ботинки вперед

		match f:
			0: # Греет руки у огня
				_rect(img, ox + 11, 9, 3, 2, DB32.light_sand)
			1: # Пьет из кружки
				_rect(img, ox + 9, 7, 2, 2, DB32.pure_white)
			2: # Укрылся от непогоды
				_rect(img, ox + 4, 7, 8, 5, DB32.wood_brown) # плащ
			3: # Машет рукой
				_rect(img, ox + 10, 4, 2, 4, DB32.light_sand)

	return img


# ==============================================================================
# 18. ВЕТРЯНАЯ МЕЛЬНИЦА (96x48)
# ==============================================================================
static func _generate_windmill() -> Image:
	var img: Image = Image.create(96, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Башня мельницы (слева, 32x48)
	for y in range(12, 48):
		var w: int = 14 + int(float(y - 12) * 0.3)
		var x0: int = 16 - w / 2
		_rect(img, x0, y, w, 1, DB32.sand if y % 4 != 0 else DB32.wood_brown)

	# Дверь и окно башни
	_rect(img, 14, 36, 6, 12, DB32.dark_brown)
	_rect(img, 14, 20, 5, 5, DB32.light_blue)
	_rect(img, 14, 20, 5, 1, DB32.dark_brown)
	_rect(img, 16, 20, 1, 5, DB32.dark_brown)

	# Конусная крыша
	for y in range(2, 12):
		var rw: int = (y - 2) * 2 + 2
		_rect(img, 16 - rw / 2, y, rw, 1, DB32.red)

	# Ступица лопастей
	_circle(img, 16, 14, 3, DB32.dark_grey)
	_safe_pixel(img, 16, 14, DB32.yellow)

	# 2 кадра вращения лопастей (справа, 32x32 в [32..63, 0..31] и [64..95, 0..31])
	for frame in range(2):
		var fx: int = 32 + frame * 32
		var cx: int = fx + 16
		var cy: int = 16
		_circle(img, cx, cy, 2, DB32.dark_grey)

		if frame == 0:
			# Прямой крест
			_rect(img, cx - 1, cy - 14, 2, 28, DB32.wood_brown)
			_rect(img, cx - 14, cy - 1, 28, 2, DB32.wood_brown)
			# Паруса на лопастях
			_rect(img, cx + 1, cy - 12, 4, 10, DB32.pure_white)
			_rect(img, cx - 5, cy + 2, 4, 10, DB32.pure_white)
			_rect(img, cx + 2, cy + 1, 10, 4, DB32.pure_white)
			_rect(img, cx - 12, cy - 5, 10, 4, DB32.pure_white)
		else:
			# Диагональный крест (поворот 45 градусов)
			for d in range(-12, 13):
				_safe_pixel(img, cx + d, cy + d, DB32.wood_brown)
				_safe_pixel(img, cx + d, cy - d, DB32.wood_brown)
				_safe_pixel(img, cx + d + 1, cy + d, DB32.pure_white)
				_safe_pixel(img, cx + d, cy - d - 1, DB32.pure_white)

	return img


# ==============================================================================
# 19. АМБАР (BARN) (48x36)
# ==============================================================================
static func _generate_barn() -> Image:
	var img: Image = Image.create(48, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Красные деревянные стены
	_rect(img, 4, 12, 40, 24, DB32.crimson)
	for y in range(12, 36, 4):
		_rect(img, 4, y, 40, 1, DB32.red)

	# Большие амбарные ворота с белой крестовиной
	_rect(img, 16, 20, 16, 16, DB32.dark_brown)
	_rect(img, 17, 21, 14, 14, DB32.white)
	_rect(img, 17, 21, 14, 1, DB32.crimson)
	_rect(img, 17, 34, 14, 1, DB32.crimson)
	_rect(img, 17, 21, 1, 14, DB32.crimson)
	_rect(img, 30, 21, 1, 14, DB32.crimson)
	# Крест на воротах
	for d in range(14):
		_safe_pixel(img, 17 + d, 21 + d, DB32.crimson)
		_safe_pixel(img, 17 + d, 34 - d, DB32.crimson)

	# Чердачное окно сеновала
	_rect(img, 20, 13, 8, 6, DB32.dark_brown)
	_rect(img, 21, 14, 6, 2, DB32.yellow) # торчит сено

	# Ломаная крыша амбара
	for y in range(4, 13):
		var w: int = 46 - (12 - y) * 2
		_rect(img, 24 - w / 2, y, w, 1, DB32.dark_grey if y % 2 == 0 else DB32.slate)
	_rect(img, 22, 2, 4, 3, DB32.charcoal)
	# Флюгер-петух на крыше
	_safe_pixel(img, 24, 0, DB32.gold)
	_safe_pixel(img, 23, 1, DB32.gold)
	_safe_pixel(img, 25, 1, DB32.gold)

	return img


# ==============================================================================
# 20. ДЕКОРАЦИИ ФОНА (128x32)
# ==============================================================================
static func _generate_decorations() -> Image:
	var img: Image = Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Деревянный заборчик (в [0..15, 16..31])
	_rect(img, 2, 18, 2, 14, DB32.wood_brown)
	_rect(img, 8, 18, 2, 14, DB32.wood_brown)
	_rect(img, 14, 18, 2, 14, DB32.wood_brown)
	_rect(img, 0, 21, 16, 2, DB32.sand)
	_rect(img, 0, 27, 16, 2, DB32.sand)

	# 2. Белый штакетник (в [16..31, 16..31])
	for f in range(4):
		var fx: int = 16 + f * 4
		_rect(img, fx, 18, 3, 14, DB32.pure_white)
		_safe_pixel(img, fx + 1, 17, DB32.pure_white) # заостренный вершок
	_rect(img, 16, 22, 16, 2, DB32.light_grey)
	_rect(img, 16, 27, 16, 2, DB32.light_grey)

	# 3. Фонарный столб дневной (в [32..47, 0..31])
	_rect(img, 39, 6, 2, 26, DB32.charcoal)
	_rect(img, 37, 4, 6, 2, DB32.dark_grey)
	_rect(img, 38, 6, 4, 4, DB32.cyan) # стекло

	# 4. Фонарный столб ночной горящий (в [48..63, 0..31])
	_rect(img, 55, 6, 2, 26, DB32.charcoal)
	_rect(img, 53, 4, 6, 2, DB32.dark_grey)
	_rect(img, 54, 6, 4, 4, DB32.yellow)     # светящийся фонарь
	_safe_pixel(img, 55, 7, DB32.pure_white) # нить накала
	# Мягкое свечение вокруг
	_circle(img, 56, 8, 4, Color(DB32.yellow.r, DB32.yellow.g, DB32.yellow.b, 0.25))

	# 5. Цветочные клумбы (в [64..79, 16..31])
	_rect(img, 64, 26, 16, 6, DB32.dark_brown)
	for i in range(5):
		var cx: int = 65 + i * 3
		_rect(img, cx, 23, 1, 4, DB32.bright_green)
		var flower_col: Color = DB32.pink if i % 2 == 0 else DB32.yellow
		_rect(img, cx - 1, 21, 3, 2, flower_col)
		_safe_pixel(img, cx, 21, DB32.pure_white)

	# 6. Декоративное дерево / куст (в [80..103, 8..31])
	_rect(img, 91, 22, 3, 10, DB32.dark_brown)
	_circle(img, 92, 16, 7, DB32.forest_green)
	_circle(img, 90, 14, 5, DB32.bright_green)
	_circle(img, 95, 15, 4, DB32.green)
	_safe_pixel(img, 89, 13, DB32.red) # яблоко
	_safe_pixel(img, 93, 16, DB32.red)

	return img


# ==============================================================================
# 21. ПОГОДНЫЕ ЧАСТИЦЫ (32x32: снег, град, ветер, ливень)
# ==============================================================================
static func _generate_weather_particles() -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Снежинка (в [0, 0..7])
	_rect(img, 1, 0, 1, 5, DB32.pure_white)
	_rect(img, 0, 2, 3, 1, DB32.pure_white)
	_safe_pixel(img, 1, 2, DB32.cyan)

	# Градина (в [8, 0..7])
	_circle(img, 10, 2, 2, DB32.cyan)
	_safe_pixel(img, 9, 1, DB32.pure_white)

	# Листок ветра (в [16, 0..7])
	_rect(img, 16, 1, 3, 2, DB32.forest_green)
	_safe_pixel(img, 18, 0, DB32.bright_green)
	_safe_pixel(img, 19, 2, DB32.lime)

	# Струя ливня (в [24, 0..7])
	_rect(img, 25, 0, 1, 6, DB32.light_blue)
	_safe_pixel(img, 25, 6, DB32.cyan)

	return img


# ==============================================================================
# 22. ТЯЖЕЛЫЙ ТРАКТОР К-7М «КИРОВЕЦ» (96x20, 2 кадра по 48x20)
# ==============================================================================
static func _generate_tractor_v2() -> Image:
	var img: Image = Image.create(96, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(2):
		var ox: int = frame * 48

		# 1. Рама и противовес спереди
		_rect(img, ox + 6, 14, 38, 2, DB32.charcoal)
		_rect(img, ox + 39, 10, 4, 5, DB32.dark_grey) # передний балласт

		# 2. Массивный капот двигателя К-7М (терракотово-оранжевый)
		_rect(img, ox + 22, 6, 17, 8, DB32.warm_brown)
		_rect(img, ox + 24, 5, 14, 1, DB32.orange)
		_rect(img, ox + 37, 7, 2, 6, DB32.charcoal)   # решетка радиатора
		_rect(img, ox + 37, 9, 2, 2, DB32.yellow)     # спаренная LED фара
		_rect(img, ox + 26, 7, 9, 1, DB32.charcoal)   # воздухозаборник
		_rect(img, ox + 26, 9, 9, 1, DB32.charcoal)

		# 3. Выхлопная труба и анимация выхлопа
		_rect(img, ox + 23, 2, 2, 5, DB32.slate)
		_rect(img, ox + 22, 1, 3, 1, DB32.charcoal)
		if frame == 0:
			_safe_pixel(img, ox + 23, 0, DB32.light_grey)
		else:
			_rect(img, ox + 22, 0, 3, 1, DB32.light_grey)
			_safe_pixel(img, ox + 21, 0, DB32.slate)

		# 4. Просторная кабина
		_rect(img, ox + 10, 3, 12, 11, DB32.pure_white)
		_rect(img, ox + 11, 4, 10, 6, DB32.cyan)       # панорамные тонированные стекла
		_rect(img, ox + 14, 4, 1, 6, DB32.charcoal)   # стойка окна
		_rect(img, ox + 9, 2, 14, 2, DB32.pure_white)  # крыша
		# Проблесковый оранжевый маячок на крыше
		_rect(img, ox + 15, 0, 2, 2, DB32.orange if frame == 0 else DB32.yellow)

		# 5. Огромный 8-корпусный плуг сзади (ox + 0 .. ox + 8)
		_rect(img, ox + 6, 11, 4, 3, DB32.charcoal)   # гидронавеска
		_rect(img, ox + 1, 13, 7, 2, DB32.slate)      # балка плуга
		_rect(img, ox + 0, 14, 3, 4, DB32.charcoal)   # лемех 1
		_rect(img, ox + 3, 15, 3, 4, DB32.charcoal)   # лемех 2
		_safe_pixel(img, ox + 1, 17, DB32.pure_white if frame == 1 else DB32.slate) # блеск лезвия

		# 6. Огромные спаренные колеса (радиус 5, диаметр 11)
		# Заднее колесо
		_circle(img, ox + 14, 14, 5, DB32.charcoal)
		_circle(img, ox + 14, 14, 2, DB32.yellow)
		# Переднее колесо
		_circle(img, ox + 32, 14, 5, DB32.charcoal)
		_circle(img, ox + 32, 14, 2, DB32.yellow)

		# Протекторы шин (поворот колес в 2 кадрах)
		if frame == 0:
			_safe_pixel(img, ox + 14, 9, DB32.slate)
			_safe_pixel(img, ox + 14, 19, DB32.slate)
			_safe_pixel(img, ox + 9, 14, DB32.slate)
			_safe_pixel(img, ox + 19, 14, DB32.slate)

			_safe_pixel(img, ox + 32, 9, DB32.slate)
			_safe_pixel(img, ox + 32, 19, DB32.slate)
			_safe_pixel(img, ox + 27, 14, DB32.slate)
			_safe_pixel(img, ox + 37, 14, DB32.slate)
		else:
			_safe_pixel(img, ox + 11, 11, DB32.slate)
			_safe_pixel(img, ox + 17, 17, DB32.slate)
			_safe_pixel(img, ox + 11, 17, DB32.slate)
			_safe_pixel(img, ox + 17, 11, DB32.slate)

			_safe_pixel(img, ox + 29, 11, DB32.slate)
			_safe_pixel(img, ox + 35, 17, DB32.slate)
			_safe_pixel(img, ox + 29, 17, DB32.slate)
			_safe_pixel(img, ox + 35, 11, DB32.slate)

	return img


# ==============================================================================
# 23. РОТОРНЫЙ КОМБАЙН «CLAAS LEXION 8900» (160x24, 4 кадра по 40x24)
# ==============================================================================
static func _generate_harvester_v2() -> Image:
	var img: Image = Image.create(160, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(4):
		var ox: int = frame * 40

		# 1. Корпус CLAAS Lexion (фирменный белый + яркий салатово-зеленый)
		_rect(img, ox + 6, 4, 25, 14, DB32.bright_green)
		_rect(img, ox + 6, 2, 22, 4, DB32.pure_white)

		# 2. Зерновой бункер сверху с золотым зерном
		_rect(img, ox + 10, 3, 14, 4, DB32.gold)
		_rect(img, ox + 12, 2, 10, 2, DB32.yellow)

		# 3. Длинный поворотный выгрузной шнек сзади
		_rect(img, ox + 1, 2, 9, 2, DB32.pure_white)
		_rect(img, ox + 0, 1, 2, 4, DB32.charcoal)

		# 4. Панорамная кабина Lexion спереди
		_rect(img, ox + 23, 4, 9, 8, DB32.cyan)
		_rect(img, ox + 22, 2, 11, 2, DB32.pure_white) # крыша кабины со спойлером
		_rect(img, ox + 30, 4, 2, 8, DB32.charcoal)   # передняя стойка
		_rect(img, ox + 29, 10, 3, 2, DB32.yellow)    # светодиодные фары
		# Маячок на крыше (мигает 4 кадра)
		_safe_pixel(img, ox + 27, 1, DB32.yellow if (frame % 2 == 0) else DB32.orange)

		# 5. Наклонная камера к жатке
		_rect(img, ox + 28, 12, 7, 5, DB32.charcoal)

		# 6. Роторное мотовило жатки с 4-кадровым вращением (ox + 35, y: 16)
		var rx: int = ox + 35
		var ry: int = 16
		_circle(img, rx, ry, 4, DB32.bright_green)
		_safe_pixel(img, rx, ry, DB32.charcoal)
		match frame:
			0:
				_rect(img, rx - 4, ry, 9, 1, DB32.pure_white)
				_rect(img, rx, ry - 4, 1, 9, DB32.pure_white)
			1:
				_safe_pixel(img, rx - 3, ry - 3, DB32.yellow)
				_safe_pixel(img, rx + 3, ry + 3, DB32.yellow)
				_safe_pixel(img, rx - 3, ry + 3, DB32.yellow)
				_safe_pixel(img, rx + 3, ry - 3, DB32.yellow)
			2:
				_rect(img, rx - 4, ry, 9, 1, DB32.yellow)
				_rect(img, rx, ry - 4, 1, 9, DB32.yellow)
			3:
				_safe_pixel(img, rx - 3, ry - 3, DB32.pure_white)
				_safe_pixel(img, rx + 3, ry + 3, DB32.pure_white)
				_safe_pixel(img, rx - 3, ry + 3, DB32.pure_white)
				_safe_pixel(img, rx + 3, ry - 3, DB32.pure_white)

		# 7. Колеса (переднее спаренное Terra Trac диаметром 11, заднее диаметром 7)
		# Переднее ведущее колесо
		_circle(img, ox + 25, 18, 5, DB32.charcoal)
		_circle(img, ox + 25, 18, 2, DB32.yellow)
		# Заднее управляемое колесо
		_circle(img, ox + 11, 19, 4, DB32.charcoal)
		_circle(img, ox + 11, 19, 1, DB32.yellow)

	return img


# ==============================================================================
# 24. МАГИСТРАЛЬНЫЙ АВТОПОЕЗД-ЗЕРНОВОЗ «КАМАЗ 65207» (192x20, 4 кадра по 48x20)
# ==============================================================================
static func _generate_truck_v2() -> Image:
	var img: Image = Image.create(192, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for frame in range(4):
		var ox: int = frame * 48

		# 1. Шасси тягача и прицепа
		_rect(img, ox + 2, 14, 44, 2, DB32.charcoal)
		# Сцепка между кузовом тягача и прицепом (ox + 17 .. ox + 21)
		_rect(img, ox + 17, 14, 4, 1, DB32.slate)

		# 2. Кабина КАМАЗ 65207 спереди (ox + 35 .. ox + 46)
		_rect(img, ox + 36, 4, 10, 11, DB32.deep_blue)
		_rect(img, ox + 35, 2, 12, 3, DB32.pure_white) # аэродинамический спойлер
		_rect(img, ox + 40, 5, 6, 5, DB32.cyan)        # лобовое и боковое стекло
		_rect(img, ox + 44, 10, 2, 3, DB32.yellow)     # двойные фары
		_rect(img, ox + 40, 11, 4, 3, DB32.charcoal)   # решетка радиатора
		_rect(img, ox + 36, 2, 2, 3, DB32.slate)      # вертикальный выхлоп

		# 3. Кузов 1 (на тягаче: ox + 21 .. ox + 35, y: 7..14)
		_rect(img, ox + 21, 7, 14, 8, DB32.slate)
		_rect(img, ox + 21, 13, 14, 1, DB32.yellow)    # светоотражающая полоса
		_rect(img, ox + 21, 7, 1, 8, DB32.charcoal)
		_rect(img, ox + 34, 7, 1, 8, DB32.charcoal)

		# 4. Кузов 2 (прицеп: ox + 2 .. ox + 17, y: 7..14)
		_rect(img, ox + 2, 7, 15, 8, DB32.slate)
		_rect(img, ox + 2, 13, 15, 1, DB32.yellow)     # светоотражающая полоса
		_rect(img, ox + 2, 7, 1, 8, DB32.charcoal)
		_rect(img, ox + 16, 7, 1, 8, DB32.charcoal)

		# 5. Заполнение зерном обоих кузовов (4 стадии)
		if frame >= 1:
			_rect(img, ox + 4, 11, 11, 3, DB32.gold)
			_rect(img, ox + 23, 11, 10, 3, DB32.gold)
		if frame >= 2:
			_rect(img, ox + 4, 9, 11, 3, DB32.yellow)
			_rect(img, ox + 23, 9, 10, 3, DB32.yellow)
		if frame == 3:
			_rect(img, ox + 5, 7, 9, 2, DB32.yellow)
			_rect(img, ox + 7, 6, 5, 1, DB32.pure_white)
			_rect(img, ox + 24, 7, 8, 2, DB32.yellow)
			_rect(img, ox + 26, 6, 4, 1, DB32.pure_white)

		# 6. Колеса автопоезда (5 осей, диаметр 7)
		# Прицеп (2 оси)
		_circle(img, ox + 6, 16, 3, DB32.charcoal)
		_circle(img, ox + 6, 16, 1, DB32.light_grey)
		_circle(img, ox + 13, 16, 3, DB32.charcoal)
		_circle(img, ox + 13, 16, 1, DB32.light_grey)
		# Тягач задняя тележка (2 оси)
		_circle(img, ox + 25, 16, 3, DB32.charcoal)
		_circle(img, ox + 25, 16, 1, DB32.light_grey)
		_circle(img, ox + 32, 16, 3, DB32.charcoal)
		_circle(img, ox + 32, 16, 1, DB32.light_grey)
		# Тягач передняя рулевая ось (1 ось)
		_circle(img, ox + 42, 16, 3, DB32.charcoal)
		_circle(img, ox + 42, 16, 1, DB32.light_grey)

	return img

