extends Control
## Pantalla de selección de nave con tutorial.
## Albertsahur explica la misión abajo a la izquierda y se anima al hablar.
## Controles: flechas < > (o teclado izquierda/derecha) para cambiar de nave,
## clic en el cuadro de diálogo, Espacio o Enter para avanzar el texto.

# ---------- Cosas que puedes cambiar fácilmente ----------
const ESCENA_SIGUIENTE := "res://scenes/ascenso.tscn"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const LETRAS_POR_SEGUNDO := 40.0

const TUTORIAL := [
	"¡Hola, director! Soy Albertsahur, tu astronauta. Antes de despegar tenemos que elegir la nave.",
	"A la izquierda están las stats: propulsión, energía, capacidad de masa, ciencia y comunicaciones.",
	"Arriba a la derecha ves el presupuesto. Cada nave cuesta distinto, y lo que sobre lo usaremos para instrumentos y equipo.",
	"Usa las flechas < > para comparar las naves. Ojo: la más cara no siempre es la mejor opción.",
	"Cuando te decidas, presiona ELEGIR NAVE. ¡Te espero!",
]

# id de la stat (igual que en mision.gd) y el nombre que se muestra
const STATS := [
	["propulsion", "PROPULSIÓN"],
	["energia", "ENERGÍA"],
	["masa", "CAP. DE MASA"],
	["ciencia", "CIENCIA"],
	["comunicaciones", "COMUNICACIONES"],
]

const C_FONDO := Color("0b0f24")
const C_PANEL := Color("39426a")
const C_BORDE := Color("6a76a8")
const C_PANTALLA := Color("0b1026")
const C_BORDE_PANTALLA := Color("1d2445")
const C_TEXTO := Color("f4eefc")
const C_DORADO := Color("f5c542")
const C_CIAN := Color("8fd3e8")
const C_ROJO := Color("e5383b")
const C_AMARILLO := Color("f2d533")
const C_VERDE := Color("3cc24f")
# ---------------------------------------------------------

var k := 1.0                 # escala según el tamaño de la pantalla
var indice := 0              # nave que se está viendo
var tutorial_terminado := false
var eligiendo := false

# Partes de la interfaz que cambian
var barras := {}
var valores := {}
var cohete: TextureRect
var capsula: TextureRect
var lbl_titulo_nave: Label
var lbl_nombre: Label
var lbl_desc: Label
var lbl_ficha: Label
var lbl_costo: Label
var lbl_restante: Label
var btn_elegir: Button
var retrato: TextureRect
var lbl_dialogo: Label
var lbl_continuar: Label
var estrellas := []

# Caras del astronauta
var tex_normal: Texture2D
var tex_hablando: Texture2D
var tex_parpadeo: Texture2D

# Diálogo
var cola := []
var letras := 0.0
var al_terminar := Callable()
var tiempo := 0.0
var reloj_boca := 0.0
var boca_abierta := false
var proximo_parpadeo := 2.5


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	k = get_viewport_rect().size.y / 360.0
	tex_normal = load("res://assets/personajes/astronauta.png")
	tex_hablando = load("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = load("res://assets/personajes/astronauta_parpadeo.png")
	theme = _crear_tema()

	var fondo := ColorRect.new()
	fondo.color = C_FONDO
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, _px(6))
	add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", _px(4))
	margen.add_child(columna)

	columna.add_child(_crear_encabezado())

	var medio := HBoxContainer.new()
	medio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	medio.add_theme_constant_override("separation", _px(4))
	columna.add_child(medio)
	medio.add_child(_crear_panel_stats())
	medio.add_child(_crear_panel_nave())
	medio.add_child(_crear_panel_ficha())

	columna.add_child(_crear_dialogo())

	_mostrar_nave(false)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	decir(TUTORIAL, _fin_tutorial)


