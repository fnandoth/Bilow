extends Node

const HUB_SCENE := "res://scenes/hub.tscn"

func procesar_retiro(player: Player, items_indices: Array[int] = []) -> void:
	if player == null:
		return
	var inventario := player.inventario_component
	if inventario != null:
		for indice in items_indices:
			var item := inventario.remover_item(indice)
			if item != null and not SaveManager.mover_item_a_cofre(item):
				inventario.agregar_item(item)
	if player.pasiva_manager != null:
		player.pasiva_manager.limpiar_pasivas()
	SaveManager.guardar_estado(player)
	get_tree().change_scene_to_file(HUB_SCENE)

func procesar_muerte(player: Player) -> void:
	if player == null:
		return
	SaveManager.guardar_oro(player)
