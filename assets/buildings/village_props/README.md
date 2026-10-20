# Victorian village props

Reusable original GLB meshes with baked UVs and stylized base colors. GLBs reference shared texture files by relative paths: keep them inside the project folder structure when moving assets. These props are not extracted from any game.

| Model | Triangles | Use |
| --- | ---: | --- |
| wall_straight | 60 | 2 m panel, about 2.9 m high including coping |
| gate_round | 324 | Round arch, 4.2 m clear opening, 12 m total span |
| basket | 112 | Hollow tapered wicker basket |
| crate | 108 | Oak crate |
| carriage | 872 | Enclosed coach with spoked wheels, bench and shafts |

Builder: tools/build_village_props.py, shared primitives tools/mesh_asset_builder.py. Brick and sandstone/oak use the previously generated stylized texture sets. Basket uses the new generated wicker texture; painted burgundy/iron/glass are plain material colors. Wicker generated with built-in imagegen; prompt in textures/prompts.md. Materials remain stylized and quiet, no photoreal scans.

Placed by scripts/village_set_dressing.gd, under the intro NavigationRegion so collisions affect navigation baking. Three archways: (-12,-34), (8,-68), (-6,-166). Their side piers narrow the street to 4.2 m. Carriage at (3.7,-3), baskets/crates along street edges. Camera-to-player collision rays fade occluding wall/arch meshes temporarily; collisions remain solid.

Model gallery: scenes/tools/village_props_preview.tscn (F6). Gameplay: scenes/tools/village_preview.tscn (F6, campaign writes disabled). No destructible prop gameplay or carriage motion added.
