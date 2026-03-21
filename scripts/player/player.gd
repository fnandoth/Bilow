class_name Player
extends CharacterBody3D

signal stat_cambiada(nombre: String, valor_nuevo: float)
signal jugador_murio()
signal recurso_cambiado(tipo: String, actual: float, maximo: float)
signal ataque_critico(objetivo: Node, arma_tipo: String, dano: float)
signal enemigo_derrotado(mob_ref: Mob, arma_tipo: String)
signal esquive_realizado()
signal sala_iniciada(sala: Sala)

const VELOCIDAD_BASE: float = 5.0
const VELOCIDAD_SPRINT: float = 8.5
const COSTO_SPRINT: float = 5.0
const COSTO_ATAQUE_BASE: float = 10.0
const COSTO_ESQUIVAR: float = 20.0
const GRAVEDAD: float = 9.8
const SENSIBILIDAD_X: float = 0.003
const SENSIBILIDAD_Y: float = 0.002
const ALTURA_OJOS: float = 1.6
const DISTANCIA_TERCERA_PERSONA: float = 5.0
const IMPULSO_ESQUIVAR: float = 9.5
const GATE_ARMADURA := {
	"ligera": 0.0,
	"media": 20.0,
	"pesada": 40.0,
}
const STATS := ["fuerza", "destreza", "inteligencia", "resistencia", "vitalidad", "arcano"]

@export var energia_maxima: float = 100.0
## Energía total disponible para sprint y futuras acciones.

@export var energia_actual: float = 100.0
## Energía actual consumida por sprint y otras habilidades.

@export var hp_actual: float = 0.0
## Vida actual calculada desde Vitalidad.

@export var mana_actual: float = 0.0
## Maná actual calculado desde Inteligencia y Arcano.

@export var color_clase: Color = Color(1.0, 1.0, 1.0, 1.0)
## Color del material de la cápsula para identificar la clase.

@export var stats_base: Dictionary = {}
## Valores base de las 6 estadísticas del personaje.

@export var stats_modificadores: Dictionary = {}
## Suma acumulada de bonificaciones activas por stat.

var oro: int = 0
var inventario_component: InventarioComponent
var equipamiento_component: EquipamientoComponent
var inventory_ui: InventoryUI

var en_primera_persona: bool = false
var _modificadores_por_fuente: Dictionary = {}
var _stats_cache: Dictionary = {}
var _cam_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _mesh_capsula: MeshInstance3D
var _collision_capsula: CollisionShape3D
var _ui_recursos: CanvasLayer
var _barras_recursos: Dictionary = {}
var _muerto: bool = false
var _modificadores_gameplay: Dictionary = {}
var _ultimo_tipo_arma_usada: String = ""
var _ultimo_costo_esquiva: float = 0.0
var _escudo_temporal_actual: float = 0.0
var nivel_manager: NivelManager
var pasiva_manager: PasivaManager

func _ready() -> void:
	# Inicializa estadísticas base, recursos y el rig visual/cámara del jugador.
	_inicializar_stats()
	_asegurar_stats_completas()
	_construir_capsula_placeholder()
	_construir_rig_camara()
	_construir_ui_recursos()
	_construir_componentes_inventario()
	_construir_componentes_progresion()
	recurso_cambiado.connect(_on_recurso_cambiado)
	_recalcular_todas_las_stats()
	_sincronizar_recursos_desde_stats(true)
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	# El pivot sigue la posición del jugador sin heredar su rotación para desacoplar cámara y facing.
	if _cam_pivot != null:
		_cam_pivot.global_position = global_position

	_regenerar_recursos(delta)

func _input(event: InputEvent) -> void:
	# Gestiona cámara con mouse capturado y toggles de captura/primera persona.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_cam_pivot.rotate_y(-event.relative.x * SENSIBILIDAD_X)
		_spring_arm.rotate_x(-event.relative.y * SENSIBILIDAD_Y)
		_spring_arm.rotation.x = clamp(_spring_arm.rotation.x, -PI / 3.0, PI / 6.0)

	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_mode()

	if event.is_action_pressed("toggle_camara"):
		toggle_primera_persona()

	if event.is_action_pressed("esquivar"):
		esquivar()

