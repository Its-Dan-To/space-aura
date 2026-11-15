class_name Mision
## NOTA SOBRE EL IDIOMA: los textos están escritos en español y el autoload
## "Idioma" los traduce al inglés. Donde un texto se mete dentro de otro con
## %s hay que traducirlo a mano con TranslationServer.translate(), porque
## Godot solo traduce el texto completo de un Label o un Button.

## Datos compartidos de la misión. No hay que configurar nada:
## cualquier script puede usar Mision.nave_elegida, Mision.presupuesto, etc.
## Las variables "static" no se borran al cambiar de escena.

static var presupuesto := 75_000_000
static var nave_elegida := ""   # "gemini4", "apollo11" o "artemis2"
static var presupuesto_restante := 75_000_000   # lo que queda después de pagar la nave y las mejoras
static var mejoras := {}        # puntos extra comprados en el taller, por stat: {"masa": 40, ...}
static var resultado := {}      # resultado del ascenso (se muestra al final de la órbita)
static var fase_orbita := ""     # "llegada" cuando venimos del viaje de 3 días
static var viaje := {}           # resultado del viaje: datos, fallas resueltas
static var captura: Texture2D = null   # última imagen del ascenso, para pasar de escena sin pantalla negra

# Mejoras del taller (se pueden repetir; ningún stat pasa de 100)
const MEJORAS := [
	{"nombre": "MÍNIMA", "costo": 5_000_000, "puntos": 15},
	{"nombre": "MEDIA", "costo": 12_000_000, "puntos": 40},
	{"nombre": "MÁXIMA", "costo": 20_000_000, "puntos": 65},
]
const STAT_MAXIMO := 100

# Stats de 0 a 100. Los números son de juego, no datos oficiales:
# ajústenlos para balancear.
const NAVES := {
	"gemini4": {
		"nombre": "GEMINI IV",
		"cohete": "Titan II GLV",
		"anio": 1965,
		"tripulacion": 2,
		"duracion": "4 días",
		"destino": "Órbita terrestre",
		"costo": 18_000_000,
		"stats": {"propulsion": 35, "energia": 40, "masa": 25, "ciencia": 30, "comunicaciones": 45},
		"descripcion": "Nave pequeña y barata para misiones cortas en órbita.",
		"comentario": "La Gemini IV es chiquita pero confiable. En ella se hizo la primera caminata espacial de Estados Unidos. Barata, pero no llega lejos ni carga mucho.",
		"cohete_img": "res://assets/naves/gemini4_cohete.png",
		"capsula_img": "res://assets/naves/gemini4_capsula.png",
		"hangar_img": "res://assets/hangar/hangar_gemini4.png",
	},
	"apollo11": {
		"nombre": "APOLLO 11",
		"cohete": "Saturn V",
		"anio": 1969,
		"tripulacion": 3,
		"duracion": "8 días",
		"destino": "Superficie lunar",
		"costo": 52_000_000,
		"stats": {"propulsion": 95, "energia": 60, "masa": 90, "ciencia": 70, "comunicaciones": 60},
		"descripcion": "El cohete más poderoso de su época. Puede llegar a la Luna.",
		"comentario": "¡El Saturn V! Con él llegamos a la Luna por primera vez. Tiene muchísima potencia y carga, pero se come buena parte del presupuesto.",
		"cohete_img": "res://assets/naves/apollo11_cohete.png",
		"capsula_img": "res://assets/naves/apollo11_capsula.png",
		"hangar_img": "res://assets/hangar/hangar_apollo11.png",
	},
	"artemis2": {
		"nombre": "ARTEMIS II",
		"cohete": "SLS + Orion",
		"anio": 2026,
		"tripulacion": 4,
		"duracion": "10 días",
		"destino": "Sobrevuelo lunar",
		"costo": 68_000_000,
		"stats": {"propulsion": 90, "energia": 85, "masa": 80, "ciencia": 75, "comunicaciones": 90},
		"descripcion": "Tecnología moderna: paneles solares y comunicaciones de primera.",
		"comentario": "Artemis II lleva cuatro tripulantes alrededor de la Luna. Es la más moderna y la mejor en energía y comunicaciones... pero casi no te deja dinero para lo demás.",
		"cohete_img": "res://assets/naves/artemis2_cohete.png",
		"capsula_img": "res://assets/naves/artemis2_capsula.png",
		"hangar_img": "res://assets/hangar/hangar_artemis2.png",
	},
}

# Orden en el que aparecen en la pantalla de selección
const ORDEN := ["gemini4", "apollo11", "artemis2"]


# ---------- Stats con mejoras ----------

## Valor de un stat (0 a 100) contando las mejoras del taller de la nave elegida
static func valor(id: String, stat: String) -> int:
	var v: int = NAVES[id].stats[stat]
	if id == nave_elegida:
		v += int(mejoras.get(stat, 0))
	return min(v, STAT_MAXIMO)


static func reiniciar_mejoras() -> void:
	mejoras = {}


# ---------- Lo que hace cada stat en el ascenso ----------

## CAP. DE MASA: golpes que aguanta. Casco más fuerte = más resistencia...
static func vida_max(id: String) -> int:
	return 2 + int(round(valor(id, "masa") / 25.0))


## ...pero la nave pesa más y se mueve más lento a los lados.
static func maniobra(id: String) -> float:
	return 420.0 - valor(id, "masa") * 2.4


static func maniobra_texto(id: String) -> String:
	var m := maniobra(id)
	if m >= 300.0:
		return "ÁGIL"
	if m >= 215.0:
		return "MEDIA"
	return "LENTA"


## PROPULSIÓN: segundos para llegar a la exosfera (más propulsión = más rápido)
static func duracion_ascenso(id: String) -> float:
	return 75.0 - valor(id, "propulsion") * 0.25


## ENERGÍA: escudo protector al despegar. Cada 40 puntos absorbe un golpe.
static func escudo_inicial(id: String) -> int:
	return int(valor(id, "energia") / 40.0)


## COMUNICACIONES: segundos de aviso antes de que caiga un rayo...
static func aviso_rayo(id: String) -> float:
	return 0.6 + valor(id, "comunicaciones") * 0.006


## ...y con 50 o más, avisa de qué lado vienen aviones y satélites.
static func avisos_laterales(id: String) -> bool:
	return valor(id, "comunicaciones") >= 50


## CIENCIA: datos científicos (puntos) por cada capa que atraviesas
static func datos_por_capa(id: String) -> int:
	return valor(id, "ciencia") * 10


static func datos_nave() -> Dictionary:
	return NAVES.get(nave_elegida, {})


static func dinero(cantidad: int) -> String:
	# 75000000 -> "$75,000,000"
	var texto := str(cantidad)
	var resultado := ""
	var contador := 0
	for i in range(texto.length() - 1, -1, -1):
		resultado = texto[i] + resultado
		contador += 1
		if contador % 3 == 0 and i > 0:
			resultado = "," + resultado
	return "$" + resultado
