extends Pasiva

func _init() -> void:
	id = "critico_regen_energia"
	nombre = "Crítico Revitalizante"
	descripcion = "Cada crítico regenera 5 de energía."
	categoria = "fisico"
	es_primo = true

func aplicar(player: Player) -> void:
	registrar_signal(player, &"ataque_critico", Callable(self, "_on_ataque_critico").bind(player))

func _on_ataque_critico(player: Player, _objetivo: Node, _arma_tipo: String, _dano: float) -> void:
	player.energia_actual = min(player.energia_actual + 5.0, player.energia_maxima)
	player.emit_signal("recurso_cambiado", "energia", player.energia_actual, player.energia_maxima)
