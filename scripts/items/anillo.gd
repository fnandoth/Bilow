class_name Anillo
extends Item

const STAT_POOL := [
	"res_fisica_pct",
	"res_magica_pct",
	"res_debuffs_pct",
	"bonus_fuerza",
	"bonus_destreza",
	"bonus_inteligencia",
	"bonus_resistencia",
	"bonus_vitalidad",
	"bonus_arcano",
]

@export var bonus_critico: float = 0.0
@export var bonus_suerte: float = 0.0
@export var bonus_cdr: float = 0.0

func _init() -> void:
	tipo_item = "accesorio"
	nombre = "Anillo"
