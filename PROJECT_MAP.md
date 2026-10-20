# Terminal Depth — карта проекта

Проверено по рабочим файлам 19 октября 2026. Пути относительно корня; `res://` соответствует корню проекта. Это навигатор для целевого чтения, не полный аудит поведения. Правила и решения автора — [AGENTS.md](AGENTS.md). `CLAUDE.md` — короткая памятка со ссылками сюда; старые sci-fi сведения остались только в истории git.

## Точки входа и Autoload

`project.godot`: Godot 4.7 / Forward+, D3D12, Jolt, главное меню `scenes/main_menu.tscn` → `scripts/main_menu.gd`.

Арт главного меню: `assets/ui/gothic_v3/main_menu.png`; локальный шрифт меню — `assets/fonts/menu_font.tres` (Cormorant Garamond, кириллица). `test_main_menu_art.tscn` проверяет кнопки и пропорции экрана без запуска забега; `-- --capture` сохраняет обе страницы в output.

| Autoload | Файл | Роль |
|---|---|---|
| Loc | `scripts/loc.gd` | Локализация, шрифты; английские строки в `data/lang/en.gd` |
| Sfx | `scenes/sfx.tscn`, `scripts/sfx.gd` | Пул звуков и воспроизведение |
| Game | `scripts/game.gd` | Забег, игрок, переходы, склад, сохранение |
| Fx | `scripts/fx.gd` | Попадания, кровь, декали, частицы, прочие эффекты |
| GameCursor | `scripts/game_cursor.gd` | Постоянная готическая стрелка мыши в игре и всех окнах |

ItemDB, ModuleDB, PassiveDB и SaveGame — подключаемые скрипты, не Autoload. Редакторский плагин: `addons/threshold_style/plugin.cfg` → `plugin.gd`, `style_panel.gd`.

## Система: Кампания, уровни и переходы

**Назначение:** запуск забега и сохранение состояния при переходах.

**Основные файлы:**
- `scripts/game.gd` — `new_game`, `continue_game`, `start_test`, `start_demo`, `complete_zone`, `go_to_hub`, `return_to_zone`, `_switch`.
- `scenes/lunar_intro.tscn`, `scripts/lunar_intro.gd` — начало кампании, викторианская деревня; планировка (дорожки, поляны, кольцо, острова, отряды, точки активностей) — `scripts/village_route_plan.gd`.
- `scenes/tavern_hub.tscn`, `scripts/tavern_hub.gd` — текущий хаб, наследует `scenes/hub.tscn`; `scenes/hub_finishes.tscn` — отделка.
- `scenes/zones/zone_1.tscn` … `zone_5.tscn`, `scripts/zone.gd` — последующие зоны, параметры уровня, дополнительная популяция и навигация.
- `scripts/hub_portal.gd`, `hub_lift_door.gd`, `level_exit.gd` (все в `scripts/`) — портал/выходы.
- `scenes/demo.tscn`, `scripts/demo_level.gd` — отдельная демо-арена. `scenes/level.tscn`, `facility.tscn`, `zone.tscn` — другие существующие уровни/тестовые основания.

**Зависимости:** Game, PlayerInventory, SaveGame, игрок, камеры и навигация уровня.

**Где менять:** последовательность кампании в Game; локальные условия — скрипт конкретной сцены. Новая игра начинает в INTRO_SCENE с автоматом, fire и ricochet (`_configure_campaign_player`, `_give_campaign_modules`); продолжение загружает сохранённые вещи. Планировка деревни и активности — [docs/SSF_VILLAGE_TEST.md](docs/SSF_VILLAGE_TEST.md). `FLOORS=6`, первый маршрут отдельно от пяти файлов зон. При визите в хаб зона остаётся вне дерева, игрок переносится с вещами; не заменять это пересозданием игрока.

## Система: Персонаж, управление и камера

**Назначение:** движение, перекат, прицеливание, состояние героя.

