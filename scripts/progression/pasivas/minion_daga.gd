extends Pasiva

func _init() -> void:
	id = "minion_daga"
	nombre = "Hoja Nigromante"
	descripcion = "Cada kill con daga genera un minion temporal que ataca al enemigo más cercano."
	categoria = "invocacion"
	es_primo = true

func aplicar(player: Player) -> void:
	registrar_signal(player, &"enemigo_derrotado", Callable(self, "_on_enemigo_derrotado").bind(player))

func _on_enemigo_derrotado(mob_ref: Mob, arma_tipo: String, player: Player) -> void:
	if arma_tipo != "daga":
		return
	player.invocar_minion_temporal(mob_ref.global_position)
