# Свет и постобработка Riverbank

Открой `scenes/art/riverbank_blockout.tscn` и нижнюю вкладку **Стиль сцены**. В игровом тесте `play_riverbank.cmd`: **F8 / L3** открывает окно и приостанавливает бой, повторное нажатие или Esc закрывает его с восстановлением прежней паузы. F8 теста supplied level1 по-прежнему управляет его камерой.

128 настроек сгруппированы в девять вкладок; поиск фильтрует поля внутри вкладок. Начинай со «Свет», «Тон», «Цвет». «Genesis · база» даёт холодный окружающий свет, нейтральный направленный и тёплые фонари, ACES, умеренный AO/glow. Селшейдинга нет. «До обработки (A/B)» возвращает исходное окружение. Экранная коррекция применяется к миру перед HUD.

**Сохранить профиль** пишет `data/visual/riverbank_postfx_saved.tres`; последующие запуски берут его автоматически. До нажатия изменения существуют только в предпросмотре, F7 их сбрасывает. Профиль содержит полные Environment и CameraAttributesPractical. Ресурсные поля (Sky, LUT и т. п.) открываются кнопками «Все параметры…» через Inspector; «Профиль целиком / Save As…» позволяет сохранить отдельную копию. Кампания и другие сцены не подключаются автоматически.

## Локальные зоны

Кнопка «Добавить локальную PostFX-зону» создаёт Node3D с отдельной копией профиля и Undo/Redo. В Inspector настрой Position, Size, Blend Radius, Blend Weight, Priority. Зона действует по положению **камеры**; высоту коробки учитывай при верхнем ракурсе. Unbound распространяет профиль на всю сцену. Больший Priority применяется позже; числовые значения/цвета смешиваются плавно, перечисления и bool переключаются на весе 0.5.

Overrides пустой — смешивается весь профиль. Для изменения только отдельных полей укажи, например, `env/tonemap_exposure`, `temperature`, `vignette`. Сами значения меняются в ресурсе Profile зоны. Зоны сохраняются обычным сохранением сцены; глобальная кнопка профиля сохраняет базу, а не расстановку зон.

## Что перенесено из подхода Unreal

| Область | Реализация и границы |
|---|---|
| Volume, priority, radius, weight, unbound, overrides | Собственные PostFXVolume3D, коробка и плавный спад; не произвольная геометрия UE Brush |
| Exposure, tonemapping, contrast, saturation | Нативный Environment/CameraAttributes; ACES и auto exposure Godot |
| Bloom, AO, fog, SSR, SSIL, SDFGI | Нативные возможности Forward+; доступны в панели, результат зависит от движка/сцены |
| DOF | CameraAttributesPractical; не физическая модель CineCamera UE |
| Цвет, lift/gamma/gain, tint, vignette, sharpness, grain, aberration, distortion | Экранный шейдер; художественные приближения, не оптическая модель UE |
| LUT, sky и остальные ресурсные поля | Полные нативные ресурсы через Inspector |
| Lumen, Nanite, path tracing, аппаратный RT, UE motion blur, convolution bloom, lens flares | Не реализованы этим инструментом; функции другого рендера нельзя скопировать панелью |

Тяжёлые эффекты не включены все сразу. Производительность на разных настройках требует отдельных измерений; известные предупреждения освобождения RID/D3D12 при выходе не объявлены исправленными.

## Устройство и проверки

`scripts/postfx_studio.gd` подключён дочерним PostFXStudio только к Riverbank. `postfx_profile.gd` — профиль и отражение нативных параметров; `postfx_volume.gd` — зоны. `assets/shaders/postfx_grade.gdshader` — коррекция мира. Редактор использует существующие `addons/threshold_style/plugin.gd` и `style_panel.gd`, прежняя мастерская Threshold сохранена. Цветокоррекция видна и в четырёх 3D-видах редактора.

`scenes/tools/test_postfx_studio.tscn`: реальные изменения Environment/шейдера, сохранение в отдельный временный ресурс и возврат, ввод F8, пауза, A/B, спад зоны, перекрытие зон с маской Overrides. Без реальных сохранений игры. D3D12 запуск сохраняет кадры `docs/art_direction/riverbank/postfx_*.png`. `test_style_workshop.tscn` проверяет прежние 32 настройки Threshold.

Источники: [Post Process Effects UE](https://dev.epicgames.com/documentation/en-us/unreal-engine/post-process-effects-in-unreal-engine), [APostProcessVolume](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/APostProcessVolume), [Godot Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html), [CameraAttributesPractical](https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html). Визуальные ориентиры: [Brent Critchfield — Worldbuilding for Darksiders Genesis](https://brentcritchfield.artstation.com/projects/baoPPG), [Airship Syndicate Art Blast](https://magazine.artstation.com/2019/12/airship-syndicate-darksiders-genesis-art-blast/).
