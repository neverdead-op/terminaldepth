# Покрытия Riverbank

Созданы встроенным ImageGen 21 октября 2026. Итоговые PNG: `assets/environment/riverbank/textures/ground/`. Фактическое разрешение выдачи — 1254×1254, без искусственного увеличения; 2048×2048 в промптах было пожеланием.

1. `T_RB_Ground_QuayCobble_A_BaseColor.png` — потёртая кладка, слой 1.
2. `T_RB_Ground_RiverSilt_A_BaseColor.png` — влажный грунт и гравий, слой 2.
3. `T_RB_Ground_MossRubble_A_BaseColor.png` — замшелый каменный осыпной грунт, слой 4.

Это цветовые карты: реальные тени и свет добавляет движок. Повтор 5–5.5 м, mipmaps и анизотропная фильтрация. Слой 0 — прежние плиты Riverbank. Материал использует общий `assets/shaders/village_floor_blend.gdshader`, карту весов создаёт существующий `scripts/blended_floor.gd`. Подготовку материала повторяет `tools/update_riverbank_open_ground.gd`.

## Промпты

### 1

```text
Use case: stylized-concept. Asset type: one square seamless tiling game ground ALBEDO texture, full bleed 2048x2048. Strict orthographic overhead surface, no perspective, no props, no text, no borders, no lighting gradient, no cast shadows or specular reflections. Hand-painted chunky stylized dark Victorian gothic coastal ruins, matching Darksiders Genesis and Hades 2 visual direction. Low contrast restrained cool charcoal slate blue violet and muted earth palette; crisp painted facets and fine readable details, not blurry, not photoreal. All four edges must tile seamlessly. No large black cracks. Subject: worn irregular small slate cobblestones embedded in damp gray brown silt, sparse chipped fragments, uneven old quay pavement, broad quiet distribution with no central motif, approximately 5 metre surface patch.
```

### 2

```text
Use case: stylized-concept. Asset type: one square seamless tiling game ground ALBEDO texture, full bleed 2048x2048. Strict orthographic overhead surface, no perspective, no props, no text, no borders, no lighting gradient, no cast shadows or specular reflections. Hand-painted chunky stylized dark Victorian gothic coastal ruins, matching Darksiders Genesis and Hades 2 visual direction. Low contrast restrained cool charcoal slate blue violet and muted earth palette; crisp painted facets and fine readable details, not blurry, not photoreal. All four edges must tile seamlessly. No large black cracks. Subject: compact damp riverbank earth mixed with fine dark slate gravel, a few small flat stones, faint shallow water-smoothed ripples in silt, desaturated cool umber gray. No large puddles, no footprints, no roads, approximately 5 metre surface patch.
```

### 3

```text
Use case: stylized-concept. Asset type: one square seamless tiling game ground ALBEDO texture, full bleed 2048x2048. Strict orthographic overhead surface, no perspective, no props, no text, no borders, no lighting gradient, no cast shadows or specular reflections. Hand-painted chunky stylized dark Victorian gothic coastal ruins, matching Darksiders Genesis and Hades 2 visual direction. Low contrast restrained cool charcoal slate blue violet and muted earth palette; crisp painted facets and fine readable details, not blurry, not photoreal. All four edges must tile seamlessly. No large black cracks. Subject: sparse low muted olive moss threading among weathered blue gray stone chips and compact dark soil. Broken patches of moss with plenty of visible earth; no bright grass, no flowers, no large roots. Approximately 5 metre surface patch.
```
