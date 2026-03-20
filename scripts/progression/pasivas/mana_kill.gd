extends Pasiva

func _init() -> void:
	id = "mana_kill"
	nombre = "Sifón Arcano"
	descripcion = "Cada enemigo derrotado te devuelve 8 de maná."
	categoria = "magico"

func aplicar(player: Player) -> void:
	registrar_signal(player, &"enemigo_derrotado", Callable(self, "_on_enemigo_derrotado").bind(player))

func _on_enemigo_derrotado(_mob_ref: Mob, _arma_tipo: String, player: Player) -> void:
	player.mana_actual = min(player.mana_actual + 8.0, player.get_mana_max())
	player.emit_signal("recurso_cambiado", "mana", player.mana_actual, player.get_mana_max())
