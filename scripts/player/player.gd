class_name Player
extends CharacterBody3D

signal stat_cambiada(nombre: String, valor_nuevo: float)

const VELOCIDAD_BASE: float = 5.0
const VELOCIDAD_SPRINT: float = 8.5
const COSTO_SPRINT: float = 5.0
const GRAVEDAD: float = 9.8
const SENSIBILIDAD_X: float = 0.003
const SENSIBILIDAD_Y: float = 0.002
const ALTURA_OJOS: float = 1.6
const DISTANCIA_TERCERA_PERSONA: float = 5.0
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

@export var color_clase: Color = Color(1.0, 1.0, 1.0, 1.0)
## Color del material de la cápsula para identificar la clase.

@export var stats_base: Dictionary = {}
## Valores base de las 6 estadísticas del personaje.

@export var stats_modificadores: Dictionary = {}
## Suma acumulada de bonificaciones activas por stat.

var en_primera_persona: bool = false
var _modificadores_por_fuente: Dictionary = {}
var _stats_cache: Dictionary = {}
var _cam_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _mesh_capsula: MeshInstance3D
var _collision_capsula: CollisionShape3D

func _ready() -> void:
	# Inicializa estadísticas base, energía y el rig visual/cámara del jugador.
	_inicializar_stats()
	_asegurar_stats_completas()
	energia_actual = energia_maxima
	_construir_capsula_placeholder()
	_construir_rig_camara()
	_recalcular_todas_las_stats()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	# El pivot sigue la posición del jugador sin heredar su rotación para desacoplar cámara y facing.
	if _cam_pivot != null:
		_cam_pivot.global_position = global_position

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

func _physics_process(delta: float) -> void:
	# Lee input en plano XZ y lo transforma a espacio mundo usando la orientación horizontal del pivot.
	var direccion_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direccion_local := Vector3(direccion_input.x, 0.0, direccion_input.y)
	var dir_mundo := (_cam_pivot.global_transform.basis * direccion_local).normalized()
	var en_movimiento := dir_mundo.length_squared() > 0.0
	var velocidad_actual := VELOCIDAD_BASE

	# Sprint solo consume energía cuando realmente hay movimiento; si no alcanza, vuelve a velocidad base.
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
	var previo := _stats_cache.get(nombre, null)
	if previo == null or not is_equal_approx(float(previo), valor):
		_stats_cache[nombre] = valor
		emit_signal("stat_cambiada", nombre, valor)
	return valor

func agregar_modificador(nombre: String, valor: float, fuente: String) -> void:
	# Registra un modificador por fuente para poder removerlo de forma agrupada después.
	if not STATS.has(nombre):
		return
	if not _modificadores_por_fuente.has(fuente):
		_modificadores_por_fuente[fuente] = []
	_modificadores_por_fuente[fuente].append({"stat": nombre, "valor": valor})
	_reconstruir_modificadores()

func remover_modificador(fuente: String) -> void:
	# Elimina todos los modificadores asociados a una fuente concreta y refresca los totales.
	if _modificadores_por_fuente.erase(fuente):
		_reconstruir_modificadores()

func puede_equipar_armadura(tipo_armadura: String) -> bool:
	# Usa Resistencia como gate configurable para armadura ligera, media o pesada.
	if tipo_armadura == "ligera":
		return true
	return get_stat("resistencia") >= float(GATE_ARMADURA.get(tipo_armadura, INF))

func gastar_energia(costo: float) -> bool:
	# Consume energía y falla si no hay suficiente recurso disponible.
	if costo <= 0.0:
		return true
	if energia_actual < costo:
		energia_actual = max(energia_actual, 0.0)
		return false
	energia_actual = max(energia_actual - costo, 0.0)
	return true

func toggle_primera_persona() -> void:
	# Alterna entre cámara tercera/primera persona y oculta la cápsula al mirar desde dentro.
	en_primera_persona = not en_primera_persona
	if en_primera_persona:
		_spring_arm.spring_length = 0.0
		_camera.position = Vector3(0.0, ALTURA_OJOS, 0.0)
		_mesh_capsula.visible = false
	else:
		_spring_arm.spring_length = DISTANCIA_TERCERA_PERSONA
		_camera.position = Vector3.ZERO
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

func _recalcular_todas_las_stats() -> void:
	# Fuerza la actualización/cacheo de todas las stats para disparar la señal cuando corresponda.
	for stat in STATS:
		get_stat(stat)

func _construir_capsula_placeholder() -> void:
	# Crea la representación visual/colisión del jugador usando solo primitivas nativas de Godot.
	_collision_capsula = CollisionShape3D.new()
	var collision_shape := CapsuleShape3D.new()
	collision_shape.radius = 0.35
	collision_shape.height = 1.2
	_collision_capsula.shape = collision_shape
	add_child(_collision_capsula)

	_mesh_capsula = MeshInstance3D.new()
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
