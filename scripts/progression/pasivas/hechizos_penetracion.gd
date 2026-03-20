extends Pasiva

const FUENTE := "pasiva_hechizos_penetracion"

func _init() -> void:
	id = "hechizos_penetracion"
	nombre = "Conjuro Perforante"
	descripcion = "Tus hechizos ignoran 20% de la resistencia mágica enemiga."
	categoria = "magico"
	es_primo = true

func aplicar(player: Player) -> void:
	player.agregar_modificador("hechizos_penetracion_pct", 0.20, FUENTE)

func remover(player: Player) -> void:
	player.remover_modificador(FUENTE)
	super.remover(player)
