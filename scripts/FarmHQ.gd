class_name FarmHQ
extends Window

const GameManager = preload("res://scripts/GameManager.gd")
const ProgressionManager = preload("res://scripts/ProgressionManager.gd")
const ContractManager = preload("res://scripts/ContractManager.gd")
const InventoryManager = preload("res://scripts/InventoryManager.gd")
const MarketManager = preload("res://scripts/MarketManager.gd")
const VehicleManager = preload("res://scripts/VehicleManager.gd")
const WorkerManager = preload("res://scripts/WorkerManager.gd")
const BuildingManager = preload("res://scripts/BuildingManager.gd")
const SettingsManager = preload("res://scripts/SettingsManager.gd")
const WindowManager = preload("res://scripts/WindowManager.gd")

signal monitor_selected(screen_index: int)
signal graphics_mode_selected(mode: String)
signal fps_selected(fps: int)
signal tractor_color_changed(color: Color)
signal repair_requested
signal strike_resolve_requested
signal bankruptcy_requested
signal police_fine_requested
signal police_bribe_requested

# UI ноды
@onready var coins_label: Label = $VBox/Header/HBoxCoins/CoinsValue
@onready var lbl_season: Label = $VBox/Header/LblSeason
@onready var btn_police_fine: Button = $VBox/Header/BtnResolvePoliceFine
@onready var btn_police_bribe: Button = $VBox/Header/BtnResolvePoliceBribe
@onready var btn_resolve_strike: Button = $VBox/Header/BtnResolveStrike
@onready var btn_emergency_repair: Button = $VBox/Header/BtnEmergencyRepair
@onready var tab_container: TabContainer = $VBox/TabContainer

# Долгосрочная прогрессия фермы (создается динамически, чтобы не ломать сцену HQ)
var lbl_farm_level: Label
var lbl_reputation: Label
var xp_bar: ProgressBar
var lbl_xp_progress: Label
var lbl_next_unlock: Label

# Контракты (динамическая вкладка)
var contracts_container: VBoxContainer

# Склад (динамическая вкладка)
var storage_container: VBoxContainer

# Рынок (динамическая вкладка)
var market_container: VBoxContainer

# Garage 2.0 (динамическая вкладка)
var fleet_container: VBoxContainer

# Работники (динамическая вкладка)
var workers_container: VBoxContainer

# Инфраструктура (динамическая вкладка)
var buildings_container: VBoxContainer

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
@onready var lbl_stat_salaries: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatSalariesVal
@onready var lbl_stat_fuel: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatFuelVal
@onready var lbl_stat_greenhouse: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatGreenhouseVal
@onready var lbl_stat_fines: Label = $VBox/TabContainer/Статистика/VBoxStats/Grid/StatFinesVal
@onready var lbl_repair_status: Label = $VBox/TabContainer/Статистика/VBoxStats/HBoxRepairAction/RepairStatusLbl
@onready var btn_stat_call_repair: Button = $VBox/TabContainer/Статистика/VBoxStats/HBoxRepairAction/BtnStatCallRepair

# Производство и ТО
@onready var lbl_fuel_level: Label = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/FuelSection/HBoxFuel/LblFuelLevel"
@onready var btn_refuel_20: Button = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/FuelSection/HBoxFuel/BtnRefuel20"
@onready var btn_refuel_full: Button = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/FuelSection/HBoxFuel/BtnRefuelFull"
@onready var check_auto_refuel: CheckBox = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/FuelSection/CheckAutoRefuel"

@onready var lbl_gh_count: Label = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/GreenhouseSection/HBoxGHBuy/LblGHCount"
@onready var btn_buy_gh: Button = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/GreenhouseSection/HBoxGHBuy/BtnBuyGreenhouse"
@onready var opt_gh_crop: OptionButton = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/GreenhouseSection/HBoxGHCrop/OptGreenhouseCrop"
@onready var lbl_gh_crop_info: Label = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/GreenhouseSection/LblGreenhouseCropInfo"

@onready var lbl_volunteer_status: Label = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/VolunteerSection/HBoxVol/LblVolunteerStatus"
@onready var btn_call_volunteers: Button = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/VolunteerSection/HBoxVol/BtnCallVolunteers"

@onready var lbl_machinery_cond: Label = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/DurabilitySection/HBoxMachinery/LblMachineryCond"
@onready var btn_repair_machinery: Button = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/DurabilitySection/HBoxMachinery/BtnRepairMachinery"
@onready var lbl_buildings_cond: Label = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/DurabilitySection/HBoxBuildings/LblBuildingsCond"
@onready var btn_repair_buildings: Button = $"VBox/TabContainer/Производство и ТО/ScrollProduction/VBox/DurabilitySection/HBoxBuildings/BtnRepairBuildings"

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
	if not close_requested.is_connected(_on_close_requested):
		close_requested.connect(_on_close_requested)
	if tab_container != null and not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)
	_setup_window_position()
	_setup_progression_ui()
	_setup_contracts_tab()
	_setup_storage_tab()
	_setup_market_tab()
	_setup_fleet_tab()
	_setup_workers_tab()
	_setup_buildings_tab()
	_setup_monitors_list()
	_setup_graphics_and_fps()
	_setup_garage_and_decor()
	_setup_upgrades_tab()
	_setup_finances_tab()
	_setup_repair_buttons()
	_setup_production_tab()
	_setup_police_buttons()
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

func _on_tab_changed(_idx: int) -> void:
	_refresh_seeds_ui()
	_update_ui()

func open_hq() -> void:
	_refresh_seeds_ui()
	_update_ui()
	show()
	grab_focus()

func _setup_progression_ui() -> void:
	var root_vbox: VBoxContainer = $VBox
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ProgressionSummary"
	panel.tooltip_text = "Уровень фермы открывает новые культуры, постройки и технику."
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	vbox.add_child(top_row)

	lbl_farm_level = Label.new()
	lbl_farm_level.add_theme_font_size_override("font_size", 15)
	top_row.add_child(lbl_farm_level)

	lbl_reputation = Label.new()
	lbl_reputation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(lbl_reputation)

	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(xp_row)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(220, 18)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	xp_row.add_child(xp_bar)

	lbl_xp_progress = Label.new()
	lbl_xp_progress.custom_minimum_size = Vector2(110, 0)
	xp_row.add_child(lbl_xp_progress)

	lbl_next_unlock = Label.new()
	lbl_next_unlock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_next_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_row.add_child(lbl_next_unlock)

	root_vbox.add_child(panel)
	root_vbox.move_child(panel, 1)

func _apply_feature_purchase_state(button: Button, feature_id: String, available_text: String, cost: int) -> void:
	var required_level: int = ProgressionManager.get_feature_required_level(feature_id)
	if not ProgressionManager.can_access_feature(feature_id):
		button.text = "🔒 Требуется ур. %d" % required_level
		button.disabled = true
	else:
		button.text = available_text
		button.disabled = GameManager.coins < cost

func _setup_contracts_tab() -> void:
	if contracts_container != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Контракты"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	contracts_container = VBoxContainer.new()
	contracts_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contracts_container.add_theme_constant_override("separation", 10)
	scroll.add_child(contracts_container)

