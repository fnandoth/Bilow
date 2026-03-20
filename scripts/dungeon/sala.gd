class_name Sala
extends Node3D

signal sala_completada(sala: Sala)
signal mob_registrado(mob: Mob)

const ALTURA_PARED := 3.0
const GROSOR_PARED := 0.6
const ALTURA_HUECO_PUERTA := 2.0
const ANCHO_HUECO_PUERTA := 2.0
const COLOR_SUELO := Color("#555555")
const COLOR_PARED := Color("#DDDDDD")
const COLOR_TECHO := Color(1.0, 1.0, 1.0, 0.15)

@export var tipo: String = "combate"
@export var posicion_grid: Vector2i = Vector2i.ZERO
@export var conexiones: Dictionary = {
	"norte": null,
	"sur": null,
	"este": null,
	"oeste": null,
}
@export var mobs_spawneados: bool = false
@export var completada: bool = false
@export var numero_piso: int = 1
@export var visitada: bool = false

var tamano_celda: float = 20.0
var tamano_sala: Vector2 = Vector2(14.0, 14.0)
var mostrar_techo: bool = true

var _door_blockers: Dictionary = {}
var _mobs_activos: Array[Mob] = []
var _spawn_manager: Node = null
var _minimap: Node = null
var _oleadas_restantes: int = 0

func configurar(tipo_sala: String, grid_pos: Vector2i, piso_actual: int, tamano_base: float, usar_techo: bool) -> void:
	tipo = tipo_sala
	posicion_grid = grid_pos
	numero_piso = piso_actual
	tamano_celda = tamano_base
	mostrar_techo = usar_techo
	tamano_sala = _calcular_tamano_por_tipo()
	name = "Sala_%s_%s" % [grid_pos.x, grid_pos.y]

func construir_geometria() -> void:
	_destruir_geometria_previa()
	_crear_suelo()
	_crear_paredes_con_huecos()
	if mostrar_techo:
		_crear_techo()

func entrar_sala() -> void:
	visitada = true
	var jugadores := get_tree().get_nodes_in_group("player")
	if not jugadores.is_empty() and jugadores[0] is Player:
		(jugadores[0] as Player).registrar_sala(self)
	_actualizar_minimapa()
	if (tipo == "combate" or tipo == "arena" or tipo == "jefe") and not mobs_spawneados:
		_spawn_manager = get_node_or_null("/root/SpawnManager")
		if _spawn_manager != null:
			_spawn_manager.set("numero_piso_actual", numero_piso)
			_spawn_manager.call("spawnear_mobs", self)
		mobs_spawneados = true
		if tipo == "combate" or tipo == "arena":
			bloquear_puertas()

func completar_sala() -> void:
	if completada:
		return
	completada = true
	desbloquear_puertas()
	if tipo == "tesoro":
		_spawnear_cofres()
	emit_signal("sala_completada", self)
	_actualizar_minimapa()

func registrar_mob(mob: Mob) -> void:
	if mob == null:
		return
	_mobs_activos.append(mob)
	if not mob.mob_murio.is_connected(_on_mob_muerto):
		mob.mob_murio.connect(_on_mob_muerto)
	emit_signal("mob_registrado", mob)

func bloquear_puertas() -> void:
	for blocker: StaticBody3D in _door_blockers.values():
		blocker.process_mode = Node.PROCESS_MODE_INHERIT
		for child in blocker.get_children():
			if child is CollisionShape3D:
				child.disabled = false

func desbloquear_puertas() -> void:
	for blocker: StaticBody3D in _door_blockers.values():
		for child in blocker.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		blocker.process_mode = Node.PROCESS_MODE_DISABLED

func _on_mob_muerto(mob_ref: Mob) -> void:
	_mobs_activos.erase(mob_ref)
	if not _mobs_activos.is_empty():
		return
	if tipo == "arena" and _oleadas_restantes > 0 and _spawn_manager != null:
		_spawn_manager.call("spawnear_siguiente_oleada", self)
		return
	if tipo == "combate" or tipo == "arena" or tipo == "jefe":
		completar_sala()

func _actualizar_minimapa() -> void:
	_minimap = get_node_or_null("/root/GeneradorPiso/MinimapPiso")
	if _minimap != null:
		_minimap.call("actualizar_sala", self)

func _spawnear_cofres() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash([numero_piso, posicion_grid.x, posicion_grid.y, "tesoro"])
	var cantidad := random.randi_range(1, 3)
	for indice in cantidad:
		var cofre := CSGBox3D.new()
		cofre.name = "Cofre_%s" % indice
		cofre.size = Vector3(1.2, 1.0, 0.9)
		cofre.position = Vector3(
			random.randf_range(-tamano_sala.x * 0.25, tamano_sala.x * 0.25),
			0.5,
			random.randf_range(-tamano_sala.y * 0.25, tamano_sala.y * 0.25)
		)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#C68E17")
		cofre.material = material
		add_child(cofre)

	if random.randf() <= 0.35:
		var trampa := CSGBox3D.new()
		trampa.name = "PlacaPresion"
		trampa.size = Vector3(1.5, 0.1, 1.5)
		trampa.position = Vector3(0.0, 0.05, 0.0)
		var material_trampa := StandardMaterial3D.new()
		material_trampa.albedo_color = Color("#884444")
		trampa.material = material_trampa
		add_child(trampa)

