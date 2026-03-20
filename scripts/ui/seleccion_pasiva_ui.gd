class_name SeleccionPasivaUI
extends CanvasLayer

var _player: Player
var _opciones: Array[Pasiva] = []

func configurar(player: Player, opciones: Array[Pasiva]) -> void:
	_player = player
	_opciones = opciones

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	_construir_ui()

func _construir_ui() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.75)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360.0, -180.0)
	panel.size = Vector2(720.0, 360.0)
	panel.add_theme_constant_override("separation", 12)
	fondo.add_child(panel)

	var titulo := Label.new()
	titulo.text = "Elige una pasiva"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(titulo)

	var rejilla := GridContainer.new()
	rejilla.columns = 1 if _opciones.size() <= 3 else 2
	rejilla.add_theme_constant_override("h_separation", 14)
	rejilla.add_theme_constant_override("v_separation", 14)
	panel.add_child(rejilla)

	for opcion in _opciones:
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(320.0, 92.0)
		boton.text = "%s\n%s\nCategoría: %s" % [opcion.nombre, opcion.descripcion, opcion.categoria]
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boton.pressed.connect(_on_pasiva_elegida.bind(opcion))
		rejilla.add_child(boton)

func _on_pasiva_elegida(pasiva: Pasiva) -> void:
	var pasiva_manager := _player.get_node_or_null("PasivaManager") as PasivaManager
	if pasiva_manager != null:
		pasiva_manager.elegir_pasiva(pasiva)
	get_tree().paused = false
	queue_free()
