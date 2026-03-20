class_name Guerrero
extends Player

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