**Основные файлы:**
- `scenes/player.tscn` — CharacterBody3D с `Model`, `Animator`, `Muzzle`, `Inventory`, `HUD`.
- `scripts/player.gd` — движение, `_start_dodge`, `_update_aim`, здоровье/ЭЩ, взаимодействия, оружие и пересчёт характеристик.
- `scripts/input_setup.gd` — InputMap, REBINDABLE, `user://controls.cfg`; `scripts/pause_menu.gd` — UI переназначения.
- `scripts/camera_rig.gd` — камера уровня: слежение, расстояние/наклон, толчки; дочерняя `Camera3D`.
- `scripts/level1_camera_controls.gd` — отдельная панель камеры теста новой карты.

**Зависимости:** Inventory, Skills, Animator, Game, группы `player`, `enemies`, `bullet_pool`.

**Где менять:** физику и прицел — player; привязки — InputSetup; кадр — CameraRig и значения конкретной сцены. Проверять мышь и геймпад, особенно удержание огня после полного переката. Не переносить настройки тестовой камеры во всю кампанию.

## Система: Модель героя и анимации

**Назначение:** визуальная поза, направленная локомоция, синхронизация действий.

**Основные файлы:**
- `assets/characters/model1_player.tscn` — текущая модель героя в `scenes/player.tscn`; восстановлена прежняя привязка 68 костей. Ручной скелет `model1_rigged111.blend` и его экспортёр `tools/export_model1_user_rig.py` отложены из-за деформаций. `scenes/tools/model1_preview.tscn` — крупный просмотр. Подготовка и проверка: `docs/MODEL1_PLAYER.md`.
- `assets/characters/huntress_player.tscn`, `scripts/huntress_model.gd` — сохранённая прежняя красная охотница.
- `scripts/player_animator.gd` — библиотека/AnimationTree, локомоция, слои действий.
- `tools/bake_model1_pro_rifle.gd` — действующий перенос стойки и 24 направлений движения X Bot из `animation/Pro Rifle Pack` в `model1_shooter.tres`; согласует оси бёдер/голеней с исходником, оружейные действия и перекат сохраняет. Старые сборщики Walking 1 / Fast Run не запускать поверх этой библиотеки.
- `assets/animations/model1_upright.tres`, `tools/bake_upright_locomotion.gd` — отвергнутая проба прямой осанки, отключена по просьбе автора; игра использует прежние Pro Rifle. История и кадры: `docs/UPRIGHT_LOCOMOTION.md`.
- `tools/bake_model1_rifle_reload.gd` — компактный MX_Reloading: правая рука удерживает автомат, левая играет действие из Reloading.fbx; после полной пересборки model1 повторить отдельно.
- `scripts/weapon_aim_modifier.gd`, `weapon_support_modifier.gd`, `weapon_recoil_modifier.gd`, `head_up_modifier.gd` (в `scripts/`) — поправки позы/отдача.
- `scripts/stance_width_modifier.gd` — ограничение чрезмерно широкой постановки ног текущей модели; параметр `max_stance_width` у Model, проверка `tools/test_stance_width.gd`.
- `scripts/bow_pose_modifier.gd`, `bow_visual.gd`, `wood_arrow_mesh.gd` (в `scripts/`) — лук, крепление/тетива/стрела.
- `assets/animations/model1_archery.tres`, `model1_shooter.tres` — текущие библиотеки лука и огнестрельного теста; исходные `huntress_archery.tres` и `huntress_shooter.tres` сохранены рядом.
- `animation/bow_combat/sources.json`, `tools/bake_bow_combat.gd`, `tools/bake_archery.gd`, `tools/bake_huntress.gd`, `tools/rig_hero_asset.py` — источники и подготовка.

**Зависимости:** состояния/сигналы player, скелет/кости, WeaponData, момент вылета снаряда.

**Где менять:** тайминги действия сверять одновременно в player и Animator. Порядок запекания и ограничения — `docs/ARCHERY_PROTOTYPE.md`, модель — `docs/HUNTRESS_PLAYER.md`, старые библиотеки — `docs/ANIMATIONS.md`. Старые Erika/Ch15 и эксперименты не являются текущим героем.

## Система: Оружие, стрельба и попадания

