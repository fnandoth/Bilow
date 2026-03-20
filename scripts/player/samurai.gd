class_name Samurai
extends Player

func _inicializar_stats() -> void:
	# Configura la distribución base del Samurai.
	color_clase = Color(0.25, 0.25, 0.25, 1.0)
	stats_base = {
		"fuerza": 8.0,
		"destreza": 15.0,
		"inteligencia": 8.0,
		"resistencia": 6.0,
		"vitalidad": 9.0,
		"arcano": 12.0,
	}
	stats_modificadores = {}
