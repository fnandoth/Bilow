class_name Pasiva
extends Resource

var id: String = ""
var nombre: String = ""
var descripcion: String = ""
var categoria: String = "fisico"
var tipo: String = "pasiva_normal"
var es_primo: bool = false

var _signal_refs: Array[Dictionary] = []
var _estado: Dictionary = {}

func aplicar(player: Player) -> void:
	pass

func remover(player: Player) -> void:
	for conexion in _signal_refs:
		var emisor := conexion.get("emisor") as Object
		var callable_ref: Callable = conexion.get("callable", Callable())
		if emisor != null and emisor.has_signal(StringName(conexion.get("signal", ""))) and emisor.is_connected(StringName(conexion.get("signal", "")), callable_ref):
			emisor.disconnect(StringName(conexion.get("signal", "")), callable_ref)
	_signal_refs.clear()
	_estado.clear()

func clonar() -> Pasiva:
	var copia := get_script().new() as Pasiva
	copia.id = id
	copia.nombre = nombre
	copia.descripcion = descripcion
	copia.categoria = categoria
	copia.tipo = tipo
	copia.es_primo = es_primo
	return copia

func registrar_signal(emisor: Object, signal_name: StringName, callable_ref: Callable) -> void:
	if emisor == null or not emisor.has_signal(signal_name):
		return
	if not emisor.is_connected(signal_name, callable_ref):
		emisor.connect(signal_name, callable_ref)
	_signal_refs.append({"emisor": emisor, "signal": String(signal_name), "callable": callable_ref})
