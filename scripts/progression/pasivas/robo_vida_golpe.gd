extends Pasiva

func _init() -> void:
	id = "robo_vida_golpe"
	nombre = "Sed de Batalla"
	descripcion = "Tus golpes físicos curan 3 HP."
	categoria = "supervivencia"

func aplicar(player: Player) -> void:
	registrar_signal(player, &"ataque_critico", Callable(self, "_on_ataque").bind(player))

func _on_ataque(_objetivo: Node, _arma_tipo: String, _dano: float, player: Player) -> void:
	player.hp_actual = min(player.hp_actual + 3.0, player.get_hp_max())
	player.emit_signal("recurso_cambiado", "hp", player.hp_actual, player.get_hp_max())
