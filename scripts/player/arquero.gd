class_name Arquero
extends Player

func _inicializar_stats() -> void:
	# Configura la distribución base del Arquero.
	color_clase = Color(0.2, 0.75, 0.3, 1.0)
	stats_base = {
		"fuerza": 9.0,
		"destreza": 16.0,
		"inteligencia": 7.0,
		"resistencia": 7.0,
		"vitalidad": 10.0,
		"arcano": 6.0,
	}
	stats_modificadores = {}
