class_name FarmHQ
extends Window

const GameManager = preload("res://scripts/GameManager.gd")
const SettingsManager = preload("res://scripts/SettingsManager.gd")
const WindowManager = preload("res://scripts/WindowManager.gd")

signal monitor_selected(screen_index: int)
signal graphics_mode_selected(mode: String)
signal fps_selected(fps: int)
signal tractor_color_changed(color: Color)
signal repair_requested
signal bankruptcy_requested

# UI ноды
@onready var coins_label: Label = $VBox/Header/HBoxCoins/CoinsValue
@onready var btn_emergency_repair: Button = $VBox/Header/BtnEmergencyRepair
@onready var tab_container: TabContainer = $VBox/TabContainer

# Магазин семян
@onready var seed_container: VBoxContainer = $VBox/TabContainer/Магазин/ScrollSeeds/VBoxSeeds

# Защита и апгрейды
@onready var btn_buy_windmill: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemWindmill/BtnBuyWindmill
@onready var btn_buy_barn: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemBarn/BtnBuyBarn
@onready var btn_buy_canopy: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemCanopy/BtnBuyCanopy
@onready var btn_buy_scarecrow: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemScarecrow/BtnBuyScarecrow
@onready var btn_buy_seeder: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemSeeder/BtnBuySeeder
@onready var btn_buy_dog: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemDog/BtnBuyDog
@onready var btn_buy_speed: Button = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemSpeed/BtnBuySpeed
@onready var lbl_speed_level: Label = $VBox/TabContainer/Улучшения/ScrollUpgrades/VBox/ItemSpeed/LblSpeedVal

# Декор и Гараж
@onready var btn_buy_heavy_tractor: Button = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/ItemHeavyTractor/HBox/BtnBuyHeavyTractor"
@onready var btn_buy_super_harvester: Button = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/ItemSuperHarvester/HBox/BtnBuySuperHarvester"
@onready var btn_buy_road_train: Button = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/ItemRoadTrain/HBox/BtnBuyRoadTrain"
@onready var color_picker: ColorPickerButton = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/HBoxColor/ColorPicker"
@onready var opt_decor: OptionButton = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/HBoxDecorSelect/OptDecor"
@onready var lbl_decor_price: Label = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/HBoxDecorBuy/LblDecorPrice"
@onready var btn_buy_decor: Button = $"VBox/TabContainer/Декор и Гараж/VBoxGarage/HBoxDecorBuy/BtnBuyDecor"

# Настройки
@onready var opt_monitors: OptionButton = $VBox/TabContainer/Настройки/VBoxSettings/HBoxMonitors/OptMonitors
@onready var check_16bit: CheckBox = $VBox/TabContainer/Настройки/VBoxSettings/HBoxGraphics/Check16bit
@onready var check_32bit: CheckBox = $VBox/TabContainer/Настройки/VBoxSettings/HBoxGraphics/Check32bit
@onready var opt_fps: OptionButton = $VBox/TabContainer/Настройки/VBoxSettings/HBoxFps/OptFps

# Финансы
@onready var lbl_total_debt: Label = $VBox/TabContainer/Финансы/VBoxFinances/HBoxDebtSummary/LblTotalDebt
@onready var lbl_subsidy_debt: Label = $VBox/TabContainer/Финансы/VBoxFinances/SubsidyBox/HBoxActions/LblSubsidyDebt
@onready var btn_take_subsidy: Button = $VBox/TabContainer/Финансы/VBoxFinances/SubsidyBox/HBoxActions/BtnTakeSubsidy
@onready var btn_repay_subsidy: Button = $VBox/TabContainer/Финансы/VBoxFinances/SubsidyBox/HBoxActions/BtnRepaySubsidy
@onready var lbl_loan_debt: Label = $VBox/TabContainer/Финансы/VBoxFinances/LoanBox/HBoxActions/LblLoanDebt
@onready var btn_take_loan: Button = $VBox/TabContainer/Финансы/VBoxFinances/LoanBox/HBoxActions/BtnTakeLoan
@onready var btn_repay_loan: Button = $VBox/TabContainer/Финансы/VBoxFinances/LoanBox/HBoxActions/BtnRepayLoan
@onready var btn_bankruptcy: Button = $VBox/TabContainer/Финансы/VBoxFinances/BankruptcyBox/BtnBankruptcy
@onready var bankruptcy_dialog: ConfirmationDialog = $BankruptcyDialog