func _format_contract_time(seconds: int) -> String:
	var safe_seconds: int = max(0, seconds)
	var hours: int = int(safe_seconds / 3600)
	var minutes: int = int((safe_seconds % 3600) / 60)
	var secs: int = safe_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]

func _make_contract_panel(contract: Dictionary, is_active: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(title_row)

	var title: Label = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.text = "%s — %s" % [
		str(contract.get("title", "📦 Контракт")),
		str(contract.get("crop_name", "Урожай"))
	]
	title_row.add_child(title)

	var time_left: Label = Label.new()
	time_left.text = "⏳ %s" % _format_contract_time(ContractManager.get_seconds_left(contract))
	title_row.add_child(time_left)

	var target: int = max(1, int(contract.get("target", 1)))
	var progress: int = int(contract.get("progress", 0)) if is_active else 0

	var description: Label = Label.new()
	description.text = "Поставить урожай: %d цикл(а/ов) | Награда: %d 🪙 + %d XP + %d реп." % [
		target,
		int(contract.get("reward_coins", 0)),
		int(contract.get("reward_xp", 0)),
		int(contract.get("reward_rep", 0))
	]
	vbox.add_child(description)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	vbox.add_child(action_row)

	if is_active:
		var progress_bar: ProgressBar = ProgressBar.new()
		progress_bar.min_value = 0
		progress_bar.max_value = target
		progress_bar.value = progress
		progress_bar.show_percentage = false
		progress_bar.custom_minimum_size = Vector2(220, 20)
		progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(progress_bar)

		var progress_label: Label = Label.new()
		progress_label.text = "%d / %d" % [progress, target]
		action_row.add_child(progress_label)

		var abandon: Button = Button.new()
		abandon.text = "Отказаться"
		var active_id: String = str(contract.get("id", ""))
		abandon.pressed.connect(func(target_id: String = active_id):
			if ContractManager.abandon_contract(target_id):
				_refresh_contracts_ui()
				_update_ui()
		)
		action_row.add_child(abandon)
	else:
		var hint: Label = Label.new()
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.text = "Прогресс начнётся автоматически после принятия."
		action_row.add_child(hint)

		var accept: Button = Button.new()
		accept.text = "Принять"
		accept.disabled = ContractManager.active_contracts.size() >= ContractManager.MAX_ACTIVE_CONTRACTS
		var offer_id: String = str(contract.get("id", ""))
		accept.pressed.connect(func(target_id: String = offer_id):
			if ContractManager.accept_contract(target_id):
				_refresh_contracts_ui()
				_update_ui()
		)
		action_row.add_child(accept)

	return panel

func _refresh_contracts_ui() -> void:
	if contracts_container == null:
		return

	for child in contracts_container.get_children():
		child.queue_free()

	if not ContractManager.initialized:
		var loading: Label = Label.new()
		loading.text = "📋 Контрактный центр загружается..."
		contracts_container.add_child(loading)
		return

	ContractManager.refresh_board(false)

	var summary: Label = Label.new()
	summary.add_theme_font_size_override("font_size", 16)
	summary.text = "📋 Контрактный центр | Активно: %d/%d | Выполнено: %d | Провалено: %d" % [
		ContractManager.active_contracts.size(),
		ContractManager.MAX_ACTIVE_CONTRACTS,
		ContractManager.total_completed,
		ContractManager.total_failed
	]
	contracts_container.add_child(summary)

	var stats: Label = Label.new()
	stats.text = "💰 Заработано на контрактах: %d 🪙 | Новая доска через: %s" % [
		ContractManager.total_contract_coins,
		_format_contract_time(ContractManager.get_board_refresh_seconds_left())
	]
	contracts_container.add_child(stats)

	var active_title: Label = Label.new()
	active_title.add_theme_font_size_override("font_size", 15)
	active_title.text = "🚜 Активные контракты"
	contracts_container.add_child(active_title)

	if ContractManager.active_contracts.is_empty():
		var none_active: Label = Label.new()
		none_active.text = "Нет активных контрактов. Можно принять до %d одновременно." % ContractManager.MAX_ACTIVE_CONTRACTS
		contracts_container.add_child(none_active)
	else:
		for contract in ContractManager.active_contracts:
			if contract is Dictionary:
				contracts_container.add_child(_make_contract_panel(contract, true))

	var offers_title: Label = Label.new()
	offers_title.add_theme_font_size_override("font_size", 15)
	offers_title.text = "📨 Доступные предложения"
	contracts_container.add_child(offers_title)

	if ContractManager.offers.is_empty():
		var empty_board: Label = Label.new()
		empty_board.text = "Все предложения этой доски уже разобраны. Новые появятся через %s." % _format_contract_time(ContractManager.get_board_refresh_seconds_left())
		contracts_container.add_child(empty_board)
	else:
		for offer in ContractManager.offers:
			if offer is Dictionary:
				contracts_container.add_child(_make_contract_panel(offer, false))

func _setup_storage_tab() -> void:
	if storage_container != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Склад"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	storage_container = VBoxContainer.new()
	storage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_container.add_theme_constant_override("separation", 10)
	scroll.add_child(storage_container)

func _sell_from_storage(crop_id: String, requested_kg: float) -> void:
	var removed_kg: float = InventoryManager.remove_crop(crop_id, requested_kg)
	if removed_kg <= 0.0:
		return

	var gross: int = GameManager.calculate_crop_sale_value(crop_id, removed_kg)
	var sale: Dictionary = GameManager.process_sale_finances(gross)
	var debt_paid: int = int(sale.get("subsidy_paid", 0)) + int(sale.get("loan_paid", 0))
	print("[FarmHQ] Продано %.0f кг %s: валовая выручка %d, долг -%d, в казну +%d" % [
		removed_kg,
		crop_id,
		gross,
		debt_paid,
		int(sale.get("net_coins", 0))
	])
	_update_ui()

func _refresh_storage_ui() -> void:
	if storage_container == null:
		return

	for child in storage_container.get_children():
		child.queue_free()

	if not InventoryManager.initialized:
		var loading: Label = Label.new()
		loading.text = "🏚 Склад загружается..."
		storage_container.add_child(loading)
		return

	if GameManager.has_barn:
		InventoryManager.ensure_minimum_level(2)

	var capacity: float = InventoryManager.get_capacity()
	var total: float = InventoryManager.get_total_stock()

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.text = "🏚 Склад урожая — уровень %d/%d" % [InventoryManager.storage_level, InventoryManager.MAX_STORAGE_LEVEL]
	storage_container.add_child(title)

	var capacity_row: HBoxContainer = HBoxContainer.new()
	capacity_row.add_theme_constant_override("separation", 8)
	storage_container.add_child(capacity_row)

	var capacity_bar: ProgressBar = ProgressBar.new()
	capacity_bar.min_value = 0.0
	capacity_bar.max_value = max(1.0, capacity)
	capacity_bar.value = total
	capacity_bar.show_percentage = false
	capacity_bar.custom_minimum_size = Vector2(280, 20)
	capacity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_row.add_child(capacity_bar)

	var capacity_label: Label = Label.new()
	capacity_label.text = "%.0f / %.0f кг" % [total, capacity]
	capacity_row.add_child(capacity_label)

	var auto_sell: CheckBox = CheckBox.new()
	auto_sell.text = "Автопродажа после уборки (совместимый режим)"
	auto_sell.set_pressed_no_signal(InventoryManager.auto_sell_on_harvest)
	auto_sell.tooltip_text = "Если выключить, урожай остаётся на складе. При переполнении излишек продаётся автоматически за 70% цены."
	auto_sell.toggled.connect(func(enabled: bool):
		InventoryManager.set_auto_sell(enabled)
		_refresh_storage_ui()
	)
	storage_container.add_child(auto_sell)

	var upgrade_row: HBoxContainer = HBoxContainer.new()
	storage_container.add_child(upgrade_row)

	var upgrade_info: Label = Label.new()
	upgrade_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if InventoryManager.storage_level == 1 and not GameManager.has_barn:
		upgrade_info.text = "Для перехода к складу 1000 кг постройте Большой амбар во вкладке «Улучшения»."
	else:
		upgrade_info.text = "Расширение склада увеличивает запас для будущей торговли на рынке."
	upgrade_row.add_child(upgrade_info)

	var upgrade_btn: Button = Button.new()
	if not InventoryManager.can_upgrade():
		upgrade_btn.text = "Максимальная ёмкость ✔"
		upgrade_btn.disabled = true
	elif InventoryManager.storage_level == 1 and not GameManager.has_barn:
		upgrade_btn.text = "Требуется амбар"
		upgrade_btn.disabled = true
	else:
		var cost: int = InventoryManager.get_next_upgrade_cost()
		var next_capacity: float = float(InventoryManager.CAPACITY_BY_LEVEL.get(InventoryManager.storage_level + 1, capacity))
		upgrade_btn.text = "Расширить до %.0f кг (%d 🪙)" % [next_capacity, cost]
		upgrade_btn.disabled = GameManager.coins < cost
		upgrade_btn.pressed.connect(func():
			var upgrade_cost: int = InventoryManager.get_next_upgrade_cost()
			if upgrade_cost > 0 and GameManager.spend_coins(upgrade_cost):
				InventoryManager.upgrade_capacity()
				_update_ui()
		)
	upgrade_row.add_child(upgrade_btn)

	var separator: HSeparator = HSeparator.new()
	storage_container.add_child(separator)

	for crop_id in InventoryManager.CROP_IDS:
		var crop_data: Dictionary = GameManager.CROPS.get(crop_id, {})
		var crop_name: String = str(crop_data.get("name", crop_id))
		var amount: float = InventoryManager.get_stock(crop_id)
		var price_100: int = GameManager.calculate_crop_sale_value(crop_id, 100.0)

		var panel: PanelContainer = PanelContainer.new()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var info: Label = Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s: %.0f кг | текущая рыночная цена: %d 🪙 / 100 кг" % [crop_name, amount, price_100]
		row.add_child(info)

		var sell_100: Button = Button.new()
		sell_100.text = "Продать 100 кг"
		sell_100.disabled = amount <= 0.0
		var cid_100: String = crop_id
		sell_100.pressed.connect(func(target_crop: String = cid_100):
			_sell_from_storage(target_crop, 100.0)
		)
		row.add_child(sell_100)

		var sell_all: Button = Button.new()
		sell_all.text = "Продать всё"
		sell_all.disabled = amount <= 0.0
		var cid_all: String = crop_id
		sell_all.pressed.connect(func(target_crop: String = cid_all):
			_sell_from_storage(target_crop, InventoryManager.get_stock(target_crop))
		)
		row.add_child(sell_all)

		storage_container.add_child(panel)

	var overflow_note: Label = Label.new()
	overflow_note.text = "Всего принято на склад: %.0f кг | Через переполнение прошло: %.0f кг" % [
		InventoryManager.total_harvest_stored_kg,
		InventoryManager.total_overflow_kg
	]
	storage_container.add_child(overflow_note)

func _setup_market_tab() -> void:
	if market_container != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Рынок"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	market_container = VBoxContainer.new()
	market_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_container.add_theme_constant_override("separation", 10)
	scroll.add_child(market_container)

func _history_price_text(crop_id: String) -> String:
	var history: Array = MarketManager.get_history(crop_id)
	if history.is_empty():
		return "нет истории"

	var parts: Array[String] = []
	var start_idx: int = max(0, history.size() - 8)
	for i in range(start_idx, history.size()):
		var entry: Dictionary = history[i]
		var price: int = int(entry.get("price", 0))
		if price > 0:
			parts.append(str(price))
		else:
			var idx_value: int = int(round(float(entry.get("effective_multiplier", 1.0)) * 100.0))
			parts.append("%d%%" % idx_value)
	return " → ".join(PackedStringArray(parts))

func _refresh_market_ui() -> void:
	if market_container == null:
		return

	for child in market_container.get_children():
		child.queue_free()

	if not MarketManager.initialized:
		var loading: Label = Label.new()
		loading.text = "📊 Рынок загружается..."
		market_container.add_child(loading)
		return

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.text = "📊 Товарная биржа фермы"
	market_container.add_child(title)

	var event_label: Label = Label.new()
	var event_left: int = MarketManager.get_event_seconds_left()
	event_label.text = "%s%s" % [
		MarketManager.get_active_event_text(),
		(" | осталось %s" % _format_contract_time(event_left)) if event_left > 0 else ""
	]
	market_container.add_child(event_label)

	var tick_label: Label = Label.new()
	tick_label.text = "Следующее изменение котировок через %s | Автопродажа рынком: %.0f кг на %d 🪙" % [
		_format_contract_time(MarketManager.get_seconds_to_next_tick()),
		MarketManager.total_auto_sold_kg,
		MarketManager.total_auto_sale_gross
	]
	market_container.add_child(tick_label)

	var note: Label = Label.new()
	note.text = "Правила ниже продают накопленный склад автоматически, когда цена за 100 кг достигает заданного порога."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_container.add_child(note)

	for crop_id in InventoryManager.CROP_IDS:
		var crop_data: Dictionary = GameManager.CROPS.get(crop_id, {})
		var crop_name: String = str(crop_data.get("name", crop_id))
		var current_price: int = GameManager.calculate_crop_sale_value(crop_id, 100.0)
		var trend: int = MarketManager.get_trend(crop_id)
		var trend_icon: String = "➡"
		if trend > 0:
			trend_icon = "📈"
		elif trend < 0:
			trend_icon = "📉"

		var panel: PanelContainer = PanelContainer.new()
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		panel.add_child(vbox)

		var header: HBoxContainer = HBoxContainer.new()
		vbox.add_child(header)

		var price_label: Label = Label.new()
		price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.text = "%s %s — %d 🪙 / 100 кг | склад: %.0f кг" % [
			trend_icon,
			crop_name,
			current_price,
			InventoryManager.get_stock(crop_id)
		]
		header.add_child(price_label)

		var market_index: Label = Label.new()
		market_index.text = "Индекс %.0f%%" % (MarketManager.get_effective_multiplier(crop_id) * 100.0)
		header.add_child(market_index)

		var history_label: Label = Label.new()
		history_label.text = "История: %s" % _history_price_text(crop_id)
		vbox.add_child(history_label)

		var rule_row: HBoxContainer = HBoxContainer.new()
		rule_row.add_theme_constant_override("separation", 8)
		vbox.add_child(rule_row)

		var rule: Dictionary = MarketManager.get_auto_sell_rule(crop_id)
		var threshold_value: int = int(rule.get("min_price", 0))
		if threshold_value <= 0:
			threshold_value = current_price

		var enabled_check: CheckBox = CheckBox.new()
		enabled_check.text = "Автопродажа"
		enabled_check.set_pressed_no_signal(bool(rule.get("enabled", false)))
		rule_row.add_child(enabled_check)

		var threshold_label: Label = Label.new()
		threshold_label.text = "если цена ≥"
		rule_row.add_child(threshold_label)

		var threshold: SpinBox = SpinBox.new()
		threshold.min_value = 1
		threshold.max_value = 10000
		threshold.step = 1
		threshold.value = threshold_value
		threshold.custom_minimum_size = Vector2(115, 0)
		rule_row.add_child(threshold)

		var units: Label = Label.new()
		units.text = "🪙 / 100 кг"
		units.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule_row.add_child(units)

		var cid: String = crop_id
		enabled_check.toggled.connect(func(enabled: bool, target_crop: String = cid, spin: SpinBox = threshold):
			MarketManager.set_auto_sell_rule(target_crop, enabled, int(spin.value))
		)
		threshold.value_changed.connect(func(value: float, target_crop: String = cid, check: CheckBox = enabled_check):
			MarketManager.set_auto_sell_rule(target_crop, check.button_pressed, int(value))
		)

		market_container.add_child(panel)

func _setup_fleet_tab() -> void:
	if fleet_container != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Автопарк"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	fleet_container = VBoxContainer.new()
	fleet_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_container.add_theme_constant_override("separation", 10)
	scroll.add_child(fleet_container)

func _vehicle_role_title(role: String) -> String:
	match role:
		VehicleManager.ROLE_TRACTOR:
			return "🚜 Тракторы"
		VehicleManager.ROLE_TANKER:
			return "💧 Поливочная техника"
		VehicleManager.ROLE_HARVESTER:
			return "🌾 Комбайны"
		VehicleManager.ROLE_TRUCK:
			return "🚚 Грузовики"
	return role

func _refresh_fleet_ui() -> void:
	if fleet_container == null:
		return

	for child in fleet_container.get_children():
		child.queue_free()

	if not VehicleManager.initialized:
		var loading: Label = Label.new()
		loading.text = "🚜 Автопарк загружается..."
		fleet_container.add_child(loading)
		return

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.text = "🚜 Garage 2.0 — активный автопарк"
	fleet_container.add_child(title)

	var summary: Label = Label.new()
	summary.text = "Среднее состояние активной техники: %.0f%% | Всего машин: %d" % [
		VehicleManager.get_average_active_condition(),
		VehicleManager.vehicles.size()
	]
	fleet_container.add_child(summary)

	for role in VehicleManager.ROLES:
		var role_title: Label = Label.new()
		role_title.add_theme_font_size_override("font_size", 15)
		role_title.text = _vehicle_role_title(role)
		fleet_container.add_child(role_title)

		var vehicles_for_role: Array[Dictionary] = VehicleManager.get_owned_for_role(role)
		for vehicle in vehicles_for_role:
			var panel: PanelContainer = PanelContainer.new()
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			panel.add_child(row)

			var vehicle_id: String = str(vehicle.get("id", ""))
			var model_id: String = str(vehicle.get("model_id", ""))
			var active_model: String = VehicleManager.get_active_model_id(role)
			var is_active: bool = model_id == active_model

			var vehicle_stats: Dictionary = VehicleManager.get_vehicle_effective_stats(vehicle_id)

			var info_box: VBoxContainer = VBoxContainer.new()
			info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_box.add_theme_constant_override("separation", 4)
			row.add_child(info_box)

			var info: Label = Label.new()
			info.text = "%s%s | класс: %s | состояние %.0f%% | пробег %.1f км" % [
				"✅ " if is_active else "",
				str(vehicle.get("name", model_id)),
				str(vehicle.get("class", "standard")),
				float(vehicle.get("condition", 100.0)),
				float(vehicle.get("mileage_km", 0.0))
			]
			info_box.add_child(info)

			var stats_label: Label = Label.new()
			stats_label.text = "Эффективно: скорость x%.2f | расход x%.2f | производительность x%.2f | надёжность %.0f%%" % [
				float(vehicle_stats.get("speed_mult", 1.0)),
				float(vehicle_stats.get("fuel_mult", 1.0)),
				float(vehicle_stats.get("capacity_mult", 1.0)),
				float(vehicle_stats.get("reliability", 0.85)) * 100.0
			]
			info_box.add_child(stats_label)

			var select_btn: Button = Button.new()
			select_btn.text = "Активна" if is_active else "Выбрать"
			select_btn.disabled = is_active
			var rid: String = role
			var vid: String = vehicle_id
			select_btn.pressed.connect(func(target_role: String = rid, target_id: String = vid):
				if VehicleManager.set_active_vehicle(target_role, target_id):
					GameManager._sync_legacy_vehicle_state()
					GameManager.save_to_settings()
					_refresh_fleet_ui()
					_update_ui()
			)
			row.add_child(select_btn)

			var upgrades_box: VBoxContainer = VBoxContainer.new()
			upgrades_box.add_theme_constant_override("separation", 3)
			info_box.add_child(upgrades_box)

			for upgrade_id in VehicleManager.UPGRADE_ORDER:
				var upgrade_info: Dictionary = VehicleManager.UPGRADE_CATALOG[upgrade_id]
				var upgrade_row: HBoxContainer = HBoxContainer.new()
				upgrade_row.add_theme_constant_override("separation", 6)
				upgrades_box.add_child(upgrade_row)

				var upgrade_level: int = VehicleManager.get_upgrade_level(vehicle_id, upgrade_id)
				var upgrade_label: Label = Label.new()
				upgrade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				upgrade_label.text = "%s %s — ур. %d/%d | %s" % [
					str(upgrade_info.get("icon", "🔧")),
					str(upgrade_info.get("name", upgrade_id)),
					upgrade_level,
					VehicleManager.MAX_UPGRADE_LEVEL,
					str(upgrade_info.get("description", ""))
				]
				upgrade_row.add_child(upgrade_label)

				var upgrade_btn: Button = Button.new()
				var upgrade_cost: int = VehicleManager.get_upgrade_cost(vehicle_id, upgrade_id)
				if upgrade_level >= VehicleManager.MAX_UPGRADE_LEVEL:
					upgrade_btn.text = "MAX ✔"
					upgrade_btn.disabled = true
				else:
					upgrade_btn.text = "Улучшить (%d 🪙)" % upgrade_cost
					upgrade_btn.disabled = GameManager.coins < upgrade_cost
					var u_vehicle_id: String = vehicle_id
					var u_upgrade_id: String = upgrade_id
					upgrade_btn.pressed.connect(func(target_vehicle_id: String = u_vehicle_id, target_upgrade_id: String = u_upgrade_id):
						var current_cost: int = VehicleManager.get_upgrade_cost(target_vehicle_id, target_upgrade_id)
						if current_cost > 0 and GameManager.spend_coins(current_cost):
							if VehicleManager.apply_upgrade(target_vehicle_id, target_upgrade_id):
								GameManager._sync_legacy_vehicle_state()
								GameManager.save_to_settings()
								_update_ui()
					)
				upgrade_row.add_child(upgrade_btn)

			fleet_container.add_child(panel)

		var role_sep: HSeparator = HSeparator.new()
		fleet_container.add_child(role_sep)

	var note: Label = Label.new()
	note.text = "Покупка улучшенных моделей остаётся во вкладке «Декор и Гараж». Здесь выбирается техника, которая реально выходит на поле."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fleet_container.add_child(note)

func _setup_workers_tab() -> void:
	if workers_container != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Работники"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	workers_container = VBoxContainer.new()
	workers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workers_container.add_theme_constant_override("separation", 10)
	scroll.add_child(workers_container)

func _refresh_workers_ui() -> void:
	if workers_container == null:
		return

	for child in workers_container.get_children():
		child.queue_free()

	if not WorkerManager.initialized:
		var loading: Label = Label.new()
		loading.text = "👨‍🌾 Персонал загружается..."
		workers_container.add_child(loading)
		return

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.text = "👨‍🌾 Персонал фермы — %d/%d" % [WorkerManager.get_worker_count(), WorkerManager.MAX_WORKERS]
	workers_container.add_child(title)

	var salary: Label = Label.new()
	salary.text = "Фонд оплаты за производственный цикл: %d 🪙 | Нанято дополнительно: %d | Повышений: %d" % [
		WorkerManager.get_total_salary_per_cycle(),
		WorkerManager.total_hired,
		WorkerManager.total_levels_gained
	]
	workers_container.add_child(salary)

	var roster_title: Label = Label.new()
	roster_title.add_theme_font_size_override("font_size", 15)
	roster_title.text = "Текущий штат"
	workers_container.add_child(roster_title)

	for worker in WorkerManager.get_workers():
		var panel: PanelContainer = PanelContainer.new()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var profession: String = str(worker.get("profession", ""))
		var prof_data: Dictionary = WorkerManager.PROFESSION_DATA.get(profession, {})
		var level: int = int(worker.get("level", 1))
		var xp: int = int(worker.get("xp", 0))
		var required: int = WorkerManager.get_worker_xp_required(level)

		var info_box: VBoxContainer = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_box)

		var info: Label = Label.new()
		info.text = "%s %s — %s | ур. %d/%d | зарплата %d 🪙" % [
			str(prof_data.get("icon", "👨‍🌾")),
			str(worker.get("name", "Работник")),
			str(prof_data.get("name", profession)),
			level,
			WorkerManager.MAX_LEVEL,
			int(worker.get("salary", 0))
		]
		info_box.add_child(info)

		var progress: Label = Label.new()
		if level >= WorkerManager.MAX_LEVEL:
			progress.text = "XP: MAX | циклов: %d | %s" % [
				int(worker.get("cycles_worked", 0)),
				str(prof_data.get("description", ""))
			]
		else:
			progress.text = "XP: %d/%d | циклов: %d | %s" % [
				xp,
				required,
				int(worker.get("cycles_worked", 0)),
				str(prof_data.get("description", ""))
			]
		info_box.add_child(progress)

		var dismiss: Button = Button.new()
		dismiss.text = "Уволить"
		var wid: String = str(worker.get("id", ""))
		dismiss.disabled = WorkerManager.get_workers_by_profession(profession).size() <= 1 and profession in [
			WorkerManager.PROF_SOWER,
			WorkerManager.PROF_IRRIGATOR,
			WorkerManager.PROF_HARVESTER,
			WorkerManager.PROF_DRIVER
		]
		dismiss.pressed.connect(func(target_worker_id: String = wid):
			if WorkerManager.dismiss_worker(target_worker_id):
				_update_ui()
		)
		row.add_child(dismiss)

		workers_container.add_child(panel)

	var hire_sep: HSeparator = HSeparator.new()
	workers_container.add_child(hire_sep)

	var hire_title: Label = Label.new()
	hire_title.add_theme_font_size_override("font_size", 15)
	hire_title.text = "Найм специалистов"
	workers_container.add_child(hire_title)

	for profession in WorkerManager.PROFESSION_ORDER:
		var prof_data: Dictionary = WorkerManager.PROFESSION_DATA[profession]
		var hire_row: HBoxContainer = HBoxContainer.new()
		hire_row.add_theme_constant_override("separation", 8)

		var hire_info: Label = Label.new()
		hire_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hire_info.text = "%s %s — %s | зарплата %d 🪙/цикл" % [
			str(prof_data.get("icon", "👨‍🌾")),
			str(prof_data.get("name", profession)),
			str(prof_data.get("description", "")),
			int(prof_data.get("salary", 0))
		]
		hire_row.add_child(hire_info)

		var hire_cost: int = WorkerManager.get_hire_cost(profession)
		var hire_btn: Button = Button.new()
		hire_btn.text = "Нанять (%d 🪙)" % hire_cost
		hire_btn.disabled = not WorkerManager.can_hire(profession) or GameManager.coins < hire_cost
		var p: String = profession
		hire_btn.pressed.connect(func(target_profession: String = p):
			var cost: int = WorkerManager.get_hire_cost(target_profession)
			if WorkerManager.can_hire(target_profession) and GameManager.spend_coins(cost):
				var hired: Dictionary = WorkerManager.hire_worker(target_profession)
				if not hired.is_empty():
					_update_ui()
		)
		hire_row.add_child(hire_btn)
		workers_container.add_child(hire_row)

