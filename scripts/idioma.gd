extends Node
## =====================================================================
##  IDIOMA DEL JUEGO  (AUTOLOAD)
## ---------------------------------------------------------------------
##  Registrado en: Proyecto > Configuración del Proyecto > Globals > Autoload
##      Ruta:    res://scripts/idioma.gd
##      Nombre: Idioma       (debe ir ARRIBA de los demás autoloads)
##
##  Cómo funciona:
##  Los textos del juego están escritos en español dentro de los scripts.
##  Este autoload carga data/traducciones.json (español -> inglés) y se lo
##  entrega al TranslationServer de Godot. Godot traduce solo el texto de
##  los Label, Button y RichTextLabel, así que casi ningún script cambia.
##
##  Desde cualquier parte del juego:
##     Idioma.actual            -> "es" o "en"
##     Idioma.elegir("en")      -> cambia el idioma en memoria
##     Idioma.alternar()        -> cambia de español a inglés y al revés
##     Idioma.es_ingles()       -> true si está en inglés
## =====================================================================

## Se emite cada vez que cambia el idioma.
signal cambiado(codigo: String)

const RUTA_TRADUCCIONES := "res://data/traducciones.json"
const IDIOMAS := ["es", "en"]
## Nombre de cada idioma tal como se le muestra al jugador.
const NOMBRES := {"es": "ESPAÑOL", "en": "ENGLISH"}

var actual: String = "es"
var _elegido: bool = false


func _ready() -> void:
	_cargar_traducciones()
	_aplicar("es")


# ---------------------------------------------------------------------
#  API PÚBLICA
# ---------------------------------------------------------------------

## true si el jugador ya eligió idioma durante la sesión actual.
func ya_eligio() -> bool:
	return _elegido


func es_ingles() -> bool:
	return actual == "en"


## Cambia el idioma en memoria (no se guarda en disco).
func elegir(codigo: String) -> void:
	_elegido = true
	_aplicar(codigo)


## Cambia de español a inglés y al revés.
func alternar() -> void:
	elegir("en" if actual == "es" else "es")


## Devuelve el texto que corresponda al idioma actual.
## Sirve para los datos que vienen de un JSON (como la bitácora), donde
## cada campo puede ser {"es": "...", "en": "..."} o un texto normal.
func texto(valor) -> String:
	if valor is Dictionary:
		if valor.has(actual):
			return str(valor[actual])
		if valor.has("es"):
			return str(valor["es"])
		for v in valor.values():
			return str(v)
		return ""
	return str(valor)


# ---------------------------------------------------------------------
#  INTERNO
# ---------------------------------------------------------------------

func _aplicar(codigo: String) -> void:
	if not IDIOMAS.has(codigo):
		codigo = "es"
	actual = codigo
	TranslationServer.set_locale(codigo)
	cambiado.emit(codigo)


func _cargar_traducciones() -> void:
	if not FileAccess.file_exists(RUTA_TRADUCCIONES):
		push_error("Idioma: no se encontró %s" % RUTA_TRADUCCIONES)
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_TRADUCCIONES))
	if not (datos is Dictionary):
		push_error("Idioma: el JSON de traducciones no es válido.")
		return

	# Traducción al español: cada texto se traduce a sí mismo.
	# Es necesaria para que Godot NO se vaya al idioma de respaldo (inglés)
	# cuando el juego está en español.
	var al_espanol := Translation.new()
	al_espanol.locale = "es"

	var al_ingles := Translation.new()
	al_ingles.locale = "en"

	var pares: Dictionary = datos.get("en", {})
	for clave in pares:
		var original := str(clave)
		al_espanol.add_message(original, original)
		al_ingles.add_message(original, str(pares[clave]))

	TranslationServer.add_translation(al_espanol)
	TranslationServer.add_translation(al_ingles)
