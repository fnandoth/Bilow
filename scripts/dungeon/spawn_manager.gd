class_name SpawnManager
extends Node

const GOBLIN_SCENE := preload("res://scripts/mobs/goblin.gd")
const LOBO_SCRIPT := preload("res://scripts/mobs/lobo.gd")
const DRAGON_SCENE := preload("res://scripts/mobs/dragon_jefe.gd")

@export var numero_piso_actual: int = 1

func spawnear_mobs(sala: Sala) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash([numero_piso_actual, sala.posicion_grid.x, sala.posicion_grid.y, sala.tipo, "spawn"])
	match sala.tipo:
		"combate":
			_spawnear_grupo(sala, random.randi_range(2, 6), [GOBLIN_SCENE])
		"arena":
			sala.preparar_oleadas(3)
			spawnear_siguiente_oleada(sala)
		"jefe":
			var jefe: Mob = DRAGON_SCENE.new()
			jefe.position = Vector3.ZERO
			sala.add_child(jefe)
			sala.registrar_mob(jefe)

func _spawnear_grupo(sala: Sala, cantidad: int, pool: Array, desplazamiento_x: float = 0.0) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash([numero_piso_actual, sala.posicion_grid.x, sala.posicion_grid.y, sala.tipo, cantidad, desplazamiento_x])
	for indice in cantidad:
		var script_recurso = pool[random.randi_range(0, pool.size() - 1)]
		var mob: Mob = script_recurso.new()
		mob.position = Vector3(
			random.randf_range(-sala.tamano_sala.x * 0.3, sala.tamano_sala.x * 0.3) + desplazamiento_x,
			0.0,
			random.randf_range(-sala.tamano_sala.y * 0.3, sala.tamano_sala.y * 0.3)
		)
		sala.add_child(mob)
		sala.registrar_mob(mob)

func spawnear_siguiente_oleada(sala: Sala) -> void:
	if sala.tipo != "arena":
		return
	if sala._oleadas_restantes <= 0:
		return
	var random := RandomNumberGenerator.new()
	random.seed = hash([numero_piso_actual, sala.posicion_grid.x, sala.posicion_grid.y, "oleada", sala._oleadas_restantes])
	var cantidad := random.randi_range(3, 5)
	sala.consumir_oleada()
	_spawnear_grupo(sala, cantidad, [GOBLIN_SCENE, LOBO_SCRIPT], 0.0)
