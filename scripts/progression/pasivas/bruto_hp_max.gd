extends Pasiva

const FUENTE := "pasiva_bruto_hp_max"

func _init() -> void:
	id = "bruto_hp_max"
	nombre = "Pulso Colosal"
	descripcion = "+30 HP máximos."
	categoria = "bruto"
	tipo = "aumento_bruto"
	es_primo = true

func aplicar(player: Player) -> void:
	player.agregar_modificador("vitalidad", 3.0, FUENTE)

func remover(player: Player) -> void:
	player.remover_modificador(FUENTE)
	super.remover(player)
