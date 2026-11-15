extends Control
## Pantalla negra con texto que se escribe letra por letra.
## Clic, Espacio o Enter: termina la línea o pasa a la siguiente.
## Esc: salta toda la intro.

# ---------- Cosas que puedes cambiar fácilmente ----------
const LINEAS := [
	"CENTRO DE CONTROL DE MISIONES.\n06:00 HORAS.",
	"Las agencias espaciales del mundo buscan a un nuevo director de misión.",
	"Alguien capaz de equilibrar presupuesto, masa, energía y ciencia...",
	"...y de tomar decisiones que podrían cambiar la historia.",
	"Ese alguien eres tú.",
	"Tu astronauta, Albertsahur, te espera en la sala de diseño.",
]
const ESCENA_SIGUIENTE := "res://scenes/seleccion_nave.tscn"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const LETRAS_POR_SEGUNDO := 35.0
const COLOR_TEXTO := Color("f4eefc")
# ---------------------------------------------------------

var texto: Label
var flecha: Label
var linea_actual := -1
var letras := 0.0
var saliendo := false
var tiempo := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var k := get_viewport_rect().size.y / 360.0   # escala según el tamaño de la pantalla

	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fuente: Font = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else null

	texto = Label.new()
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", int(14 * k))
	texto.add_theme_color_override("font_color", COLOR_TEXTO)
	texto.add_theme_constant_override("line_spacing", int(6 * k))
	if fuente:
		texto.add_theme_font_override("font", fuente)
	add_child(texto)
	texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texto.offset_left = 60 * k
	texto.offset_right = -60 * k

	flecha = Label.new()
	flecha.text = "- clic para continuar -"
	flecha.add_theme_font_size_override("font_size", int(8 * k))
	if fuente:
		flecha.add_theme_font_override("font", fuente)
	flecha.add_theme_color_override("font_color", Color("f2c6e0"))
	flecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(flecha)
	flecha.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	flecha.offset_top = -50 * k
	flecha.offset_bottom = -30 * k

	var saltar := Label.new()
	saltar.text = "ESC: saltar"
	saltar.add_theme_font_size_override("font_size", int(8 * k))
	saltar.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	if fuente:
		saltar.add_theme_font_override("font", fuente)
	saltar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(saltar)
	saltar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	saltar.offset_top = -20 * k
	saltar.offset_bottom = -6 * k
	saltar.offset_right = -10 * k

	_siguiente_linea()


func _process(delta: float) -> void:
	tiempo += delta
	if linea_actual < LINEAS.size() and not saliendo:
		letras = min(letras + LETRAS_POR_SEGUNDO * delta, texto.get_total_character_count())
		texto.visible_characters = int(letras)
	# El aviso parpadea cuando la línea ya terminó
	flecha.visible = _linea_terminada() and fmod(tiempo, 0.8) < 0.5 and not saliendo


func _input(event: InputEvent) -> void:
	if saliendo:
		return
	if event.is_action_pressed("ui_cancel"):
		_terminar()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _linea_terminada():
			_siguiente_linea()
		else:
			letras = texto.get_total_character_count()   # muestra la línea completa


func _linea_terminada() -> bool:
	return texto.visible_characters >= texto.get_total_character_count()


func _siguiente_linea() -> void:
	linea_actual += 1
	if linea_actual >= LINEAS.size():
		_terminar()
		return
	texto.text = LINEAS[linea_actual]
	letras = 0.0
	texto.visible_characters = 0


func _terminar() -> void:
	saliendo = true
	var t := create_tween()
	t.tween_property(texto, "modulate:a", 0.0, 0.8)
	t.tween_interval(0.3)
	t.tween_callback(_cambiar_escena)


func _cambiar_escena() -> void:
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
	else:
		push_warning("No existe " + ESCENA_SIGUIENTE)
