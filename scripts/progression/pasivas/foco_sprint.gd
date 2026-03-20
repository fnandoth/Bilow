extends Pasiva

const FUENTE := "pasiva_foco_sprint"

func _init() -> void:
	id = "foco_sprint"
	nombre = "Zancada Medida"
	descripcion = "Mientras corres, ganas +2 de destreza."
	categoria = "movimiento"

func aplicar(player: Player) -> void:
	player.agregar_modificador("destreza", 2.0, FUENTE)

func remover(player: Player) -> void:
	player.remover_modificador(FUENTE)
	super.remover(player)
