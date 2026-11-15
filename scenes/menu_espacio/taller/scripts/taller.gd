extends Control
## TALLER: se mejora la nave elegida antes del despegue.
## Misma interfaz que la selección de nave, con el hangar en el centro.
## Clic en un stat (izquierda) -> comprar mejora mínima, media o máxima (derecha).
## Los precios y puntos están en mision.gd (MEJORAS).

# ---------- Cosas que puedes cambiar fácilmente ----------
const ESCENA_SIGUIENTE := "res://scenes/ascenso.tscn"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const LETRAS_POR_SEGUNDO := 40.0

const STATS := [
	["propulsion", "PROPULSIÓN"],
	["energia", "ENERGÍA"],
	["masa", "CAP. DE MASA"],
	["ciencia", "CIENCIA"],
	["comunicaciones", "COMUNICACIONES"],
]

# Lo que explica Albertsahur de cada stat
const EFECTOS := {
	"propulsion": "PROPULSIÓN: motores más potentes. La nave sube más rápido y llegas antes a la exosfera.",
	"energia": "ENERGÍA: alimenta un escudo protector. Cada 40 puntos de energía absorbe un golpe sin perder resistencia.",
	"masa": "CAP. DE MASA: casco más fuerte, aguanta más golpes... pero la nave pesa más y se mueve más lento a los lados.",
	"ciencia": "CIENCIA: más instrumentos. Juntamos más datos en cada capa de la atmósfera y eso da más puntos al final.",
	"comunicaciones": "COMUNICACIONES: el centro de control nos avisa antes de que caigan rayos. Con 50 o más, también avisa de dónde vienen aviones y satélites.",
}

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
const C_SELECCION := Color("f2c6e0")
# ---------------------------------------------------------

var k := 1.0
var id_nave := "apollo11"
var datos_nave: Dictionary
var stat_elegido := "propulsion"
var compras := []          # historial para deshacer: [stat, puntos, costo]
var saliendo := false
var yendo := false

var filas := {}
var barras := {}
var valores := {}
var lbl_restante: Label
var lbl_gastado: Label
var lbl_stat: Label
var lbl_efecto: Label
var lbl_resumen: Label
var botones_mejora := []
var btn_deshacer: Button
var btn_lanzar: Button

