# Gothic house — original game mesh

`gothic_house.glb`: standalone textured mesh, 3,322 triangles / 7 merged surfaces. Three embedded albedo textures (painted sandstone, oak, existing stylized slate). UVs are baked into the mesh; no triplanar dependency. Created as an original architectural interpretation of the user-provided Bloodborne screenshot; no extracted game models or textures. No interior or sculpted micro-ornament.

`gothic_house.tscn`: reusable Godot wrapper with a simple solid building collision. Full scale approx. 6 × 8.3 × 7.6 m including eaves and porch. Front +Z. `tools/build_gothic_house.py` recreates the GLB without Blender or external libraries. Prompt set for generated base colors: `textures/prompts.md`. No fabricated normal or roughness textures; roughness set in materials.

F6 preview: `scenes/tools/gothic_house_preview.tscn`. Space pauses rotation, mouse wheel zooms. Screenshot: `docs/screens/gothic_house_model.png`. First village now uses this house family along the route; doors are decorative, buildings not enterable.
