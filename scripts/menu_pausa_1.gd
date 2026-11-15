extends CanvasLayer
## MENÚ DE PAUSA (en todas las escenas)
## Un botoncito (II) arriba a la izquierda. Al darle clic se pausa el juego y aparece:
##   CONTINUAR | BITÁCORA | IDIOMA | REINICIAR ESCENA | MENÚ PRINCIPAL
## La BITÁCORA abre bitacora_ui.tscn. Necesita el Autoload "Bitacora"
## (scripts/bitacora.gd) registrado ANTES que este en la lista de Autoloads.
## Se instala UNA sola vez como Autoload (ver instrucciones) y aparece solo
## en todas las escenas, menos en el menú principal.

# ---------- Cosas que puedes cambiar fácilmente ----------
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const ESCENA_BITACORA := "res://scenes/bitacora_ui.tscn"
const POSICION := Vector2(6, 6)        # dónde va el botón (pantalla de 648 de alto)
# Cuánto dura en pantalla el aviso de "nueva entrada en la bitácora".
# Pon 0.0 para que se quede hasta que el jugador abra el menú de pausa.
const SEGUNDOS_AVISO := 6.0
const TAMANO := Vector2(30, 26)        # tamaño del botón
# ---------------------------------------------------------

const C_FONDO := Color(0.04, 0.06, 0.15, 0.92)
const C_BORDE := Color("6a76a8")
const C_HOVER := Color("3a2a66")
const C_BORDE_HOVER := Color("f2c6e0")
const C_TEXTO := Color("f4eefc")
const C_DORADO := Color("f5c542")

var k := 1.0
var fuente: Font
var boton: Button
var fondo: ColorRect
var panel: PanelContainer
var abierto := false
var escena_actual: Node = null

# Bitácora
var bitacora_ui = null                 # instancia de bitacora_ui.tscn (sin tipo: usa funciones propias)
var opcion_bitacora: Button
var aviso: PanelContainer              # cartelito "Nueva entrada en la bitácora"
var aviso_texto: Label
var tween_aviso: Tween


