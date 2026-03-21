class_name Guerrero
extends Player

const RUTA_ANIMACIONES_KAYKIT := "res://addons/kaykit_animations/"
const NOMBRES_HUESO_MANO := ["armRight", "hand_right", "handRight", "Hand_R", "mixamorig:RightHand"]
const OSCILACION_IDLE := 0.02
const VELOCIDAD_IDLE := 2.5
const VELOCIDAD_WALK := 8.0
const GRADOS_WALK := 3.0
const GRADOS_ATAQUE := 45.0
const DURACION_ATAQUE := 0.15

var _skeleton : Skeleton3D = null
var _espada_node : Node3D = null
var _modelo_knight : Node3D = null
var _attachment_mano_derecha : BoneAttachment3D = null
var _anim_player : AnimationPlayer = null
var _usando_animaciones_kaykit: bool = false
var _tiempo_anim: float = 0.0
var _en_movimiento_visual: bool = false
var _animacion_actual: StringName = &"idle"
var _ataque_en_curso: bool = false
var _escala_base_modelo := Vector3.ONE

func _ready() -> void:
	super._ready()
	_configurar_modelo_guerrero()
	_configurar_animaciones()
	_actualizar_animacion_base()

func _process(delta: float) -> void:
	super._process(delta)
	_actualizar_animacion_movimiento()
	if not _usando_animaciones_kaykit:
		_animar_fallback(delta)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_actualizar_animacion_movimiento()

func atacar(objetivo: Node, arma: Arma) -> void:
	var energia_previa := energia_actual
	super.atacar(objetivo, arma)
	if objetivo == null or arma == null:
		return
	if energia_actual < energia_previa:
		_reproducir_animacion(&"attack")

func esquivar() -> void:
	var energia_previa := energia_actual
	super.esquivar()
	if energia_actual < energia_previa:
		_reproducir_animacion(&"dodge")

func _inicializar_stats() -> void:
	# Configura la distribución base del Guerrero.
	color_clase = Color(0.85, 0.15, 0.15, 1.0)
	stats_base = {
		"fuerza": 15.0,
		"destreza": 8.0,
		"inteligencia": 5.0,
		"resistencia": 14.0,
		"vitalidad": 13.0,
		"arcano": 5.0,
	}
	stats_modificadores = {}

func _configurar_modelo_guerrero() -> void:
	var capsula := get_node_or_null("CapsulaPlaceholder") as MeshInstance3D
	if capsula != null:
		capsula.queue_free()
		_mesh_capsula = null

	var claves_knight := AssetManager.obtener_grupo_chars("knight")
	if claves_knight.is_empty():
		push_error("Guerrero: no se encontro modelo knight en el catalogo de personajes. Ruta revisada: " + AssetManager.RUTA_CHARS)
		_crear_capsula_fallback(Color(0.7, 0.1, 0.1))
		return

	var escena_knight := AssetManager.obtener_char(claves_knight[0])
	if escena_knight == null:
		push_error("Guerrero: no se pudo cargar la escena knight descubierta en runtime -> " + claves_knight[0] + " desde " + AssetManager.RUTA_CHARS)
		_crear_capsula_fallback(Color(0.7, 0.1, 0.1))
		return

	_modelo_knight = escena_knight.instantiate() as Node3D
	if _modelo_knight == null:
		push_error("Guerrero: la escena knight descubierta no instancio un Node3D valido -> " + claves_knight[0])
		_crear_capsula_fallback(Color(0.7, 0.1, 0.1))
		return

	_modelo_knight.name = "ModeloKnight"
	add_child(_modelo_knight)
	_modelo_knight.scale = Vector3.ONE
	_modelo_knight.position = Vector3(0.0, -1.0, 0.0)
	_escala_base_modelo = _modelo_knight.scale

	_skeleton = _buscar_skeleton(_modelo_knight)
	if _skeleton == null:
		push_error("Guerrero: no se encontro Skeleton3D dentro del modelo knight.")
		return

	_adjuntar_espada()
	_excluir_modelo_de_spring_arm()

func _buscar_skeleton(nodo: Node) -> Skeleton3D:
	if nodo is Skeleton3D:
		return nodo as Skeleton3D
	for hijo in nodo.get_children():
		var resultado := _buscar_skeleton(hijo)
		if resultado != null:
			return resultado
	return null

