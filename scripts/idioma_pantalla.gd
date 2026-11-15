extends Control
## =====================================================================
##  PANTALLA DE IDIOMA  (la primera que ve el jugador)
## ---------------------------------------------------------------------
##  Script de scenes/idioma.tscn. Esta escena es la principal del juego:
##  Proyecto > Configuración del Proyecto > Aplicación > Ejecutar >
##  Escena Principal = res://scenes/idioma.tscn
##
##  Pregunta el idioma una sola vez y después se va al menú principal.
##  La elección se guarda, así que las siguientes partidas entran directo.
##  Para que vuelva a preguntar, pon SIEMPRE_PREGUNTAR en true (o borra
##  el archivo user://idioma.json).
## =====================================================================

const ESCENA_SIGUIENTE := "res://scenes/menu_principal.tscn"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const RUTA_FONDO := "res://assets/espacio/fondos/"
## Si lo pones en true, pregunta el idioma cada vez que se abre el juego.
const SIEMPRE_PREGUNTAR := false

# Mismos colores que el menú principal
const COLOR_FONDO_BOTON := Color("1b1433dd")
const COLOR_BORDE := Color("8a6bbf")
const COLOR_HOVER := Color("3a2a66")
const COLOR_BORDE_HOVER := Color("f2c6e0")
const COLOR_TEXTO := Color("f4eefc")

var fuente: Font
var tiempo := 0.0
var estrellas: TextureRect


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font

	# Si ya eligió antes, nos saltamos esta pantalla
	if Idioma.ya_eligio() and not SIEMPRE_PREGUNTAR:
		call_deferred("_continuar")
		return

	_crear_fondo()
	_crear_menu()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	tiempo += delta
	if estrellas:
		estrellas.position.x = -round(fposmod(tiempo * 8.0, 128.0))


# ---------------- Fondo ----------------

func _crear_fondo() -> void:
	var negro := ColorRect.new()
	negro.color = Color("0b0f24")
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(negro)

	var archivo := RUTA_FONDO + "stars-mid-tile.png"
	if not ResourceLoader.exists(archivo):
		return
	estrellas = TextureRect.new()
	estrellas.texture = load(archivo)
	estrellas.stretch_mode = TextureRect.STRETCH_TILE
	estrellas.size = get_viewport_rect().size + Vector2(256, 0)
	estrellas.position = Vector2(-128, 0)
	estrellas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(estrellas)


# ---------------- Menú ----------------

func _crear_menu() -> void:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 18)
	add_child(caja)

	# En esta pantalla los textos NO se traducen: cada uno debe verse
	# siempre en su propio idioma para que el jugador los reconozca.
	caja.add_child(_titulo("ELIGE TU IDIOMA", 30, Color("f5c542")))
	caja.add_child(_titulo("CHOOSE YOUR LANGUAGE", 20, Color("8fd3ff")))

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 16)
	caja.add_child(hueco)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 24)
	caja.add_child(fila)
	fila.add_child(_boton("ESPAÑOL", "es"))
	fila.add_child(_boton("ENGLISH", "en"))


func _titulo(texto: String, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	return l


func _boton(texto: String, codigo: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(220, 64)
	b.add_theme_font_override("font", fuente)
	b.add_theme_font_size_override("font_size", 26)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, COLOR_TEXTO)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_FONDO_BOTON
	normal.border_color = COLOR_BORDE
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(10)
	var encima := normal.duplicate()
	encima.bg_color = COLOR_HOVER
	encima.border_color = COLOR_BORDE_HOVER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", encima)
	b.add_theme_stylebox_override("pressed", encima)
	b.add_theme_stylebox_override("focus", encima)

	b.pressed.connect(_elegir.bind(codigo))
	return b


func _elegir(codigo: String) -> void:
	Idioma.elegir(codigo)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(_continuar)


func _continuar() -> void:
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
	else:
		push_error("No existe " + ESCENA_SIGUIENTE)
