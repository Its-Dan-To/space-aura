extends Node
## =====================================================================
##  BITÁCORA ESPACIAL — Gestor de datos (AUTOLOAD)
## ---------------------------------------------------------------------
##  Regístralo en: Proyecto > Configuración del Proyecto > Globals > Autoload
##     Ruta:   res://scripts/autoload/bitacora.gd
##     Nombre: Bitacora
##
##  Uso desde CUALQUIER script del juego:
##     Bitacora.desbloquear_entrada("gemini_4")
##     if Bitacora.esta_desbloqueada("apollo_11"): ...
##
##  NOTA: no le pongas `class_name Bitacora` a este script, porque
##  chocaría con el nombre del autoload.
## =====================================================================

## Se emite cuando una entrada pasa de bloqueada a desbloqueada.
signal entrada_desbloqueada(id: String)
## Se emite cuando se (re)cargan los datos desde el JSON.
signal datos_cargados

## Los textos de cada entrada pueden venir en los dos idiomas:
##     "titulo": {"es": "Cráteres lunares", "en": "Lunar Craters"}
## También se acepta un texto normal, y entonces se usa igual en los dos.
## Quien decide cuál se muestra es el autoload "Idioma".

## Archivo con el contenido de las entradas (solo lectura, viaja con el juego).
const RUTA_DATOS := "res://data/bitacora_entradas.json"
## Archivo con el progreso del jugador (se escribe en la carpeta de usuario).
const RUTA_PROGRESO := "user://bitacora_progreso.json"

## Relación entre el id de nave de Mision ("apollo11") y su entrada en la bitácora.
const ENTRADA_POR_NAVE := {
	"apollo11": "apollo_11",
	"artemis2": "artemis_2",
	"gemini4": "gemini_4",
}

## Lista ordenada de entradas. Cada una es un Dictionary con:
## id, titulo, subtitulo_o_fecha, texto, ruta_imagen, desbloqueada
var _entradas: Array[Dictionary] = []
## Índice rápido: id -> posición en _entradas
var _indice_por_id: Dictionary = {}


func _ready() -> void:
	_cargar_datos()
	_cargar_progreso()
	var idioma = get_node_or_null("/root/Idioma")
	if idioma != null:
		idioma.cambiado.connect(_on_idioma_cambiado)


## Vuelve a leer los textos en el idioma nuevo, conservando el progreso.
func _on_idioma_cambiado(_codigo: String) -> void:
	var desbloqueadas := obtener_ids_desbloqueados()
	_cargar_datos()
	for id in desbloqueadas:
		if _indice_por_id.has(id):
			_entradas[_indice_por_id[id]]["desbloqueada"] = true
	datos_cargados.emit()


# ---------------------------------------------------------------------
#  API PÚBLICA
# ---------------------------------------------------------------------

## Desbloquea una entrada por su id. Devuelve true si se desbloqueó ahora
## (false si no existe o si ya estaba desbloqueada).
func desbloquear_entrada(id: String, notificar: bool = true) -> bool:
	if not _indice_por_id.has(id):
		push_warning("Bitacora: no existe ninguna entrada con id '%s'." % id)
		return false
	var entrada: Dictionary = _entradas[_indice_por_id[id]]
	if entrada["desbloqueada"]:
		return false
	entrada["desbloqueada"] = true  # Los Dictionary se pasan por referencia
	_guardar_progreso()
	if notificar:
		entrada_desbloqueada.emit(id)
	return true


## Desbloquea la entrada de la nave elegida, usando los ids de Mision
## ("apollo11", "artemis2", "gemini4").
func desbloquear_nave(id_nave: String) -> bool:
	if not ENTRADA_POR_NAVE.has(id_nave):
		push_warning("Bitacora: la nave '%s' no tiene entrada en la bitácora." % id_nave)
		return false
	return desbloquear_entrada(ENTRADA_POR_NAVE[id_nave])


## Devuelve true si la entrada existe y está desbloqueada.
func esta_desbloqueada(id: String) -> bool:
	return _indice_por_id.has(id) and _entradas[_indice_por_id[id]]["desbloqueada"]


## Devuelve una entrada (o un Dictionary vacío si no existe).
func obtener_entrada(id: String) -> Dictionary:
	if not _indice_por_id.has(id):
		return {}
	return _entradas[_indice_por_id[id]]


