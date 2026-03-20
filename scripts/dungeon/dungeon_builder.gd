class_name DungeonBuilder
extends Node3D

const TAMANO_PIEZA := 2.0
const ALTURA_LUZ := 2.5
const COLOR_FALLBACK := Color("#FF00FF")
const DIRECCIONES := ["norte", "sur", "este", "oeste"]
const ROTACIONES := {
	"norte": 0.0,
	"este": -PI * 0.5,
	"sur": PI,
	"oeste": PI * 0.5,
}
const OFFSETS_PUERTA := {
	"norte": Vector3(0.0, 0.0, -9.0),
	"sur": Vector3(0.0, 0.0, 9.0),
	"este": Vector3(9.0, 0.0, 0.0),
	"oeste": Vector3(-9.0, 0.0, 0.0),
}
const OFFSETS_ESQUINA := {
	"noroeste": Vector3(-9.0, 0.0, -9.0),
	"noreste": Vector3(9.0, 0.0, -9.0),
	"sureste": Vector3(9.0, 0.0, 9.0),
	"suroeste": Vector3(-9.0, 0.0, 9.0),
}
const ROTACIONES_ESQUINA := {
	"noroeste": 0.0,
	"noreste": -PI * 0.5,
	"sureste": PI,
	"suroeste": PI * 0.5,
}
const OFFSETS_PILAR := [
	Vector3(-6.0, 0.0, -6.0),
	Vector3(6.0, 0.0, -6.0),
	Vector3(6.0, 0.0, 6.0),
	Vector3(-6.0, 0.0, 6.0),
]

# Libera todas las piezas instanciadas previamente para que cada nuevo piso reconstruya la geometría desde cero sin duplicados.
func limpiar() -> void:
	for child in get_children():
		child.queue_free()

# Construye una sala completa colocando suelos, perímetro, puertas, esquinas, pilares y luz usando la posición mundial calculada por GeneradorPiso.
func construir_sala(sala: Sala, posicion_mundo: Vector3) -> void:
	var centro := posicion_mundo
	for x in range(10):
		for z in range(10):
			var suelo_pos := posicion_mundo + Vector3(-9.0 + x * TAMANO_PIEZA, 0.0, -9.0 + z * TAMANO_PIEZA)
			_instanciar_pieza("floor", suelo_pos)
	for direccion: String in DIRECCIONES:
		_construir_lado(sala, posicion_mundo, direccion)
	for esquina: String in OFFSETS_ESQUINA.keys():
		_instanciar_pieza(_grupo_esquina(), posicion_mundo + OFFSETS_ESQUINA[esquina], ROTACIONES_ESQUINA[esquina])
	if sala.tipo == "arena" or sala.tipo == "jefe":
		for offset: Vector3 in OFFSETS_PILAR:
			_instanciar_pieza(_grupo_pilar(), posicion_mundo + offset)
	_agregar_luz_sala(sala, centro)

