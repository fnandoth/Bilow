class_name PasivaManager
extends Node

signal pasiva_elegida(pasiva_id: String)

var pasivas_activas: Array[Pasiva] = []
var pool_clase: Array[Pasiva] = []
var pool_generico: Array[Pasiva] = []

func _ready() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	var clase_jugador := player.get_script().get_global_name() if player.get_script() != null else "Player"
	pool_clase = PasivaFactory.crear_pool_clase(clase_jugador)
	pool_generico = PasivaFactory.crear_pool_generico()

func elegir_pasiva(pasiva: Pasiva) -> void:
	var player := get_parent() as Player
	if player == null or pasiva == null:
		return
	var instancia := pasiva.get_script().new() as Pasiva
	instancia.aplicar(player)
	pasivas_activas.append(instancia)
	emit_signal("pasiva_elegida", instancia.id)

func limpiar_pasivas() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	for pasiva in pasivas_activas:
		pasiva.remover(player)
	pasivas_activas.clear()

func construir_pool_total() -> Array[Pasiva]:
	var total: Array[Pasiva] = []
	for pasiva in pool_clase + pool_generico:
		total.append(pasiva)
	return total

func contar_pasiva_activa(id_pasiva: String) -> int:
	var repeticiones := 0
	for pasiva in pasivas_activas:
		if pasiva.id == id_pasiva:
			repeticiones += 1
	return repeticiones