func _physics_process(delta: float) -> void:
	# Lee input en plano XZ y lo transforma a espacio mundo usando la orientación horizontal del pivot.
	var direccion_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direccion_local := Vector3(direccion_input.x, 0.0, direccion_input.y)
	var dir_mundo := (_cam_pivot.global_transform.basis * direccion_local).normalized()
	var en_movimiento := dir_mundo.length_squared() > 0.0
	var velocidad_actual := VELOCIDAD_BASE

	# Correr cuesta 5 por segundo y usa la fórmula escalada por Destreza con mínimo de 2.
	if en_movimiento and Input.is_action_pressed("sprint") and gastar_energia(COSTO_SPRINT * delta):
		velocidad_actual = VELOCIDAD_SPRINT

	velocity.x = dir_mundo.x * velocidad_actual
	velocity.z = dir_mundo.z * velocidad_actual

	# Se aplica gravedad acumulativa para respetar el comportamiento físico de CharacterBody3D.
	if not is_on_floor():
		velocity.y -= GRAVEDAD * delta
	else:
		velocity.y = 0.0

	# Se usa slerp sobre la base para interpolar suavemente la rotación y evitar giros bruscos cuadro a cuadro.
	if en_movimiento:
		var objetivo := Transform3D().looking_at(dir_mundo, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(objetivo.basis, 10.0 * delta).orthonormalized()

	move_and_slide()

func _inicializar_stats() -> void:
	# Define los valores base de la clase; las subclases sobrescriben este método.
	stats_base = {
		"fuerza": 5.0,
		"destreza": 5.0,
		"inteligencia": 5.0,
		"resistencia": 5.0,
		"vitalidad": 5.0,
		"arcano": 5.0,
	}
	stats_modificadores = {}

func get_stat(nombre: String) -> float:
	# Retorna base + modificadores y emite señal solo si el valor cacheado cambió desde la última consulta.
	var valor := float(stats_base.get(nombre, 0.0)) + float(stats_modificadores.get(nombre, 0.0))
	var previo = _stats_cache.get(nombre, null)
	if previo == null or not is_equal_approx(float(previo), valor):
		_stats_cache[nombre] = valor
		emit_signal("stat_cambiada", nombre, valor)
	return valor

func get_hp_max() -> float:
	# HP máximo = Vitalidad * 10.
	return get_stat("vitalidad") * 10.0

func get_mana_max() -> float:
	# Mana máximo = Inteligencia * 8 + Arcano * 4.
	return get_stat("inteligencia") * 8.0 + get_stat("arcano") * 4.0

func get_tier_hechizo() -> int:
	# Tier = floor(Arcano / 10), con mínimo 1.
	return max(1, int(floor(get_stat("arcano") / 10.0)))

func agregar_modificador(nombre: String, valor: float, fuente: String) -> void:
	# Registra modificadores de stats y gameplay por fuente para removerlos al limpiar una pasiva o item.
	if STATS.has(nombre):
		if not _modificadores_por_fuente.has(fuente):
			_modificadores_por_fuente[fuente] = []
		_modificadores_por_fuente[fuente].append({"stat": nombre, "valor": valor})
		_reconstruir_modificadores()
		return
	if not _modificadores_gameplay.has(fuente):
		_modificadores_gameplay[fuente] = {}
	_modificadores_gameplay[fuente][nombre] = valor

func remover_modificador(fuente: String) -> void:
	# Elimina todos los modificadores asociados a una fuente concreta y refresca los totales.
	var cambio_stats := _modificadores_por_fuente.erase(fuente)
	_modificadores_gameplay.erase(fuente)
	if cambio_stats:
		_reconstruir_modificadores()

func get_modificador(nombre: String) -> float:
	var total := 0.0
	for mods in _modificadores_gameplay.values():
		total += float((mods as Dictionary).get(nombre, 0.0))
	return total

func puede_equipar_armadura(tipo_armadura: String) -> bool:
	# Usa Resistencia como gate configurable para armadura ligera, media o pesada.
	if tipo_armadura == "ligera":
		return true
	return get_stat("resistencia") >= float(GATE_ARMADURA.get(tipo_armadura, INF))

func gastar_energia(cantidad: float) -> bool:
	# Costo real de energía = max(2, costo_base - Destreza * 0.3), salvo overrides temporales de gameplay.
	if cantidad <= 0.0:
		return true
	var costo_real : float= max(2.0, cantidad - get_stat("destreza") * 0.3)
	if get_modificador("esquiva_gratis_hasta") > 0.0 and is_equal_approx(cantidad, COSTO_ESQUIVAR):
		costo_real = 0.0
	if energia_actual < costo_real:
		_emitir_cambio_recurso("energia", energia_actual, energia_maxima)
		return false
	energia_actual = max(energia_actual - costo_real, 0.0)
	_emitir_cambio_recurso("energia", energia_actual, energia_maxima)
	return true

func gastar_mana(cantidad: float) -> bool:
	# El maná usa costo directo sin reducción base adicional.
	if cantidad <= 0.0:
		return true
	if mana_actual < cantidad:
		_emitir_cambio_recurso("mana", mana_actual, get_mana_max())
		return false
	mana_actual = max(mana_actual - cantidad, 0.0)
	_emitir_cambio_recurso("mana", mana_actual, get_mana_max())
	return true

func recibir_dano(cantidad: float, tipo: String) -> void:
	var reduccion := cantidad
	match tipo:
		"fisico":
			# Daño físico recibido = daño entrante * max(0, 1 - Resistencia * 0.015).
			reduccion = cantidad * max(0.0, 1.0 - get_stat("resistencia") * 0.015)
		"magico":
			# El daño mágico no se reduce por Resistencia base.
			reduccion = cantidad
		_:
			reduccion = cantidad

	if _escudo_temporal_actual > 0.0:
		var absorbido : float= min(_escudo_temporal_actual, reduccion)
		_escudo_temporal_actual -= absorbido
		reduccion -= absorbido
	hp_actual -= reduccion
	hp_actual = max(hp_actual, 0.0)
	_emitir_cambio_recurso("hp", hp_actual, get_hp_max())

	if hp_actual <= 0.0 and not _muerto:
		_muerto = true
		emit_signal("jugador_murio")

func atacar(objetivo: Node, arma: Arma) -> void:
	if objetivo == null or arma == null:
		return
	if not objetivo.has_method("recibir_dano"):
		return
	if not gastar_energia(COSTO_ATAQUE_BASE):
		return

	_ultimo_tipo_arma_usada = arma.tipo_arma
	var dano := arma.dano_base
	match arma.tipo_arma:
		"espada", "maza":
			# Espada/Maza = daño base * 1.0 + Fuerza * 1.0.
			dano = arma.dano_base * 1.0 + get_stat("fuerza") * 1.0
		"daga", "katana":
			# Daga/Katana = daño base * 0.5 + Destreza * 1.5.
			dano = arma.dano_base * 0.5 + get_stat("destreza") * 1.5
		"arco":
			# Arco = daño base * 0.6 + Destreza * 1.2.
			dano = arma.dano_base * 0.6 + get_stat("destreza") * 1.2
		"escudo":
			# Escudo = daño base * 0.7 + Fuerza * 0.7.
			dano = arma.dano_base * 0.7 + get_stat("fuerza") * 0.7

	if arma.tipo_arma == "espada":
		dano *= 1.0 + get_modificador("bonus_dano_espada_pct")
	var critico :float= randf() <= clamp(0.1 + get_stat("destreza") * 0.01, 0.1, 0.45)
	if critico:
		dano *= 1.5
		emit_signal("ataque_critico", objetivo, arma.tipo_arma, dano)
	objetivo.recibir_dano(dano, "fisico")

func esquivar() -> void:
	_ultimo_costo_esquiva = max(0.0, max(2.0, COSTO_ESQUIVAR - get_stat("destreza") * 0.3))
	if get_modificador("esquiva_gratis_hasta") >= float(Time.get_ticks_msec()):
		_ultimo_costo_esquiva = 0.0
	if not gastar_energia(COSTO_ESQUIVAR):
		return

	var direccion_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direccion_local := Vector3(direccion_input.x, 0.0, direccion_input.y)
	var direccion_mundo := (_cam_pivot.global_transform.basis * direccion_local).normalized()
	if direccion_mundo.length_squared() == 0.0:
		direccion_mundo = -global_transform.basis.z.normalized()

	# Esquivar aplica un impulso contrario al desplazamiento actual para salir de la trayectoria.
	velocity.x = -direccion_mundo.x * IMPULSO_ESQUIVAR
	velocity.z = -direccion_mundo.z * IMPULSO_ESQUIVAR
	emit_signal("esquive_realizado")

func lanzar_hechizo(hechizo: Variant) -> Dictionary:
	var dano_base := 0.0
	var costo_base := 0.0
	if hechizo is Dictionary:
		dano_base = float(hechizo.get("dano_base", 0.0))
		costo_base = float(hechizo.get("costo_mana", 0.0))
	else:
		dano_base = float(hechizo.get("dano_base"))
		costo_base = float(hechizo.get("costo_mana"))

	var tier_hechizo := get_tier_hechizo()
	# Daño final = daño base * (1 + 0.15 * tier de hechizo).
	var dano_final := dano_base * (1.0 + 0.15 * float(tier_hechizo))
	var penetracion := get_modificador("hechizos_penetracion_pct")
	# Costo de maná = costo base * max(0.1, 1 - 0.10 * tier de hechizo).
	var costo_mana :float= costo_base * max(0.1, 1.0 - 0.10 * float(tier_hechizo))

	if not gastar_mana(costo_mana):
		return {"lanzado": false, "dano": 0.0, "costo_mana": costo_mana, "tier_hechizo": tier_hechizo}

	return {"lanzado": true, "dano": dano_final, "costo_mana": costo_mana, "tier_hechizo": tier_hechizo, "penetracion_res_magica": penetracion}


func cargar_estado_guardado(estado: Dictionary) -> void:
	oro = int(estado.get("oro", 0))
	if pasiva_manager != null:
		pasiva_manager.cargar_pasivas_descubiertas(estado.get("pasivas_descubiertas", []))

func obtener_pasivas_descubiertas_descriptivas() -> Array[Dictionary]:
	if pasiva_manager == null:
		return []
	return pasiva_manager.obtener_pasivas_descubiertas()

func registrar_muerte_enemigo(mob_ref: Mob) -> void:
	emit_signal("enemigo_derrotado", mob_ref, _ultimo_tipo_arma_usada)

func registrar_sala(sala: Sala) -> void:
	if sala == null:
		return
	if not sala.mob_registrado.is_connected(_on_sala_mob_registrado):
		sala.mob_registrado.connect(_on_sala_mob_registrado)
	emit_signal("sala_iniciada", sala)

func reembolsar_energia(cantidad: float) -> void:
	if cantidad <= 0.0:
		return
	energia_actual = min(energia_actual + cantidad, energia_maxima)
	_emitir_cambio_recurso("energia", energia_actual, energia_maxima)

func get_ultimo_costo_esquiva() -> float:
	return _ultimo_costo_esquiva

func otorgar_escudo_temporal(cantidad: float) -> void:
	_escudo_temporal_actual += max(cantidad, 0.0)

func invocar_minion_temporal(origen: Vector3) -> void:
	var minion := Node3D.new()
	minion.name = "MinionTemporal"
	minion.position = origen + Vector3(0.0, 0.5, 0.0)
	var visual := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.25
	visual.mesh = esfera
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.85, 0.7, 1.0)
	visual.material_override = material
	minion.add_child(visual)
	get_tree().current_scene.add_child(minion)
	var tween := create_tween()
	tween.tween_property(minion, "position:y", minion.position.y + 0.8, 0.5)
	tween.tween_interval(2.0)
	tween.tween_callback(minion.queue_free)