# Coloca una pieza modular en la coordenada mundial indicada y rota sobre Y para alinear la orientación cardinal de la pared/puerta/esquina.
func _instanciar_pieza(nombre_grupo: String, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var grupo := AssetManager.obtener_grupo(nombre_grupo)
	if grupo.is_empty() and nombre_grupo == "corner":
		grupo = AssetManager.obtener_grupo("wall_corner")
	if grupo.is_empty() and nombre_grupo == "door":
		grupo = AssetManager.obtener_grupo("doorway")
	if grupo.is_empty() and nombre_grupo == "pillar":
		grupo = AssetManager.obtener_grupo("column")
	if grupo.is_empty():
		push_warning("DungeonBuilder: sin piezas para grupo '" + nombre_grupo + "'")
		return _crear_fallback(pos, rot_y)
	var escena := AssetManager.obtener(grupo.pick_random())
	if escena == null:
		return _crear_fallback(pos, rot_y)
	var instancia := escena.instantiate() as Node3D
	if instancia == null:
		return _crear_fallback(pos, rot_y)
		
	instancia.position = pos
	instancia.rotation.y = rot_y
	add_child(instancia)
	return instancia

# Recorre cada lado de la sala para colocar muro o puerta en las 10 posiciones modulares del perímetro según exista conexión lógica en esa dirección.
func _construir_lado(sala: Sala, posicion_mundo: Vector3, direccion: String) -> void:
	for indice in range(10):
		var es_centro_puerta := indice >= 4 and indice <= 5 and sala.conexiones.get(direccion) != null
		if es_centro_puerta:
			var puerta_offset := _offset_lado(direccion, indice)
			_instanciar_pieza(_grupo_puerta(), posicion_mundo + puerta_offset, ROTACIONES[direccion])
			continue
		if _es_esquina(direccion, indice):
			continue
		var pared_offset := _offset_lado(direccion, indice)
		_instanciar_pieza("wall", posicion_mundo + pared_offset, ROTACIONES[direccion])

# Calcula la coordenada modular de una pieza perimetral para un lado específico y así mantener el grid de 2u alineado con la sala de 20u.
func _offset_lado(direccion: String, indice: int) -> Vector3:
	var coordenada := -9.0 + indice * TAMANO_PIEZA
	match direccion:
		"norte":
			return Vector3(coordenada, 0.0, -9.0)
		"sur":
			return Vector3(coordenada, 0.0, 9.0)
		"este":
			return Vector3(9.0, 0.0, coordenada)
		_:
			return Vector3(-9.0, 0.0, coordenada)

# Omite los índices extremos porque ahí se colocan piezas de esquina dedicadas y no segmentos rectos de pared.
func _es_esquina(direccion: String, indice: int) -> bool:
	return indice == 0 or indice == 9

# Prefiere piezas etiquetadas como wall_corner y si no existen usa el fragmento corner para cubrir esquinas exteriores visibles.
func _grupo_esquina() -> String:
	return "wall_corner" if not AssetManager.obtener_grupo("wall_corner").is_empty() else "corner"

# Prefiere doorway cuando existe porque describe mejor el hueco jugable; si no, usa door para cualquier variante compatible.
func _grupo_puerta() -> String:
	return "doorway" if not AssetManager.obtener_grupo("doorway").is_empty() else "door"

# Prefiere pillar para decoración estructural y cae a column cuando la librería solo ofrezca esa denominación.
func _grupo_pilar() -> String:
	return "pillar" if not AssetManager.obtener_grupo("pillar").is_empty() else "column"

# Añade una OmniLight3D en el centro de la sala para reforzar la lectura visual del tipo de sala sin cambiar la lógica de combate.
func _agregar_luz_sala(sala: Sala, centro: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.position = centro + Vector3(0, ALTURA_LUZ, 0)
	match sala.tipo:
		"jefe":
			luz.light_energy = 1.8
			luz.light_color = Color(1.0, 0.3, 0.3)
		"tesoro":
			luz.light_energy = 1.4
			luz.light_color = Color(1.0, 0.9, 0.4)
		"arena":
			luz.light_energy = 1.5
			luz.light_color = Color(1.0, 0.7, 0.5)
		_:
			luz.light_energy = 1.0
			luz.light_color = Color(0.8, 0.7, 1.0)
	luz.omni_range = 14.0
	add_child(luz)

# Crea un cubo magenta exactamente en la coordenada faltante y con la rotación pedida para que cualquier asset ausente quede visible durante pruebas.
func _crear_fallback(pos: Vector3, rot_y: float) -> Node3D:
	var fallback := CSGBox3D.new()
	fallback.size = Vector3(2.0, 2.0, 2.0)
	fallback.position = pos + Vector3(0.0, 1.0, 0.0)
	fallback.rotation.y = rot_y
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_FALLBACK
	fallback.material = material
	add_child(fallback)
	return fallback