func _calcular_tamano_por_tipo() -> Vector2:
	match tipo:
		"arena":
			return Vector2(tamano_celda - 2.0, tamano_celda - 2.0)
		"jefe":
			return Vector2(tamano_celda - 1.0, tamano_celda - 1.0)
		"pasillo":
			return Vector2(tamano_celda - 4.0, tamano_celda - 10.0)
		_:
			return Vector2(tamano_celda - 6.0, tamano_celda - 6.0)

func _destruir_geometria_previa() -> void:
	for child in get_children():
		if child is CSGBox3D or child is StaticBody3D:
			child.queue_free()
	_door_blockers.clear()

func _crear_suelo() -> void:
	var suelo := CSGBox3D.new()
	suelo.name = "Suelo"
	suelo.size = Vector3(tamano_sala.x, 0.4, tamano_sala.y)
	suelo.position = Vector3(0.0, -0.2, 0.0)
	suelo.material = _crear_material(COLOR_SUELO)
	add_child(suelo)

func _crear_techo() -> void:
	var techo := CSGBox3D.new()
	techo.name = "Techo"
	techo.size = Vector3(tamano_sala.x, 0.2, tamano_sala.y)
	techo.position = Vector3(0.0, ALTURA_PARED + 0.1, 0.0)
	techo.material = _crear_material(COLOR_TECHO, true)
	add_child(techo)

func _crear_paredes_con_huecos() -> void:
	_crear_pared_lado("norte")
	_crear_pared_lado("sur")
	_crear_pared_lado("este")
	_crear_pared_lado("oeste")

func _crear_pared_lado(direccion: String) -> void:
	var tiene_puerta := conexiones.get(direccion) != null
	if not tiene_puerta:
		_crear_segmento_pared(direccion, 0, _longitud_pared(direccion), ALTURA_PARED, false)
		return

	var longitud := _longitud_pared(direccion)
	var mitad_hueco := ANCHO_HUECO_PUERTA * 0.5
	var segmento_lateral := max((longitud - ANCHO_HUECO_PUERTA) * 0.5, 0.5)
	_crear_segmento_pared(direccion, -(mitad_hueco + segmento_lateral * 0.5), segmento_lateral, ALTURA_PARED, false)
	_crear_segmento_pared(direccion, mitad_hueco + segmento_lateral * 0.5, segmento_lateral, ALTURA_PARED, false)
	_crear_segmento_pared(direccion, 0, ANCHO_HUECO_PUERTA, ALTURA_PARED - ALTURA_HUECO_PUERTA, true)
	_crear_bloqueador_puerta(direccion)

func _crear_segmento_pared(direccion: String, offset: float, longitud: float, altura: float, sobre_puerta: bool) -> void:
	if longitud <= 0.0 or altura <= 0.0:
		return
	var pared := CSGBox3D.new()
	pared.name = "Pared_%s_%s" % [direccion, abs(offset)]
	var base_y := altura * 0.5
	if sobre_puerta:
		base_y = ALTURA_HUECO_PUERTA + altura * 0.5
	match direccion:
		"norte", "sur":
			pared.size = Vector3(longitud, altura, GROSOR_PARED)
			pared.position = Vector3(offset, base_y, _z_pared(direccion))
		"este", "oeste":
			pared.size = Vector3(GROSOR_PARED, altura, longitud)
			pared.position = Vector3(_x_pared(direccion), base_y, offset)
	pared.material = _crear_material(COLOR_PARED)
	add_child(pared)

func _crear_bloqueador_puerta(direccion: String) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Bloqueo_%s" % direccion
	var colision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	if direccion == "norte" or direccion == "sur":
		shape.size = Vector3(ANCHO_HUECO_PUERTA, ALTURA_HUECO_PUERTA, 1.0)
		cuerpo.position = Vector3(0.0, ALTURA_HUECO_PUERTA * 0.5, _z_pared(direccion))
	else:
		shape.size = Vector3(1.0, ALTURA_HUECO_PUERTA, ANCHO_HUECO_PUERTA)
		cuerpo.position = Vector3(_x_pared(direccion), ALTURA_HUECO_PUERTA * 0.5, 0.0)
	colision.shape = shape
	cuerpo.add_child(colision)
	add_child(cuerpo)
	_door_blockers[direccion] = cuerpo
	desbloquear_puertas()

func _longitud_pared(direccion: String) -> float:
	return tamano_sala.x if direccion == "norte" or direccion == "sur" else tamano_sala.y

func _z_pared(direccion: String) -> float:
	return -tamano_sala.y * 0.5 if direccion == "norte" else tamano_sala.y * 0.5

func _x_pared(direccion: String) -> float:
	return tamano_sala.x * 0.5 if direccion == "este" else -tamano_sala.x * 0.5

func _crear_material(color: Color, transparente: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if transparente:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func preparar_oleadas(cantidad: int) -> void:
	_oleadas_restantes = max(cantidad, 0)

func consumir_oleada() -> void:
	_oleadas_restantes = max(_oleadas_restantes - 1, 0)