var retrato: TextureRect
var lbl_dialogo: Label
var lbl_continuar: Label
var tex_normal: Texture2D
var tex_hablando: Texture2D
var tex_parpadeo: Texture2D
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
	id_nave = Mision.nave_elegida if Mision.NAVES.has(Mision.nave_elegida) else "apollo11"
	Mision.nave_elegida = id_nave
	datos_nave = Mision.NAVES[id_nave]
	Mision.reiniciar_mejoras()
	Mision.presupuesto_restante = Mision.presupuesto - int(datos_nave.costo)

	tex_normal = _cargar("res://assets/personajes/astronauta.png")
	tex_hablando = _cargar("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = _cargar("res://assets/personajes/astronauta_parpadeo.png")
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
	medio.add_child(_crear_panel_hangar())
	medio.add_child(_crear_panel_mejoras())

	columna.add_child(_crear_dialogo())

	_elegir_stat("propulsion", false)
	_actualizar(false)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	decir([
		TranslationServer.translate("¡Bienvenido al taller, director! Aquí equipamos la %s antes del despegue.") % datos_nave.nombre,
		"Toca un stat a la izquierda y compra una mejora a la derecha: mínima, media o máxima. Ningún stat pasa de 100.",
		"Cada stat cambia el vuelo: propulsión sube más rápido, energía da escudos, masa da resistencia, comunicaciones da avisos y ciencia da puntos.",
		"Ojo: el dinero que no gastes también suma puntos al final. ¡Elige con cuidado!",
	])


func _cargar(ruta: String) -> Texture2D:
	var t: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	if t == null:
		push_error("No encuentro la imagen: " + ruta)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	return t


func _process(delta: float) -> void:
	tiempo += delta
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
		proximo_parpadeo -= delta
		if proximo_parpadeo <= 0.0:
			retrato.texture = tex_parpadeo
			if proximo_parpadeo <= -0.12:
				proximo_parpadeo = randf_range(2.0, 4.5)
		else:
			retrato.texture = tex_normal
	var hay_mas: bool = not cola.is_empty() or al_terminar.is_valid()
	lbl_continuar.visible = not _hablando() and hay_mas and fmod(tiempo, 0.8) < 0.55


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_avanzar()


# ================= Tienda =================

func _elegir_stat(stat: String, hablar: bool = true) -> void:
	stat_elegido = stat
	for s in STATS:
		var estilo := _caja(C_PANTALLA, C_SELECCION if s[0] == stat else C_BORDE_PANTALLA, 2 if s[0] == stat else 1, 3)
		filas[s[0]].add_theme_stylebox_override("panel", estilo)
	for s in STATS:
		if s[0] == stat:
			lbl_stat.text = s[1]
	lbl_efecto.text = String(EFECTOS[stat]).split(": ", true, 1)[1]
	_actualizar_botones()
	if hablar and not saliendo:
		decir([EFECTOS[stat]])


func _comprar(nivel: int) -> void:
	var m: Dictionary = Mision.MEJORAS[nivel]
	var costo: int = m.costo
	if costo > Mision.presupuesto_restante or saliendo:
		return
	var antes := Mision.valor(id_nave, stat_elegido)
	var util: int = min(int(m.puntos), Mision.STAT_MAXIMO - antes)
	if util <= 0:
		return
	Mision.mejoras[stat_elegido] = int(Mision.mejoras.get(stat_elegido, 0)) + util
	Mision.presupuesto_restante -= costo
	compras.append([stat_elegido, util, costo])
	_actualizar(true)
	var nombre: String = lbl_stat.text
	var linea := TranslationServer.translate("¡Listo! Mejora %s instalada: %s sube de %d a %d.") % [TranslationServer.translate(m.nombre), TranslationServer.translate(nombre), antes, antes + util]
	if util < int(m.puntos):
		linea += TranslationServer.translate(" (Solo se aprovecharon %d puntos porque el máximo es 100.)") % util
	decir([linea, _comentario_efecto(stat_elegido)])


func _deshacer() -> void:
	if compras.is_empty() or saliendo:
		return
	var c: Array = compras.pop_back()
	Mision.mejoras[c[0]] = int(Mision.mejoras.get(c[0], 0)) - int(c[1])
	Mision.presupuesto_restante += int(c[2])
	_actualizar(true)
	decir([TranslationServer.translate("Desinstalamos la última mejora y te devolvieron %s.") % Mision.dinero(int(c[2]))])


func _comentario_efecto(stat: String) -> String:
	match stat:
		"propulsion":
			return TranslationServer.translate("Ahora llegaremos a la exosfera en unos %d segundos de vuelo a toda potencia.") % int(Mision.duracion_ascenso(id_nave))
		"energia":
			return TranslationServer.translate("El escudo protector aguantará %d golpe(s) antes de que el casco reciba daño.") % Mision.escudo_inicial(id_nave)
		"masa":
			return TranslationServer.translate("El casco aguanta %d golpes, y la maniobra quedó %s.") % [Mision.vida_max(id_nave), TranslationServer.translate(Mision.maniobra_texto(id_nave)).to_lower()]
		"ciencia":
			return TranslationServer.translate("Juntaremos %d puntos de datos en cada capa de la atmósfera.") % Mision.datos_por_capa(id_nave)
		"comunicaciones":
			var extra := " ¡Y ya nos avisarán de dónde vienen aviones y satélites!" if Mision.avisos_laterales(id_nave) else ""
			return TranslationServer.translate("Tendremos %.1f segundos de aviso antes de cada rayo.%s") % [Mision.aviso_rayo(id_nave), extra]
	return ""


func _actualizar(animar: bool) -> void:
	var t := create_tween().set_parallel(true)
	var hubo_animacion := false
	for s in STATS:
		var base: int = datos_nave.stats[s[0]]
		var total := Mision.valor(id_nave, s[0])
		var extra := total - base
		valores[s[0]].text = str(total) if extra <= 0 else TranslationServer.translate("%d (+%d)") % [total, extra]
		valores[s[0]].add_theme_color_override("font_color", C_CIAN if extra > 0 else C_DORADO)
		var barra: ProgressBar = barras[s[0]]
		var c := _color_stat(total)
		barra.add_theme_stylebox_override("fill", _caja(c, c.lightened(0.25), 1, 0))
		if animar:
			t.tween_property(barra, "value", float(total), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			hubo_animacion = true
		else:
			barra.value = total
	if not hubo_animacion:
		t.kill()

	var gastado := Mision.presupuesto - int(datos_nave.costo) - Mision.presupuesto_restante
	lbl_gastado.text = "MEJORAS: -" + Mision.dinero(gastado)
	lbl_restante.text = "   QUEDAN: " + Mision.dinero(Mision.presupuesto_restante)
	var col := C_VERDE
	if Mision.presupuesto_restante < 5_000_000:
		col = C_ROJO
	elif Mision.presupuesto_restante < 15_000_000:
		col = C_AMARILLO
	lbl_restante.add_theme_color_override("font_color", col)

	lbl_resumen.text = TranslationServer.translate("RESISTENCIA %d  |  MANIOBRA %s  |  ESCUDO %d\nAVISO DE RAYOS %.1f s%s  |  DATOS %d por capa") % [
		Mision.vida_max(id_nave), TranslationServer.translate(Mision.maniobra_texto(id_nave)), Mision.escudo_inicial(id_nave),
		Mision.aviso_rayo(id_nave), TranslationServer.translate(" + LATERALES") if Mision.avisos_laterales(id_nave) else "",
		Mision.datos_por_capa(id_nave)]
	_actualizar_botones()


func _actualizar_botones() -> void:
	var actual := Mision.valor(id_nave, stat_elegido)
	for i in Mision.MEJORAS.size():
		var m: Dictionary = Mision.MEJORAS[i]
		var b: Button = botones_mejora[i]
		var util: int = min(int(m.puntos), Mision.STAT_MAXIMO - actual)
		var precio := TranslationServer.translate("$%dM") % int(int(m.costo) / 1_000_000.0)
		if util <= 0:
			b.text = TranslationServer.translate("%s  (STAT AL MÁXIMO)") % TranslationServer.translate(m.nombre)
		elif util < int(m.puntos):
			b.text = TranslationServer.translate("%s  +%d (solo +%d)  %s") % [TranslationServer.translate(m.nombre), m.puntos, util, precio]
		else:
			b.text = TranslationServer.translate("%s  +%d   %s") % [TranslationServer.translate(m.nombre), m.puntos, precio]
		b.disabled = util <= 0 or int(m.costo) > Mision.presupuesto_restante or saliendo
	btn_deshacer.disabled = compras.is_empty() or saliendo


func _color_stat(valor: int) -> Color:
	if valor >= 70:
		return C_VERDE
	if valor >= 40:
		return C_AMARILLO
	return C_ROJO


func _lanzar() -> void:
	if saliendo:
		return
	saliendo = true
	btn_lanzar.disabled = true
	_actualizar_botones()
	decir([TranslationServer.translate("¡La %s está lista! Vamos a la plataforma de lanzamiento.") % datos_nave.nombre])
	# Bitácora: se desbloquea la entrada de la nave elegida
	var bitacora = get_node_or_null("/root/Bitacora")
	if bitacora:
		bitacora.desbloquear_nave(id_nave)
	# Se va solo después de un momento (no hace falta dar clic)
	get_tree().create_timer(2.5).timeout.connect(_ir_siguiente)


func _ir_siguiente() -> void:
	if yendo:
		return
	yendo = true
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.5)
		t.tween_callback(func(): get_tree().change_scene_to_file(ESCENA_SIGUIENTE))
	else:
		push_error("No existe " + ESCENA_SIGUIENTE)
		decir(["(No encuentro la escena del lanzamiento. Revisa que ascenso.tscn esté en res://scenes/)"])
		yendo = false
		saliendo = false
		btn_lanzar.disabled = false
		_actualizar_botones()


# ================= Diálogo =================

func decir(lineas: Array, despues: Callable = Callable()) -> void:
	cola = lineas.duplicate()
	al_terminar = despues
	_siguiente_linea()


func _siguiente_linea() -> void:
	if cola.is_empty():
		var f := al_terminar
		al_terminar = Callable()
		if f.is_valid():
			f.call()
		return
	lbl_dialogo.text = cola.pop_front()
	letras = 0.0
	lbl_dialogo.visible_characters = 0


func _hablando() -> bool:
	return lbl_dialogo.visible_characters < lbl_dialogo.get_total_character_count()


func _avanzar() -> void:
	if _hablando():
		letras = lbl_dialogo.get_total_character_count()
	else:
		_siguiente_linea()


func _on_dialogo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_avanzar()


func _on_fila_input(event: InputEvent, stat: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_elegir_stat(stat)


# ================= Construcción de la interfaz (igual que la selección) =================

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
	tema.set_stylebox("hover", "Button", _caja(Color("3a2a66"), C_SELECCION, 2, 4))
	tema.set_stylebox("pressed", "Button", _caja(C_BORDE, C_SELECCION, 2, 4))
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
	izq.add_child(_etiqueta("DISEÑO DE MISIÓN: TALLER DE MEJORAS", 9, C_CIAN))

	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)

	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 0)
	fila.add_child(der)
	var presupuesto := _etiqueta(TranslationServer.translate("PRESUPUESTO: %s  |  NAVE: -%s") % [Mision.dinero(Mision.presupuesto), Mision.dinero(int(datos_nave.costo))], 10, C_DORADO)
	presupuesto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	der.add_child(presupuesto)
	var costos := HBoxContainer.new()
	costos.alignment = BoxContainer.ALIGNMENT_END
	costos.add_theme_constant_override("separation", 0)
	der.add_child(costos)
	lbl_gastado = _etiqueta("", 9)
	lbl_restante = _etiqueta("", 9)
	costos.add_child(lbl_gastado)
	costos.add_child(lbl_restante)
	return p