func _process(delta: float) -> void:
	tiempo += delta

	# --- Albertsahur hablando: escribe el texto y mueve la boca ---
	if _hablando():
		letras = min(letras + LETRAS_POR_SEGUNDO * delta, lbl_dialogo.get_total_character_count())
		lbl_dialogo.visible_characters = int(letras)
		reloj_boca += delta
		if reloj_boca >= 0.11:
			reloj_boca = 0.0
			boca_abierta = not boca_abierta
		retrato.texture = tex_hablando if boca_abierta else tex_normal
		var salto: float = round(abs(sin(tiempo * 14.0)) * _px(2))
		retrato.offset_top = -salto
		retrato.offset_bottom = -salto
	else:
		retrato.offset_top = 0
		retrato.offset_bottom = 0
		# Parpadea de vez en cuando
		proximo_parpadeo -= delta
		if proximo_parpadeo <= 0.0:
			retrato.texture = tex_parpadeo
			if proximo_parpadeo <= -0.12:
				proximo_parpadeo = randf_range(2.0, 4.5)
		else:
			retrato.texture = tex_normal

	var hay_mas: bool = not cola.is_empty() or al_terminar.is_valid()
	lbl_continuar.visible = not _hablando() and hay_mas and fmod(tiempo, 0.8) < 0.55

	# --- El cohete flota un poquito ---
	var flotar: float = round(sin(tiempo * 2.0) * _px(2))
	cohete.offset_top = _px(8) + flotar
	cohete.offset_bottom = -_px(2) + flotar

	# --- Estrellas bajando, como si el cohete subiera ---
	for e in estrellas:
		e.d += e.vel * delta
		var o: float = fposmod(e.d, 128.0)
		e.nodo.offset_top = -128.0 + o
		e.nodo.offset_bottom = o


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_avanzar()
	elif event.is_action_pressed("ui_left"):
		_cambiar_nave(-1)
	elif event.is_action_pressed("ui_right"):
		_cambiar_nave(1)


# ================= Diálogo =================

## Hace que Albertsahur diga varias líneas. "despues" se llama al terminar.
func decir(lineas: Array, despues: Callable = Callable()) -> void:
	cola = lineas.duplicate()
	al_terminar = despues
	_siguiente_linea()


func _siguiente_linea() -> void:
	if cola.is_empty():
		var funcion := al_terminar
		al_terminar = Callable()
		if funcion.is_valid():
			funcion.call()
		return
	lbl_dialogo.text = cola.pop_front()
	letras = 0.0
	lbl_dialogo.visible_characters = 0


func _hablando() -> bool:
	return lbl_dialogo.visible_characters < lbl_dialogo.get_total_character_count()


func _avanzar() -> void:
	if _hablando():
		letras = lbl_dialogo.get_total_character_count()   # muestra todo de golpe
	else:
		_siguiente_linea()


func _on_dialogo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_avanzar()


func _fin_tutorial() -> void:
	tutorial_terminado = true
	btn_elegir.disabled = false


# ================= Naves =================

func _cambiar_nave(direccion: int) -> void:
	if eligiendo:
		return
	indice = wrapi(indice + direccion, 0, Mision.ORDEN.size())
	_mostrar_nave(true)
	# Después del tutorial, Albertsahur comenta cada nave
	if tutorial_terminado:
		decir([Mision.NAVES[Mision.ORDEN[indice]].comentario])


func _mostrar_nave(animar: bool) -> void:
	var n: Dictionary = Mision.NAVES[Mision.ORDEN[indice]]
	cohete.texture = load(n.cohete_img)
	capsula.texture = load(n.capsula_img)
	lbl_titulo_nave.text = "ELIGE TU NAVE  %d/%d" % [indice + 1, Mision.ORDEN.size()]
	lbl_nombre.text = n.nombre
	lbl_desc.text = n.descripcion
	var id: String = Mision.ORDEN[indice]
	lbl_ficha.text = "COHETE: %s (%d)\nTRIPULACIÓN: %d\nDESTINO: %s\nCOSTO: %s\nRESISTENCIA: %d golpes\nMANIOBRA: %s" % [
		n.cohete, n.anio, n.tripulacion, n.destino, Mision.dinero(n.costo),
		Mision.vida_max(id), Mision.maniobra_texto(id)]

	var resta: int = Mision.presupuesto - n.costo
	lbl_costo.text = "NAVE: -" + Mision.dinero(n.costo)
	lbl_restante.text = "   QUEDAN: " + Mision.dinero(resta)
	var color_resta := C_VERDE
	if resta < 15_000_000:
		color_resta = C_ROJO
	elif resta < 40_000_000:
		color_resta = C_AMARILLO
	lbl_restante.add_theme_color_override("font_color", color_resta)

	var t := create_tween().set_parallel(true)
	for s in STATS:
		var valor: int = n.stats[s[0]]
		var barra: ProgressBar = barras[s[0]]
		valores[s[0]].text = str(valor)
		var c := _color_stat(valor)
		barra.add_theme_stylebox_override("fill", _caja(c, c.lightened(0.25), 1, 0))
		if animar:
			t.tween_property(barra, "value", float(valor), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			barra.value = valor
	if animar:
		cohete.modulate.a = 0.0
		capsula.modulate.a = 0.0
		t.tween_property(cohete, "modulate:a", 1.0, 0.25)
		t.tween_property(capsula, "modulate:a", 1.0, 0.25)
	else:
		t.kill()


func _color_stat(valor: int) -> Color:
	if valor >= 70:
		return C_VERDE
	if valor >= 40:
		return C_AMARILLO
	return C_ROJO


func _elegir() -> void:
	if eligiendo:
		return
	eligiendo = true
	btn_elegir.disabled = true
	Mision.nave_elegida = Mision.ORDEN[indice]
	var n: Dictionary = Mision.datos_nave()
	Mision.presupuesto_restante = Mision.presupuesto - n.costo
	decir([
		"¡Excelente elección! La %s ya está en la plataforma de lanzamiento." % n.nombre,
		"Nos quedan %s para el resto de la misión. ¡Prepárate para el despegue!" % Mision.dinero(Mision.presupuesto_restante),
	], _ir_siguiente)


func _ir_siguiente() -> void:
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.5)
		t.tween_callback(func(): get_tree().change_scene_to_file(ESCENA_SIGUIENTE))
	else:
		push_warning("Todavía no existe " + ESCENA_SIGUIENTE)
		decir(["(No encuentro la escena del ascenso. Revisa que ascenso.tscn esté en res://scenes/)"])
		eligiendo = false
		btn_elegir.disabled = false


