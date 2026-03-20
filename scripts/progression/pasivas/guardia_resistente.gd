extends Pasiva

const FUENTE := "pasiva_guardia_resistente"

func _init() -> void:
	id = "guardia_resistente"
	nombre = "Guardia Resistente"
	descripcion = "Ganas +2 de resistencia."
	categoria = "supervivencia"

func aplicar(player: Player) -> void:
	player.agregar_modificador("resistencia", 2.0, FUENTE)

func remover(player: Player) -> void:
	player.remover_modificador(FUENTE)
	super.remover(player)
