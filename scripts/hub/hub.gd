extends Node3D

const DUNGEON_SCENE := "res://scenes/dungeon_stub.tscn"
const CHEST_COLUMNS := 4
const CHEST_SLOTS := 12
const TAMANO_PIEZA := 2.0
const TAMANO_HUB_PIEZAS := 10
const ORIGEN_HUB := -9.0
const COLOR_LUZ_ESQUINA := Color(1.0, 0.92, 0.72)
const FALLBACK_PROPS := ["barrel", "crate"]

var player: Player
var oro_label: Label
var overlay: CanvasLayer
var panel_contenido: VBoxContainer
var panel_titulo: Label
var dialogo_salida: ConfirmationDialog

# Construye la sala fija del Hub con piezas KayKit, overlay UI y jugador persistente al cargar la escena principal.
func _ready() -> void:
	_construir_base_hub()
	_construir_overlay()
	_cargar_o_crear_player()
	_refrescar_oro()

# Monta suelo, perímetro, props interactivos, áreas de sub-zona y luces interiores en coordenadas modulares de 2u para un hub de 20x20.
func _construir_base_hub() -> void:
	for x in range(TAMANO_HUB_PIEZAS):
		for z in range(TAMANO_HUB_PIEZAS):
			_instanciar_grupo("floor", _coordenada_hub(x, z))
	for x in range(TAMANO_HUB_PIEZAS):
		if x in [4, 5]:
			_instanciar_grupo(_grupo_puerta(), _coordenada_hub(x, 0), PI)
		else:
			_instanciar_grupo(_grupo_pared(), _coordenada_hub(x, 0), 0.0)
		if x == 0 or x == TAMANO_HUB_PIEZAS - 1:
			continue
		_instanciar_grupo(_grupo_pared(), _coordenada_hub(x, TAMANO_HUB_PIEZAS - 1), PI)
	for z in range(1, TAMANO_HUB_PIEZAS - 1):
		_instanciar_grupo(_grupo_pared(), _coordenada_hub(0, z), PI * 0.5)
		_instanciar_grupo(_grupo_pared(), _coordenada_hub(TAMANO_HUB_PIEZAS - 1, z), -PI * 0.5)
	_instanciar_grupo(_grupo_esquina(), _coordenada_hub(0, 0), 0.0)
	_instanciar_grupo(_grupo_esquina(), _coordenada_hub(TAMANO_HUB_PIEZAS - 1, 0), -PI * 0.5)
	_instanciar_grupo(_grupo_esquina(), _coordenada_hub(TAMANO_HUB_PIEZAS - 1, TAMANO_HUB_PIEZAS - 1), PI)
	_instanciar_grupo(_grupo_esquina(), _coordenada_hub(0, TAMANO_HUB_PIEZAS - 1), PI * 0.5)
	var prop_cofre := _instanciar_prop_con_fallback(["chest"], "ZonaCofre", Vector3(-6.0, 0.0, -2.0))
	var prop_taller := _instanciar_prop_con_fallback(["anvil", "forge"], "ZonaTaller", Vector3(6.0, 0.0, -2.0))
	var prop_bestiario := _instanciar_prop_con_fallback(["bookcase", "shelf"], "ZonaBestiario", Vector3(0.0, 0.0, 6.0))
	var prop_libro := _instanciar_prop_con_fallback(["table"], "LibroPasivas", Vector3(-6.0, 0.0, 6.0))
	_instanciar_prop_con_fallback(["book"], "LibroPasivas", Vector3(-5.6, 1.1, 6.0))
	var prop_salida := _instanciar_prop_con_fallback(["stairs", "gate"], "ZonaSalida", Vector3(0.0, 0.0, -6.0))
	_crear_zona("ZonaCofre", prop_cofre.position + Vector3(0.0, 0.5, 0.0), _on_zona_cofre_activada)
	_crear_zona("ZonaTaller", prop_taller.position + Vector3(0.0, 0.5, 0.0), _on_zona_taller_activada)
	_crear_zona("ZonaBestiario", prop_bestiario.position + Vector3(0.0, 0.5, 0.0), _on_zona_bestiario_activada)
	_crear_zona("LibroPasivas", prop_libro.position + Vector3(0.0, 0.5, 0.0), _on_libro_pasivas_activado)
	_crear_zona("ZonaSalida", prop_salida.position + Vector3(0.0, 0.5, 0.0), _on_zona_salida_activada)
	_agregar_luces_hub()

