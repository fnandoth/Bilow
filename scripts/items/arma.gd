class_name Arma
extends Item

@export var dano_base: float = 0.0
## Daño base del arma antes de escalados.

@export var ataques_por_s: float = 1.0
## Velocidad base de ataque por segundo.

@export var tipo_arma: String = "espada"
## Subtipo del arma: espada, daga, arco, maza, katana o escudo.

func _init() -> void:
	tipo_item = "arma"
	nombre = "Arma"
