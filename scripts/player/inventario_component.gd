class_name InventarioComponent
extends Node

signal inventario_cambiado()

const CAPACIDAD := 18

var casillas: Array[Item] = []

func _ready() -> void:
	_inicializar_casillas()

func _inicializar_casillas() -> void:
	casillas.clear()
	casillas.resize(CAPACIDAD)
	for i in range(CAPACIDAD):
		casillas[i] = null

func agregar_item(item: Item) -> bool:
	if item == null:
		return false
	for i in range(casillas.size()):
		if casillas[i] == null:
			casillas[i] = item
			emit_signal("inventario_cambiado")
			return true
	return false

func remover_item(indice: int) -> Item:
	if indice < 0 or indice >= casillas.size():
		return null
	var item := casillas[indice]
	casillas[indice] = null
	emit_signal("inventario_cambiado")
	return item

func mover_item(desde: int, hasta: int) -> void:
	if desde < 0 or desde >= casillas.size():
		return
	if hasta < 0 or hasta >= casillas.size():
		return
	var temporal := casillas[desde]
	casillas[desde] = casillas[hasta]
	casillas[hasta] = temporal
	emit_signal("inventario_cambiado")

func tiene_espacio() -> bool:
	for item in casillas:
		if item == null:
			return true
	return false