# Devuelve la coordenada mundial de una pieza modular del Hub para mantener todas las instancias alineadas a la retícula de 2 unidades.
func _coordenada_hub(x: int, z: int) -> Vector3:
	return Vector3(ORIGEN_HUB + x * TAMANO_PIEZA, 0.0, ORIGEN_HUB + z * TAMANO_PIEZA)

# Instancia una pieza del grupo pedido en la coordenada exacta del Hub y aplica la rotación cardinal que la alinea con el muro o prop deseado.
func _instanciar_grupo(nombre_grupo: String, posicion: Vector3, rot_y: float = 0.0) -> Node3D:
	var grupos := AssetManager.obtener_grupo(nombre_grupo)
	if grupos.is_empty() and nombre_grupo == "door":
		grupos = AssetManager.obtener_grupo("doorway")
	if grupos.is_empty() and nombre_grupo == "wall_corner":
		grupos = AssetManager.obtener_grupo("corner")
	if grupos.is_empty() and nombre_grupo == "wall":
		return _crear_fallback_visual(posicion, rot_y)
	if grupos.is_empty():
		push_warning("Hub: sin piezas para grupo '" + nombre_grupo + "'")
		return _crear_fallback_visual(posicion, rot_y)
	var escena := AssetManager.obtener(grupos.pick_random())
	if escena == null:
		return _crear_fallback_visual(posicion, rot_y)
	var instancia := escena.instantiate() as Node3D
	if instancia == null:
		return _crear_fallback_visual(posicion, rot_y)
	instancia.position = posicion
	instancia.rotation.y = rot_y
	add_child(instancia)
	return instancia

# Busca un prop por prioridad semántica y lo coloca en la coordenada indicada; si falta, usa barrel/crate para que la sub-zona siga siendo visible.
func _instanciar_prop_con_fallback(preferencias: Array[String], etiqueta: String, posicion: Vector3) -> Node3D:
	for nombre in preferencias:
		var grupo := AssetManager.obtener_grupo(nombre)
		if not grupo.is_empty():
			return _instanciar_grupo(grupo.pick_random(), posicion)
	for fallback in FALLBACK_PROPS:
		var grupo_fallback := AssetManager.obtener_grupo(fallback)
		if not grupo_fallback.is_empty():
			push_warning("Hub: prop faltante en %s, usando fallback '%s'." % [etiqueta, fallback])
			return _instanciar_grupo(grupo_fallback.pick_random(), posicion)
	push_warning("Hub: sin props ni fallbacks para %s." % etiqueta)
	return _crear_fallback_visual(posicion, 0.0)

# Crea un Area3D esférico de radio 2 sobre el prop correspondiente para conservar la lógica de interacción del Prompt 7 sin cambiar callbacks.
func _crear_zona(nombre: String, posicion: Vector3, callback: Callable) -> void:
	var area := Area3D.new()
	area.name = nombre
	area.position = posicion
	var shape := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 2.0
	shape.shape = esfera
	area.add_child(shape)
	area.body_entered.connect(callback)
	add_child(area)

# Añade una luz central y cuatro luces cálidas en las esquinas del Hub para iluminar la sala interior sin usar DirectionalLight3D.
func _agregar_luces_hub() -> void:
	var central := OmniLight3D.new()
	central.position = Vector3(0.0, 4.0, 0.0)
	central.light_energy = 1.2
	central.omni_range = 25.0
	add_child(central)
	for esquina in [Vector3(-7.0, 3.0, -7.0), Vector3(7.0, 3.0, -7.0), Vector3(7.0, 3.0, 7.0), Vector3(-7.0, 3.0, 7.0)]:
		var luz := OmniLight3D.new()
		luz.position = esquina
		luz.light_energy = 0.6
		luz.omni_range = 12.0
		luz.light_color = COLOR_LUZ_ESQUINA
		add_child(luz)

# Expone el grupo de pared recta elegido para el perímetro del Hub priorizando variantes legibles de KayKit.
func _grupo_pared() -> String:
	return "wall"

# Expone el grupo de esquina elegido para cerrar correctamente las cuatro esquinas exteriores del Hub.
func _grupo_esquina() -> String:
	return "wall_corner" if not AssetManager.obtener_grupo("wall_corner").is_empty() else "corner"

