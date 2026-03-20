class_name SaveManager
extends Node

const SAVE_PATH := "user://bilow_save.cfg"
const BESTIARY_PATH := "user://bilow_bestiary.cfg"
const CHEST_SLOTS := 12
const ITEM_SCRIPTS := {
	"Item": preload("res://scripts/items/item.gd"),
	"Arma": preload("res://scripts/items/arma.gd"),
	"Armadura": preload("res://scripts/items/armadura.gd"),
	"Anillo": preload("res://scripts/items/anillo.gd"),
	"Amuleto": preload("res://scripts/items/amuleto.gd"),
}
const MOB_DATABASE := {
	"Goblin": {
		"scene_name": "Goblin",
		"vida": 45.0,
		"armadura": 1.0,
		"drops": ["Arma común", "Anillo común"],
		"resistencias": {"fisica": 0.08, "magica": 0.02},
	},
	"Lobo": {
		"scene_name": "Lobo",
		"vida": 60.0,
		"armadura": 2.0,
		"drops": ["Armadura ligera", "Amuleto común"],
		"resistencias": {"fisica": 0.12, "magica": 0.05},
	},
	"Minotauro": {
		"scene_name": "Minotauro",
		"vida": 160.0,
		"armadura": 5.0,
		"drops": ["Arma épica", "Armadura pesada"],
		"resistencias": {"fisica": 0.22, "magica": 0.10},
	},
	"Dragon Jefe": {
		"scene_name": "DragonJefe",
		"vida": 420.0,
		"armadura": 10.0,
		"drops": ["Arma legendaria", "Amuleto legendario"],
		"resistencias": {"fisica": 0.30, "magica": 0.25},
	},
}

var save_cfg := ConfigFile.new()
var bestiary_cfg := ConfigFile.new()
var cofre_inter_run: Array = []

func _ready() -> void:
	_cargar_archivos()
	_asegurar_cofre_slots()

func guardar_estado(player: Player) -> void:
	# Serializa el estado global persistente del perfil (oro, pasivas y cofre) y lo guarda en disco.
	if player == null:
		return
	_cargar_archivos()
	_asegurar_cofre_slots()
	save_cfg.set_value("global", "oro", player.oro)
	var pasivas_descubiertas: Array[String] = []
	if player.pasiva_manager != null and player.pasiva_manager.has_method("ids_descubiertos"):
		pasivas_descubiertas = player.pasiva_manager.ids_descubiertos()
	save_cfg.set_value("global", "pasivas_descubiertas", pasivas_descubiertas)

	for indice in range(CHEST_SLOTS):
		var item := cofre_inter_run[indice] as Item
		save_cfg.set_value("cofre", "slot_%s" % indice, serializar_item(item))
	save_cfg.save(SAVE_PATH)

func guardar_oro(player: Player) -> void:
	if player == null:
		return
	_cargar_archivos()
	save_cfg.set_value("global", "oro", player.oro)
	save_cfg.save(SAVE_PATH)

func cargar_estado() -> Dictionary:
	# Deserializa el archivo principal y devuelve un diccionario listo para reconstruir el perfil actual.
	_cargar_archivos()
	_asegurar_cofre_slots()
	var estado := {
		"oro": int(save_cfg.get_value("global", "oro", 0)),
		"cofre": [],
		"pasivas_descubiertas": save_cfg.get_value("global", "pasivas_descubiertas", []),
	}
	for indice in range(CHEST_SLOTS):
		var item := deserializar_item(save_cfg.get_value("cofre", "slot_%s" % indice, null))
		cofre_inter_run[indice] = item
		estado["cofre"].append(item)
	return estado

func decrementar_runs_cofre() -> void:
	cargar_estado()
	for indice in range(CHEST_SLOTS):
		var item := cofre_inter_run[indice] as Item
		if item == null:
			continue
		item.runs_restantes -= 1
		if item.runs_restantes <= 0:
			cofre_inter_run[indice] = null
	guardar_estado_desde_cache()

func guardar_estado_desde_cache() -> void:
	_cargar_archivos()
	for indice in range(CHEST_SLOTS):
		save_cfg.set_value("cofre", "slot_%s" % indice, serializar_item(cofre_inter_run[indice]))
	save_cfg.save(SAVE_PATH)

func registrar_mob(nombre: String) -> void:
	bestiary_cfg.set_value(
		"mobs",
		nombre + "_kills",
		int(bestiary_cfg.get_value("mobs", nombre + "_kills", 0)) + 1
	)
	bestiary_cfg.save(BESTIARY_PATH)

func obtener_kills(nombre: String) -> int:
	return int(bestiary_cfg.get_value("mobs", nombre + "_kills", 0))

func obtener_mobs_registrados() -> Array[String]:
	_cargar_archivos()
	var nombres: Array[String] = []
	for clave in bestiary_cfg.get_section_keys("mobs"):
		if String(clave).ends_with("_kills"):
			nombres.append(String(clave).trim_suffix("_kills"))
	nombres.sort()
	return nombres

func obtener_info_mob(nombre: String) -> Dictionary:
	var data: Dictionary = MOB_DATABASE.get(nombre, {}).duplicate(true)
	data["kills"] = obtener_kills(nombre)
	return data

