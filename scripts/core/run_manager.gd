extends Node

const HUB_SCENE := "res://scenes/hub.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon_stub.tscn"
const PLAYER_NAME := "Player"

var numero_piso_actual: int = 1
var player: Player
var viene_del_hub: bool = false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().current_scene_changed.connect(_on_current_scene_changed)
	if get_tree().current_scene != null:
		_on_current_scene_changed(get_tree().current_scene)

func procesar_retiro(player_ref: Player, items_indices: Array[int] = []) -> void:
	if player_ref == null:
		return
	var inventario := player_ref.inventario_component
	if inventario != null:
		for indice in items_indices:
			var item := inventario.remover_item(indice)
			if item != null and not SaveManager.mover_item_a_cofre(item):
				inventario.agregar_item(item)
	if player_ref.pasiva_manager != null:
		player_ref.pasiva_manager.limpiar_pasivas()
	SaveManager.guardar_estado(player_ref)
	player = player_ref
	get_tree().change_scene_to_file(HUB_SCENE)

func procesar_muerte(player_ref: Player) -> void:
	if player_ref == null:
		return
	SaveManager.guardar_oro(player_ref)

func _on_node_added(node: Node) -> void:
	if node is Player:
		player = node as Player
		if String(node.name).is_empty():
			node.name = PLAYER_NAME

func _on_current_scene_changed(scene: Node) -> void:
	if scene == null:
		return
	if scene.scene_file_path == DUNGEON_SCENE:
		_configurar_dungeon(scene)
	elif scene.scene_file_path == HUB_SCENE:
		call_deferred("_posicionar_jugador_en_hub", scene)

func _configurar_dungeon(scene: Node) -> void:
	if GeneradorPiso.get_parent() != scene:
		if GeneradorPiso.get_parent() != null:
			GeneradorPiso.get_parent().remove_child(GeneradorPiso)
		scene.add_child(GeneradorPiso)
	if not GeneradorPiso.piso_listo.is_connected(_on_piso_listo):
		GeneradorPiso.piso_listo.connect(_on_piso_listo)
	GeneradorPiso.generar_piso(numero_piso_actual)

func _posicionar_jugador_en_hub(scene: Node) -> void:
	var hub := scene as Node3D
	if hub == null:
		return
	var spawn_point := hub.get_node_or_null("SpawnPoint") as Node3D
	if spawn_point == null:
		return
	var player_ref := _obtener_o_instanciar_jugador(hub)
	if player_ref == null:
		return
	player_ref.global_position = spawn_point.global_position

func _on_piso_listo(posicion_inicio: Vector3) -> void:
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		return
	var player_ref := _obtener_o_instanciar_jugador(scene)
	if player_ref == null:
		return
	player_ref.global_position = posicion_inicio
	if viene_del_hub:
		viene_del_hub = false

func _obtener_o_instanciar_jugador(parent: Node3D) -> Player:
	if is_instance_valid(player) and player.get_parent() == parent:
		return player
	var existente := parent.get_node_or_null(PLAYER_NAME)
	if existente is Player:
		player = existente as Player
		return player
	player = Player.new()
	player.name = PLAYER_NAME
	parent.add_child(player)
	var estado := SaveManager.cargar_estado()
	player.cargar_estado_guardado(estado)
	return player
