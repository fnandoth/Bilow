class_name Armadura
extends Item

const STAT_POOL := [
	"vitalidad",
	"resistencia",
	"res_fisica_pct",
	"res_fuego_pct",
	"res_hielo_pct",
	"res_rayo_pct",
	"res_veneno_pct",
]

@export var armadura_base: int = 0
## Valor base de mitigación física.

@export var tipo_armadura: String = "ligera"
## Peso de armadura: ligera, media o pesada.

@export var req_resistencia: int = 0
## Resistencia mínima para equiparla.

func _init() -> void:
	tipo_item = "armadura"
	nombre = "Armadura"