**Назначение:** вычисление выстрела, полёт, вторичные эффекты и урон.

**Основные файлы:**
- `scripts/weapon_data.gd` (WeaponData), `data/weapons/rifle.tres`, `shotgun.tres`, `huntress_bow.tres`, `mine.tres` (в `data/weapons/`) — параметры баз; остальные базы там же.
- `scripts/player.gd` — `weapon_stats`, `module_error`, `insert_module`, `_update_shooting`, `_update_bow_shooting`, `_shoot`, экипировка и перезарядка.
- `scripts/bullet_pool.gd`, `scripts/bullet.gd`, `scenes/bullet.tscn` — пул, пошаговые лучевые попадания, пробивание/рикошет/наведение/взрыв.
- `scripts/explosion.gd`, `scenes/explosion.tscn`, `scripts/fx.gd`, `scripts/sfx.gd` — эффекты.
- `assets/weapons/huntress_bow/bow_visual.tscn`, `data/weapons/huntress_bow.tres` — закреплённый лук.
- `assets/weapons/gun1/gun1_visual.tscn` — предоставленная модель автомата с отметкой дула; подключена в `data/weapons/rifle.tres`. Подготовка и просмотр: `docs/GUN1_WEAPON.md`.
- `assets/weapons/supplied_pistol/pistol_visual.tscn` — предоставленный револьвер из `pistol/RIP0.obj`, сохранён в проекте, но временно исключён из игры; отдельные пистолетные анимации отложены. В `level1_playtest` слот 2 теперь занимает дробовик. См. `docs/SUPPLIED_PISTOL.md`.

**Зависимости:** GearItem.stats, модули, `_gear` игрока, Animator, `take_damage` цели, пул уровня.

**Где менять:** базовые цифры в WeaponData; суммарный расчёт в GearItem/player; траекторию/вторичные попадания в bullet. По умолчанию `fixed_bow_loadout=true`: обычные слоты и модули огнестрела существуют, но поведение режима ограничено. `tools/level1_playtest.gd` передаёт false и библиотеку model1_shooter через `Game.start_test(..., player_options)`.

## Система: Предметы, инвентарь, экипировка и модификаторы

**Назначение:** базы/свойства вещей, сумка, гнёзда, добыча и экономика.

**Основные файлы:**
- `scripts/item_db.gd` — BASES, AFFIXES, UNIQUES, CURRENCY, доступность, цены, разбор.
- `scripts/gear_item.gd` (GearItem) — экземпляр вещи, `stats`, `apply_currency`, имя/иконка/редкость, модули.
- `scripts/player_inventory.gd` (PlayerInventory) — entries/сетка, equipment/weapons, валюта, equip/unequip, gear_stats, сигнал changed.
- `scripts/module_data.gd` (ModuleData), `scripts/module_db.gd`, `data/modules/fire.tres`, `data/modules/ricochet.tres` — параметры и каталог модулей.
- `scripts/loot_pickup.gd`, `loot_chest.gd`, `loot_beam.gd` (в `scripts/`) — добыча в мире.
- `scripts/vendor.gd`, `workbench.gd`, `stash.gd` (в `scripts/`) — торговля/разбор/склад; UI в `scripts/inventory_screen.gd`.

**Зависимости:** player пересчитывает характеристики по changed; Game хранит склад; SaveGame сериализует вещи и модули.

**Доступно сейчас:** только арбалет/коломёт (`rifle`) и дробовик (`shotgun`). Пистолеты и остальные базы сохранены, но исключены из выдачи, добычи и экипировки. Проверка: `scenes/tools/test_active_weapons.tscn`, обычный старт — с `-- --campaign-start`.

**Где менять:** новые базы/свойства — ItemDB + GearItem; новые модули — Resource + ModuleDB + потребитель характеристики. Гнёзда и совместимость проверяет player; не ограничиваться визуальным экраном. Изменение структуры предмета требует проверки загрузки старых сохранений.

## Система: Навыки, пассивки и характеристики

**Назначение:** активные способности и общие бонусы героя.

