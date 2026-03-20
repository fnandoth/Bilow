class_name MinimapPiso
extends CanvasLayer

const TAMANO_CELDA_UI := 10.0
const COLORES := {
	"combate": Color("#D64545"),
	"tesoro": Color("#E3D04F"),
	"arena": Color("#F08A24"),
	"inicio": Color("#4CAF50"),
	"jefe": Color("#8E44AD"),
	"pasillo": Color("#7F8C8D"),
}

var _contenedor: Control
var _tiles: Dictionary = {}

func _ready() -> void:
	layer = 20
	_contenedor = Control.new()
	_contenedor.name = "ContenedorMinimap"
	_contenedor.position = Vector2(16, 16)
	add_child(_contenedor)

func construir(lista_salas: Array[Sala]) -> void:
	for child in _contenedor.get_children():
		child.queue_free()
	_tiles.clear()

	for sala in lista_salas:
		var tile := ColorRect.new()
		tile.custom_minimum_size = Vector2.ONE * TAMANO_CELDA_UI
		tile.size = Vector2.ONE * TAMANO_CELDA_UI
		tile.position = Vector2(sala.posicion_grid.x, sala.posicion_grid.y) * TAMANO_CELDA_UI
		tile.color = COLORES.get(sala.tipo, Color.WHITE)
		tile.visible = sala.visitada
		tile.tooltip_text = "%s (%s, %s)" % [sala.tipo, sala.posicion_grid.x, sala.posicion_grid.y]
		_contenedor.add_child(tile)
		_tiles[sala.posicion_grid] = tile

func actualizar_sala(sala: Sala) -> void:
	var tile: ColorRect = _tiles.get(sala.posicion_grid)
	if tile == null:
		return
	tile.visible = sala.visitada
	tile.color = COLORES.get(sala.tipo, Color.WHITE)