func _adjuntar_espada() -> void:
	if _skeleton == null:
		return

	_attachment_mano_derecha = BoneAttachment3D.new()
	_attachment_mano_derecha.name = "AttachmentManoDerecha"

	var indice_hueso := -1
	for nombre_hueso in NOMBRES_HUESO_MANO:
		# Se prueban varios nombres porque KayKit cambia el naming del hueso de mano derecha entre versiones/importadores.
		indice_hueso = _skeleton.find_bone(nombre_hueso)
		if indice_hueso != -1:
			_attachment_mano_derecha.bone_name = nombre_hueso
			break

	if indice_hueso == -1:
		push_error("Guerrero: no se encontro hueso de mano derecha. Nombres intentados: " + str(NOMBRES_HUESO_MANO) + ". Revisar el Skeleton3D en el Inspector para ver los nombres reales.")
		return

	_skeleton.add_child(_attachment_mano_derecha)

	var claves_sword := AssetManager.obtener_grupo_chars("sword")
	if claves_sword.is_empty():
		push_warning("Guerrero: no se encontro modelo de espada en " + AssetManager.RUTA_CHARS + ". La mano derecha queda vacia.")
		return

	var escena_sword := AssetManager.obtener_char(claves_sword[0])
	if escena_sword == null:
		push_error("Guerrero: no se pudo cargar la espada descubierta en runtime -> " + claves_sword[0] + " desde " + AssetManager.RUTA_CHARS)
		return

	_espada_node = escena_sword.instantiate() as Node3D
	if _espada_node == null:
		push_error("Guerrero: la escena de espada descubierta no instancio un Node3D valido -> " + claves_sword[0])
		return

	_espada_node.name = "EspadaEquipada"
	_attachment_mano_derecha.add_child(_espada_node)
	_espada_node.position = Vector3(0.0, 0.1, 0.0)
	_espada_node.rotation_degrees = Vector3(0.0, 0.0, -90.0)

func _configurar_animaciones() -> void:
	_anim_player = _buscar_animation_player()
	_usando_animaciones_kaykit = _intentar_configurar_animaciones_kaykit()
	if not _usando_animaciones_kaykit:
		if _anim_player == null:
			_anim_player = AnimationPlayer.new()
			_anim_player.name = "AnimationPlayer"
			add_child(_anim_player)
		_crear_animaciones_fallback()


func _buscar_animation_player() -> AnimationPlayer:
	if _modelo_knight == null:
		return null
	return _modelo_knight.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _intentar_configurar_animaciones_kaykit() -> bool:
	var dir := DirAccess.open(RUTA_ANIMACIONES_KAYKIT)
	if dir == null:
		return false

	if _anim_player == null:
		_anim_player = _buscar_animation_player()
	if _anim_player == null:
		return false

	var archivos := _buscar_recursos_animacion(RUTA_ANIMACIONES_KAYKIT)
	for archivo in archivos:
		var recurso := load(archivo)
		if recurso is AnimationLibrary:
			_anim_player.add_animation_library("kaykit", recurso)
			return _anim_player.has_animation("kaykit/idle") or _anim_player.has_animation("kaykit/walk") or _anim_player.has_animation("kaykit/attack")
	return _anim_player.get_animation_list().size() > 0

func _buscar_recursos_animacion(ruta_base: String) -> Array[String]:
	var encontrados : Array[String] = []
	var dir := DirAccess.open(ruta_base)
	if dir == null:
		return encontrados
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		var ruta_actual := ruta_base.path_join(archivo)
		if dir.current_is_dir():
			if not archivo.begins_with("."):
				encontrados.append_array(_buscar_recursos_animacion(ruta_actual))
		elif archivo.to_lower().ends_with(".tres") or archivo.to_lower().ends_with(".res") or archivo.to_lower().ends_with(".gltf"):
			encontrados.append(ruta_actual)
		archivo = dir.get_next()
	dir.list_dir_end()
	return encontrados

func _crear_animaciones_fallback() -> void:
	if _anim_player == null:
		return
	if not _anim_player.has_animation("idle"):
		_anim_player.add_animation("idle", _crear_animacion_idle())
	if not _anim_player.has_animation("walk"):
		_anim_player.add_animation("walk", _crear_animacion_walk())
	if not _anim_player.has_animation("attack"):
		_anim_player.add_animation("attack", _crear_animacion_attack())

func _crear_animacion_idle() -> Animation:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	return anim

func _crear_animacion_walk() -> Animation:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	return anim