func serializar_item(item: Item) -> Variant:
	# Convierte un Resource Item en Dictionary para poder persistirlo en ConfigFile sin perder subtipo ni mejoras.
	if item == null:
		return null
	var data := {
		"class": item.get_script().get_global_name(),
		"nombre": item.nombre,
		"tipo_item": item.tipo_item,
		"rareza": item.rareza,
		"stats_extra": item.stats_extra.duplicate(true),
		"runs_restantes": int(item.get("runs_restantes")),
		"mejoras": int(item.get("mejoras")),
	}
	if item is Arma:
		data["dano_base"] = (item as Arma).dano_base
		data["ataques_por_s"] = (item as Arma).ataques_por_s
		data["tipo_arma"] = (item as Arma).tipo_arma
	if item is Armadura:
		data["armadura_base"] = (item as Armadura).armadura_base
		data["tipo_armadura"] = (item as Armadura).tipo_armadura
		data["req_resistencia"] = (item as Armadura).req_resistencia
	if item is Amuleto:
		data["aumento_stat_principal"] = (item as Amuleto).aumento_stat_principal.duplicate(true)
		data["aumento_dano_elemental"] = (item as Amuleto).aumento_dano_elemental.duplicate(true)
		data["bonus_velocidad_mov"] = (item as Amuleto).bonus_velocidad_mov
	if item is Anillo:
		data["bonus_critico"] = (item as Anillo).bonus_critico
		data["bonus_suerte"] = (item as Anillo).bonus_suerte
		data["bonus_cdr"] = (item as Anillo).bonus_cdr
	return data

func deserializar_item(data: Variant) -> Item:
	# Reconstruye un Item desde Dictionary restaurando el subtipo correcto y todos los campos persistentes.
	if data == null or not (data is Dictionary):
		return null
	var item_class := String((data as Dictionary).get("class", "Item"))
	var script := ITEM_SCRIPTS.get(item_class, ITEM_SCRIPTS["Item"])
	var item := script.new() as Item
	item.nombre = String(data.get("nombre", item.nombre))
	item.tipo_item = String(data.get("tipo_item", item.tipo_item))
	item.rareza = int(data.get("rareza", 0))
	item.stats_extra = (data.get("stats_extra", []) as Array).duplicate(true)
	item.runs_restantes = int(data.get("runs_restantes", 2))
	item.mejoras = int(data.get("mejoras", 0))
	if item is Arma:
		(item as Arma).dano_base = float(data.get("dano_base", 0.0))
		(item as Arma).ataques_por_s = float(data.get("ataques_por_s", 1.0))
		(item as Arma).tipo_arma = String(data.get("tipo_arma", "espada"))
	if item is Armadura:
		(item as Armadura).armadura_base = int(data.get("armadura_base", 0))
		(item as Armadura).tipo_armadura = String(data.get("tipo_armadura", "ligera"))
		(item as Armadura).req_resistencia = int(data.get("req_resistencia", 0))
	if item is Amuleto:
		(item as Amuleto).aumento_stat_principal = (data.get("aumento_stat_principal", {}) as Dictionary).duplicate(true)
		(item as Amuleto).aumento_dano_elemental = (data.get("aumento_dano_elemental", {}) as Dictionary).duplicate(true)
		(item as Amuleto).bonus_velocidad_mov = float(data.get("bonus_velocidad_mov", 0.0))
	if item is Anillo:
		(item as Anillo).bonus_critico = float(data.get("bonus_critico", 0.0))
		(item as Anillo).bonus_suerte = float(data.get("bonus_suerte", 0.0))
		(item as Anillo).bonus_cdr = float(data.get("bonus_cdr", 0.0))
	return item

func vender_item_cofre(indice: int) -> int:
	cargar_estado()
	if indice < 0 or indice >= cofre_inter_run.size():
		return 0
	var item := cofre_inter_run[indice] as Item
	if item == null:
		return 0
	var precio := calcular_precio(item)
	cofre_inter_run[indice] = null
	guardar_estado_desde_cache()
	return precio

func calcular_precio(item: Item) -> int:
	if item == null:
		return 0
	return item.rareza * 10 + item.stats_extra.size() * 5

func mover_item_a_cofre(item: Item) -> bool:
	cargar_estado()
	if item == null:
		return false
	item.runs_restantes = max(1, int(item.get("runs_restantes")))
	if item.runs_restantes <= 0:
		item.runs_restantes = 2
	for indice in range(CHEST_SLOTS):
		if cofre_inter_run[indice] == null:
			cofre_inter_run[indice] = item
			guardar_estado_desde_cache()
			return true
	return false

func _cargar_archivos() -> void:
	save_cfg = ConfigFile.new()
	bestiary_cfg = ConfigFile.new()
	save_cfg.load(SAVE_PATH)
	bestiary_cfg.load(BESTIARY_PATH)

func _asegurar_cofre_slots() -> void:
	if cofre_inter_run.size() != CHEST_SLOTS:
		cofre_inter_run.resize(CHEST_SLOTS)
		for indice in range(CHEST_SLOTS):
			if cofre_inter_run[indice] == null:
				cofre_inter_run[indice] = null