**Основные файлы:**
- `scripts/player_skills.gd` — гранаты, мины, nova, заряженный выстрел, области стихийного урона; узел создаётся игроком.
- `scripts/passive_db.gd` — NODES/EDGES, ключи бонусов.
- `scripts/player.gd` — allocate/refund, passive_stats, `_recalculate_stats`, `_recalculate_defense`, уровень/опыт; `_gear` — общие бонусы.
- `scripts/skills_screen.gd`, `passive_tree_screen.gd`, `character_screen.gd` (в `scripts/`) — экраны способностей/дерева/характеристик.
- `data/weapons/mine.tres` — база мин.

**Зависимости:** экипировка и модули, InputSetup, Fx/Sfx, take_damage целей.

**Где менять:** описание узла — PassiveDB; доступность/связность — player; реализация способности — PlayerSkills; отображение — соответствующий экран. Ключи характеристик согласовывать с ItemDB/GearItem и потребителем урона.

## Система: Враги, AI и бой

**Назначение:** навигация, пробуждение, атаки, статусы, смерть и награды.

**Основные файлы:**
- `scripts/enemy.gd` (Enemy) — `_think`, `_chase_direction`, `_resolve_melee`, `take_damage`, `_die`, `_drop_loot`.
- `scripts/crawler.gd`, `brute.gd`, `leaper.gd`, `spitter.gd`, `boss.gd`, `robot_gunner.gd`, `robot_drone.gd` (в `scripts/`) — варианты поведения.
- `scenes/crawler.tscn`, `brute.tscn`, `leaper.tscn`, `spitter.tscn`, `robot_heavy.tscn`, `robot_walker.tscn`, `robot_drone.tscn` (в `scenes/`); боссы — `scenes/boss_foreman.tscn`, `boss_doctor.tscn`, `boss_sentinel.tscn` (в `scenes/`).
- `scripts/enemy_projectile.gd`, `monster_mods.gd`, `enemy_animation_profiles.gd`, `enemy_spawner.gd` (в `scripts/`) — дальний урон, редкость, клипы, волны.
- `scripts/health_bar_3d.gd`, `scripts/hud_target_bar.gd` — здоровье и выбранная цель.

**Зависимости:** NavigationRegion3D уровня, игрок, Fx/Sfx, ItemDB, зона/XP.

**Где менять:** общее поведение в Enemy, особенное — наследник/сцена. Контакт ближней атаки связан с анимацией. Группа enemies содержит также манекены и разрушаемые цели: не считать каждый узел Enemy. Дополнительную популяцию zone.gd создаёт после готовности навигации с компенсацией XP/добычи.

## Система: Взаимодействия и задания

**Назначение:** двери, разговоры, услуги, события и задачи зоны.

**Основные файлы:**
- `scripts/interactable.gd`, `door.gd`, `keycard.gd`, `safe_zone.gd` (в `scripts/`) — взаимодействие/доступ/безопасность.
- `scripts/npc_dialog.gd`, `npc_conversation.gd`, `dialog_box.gd` (в `scripts/`) — данные и интерфейс разговоров.
- `scripts/zone_quests.gd`, `scientist.gd`, `ally_robot.gd`, `destructible.gd`, `seal_event.gd` (в `scripts/`) — задачи и объекты событий.
- `scripts/first_time_hints.gd`, `scripts/hud_quest.gd` — подсказки и список заданий.

**Зависимости:** группы объектов, player.interact/ключи/награды, Game.dialog_seen, зона.

**Где менять:** условия задачи в ZoneQuests и объекте события; обучающий маршрут — lunar_intro; разговор/услуга — NPC и соответствующий экран. Старые технические ID не переименовывать только из-за смены художественного направления.

В деревне `enabled_quests` явно включает сундуки, обелиски, ритуал и посещение `landmark_rects`; прогресс исследования берётся из существующего `Zone._visited`. Пустой список сохраняет прежние правила следующих этажей. `seal_event.gd`: локальные параметры каменного алтаря/врагов и `wave_timeout=0` для ожидания полной зачистки волны; прочие сцены используют прежние значения по умолчанию.

## Система: HUD и интерфейсы

