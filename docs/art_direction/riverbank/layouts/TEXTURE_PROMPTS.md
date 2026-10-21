# Новые стилизованные покрытия

Встроенный ImageGen, 21 октября 2026. Фактическая выдача — 1254×1254, без апскейла. Итоги в `assets/environment/riverbank/textures/ground/stylized_v2/`:

1. `T_RB_Ground_Flagstone_A_BaseColor.png`
2. `T_RB_Ground_Soil_A_BaseColor.png`
3. `T_RB_Ground_Moss_A_BaseColor.png` — первоначальный бледный вариант, сохранён.
4. `T_RB_Ground_Meadow_A_BaseColor.png` — одобренное травяное поле.
5. `T_RB_Ground_Moss_B_BaseColor.png` — отвергнутый насыщенный вариант, сохранён для истории. Moss A Bright — предыдущая промежуточная версия (+0.4 EV), тоже сохранена. Активный новый BrokenSlate A описан в [TERRAIN_TRANSITIONS.md](TERRAIN_TRANSITIONS.md).

Крупные спокойные формы вместо прежней мелкой фактуры. Старые текстуры сохранены в родительской папке для истории и не используются текущим материалом. [Дополнительные промпты Meadow A и Moss B](MEADOW_PROMPTS.md).

## 1

```text
Use case: stylized-concept. Production game texture, seamless square ALBEDO, top-down flat 2D painted surface ONLY, full bleed. Strongly stylized like the broad chunky painted shapes of Darksiders Genesis and Hades II. ABSOLUTELY NO photographic detail, NO realistic gravel, NO noise grain, NO fine scratches, NO speckling, NO microtexture, NO gradient lighting. Large simple calm shapes in 3 or 4 flat muted colors with a few deliberate broad angular brush strokes. Even flat diffuse lighting. Seamless edges, no text, no borders. Low contrast cool slate lavender and dusty muted blue gray palette to match chunky purple gothic stone ruins. Readable from distant gameplay camera. SUBJECT: large irregular old slate flagstones fitted together with shallow very narrow seams, each stone mostly a solid calm painted color with only two or three broad planar facets. No tiny stones, no debris, no wide cracks. Tile contains about 18 large stone shapes, no regular square grid. Quiet painterly cartoon game material, not a photograph.
```

## 2

```text
Use case: stylized-concept. Production game texture, seamless square ALBEDO, top-down flat 2D painted surface ONLY, full bleed. Strongly stylized like the broad chunky painted shapes of Darksiders Genesis and Hades II. ABSOLUTELY NO photographic detail, NO realistic gravel, NO noise grain, NO fine scratches, NO speckling, NO microtexture, NO gradient lighting. Large simple calm shapes in 3 or 4 flat muted colors with a few deliberate broad angular brush strokes. Even flat diffuse lighting. Seamless edges, no text, no borders. Low contrast cool slate lavender and dusty muted blue gray palette to match chunky purple gothic stone ruins. Readable from distant gameplay camera. SUBJECT: smooth compact riverbank soil in muted slate mauve gray with broad organic irregular patches. Only 5 or 6 very simple flat embedded stones, no gravel. Simple broad painted swirls, calm untextured large areas, soft overall color changes. No puddles, no shiny wetness, no fine detail.
```

## 3

```text
Use case: stylized-concept. Production game texture, seamless square ALBEDO, top-down flat 2D painted surface ONLY, full bleed. Strongly stylized like the broad chunky painted shapes of Darksiders Genesis and Hades II. ABSOLUTELY NO photographic detail, NO realistic gravel, NO noise grain, NO fine scratches, NO speckling, NO microtexture, NO gradient lighting. Large simple calm shapes in 3 or 4 flat muted colors with a few deliberate broad angular brush strokes. Even flat diffuse lighting. Seamless edges, no text, no borders. Low contrast cool slate lavender and dusty muted blue gray palette to match chunky purple gothic stone ruins. Readable from distant gameplay camera. SUBJECT: flat stylized low moss ground cover, broad soft moss patches interspersed with smooth slate gray soil and 5 or 6 simple flat stones. Muted sage blue green, NOT neon. Moss painted as groups of broad brush marks, not individual leaves or grass blades. No microscopic texture, no realistic dirt.
```
