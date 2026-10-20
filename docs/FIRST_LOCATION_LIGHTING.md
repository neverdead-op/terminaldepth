# First-location visual pass

Target: user-supplied generated 3D reference, interpreted as warm local lamp pools, cold shadows, damp stone and fog. This is an actual Godot Forward+ scene, not image-to-3D reconstruction and not exact renderer matching.

After the author's request for substantially stronger darkness: moonlight_energy=0.14, village_ambient_energy=0.22, hero_fill_energy=0.28, volumetric fog density 0.025. Local FogVolumes add low mist at four street sections. Warm lamps inject light into the fog; only two nearest lamps cast shadows. Moon shadows use 4 cascades / 55 m maximum distance. SSAO, SSIL, SSR, Filmic and MSAA 4x are enabled. enhanced_lighting=false disables SSR/SSIL/volumetric fog/MSAA for a lighter mode. These values are exported on LunarIntro for Inspector changes.

Floor keeps the approved first texture, thin cracks and integrated red petals. garden_floor.gdshader adds shallow joint normal variation and patchy roughness for damp reflections; defaults of these effects remain off in other previews unless explicitly configured. This is approximate shader relief from base-color contrast, not a sculpted height map or mesh displacement.

Complete first-level gameplay remains: 8 packs of 5 enemies, chest and equipment gate, boss with reinforcements, first level-up, tavern transition, inventory retained. Existing weapon and monster models remain; no unrelated balance expansion.

Checks: test_first_location_lighting renders the actual scene with 41 enemies and bounded lamp shadows; test_village verifies the full route, each of the three narrow gates, equipment gate, boss XP, tavern services and exit to the next area. Captures: docs/screens/first_location_lighting.png, village_props_models.png. Recorded frame timings are local short runs, not a guaranteed campaign frame rate.
