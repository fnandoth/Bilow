extends Node3D

const DUNGEON_SCENE := "res://scenes/dungeon_stub.tscn"
const CHEST_COLUMNS := 4
const CHEST_SLOTS := 12

var player: Player
var oro_label: Label
var overlay: CanvasLayer
var panel_contenido: VBoxContainer
var panel_titulo: Label
var dialogo_salida: ConfirmationDialog

func _ready() -> void:
	_construir_base_hub()
	_construir_overlay()
	_cargar_o_crear_player()
	_refrescar_oro()

func _construir_base_hub() -> void:
	var suelo := CSGBox3D.new()
	suelo.size = Vector3(16.0, 0.5, 16.0)
	suelo.position = Vector3(0.0, -0.25, 0.0)
	var suelo_mat := StandardMaterial3D.new()
	suelo_mat.albedo_color = Color(0.12, 0.24, 0.14)
	suelo.material = suelo_mat
	add_child(suelo)

	for pared_data in [
		{"size": Vector3(16.0, 4.0, 0.5), "pos": Vector3(0.0, 2.0, -8.0)},
		{"size": Vector3(16.0, 4.0, 0.5), "pos": Vector3(0.0, 2.0, 8.0)},
		{"size": Vector3(0.5, 4.0, 16.0), "pos": Vector3(-8.0, 2.0, 0.0)},
		{"size": Vector3(0.5, 4.0, 16.0), "pos": Vector3(8.0, 2.0, 0.0)},
	]:
		var pared := CSGBox3D.new()
		pared.size = pared_data["size"]
		pared.position = pared_data["pos"]
		var pared_mat := StandardMaterial3D.new()
		pared_mat.albedo_color = Color(0.88, 0.82, 0.68)
		pared.material = pared_mat
		add_child(pared)

	_crear_zona("ZonaCofre", Vector3(-4.5, 0.5, -3.0), Color(0.65, 0.42, 0.12), _on_zona_cofre_activada)
	_crear_zona("ZonaTaller", Vector3(4.5, 0.5, -3.0), Color(0.35, 0.35, 0.35), _on_zona_taller_activada)
	_crear_zona("ZonaBestiario", Vector3(-4.5, 0.5, 3.0), Color(0.25, 0.25, 0.5), _on_zona_bestiario_activada)
	_crear_zona("ZonaSalida", Vector3(4.5, 0.5, 3.0), Color(0.2, 0.5, 0.25), _on_zona_salida_activada)
	_crear_zona("LibroPasivas", Vector3(0.0, 0.5, 0.0), Color(0.55, 0.18, 0.18), _on_libro_pasivas_activado)

func _crear_zona(nombre: String, posicion: Vector3, color: Color, callback: Callable) -> void:
	var area := Area3D.new()
	area.name = nombre
	area.position = posicion
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.0, 2.2)
	shape.shape = box
	area.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 1.0, 2.0)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	area.add_child(visual)
	area.body_entered.connect(callback)
	add_child(area)

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

func _cargar_o_crear_player() -> void:
	var estado := SaveManager.cargar_estado()
	player = Player.new()
	player.name = "PlayerHub"
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 6.0)
	player.cargar_estado_guardado(estado)
	player.inventory_ui.visible = false
	player._ui_recursos.visible = false

func _refrescar_oro() -> void:
	if oro_label != null and player != null:
		oro_label.text = "Oro: %s" % player.oro

func _limpiar_panel() -> void:
	for child in panel_contenido.get_children():
		panel_contenido.remove_child(child)
		child.queue_free()

func _on_zona_cofre_activada(body: Node3D) -> void:
	if body != player:
		return
	_mostrar_cofre()

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

func _vender_item_cofre(indice: int) -> void:
	var oro := SaveManager.vender_item_cofre(indice)
	if oro > 0:
		player.oro += oro
		SaveManager.guardar_estado(player)
		_refrescar_oro()
		_mostrar_cofre()

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

func _on_zona_salida_activada(body: Node3D) -> void:
	if body != player:
		return
	dialogo_salida.popup_centered()

func _volver_a_dungeon() -> void:
	SaveManager.guardar_estado(player)
	SaveManager.decrementar_runs_cofre()
	get_tree().change_scene_to_file(DUNGEON_SCENE)

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
