extends RefCounted
## Нарисованный предмет (2D-картинка) в 3D-мире под нашей неподвижной камерой.
## Стоячий: плоскость лицом к камере, чуть откинута назад — заваливается в перспективе вместе с 3D-предметами.
## Лежачий (ground): картинка на земле, вытянута вглубь, чтобы с камеры выглядеть как нарисована (алтари, люки).

## Угол камеры над горизонтом (camera_rig.gd, elevation_degrees).
const ELEVATION_DEGREES := 45.0
## 0 — стоит вертикально (полный завал), 1 — смотрит прямо в камеру (без завала).
const DEFAULT_LEAN := 0.45


## width — ширина в метрах; низ картинки — в точке узла (у лежачей — центр).
static func make(texture: Texture2D, width: float, flip := false, ground := false, lean := DEFAULT_LEAN, elevation_degrees := ELEVATION_DEGREES) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = width / texture.get_width()
	sprite.flip_h = flip
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var elevation := deg_to_rad(elevation_degrees)
	if ground:
		sprite.rotation.x = -PI * 0.5
		sprite.scale.y = 1.0 / sin(elevation)
		sprite.position.y = 0.03
	else:
		sprite.offset = Vector2(0, texture.get_height() * 0.5)
		var tilt := elevation * (1.0 - lean)
		sprite.rotation.x = -tilt
		sprite.scale.y = 1.0 / cos(elevation - tilt)
	return sprite