# Статистика
@onready var lbl_stat_coins: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatCoinsVal
@onready var lbl_stat_harvests: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatHarvestsVal
@onready var lbl_stat_strikes: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatStrikesVal
@onready var lbl_stat_repairs: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatRepairsVal
@onready var lbl_stat_bankruptcies: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatBankruptciesVal
@onready var lbl_repair_status: Label = $VBox/TabContainer/Статистика/VBoxStats/HBoxRepairAction/RepairStatusLbl
@onready var btn_stat_call_repair: Button = $VBox/TabContainer/Статистика/VBoxStats/HBoxRepairAction/BtnStatCallRepair

var speed_upgrade_cost: int = 120

const DECOR_CATALOG: Dictionary = {
	"none": {"title": "Без оформления", "cost": 0},
	"fence_wood": {"title": "🪵 Деревянный забор", "cost": 150},
	"fence_white": {"title": "🏡 Белый штакетник", "cost": 250},
	"lamps": {"title": "🏮 Фонарные столбы (свет ночью)", "cost": 350},
	"flowers": {"title": "🌷 Цветочные клумбы", "cost": 200},
	"trees": {"title": "🌳 Яблоневые деревья", "cost": 300}
}

func _ready() -> void:
	close_requested.connect(_on_close_requested)
	if tab_container != null:
		tab_container.tab_changed.connect(func(_idx: int):
			_refresh_seeds_ui()
			_update_ui()
		)
	_setup_window_position()
	_setup_monitors_list()
	_setup_graphics_and_fps()
	_setup_garage_and_decor()
	_setup_upgrades_tab()
	_setup_finances_tab()
	_setup_repair_buttons()
	_refresh_seeds_ui()
	_update_ui()

func _setup_window_position() -> void:
	var screen_idx: int = SettingsManager.get_screen_index()
	if screen_idx < 0 or screen_idx >= DisplayServer.get_screen_count():
		screen_idx = DisplayServer.get_primary_screen()
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
	position = rect.position + (rect.size - size) / 2

func _on_close_requested() -> void:
	hide()

func open_hq() -> void:
	_refresh_seeds_ui()
	_update_ui()
	show()
	grab_focus()

func _setup_repair_buttons() -> void:
	var do_repair = func():
		repair_requested.emit()
		_update_ui()

	btn_emergency_repair.pressed.connect(do_repair)
	btn_stat_call_repair.pressed.connect(do_repair)