func _crear_animacion_attack() -> Animation:
	var anim := Animation.new()
	anim.length = DURACION_ATAQUE * 2.0
	anim.loop_mode = Animation.LOOP_NONE
	return anim

func _animar_fallback(delta: float) -> void:
	if _modelo_knight == null:
		return

	_tiempo_anim += delta
	if _animacion_actual == &"attack":
		return
	if _animacion_actual == &"walk":
		_modelo_knight.rotation.y = sin(_tiempo_anim * VELOCIDAD_WALK) * deg_to_rad(GRADOS_WALK)
		_modelo_knight.scale = _escala_base_modelo
	else:
		_modelo_knight.rotation.y = 0.0
		var factor := 1.0 - OSCILACION_IDLE * (0.5 + 0.5 * sin(_tiempo_anim * VELOCIDAD_IDLE))
		_modelo_knight.scale = Vector3(_escala_base_modelo.x, _escala_base_modelo.y * factor, _escala_base_modelo.z)

func _actualizar_animacion_movimiento() -> void:
	_en_movimiento_visual = Vector2(velocity.x, velocity.z).length_squared() > 0.01 and is_on_floor()
	if _ataque_en_curso:
		return
	_actualizar_animacion_base()

func _actualizar_animacion_base() -> void:
	if _en_movimiento_visual:
		_reproducir_animacion(&"walk")
	else:
		_reproducir_animacion(&"idle")

func _reproducir_animacion(nombre: StringName) -> void:
	if nombre == &"dodge":
		if _anim_player != null and (_anim_player.has_animation("dodge") or _anim_player.has_animation("kaykit/dodge")):
			nombre = _resolver_nombre_animacion("dodge")
		else:
			nombre = &"idle"
	elif nombre == &"attack":
		nombre = _resolver_nombre_animacion("attack")
	elif nombre == &"walk":
		nombre = _resolver_nombre_animacion("walk")
	else:
		nombre = _resolver_nombre_animacion("idle")

	if nombre == _animacion_actual and nombre != &"attack":
		return

	_animacion_actual = nombre
	if String(nombre).contains("attack"):
		_lanzar_ataque_visual()
		return

	if _anim_player != null and _anim_player.has_animation(String(nombre)):
		_anim_player.play(String(nombre))

func _resolver_nombre_animacion(base: String) -> StringName:
	if _anim_player != null:
		if _anim_player.has_animation(base):
			return StringName(base)
		var kaykit := "kaykit/" + base
		if _anim_player.has_animation(kaykit):
			return StringName(kaykit)
	return StringName(base)

func _lanzar_ataque_visual() -> void:
	_ataque_en_curso = true
	if _anim_player != null and _anim_player.has_animation(String(_animacion_actual)) and _usando_animaciones_kaykit:
		_anim_player.play(String(_animacion_actual))
		await _anim_player.animation_finished
		_ataque_en_curso = false
		_actualizar_animacion_base()
		return

	if _attachment_mano_derecha == null:
		_ataque_en_curso = false
		_actualizar_animacion_base()
		return

	var tween := create_tween()
	tween.tween_property(_attachment_mano_derecha, "rotation_degrees:z", GRADOS_ATAQUE, DURACION_ATAQUE)
	tween.tween_property(_attachment_mano_derecha, "rotation_degrees:z", -GRADOS_ATAQUE, DURACION_ATAQUE)
	await tween.finished
	if _attachment_mano_derecha != null:
		_attachment_mano_derecha.rotation_degrees.z = 0.0
	_ataque_en_curso = false
	_actualizar_animacion_base()

func _excluir_modelo_de_spring_arm() -> void:
	if _spring_arm == null or _modelo_knight == null:
		return
	_spring_arm.add_excluded_object(_modelo_knight.get_rid())
	for hijo in _modelo_knight.find_children("*", "MeshInstance3D", true, false):
		if hijo is MeshInstance3D:
			_spring_arm.add_excluded_object((hijo as MeshInstance3D).get_rid())

func _crear_capsula_fallback(color: Color) -> void:
	if _mesh_capsula != null and is_instance_valid(_mesh_capsula):
		return
	_mesh_capsula = MeshInstance3D.new()
	_mesh_capsula.name = "CapsulaPlaceholder"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.2
	_mesh_capsula.mesh = capsule_mesh
	_mesh_capsula.position = Vector3(0.0, 0.9, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	_mesh_capsula.material_override = material
	add_child(_mesh_capsula)