**Назначение:** состояние героя, окна и управление на паузе.

**Основные файлы:**
- `scripts/hud.gd` — сборка HUD и экранов из preload; большая часть UI создаётся кодом, а не отдельными tscn.
- `scripts/hud_life_bar.gd`, `hud_xp_bar.gd`, `hud_quick_menu.gd`, `hud_crosshair.gd`, `hud_damage_overlay.gd` (в `scripts/`) — основные элементы.
- `scripts/hud_minimap.gd`, `hud_notifications.gd`, `hud_loot_labels.gd`, `hud_world_labels.gd`, `hud_world_prompt.gd`, `hud_ref.gd` (в `scripts/`) — карта/подписи/уведомления/компоновка.
- `scripts/inventory_screen.gd`, `scripts/skills_screen.gd`, `scripts/pause_menu.gd` — окна.
- Пауза: `assets/ui/gothic_v3/pause_menu.png`, шрифт `assets/fonts/menu_font.tres`; `test_pause_art.tscn` проверяет восемь пунктов, таблицу ввода, отмену назначения и возврат без записи настроек.
- `scripts/inventory_art.gd`, `assets/ui/gothic_v4/inventory_poe.png` — геометрия и утверждённый каменный рисунок боковых окон навыков и инвентаря: около 36% экрана с каждой стороны, открытый центр, равномерный масштаб 16:9; торговля/склад сохраняют прежний вид.
- `scripts/ui_style.gd`, `scripts/ui_icons.gd`, `assets/ui/gothic_v2`, `assets/fonts/main_font.tres` — общая графика/иконки/шрифт.

**Зависимости:** сигналы player и Inventory, Game, Loc, InputSetup; пауза SceneTree.

**Где менять:** общий вид в UiStyle, изображения предметов через UiIcons.draw_item_picture; данные в игровой системе. При правках окон проверять закрытие/возобновление и геймпад. Дизайн: `docs/UI_GOTHIC_V2.md`.

## Система: Сохранения и загрузка

**Назначение:** прогресс забега и инвентарей.

**Основные файлы:**
- `scripts/save_game.gd` — `user://save.json`, VERSION, campaign_version, write/read_all/apply, сериализация инвентаря/вещей и совместимость.
- `scripts/game.gd` — автосохранение, сохранение при переходах, продолжение, testing.
- `scripts/input_setup.gd` — отдельно `user://controls.cfg`.

**Зависимости:** PlayerInventory, GearItem, ItemDB, ModuleDB, пассивки, склад Game.

**Где менять:** формат/миграции в SaveGame, момент записи в Game. Состояние врагов/сундуков зоны не сериализуется. Фактическое место загрузки определяется `new_game` с учётом campaign_version/floor, а не только комментарием SaveGame. `testing` защищает Game.save, но не прямые write/delete. Изолировать пользовательские данные до тестов сериализации.

## Система: Окружение, свет, материалы и размещение

**Назначение:** внешний вид локаций и повторяемые модели.

**Основные файлы:**
- `scripts/model_batch.gd` — @tool, PackedScene + transforms (12 чисел на экземпляр), MultiMesh на меш источника, tint с кэшем копий материалов. Коллизии проверять отдельно в сцене.
- `scripts/village_architecture.gd`, `village_materials.gd`, `village_set_dressing.gd`, `village_petal_rain.gd`, `town_ruin_dressing.gd` (в `scripts/`) — деревня и декор.
- `assets/shaders/garden_floor.gdshader`, `assets/textures/victorian_garden/stylized_v2`, `assets/textures/victorian_village/stylized_v2` — одобренные покрытия.
- `scripts/threshold_composition.gd`, `threshold_look.gd`, `threshold_look_controller.gd`, `threshold_fluffy_fog.gd`, `threshold_chain.gd` (в `scripts/`) — отдельная композиция, профиль вида, слои тумана, цепи.
- `scenes/art/threshold_composition.tscn`, `scenes/tools/threshold_preview.tscn`, `data/visual/threshold_saved.tres`, `addons/threshold_style/style_panel.gd` — мастерская стиля в редакторе/игре; запись профиля явная.
- `scripts/level1_material_preview.gd`, `assets/environment`, `art_source` — новая карта, игровые модели и редактируемые источники.