# ================= Construcción de la interfaz =================

func _px(n: float) -> int:
	return int(round(n * k))


func _caja(fondo: Color, borde: Color, grosor: int = 2, margen: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(max(1, _px(grosor)))
	s.set_content_margin_all(_px(margen))
	return s


func _panel(estilo: StyleBoxFlat) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", estilo)
	return p


func _etiqueta(texto: String, tamano: int, color: Color = C_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", _px(tamano))
	l.add_theme_color_override("font_color", color)
	return l


func _imagen() -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _crear_tema() -> Theme:
	var tema := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		tema.default_font = load(RUTA_FUENTE)
	tema.default_font_size = _px(9)
	tema.set_color("font_color", "Label", C_TEXTO)
	tema.set_stylebox("normal", "Button", _caja(C_PANTALLA, C_BORDE, 2, 4))
	tema.set_stylebox("hover", "Button", _caja(Color("3a2a66"), Color("f2c6e0"), 2, 4))
	tema.set_stylebox("pressed", "Button", _caja(C_BORDE, Color("f2c6e0"), 2, 4))
	tema.set_stylebox("disabled", "Button", _caja(Color("2a2f45"), Color("454b66"), 2, 4))
	for estado in ["font_color", "font_hover_color", "font_pressed_color"]:
		tema.set_color(estado, "Button", C_TEXTO)
	tema.set_color("font_disabled_color", "Button", Color("6b7090"))
	return tema


func _crear_encabezado() -> Control:
	var p := _panel(_caja(C_PANTALLA, C_BORDE, 2, 5))
	var fila := HBoxContainer.new()
	p.add_child(fila)

	var izq := VBoxContainer.new()
	izq.add_theme_constant_override("separation", 0)
	fila.add_child(izq)
	izq.add_child(_etiqueta("EL VIAJE DE ALBERTSAHUR", 14, C_DORADO))
	izq.add_child(_etiqueta("DISEÑO DE MISIÓN: SELECCIÓN DE NAVE", 9, C_CIAN))

	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)

	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 0)
	fila.add_child(der)
	var presupuesto := _etiqueta("PRESUPUESTO: " + Mision.dinero(Mision.presupuesto), 12, C_DORADO)
	presupuesto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	der.add_child(presupuesto)
	var costos := HBoxContainer.new()
	costos.alignment = BoxContainer.ALIGNMENT_END
	costos.add_theme_constant_override("separation", 0)
	der.add_child(costos)
	lbl_costo = _etiqueta("", 9)
	lbl_restante = _etiqueta("", 9)
	costos.add_child(lbl_costo)
	costos.add_child(lbl_restante)
	return p