func _on_sala_mob_registrado(mob: Mob) -> void:
	if nivel_manager != null:
		nivel_manager.registrar_mob(mob)

func toggle_primera_persona() -> void:
	# Alterna entre cámara tercera/primera persona y oculta la cápsula al mirar desde dentro.
	en_primera_persona = not en_primera_persona
	if en_primera_persona:
		_spring_arm.spring_length = 0.0
		_camera.position = Vector3(0.0, ALTURA_OJOS, 0.0)
		if _mesh_capsula != null:
			_mesh_capsula.visible = false
	else:
		_spring_arm.spring_length = DISTANCIA_TERCERA_PERSONA
		_camera.position = Vector3.ZERO
		if _mesh_capsula != null:
			_mesh_capsula.visible = true

func _toggle_mouse_mode() -> void:
	# Alterna captura del mouse para poder liberar/capturar la cámara en runtime.
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _asegurar_stats_completas() -> void:
	# Completa cualquier stat faltante para evitar claves ausentes al consultar o recalcular.
	for stat in STATS:
		if not stats_base.has(stat):
			stats_base[stat] = 0.0
		if not stats_modificadores.has(stat):
			stats_modificadores[stat] = 0.0

func _reconstruir_modificadores() -> void:
	# Recompone el diccionario plano de modificadores a partir del registro por fuente.
	stats_modificadores = {}
	for stat in STATS:
		stats_modificadores[stat] = 0.0
	for fuente in _modificadores_por_fuente.keys():
		for mod in _modificadores_por_fuente[fuente]:
			var stat: String = String(mod.get("stat", ""))
			stats_modificadores[stat] = float(stats_modificadores.get(stat, 0.0)) + float(mod.get("valor", 0.0))
	_recalcular_todas_las_stats()
	_sincronizar_recursos_desde_stats(false)