func _update_ui() -> void:
	if coins_label != null:
		coins_label.text = "%d 🪙" % GameManager.coins

	# Статус поломки или застревания в грязи
	var is_trouble: bool = GameManager.is_broken_down or GameManager.is_stuck_in_mud
	btn_emergency_repair.visible = is_trouble
	btn_stat_call_repair.disabled = not is_trouble or (GameManager.coins < 30)

	if GameManager.is_broken_down:
		lbl_repair_status.text = "Статус: ⚙ ТЕХНИКА СЛОМАЛАСЬ! ВАЛИТ ДЫМ!"
	elif GameManager.is_stuck_in_mud:
		lbl_repair_status.text = "Статус: 🌧 ТЕХНИКА ЗАСТРЯЛА В ГРЯЗИ!"
	else:
		lbl_repair_status.text = "Статус: Вся техника на ходу ✔"

	# Мельница
	if btn_buy_windmill != null:
		if GameManager.has_windmill:
			btn_buy_windmill.text = "Построено ✔"
			btn_buy_windmill.disabled = true
		else:
			btn_buy_windmill.text = "Построить (600 🪙)"
			btn_buy_windmill.disabled = GameManager.coins < 600

	# Амбар
	if btn_buy_barn != null:
		if GameManager.has_barn:
			btn_buy_barn.text = "Построено ✔"
			btn_buy_barn.disabled = true
		else:
			btn_buy_barn.text = "Построить (450 🪙)"
			btn_buy_barn.disabled = GameManager.coins < 450

	# Навес
	if btn_buy_canopy != null:
		if GameManager.canopy_count >= 2:
			btn_buy_canopy.text = "Максимум (2/2) ✔"
			btn_buy_canopy.disabled = true
		else:
			btn_buy_canopy.text = "Построить (%d/2 за 250 🪙)" % [GameManager.canopy_count]
			btn_buy_canopy.disabled = GameManager.coins < 250

	# Пугало (до 3 на монитор)
	if btn_buy_scarecrow != null:
		var max_s: int = GameManager.get_max_scarecrows()
		if GameManager.scarecrow_count >= max_s:
			btn_buy_scarecrow.text = "Максимум (%d/%d) ✔" % [GameManager.scarecrow_count, max_s]
			btn_buy_scarecrow.disabled = true
		else:
			btn_buy_scarecrow.text = "Купить (%d/%d за 150 🪙)" % [GameManager.scarecrow_count, max_s]
			btn_buy_scarecrow.disabled = GameManager.coins < 150

	# Сеялка
	if btn_buy_seeder != null:
		if GameManager.has_seeder_tractor:
			btn_buy_seeder.text = "Куплено ✔"
			btn_buy_seeder.disabled = true
		else:
			btn_buy_seeder.text = "Купить (350 🪙)"
			btn_buy_seeder.disabled = GameManager.coins < 350

	# Собака
	if btn_buy_dog != null:
		if GameManager.has_guard_dog:
			btn_buy_dog.text = "Куплено ✔"
			btn_buy_dog.disabled = true
		else:
			btn_buy_dog.text = "Купить (500 🪙)"
			btn_buy_dog.disabled = GameManager.coins < 500

	# Скорость
	if btn_buy_speed != null and lbl_speed_level != null:
		lbl_speed_level.text = "x%.2f" % GameManager.speed_multiplier
		btn_buy_speed.text = "Улучшить (+15%% за %d 🪙)" % speed_upgrade_cost
		btn_buy_speed.disabled = GameManager.coins < speed_upgrade_cost

	# Статистика
	if lbl_stat_coins != null:
		lbl_stat_coins.text = "%d 🪙" % GameManager.total_coins_earned
	if lbl_stat_harvests != null:
		lbl_stat_harvests.text = "%d" % GameManager.total_harvested
	if lbl_stat_strikes != null:
		lbl_stat_strikes.text = "%d" % GameManager.total_strikes_resolved
	if lbl_stat_repairs != null:
		lbl_stat_repairs.text = "%d" % GameManager.total_repairs_done
	if lbl_stat_bankruptcies != null:
		lbl_stat_bankruptcies.text = "%d" % GameManager.total_bankruptcies

	# Финансы
	if lbl_total_debt != null:
		lbl_total_debt.text = "%d 🪙" % GameManager.get_total_debt()
	if lbl_subsidy_debt != null:
		lbl_subsidy_debt.text = "Остаток долга: %d 🪙" % GameManager.subsidy_debt
	if btn_take_subsidy != null:
		btn_take_subsidy.disabled = (GameManager.subsidy_debt > 0)
	if btn_repay_subsidy != null:
		btn_repay_subsidy.disabled = (GameManager.subsidy_debt <= 0) or (GameManager.coins < GameManager.subsidy_debt)
		btn_repay_subsidy.text = "Погасить (%d 🪙)" % GameManager.subsidy_debt if GameManager.subsidy_debt > 0 else "Погасить досрочно"

	if lbl_loan_debt != null:
		lbl_loan_debt.text = "Остаток долга: %d 🪙" % GameManager.loan_debt
	if btn_take_loan != null:
		btn_take_loan.disabled = (GameManager.loan_debt > 0)
	if btn_repay_loan != null:
		btn_repay_loan.disabled = (GameManager.loan_debt <= 0) or (GameManager.coins < GameManager.loan_debt)
		btn_repay_loan.text = "Погасить (%d 🪙)" % GameManager.loan_debt if GameManager.loan_debt > 0 else "Погасить досрочно"

	# Модернизация автопарка (новая техника)
	if btn_buy_heavy_tractor != null:
		if GameManager.has_heavy_tractor:
			btn_buy_heavy_tractor.text = "Куплено ✔"
			btn_buy_heavy_tractor.disabled = true
		else:
			btn_buy_heavy_tractor.text = "Купить (800 🪙)"
			btn_buy_heavy_tractor.disabled = GameManager.coins < 800

	if btn_buy_super_harvester != null:
		if GameManager.has_super_harvester:
			btn_buy_super_harvester.text = "Куплено ✔"
			btn_buy_super_harvester.disabled = true
		else:
			btn_buy_super_harvester.text = "Купить (1200 🪙)"
			btn_buy_super_harvester.disabled = GameManager.coins < 1200

	if btn_buy_road_train != null:
		if GameManager.has_road_train:
			btn_buy_road_train.text = "Куплено ✔"
			btn_buy_road_train.disabled = true
		else:
			btn_buy_road_train.text = "Купить (950 🪙)"
			btn_buy_road_train.disabled = GameManager.coins < 950

