class_name Mob
extends CharacterBody3D

signal mob_murio(mob_ref: Mob)

const VISUALES := {
	"normal": {
		"color": Color("#5C0000"),
		"scale": Vector3(0.5, 0.9, 0.5),
	},
	"elite": {
		"color": Color("#B35A00"),
		"scale": Vector3(0.6, 1.1, 0.6),
	},
	"jefe": {
		"color": Color("#FF0000"),
		"scale": Vector3(0.9, 1.6, 0.9),
	},
}

@export var nombre: String = "Mob"
@export var vida_max: float = 50.0
@export var vida: float = 50.0
@export var armadura: float = 0.0
@export var resistencia_fisica: float = 0.0
@export var resistencia_magica: float = 0.0
@export var velocidad_movimiento: float = 3.0
@export var velocidad_ataque: float = 1.0
@export var tier_visual: String = "normal"

var _mesh: MeshInstance3D
var _collision: CollisionShape3D

func _ready() -> void:
	_configurar_stats_base()
	_construir_visual_placeholder()
	vida = vida_max

func _configurar_stats_base() -> void:
	pass

func recibir_dano(cantidad: float, tipo: String) -> void:
	var dano_final := cantidad
	match tipo:
		"fisico":
			# Daño físico final = daño entrante * max(0, 1 - resistencia_fisica) y luego menos armadura plana.
			dano_final = max(0.0, cantidad * max(0.0, 1.0 - resistencia_fisica) - armadura)
		"magico":
			# Daño mágico final = daño entrante * max(0, 1 - resistencia_magica).
			dano_final = cantidad * max(0.0, 1.0 - resistencia_magica)
		_:
			dano_final = cantidad

	vida = max(vida - dano_final, 0.0)
	if vida <= 0.0:
		emit_signal("mob_murio", self)
		queue_free()

func _construir_visual_placeholder() -> void:
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.2
	_collision.shape = shape
	add_child(_collision)

	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	_mesh.mesh = capsule
	_mesh.position = Vector3(0.0, 0.9, 0.0)

	var estilo: Dictionary = VISUALES.get(tier_visual, VISUALES["normal"])
	_mesh.scale = estilo["scale"]
	var material := StandardMaterial3D.new()
	material.albedo_color = estilo["color"]
	_mesh.material_override = material
	add_child(_mesh)