func _setup_buildings_tab() -> void:
	if buildings_container != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Инфраструктура"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	buildings_container = VBoxContainer.new()
	buildings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buildings_container.add_theme_constant_override("separation", 10)
	scroll.add_child(buildings_container)

func _refresh_buildings_ui() -> void:
	if buildings_container == null:
		return

	for child in buildings_container.get_children():
		child.queue_free()

	if not BuildingManager.initialized:
		var loading: Label = Label.new()
		loading.text = "🏗 Инфраструктура загружается..."
		buildings_container.add_child(loading)
		return

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.text = "🏗 Инфраструктура фермы"
	buildings_container.add_child(title)

	var summary: Label = Label.new()
	summary.text = "Инвестировано: %d 🪙 | Доп. склад: +%.0f кг | Бак: %.0f л | Цена продажи: x%.2f" % [
		BuildingManager.total_invested,
		BuildingManager.get_storage_bonus_kg(),
		GameManager.max_fuel,
		BuildingManager.get_sale_multiplier()
	]
	buildings_container.add_child(summary)

	var effects: Label = Label.new()
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects.text = "ТО x%.2f | износ x%.2f | топливо x%.2f | рост x%.2f | урожай x%.2f | надёжность +%.1f%%" % [
		BuildingManager.get_repair_cost_multiplier(),
		BuildingManager.get_wear_multiplier(),
		BuildingManager.get_fuel_price_multiplier(),
		BuildingManager.get_growth_multiplier(),
		BuildingManager.get_yield_multiplier(),
		BuildingManager.get_reliability_bonus() * 100.0
	]
	buildings_container.add_child(effects)

	for building_id in BuildingManager.BUILDING_ORDER:
		var info: Dictionary = BuildingManager.BUILDINGS[building_id]
		var level: int = BuildingManager.get_level(building_id)
		var panel: PanelContainer = PanelContainer.new()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s %s — ур. %d/%d\n%s" % [
			str(info.get("icon", "🏗")),
			str(info.get("name", building_id)),
			level,
			BuildingManager.MAX_LEVEL,
			str(info.get("description", ""))
		]
		row.add_child(label)

		var btn: Button = Button.new()
		var requires_barn: bool = building_id == "barn_upgrade" and not GameManager.has_barn
		if requires_barn:
			btn.text = "Нужен амбар"
			btn.disabled = true
		elif level >= BuildingManager.MAX_LEVEL:
			btn.text = "MAX ✔"
			btn.disabled = true
		else:
			var cost: int = BuildingManager.get_upgrade_cost(building_id)
			btn.text = "Построить / улучшить (%d 🪙)" % cost
			btn.disabled = GameManager.coins < cost
			var bid: String = building_id
			btn.pressed.connect(func(target_id: String = bid):
				var current_cost: int = BuildingManager.get_upgrade_cost(target_id)
				if current_cost > 0 and GameManager.spend_coins(current_cost):
					if BuildingManager.upgrade(target_id):
						GameManager.refresh_infrastructure_effects()
						GameManager.save_to_settings()
						_update_ui()
			)
		row.add_child(btn)
		buildings_container.add_child(panel)

