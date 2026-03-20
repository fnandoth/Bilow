extends Node

const RUTA_GLTF := "res://addons/kaykit_dungeon_remastered/Assets/gltf/"
const EXTENSIONES_VALIDAS := [".gltf", ".glb", ".gltf.glb"]

var _catalogo : Dictionary = {}

# Escanea la carpeta de piezas GLTF/GLB embebidas en KayKit para registrar cada PackedScene por clave y evitar rutas hardcodeadas.
func _ready() -> void:
	_catalogo.clear()
	var dir := DirAccess.open(RUTA_GLTF)
	if dir == null:
		push_error("AssetManager: no se encontro la carpeta gltf en " + RUTA_GLTF)
		return
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if not dir.current_is_dir() and _es_archivo_3d(archivo):
			var clave := _normalizar_clave(archivo)
			var recurso := load(RUTA_GLTF + archivo)
			if recurso is PackedScene:
				_catalogo[clave] = recurso
		archivo = dir.get_next()
	dir.list_dir_end()
	print("AssetManager: ", _catalogo.size(), " assets cargados.")

# Devuelve la PackedScene registrada bajo la clave indicada para instanciar la pieza exacta que corresponda a ese nombre lógico.
func obtener(nombre: String) -> PackedScene:
	var clave := nombre.to_lower()
	if not _catalogo.has(clave):
		push_warning("AssetManager: asset no encontrado -> " + clave)
		return null
	return _catalogo[clave]

# Devuelve todas las claves cuyo nombre contiene el fragmento solicitado para elegir variantes visuales del mismo grupo sin hardcodear archivos.
func obtener_grupo(fragmento: String) -> Array[String]:
	var resultado : Array[String] = []
	var patron := fragmento.to_lower()
	for clave: String in _catalogo.keys():
		if clave.contains(patron):
			resultado.append(clave)
	resultado.sort()
	return resultado

# Normaliza el nombre del archivo a clave de catálogo eliminando extensiones múltiples para que AssetManager responda con nombres estables.
func _normalizar_clave(archivo: String) -> String:
	var clave := archivo.to_lower()
	for extension in EXTENSIONES_VALIDAS:
		if clave.ends_with(extension):
			clave = clave.trim_suffix(extension)
	return clave

# Detecta si el archivo encontrado en la carpeta gltf es una escena modular importable de KayKit y no una textura auxiliar.
func _es_archivo_3d(archivo: String) -> bool:
	for extension in EXTENSIONES_VALIDAS:
		if archivo.to_lower().ends_with(extension):
			return true
	return false