# Expone el grupo de puerta elegido para el hueco norte del Hub priorizando doorway cuando existe en el catálogo.
func _grupo_puerta() -> String:
	return "doorway" if not AssetManager.obtener_grupo("doorway").is_empty() else "door"

# Crea un bloque magenta visible en la coordenada faltante para que cualquier asset del Hub ausente se detecte enseguida en pruebas manuales.
func _crear_fallback_visual(posicion: Vector3, rot_y: float) -> Node3D:
	var mesh := CSGBox3D.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	mesh.position = posicion + Vector3(0.0, 1.0, 0.0)
	mesh.rotation.y = rot_y
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#FF00FF")
	mesh.material = material
	add_child(mesh)
	return mesh

# Construye la capa UI del Hub con panel persistente, texto guía y diálogo para volver a la dungeon desde la zona de salida.
func _construir_overlay() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)
	oro_label = Label.new()
	oro_label.position = Vector2(24.0, 24.0)
	root.add_child(oro_label)
	var panel := Panel.new()
	panel.position = Vector2(24.0, 64.0)
	panel.size = Vector2(720.0, 520.0)
	root.add_child(panel)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margen)
	panel_contenido = VBoxContainer.new()
	margen.add_child(panel_contenido)
	panel_titulo = Label.new()
	panel_contenido.add_child(panel_titulo)
	var hint := Label.new()
	hint.text = "Entra en una zona del Hub para interactuar."
	panel_contenido.add_child(hint)
	var dialogo := ConfirmationDialog.new()
	dialogo.title = "Salida"
	dialogo.dialog_text = "¿Volver a la dungeon?"
	dialogo.confirmed.connect(_volver_a_dungeon)
	root.add_child(dialogo)
	dialogo_salida = dialogo

# Carga el estado persistente del jugador y lo ubica dentro del Hub en una coordenada despejada cercana al acceso norte.
func _cargar_o_crear_player() -> void:
	var estado := SaveManager.cargar_estado()
	player = Player.new()
	player.name = "PlayerHub"
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 6.0)
	player.cargar_estado_guardado(estado)
	player.inventory_ui.visible = false
	player._ui_recursos.visible = false

# Refresca la etiqueta de oro para que el panel del Hub siempre muestre el recurso persistente actualizado del jugador.
func _refrescar_oro() -> void:
	if oro_label != null and player != null:
		oro_label.text = "Oro: %s" % player.oro

# Vacía el contenido dinámico del panel lateral antes de abrir otra sub-zona y reconstruir su UI contextual.
func _limpiar_panel() -> void:
	for child in panel_contenido.get_children():
		panel_contenido.remove_child(child)
		child.queue_free()

# Reacciona cuando el jugador entra al área del cofre para abrir la interfaz del cofre inter-run en esa sub-zona oeste.
func _on_zona_cofre_activada(body: Node3D) -> void:
	if body != player:
		return
	_mostrar_cofre()

# Construye la UI del cofre inter-run con 12 slots para gestionar items guardados entre runs desde la pared oeste del Hub.
func _mostrar_cofre() -> void:
	_limpiar_panel()
	panel_titulo = Label.new()
	panel_titulo.text = "Cofre inter-run"
	panel_contenido.add_child(panel_titulo)
	var grid := GridContainer.new()
	grid.columns = CHEST_COLUMNS
	panel_contenido.add_child(grid)
	for indice in range(CHEST_SLOTS):
		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(160.0, 120.0)
		grid.add_child(slot)
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(150.0, 72.0)
		slot.add_child(panel)
		var color := ColorRect.new()
		color.position = Vector2(8.0, 8.0)
		color.size = Vector2(134.0, 56.0)
		var item := SaveManager.cofre_inter_run[indice] as Item
		color.color = Color(0.2, 0.2, 0.2) if item == null else InventoryUI.COLOR_RAREZA.get(item.rareza, Color.WHITE)
		panel.add_child(color)
		var nombre := Label.new()
		nombre.position = Vector2(12.0, 12.0)
		nombre.text = "Vacío" if item == null else item.nombre
		panel.add_child(nombre)
		var runs := Label.new()
		runs.position = Vector2(12.0, 36.0)
		runs.text = "Runs: -" if item == null else "Runs: %s" % item.runs_restantes
		panel.add_child(runs)
		var vender := Button.new()
		vender.text = "Vender"
		vender.disabled = item == null
		vender.pressed.connect(_vender_item_cofre.bind(indice))
		slot.add_child(vender)

