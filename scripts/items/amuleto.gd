class_name Amuleto
extends Item

const STAT_POOL := [
	"crit_prob_pct",
	"crit_dano_pct",
	"penetracion_elemental_pct",
	"mana_max",
	"recuperacion_recurso_pct",
	"bonus_suerte",
]

@export var aumento_stat_principal: Dictionary = {"stat": "fuerza", "valor": 0.0}
## Stat principal elevada del amuleto.

@export var aumento_dano_elemental: Dictionary = {"elemento": "fuego", "pct": 0.0}
## Bono porcentual a un elemento ofensivo.

@export var bonus_velocidad_mov: float = 0.0
## Incremento porcentual de velocidad de movimiento.

func _init() -> void:
	tipo_item = "accesorio"
	nombre = "Amuleto"