**Зависимости:** @tool/EditorPlugin, Environment/камеры, шейдеры, внешние PNG моделей, сборщики.

**Где менять:** конкретную сцену и её профиль; общие шейдеры затрагивают все потребители. Фоновые декорации не считать коллизиями. Детали: `docs/FIRST_LOCATION_LIGHTING.md`, `VICTORIAN_VILLAGE.md`, `THRESHOLD_COMPOSITION.md`, `STYLE_WORKSHOP.md`, `HUB_LIGHTING_TEST.md`, `LIGHT_STYLE_STUDY.md` (в `docs/`).

## Система: Отдельный тест новой карты

**Назначение:** проверка пользовательской карты без замены кампании.

**Основные файлы:**
- `scenes/tools/level1_playtest.tscn`, `tools/level1_playtest.gd` — запуск/проверки/перезапуск.
- `scenes/art/level1_supplied.tscn`, `scripts/level1_supplied.gd` — маршрут/спавны/завершение в таверне.
- `scripts/level1_step_assist.gd`, `scripts/level1_camera_controls.gd`, `scripts/level1_material_preview.gd` — локальные проходы, камера и материал.
- `scenes/tools/build_level1_supplied.tscn`, `tools/build_level1_supplied.gd` — пересборка тестовой сцены.

**Зависимости:** Game.start_test/player_options, огнестрельная библиотека охотницы, навигация и исходные модели.

**Где менять:** только эту ветку, если задача о supplied/playtest. F2 обзор, F7 пересоздание боя, F8 камера. Точные ограничения/проверки — `docs/LEVEL1_SUPPLIED_PLAYTEST.md`; последние настройки в AGENTS.md и фактических сцене/сборщике.

## Прочие действующие скрипты

- Внешний вид персонажей/врагов: `scripts/suit.gd` (+ `assets/shaders/suit.gdshader`), `outfit.gd`, `hair.gd`, `shooter_model.gd` (Mixamo-модель), `plasma_cutter_model.gd`, `huntress_cloth_modifier.gd` (следование плаща без физики) — все в `scripts/`.
- Подсветка и мелочи мира: `scripts/highlight.gd` (контур активных объектов), `flicker_light.gd` (мигающие лампы), `player_bar_3d.gd` (полоски над героем), `menu_tabs.gd` (вкладки окон), `dummy.gd` (манекен).
- Наследие sci-fi этапа: `scripts/facility.gd` + `scenes/facility.tscn`, `scenes/level.tscn`, `scenes/zone.tscn`; `scripts/hud_health_bar.gd` нигде не подключён.
- `scripts/icon_render.gd` + `scenes/tools/icon_render.tscn` — рендер иконок оружия (пишет PNG в `assets/icons/weapons`, запускать с окном).

## Быстрый указатель «задача → откуда начинать»

| Задача | Начать с |
|---|---|
| Цифры оружия | `data/weapons/<имя>.tres`, затем `scripts/weapon_data.gd` |
| Новый модуль | `data/modules/*.tres`, `scripts/module_db.gd`, потребитель в `player.weapon_stats` / `bullet.gd` |
| Свойство/база вещи, цены | `scripts/item_db.gd`, `scripts/gear_item.gd` |
| Поведение врага | наследник в `scripts/`, общее — `scripts/enemy.gd`; редкость — `monster_mods.gd` |
| Кнопка/привязка | `scripts/input_setup.gd` (+ подсказки в `pause_menu.gd`) |
| Окно/HUD | `scripts/hud.gd` → нужный `hud_*.gd` / `*_screen.gd`, вид — `ui_style.gd`, `inventory_art.gd` |
| Текст на английском | `data/lang/en.gd` (ключ — русская строка) |
| Звук | `scripts/sfx.gd` SOUNDS, файлы `assets/sounds` |
| Переходы/старт кампании | `scripts/game.gd` (`new_game`, `_switch`), сцены `lunar_intro` / `tavern_hub` |
| Поле сохранения | `scripts/save_game.gd` (`write`, `apply`, `_inventory_to/_from`) |
| Задание зоны | `scripts/zone_quests.gd` + объект события |