# Vende el item almacenado en el slot indicado, actualiza oro persistente y reconstruye la vista del cofre en la misma sub-zona.
func _vender_item_cofre(indice: int) -> void:
	var oro := SaveManager.vender_item_cofre(indice)
	if oro > 0:
		player.oro += oro
		SaveManager.guardar_estado(player)
		_refrescar_oro()
		_mostrar_cofre()

# Reacciona cuando el jugador entra al taller del lado este para ofrecer mejoras a su equipamiento equipado.
func _on_zona_taller_activada(body: Node3D) -> void:
	if body != player:
		return
	_limpiar_panel()
	var titulo := Label.new()
	titulo.text = "Taller"
	panel_contenido.add_child(titulo)
	for slot in EquipamientoComponent.ALL_SLOTS:
		var item := player.equipamiento_component.obtener_item(slot)
		if item == null:
			continue
		var fila := HBoxContainer.new()
		panel_contenido.add_child(fila)
		var label := Label.new()
		label.text = "%s: %s (mejoras %s/5)" % [slot, item.nombre, item.mejoras]
		fila.add_child(label)
		var boton := Button.new()
		var costo := (item.rareza + 1) * 50
		boton.text = "Mejorar (%s oro)" % costo
		boton.disabled = item.mejoras >= 5 or player.oro < costo
		boton.pressed.connect(_mejorar_item.bind(item, costo))
		fila.add_child(boton)

# Aplica la mejora elegida al item en el taller del Hub y actualiza inmediatamente oro, estado persistente y panel activo.
func _mejorar_item(item: Item, costo: int) -> void:
	if item == null or player.oro < costo or item.mejoras >= 5:
		return
	player.oro -= costo
	if item is Arma:
		(item as Arma).dano_base *= 1.10
	elif item is Armadura:
		(item as Armadura).armadura_base = int(round((item as Armadura).armadura_base * 1.10))
	item.mejoras += 1
	SaveManager.guardar_estado(player)
	_refrescar_oro()
	_on_zona_taller_activada(player)

# Reacciona cuando el jugador entra al bestiario del sur para desplegar la información persistente de mobs descubiertos.
func _on_zona_bestiario_activada(body: Node3D) -> void:
	if body != player:
		return
	_limpiar_panel()
	var titulo := Label.new()
	titulo.text = "Bestiario"
	panel_contenido.add_child(titulo)
	for nombre in SaveManager.obtener_mobs_registrados():
		var info := SaveManager.obtener_info_mob(nombre)
		var texto := "%s — kills: %s" % [nombre, info.get("kills", 0)]
		if int(info.get("kills", 0)) >= 10:
			texto += " | vida: %s armadura: %s drops: %s" % [info.get("vida", "?"), info.get("armadura", "?"), ", ".join(info.get("drops", []))]
		if int(info.get("kills", 0)) >= 50:
			var resistencias := info.get("resistencias", {}) as Dictionary
			texto += " | resistencias: física %s mágica %s" % [resistencias.get("fisica", "?"), resistencias.get("magica", "?")]
		var label := Label.new()
		label.text = texto
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel_contenido.add_child(label)

# Reacciona cuando el jugador pisa la salida norte para mostrar el diálogo de confirmación antes de regresar a la dungeon.
func _on_zona_salida_activada(body: Node3D) -> void:
	if body != player:
		return
	dialogo_salida.popup_centered()

# Guarda el estado del jugador y cambia a la escena de dungeon cuando se confirma la salida desde la puerta norte del Hub.
func _volver_a_dungeon() -> void:
	SaveManager.guardar_estado(player)
	SaveManager.decrementar_runs_cofre()
	get_tree().change_scene_to_file(DUNGEON_SCENE)

# Reacciona cuando el jugador entra al libro de pasivas del suroeste para listar las pasivas descubiertas en el panel UI.
func _on_libro_pasivas_activado(body: Node3D) -> void:
	if body != player:
		return
	_limpiar_panel()
	var titulo := Label.new()
	titulo.text = "Libro de pasivas"
	panel_contenido.add_child(titulo)
	for entrada in player.obtener_pasivas_descubiertas_descriptivas():
		var label := Label.new()
		label.text = "%s [%s]: %s" % [entrada.get("nombre", "?"), entrada.get("categoria", "?"), entrada.get("descripcion", "")]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel_contenido.add_child(label)