func _setup_repair_buttons() -> void:
	var do_repair = func():
		repair_requested.emit()
		_update_ui()

	btn_emergency_repair.pressed.connect(do_repair)
	btn_stat_call_repair.pressed.connect(do_repair)

	if btn_resolve_strike != null:
		btn_resolve_strike.pressed.connect(func():
			strike_resolve_requested.emit()
			_update_ui()
		)

func _update_ui() -> void:
	_refresh_contracts_ui()
	_refresh_storage_ui()
	_refresh_market_ui()
	_refresh_fleet_ui()
	_refresh_workers_ui()
	_refresh_buildings_ui()

	if coins_label != null:
		coins_label.text = "%d 🪙" % GameManager.coins

	if lbl_farm_level != null:
		lbl_farm_level.text = "⭐ Ферма: ур. %d / %d" % [ProgressionManager.farm_level, ProgressionManager.MAX_LEVEL]
	if lbl_reputation != null:
		lbl_reputation.text = "🏅 Репутация: %d — %s" % [ProgressionManager.reputation, ProgressionManager.get_reputation_title()]
	if xp_bar != null and lbl_xp_progress != null:
		var xp_required: int = ProgressionManager.get_xp_required_for_current_level()
		if ProgressionManager.farm_level >= ProgressionManager.MAX_LEVEL:
			xp_bar.max_value = 1.0
			xp_bar.value = 1.0
			lbl_xp_progress.text = "MAX"
		else:
			xp_bar.max_value = float(max(1, xp_required))
			xp_bar.value = float(ProgressionManager.xp)
			lbl_xp_progress.text = "%d / %d XP" % [ProgressionManager.xp, xp_required]
	if lbl_next_unlock != null:
		lbl_next_unlock.text = "Следующее: %s" % ProgressionManager.get_next_unlock_text()

	# Сезон года и модификатор рыночных цен
	if lbl_season != null:
		var s_name: String = GameManager.get_season_name()
		var s_mult: float = GameManager.get_season_price_multiplier()
		var mult_diff: int = int((s_mult - 1.0) * 100.0)
		var mult_str: String = ("+%d%%" % mult_diff) if mult_diff >= 0 else ("%d%%" % mult_diff)
		lbl_season.text = "🗓 Сезон: %s (Цены: %s)" % [s_name, mult_str]

	# Кнопки взаимодействия с полицией
	if btn_police_fine != null and btn_police_bribe != null:
		var is_pol: bool = GameManager.is_police_active
		btn_police_fine.visible = is_pol
		btn_police_bribe.visible = is_pol
		if is_pol:
			var fine_amt: int = 40 if GameManager.has_guard_dog else 80
			var bribe_amt: int = max(10, int(GameManager.coins * 0.10))
			btn_police_fine.text = "📋 Штраф (%d 🪙)" % fine_amt
			btn_police_fine.disabled = (GameManager.coins < fine_amt)
			btn_police_bribe.text = "🤝 Взятка (%d 🪙)" % bribe_amt
			btn_police_bribe.disabled = (GameManager.coins < bribe_amt)

	# Кнопка урегулирования забастовки сеятелей
	if btn_resolve_strike != null:
		btn_resolve_strike.visible = GameManager.is_strike_active
		btn_resolve_strike.disabled = (GameManager.coins < 50)
		btn_resolve_strike.text = "🚨 Забастовка! Премия (50 🪙)"

	# Статус поломки или застревания в грязи
	var is_trouble: bool = GameManager.is_broken_down or GameManager.is_stuck_in_mud
	if btn_emergency_repair != null and btn_stat_call_repair != null:
		btn_emergency_repair.visible = is_trouble

		if GameManager.is_repairing:
			btn_emergency_repair.text = "🚑 Ремонт уже в пути..."
			btn_emergency_repair.disabled = true
			btn_stat_call_repair.text = "🚑 Ремонт уже в пути..."
			btn_stat_call_repair.disabled = true
			lbl_repair_status.text = "Статус: 🚑 Аварийная служба в пути..."
		elif is_trouble:
			btn_emergency_repair.text = "🔧 Вызвать ремонт (30 🪙)"
			btn_emergency_repair.disabled = (GameManager.coins < 30)
			btn_stat_call_repair.text = "🔧 Вызвать ремонтную бригаду (30 🪙)"
			btn_stat_call_repair.disabled = (GameManager.coins < 30)
			if GameManager.is_broken_down:
				lbl_repair_status.text = "Статус: ⚙ ТЕХНИКА СЛОМАЛАСЬ! ВАЛИТ ДЫМ!"
			elif GameManager.is_stuck_in_mud:
				lbl_repair_status.text = "Статус: 🌧 ТЕХНИКА ЗАСТРЯЛА В ГРЯЗИ!"
		else:
			btn_emergency_repair.text = "🔧 Вызвать ремонт (30 🪙)"
			btn_emergency_repair.disabled = true
			btn_stat_call_repair.text = "🔧 Вызвать ремонтную бригаду (30 🪙)"
			btn_stat_call_repair.disabled = true
			lbl_repair_status.text = "Статус: Вся техника на ходу ✔"

	# Мельница
	if btn_buy_windmill != null:
		if GameManager.has_windmill:
			btn_buy_windmill.text = "Построено ✔"
			btn_buy_windmill.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_windmill, "windmill", "Построить (600 🪙)", 600)

	# Амбар
	if btn_buy_barn != null:
		if GameManager.has_barn:
			btn_buy_barn.text = "Построено ✔"
			btn_buy_barn.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_barn, "barn", "Построить (450 🪙)", 450)

	# Навес
	if btn_buy_canopy != null:
		if GameManager.canopy_count >= 2:
			btn_buy_canopy.text = "Максимум (2/2) ✔"
			btn_buy_canopy.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_canopy, "canopy", "Построить (%d/2 за 250 🪙)" % [GameManager.canopy_count], 250)

	# Пугало (до 3 на монитор)
	if btn_buy_scarecrow != null:
		var max_s: int = GameManager.get_max_scarecrows()
		if GameManager.scarecrow_count >= max_s:
			btn_buy_scarecrow.text = "Максимум (%d/%d) ✔" % [GameManager.scarecrow_count, max_s]
			btn_buy_scarecrow.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_scarecrow, "scarecrow", "Купить (%d/%d за 150 🪙)" % [GameManager.scarecrow_count, max_s], 150)

	# Сеялка
	if btn_buy_seeder != null:
		if GameManager.has_seeder_tractor:
			btn_buy_seeder.text = "Куплено ✔"
			btn_buy_seeder.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_seeder, "seeder", "Купить (350 🪙)", 350)

	# Собака
	if btn_buy_dog != null:
		if GameManager.has_guard_dog:
			btn_buy_dog.text = "Куплено ✔"
			btn_buy_dog.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_dog, "guard_dog", "Купить (500 🪙)", 500)

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
	if lbl_stat_salaries != null:
		lbl_stat_salaries.text = "%d 🪙" % GameManager.total_salaries_paid
	if lbl_stat_fuel != null:
		lbl_stat_fuel.text = "%d 🪙" % GameManager.total_fuel_spent
	if lbl_stat_greenhouse != null:
		lbl_stat_greenhouse.text = "%d 🪙" % GameManager.total_greenhouse_earned
	if lbl_stat_fines != null:
		lbl_stat_fines.text = "%d 🪙" % GameManager.total_fines_paid

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
		if VehicleManager.owns_model("tractor_heavy"):
			btn_buy_heavy_tractor.text = "Куплено ✔"
			btn_buy_heavy_tractor.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_heavy_tractor, "heavy_tractor", "Купить (800 🪙)", 800)

	if btn_buy_super_harvester != null:
		if VehicleManager.owns_model("harvester_super"):
			btn_buy_super_harvester.text = "Куплено ✔"
			btn_buy_super_harvester.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_super_harvester, "super_harvester", "Купить (1200 🪙)", 1200)

	if btn_buy_road_train != null:
		if VehicleManager.owns_model("truck_road_train"):
			btn_buy_road_train.text = "Куплено ✔"
			btn_buy_road_train.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_road_train, "road_train", "Купить (950 🪙)", 950)

	# Производство и ТО: Топливо
	if lbl_fuel_level != null:
		lbl_fuel_level.text = "Уровень топлива: %.1f / %.0f л" % [GameManager.fuel_level, GameManager.max_fuel]
	if btn_refuel_20 != null:
		var partial_amount: float = min(20.0, max(0.0, GameManager.max_fuel - GameManager.fuel_level))
		var partial_cost: int = GameManager.calculate_refuel_cost(partial_amount)
		btn_refuel_20.text = "Заправить %.0f л (%d 🪙)" % [partial_amount, partial_cost] if partial_amount > 0.5 else "Бак полон ✔"
		btn_refuel_20.disabled = (partial_amount <= 0.5) or (GameManager.coins < partial_cost)
	if btn_refuel_full != null:
		var needed: float = GameManager.max_fuel - GameManager.fuel_level
		var full_cost: int = GameManager.calculate_refuel_cost(needed)
		btn_refuel_full.text = "Полный бак (%d 🪙)" % full_cost if needed > 0.5 else "Бак полон ✔"
		btn_refuel_full.disabled = (needed <= 0.5) or (GameManager.coins < full_cost)
	if check_auto_refuel != null:
		check_auto_refuel.button_pressed = GameManager.auto_refuel

	# Производство и ТО: Теплицы
	if lbl_gh_count != null:
		lbl_gh_count.text = "Построено теплиц: %d / 2" % GameManager.greenhouse_count
	if btn_buy_gh != null:
		if GameManager.greenhouse_count >= 2:
			btn_buy_gh.text = "Максимум (2/2) ✔"
			btn_buy_gh.disabled = true
		else:
			_apply_feature_purchase_state(btn_buy_gh, "greenhouse", "Купить теплицу (700 🪙)", 700)
	if lbl_gh_crop_info != null:
		var gh_data: Dictionary = GameManager.get_current_greenhouse_data()
		lbl_gh_crop_info.text = "%s: доход +%d 🪙 (семена %d 🪙, созревание %.0f сек)" % [
			gh_data.get("name", ""),
			gh_data.get("reward", 0),
			gh_data.get("seed_cost", 0),
			gh_data.get("growth_time", 20.0)
		]

	# Производство и ТО: Волонтёры
	if lbl_volunteer_status != null and btn_call_volunteers != null:
		if GameManager.is_volunteers_active:
			var rem_sec: int = int(GameManager.volunteer_timer)
			lbl_volunteer_status.text = "Статус: 🤝 Волонтёры помогают на поле! (Осталось: %d:%02d)" % [rem_sec / 60, rem_sec % 60]
			btn_call_volunteers.disabled = true
			btn_call_volunteers.text = "Волонтёры работают ✔"
		elif GameManager.can_call_volunteers():
			lbl_volunteer_status.text = "Статус: Готовы прийти на помощь бесплатно ✔"
			btn_call_volunteers.disabled = false
			btn_call_volunteers.text = "🤝 Призвать волонтёров (+70%)"
		else:
			var cd_left: int = GameManager.get_volunteer_cooldown_left()
			lbl_volunteer_status.text = "Статус: Перезарядка призыва (%d мин)" % int(ceil(float(cd_left) / 60.0))
			btn_call_volunteers.disabled = true
			btn_call_volunteers.text = "Перезарядка (%d:%02d)" % [cd_left / 60, cd_left % 60]

	# Производство и ТО: Износ и ТО
	if lbl_machinery_cond != null and btn_repair_machinery != null:
		var avg_mach: float = GameManager.get_machinery_average_condition()
		var cond_warn: String = " (Требует ТО!)" if avg_mach < 40.0 else " ✔"
		lbl_machinery_cond.text = "Состояние автопарка: %.0f%%%s" % [avg_mach, cond_warn]
		var machinery_repair_cost: int = GameManager.get_machinery_repair_cost()
		btn_repair_machinery.text = "ТО автопарка (%d 🪙)" % machinery_repair_cost if avg_mach < 99.0 else "Техника в идеале ✔"
		btn_repair_machinery.disabled = (avg_mach >= 99.0) or (GameManager.coins < machinery_repair_cost)

	if lbl_buildings_cond != null and btn_repair_buildings != null:
		var avg_build: float = (GameManager.windmill_condition + GameManager.barn_condition + GameManager.canopy_condition + GameManager.greenhouse_condition) / 4.0
		var build_warn: String = " (Требует капремонта!)" if avg_build < 40.0 else " ✔"
		lbl_buildings_cond.text = "Состояние построек: %.0f%%%s" % [avg_build, build_warn]
		var building_repair_cost: int = GameManager.get_building_repair_cost()
		btn_repair_buildings.text = "Капремонт зданий (%d 🪙)" % building_repair_cost if avg_build < 99.0 else "Здания в идеале ✔"
		btn_repair_buildings.disabled = (avg_build >= 99.0) or (GameManager.coins < building_repair_cost)

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

		var this_cid: String = str(crop_id)
		var this_cost: int = int(c_data.seed_cost)
		var is_unlocked: bool = bool(c_data.unlocked)
		var required_level: int = ProgressionManager.get_crop_required_level(this_cid)

		var lbl_info: Label = Label.new()
		lbl_info.text = "%s\n⏱ Рост: %.0fc | 💰 Доход: +%d 🪙 | 🌱 Семена: %d 🪙/цикл | ⭐ Ур. %d" % [
			c_data.name, c_data.growth_time, c_data.base_reward, c_data.seed_cost, required_level
		]
		lbl_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_info)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(160, 36)

		if not is_unlocked:
			if not ProgressionManager.can_unlock_crop(this_cid):
				btn.text = "🔒 Требуется ур. %d" % required_level
				btn.disabled = true
			else:
				btn.text = "Открыть (%d 🪙)" % this_cost
				btn.disabled = GameManager.coins < this_cost
				btn.pressed.connect(func(target_cid: String = this_cid, target_cost: int = this_cost):
					if ProgressionManager.can_unlock_crop(target_cid) and GameManager.spend_coins(target_cost):
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
		if ProgressionManager.can_access_feature("windmill") and GameManager.spend_coins(600):
			GameManager.has_windmill = true
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_barn.pressed.connect(func():
		if ProgressionManager.can_access_feature("barn") and GameManager.spend_coins(450):
			GameManager.has_barn = true
			InventoryManager.ensure_minimum_level(2)
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_canopy.pressed.connect(func():
		if ProgressionManager.can_access_feature("canopy") and GameManager.canopy_count < 2 and GameManager.spend_coins(250):
			GameManager.canopy_count += 1
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_scarecrow.pressed.connect(func():
		var max_s: int = GameManager.get_max_scarecrows()
		if ProgressionManager.can_access_feature("scarecrow") and GameManager.scarecrow_count < max_s and GameManager.spend_coins(150):
			GameManager.scarecrow_count += 1
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_seeder.pressed.connect(func():
		if ProgressionManager.can_access_feature("seeder") and GameManager.spend_coins(350):
			GameManager.has_seeder_tractor = true
			GameManager.save_to_settings()
			_update_ui()
	)

	btn_buy_dog.pressed.connect(func():
		if ProgressionManager.can_access_feature("guard_dog") and GameManager.spend_coins(500):
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
			if ProgressionManager.can_access_feature("heavy_tractor") and GameManager.spend_coins(800):
				if VehicleManager.purchase_model("tractor_heavy"):
					GameManager._sync_legacy_vehicle_state()
					GameManager.save_to_settings()
				_update_ui()
		)

	if btn_buy_super_harvester != null:
		btn_buy_super_harvester.pressed.connect(func():
			if ProgressionManager.can_access_feature("super_harvester") and GameManager.spend_coins(1200):
				if VehicleManager.purchase_model("harvester_super"):
					GameManager._sync_legacy_vehicle_state()
					GameManager.save_to_settings()
				_update_ui()
		)

	if btn_buy_road_train != null:
		btn_buy_road_train.pressed.connect(func():
			if ProgressionManager.can_access_feature("road_train") and GameManager.spend_coins(950):
				if VehicleManager.purchase_model("truck_road_train"):
					GameManager._sync_legacy_vehicle_state()
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

func _setup_police_buttons() -> void:
	if btn_police_fine != null:
		btn_police_fine.pressed.connect(func():
			police_fine_requested.emit()
			_update_ui()
		)
	if btn_police_bribe != null:
		btn_police_bribe.pressed.connect(func():
			police_bribe_requested.emit()
			_update_ui()
		)

func _setup_production_tab() -> void:
	# Топливо
	if btn_refuel_20 != null:
		btn_refuel_20.pressed.connect(func():
			var amount: float = min(20.0, max(0.0, GameManager.max_fuel - GameManager.fuel_level))
			if amount > 0.0 and GameManager.refuel(amount):
				_update_ui()
		)
	if btn_refuel_full != null:
		btn_refuel_full.pressed.connect(func():
			var needed: float = GameManager.max_fuel - GameManager.fuel_level
			if needed > 0.0 and GameManager.refuel(needed):
				_update_ui()
		)
	if check_auto_refuel != null:
		check_auto_refuel.button_pressed = GameManager.auto_refuel
		check_auto_refuel.toggled.connect(func(toggled: bool):
			GameManager.auto_refuel = toggled
			GameManager.save_to_settings()
		)

	# Теплицы
	if btn_buy_gh != null:
		btn_buy_gh.pressed.connect(func():
			if ProgressionManager.can_access_feature("greenhouse") and GameManager.buy_greenhouse():
				_update_ui()
		)

	if opt_gh_crop != null:
		opt_gh_crop.clear()
		var gh_keys: Array = GameManager.GREENHOUSE_CROPS.keys()
		var current_crop_idx: int = 0
		for i in range(gh_keys.size()):
			var k: String = gh_keys[i]
			var c_info: Dictionary = GameManager.GREENHOUSE_CROPS[k]
			opt_gh_crop.add_item(c_info.get("name", k), i)
			opt_gh_crop.set_item_metadata(i, k)
			if k == GameManager.greenhouse_crop:
				current_crop_idx = i
		opt_gh_crop.selected = current_crop_idx
		opt_gh_crop.item_selected.connect(func(idx: int):
			var selected_crop: String = str(opt_gh_crop.get_item_metadata(idx))
			GameManager.greenhouse_crop = selected_crop
			GameManager.save_to_settings()
			_update_ui()
		)

	# Волонтёры
	if btn_call_volunteers != null:
		btn_call_volunteers.pressed.connect(func():
			if GameManager.call_volunteers():
				_update_ui()
		)

	# Износ и ТО
	if btn_repair_machinery != null:
		btn_repair_machinery.pressed.connect(func():
			if GameManager.repair_all_machinery():
				_update_ui()
		)

	if btn_repair_buildings != null:
		btn_repair_buildings.pressed.connect(func():
			if GameManager.repair_all_buildings():
				_update_ui()
		)

