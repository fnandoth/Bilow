class_name Sala
extends Node3D

signal sala_completada(sala: Sala)
signal mob_registrado(mob: Mob)

const ALTURA_HUECO_PUERTA := 2.0
const ANCHO_HUECO_PUERTA := 2.0

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

# Configura la identidad lógica de la sala, su coordenada de grilla y el tamaño base usado por spawns y bloqueadores al entrar al piso.
func configurar(tipo_sala: String, grid_pos: Vector2i, piso_actual: int, tamano_base: float, usar_techo: bool) -> void:
	tipo = tipo_sala
	posicion_grid = grid_pos
	numero_piso = piso_actual
	tamano_celda = tamano_base
	mostrar_techo = usar_techo
	tamano_sala = _calcular_tamano_por_tipo()
	name = "Sala_%s_%s" % [grid_pos.x, grid_pos.y]

# Marca la sala como visitada y dispara el flujo de combate/spawn cuando el jugador entra físicamente en esa coordenada del layout.
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

# Completa la sala para desbloquear puertas, resolver recompensas de tesoro y sincronizar su estado con el minimapa lógico.
func completar_sala() -> void:
	if completada:
		return
	completada = true
	desbloquear_puertas()
	if tipo == "tesoro":
		_spawnear_cofres()
	emit_signal("sala_completada", self)
	_actualizar_minimapa()

# Registra cada mob activo en esta coordenada para saber cuándo una oleada terminó y la sala puede considerarse despejada.
func registrar_mob(mob: Mob) -> void:
	if mob == null:
		return
	_mobs_activos.append(mob)
	if not mob.mob_murio.is_connected(_on_mob_muerto):
		mob.mob_murio.connect(_on_mob_muerto)
	emit_signal("mob_registrado", mob)

# Activa todos los bloqueadores invisibles de puerta ya colocados en los lados conectados para impedir salir durante combates.
func bloquear_puertas() -> void:
	for blocker: StaticBody3D in _door_blockers.values():
		blocker.process_mode = Node.PROCESS_MODE_INHERIT
		for child in blocker.get_children():
			if child is CollisionShape3D:
				child.disabled = false

# Desactiva los bloqueadores invisibles de puerta para permitir el tránsito libre entre salas una vez completado el encuentro.
func desbloquear_puertas() -> void:
	for blocker: StaticBody3D in _door_blockers.values():
		for child in blocker.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		blocker.process_mode = Node.PROCESS_MODE_DISABLED

# Atiende la muerte de un mob en esta sala para abrir puertas o lanzar la siguiente oleada cuando el contador de enemigos llega a cero.
func _on_mob_muerto(mob_ref: Mob) -> void:
	_mobs_activos.erase(mob_ref)
	if not _mobs_activos.is_empty():
		return
	if tipo == "arena" and _oleadas_restantes > 0 and _spawn_manager != null:
		_spawn_manager.call("spawnear_siguiente_oleada", self)
		return
	if tipo == "combate" or tipo == "arena" or tipo == "jefe":
		completar_sala()

# Localiza el minimapa global y refresca el color/estado de esta coordenada lógica sin tocar la representación 3D.
func _actualizar_minimapa() -> void:
	_minimap = get_node_or_null("/root/GeneradorPiso/MinimapPiso")
	if _minimap != null:
		_minimap.call("actualizar_sala", self)

# Genera cofres de recompensa y una posible trampa en posiciones internas de la sala usando el mismo tamano_sala que el piso visual.
func _spawnear_cofres() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash([numero_piso, posicion_grid.x, posicion_grid.y, "tesoro"])
	for indice in random.randi_range(1, 3):
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

# Calcula el tamaño lógico de uso interno de la sala para que mobs, cofres y puertas respeten la escala base de 20 unidades por celda.
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

# Rehace los bloqueadores invisibles de las puertas en las coordenadas cardinales de la sala para mantener la lógica de cierre sin CSG visibles.
func reconstruir_bloqueadores_puertas() -> void:
	_destruir_bloqueadores_previos()
	for direccion: String in conexiones.keys():
		if conexiones[direccion] != null:
			_crear_bloqueador_puerta(direccion)
	desbloquear_puertas()

# Elimina bloqueadores de puertas antiguos de esta sala para no duplicar colisiones cuando se regenera el piso completo.
func _destruir_bloqueadores_previos() -> void:
	for child in get_children():
		if child is StaticBody3D and child.name.begins_with("Bloqueo_"):
			child.queue_free()
	_door_blockers.clear()

# Crea un StaticBody3D en la coordenada del hueco cardinal para cerrar temporalmente esa salida cuando la sala está bloqueada.
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

# Calcula la coordenada Z del lado norte o sur para alinear bloqueadores de puerta con el borde jugable de la sala.
func _z_pared(direccion: String) -> float:
	return -tamano_sala.y * 0.5 if direccion == "norte" else tamano_sala.y * 0.5

# Calcula la coordenada X del lado este u oeste para alinear bloqueadores de puerta con el borde jugable de la sala.
func _x_pared(direccion: String) -> float:
	return tamano_sala.x * 0.5 if direccion == "este" else -tamano_sala.x * 0.5

# Prepara el contador de oleadas para que las arenas sepan cuántos grupos faltan por resolver en esta coordenada.
func preparar_oleadas(cantidad: int) -> void:
	_oleadas_restantes = max(cantidad, 0)

# Consume una oleada completada para acercar la arena al desbloqueo final cuando SpawnManager lanza otro grupo.
func consumir_oleada() -> void:
	_oleadas_restantes = max(_oleadas_restantes - 1, 0)
