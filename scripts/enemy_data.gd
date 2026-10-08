class_name EnemyData
extends Resource

## Тип врага. CONTACT — эта фаза; FLYING и BOSS объявлены сейчас, потому что
## типы перечислены в спеке §6.2, а добавление значения в enum позже сломает
## сохранения и проверки, читающие тип.
enum EnemyKind { CONTACT, FLYING, BOSS }

@export var display_name: String = "Enemy"
@export var max_health: float = 50.0
## Контактный урон за один тик контакта (каденция — у врага, не здесь).
@export var contact_damage: float = 10.0
@export var move_speed: float = 6.0
## Интервал между спавнами в секундах — для Фазы 3; поле здесь, чтобы данные
## были полными с первого дня (спека §6.2).
@export var spawn_interval: float = 1.5
@export var color: Color = Color(0.8, 0.25, 0.25)
@export var kind: EnemyKind = EnemyKind.CONTACT


## Пригодны ли данные к спавну. Враг спрашивает это до появления в мире, а не
## падает сам: нулевая скорость оставила бы врага висеть в точке спавна, нулевой
## контактный урон — бессмертным, а нулевой интервал спавна уронил бы волну.
func is_valid() -> bool:
	return max_health > 0.0 and contact_damage > 0.0 \
		and move_speed > 0.0 and spawn_interval > 0.0
