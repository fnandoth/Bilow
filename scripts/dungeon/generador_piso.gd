extends Node3D

const SalaScript := preload("res://scripts/dungeon/sala.gd")
const MinimapScript := preload("res://scripts/dungeon/minimap_piso.gd")
const DungeonBuilderScript := preload("res://scripts/dungeon/dungeon_builder.gd")

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
var dungeon_builder: DungeonBuilder

# Inicializa el minimapa lógico y asegura un DungeonBuilder hijo que será quien coloque las piezas KayKit del piso procedural.
func _ready() -> void:
	if has_node("MinimapPiso"):
		minimap = $MinimapPiso
	else:
		minimap = MinimapScript.new()
		minimap.name = "MinimapPiso"
		add_child(minimap)
	if has_node("DungeonBuilder"):
		dungeon_builder = $DungeonBuilder
	else:
		dungeon_builder = DungeonBuilderScript.new()
		dungeon_builder.name = "DungeonBuilder"
		add_child(dungeon_builder)

# Genera la grilla lógica del piso y luego delega toda la construcción visual a DungeonBuilder manteniendo intacto el minimapa UI.
func generar_piso(numero_piso: int, seed: int = -1) -> Array[Sala]:
	numero_piso_actual = numero_piso
	semilla_actual = seed if seed != -1 else int(Time.get_unix_time_from_system())
	rng.seed = semilla_actual
	_limpiar_piso_actual()

	grid = []
	for x in MAX_SALAS:
		grid.append([])
		for _y in MAX_SALAS:
			grid[x].append(null)

	var sala_inicio := _crear_sala("inicio", Vector2i.ZERO)
	grid[0][0] = sala_inicio
	salas.append(sala_inicio)

	var cola: Array[Sala] = [sala_inicio]
	var celdas_ocupadas := {Vector2i.ZERO: true}
	while not cola.is_empty() and salas.size() < MAX_SALAS:
		var sala_actual: Sala = cola.pop_front()
		var direcciones := DIRECCIONES.keys()
		direcciones.shuffle()

		for direccion in direcciones:
			if salas.size() >= MAX_SALAS:
				break
			var offset: Vector2i = DIRECCIONES[direccion]
			var destino := sala_actual.posicion_grid + offset
			if not _esta_en_limites(destino) or celdas_ocupadas.has(destino):
				continue
			if rng.randf() > 0.70:
				continue
			var nueva_sala := _crear_sala("combate", destino)
			grid[destino.x][destino.y] = nueva_sala
			celdas_ocupadas[destino] = true
			_conectar_salas(sala_actual, nueva_sala, direccion)
			salas.append(nueva_sala)
			cola.push_back(nueva_sala)

		if salas.size() < MIN_SALAS and cola.is_empty():
			var sala_forzada := _forzar_expansion(celdas_ocupadas)
			if sala_forzada != null:
				cola.push_back(sala_forzada)

	while salas.size() < MIN_SALAS:
		_forzar_expansion(celdas_ocupadas)

	_asignar_tipos_especiales()
	_construir_dungeon_visual()
	minimap.construir(salas)
	return salas

# Crea la Sala lógica en la coordenada de grilla indicada, la posiciona usando TAMANO_CELDA=20 y la añade al árbol sin geometría CSG propia.
func _crear_sala(tipo: String, posicion: Vector2i) -> Sala:
	var sala: Sala = SalaScript.new()
	sala.configurar(tipo, posicion, numero_piso_actual, TAMANO_CELDA, mostrar_techo_pruebas)
	sala.position = Vector3(posicion.x * TAMANO_CELDA, 0.0, posicion.y * TAMANO_CELDA)
	add_child(sala)
	return sala

# Enlaza dos salas en la dirección cardinal correspondiente para que DungeonBuilder y la lógica de puertas conozcan las conexiones activas.
func _conectar_salas(origen: Sala, destino: Sala, direccion: String) -> void:
	origen.conexiones[direccion] = destino
	destino.conexiones[OPUESTAS[direccion]] = origen

# Fuerza una expansión conectada desde una sala existente hacia una celda libre para garantizar el mínimo de salas sin romper la BFS.
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

# Reasigna tipos especiales según distancia y tiradas aleatorias para que la iluminación y decoración visual reflejen la intención lúdica de cada sala.
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

# Invoca a DungeonBuilder para limpiar piezas previas y reconstruir cada sala en su coordenada mundial usando piezas KayKit modulares.
func _construir_dungeon_visual() -> void:
	dungeon_builder.limpiar()
	for sala in salas:
		sala.reconstruir_bloqueadores_puertas()
		var pos_mundo := Vector3(sala.posicion_grid.x * TAMANO_CELDA, 0.0, sala.posicion_grid.y * TAMANO_CELDA)
		dungeon_builder.construir_sala(sala, pos_mundo)

# Valida que la coordenada lógica siga dentro del grid cuadrado máximo para evitar indexación fuera de rango al generar el layout.
func _esta_en_limites(posicion: Vector2i) -> bool:
	return posicion.x >= 0 and posicion.y >= 0 and posicion.x < MAX_SALAS and posicion.y < MAX_SALAS

# Elimina salas previas y limpia el DungeonBuilder antes de cambiar de piso para que no queden piezas ni nodos lógicos persistentes.
func _limpiar_piso_actual() -> void:
	if dungeon_builder != null:
		dungeon_builder.limpiar()
	for sala in salas:
		if is_instance_valid(sala):
			sala.queue_free()
	salas.clear()