func _refresh_seeds_ui() -> void:
	if seed_container == null:
		return

	for child in seed_container.get_children():
		child.queue_free()

	for crop_id in GameManager.CROPS:
		var c_data: Dictionary = GameManager.CROPS[crop_id]
		var item_panel: PanelContainer = PanelContainer.new()
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		item_panel.add_child(hbox)

		var lbl_info: Label = Label.new()
		lbl_info.text = "%s\n⏱ Рост: %.0fc | 💰 Доход: +%d 🪙" % [
			c_data.name, c_data.growth_time, c_data.base_reward
		]
		lbl_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_info)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(160, 36)

		var this_cid: String = str(crop_id)
		var this_cost: int = int(c_data.seed_cost)
		var is_unlocked: bool = bool(c_data.unlocked)

		if not is_unlocked:
			btn.text = "Открыть (%d 🪙)" % this_cost
			btn.disabled = GameManager.coins < this_cost
			btn.pressed.connect(func(target_cid: String = this_cid, target_cost: int = this_cost):
				if GameManager.spend_coins(target_cost):
					GameManager.CROPS[target_cid]["unlocked"] = true
					GameManager.current_crop = target_cid
					GameManager.save_to_settings()
					_refresh_seeds_ui()
					_update_ui()
			)
		else:
			if GameManager.current_crop == this_cid:
				btn.text = "Выбрано для сева ✔"
				btn.disabled = true
			else:
				btn.text = "Выбрать для сева"
				btn.disabled = false
				btn.pressed.connect(func(target_cid: String = this_cid):
					GameManager.current_crop = target_cid
					GameManager.save_to_settings()
					_refresh_seeds_ui()
					_update_ui()
				)

		hbox.add_child(btn)
		seed_container.add_child(item_panel)

