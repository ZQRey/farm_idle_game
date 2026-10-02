# Changelog

## 1.0.0-rc.1 — 2026-10-02

Первый release candidate Farm Idle Companion.

### Gameplay
- Полный цикл основного поля приведён к ~16–19 минутам.
- Добавлены progression, contracts, storage, market, Garage 2.0, tuning, workers, infrastructure, quality, events, achievements, offline progress, livestock, processing, multiple fields, specialization и Prestige.
- Экономика перебалансирована для положительной ранней маржи и контролируемого late-game роста.
- Итоговый множитель продажи урожая ограничен x6.

### Desktop companion
- Прозрачная полоса над taskbar.
- Tray-first управление.
- Click-through / no-focus desktop window.
- Выбор монитора и безопасный fallback для разноуровневых multi-monitor layouts.
- Windows helper извлекается из embedded PCK в user:// перед применением Win32 styles.

### Reliability
- Versioned save schema и migrations.
- Backup/recovery settings.cfg.
- Validation критичных save values.
- Coalesced autosave и deep snapshots mutable state.
- GitHub Actions: import, strict parse, validation suite, Windows export и Windows executable smoke-test.

### Performance
- 30 FPS default cap.
- Heavy custom field drawing ограничен 12 FPS.
- FarmHQ перестраивает только активную динамическую вкладку.

### UX
- Тайминги культур показываются в минутах.
- Неподдерживаемый режим «Все мониторы» блокируется и в HQ, и в tray.
- Событие инспекции оформлено нейтрально для детской игры.

### Known RC limitations
- Нужен ручной Windows desktop smoke-test tray/taskbar/click-through/Z-order.
- Нужен ручной multi-monitor runtime test на реальных дисплеях.
- После этих проверок возможны точечные UI/animation corrections перед 1.0.0.
