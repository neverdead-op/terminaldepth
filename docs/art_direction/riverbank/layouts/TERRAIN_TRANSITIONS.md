# Покрытие BrokenSlate A и переходы

21 октября 2026. Автор одобрил текущий переход трава/плиты после замены жёсткого края на переход по швам. Meadow и меши травы сохранены. Маленький бледный рисунок Moss заменён новым покрытием с крупными холодными камнями и тёплой землёй. Никаких изменений маршрута или границ проходимости.

## Источники и решения

- [Epic: Landscape Materials, LB Height Blend](https://dev.epicgames.com/documentation/en-us/unreal-engine/landscape-materials-in-unreal-engine): высотная маска позволяет земле заполнять промежутки между камнями вместо простого растворения двух рисунков. Использован принцип, а не код UE. [Ограничения и нулевые веса](https://dev.epicgames.com/documentation/en-us/unreal-engine/landscape-material-expressions-in-unreal-engine): сохраняем нормализацию и запасной слой, чтобы стык не давал чёрных дыр.
- [Brent Critchfield — Worldbuilding for Darksiders Genesis](https://brentcritchfield.artstation.com/projects/baoPPG), [официальный Art Blast команды](https://magazine.artstation.com/2019/12/airship-syndicate-darksiders-genesis-art-blast/): референсы композиции и света. Наше художественное решение — более крупные каменные формы, тёплая земля и локальная зелень, согласованные с имеющимися мешами. Это интерпретация референсов, не реконструкция материалов оригинальной игры.
- [Burley, On Histogram-Preserving Blending for Randomized Texture Tiling](https://jcgt.org/published/0008/04/02/): случайные сдвиги выборок уменьшают повтор, повышение степени весов помогает сохранять структуру. Здесь простое смешивание трёх выборок на треугольной сетке с общей маской высоты, **без** полного histogram-preserving преобразования. Поэтому мелкие области смешивания всё ещё возможны.

Граница определяется размытой splat-картой, умеренным шумом и отдельными масками плит/сланца. Земляная подложка у травы смягчает смену оттенка. Не подменяем весь камень зелёной дымкой: отдельные плиты сохраняются на краю дернины. Stochastic-выборки включены только для BrokenSlate; grass UV и цвет корней прежние.

## Файлы

Все три ресурса находятся в `assets/environment/riverbank/textures/ground/stylized_v2/`:

- `T_RB_Ground_BrokenSlate_A_BaseColor.png` — новая текстура ImageGen, 1254×1254, без апскейла, HQ BC7 + mipmaps.
- `T_RB_Ground_BrokenSlate_A_Height.png` — техническая маска холодных камней над тёплой землёй.
- `T_RB_Ground_Flagstone_A_Height.png` — техническая маска плоскостей плит и тёмных швов.

Маски воспроизводятся `tools/build_riverbank_height_masks.py`. Это оценка по цветовым областям, а не физическая глубина. Материал `ground_open.tres` собирается `tools/update_riverbank_open_ground.gd`. Общие новые параметры шейдера выключены по умолчанию; другие материалы продолжают использовать прежнее смешивание. Старые Moss A/A Bright/B не удалены.

Настройки и 24853 пучка травы описаны в [README](README.md). Реальные кадры D3D12: [сад](../postfx_garden.png), [стык](../terrain_transition_detail.png). Игровая проверка подтвердила физический проход, навигацию, 24 врага, огонь/попадание и паузу без записи сохранений. Это не измерение стабильного FPS.

## Генерация

Встроенный инструмент ImageGen, режим generate с локальной Flagstone A как **референсом палитры и кисти**, не как редактируемой картинкой. Результат скопирован в проект под новым именем; оригинал сохранён в generated_images. Итоговый промпт:

```text
Use case: stylized-concept. Create ONE production-ready seamless square tileable ground base-color texture for a stylized 3D top-down gothic action RPG, Darksiders Genesis inspired chunky hand-painted environment. Reference image is ONLY a palette and brushwork reference, NOT an edit target. New subject: weathered broken slate paving sinking into compact rich earthy ground, with restrained dark olive moss nestled in crevices and a few grouped short blades along soil pockets. About 45 percent broad irregular stone surfaces, 40 percent quiet deep desaturated warm plum-brown earthen ground, 15 percent clustered olive vegetation. Stones are chunky and broad, asymmetrical bevels, painterly three-tone planes and warm chipped edges; muted blue slate and dusky violet, NOT white/light gray. Give stones tangible sculpted-looking forms yet minimal baked directional lighting, no cast shadows. Earth has broad painted tonal patches, no photo grain. Moss should be restrained dark olive green coordinating with grass but MUST NOT cover the entire ground in an even confetti pattern. Vary stone sizes, cluster stones asymmetrically, avoid a single memorable central rock, avoid regular gravel distribution. Strong readable shapes at gameplay camera distance. No photorealism, no photograph, no pebbly microdetail, no flat vector outlines or cell-shading, no washed-out mint/sage, no gray blue fog, no grid, no ornamental flowers. Strict orthographic overhead flat texture, uniform neutral illumination, no perspective, no horizon, edge to edge material, no text, no border. All opposite edges must tile seamlessly in both directions. High resolution.
```