func _crear_panel_stats() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE))
	p.custom_minimum_size.x = _px(150)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(3))
	p.add_child(v)

	var titulo := _etiqueta("STATS DE LA NAVE", 11)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	for s in STATS:
		var fila := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 1, 3))
		fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(fila)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", _px(5))
		fila.add_child(h)

		var icono := _imagen()
		icono.texture = load("res://assets/ui/icono_%s.png" % s[0])
		icono.custom_minimum_size = Vector2(_px(24), _px(24))
		h.add_child(icono)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", _px(2))
		h.add_child(col)

		var arriba := HBoxContainer.new()
		col.add_child(arriba)
		var nombre := _etiqueta(s[1], 8)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arriba.add_child(nombre)
		var valor := _etiqueta("0", 8, C_DORADO)
		arriba.add_child(valor)
		valores[s[0]] = valor

		var barra := ProgressBar.new()
		barra.show_percentage = false
		barra.max_value = 100
		barra.custom_minimum_size.y = _px(7)
		barra.add_theme_stylebox_override("background", _caja(Color("05070f"), Color("2a3050"), 1, 0))
		col.add_child(barra)
		barras[s[0]] = barra
	return p


func _crear_panel_nave() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(3))
	p.add_child(v)

	lbl_titulo_nave = _etiqueta("", 11)
	lbl_titulo_nave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_titulo_nave)

	var pantalla := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 2, 0))
	pantalla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pantalla.clip_contents = true
	v.add_child(pantalla)

	# Fondo de estrellas (usa el paquete Cozy Space Backdrops)
	var cielo := Control.new()
	cielo.clip_contents = true
	cielo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla.add_child(cielo)
	for capa in [["stars-far-tile.png", 4.0], ["stars-near-tile.png", 14.0]]:
		var e := TextureRect.new()
		e.texture = load("res://assets/espacio/fondos/" + capa[0])
		e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		e.stretch_mode = TextureRect.STRETCH_TILE
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cielo.add_child(e)
		e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		estrellas.append({"nodo": e, "vel": capa[1], "d": 0.0})

	# Flecha izquierda | nave | flecha derecha
	var contenido := HBoxContainer.new()
	pantalla.add_child(contenido)
	contenido.add_child(_boton_flecha("<", -1))

	var centro := VBoxContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_theme_constant_override("separation", _px(2))
	contenido.add_child(centro)

	var soporte := Control.new()
	soporte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	soporte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(soporte)
	cohete = _imagen()
	soporte.add_child(cohete)
	cohete.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	lbl_nombre = _etiqueta("", 13, C_DORADO)
	lbl_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(lbl_nombre)
	lbl_desc = _etiqueta("", 8)
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.custom_minimum_size.y = _px(24)
	centro.add_child(lbl_desc)

	contenido.add_child(_boton_flecha(">", 1))
	return p


func _boton_flecha(texto: String, direccion: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_px(22), _px(40))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", _px(14))
	b.pressed.connect(_cambiar_nave.bind(direccion))
	return b


func _crear_panel_ficha() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE))
	p.custom_minimum_size.x = _px(135)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(4))
	p.add_child(v)

	var titulo := _etiqueta("FICHA TÉCNICA", 11)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	var marco := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 2, 3))
	v.add_child(marco)
	capsula = _imagen()
	capsula.custom_minimum_size.y = _px(46)
	marco.add_child(capsula)

	lbl_ficha = _etiqueta("", 8)
	lbl_ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(lbl_ficha)

	btn_elegir = Button.new()
	btn_elegir.text = "ELEGIR NAVE"
	btn_elegir.focus_mode = Control.FOCUS_NONE
	btn_elegir.disabled = true   # se activa al terminar el tutorial
	btn_elegir.custom_minimum_size.y = _px(28)
	btn_elegir.add_theme_font_size_override("font_size", _px(11))
	btn_elegir.add_theme_stylebox_override("normal", _caja(Color("6b3b5e"), Color("f2c6e0"), 2, 4))
	btn_elegir.add_theme_stylebox_override("hover", _caja(Color("8a4c79"), Color("ffffff"), 2, 4))
	btn_elegir.pressed.connect(_elegir)
	v.add_child(btn_elegir)
	return p


func _crear_dialogo() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE, 2, 4))
	p.custom_minimum_size.y = _px(74)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(_on_dialogo_input)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", _px(6))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)

	# Retrato de Albertsahur
	var marco := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 2, 0))
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(marco)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(_px(62), _px(56))
	hueco.clip_contents = true
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(hueco)
	retrato = _imagen()
	retrato.texture = tex_normal
	hueco.add_child(retrato)
	retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Cuadro de texto
	var caja := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 2, 6))
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(caja)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(2))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(v)
	v.add_child(_etiqueta("ALBERTSAHUR", 8, C_DORADO))
	lbl_dialogo = _etiqueta("", 10)
	lbl_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(lbl_dialogo)
	lbl_continuar = _etiqueta("clic / espacio >", 7, C_CIAN)
	lbl_continuar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(lbl_continuar)
	return p
