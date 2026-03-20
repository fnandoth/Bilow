class_name NivelManager
extends Node

signal nivel_subido(nivel: int)

const PRIMOS := [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]
const UI_SCRIPT := preload("res://scripts/ui/seleccion_pasiva_ui.gd")

var experiencia: float = 0.0
var nivel_actual: int = 1
var tabla_xp: Array[float] = [0.0]

func _ready() -> void:
	_generar_tabla_xp(50)
	var player := get_parent() as Player
	if player != null and not player.jugador_murio.is_connected(_on_jugador_murio):
		player.jugador_murio.connect(_on_jugador_murio)

func ganar_xp(cantidad: float) -> void:
	experiencia += cantidad
	while nivel_actual < tabla_xp.size() and experiencia >= tabla_xp[nivel_actual]:
		subir_nivel()

func subir_nivel() -> void:
	var costo_nivel := tabla_xp[nivel_actual]
	nivel_actual += 1
	experiencia -= costo_nivel
	emit_signal("nivel_subido", nivel_actual)
	mostrar_seleccion_pasiva(nivel_actual)

func mostrar_seleccion_pasiva(nivel: int) -> void:
	var player := get_parent() as Player
	if player == null:
		return
	var pasiva_manager := player.get_node_or_null("PasivaManager") as PasivaManager
	if pasiva_manager == null:
		return
	var opciones: Array[Pasiva] = []
	var es_primo := PRIMOS.has(nivel)
	if es_primo:
		opciones.append_array(_seleccionar_aleatorias(_filtrar_por_primo(pasiva_manager.construir_pool_total(), true, false), 3))
		opciones.append_array(_seleccionar_aleatorias(_filtrar_por_primo(pasiva_manager.construir_pool_total(), false, true), 2))
	else:
		# La dilución usa peso = 1 / (1 + repeticiones_activas). Cuantas más veces haya salido una pasiva en la build,
		# menor es su peso relativo dentro del pool mezclado de clase + genéricas, así baja la probabilidad de repetirla.
		var pool_normal: Array[Pasiva] = []
		for pasiva in pasiva_manager.construir_pool_total():
			if not pasiva.es_primo and pasiva.tipo != "aumento_bruto":
				pool_normal.append(pasiva)
		opciones = _seleccionar_ponderadas(pool_normal, pasiva_manager, 5)
	var ui := UI_SCRIPT.new()
	ui.name = "SeleccionPasivaUI"
	ui.configurar(player, opciones)
	add_child(ui)

func registrar_mob(mob: Mob) -> void:
	if mob == null or mob.mob_murio.is_connected(_on_mob_murio):
		return
	mob.mob_murio.connect(_on_mob_murio)

func _on_mob_murio(mob_ref: Mob) -> void:
	ganar_xp(mob_ref.xp_reward)
	var player := get_parent() as Player
	if player != null:
		player.registrar_muerte_enemigo(mob_ref)

func _generar_tabla_xp(niveles: int) -> void:
	tabla_xp.clear()
	tabla_xp.append(0.0)
	for nivel in range(1, niveles + 1):
		tabla_xp.append(pow(float(nivel), 2.0) * 80.0 + float(nivel) * 20.0)

func _filtrar_por_primo(pool: Array[Pasiva], solo_primo: bool, solo_bruto: bool) -> Array[Pasiva]:
	var filtrado: Array[Pasiva] = []
	for pasiva in pool:
		if solo_bruto and pasiva.tipo == "aumento_bruto":
			filtrado.append(pasiva)
		elif solo_primo and pasiva.es_primo and pasiva.tipo != "aumento_bruto":
			filtrado.append(pasiva)
	return filtrado

func _seleccionar_aleatorias(pool: Array[Pasiva], cantidad: int) -> Array[Pasiva]:
	var copia := pool.duplicate()
	copia.shuffle()
	return copia.slice(0, min(cantidad, copia.size()))

func _seleccionar_ponderadas(pool: Array[Pasiva], pasiva_manager: PasivaManager, cantidad: int) -> Array[Pasiva]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var disponibles := pool.duplicate()
	var seleccionadas: Array[Pasiva] = []
	while not disponibles.is_empty() and seleccionadas.size() < cantidad:
		var peso_total := 0.0
		var pesos: Array[float] = []
		for pasiva in disponibles:
			var repeticiones := pasiva_manager.contar_pasiva_activa(pasiva.id)
			var peso := 1.0 / (1.0 + float(repeticiones))
			pesos.append(peso)
			peso_total += peso
		var tirada := rng.randf() * peso_total
		var acumulado := 0.0
		for indice in range(disponibles.size()):
			acumulado += pesos[indice]
			if tirada <= acumulado:
				seleccionadas.append(disponibles[indice])
				disponibles.remove_at(indice)
				break
	return seleccionadas

func _on_jugador_murio() -> void:
	var player := get_parent() as Player
	if player != null:
		var pasiva_manager := player.get_node_or_null("PasivaManager") as PasivaManager
		if pasiva_manager != null:
			pasiva_manager.limpiar_pasivas()
