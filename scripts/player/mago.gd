class_name Mago
extends Player

func _inicializar_stats() -> void:
	# Configura la distribución base del Mago.
	color_clase = Color(0.2, 0.35, 0.9, 1.0)
	stats_base = {
		"fuerza": 5.0,
		"destreza": 8.0,
		"inteligencia": 16.0,
		"resistencia": 5.0,
		"vitalidad": 7.0,
		"arcano": 14.0,
	}
	stats_modificadores = {}
