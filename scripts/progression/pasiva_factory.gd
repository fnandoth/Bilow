class_name PasivaFactory
extends RefCounted

const CRITICO_REGEN_SCRIPT := preload("res://scripts/progression/pasivas/critico_regen_energia.gd")
const HECHIZOS_PEN_SCRIPT := preload("res://scripts/progression/pasivas/hechizos_penetracion.gd")
const ESCUDO_BAJO_HP_SCRIPT := preload("res://scripts/progression/pasivas/escudo_bajo_hp.gd")
const MINION_DAGA_SCRIPT := preload("res://scripts/progression/pasivas/minion_daga.gd")
const ESQUIVA_GRATIS_SCRIPT := preload("res://scripts/progression/pasivas/esquiva_gratis.gd")
const BRUTO_DANO_ESPADA_SCRIPT := preload("res://scripts/progression/pasivas/bruto_dano_espada.gd")
const BRUTO_HP_MAX_SCRIPT := preload("res://scripts/progression/pasivas/bruto_hp_max.gd")
const MANA_KILL_SCRIPT := preload("res://scripts/progression/pasivas/mana_kill.gd")
const ROBO_VIDA_SCRIPT := preload("res://scripts/progression/pasivas/robo_vida_golpe.gd")
const FOCO_SPRINT_SCRIPT := preload("res://scripts/progression/pasivas/foco_sprint.gd")
const GUARDIA_RESISTENTE_SCRIPT := preload("res://scripts/progression/pasivas/guardia_resistente.gd")

static func crear_pool_generico() -> Array[Pasiva]:
	return [
		CRITICO_REGEN_SCRIPT.new(),
		HECHIZOS_PEN_SCRIPT.new(),
		ESCUDO_BAJO_HP_SCRIPT.new(),
		ESQUIVA_GRATIS_SCRIPT.new(),
		BRUTO_HP_MAX_SCRIPT.new(),
		MANA_KILL_SCRIPT.new(),
		ROBO_VIDA_SCRIPT.new(),
		FOCO_SPRINT_SCRIPT.new(),
		GUARDIA_RESISTENTE_SCRIPT.new(),
	]

static func crear_pool_clase(nombre_clase: String) -> Array[Pasiva]:
	var pool: Array[Pasiva] = []
	match nombre_clase.to_lower():
		"guerrero", "samurai", "paladin":
			pool.append(BRUTO_DANO_ESPADA_SCRIPT.new())
		"nigromante":
			pool.append(MINION_DAGA_SCRIPT.new())
		_:
			pool.append(MINION_DAGA_SCRIPT.new())
			pool.append(BRUTO_DANO_ESPADA_SCRIPT.new())
	return pool