func _recalcular_todas_las_stats() -> void:
	# Fuerza la actualización/cacheo de todas las stats para disparar la señal cuando corresponda.
	for stat in STATS:
		get_stat(stat)

func _sincronizar_recursos_desde_stats(restaurar_completo: bool) -> void:
	var hp_max := get_hp_max()
	var mana_max := get_mana_max()
	energia_maxima = 100.0

	if restaurar_completo or hp_actual <= 0.0:
		hp_actual = hp_max
	else:
		hp_actual = clamp(hp_actual, 0.0, hp_max)

	if restaurar_completo or mana_actual <= 0.0:
		mana_actual = mana_max
	else:
		mana_actual = clamp(mana_actual, 0.0, mana_max)

	if restaurar_completo or energia_actual <= 0.0:
		energia_actual = energia_maxima
	else:
		energia_actual = clamp(energia_actual, 0.0, energia_maxima)

	_emitir_cambio_recurso("hp", hp_actual, hp_max)
	_emitir_cambio_recurso("energia", energia_actual, energia_maxima)
	_emitir_cambio_recurso("mana", mana_actual, mana_max)

func _regenerar_recursos(delta: float) -> void:
	var hp_previa := hp_actual
	var energia_previa := energia_actual
	var hp_max := get_hp_max()

	# Regeneración de HP = Vitalidad * 0.05 por segundo, limitada por hp_max.
	hp_actual = clamp(hp_actual + get_stat("vitalidad") * 0.05 * delta, 0.0, hp_max)
	# Regeneración de Energía = 8 puntos por segundo, limitada por 100.
	energia_actual = clamp(energia_actual + 8.0 * delta, 0.0, energia_maxima)

	if not is_equal_approx(hp_previa, hp_actual):
		_emitir_cambio_recurso("hp", hp_actual, hp_max)
	if not is_equal_approx(energia_previa, energia_actual):
		_emitir_cambio_recurso("energia", energia_actual, energia_maxima)

