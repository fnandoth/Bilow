extends Pasiva

const FUENTE := "pasiva_bruto_dano_espada"

func _init() -> void:
	id = "bruto_dano_espada"
	nombre = "Temple de Acero"
	descripcion = "+20% de daño con espadas."
	categoria = "bruto"
	tipo = "aumento_bruto"
	es_primo = true

func aplicar(player: Player) -> void:
	player.agregar_modificador("bonus_dano_espada_pct", 0.20, FUENTE)

func remover(player: Player) -> void:
	player.remover_modificador(FUENTE)
	super.remover(player)