func _crear_panel_stats() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE))
	p.custom_minimum_size.x = _px(150)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(3))
	p.add_child(v)

	var titulo := _etiqueta("STATS (toca uno)", 11)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	for s in STATS:
		var fila := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 1, 3))
		fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fila.mouse_filter = Control.MOUSE_FILTER_STOP
		fila.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fila.gui_input.connect(_on_fila_input.bind(s[0]))
		v.add_child(fila)
		filas[s[0]] = fila
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", _px(5))
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(h)

		var icono := _imagen()
		icono.texture = _cargar("res://assets/ui/icono_%s.png" % s[0])
		icono.custom_minimum_size = Vector2(_px(24), _px(24))
		h.add_child(icono)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", _px(2))
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(col)

		var arriba := HBoxContainer.new()
		arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.add_theme_stylebox_override("background", _caja(Color("05070f"), Color("2a3050"), 1, 0))
		col.add_child(barra)
		barras[s[0]] = barra
	return p


func _crear_panel_hangar() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(3))
	p.add_child(v)

	var titulo := _etiqueta("HANGAR: " + String(datos_nave.nombre), 11)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	var pantalla := _panel(_caja(C_PANTALLA, C_BORDE_PANTALLA, 2, 0))
	pantalla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pantalla.clip_contents = true
	v.add_child(pantalla)

	# Imagen del hangar con la nave elegida (llena todo el panel)
	var hangar := TextureRect.new()
	hangar.texture = _cargar(datos_nave.hangar_img)
	hangar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hangar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hangar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hangar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla.add_child(hangar)

	# Resumen de cómo vuela la nave, encima de la imagen
	var capa := VBoxContainer.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla.add_child(capa)
	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(hueco)
	var caja := _panel(_caja(Color(0.04, 0.06, 0.15, 0.85), C_BORDE_PANTALLA, 1, 4))
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(caja)
	lbl_resumen = _etiqueta("", 7, C_CIAN)
	lbl_resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(lbl_resumen)
	return p


