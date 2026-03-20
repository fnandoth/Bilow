class_name PasivaManager
extends Node

signal pasiva_elegida(pasiva_id: String)

var pasivas_activas: Array[Pasiva] = []
var pool_clase: Array[Pasiva] = []
var pool_generico: Array[Pasiva] = []
var _ids_descubiertos: Dictionary = {}

func _ready() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	var clase_jugador:String = player.get_script().get_global_name() if player.get_script() != null else "Player"
	pool_clase = PasivaFactory.crear_pool_clase(clase_jugador)
	pool_generico = PasivaFactory.crear_pool_generico()

func elegir_pasiva(pasiva: Pasiva) -> void:
	var player := get_parent() as Player
	if player == null or pasiva == null:
		return
	var instancia := pasiva.get_script().new() as Pasiva
	instancia.aplicar(player)
	pasivas_activas.append(instancia)
	if not instancia.id.is_empty():
		_ids_descubiertos[instancia.id] = {
			"id": instancia.id,
			"nombre": instancia.nombre,
			"descripcion": instancia.descripcion,
			"categoria": instancia.categoria,
		}
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

func ids_descubiertos() -> Array[String]:
	var ids: Array[String] = []
	for pasiva_id in _ids_descubiertos.keys():
		ids.append(String(pasiva_id))
	ids.sort()
	return ids

func cargar_pasivas_descubiertas(ids: Array) -> void:
	for pasiva_id in ids:
		var pasiva := _buscar_pasiva_por_id(String(pasiva_id))
		if pasiva != null:
			_ids_descubiertos[String(pasiva_id)] = {
				"id": pasiva.id,
				"nombre": pasiva.nombre,
				"descripcion": pasiva.descripcion,
				"categoria": pasiva.categoria,
			}

func obtener_pasivas_descubiertas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for pasiva_id in ids_descubiertos():
		resultado.append((_ids_descubiertos[pasiva_id] as Dictionary).duplicate(true))
	return resultado

func _buscar_pasiva_por_id(id_pasiva: String) -> Pasiva:
	for pasiva in construir_pool_total():
		if pasiva.id == id_pasiva:
			return pasiva
	return null
