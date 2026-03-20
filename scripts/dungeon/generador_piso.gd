extends Node3D

const SalaScript := preload("res://scripts/dungeon/sala.gd")
const MinimapScript := preload("res://scripts/dungeon/minimap_piso.gd")

const MIN_SALAS := 8
const MAX_SALAS := 14
const TAMANO_CELDA := 20
const DIRECCIONES := {
	"norte": Vector2i(0, -1),
	"sur": Vector2i(0, 1),
	"este": Vector2i(1, 0),
	"oeste": Vector2i(-1, 0),
}
const OPUESTAS := {
	"norte": "sur",
	"sur": "norte",
	"este": "oeste",
	"oeste": "este",
}

@export var mostrar_techo_pruebas: bool = true

var numero_piso_actual: int = 1
var semilla_actual: int = 0
var rng := RandomNumberGenerator.new()
var salas: Array[Sala] = []
var grid: Array = []
var minimap: MinimapPiso

func _ready() -> void:
	if has_node("MinimapPiso"):
		minimap = $MinimapPiso
	else:
		minimap = MinimapScript.new()
		minimap.name = "MinimapPiso"
		add_child(minimap)

func generar_piso(numero_piso: int, seed: int = -1) -> Array[Sala]:
	numero_piso_actual = numero_piso
	semilla_actual = seed if seed != -1 else int(Time.get_unix_time_from_system())
	rng.seed = semilla_actual
	_limpiar_piso_actual()

	# Paso 1: crear el grid cuadrado del tamaño maximo permitido para alojar salas.
	grid = []
	for x in MAX_SALAS:
		grid.append([])
		for _y in MAX_SALAS:
			grid[x].append(null)

	# Paso 2: colocar la sala inicial en el origen logico del piso.
	var sala_inicio := _crear_sala("inicio", Vector2i.ZERO)
	grid[0][0] = sala_inicio
	salas.append(sala_inicio)

	# Paso 3: expandir el layout con una BFS para mantener conectividad desde el inicio.
	var cola: Array[Sala] = [sala_inicio]
	var celdas_ocupadas := {Vector2i.ZERO: true}
	while not cola.is_empty() and salas.size() < MAX_SALAS:
		var sala_actual: Sala = cola.pop_front()
		var direcciones := DIRECCIONES.keys()
		direcciones.shuffle()

		# Para cada sala expandible, probamos vecinos libres con 70% de probabilidad.
		for direccion in direcciones:
			if salas.size() >= MAX_SALAS:
				break
			var offset: Vector2i = DIRECCIONES[direccion]
			var destino := sala_actual.posicion_grid + offset

			# Saltamos posiciones fuera del grid o ya ocupadas por otra sala.
			if not _esta_en_limites(destino) or celdas_ocupadas.has(destino):
				continue

			# La probabilidad del 70% gobierna si realmente nace una sala adyacente.
			if rng.randf() > 0.70:
				continue

			# Creamos la sala vecina, la enlazamos y la añadimos a la BFS.
			var nueva_sala := _crear_sala("combate", destino)
			grid[destino.x][destino.y] = nueva_sala
			celdas_ocupadas[destino] = true
			_conectar_salas(sala_actual, nueva_sala, direccion)
			salas.append(nueva_sala)
			cola.push_back(nueva_sala)

		# Si aun no llegamos al minimo, forzamos una expansion conectada desde la sala actual.
		if salas.size() < MIN_SALAS and cola.is_empty():
			var sala_forzada := _forzar_expansion(celdas_ocupadas)
			if sala_forzada != null:
				cola.push_back(sala_forzada)

	# Garantizamos el minimo de salas incluso si la aleatoriedad fue muy conservadora.
	while salas.size() < MIN_SALAS:
		_forzar_expansion(celdas_ocupadas)

	_asignar_tipos_especiales()
	_instanciar_geometria()
	minimap.construir(salas)
	return salas

func _crear_sala(tipo: String, posicion: Vector2i) -> Sala:
	var sala: Sala = SalaScript.new()
	sala.configurar(tipo, posicion, numero_piso_actual, TAMANO_CELDA, mostrar_techo_pruebas)
	sala.position = Vector3(posicion.x * TAMANO_CELDA, 0.0, posicion.y * TAMANO_CELDA)
	add_child(sala)
	return sala

func _conectar_salas(origen: Sala, destino: Sala, direccion: String) -> void:
	origen.conexiones[direccion] = destino
	destino.conexiones[OPUESTAS[direccion]] = origen

func _forzar_expansion(celdas_ocupadas: Dictionary) -> Sala:
	var candidatas := salas.duplicate()
	candidatas.shuffle()
	for sala_base: Sala in candidatas:
		var direcciones := DIRECCIONES.keys()
		direcciones.shuffle()
		for direccion in direcciones:
			var destino : Vector2i = sala_base.posicion_grid + DIRECCIONES[direccion]
			if not _esta_en_limites(destino) or celdas_ocupadas.has(destino):
				continue
			var nueva_sala := _crear_sala("combate", destino)
			grid[destino.x][destino.y] = nueva_sala
			celdas_ocupadas[destino] = true
			_conectar_salas(sala_base, nueva_sala, direccion)
			salas.append(nueva_sala)
			return nueva_sala
	return null

func _asignar_tipos_especiales() -> void:
	var sala_mas_lejana := salas[0]
	var distancia_maxima := -1
	for sala in salas:
		var distancia : int = abs(sala.posicion_grid.x) + abs(sala.posicion_grid.y)
		if distancia > distancia_maxima:
			distancia_maxima = distancia
			sala_mas_lejana = sala

	sala_mas_lejana.tipo = "jefe" if numero_piso_actual % 15 == 0 else "combate"
	sala_mas_lejana.tamano_sala = sala_mas_lejana._calcular_tamano_por_tipo()

	for sala in salas:
		if sala == salas[0] or sala == sala_mas_lejana:
			continue
		var tirada := rng.randf()
		if tirada <= 0.15:
			sala.tipo = "tesoro"
		elif tirada <= 0.25:
			sala.tipo = "arena"
		elif tirada <= 0.40:
			sala.tipo = "pasillo"
		else:
			sala.tipo = "combate"
		sala.tamano_sala = sala._calcular_tamano_por_tipo()

func _instanciar_geometria() -> void:
	for sala in salas:
		sala.construir_geometria()

func _esta_en_limites(posicion: Vector2i) -> bool:
	return posicion.x >= 0 and posicion.y >= 0 and posicion.x < MAX_SALAS and posicion.y < MAX_SALAS

func _limpiar_piso_actual() -> void:
	for sala in salas:
		if is_instance_valid(sala):
			sala.queue_free()
	salas.clear()