## Ключевые связи между системами

- ItemDB/WeaponData/ModuleDB → GearItem.stats + Inventory.gear_stats + PassiveDB → player._gear/weapon_stats → payload → BulletPool → Bullet → take_damage → Fx/Sfx/добыча/XP.
- InputSetup → player/PlayerSkills → Animator и модификаторы; момент выстрела лука связан с фазой клипа.
- Inventory.changed → player._on_inventory_changed → пересчёт/обновление; HUD читает состояние игрока и подписывается на сигналы.
- Game переносит player целиком между сценами; уровень предоставляет Spawn, камеру, навигацию и пул. Портал сохраняет зону в памяти, SaveGame хранит лишь прогресс и вещи.
- Карта/задания зависят от данных зоны и групп объектов; при добавлении нового уровня сверять эти контракты с готовым уровнем.

## Особенности структуры сцен и ресурсов

- `scripts/` — runtime и @tool; `scenes/` — игровые сцены; `scenes/tools/` + `tools/` — тесты, превью, генераторы. `data/` — ресурсы и таблицы; `assets/` — импортируемые файлы; `art_source/`, `animation/`, `_packs/` — источники.
- `work/` содержит пробы и прежние копии, не использовать как основной код; `.godot/` — кэш. У отдельных источников/экспериментов есть `.gdignore`.
- `tools/gen_open_zone.py` создаёт зоны; `tools/gen_hub.py` существует, но ручную базу пересоздавать нельзя. Другие сборщики: `tools/build_threshold_scene.gd`, `tools/build_level1_supplied.gd`, `tools/prepare_hub_lightmap.gd`. Это операции записи, не безобидные проверки.
- Импортированные модели могут ссылаться на внешние PNG; переносить комплектом. Scene ownership, ссылки библиотек и MultiMesh требуют отдельной проверки при упаковке; цепи восстанавливают трансформации при загрузке.

## Проверка проекта и тестирование

Выбирать минимальный набор под патч, предварительно прочитав вход теста и его операции записи. Обычный шаблон: `<Godot> --headless --path <корень> res://scenes/tools/test_имя.tscn`. Пользовательские параметры после `--`; визуальные проверки запускать с окном. Это примеры для будущих задач; при подготовке карты Godot не запускался.

| Область | Сцены в `scenes/tools/` | Что проверить |
|---|---|---|
| Загрузка скриптов | `check_project.tscn` | `tools/check_project.gd` загружает только верхний уровень scripts/, не все сцены/подпапки |
| Выстрел/контакт/перекат | `test_combat.tscn`, `test_combat_feel.tscn`, `test_roll_aim.tscn` | Попадания, трассер, продолжение огня после переката |
| Лук/герой/шаги | `test_archery.tscn`, `test_archery_campaign.tscn`, `test_footsteps.tscn`, `test_mixamo.tscn` | Действие, попадание, экипировка, локомоция |
| Вещи/UI | `test_equipment_catalog.tscn`, `test_ui.tscn`, `test_inventory_art.tscn`, `test_health_bars.tscn`, `test_nova.tscn` | Каталог, окна, здоровье, способность; inventory_art: сетка, перенос модулей, экипировка, вкладки/пауза, `-- --capture` — кадр в output |
| Маршрут/кампания | `test_village.tscn`, `test_act_one.tscn`, `test_onboarding.tscn` | Проход, задачи, переходы; onboarding: отдельно `-- --population-only` |
| Старт SSF и расширенная деревня | `test_ssf_village.tscn` | Комплект, площадь ≥ 6000 м², четыре вида врагов, четыре активности, сундук и дверь, ритуал, перенос вещей в таверну; `-- --capture` для кадров. `--menu-start` только с изолированным APPDATA, см. docs/SSF_VILLAGE_TEST.md |
| Свет/окружение | `test_first_location_lighting.tscn`, `test_garden_floor.tscn`, `test_threshold_composition.tscn`, `test_style_workshop.tscn` | Сцена и реальный кадр, пауза/редактор при необходимости |
| Новая карта | `level1_playtest.tscn` | По задаче `-- --check`, `-- --walk-check`, `-- --combat-check`; F7 и камера |
| Этаж зоны без меню | `test_zone.tscn` (скрипт `scripts/tools/test_zone.gd`) | `-- floor=2 freeze=1 zoom=0.4 shots=<папка>`; Game.testing, без сохранений |
| База/свет/стиль/кровь | `test_editable_hub.tscn`, `test_hub_refresh.tscn`, `test_hub_lighting.tscn`, `test_light_style.tscn`, `test_victorian_style.tscn`, `test_threshold_polish.tscn`, `test_gore_pass.tscn` | Перед запуском прочитать одноимённый `tools/*.gd`: часть пишет кадры |