func _crear_panel_mejoras() -> Control:
	var p := _panel(_caja(C_PANEL, C_BORDE))
	p.custom_minimum_size.x = _px(165)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(4))
	p.add_child(v)

	var titulo := _etiqueta("MEJORAS", 11)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	lbl_stat = _etiqueta("", 10, C_DORADO)
	lbl_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_stat)

	lbl_efecto = _etiqueta("", 7)
	lbl_efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_efecto.custom_minimum_size.y = _px(34)
	v.add_child(lbl_efecto)

	for i in Mision.MEJORAS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = _px(20)
		b.add_theme_font_size_override("font_size", _px(8))
		b.pressed.connect(_comprar.bind(i))
		v.add_child(b)
		botones_mejora.append(b)

	btn_deshacer = Button.new()
	btn_deshacer.text = "DESHACER ÚLTIMA"
	btn_deshacer.focus_mode = Control.FOCUS_NONE
	btn_deshacer.custom_minimum_size.y = _px(16)
	btn_deshacer.add_theme_font_size_override("font_size", _px(7))
	btn_deshacer.pressed.connect(_deshacer)
	v.add_child(btn_deshacer)

	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hueco)

	btn_lanzar = Button.new()
	btn_lanzar.text = "¡A LA PLATAFORMA!"
	btn_lanzar.focus_mode = Control.FOCUS_NONE
	btn_lanzar.custom_minimum_size.y = _px(28)
	btn_lanzar.add_theme_font_size_override("font_size", _px(11))
	btn_lanzar.add_theme_stylebox_override("normal", _caja(Color("6b3b5e"), C_SELECCION, 2, 4))
	btn_lanzar.add_theme_stylebox_override("hover", _caja(Color("8a4c79"), Color("ffffff"), 2, 4))
	btn_lanzar.pressed.connect(_lanzar)
	v.add_child(btn_lanzar)
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
