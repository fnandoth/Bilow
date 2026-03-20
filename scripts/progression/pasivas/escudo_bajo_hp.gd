extends Pasiva

func _init() -> void:
	id = "escudo_bajo_hp"
	nombre = "Último Baluarte"
	descripcion = "Al caer por debajo del 20% de HP, ganas un escudo de 30 HP una vez por sala."
	categoria = "supervivencia"
	es_primo = true

func aplicar(player: Player) -> void:
	_estado["usado"] = false
	registrar_signal(player, &"recurso_cambiado", Callable(self, "_on_recurso_cambiado").bind(player))
	registrar_signal(player, &"sala_iniciada", Callable(self, "_on_sala_iniciada"))

func _on_sala_iniciada(_sala: Sala) -> void:
	_estado["usado"] = false

func _on_recurso_cambiado(tipo: String, actual: float, maximo: float, player: Player) -> void:
	if tipo != "hp" or bool(_estado.get("usado", false)):
		return
	if maximo <= 0.0 or actual > maximo * 0.2:
		return
	_estado["usado"] = true
	player.otorgar_escudo_temporal(30.0)
