class_name ItemFactory
extends Resource

const WEAPON_TYPES := ["espada", "daga", "arco", "maza", "katana", "escudo"]
const ARMOR_TYPES := ["ligera", "media", "pesada"]
const ARMOR_EQUIP_SLOTS := ["casco", "pechera", "pantalon", "botas", "guantes", "cinturon"]
const ELEMENTS := ["fuego", "hielo", "rayo", "veneno", "sagrado", "sombras"]
const MAIN_STATS := ["fuerza", "destreza", "inteligencia", "resistencia", "vitalidad", "arcano"]
const WEAPON_STAT_POOL := [
	"fuerza",
	"destreza",
	"inteligencia",
	"crit_prob_pct",
	"crit_dano_pct",
	"vel_ataque_pct",
	"dano_area_pct",
]
const DEFAULT_ITEM_NAMES := {
	"arma": "Arma %s",
	"armadura": "Armadura %s",
	"anillo": "Anillo %s",
	"amuleto": "Amuleto %s",
}

static var _rng := RandomNumberGenerator.new()
static var _rng_inicializado := false

static func generar(tipo: String, rareza: int) -> Item:
	if not _rng_inicializado:
		_rng.randomize()
		_rng_inicializado = true
	var rareza_normalizada := clampi(rareza, 0, 4)
	var item := _crear_base(tipo.to_lower(), rareza_normalizada, _rng)
	if item == null:
		return null

	item.stats_extra = _generar_stats_extra_para_item(item, _rng)
	item.limitar_stats_extra()
	return item

static func _crear_base(tipo: String, rareza: int, rng: RandomNumberGenerator) -> Item:
	match tipo:
		"arma":
			var arma := Arma.new()
			arma.rareza = rareza
			arma.tipo_arma = WEAPON_TYPES[rng.randi_range(0, WEAPON_TYPES.size() - 1)]
			arma.dano_base = rng.randf_range(12.0, 55.0) * (1.0 + rareza * 0.35)
			arma.ataques_por_s = rng.randf_range(0.9, 1.8)
			arma.nombre = DEFAULT_ITEM_NAMES["arma"] % _capitalizar(arma.tipo_arma)
			return arma
		"armadura":
			var armadura := Armadura.new()
			armadura.rareza = rareza
			armadura.tipo_armadura = ARMOR_TYPES[rng.randi_range(0, ARMOR_TYPES.size() - 1)]
			armadura.slot_equipamiento = ARMOR_EQUIP_SLOTS[rng.randi_range(0, ARMOR_EQUIP_SLOTS.size() - 1)]
			armadura.armadura_base = rng.randi_range(8, 30) + rareza * 10
			armadura.req_resistencia = rng.randi_range(0, 8) + rareza * 4
			armadura.nombre = "%s %s" % [_capitalizar(armadura.slot_equipamiento), _capitalizar(armadura.tipo_armadura)]
			return armadura
		"anillo":
			var anillo := Anillo.new()
			anillo.rareza = rareza
			anillo.nombre = DEFAULT_ITEM_NAMES["anillo"] % _nombre_rareza(rareza)
			return anillo
		"amuleto":
			var amuleto := Amuleto.new()
			amuleto.rareza = rareza
			amuleto.aumento_stat_principal = {
				"stat": MAIN_STATS[rng.randi_range(0, MAIN_STATS.size() - 1)],
				"valor": rng.randf_range(8.0, 18.0) * (1.0 + rareza * 0.25),
			}
			amuleto.aumento_dano_elemental = {
				"elemento": ELEMENTS[rng.randi_range(0, ELEMENTS.size() - 1)],
				"pct": rng.randf_range(0.08, 0.22) * (1.0 + rareza * 0.15),
			}
			amuleto.bonus_velocidad_mov = rng.randf_range(0.03, 0.12) * (1.0 + rareza * 0.10)
			amuleto.nombre = DEFAULT_ITEM_NAMES["amuleto"] % _nombre_rareza(rareza)
			return amuleto
		_:
			return null

static func _generar_stats_extra_para_item(item: Item, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var rango := item.obtener_rango_stats_extra()
	if rango.y == 0:
		return []

	var cantidad := rng.randi_range(rango.x, rango.y)
	var pool := _obtener_pool_por_item(item)
	var disponibles := pool.duplicate()
	var resultado: Array[Dictionary] = []

	for _indice in range(cantidad):
		if disponibles.is_empty():
			break
		var idx := rng.randi_range(0, disponibles.size() - 1)
		var stat: String = disponibles[idx]
		disponibles.remove_at(idx)
		resultado.append({
			"stat": stat,
			"valor": _valor_para_stat(stat, item.rareza, rng),
		})

	return resultado

static func _obtener_pool_por_item(item: Item) -> Array[String]:
	if item is Armadura:
		return Armadura.STAT_POOL.duplicate()
	if item is Anillo:
		return Anillo.STAT_POOL.duplicate()
	if item is Amuleto:
		return Amuleto.STAT_POOL.duplicate()
	return WEAPON_STAT_POOL.duplicate()

static func _valor_para_stat(stat: String, rareza: int, rng: RandomNumberGenerator) -> float:
	var multiplicador := 1.0 + rareza * 0.30
	match stat:
		"fuerza", "destreza", "inteligencia", "resistencia", "vitalidad", "arcano":
			return roundf(rng.randf_range(2.0, 8.0) * multiplicador)
		"bonus_fuerza", "bonus_destreza", "bonus_inteligencia", "bonus_resistencia", "bonus_vitalidad", "bonus_arcano":
			return roundf(rng.randf_range(3.0, 10.0) * multiplicador)
		"res_fisica_pct", "res_magica_pct", "res_debuffs_pct", "res_fuego_pct", "res_hielo_pct", "res_rayo_pct", "res_veneno_pct", "crit_prob_pct", "vel_ataque_pct", "dano_area_pct", "penetracion_elemental_pct", "recuperacion_recurso_pct", "bonus_suerte":
			return snappedf(rng.randf_range(0.03, 0.16) * multiplicador, 0.01)
		"crit_dano_pct":
			return snappedf(rng.randf_range(0.10, 0.35) * multiplicador, 0.01)
		"mana_max":
			return roundf(rng.randf_range(15.0, 45.0) * multiplicador)
		_:
			return roundf(rng.randf_range(1.0, 5.0) * multiplicador)

static func _nombre_rareza(rareza: int) -> String:
	match rareza:
		0:
			return "Comun"
		1:
			return "Poco Comun"
		2:
			return "Raro"
		3:
			return "Epico"
		4:
			return "Legendario"
		_:
			return "Comun"

static func _capitalizar(texto: String) -> String:
	if texto.is_empty():
		return texto
	return texto.substr(0, 1).to_upper() + texto.substr(1)
