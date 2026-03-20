class_name EquipamientoComponent
extends Node

signal equipo_cambiado(slot: String)

const ARMOR_SLOTS := ["casco", "pechera", "pantalon", "botas", "guantes", "cinturon"]
const ACCESSORY_SLOTS := ["amuleto", "anillo_1", "anillo_2"]
const HAND_SLOTS := ["mano_derecha", "mano_izquierda"]
const ALL_SLOTS := ARMOR_SLOTS + ACCESSORY_SLOTS + HAND_SLOTS

var casco: Armadura = null
var pechera: Armadura = null
var pantalon: Armadura = null
var botas: Armadura = null
var guantes: Armadura = null
var cinturon: Armadura = null
var amuleto: Amuleto = null
var anillo_1: Anillo = null
var anillo_2: Anillo = null
var mano_derecha: Item = null
var mano_izquierda: Item = null

func equipar(item: Item, slot: String) -> bool:
	# Valida que exista un item y que el nombre del slot esté soportado por el componente.
	if item == null or not ALL_SLOTS.has(slot):
		return false

	# Valida que el tipo concreto del item coincida con la familia permitida por el slot solicitado.
	if not _slot_acepta_item(slot, item):
		return false

	# Valida la restricción de armadura del Player antes de tocar el equipamiento actual.
	if item is Armadura and not _puede_equipar_armadura(item as Armadura):
		return false

	# Valida las reglas especiales de manos: arco solo en mano derecha y bloquea la izquierda.
	if slot in HAND_SLOTS and not _puede_equipar_en_manos(item, slot):
		return false

	if slot == "mano_derecha" and item is Arma and (item as Arma).tipo_arma == "arco":
		desequipar("mano_izquierda")

	# Si había item previo en el slot destino, se remueven primero sus modificadores antes de reemplazarlo.
	if _obtener_item_slot(slot) != null:
		desequipar(slot)

	_establecer_item_slot(slot, item)
	_aplicar_modificadores_item(item, slot)
	emit_signal("equipo_cambiado", slot)

	if slot == "mano_derecha" and item is Arma and (item as Arma).tipo_arma == "arco":
		emit_signal("equipo_cambiado", "mano_izquierda")
	return true

func desequipar(slot: String) -> Item:
	if not ALL_SLOTS.has(slot):
		return null
	var item := _obtener_item_slot(slot)
	if item == null:
		return null
	player().remover_modificador(slot)
	_establecer_item_slot(slot, null)
	emit_signal("equipo_cambiado", slot)
	return item

func obtener_item(slot: String) -> Item:
	if not ALL_SLOTS.has(slot):
		return null
	return _obtener_item_slot(slot)

func player() -> Player:
	return get_parent() as Player

func _slot_acepta_item(slot: String, item: Item) -> bool:
	# Valida compatibilidad fuerte entre categoría del slot y tipo de recurso recibido.
	if slot in ARMOR_SLOTS:
		return item is Armadura and _resolver_slot_armadura(item) == slot
	if slot == "amuleto":
		return item is Amuleto
	if slot == "anillo_1" or slot == "anillo_2":
		return item is Anillo
	if slot in HAND_SLOTS:
		return item is Arma
	return false

func _puede_equipar_armadura(item: Armadura) -> bool:
	# Delega en Player la validación de requisito de resistencia para la armadura concreta.
	var jugador := player()
	return jugador != null and jugador.puede_equipar_armadura(item.tipo_armadura)

func _puede_equipar_en_manos(item: Item, slot: String) -> bool:
	# Aplica la regla especial de manos: si ya hay arco en derecha, izquierda queda bloqueada; el arco solo entra a derecha.
	if not (item is Arma):
		return false
	var arma := item as Arma
	if arma.tipo_arma == "arco":
		return slot == "mano_derecha"
	if mano_derecha is Arma and (mano_derecha as Arma).tipo_arma == "arco" and slot == "mano_izquierda":
		return false
	return true

func _aplicar_modificadores_item(item: Item, fuente: String) -> void:
	var jugador := player()
	if jugador == null:
		return
	for mod in item.stats_extra:
		jugador.agregar_modificador(String(mod.get("stat", "")), float(mod.get("valor", 0.0)), fuente)

func _resolver_slot_armadura(item: Item) -> String:
	var slot := String(item.get("slot_equipamiento"))
	if slot.is_empty():
		slot = String(item.get("slot"))
	if not slot.is_empty():
		return slot
	var nombre := item.nombre.to_lower()
	for armor_slot in ARMOR_SLOTS:
		if nombre.contains(armor_slot):
			return armor_slot
	return ""

func _obtener_item_slot(slot: String) -> Item:
	return get(slot) as Item

func _establecer_item_slot(slot: String, item: Item) -> void:
	set(slot, item)
