class_name Paladin
extends Player

func _inicializar_stats() -> void:
	# Configura la distribución base del Paladin.
	color_clase = Color(0.9, 0.75, 0.2, 1.0)
	stats_base = {
		"fuerza": 14.0,
		"destreza": 6.0,
		"inteligencia": 8.0,
		"resistencia": 12.0,
		"vitalidad": 11.0,
		"arcano": 13.0,
	}
	stats_modificadores = {}
