class_name Item
extends Resource

const RAREZA_MAX_STATS := {
	0: Vector2i(0, 0),
	1: Vector2i(1, 2),
	2: Vector2i(2, 3),
	3: Vector2i(4, 5),
	4: Vector2i(6, 6),
}

@export var nombre: String = "Item"
## Nombre visible del item.

@export var tipo_item: String = "material"
## Categoria general del item.

@export_range(0, 4, 1) var rareza: int = 0
## Rareza del item: 0 Comun a 4 Legendario.

@export var stats_extra: Array[Dictionary] = []
## Bonificaciones variables: [{stat: String, valor: float}].

@export var runs_restantes: int = 2
## Cantidad máxima de runs restantes dentro del cofre inter-run.

@export_range(0, 5, 1) var mejoras: int = 0
## Número de mejoras del taller aplicadas sobre el item.

func obtener_rango_stats_extra() -> Vector2i:
	return RAREZA_MAX_STATS.get(clampi(rareza, 0, 4), Vector2i.ZERO)

func puede_agregar_stats_extra(cantidad: int) -> bool:
	var rango := obtener_rango_stats_extra()
	return cantidad >= rango.x and cantidad <= rango.y

func limitar_stats_extra() -> void:
	var rango := obtener_rango_stats_extra()
	if stats_extra.size() > rango.y:
		stats_extra = stats_extra.slice(0, rango.y)
