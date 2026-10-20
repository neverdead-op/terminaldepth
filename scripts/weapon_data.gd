class_name WeaponData
extends Resource
## Описание оружия: все цифры в одном файле (.tres в папке data/weapons).
## Открыть двойным щелчком в FileSystem — и менять в Inspector.
## Позже на эту основу лягут предметы: редкость и свойства будут менять эти числа.

@export var display_name := "Оружие"

@export_group("Стрельба")
## Может ли попадание включать длительную анимацию падения/отшатывания врага.
@export var allow_hit_stagger := true
@export var damage := 10.0  ## урон одной пули (у дробовика — одной дробинки)
@export var fire_rate := 5.0  ## выстрелов в секунду
## true — стреляет, пока зажата кнопка; false — один выстрел на одно нажатие.
@export var automatic := true
@export var pellets := 1  ## сколько пуль за выстрел (дробовик — много)
@export_range(0.0, 45.0) var spread_degrees := 2.0  ## разброс в обе стороны
## Конус при установленном «Мультишоте»; базовый разброс остаётся самостоятельным.
@export_range(0.0, 45.0) var multishot_spread_degrees := 7.0
## Размер тёмных дробинок в изображении, не меняет их урон и столкновения.
@export_range(0.5, 3.0, 0.1) var pellet_visual_scale := 1.0
@export var bullet_speed := 45.0
@export var bullet_range := 30.0  ## дальность полёта пули, м
@export var projectile_width := 0.0 ## ширина плазменной полосы и её проверки попадания, м
@export var secondary_skill := &"" ## grenade или plasma_pulse
@export var secondary_damage_mult := 2.6
@export var secondary_width := 1.8
@export var secondary_charge := 0.32
@export var secondary_cooldown := 2.4
@export var secondary_pierce := 0
@export var secondary_ammo_cost := 2

@export_group("Особенности базы")
## Вид снаряда: bullet — пуля, arrow — энергетическая стрела, grenade — граната (взрыв в конце полёта),
## flame — струя огня (не высекает искр, расширяется и гаснет).
@export var projectile := &"bullet"
## Встроенные свойства базы (модули и вещи добавляются сверху).
@export var pierce := 0
@export var explode_radius := 0.0
@export var explode_ratio := 0.0
@export var element := &""
@export var element_ratio := 0.0

@export_group("Магазин")
@export var magazine_size := 12
@export var reload_time := 1.5  ## сек

@export_group("Ощущения")
@export var shot_sound := &"shot_pistol"
@export var shot_volume_db := 0.0
## Толчок камеры при выстреле (м). 0 — без толчка.
@export var camera_kick := 0.03
@export var muzzle_flash_energy := 4.0
@export var smoke_interval := 0.14 ## не накапливать дым при непрерывной очереди
## Тряска камеры при выстреле (0.05 — лёгкая, 0.3 — сильная).
@export var recoil_shake := 0.06
@export var recoil_shake_cap := 0.38
## Насколько оружие дёргается назад в руках (м).
@export var gun_kick := 0.06
@export var gun_return_time := 0.13
@export var body_recoil_degrees := 2.0
@export var body_recoil_return := 14.0
## Отдача всем телом: модель героини отбрасывает назад на столько метров и возвращает за body_push_return с.
@export var body_push := 0.0
@export var body_push_return := 0.22
## Плечи и руки дёргает вверх-назад (доля от body_recoil_degrees): ствол «подбрасывает».
@export_range(0.0, 2.0) var arm_recoil := 0.0
## Вибрация геймпада при выстреле: слабый и сильный моторы (0..1) и длительность (сек).
@export_range(0.0, 1.0) var vibration_weak := 0.2
@export_range(0.0, 1.0) var vibration_strong := 0.0
@export var vibration_time := 0.06

@export_group("Вид (временная заглушка)")
## Иконка в меню оружия: pistol, rifle или shotgun (рисуется кодом, пока нет картинок).
@export var icon := &"pistol"
## Модель оружия в руке (из Sci-Fi Essentials). Пусто — брусок-заглушка ниже.
@export var model: PackedScene
@export var model_scale := 1.0
## Сдвиг модели в руке (м): x — вбок, y — вверх, z — назад (минус — вперёд по стволу).
@export var model_offset := Vector3.ZERO
## Поворот модели вокруг вертикали: у моделей пака ствол смотрит вдоль −X, а нужно вдоль −Z.
@export var model_yaw := -90.0
## Размер бруска-заглушки: ширина, высота, длина.
@export var model_size := Vector3(0.05, 0.1, 0.24)
@export var model_color := Color(0.08, 0.08, 0.09)


@export_group("Хват оружия")
## Поправка рукояти относительно правой ладони.
@export var grip_offset := Vector3.ZERO
@export var grip_rotation_degrees := Vector3.ZERO
@export var support_hand_enabled := true
## Точка левого запястья относительно оружия (метры): под цевьём.
@export var support_hand_offset := Vector3(-0.055, -0.035, -0.12)
@export var pistol_support_offset := Vector3(-0.055, -0.025, 0.08)
