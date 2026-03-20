class_name InventoryUI
extends CanvasLayer

const INVENTORY_COLUMNS := 6
const INVENTORY_ROWS := 3
const CELL_SIZE := Vector2(60.0, 60.0)
const COLOR_VACIO := Color("#333333")
const COLOR_RAREZA := {
	0: Color("#AAAAAA"),
	1: Color("#55AA55"),
	2: Color("#5555FF"),
	3: Color("#AA00AA"),
	4: Color("#FFAA00"),
}
const SLOT_LABELS := {
	"casco": "Casco",
	"pechera": "Pechera",
	"pantalon": "Pantalón",
	"botas": "Botas",
	"guantes": "Guantes",
	"cinturon": "Cinturón",
	"amuleto": "Amuleto",
	"anillo_1": "Anillo 1",
	"anillo_2": "Anillo 2",
	"mano_derecha": "Mano derecha",
	"mano_izquierda": "Mano izquierda",
}
const SLOT_ORDER := ["casco", "pechera", "pantalon", "botas", "guantes", "cinturon", "amuleto", "anillo_1", "anillo_2", "mano_derecha", "mano_izquierda"]

var inventario: InventarioComponent
var equipamiento: EquipamientoComponent
var jugador: Player
var en_hub: bool = false

var _grid: GridContainer
var _celdas: Array[Dictionary] = []
var _tooltip_panel: Panel
var _tooltip_label: Label
var _menu_panel: Panel
var _menu_slot_index: int = -1
var _equipo_panel: VBoxContainer
var _equipo_labels: Dictionary = {}