func _setup_upgrades_tab() -> void:
	btn_buy_windmill.pressed.connect(func():
		if GameManager.spend_coins(600):
			GameManager.has_windmill = true
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_barn.pressed.connect(func():
		if GameManager.spend_coins(450):
			GameManager.has_barn = true
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_canopy.pressed.connect(func():
		if GameManager.canopy_count < 2 and GameManager.spend_coins(250):
			GameManager.canopy_count += 1
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_scarecrow.pressed.connect(func():
		var max_s: int = GameManager.get_max_scarecrows()
		if GameManager.scarecrow_count < max_s and GameManager.spend_coins(150):
			GameManager.scarecrow_count += 1
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_seeder.pressed.connect(func():
		if GameManager.spend_coins(350):
			GameManager.has_seeder_tractor = true
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_dog.pressed.connect(func():
		if GameManager.spend_coins(500):
			GameManager.has_guard_dog = true
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_speed.pressed.connect(func():
		if GameManager.spend_coins(speed_upgrade_cost):
			GameManager.speed_multiplier *= 1.15
			speed_upgrade_cost = int(speed_upgrade_cost * 1.8)
			GameManager.save_to_settings()
			_update_ui()
	)

func _setup_garage_and_decor() -> void:
	if btn_buy_heavy_tractor != null:
		btn_buy_heavy_tractor.pressed.connect(func():
			if GameManager.spend_coins(800):
				GameManager.has_heavy_tractor = true
				GameManager.save_to_settings()
				_update_ui()
		)

	if btn_buy_super_harvester != null:
		btn_buy_super_harvester.pressed.connect(func():
			if GameManager.spend_coins(1200):
				GameManager.has_super_harvester = true
				GameManager.save_to_settings()
				_update_ui()
		)

	if btn_buy_road_train != null:
		btn_buy_road_train.pressed.connect(func():
			if GameManager.spend_coins(950):
				GameManager.has_road_train = true
				GameManager.save_to_settings()
				_update_ui()
		)

	color_picker.color = GameManager.tractor_color
	color_picker.color_changed.connect(func(c: Color):
		GameManager.tractor_color = c
		GameManager.save_to_settings()
		tractor_color_changed.emit(c)
	)

	# Список декораций
	opt_decor.clear()
	var d_keys: Array = DECOR_CATALOG.keys()
	for i in range(d_keys.size()):
		var k: String = d_keys[i]
		var info: Dictionary = DECOR_CATALOG[k]
		opt_decor.add_item(info.title, i)
		opt_decor.set_item_metadata(i, k)
		if k == GameManager.active_decoration:
			opt_decor.selected = i

	_update_decor_ui()
	opt_decor.item_selected.connect(func(_idx: int): _update_decor_ui())

	btn_buy_decor.pressed.connect(func():
		var sel_idx: int = opt_decor.selected
		var k: String = str(opt_decor.get_item_metadata(sel_idx))
		var info: Dictionary = DECOR_CATALOG[k]

		if GameManager.unlocked_decorations.has(k):
			GameManager.active_decoration = k
			GameManager.save_to_settings()
			_update_decor_ui()
		else:
			if GameManager.spend_coins(info.cost):
				GameManager.unlocked_decorations.append(k)
				GameManager.active_decoration = k
				GameManager.save_to_settings()
				_update_decor_ui()
				_update_ui()
	)

func _update_decor_ui() -> void:
	var sel_idx: int = opt_decor.selected
	var k: String = str(opt_decor.get_item_metadata(sel_idx))
	var info: Dictionary = DECOR_CATALOG[k]

	if GameManager.unlocked_decorations.has(k):
		lbl_decor_price.text = "Куплено ✔"
		if GameManager.active_decoration == k:
			btn_buy_decor.text = "Активно ✔"
			btn_buy_decor.disabled = true
		else:
			btn_buy_decor.text = "Установить"
			btn_buy_decor.disabled = false
	else:
		lbl_decor_price.text = "Стоимость: %d 🪙" % info.cost
		btn_buy_decor.text = "Купить и применить"
		btn_buy_decor.disabled = GameManager.coins < info.cost

func _setup_monitors_list() -> void:
	opt_monitors.clear()
	var options: Array[Dictionary] = WindowManager.get_monitor_options()
	var current_screen: int = SettingsManager.get_screen_index()
	var select_idx: int = 0

	for i in range(options.size()):
		var opt: Dictionary = options[i]
		opt_monitors.add_item(opt.title, i)
		opt_monitors.set_item_metadata(i, opt.id)
		if opt.id == current_screen:
			select_idx = i

	opt_monitors.selected = select_idx
	opt_monitors.item_selected.connect(func(idx: int):
		var target_screen: int = int(opt_monitors.get_item_metadata(idx))
		SettingsManager.set_screen_index(target_screen)
		monitor_selected.emit(target_screen)
	)

func _setup_graphics_and_fps() -> void:
	var mode: String = SettingsManager.get_graphics_mode()
	check_16bit.button_pressed = (mode == "16bit")
	check_32bit.button_pressed = (mode == "32bit")

	check_16bit.toggled.connect(func(toggled: bool):
		if toggled:
			check_32bit.button_pressed = false
			SettingsManager.set_graphics_mode("16bit")
			graphics_mode_selected.emit("16bit")
	)

	check_32bit.toggled.connect(func(toggled: bool):
		if toggled:
			check_16bit.button_pressed = false
			SettingsManager.set_graphics_mode("32bit")
			graphics_mode_selected.emit("32bit")
	)

	opt_fps.clear()
	opt_fps.add_item("30 FPS (Рекомендуется)", 30)
	opt_fps.add_item("60 FPS", 60)
	var current_fps: int = SettingsManager.get_fps_limit()
	opt_fps.selected = 0 if current_fps <= 30 else 1
	opt_fps.item_selected.connect(func(idx: int):
		var target_fps: int = 30 if idx == 0 else 60
		SettingsManager.set_fps_limit(target_fps)
		fps_selected.emit(target_fps)
	)

func _setup_finances_tab() -> void:
	if btn_take_subsidy != null:
		btn_take_subsidy.pressed.connect(func():
			if GameManager.take_subsidy():
				_refresh_seeds_ui()
				_update_ui()
		)

	if btn_repay_subsidy != null:
		btn_repay_subsidy.pressed.connect(func():
			if GameManager.repay_subsidy_early():
				_refresh_seeds_ui()
				_update_ui()
		)

	if btn_take_loan != null:
		btn_take_loan.pressed.connect(func():
			if GameManager.take_bank_loan():
				_refresh_seeds_ui()
				_update_ui()
		)

	if btn_repay_loan != null:
		btn_repay_loan.pressed.connect(func():
			if GameManager.repay_loan_early():
				_refresh_seeds_ui()
				_update_ui()
		)

	if btn_bankruptcy != null and bankruptcy_dialog != null:
		btn_bankruptcy.pressed.connect(func():
			bankruptcy_dialog.popup_centered()
		)
		bankruptcy_dialog.confirmed.connect(func():
			GameManager.declare_bankruptcy()
			bankruptcy_requested.emit()
			if opt_decor != null:
				opt_decor.selected = 0
			_refresh_seeds_ui()
			_update_decor_ui()
			_update_ui()
		)