Godot: `C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe`; общая проверка разбора — `--headless --editor --quit --path .`. Скрипты `tools/test_*.gd` лежат под `.gdignore`, сцены в `scenes/tools/` ссылаются на них. SceneTree-скрипты (`--script`): `tools/test_huntress.gd`, `test_model1.gd`, `test_stance_width.gd`, `test_bow_action.gd`.

Проверка деформаций охотницы — отдельный SceneTree-скрипт `tools/test_huntress.gd`: `<Godot> --headless --path <корень> --script res://tools/test_huntress.gd` (сцены test_huntress.tscn нет).

F5 запускает главное меню; F6 — текущую открытую сцену. Превью: `huntress_preview.tscn`, `archery_combat_preview.tscn`, `threshold_preview.tscn`, `village_preview.tscn` (в `scenes/tools/`). Режим `--capture` у ряда тестов пишет кадры в docs/screens: учитывать это как изменение файлов. Снимки не доказывают производительность. Экспорт: `export_presets.cfg`; генерацию/запекание запускать только для соответствующей задачи.

## Известные архитектурные риски и границы исследования

- `player.gd` объединяет движение, бой, характеристики и интерфейсы предметов; `enemy.gd` — AI, урон, визуал и добычу. Локальная правка требует целевого поиска потребителей, особенно Animator/Skills/HUD. Это не повод для незапрошенного рефакторинга.
- Существуют несовпадающие исторические описания: комментарии Game/SaveGame о старте на базе, старые цифры/модели в истории CLAUDE.md; в LEVEL1_SUPPLIED_PLAYTEST есть устаревшее число тяжёлых рядом с новыми настройками. Сверять код и последние авторские решения; документацию прошлых этапов не применять автоматически.
- Game.testing не перехватывает прямые обращения к SaveGame; настройки управления/профиль вида имеют отдельные пути записи. Проверять побочные эффекты каждого запуска.
- Генераторы и запекатели перезаписывают результаты, @tool выполняется в редакторе; ручная база особенно уязвима к повторной генерации.
- По прежним записям автора, стабильный FPS и корректное завершение D3D12 ещё не подтверждены, полный старый onboarding требует сверки ожиданий заданий. В этой задаче эти сообщения не воспроизводились и не исправлялись.
- В корне лежат исходные папки без `.gdignore` (`animation/` ~1000 файлов, `GUN 1`, `MODEL 1`, `pistol`, `audio 11`, `reference`, `output`, `ztest`, `art_source`): Godot их импортирует, что замедляет редактор и засоряет `res://`. Есть посторонние копии: `scenes/hub 222.tscn` (+ `.exr`/`.lmbake`, нигде не используется), папки с испорченными именами в корне (только `.thumbnails`). Не удалять без указания автора.
- Рабочая папка содержит много незакоммиченных изменений (удалённые архивы Sonniss, переимпорт текстур, правки библиотек анимаций). Перед коммитом выбирать только свои файлы.
- Дополнительного исследования по конкретному заданию требуют: полный набор миграций старых вещей, все ветви переходов/смерти, поведение каждого босса, совместимость всех исходных клипов и бюджет рендера. Наличие файлов/тестов не означает прохождение этих проверок.