## Devuelve todas las entradas en orden. Trátalas como solo lectura;
## para cambiar el estado usa desbloquear_entrada().
func obtener_entradas() -> Array[Dictionary]:
	return _entradas


## Lista de ids desbloqueados, en el orden del JSON.
func obtener_ids_desbloqueados() -> Array[String]:
	var ids: Array[String] = []
	for entrada in _entradas:
		if entrada["desbloqueada"]:
			ids.append(entrada["id"])
	return ids


func contar_desbloqueadas() -> int:
	return obtener_ids_desbloqueados().size()


func contar_total() -> int:
	return _entradas.size()


## Borra el progreso guardado y vuelve al estado inicial del JSON.
func reiniciar_progreso() -> void:
	if FileAccess.file_exists(RUTA_PROGRESO):
		DirAccess.remove_absolute(RUTA_PROGRESO)
	_cargar_datos()


# ---------------------------------------------------------------------
#  CARGA DE DATOS
# ---------------------------------------------------------------------

## Elige el texto del idioma actual. Acepta {"es": ..., "en": ...} o un texto suelto.
func _idioma(valor) -> String:
	var idioma = get_node_or_null("/root/Idioma")
	if idioma != null:
		return idioma.texto(valor)
	if valor is Dictionary:
		return str(valor.get("es", ""))
	return str(valor)


func _cargar_datos() -> void:
	_entradas.clear()
	_indice_por_id.clear()

	if not FileAccess.file_exists(RUTA_DATOS):
		push_error("Bitacora: no se encontró %s" % RUTA_DATOS)
		datos_cargados.emit()
		return

	var contenido := FileAccess.get_file_as_string(RUTA_DATOS)
	var datos = JSON.parse_string(contenido)

	# Acepta { "entradas": [...] } o directamente [...]
	var lista: Array = []
	if datos is Dictionary and datos.get("entradas") is Array:
		lista = datos["entradas"]
	elif datos is Array:
		lista = datos
	else:
		push_error("Bitacora: el JSON de %s no es válido o tiene un formato inesperado." % RUTA_DATOS)

	for item in lista:
		if not (item is Dictionary) or not item.has("id"):
			push_warning("Bitacora: se ignoró una entrada sin 'id'.")
			continue
		var id := str(item["id"])
		if _indice_por_id.has(id):
			push_warning("Bitacora: id duplicado '%s', se ignora el segundo." % id)
			continue
		# Normalizamos campos para que la UI nunca encuentre claves faltantes.
		var entrada := {
			"id": id,
			"titulo": _idioma(item.get("titulo", id)),
			"subtitulo_o_fecha": _idioma(item.get("subtitulo_o_fecha", "")),
			"texto": _idioma(item.get("texto", "")),
			"ruta_imagen": str(item.get("ruta_imagen", "")),
			# Opcional: si la imagen es una hoja de cuadros (spritesheet) animada
			# {"columnas": 11, "filas": 8, "frames": 88, "fps": 12.5}
			"animacion": item.get("animacion") if item.get("animacion") is Dictionary else {},
			"desbloqueada": item.get("desbloqueada", false) == true,
		}
		_indice_por_id[id] = _entradas.size()
		_entradas.append(entrada)

	datos_cargados.emit()


# ---------------------------------------------------------------------
#  GUARDADO DE PROGRESO (user://bitacora_progreso.json)
# ---------------------------------------------------------------------

func _guardar_progreso() -> void:
	var archivo := FileAccess.open(RUTA_PROGRESO, FileAccess.WRITE)
	if archivo == null:
		push_error("Bitacora: no se pudo guardar el progreso (%s)." % error_string(FileAccess.get_open_error()))
		return
	archivo.store_string(JSON.stringify({"desbloqueadas": obtener_ids_desbloqueados()}, "\t"))
	archivo.close()


func _cargar_progreso() -> void:
	if not FileAccess.file_exists(RUTA_PROGRESO):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PROGRESO))
	if not (datos is Dictionary) or not (datos.get("desbloqueadas") is Array):
		push_warning("Bitacora: el archivo de progreso está dañado; se ignora.")
		return
	for id in datos["desbloqueadas"]:
		var id_str := str(id)
		if _indice_por_id.has(id_str):
			_entradas[_indice_por_id[id_str]]["desbloqueada"] = true
