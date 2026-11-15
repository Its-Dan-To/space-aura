class_name LunaEstado
## Estado compartido de la base lunar. Las variables "static" se conservan
## al cambiar de escena, así que el mapa recuerda qué minijuegos ya se hicieron.

static var escena_mapa := ""        # escena del mapa de la Luna (se llena sola)
static var resultados := {}         # id -> {"exito": bool, "puntos": int}
static var posiciones := {}         # player_id -> Vector2, para regresar donde estaban
static var estacion_activa := ""

# Controles (los mismos que usa player.gd; el juego usa los del jugador 1)
const CONTROLES := {
	"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D, "p1_interact": KEY_E,
	"p2_up": KEY_UP, "p2_down": KEY_DOWN, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_interact": KEY_SHIFT,
	"luna_reintentar": KEY_R,
}


## Crea las acciones del teclado si todavía no existen.
static func asegurar_controles() -> void:
	for accion in CONTROLES:
		if InputMap.has_action(accion):
			continue
		InputMap.add_action(accion)
		var ev := InputEventKey.new()
		ev.physical_keycode = CONTROLES[accion]
		InputMap.action_add_event(accion, ev)


## Guarda el resultado de un minijuego. Se queda con el mejor intento.
static func registrar(id: String, exito: bool, puntos: int) -> void:
	var anterior: Dictionary = resultados.get(id, {})
	if anterior.is_empty() or (exito and not anterior.exito) or (exito == anterior.exito and puntos > anterior.puntos):
		resultados[id] = {"exito": exito, "puntos": puntos}


static func completado(id: String) -> bool:
	return resultados.has(id) and bool(resultados[id].exito)


static func puntos_totales() -> int:
	var total := 0
	for id in resultados:
		total += int(resultados[id].puntos)
	return total


static func reiniciar() -> void:
	resultados = {}
	posiciones = {}
	estacion_activa = ""


## Nave elegida al inicio del juego ("gemini4", "apollo11" o "artemis2").
## Si se prueba la escena sola (F6) y no hay nave elegida, usa el Apollo 11.
static func nave_id() -> String:
	var id := String(Mision.nave_elegida)
	if id == "" or not Mision.NAVES.has(id):
		return "apollo11"
	return id


static func nave_nombre() -> String:
	return String(Mision.NAVES[nave_id()].nombre)


## Busca la escena del jugador 1 o 2 en las rutas más comunes del proyecto.
static func escena_jugador(pid: int) -> PackedScene:
	var rutas := {
		1: ["res://scenes/luna/astronauta_luna.tscn", "res://scenes/Player.tscn", "res://Player.tscn", "res://scenes/player.tscn", "res://player/player.tscn"],
		2: ["res://scenes/Player_2.tscn", "res://scenes/Player2.tscn", "res://Player_2.tscn", "res://Player2.tscn"],
	}
	for ruta in rutas[pid]:
		if ResourceLoader.exists(ruta):
			return load(ruta)
	return null