func _ready() -> void:
	jugador = get_parent() as Player
	inventario = jugador.get_node_or_null("InventarioComponent") as InventarioComponent
	equipamiento = jugador.get_node_or_null("EquipamientoComponent") as EquipamientoComponent
	visible = true
	_build_ui()
	if inventario != null:
		inventario.inventario_cambiado.connect(_refrescar_inventario)
	if equipamiento != null:
		equipamiento.equipo_cambiado.connect(_on_equipo_cambiado)
	_refrescar_inventario()
	_refrescar_equipo()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "InventoryRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var inventory_panel := Panel.new()
	inventory_panel.position = Vector2(24.0, 120.0)
	inventory_panel.size = Vector2(420.0, 260.0)
	root.add_child(inventory_panel)

	var inventory_title := Label.new()
	inventory_title.text = "Inventario"
	inventory_title.position = Vector2(12.0, 10.0)
	inventory_panel.add_child(inventory_title)

	_grid = GridContainer.new()
	_grid.columns = INVENTORY_COLUMNS
	_grid.position = Vector2(12.0, 36.0)
	_grid.size = Vector2(390.0, 210.0)
	inventory_panel.add_child(_grid)

	for i in range(INVENTORY_COLUMNS * INVENTORY_ROWS):
		var cell_panel := Panel.new()
		cell_panel.custom_minimum_size = CELL_SIZE
		cell_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		cell_panel.gui_input.connect(_on_inventory_cell_input.bind(i))
		_grid.add_child(cell_panel)

		var color_rect := ColorRect.new()
		color_rect.name = "Color"
		color_rect.color = COLOR_VACIO
		color_rect.position = Vector2(6.0, 6.0)
		color_rect.size = CELL_SIZE - Vector2(12.0, 12.0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_panel.add_child(color_rect)

		var label := Label.new()
		label.name = "Index"
		label.text = str(i + 1)
		label.position = Vector2(4.0, 40.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_panel.add_child(label)

		_celdas.append({"panel": cell_panel, "color": color_rect})

	_equipo_panel = VBoxContainer.new()
	_equipo_panel.position = Vector2(470.0, 120.0)
	_equipo_panel.size = Vector2(260.0, 320.0)
	root.add_child(_equipo_panel)

	var equipo_title := Label.new()
	equipo_title.text = "Equipo"
	_equipo_panel.add_child(equipo_title)

	for slot in SLOT_ORDER:
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(240.0, 26.0)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_panel.gui_input.connect(_on_equipment_slot_input.bind(slot))
		_equipo_panel.add_child(slot_panel)

		var slot_label := Label.new()
		slot_label.position = Vector2(8.0, 4.0)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(slot_label)
		_equipo_labels[slot] = slot_label

	_tooltip_panel = Panel.new()
	_tooltip_panel.visible = false
	_tooltip_panel.size = Vector2(220.0, 120.0)
	root.add_child(_tooltip_panel)

	_tooltip_label = Label.new()
	_tooltip_label.position = Vector2(8.0, 8.0)
	_tooltip_label.size = Vector2(204.0, 104.0)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_panel.add_child(_tooltip_label)

	_menu_panel = Panel.new()
	_menu_panel.visible = false
	_menu_panel.size = Vector2(140.0, 110.0)
	root.add_child(_menu_panel)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.position = Vector2(8.0, 8.0)
	menu_vbox.size = Vector2(124.0, 94.0)
	_menu_panel.add_child(menu_vbox)

	var equip_button := Button.new()
	equip_button.text = "Equipar"
	equip_button.pressed.connect(_on_equip_pressed)
	menu_vbox.add_child(equip_button)

	var drop_button := Button.new()
	drop_button.text = "Descartar"
	drop_button.pressed.connect(_on_drop_pressed)
	menu_vbox.add_child(drop_button)

	var sell_button := Button.new()
	sell_button.text = "Vender"
	sell_button.pressed.connect(_on_sell_pressed)
	menu_vbox.add_child(sell_button)

func _refrescar_inventario() -> void:
	if inventario == null:
		return
	for i in range(_celdas.size()):
		var item := inventario.casillas[i]
		var color_rect := _celdas[i]["color"] as ColorRect
		color_rect.color = _obtener_color_item(item)

func _refrescar_equipo() -> void:
	if equipamiento == null:
		return
	for slot in SLOT_ORDER:
		var item := equipamiento.obtener_item(slot)
		var texto := "%s: %s" % [SLOT_LABELS[slot], "Vacío" if item == null else item.nombre]
		(_equipo_labels[slot] as Label).text = texto
		(_equipo_labels[slot] as Label).modulate = _obtener_color_item(item)

func _on_equipo_cambiado(_slot: String) -> void:
	_refrescar_equipo()
	_refrescar_inventario()

func _on_inventory_cell_input(event: InputEvent, indice: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	var item := inventario.casillas[indice]
	if item == null:
		_ocultar_popups()
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_mostrar_tooltip(item, mouse_event.global_position)
		_menu_panel.visible = false
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_mostrar_menu(indice, mouse_event.global_position)
		_tooltip_panel.visible = false

func _on_equipment_slot_input(event: InputEvent, slot: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var item := equipamiento.obtener_item(slot)
	if item == null:
		return
	var desequipado := equipamiento.desequipar(slot)
	if desequipado == null:
		return
	if inventario == null or not inventario.agregar_item(desequipado):
		equipamiento.equipar(desequipado, slot)

func _mostrar_tooltip(item: Item, posicion: Vector2) -> void:
	_tooltip_panel.position = posicion + Vector2(12.0, 12.0)
	_tooltip_label.text = _formatear_info_item(item)
	_tooltip_panel.visible = true

func _mostrar_menu(indice: int, posicion: Vector2) -> void:
	_menu_slot_index = indice
	_menu_panel.position = posicion + Vector2(12.0, 12.0)
	_menu_panel.visible = true

func _ocultar_popups() -> void:
	_tooltip_panel.visible = false
	_menu_panel.visible = false
	_menu_slot_index = -1

func _on_equip_pressed() -> void:
	if inventario == null or equipamiento == null or _menu_slot_index < 0:
		return
	var item := inventario.casillas[_menu_slot_index]
	var slot := _resolver_slot_para_item(item)
	if slot.is_empty():
		return
	var tomado := inventario.remover_item(_menu_slot_index)
	if tomado == null:
		return
	var previo := equipamiento.obtener_item(slot)
	var mano_izquierda_previa := equipamiento.mano_izquierda
	if tomado is Arma and (tomado as Arma).tipo_arma == "arco" and mano_izquierda_previa != null:
		if not inventario.tiene_espacio() and previo == null:
			inventario.agregar_item(tomado)
			return
		equipamiento.desequipar("mano_izquierda")
		inventario.agregar_item(mano_izquierda_previa)
	if equipamiento.equipar(tomado, slot):
		if previo != null:
			inventario.agregar_item(previo)
	else:
		inventario.agregar_item(tomado)
	_ocultar_popups()

func _on_drop_pressed() -> void:
	if inventario == null or _menu_slot_index < 0:
		return
	inventario.remover_item(_menu_slot_index)
	_ocultar_popups()

func _on_sell_pressed() -> void:
	if inventario == null or _menu_slot_index < 0 or not en_hub:
		return
	var item := inventario.remover_item(_menu_slot_index)
	if item != null and jugador != null:
		jugador.oro += max(1, item.rareza + 1)
	_ocultar_popups()

func _resolver_slot_para_item(item: Item) -> String:
	if item == null:
		return ""
	if item is Amuleto:
		return "amuleto"
	if item is Anillo:
		return "anillo_1" if equipamiento.anillo_1 == null else "anillo_2"
	if item is Armadura:
		var slot := String(item.get("slot_equipamiento"))
		if slot.is_empty():
			slot = String(item.get("slot"))
		if slot.is_empty():
			var nombre := item.nombre.to_lower()
			for armor_slot in ["casco", "pechera", "pantalon", "botas", "guantes", "cinturon"]:
				if nombre.contains(armor_slot):
					return armor_slot
		return slot
	if item is Arma:
		var arma := item as Arma
		if arma.tipo_arma == "arco":
			return "mano_derecha"
		if equipamiento.mano_derecha == null:
			return "mano_derecha"
		if equipamiento.mano_izquierda == null and not (equipamiento.mano_derecha is Arma and (equipamiento.mano_derecha as Arma).tipo_arma == "arco"):
			return "mano_izquierda"
		return "mano_derecha"
	return ""

func _formatear_info_item(item: Item) -> String:
	var lineas := ["Nombre: %s" % item.nombre, "Tipo: %s" % item.tipo_item]
	if item is Arma:
		lineas.append("Arma: %s" % (item as Arma).tipo_arma)
	if item is Armadura:
		lineas.append("Armadura: %s" % (item as Armadura).tipo_armadura)
	if item.stats_extra.is_empty():
		lineas.append("Stats: sin bonificaciones")
	else:
		lineas.append("Stats:")
		for mod in item.stats_extra:
			lineas.append("- %s: %s" % [String(mod.get("stat", "?")), str(mod.get("valor", 0.0))])
	return "\n".join(lineas)

func _obtener_color_item(item: Item) -> Color:
	if item == null:
		return COLOR_VACIO
	return COLOR_RAREZA.get(clampi(item.rareza, 0, 4), COLOR_RAREZA[0])
