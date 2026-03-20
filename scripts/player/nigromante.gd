class_name Nigromante
extends Player

func _inicializar_stats() -> void:
	# Configura la distribución base del Nigromante.
	color_clase = Color(0.45, 0.15, 0.6, 1.0)
	stats_base = {
		"fuerza": 4.0,
		"destreza": 7.0,
		"inteligencia": 15.0,
		"resistencia": 5.0,
		"vitalidad": 7.0,
		"arcano": 15.0,
	}
	stats_modificadores = {}
