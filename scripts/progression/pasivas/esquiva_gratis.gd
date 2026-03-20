extends Pasiva

const FUENTE := "pasiva_esquiva_gratis"

func _init() -> void:
	id = "esquiva_gratis"
	nombre = "Inercia Asesina"
	descripcion = "Si esquivas dentro de 2 segundos tras una kill, no gastas energía."
	categoria = "movimiento"

func aplicar(player: Player) -> void:
	registrar_signal(player, &"enemigo_derrotado", Callable(self, "_on_enemigo_derrotado").bind(player))
	registrar_signal(player, &"esquive_realizado", Callable(self, "_on_esquive_realizado").bind(player))

func _on_enemigo_derrotado(_mob_ref: Mob, _arma_tipo: String, player: Player) -> void:
	player.agregar_modificador("esquiva_gratis_hasta", Time.get_ticks_msec() + 2000.0, FUENTE)

func _on_esquive_realizado(player: Player) -> void:
	var expiracion := player.get_modificador("esquiva_gratis_hasta")
	if expiracion >= float(Time.get_ticks_msec()):
		player.reembolsar_energia(player.get_ultimo_costo_esquiva())
	player.remover_modificador(FUENTE)

func remover(player: Player) -> void:
	player.remover_modificador(FUENTE)
	super.remover(player)