func _emitir_cambio_recurso(tipo: String, actual: float, maximo: float) -> void:
	emit_signal("recurso_cambiado", tipo, actual, maximo)

func _on_recurso_cambiado(tipo: String, actual: float, maximo: float) -> void:
	# La UI se refresca exclusivamente en respuesta a la signal recurso_cambiado.
	_actualizar_barra_recurso(tipo, actual, maximo)

func _construir_capsula_placeholder() -> void:
	# Crea la representación visual/colisión del jugador usando solo primitivas nativas de Godot.
	_collision_capsula = CollisionShape3D.new()
	var collision_shape := CapsuleShape3D.new()
	collision_shape.radius = 0.35
	collision_shape.height = 1.2
	_collision_capsula.shape = collision_shape
	add_child(_collision_capsula)

	_mesh_capsula = MeshInstance3D.new()
	_mesh_capsula.name = "CapsulaPlaceholder"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.2
	_mesh_capsula.mesh = capsule_mesh
	_mesh_capsula.position = Vector3(0.0, 0.9, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color_clase
	_mesh_capsula.material_override = material
	add_child(_mesh_capsula)

func _construir_rig_camara() -> void:
	# Monta un pivot top-level para que siga al jugador sin heredar su yaw/facing directamente.
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CamPivot"
	_cam_pivot.set_as_top_level(true)
	_cam_pivot.global_position = global_position
	add_child(_cam_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm3D"
	_spring_arm.spring_length = DISTANCIA_TERCERA_PERSONA
	_spring_arm.collision_mask = 1
	_spring_arm.margin = 0.2
	_spring_arm.position = Vector3(0.0, 1.0, 0.0)
	_cam_pivot.add_child(_spring_arm)
	_spring_arm.add_excluded_object(get_rid())

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_spring_arm.add_child(_camera)


func _construir_componentes_progresion() -> void:
	nivel_manager = NivelManager.new()
	nivel_manager.name = "NivelManager"
	add_child(nivel_manager)

	pasiva_manager = PasivaManager.new()
	pasiva_manager.name = "PasivaManager"
	add_child(pasiva_manager)

func _construir_componentes_inventario() -> void:
	inventario_component = InventarioComponent.new()
	inventario_component.name = "InventarioComponent"
	add_child(inventario_component)

	equipamiento_component = EquipamientoComponent.new()
	equipamiento_component.name = "EquipamientoComponent"
	add_child(equipamiento_component)

	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	add_child(inventory_ui)

func _construir_ui_recursos() -> void:
	_ui_recursos = CanvasLayer.new()
	_ui_recursos.name = "UIRecursos"
	add_child(_ui_recursos)

	var panel := Control.new()
	panel.name = "PanelRecursos"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(260.0, 84.0)
	_ui_recursos.add_child(panel)

	_crear_barra_recurso(panel, "hp", Color(0.75, 0.12, 0.12, 1.0), 0.0)
	_crear_barra_recurso(panel, "energia", Color(0.92, 0.78, 0.18, 1.0), 28.0)
	_crear_barra_recurso(panel, "mana", Color(0.18, 0.42, 0.95, 1.0), 56.0)

func _crear_barra_recurso(panel: Control, tipo: String, color: Color, y: float) -> void:
	var fondo := ColorRect.new()
	fondo.name = "%sFondo" % tipo.capitalize()
	fondo.color = Color(0.08, 0.08, 0.08, 0.9)
	fondo.position = Vector2(0.0, y)
	fondo.size = Vector2(220.0, 20.0)
	panel.add_child(fondo)

	var relleno := ColorRect.new()
	relleno.name = "%sRelleno" % tipo.capitalize()
	relleno.color = color
	relleno.position = Vector2(0.0, y)
	relleno.size = Vector2(220.0, 20.0)
	panel.add_child(relleno)
	_barras_recursos[tipo] = relleno

func _actualizar_barra_recurso(tipo: String, actual: float, maximo: float) -> void:
	var barra := _barras_recursos.get(tipo, null) as ColorRect
	if barra == null:
		return
	var proporcion := 0.0
	if maximo > 0.0:
		proporcion = clamp(actual / maximo, 0.0, 1.0)
	barra.size.x = 220.0 * proporcion