func _ready() -> void:
	layer = 100                                   # siempre encima de todo
	process_mode = Node.PROCESS_MODE_ALWAYS       # funciona aunque el juego esté en pausa
	k = get_viewport().get_visible_rect().size.y / 648.0
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font

	# Botón pequeño con tres rayitas
	boton = Button.new()
	boton.text = "II"
	boton.focus_mode = Control.FOCUS_NONE
	boton.position = POSICION * k
	boton.size = TAMANO * k
	boton.custom_minimum_size = TAMANO * k
	boton.tooltip_text = "Menú"
	_estilo_boton(boton, 16)
	boton.modulate.a = 0.75
	boton.mouse_entered.connect(func(): boton.modulate.a = 1.0)
	boton.mouse_exited.connect(func(): boton.modulate.a = 0.75)
	boton.pressed.connect(_alternar)
	add_child(boton)

	# Fondo oscuro (solo cuando el menú está abierto)
	fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.45)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.size = get_viewport().get_visible_rect().size
	fondo.visible = false
	fondo.gui_input.connect(_clic_fuera)
	add_child(fondo)
	move_child(fondo, 0)

	# Menú desplegable debajo del botón
	panel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = C_FONDO
	estilo.border_color = C_BORDE
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(6 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	panel.position = (POSICION + Vector2(0, TAMANO.y + 4)) * k
	panel.visible = false
	add_child(panel)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", int(4 * k))
	panel.add_child(lista)
	opcion_bitacora = _opcion("BITÁCORA", _abrir_bitacora)
	lista.add_child(_opcion("CONTINUAR", _cerrar))
	lista.add_child(opcion_bitacora)
	lista.add_child(_opcion("IDIOMA / LANGUAGE", _cambiar_idioma))
	lista.add_child(_opcion("REINICIAR ESCENA", _reiniciar))
	lista.add_child(_opcion("MENÚ PRINCIPAL", _ir_al_menu))

	_crear_aviso()
	_preparar_bitacora()
	_revisar_escena()


func _opcion(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 26) * k
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_estilo_boton(b, 12)
	b.pressed.connect(accion)
	return b


func _estilo_boton(b: Button, tam: int) -> void:
	b.add_theme_font_override("font", fuente)
	b.add_theme_font_size_override("font_size", int(tam * k))
	for estado in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = C_FONDO if estado == "normal" else C_HOVER
		s.border_color = C_BORDE if estado == "normal" else C_BORDE_HOVER
		s.set_border_width_all(max(1, int(1 * k)))
		s.set_content_margin_all(int(4 * k))
		b.add_theme_stylebox_override(estado, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, C_TEXTO)


# ---------- Abrir / cerrar ----------

func _alternar() -> void:
	if abierto:
		_cerrar()
	else:
		_abrir()


func _abrir() -> void:
	abierto = true
	_ocultar_aviso()   # ya vio el aviso: se quita el cartelito
	panel.visible = true
	fondo.visible = true
	get_tree().paused = true


func _cerrar() -> void:
	abierto = false
	if bitacora_ui and bitacora_ui.esta_abierta():
		bitacora_ui.cerrar()
	panel.visible = false
	fondo.visible = false
	get_tree().paused = false


func _clic_fuera(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cerrar()


func _reiniciar() -> void:
	_cerrar()
	get_tree().reload_current_scene()


func _ir_al_menu() -> void:
	_cerrar()
	if ResourceLoader.exists(ESCENA_MENU):
		get_tree().change_scene_to_file(ESCENA_MENU)
	else:
		push_warning("No existe " + ESCENA_MENU)


# ---------- Bitácora ----------

func _preparar_bitacora() -> void:
	var datos = get_node_or_null("/root/Bitacora")
	if datos == null:
		push_warning("MenuPausa: falta el Autoload 'Bitacora' (scripts/bitacora.gd).")
		opcion_bitacora.disabled = true
		return
	if not ResourceLoader.exists(ESCENA_BITACORA):
		push_warning("MenuPausa: no existe " + ESCENA_BITACORA)
		opcion_bitacora.disabled = true
		return

	datos.entrada_desbloqueada.connect(_on_entrada_desbloqueada)

	bitacora_ui = load(ESCENA_BITACORA).instantiate()
	bitacora_ui.mostrar_boton_hud = false     # aquí se abre desde el menú, no con su botón
	bitacora_ui.layer = layer + 10            # encima del menú de pausa
	bitacora_ui.cerrado.connect(_on_bitacora_cerrada)
	add_child(bitacora_ui)

	# Mismo estilo que el menú de pausa
	var marco := StyleBoxFlat.new()
	marco.bg_color = C_FONDO
	marco.border_color = C_BORDE
	marco.set_border_width_all(max(1, int(2 * k)))
	marco.set_content_margin_all(int(6 * k))
	var panel_diario: Control = bitacora_ui.get_node_or_null("Ventana/Centro/Panel")
	if panel_diario:
		panel_diario.add_theme_stylebox_override("panel", marco)


func _abrir_bitacora() -> void:
	if bitacora_ui == null:
		return
	# El juego sigue en pausa; solo escondemos el menú mientras se lee el diario.
	panel.visible = false
	fondo.visible = false
	_marcar_novedad(false)
	bitacora_ui.abrir()


func _on_bitacora_cerrada() -> void:
	# Al cerrar el diario (X o Esc) se vuelve al menú de pausa.
	if abierto:
		panel.visible = true
		fondo.visible = true


func _on_entrada_desbloqueada(id: String) -> void:
	_marcar_novedad(true)
	var entrada: Dictionary = get_node("/root/Bitacora").obtener_entrada(id)
	_mostrar_aviso(TranslationServer.translate("NUEVA ENTRADA EN LA BITÁCORA:") + "\n" + str(entrada.get("titulo", id)))


func _marcar_novedad(hay: bool) -> void:
	opcion_bitacora.text = "BITÁCORA  (!)" if hay else "BITÁCORA"
	var color := C_DORADO if hay else C_TEXTO
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		boton.add_theme_color_override(c, color)
		opcion_bitacora.add_theme_color_override(c, color)


func _crear_aviso() -> void:
	aviso = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = C_FONDO
	estilo.border_color = C_DORADO
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(6 * k))
	aviso.add_theme_stylebox_override("panel", estilo)
	aviso.position = (POSICION + Vector2(TAMANO.x + 8, 0)) * k
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.visible = false
	aviso_texto = Label.new()
	aviso_texto.add_theme_font_override("font", fuente)
	aviso_texto.add_theme_font_size_override("font_size", int(11 * k))
	aviso_texto.add_theme_color_override("font_color", C_TEXTO)
	aviso_texto.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	aviso.add_child(aviso_texto)
	add_child(aviso)


func _mostrar_aviso(texto: String) -> void:
	aviso_texto.text = texto
	aviso.modulate.a = 1.0
	aviso.visible = true
	if tween_aviso:
		tween_aviso.kill()
		tween_aviso = null
	if SEGUNDOS_AVISO <= 0.0:
		return   # se queda hasta que se abra el menú de pausa
	tween_aviso = create_tween()
	tween_aviso.tween_interval(SEGUNDOS_AVISO)
	tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.8)
	tween_aviso.tween_callback(aviso.hide)


func _ocultar_aviso() -> void:
	if tween_aviso:
		tween_aviso.kill()
		tween_aviso = null
	if aviso:
		aviso.hide()


## Cambia entre español e inglés sin salir de la partida.
## Godot vuelve a traducir solo el texto de los botones y las etiquetas.
func _cambiar_idioma() -> void:
	var idioma = get_node_or_null("/root/Idioma")
	if idioma == null:
		push_warning("MenuPausa: falta el Autoload 'Idioma' (scripts/idioma.gd).")
		return
	idioma.alternar()
	_ocultar_aviso()


# ---------- Ocultarlo en el menú principal ----------

func _process(_delta: float) -> void:
	if get_tree().current_scene != escena_actual:
		_revisar_escena()


func _revisar_escena() -> void:
	escena_actual = get_tree().current_scene
	var escena := get_tree().current_scene
	var en_menu := escena != null and escena.scene_file_path == ESCENA_MENU
	boton.visible = not en_menu
	if en_menu and abierto:
		_cerrar()
