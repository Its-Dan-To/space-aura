extends Control
## ÓRBITA TERRESTRE + ESCAPE + LLEGADA A LA LUNA (todo en una sola escena, sin cortes)
## 1. La cápsula da vueltas a la Tierra (órbita de estacionamiento).
## 2. Enciende motores y escapa de la gravedad de la Tierra.
## 3. Nos acercamos a la Luna (aquí irá después la parte del viaje de 3 días).
## 4. Apollo 11: órbita lunar + alunizaje. Artemis II: sobrevuelo. Gemini IV: órbita lunar.
## Albertsahur explica cada paso. Al final se muestra el puntaje.

# ---------- Cosas que puedes cambiar fácilmente ----------
const RUTA := "res://assets/espacio/"
const NEBULOSA := "nebula-violet-tile.png"   # o "nebula-teal-tile.png" / "nebula-rose-tile.png"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const MODULO_LUNAR := "res://assets/naves/modulo_lunar.png"
const ESCENA_VIAJE := "res://scenes/viaje.tscn"   # viaje de 3 días en primera persona
const ESCENA_SIGUIENTE := "res://scenes/luna/mapa_luna.tscn"
const ESCENA_ALUNIZAJE := "res://scenes/Aterrizaje/Aterrizaje_2.0.tscn"   # minijuego de alunizaje
const NAVES_CON_ALUNIZAJE := ["apollo11", "gemini4"]   # Artemis II solo hace sobrevuelo
const ESCENA_TALLER := "res://scenes/taller.tscn"
const ESCENA_SELECCION := "res://scenes/seleccion_nave.tscn"
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const SEGUNDOS_POR_VUELTA := 9.0        # vuelta a la Tierra
const SEGUNDOS_POR_VUELTA_LUNA := 8.0   # vuelta a la Luna
const DURACION_ACERCAMIENTO := 10.0     # segundos que tarda en acercarse a la Luna
const TAMANO_TIERRA := 6.0      # la Tierra mide 48 px; se agranda 6 veces
const TAMANO_LUNA := 7.0        # al llegar, la Luna se agranda 7 veces
const ALTO_CAPSULA := 46.0
const INCLINACION := -0.22      # inclinación de la órbita terrestre (radianes)
const DISTANCIA_KM := 384400.0

const LINEAS_ORBITA := [
	"¡Salimos de la atmósfera! Ahora estamos en órbita alrededor de la Tierra.",
	"Vamos a casi 28,000 km/h. Estamos cayendo todo el tiempo hacia la Tierra, pero vamos tan rápido de lado que nunca chocamos con ella: eso es una órbita.",
	"No salimos directo al espacio. Primero damos vueltas en una 'órbita de estacionamiento' para revisar que todos los sistemas funcionen bien.",
	"También esperamos el momento justo: cuando el destino queda bien alineado, aprovechamos la velocidad que ya llevamos y gastamos menos combustible.",
]
const LINEA_NAVE := {
	"apollo11": "Así lo hizo el Apollo 11 en 1969: dio una vuelta y media a la Tierra antes de encender el motor rumbo a la Luna.",
	"artemis2": "Artemis II también revisa sus sistemas dando vueltas a la Tierra antes de encender motores hacia la Luna.",
	"gemini4": "Dato curioso: la Gemini IV real nunca salió de la órbita; pasó 4 días dando vueltas a la Tierra. ¡Nosotros sí vamos a ir más lejos!",
}
const LINEAS_ESCAPE := [
	"¡Ahora! Encendemos motores hasta unos 40,000 km/h: la velocidad de escape de la Tierra.",
	"A esa velocidad la gravedad ya no puede regresarnos. ¡Adiós, Tierra! ¡Rumbo a la Luna!",
]
const LINEAS_ACERCAMIENTO := [
	"¡Mira cómo se hace chiquita la Tierra! La Luna está a unos 384,400 km de distancia.",
	"Casi todo el camino vamos con los motores apagados: el impulso que tomamos nos lleva hasta allá.",
]
const LINEAS_INSERCION := [
	"Llegamos. Si no hacemos nada, pasaríamos de largo. Giramos la nave y encendemos el motor al revés para frenar.",
	"Así la gravedad de la Luna nos atrapa: ¡estamos en órbita lunar!",
	"La gravedad de la Luna es como una sexta parte de la de la Tierra. Por eso los astronautas parecen brincar al caminar.",
]
const LINEAS_APOLLO := [
	"Ahora el módulo lunar 'Eagle' se separa con dos astronautas, mientras el tercero se queda en órbita.",
]
const LINEAS_ALUNIZAJE := [
	"'El Águila ha aterrizado.' El 20 de julio de 1969, el Apollo 11 llegó al Mar de la Tranquilidad.",
	"¡Misión cumplida, director! Llegamos a la Luna.",
]
const LINEAS_A_ALUNIZAR := [
	"¡Ahora te toca a ti, director! Toma los controles y aluniza con cuidado.",
]
const LINEAS_GEMINI := [
	"Dato curioso: ninguna Gemini fue a la Luna. Servían para practicar en órbita las maniobras que luego usó el programa Apollo.",
	"¡Pero en nuestra misión sí lo logramos! ¡Misión cumplida, director!",
]
const LINEAS_ARTEMIS := [
	"Artemis II no frena para quedarse: usa una trayectoria de regreso libre.",
	"Le damos la vuelta a la Luna por su lado oculto y su gravedad nos regresa solita hacia la Tierra, casi sin gastar combustible.",
]
const LINEAS_ARTEMIS_FIN := [
	"¡Vimos el lado oculto de la Luna! Ahora regresamos a casa. ¡Misión cumplida, director!",
]
# ---------------------------------------------------------

var k := 1.0
var pantalla := Vector2.ZERO
var fuente: Font
var tiempo := 0.0
var id_nave := "apollo11"

var capas := []
var raiz: Node2D
var tierra: Sprite2D
var luna: Sprite2D
var capsula: Sprite2D
var fuego: CPUParticles2D
var modulo: Sprite2D
var orbita_atras: Node2D
var orbita_frente: Node2D
var reloj_frames := 0.0
var temblor := 0.0

# orbita, listo, escape, acercamiento, insercion, orbita_lunar, alunizaje, sobrevuelo, regreso, fin
var estado := "orbita"
var angulo := 0.6
var vueltas := 0.0
var t_escape := 0.0
var t_acercamiento := 0.0
var escala_orbita := 1.0
var listo_modulo := false
var giro_sobrevuelo := 0.0
var yendo_a_alunizaje := false

# Tierra
var centro_tierra := Vector2.ZERO
var rx_tierra := 0.0
var ry_tierra := 0.0
var tierra_inicio := Vector2.ZERO
# Luna
var luna_inicio := Vector2.ZERO
var centro_luna := Vector2.ZERO
var radio_luna := 0.0
var rx_luna := 0.0
var ry_luna := 0.0
var capsula_inicio := Vector2.ZERO

var lbl_titulo: Label
var lbl_velocidad: Label
var lbl_vuelta: Label
var lbl_centro: Label
var capa_hud: CanvasLayer

var retrato: TextureRect
var lbl_dialogo: Label
var tex_normal: Texture2D
var tex_hablando: Texture2D
var tex_parpadeo: Texture2D
var cola := []
var al_terminar := Callable()
var letras := 0.0
var espera := 0.0
var reloj_boca := 0.0
var boca_abierta := false
var parpadeo := 2.0


func _ready() -> void:
	pantalla = get_viewport_rect().size
	k = pantalla.y / 648.0
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font
	id_nave = Mision.nave_elegida if Mision.NAVES.has(Mision.nave_elegida) else "apollo11"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	raiz = Node2D.new()
	add_child(raiz)
	_crear_capa(NEBULOSA, 3.0, 256)
	_crear_capa("stars-mid-tile.png", 8.0, 128)
	_crear_capa("stars-near-tile.png", 16.0, 128)

	# --- Tierra con su halo de atmósfera ---
	centro_tierra = Vector2(pantalla.x * 0.42, pantalla.y * 0.48)
	tierra_inicio = centro_tierra
	tierra = Sprite2D.new()
	tierra.texture = _cargar(RUTA + "planetas/planet-terran-spin-24f.png")
	tierra.hframes = 24
	tierra.scale = Vector2.ONE * TAMANO_TIERRA * k
	tierra.position = centro_tierra
	raiz.add_child(tierra)
	var halo := Node2D.new()
	halo.show_behind_parent = true
	halo.draw.connect(_dibujar_halo.bind(halo))
	tierra.add_child(halo)
	rx_tierra = 24.0 * TAMANO_TIERRA * k * 1.75
	ry_tierra = rx_tierra * 0.38

	orbita_atras = Node2D.new()
	orbita_atras.z_index = -2
	orbita_atras.draw.connect(_dibujar_orbita.bind(true))
	raiz.add_child(orbita_atras)
	orbita_frente = Node2D.new()
	orbita_frente.z_index = 1
	orbita_frente.draw.connect(_dibujar_orbita.bind(false))
	raiz.add_child(orbita_frente)

	# --- Luna: primero chiquita a lo lejos ---
	luna_inicio = Vector2(pantalla.x * 0.86, pantalla.y * 0.18)
	luna = Sprite2D.new()
	luna.texture = _cargar(RUTA + "planetas/planet-moon-spin-24f.png")
	luna.hframes = 24
	luna.scale = Vector2.ONE * 1.6 * k
	luna.position = luna_inicio
	raiz.add_child(luna)
	centro_luna = Vector2(pantalla.x * 0.6, pantalla.y * 0.42)
	radio_luna = 24.0 * TAMANO_LUNA * k
	rx_luna = radio_luna * 1.45
	ry_luna = rx_luna * 0.38

	# --- Cápsula de la nave elegida ---
	capsula = Sprite2D.new()
	capsula.texture = _cargar(Mision.NAVES[id_nave].capsula_img)
	var esc := ALTO_CAPSULA * k / capsula.texture.get_size().y
	capsula.scale = Vector2(esc, esc)
	capsula.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if esc < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(capsula)
	_crear_fuego()

	_crear_hud()
	_crear_dialogo()
	_mover_en_orbita(0.0)
	_transicion_de_entrada()

	if Mision.fase_orbita == "llegada":
		# Venimos del viaje de 3 días: empezamos ya cerca de la Luna
		Mision.fase_orbita = ""
		_preparar_llegada()
	else:
		var lineas: Array = LINEAS_ORBITA.duplicate()
		lineas.append(LINEA_NAVE.get(id_nave, ""))
		decir(lineas, _listo_para_escapar)


## Si venimos del ascenso, su última imagen se desvanece encima (sin pantalla negra)
func _transicion_de_entrada() -> void:
	if Mision.captura != null:
		var foto := TextureRect.new()
		foto.texture = Mision.captura
		foto.size = pantalla
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_SCALE
		var encima := CanvasLayer.new()
		encima.layer = 10
		add_child(encima)
		encima.add_child(foto)
		Mision.captura = null
		var t := create_tween()
		t.tween_property(foto, "modulate:a", 0.0, 1.5)
		t.tween_callback(encima.queue_free)
	else:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.0)


func _process(delta: float) -> void:
	tiempo += delta
	_actualizar_dialogo(delta)

	var vel_fondo := 1.0
	if estado == "escape" or estado == "acercamiento":
		vel_fondo = 3.5
	for c in capas:
		c.d += c.vel * delta * vel_fondo
		c.nodo.position.x = -round(fposmod(c.d, c.tile))

	reloj_frames += delta
	if reloj_frames >= 0.12:
		reloj_frames = 0.0
		tierra.frame = (tierra.frame + 1) % tierra.hframes
		luna.frame = (luna.frame + 1) % luna.hframes

	var w := TAU / SEGUNDOS_POR_VUELTA
	var w_luna := TAU / SEGUNDOS_POR_VUELTA_LUNA
	match estado:
		"orbita", "listo":
			_mover_en_orbita(w * delta)
			# Enciende motores cuando pasa por el lado derecho, por delante de la Tierra
			if estado == "listo" and fposmod(angulo, TAU) < 0.35:
				_iniciar_escape()
		"escape":
			t_escape += delta
			escala_orbita = 1.0 + 0.45 * t_escape * t_escape
			_mover_en_orbita(w * (1.0 + t_escape * 0.9) * delta)
			var v: float = lerp(27600.0, 40300.0, clamp(t_escape / 2.0, 0.0, 1.0))
			lbl_velocidad.text = TranslationServer.translate("VELOCIDAD: %s km/h") % _miles(v)
			if t_escape >= 1.8:
				_iniciar_acercamiento()
		"acercamiento":
			t_acercamiento += delta
			_animar_acercamiento(t_acercamiento / DURACION_ACERCAMIENTO)
			if t_acercamiento >= DURACION_ACERCAMIENTO:
				_llegar_a_la_luna()
		"orbita_lunar":
			_mover_en_orbita(w_luna * delta)
			if listo_modulo and fposmod(angulo, TAU) > 2.85 and fposmod(angulo, TAU) < 3.1:
				listo_modulo = false
				_soltar_modulo()
		"alunizaje":
			_mover_en_orbita(w_luna * delta)
		"sobrevuelo":
			giro_sobrevuelo += w_luna * 0.8 * delta
			angulo = PI + giro_sobrevuelo
			_mover_en_orbita(0.0)
			if giro_sobrevuelo >= TAU:
				estado = "regreso"
				decir(LINEAS_ARTEMIS_FIN)
				get_tree().create_timer(6.0).timeout.connect(_terminar)
		"regreso":
			var dir := Vector2(-1.0, 0.25).normalized()
			capsula.position += dir * 220.0 * k * delta
			capsula.rotation = lerp_angle(capsula.rotation, dir.angle() + PI * 0.5, 3.0 * delta)

	if temblor > 0.0:
		temblor -= delta
		raiz.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 4.0 * k
	else:
		raiz.position = Vector2.ZERO
	orbita_atras.queue_redraw()
	orbita_frente.queue_redraw()


# ================= Órbitas (Tierra y Luna) =================

func _alrededor_de_la_luna() -> bool:
	return estado in ["insercion", "orbita_lunar", "alunizaje", "sobrevuelo"]


func _punto(a: float) -> Vector2:
	if _alrededor_de_la_luna():
		return centro_luna + Vector2(cos(a) * rx_luna, sin(a) * ry_luna)
	var p := Vector2(cos(a) * rx_tierra, sin(a) * ry_tierra) * escala_orbita
	return centro_tierra + p.rotated(INCLINACION)


func _mover_en_orbita(avance: float) -> void:
	angulo += avance
	vueltas += avance / TAU
	if estado == "orbita" or estado == "listo":
		lbl_vuelta.text = TranslationServer.translate("VUELTA %d") % (int(vueltas) + 1)
	capsula.position = _punto(angulo)
	# La punta mira hacia donde avanza
	var siguiente := _punto(angulo + 0.05)
	capsula.rotation = (siguiente - capsula.position).angle() + PI * 0.5
	# Detrás del planeta (mitad de arriba de la órbita): más chica y oscura
	var atras := sin(angulo) < 0.0 and escala_orbita < 1.6
	capsula.z_index = -1 if atras else 2
	var prof := 0.82 + 0.18 * (sin(angulo) * 0.5 + 0.5)
	var esc := ALTO_CAPSULA * k / capsula.texture.get_size().y * prof
	capsula.scale = Vector2(esc, esc)
	capsula.modulate = Color(prof, prof, prof + 0.05)


func _dibujar_halo(nodo: Node2D) -> void:
	# Coordenadas de la imagen de la Tierra (48 px), se agranda junto con ella
	for i in 6:
		nodo.draw_circle(Vector2.ZERO, 24.0 + (6 - i) * 0.85, Color(0.45, 0.75, 1.0, 0.035 * (i + 1)))


func _dibujar_orbita(atras: bool) -> void:
	var visible_orbita := estado == "orbita" or estado == "listo" or _alrededor_de_la_luna()
	if not visible_orbita:
		return
	var nodo := orbita_atras if atras else orbita_frente
	var color := Color(0.6, 0.9, 1.0) if not _alrededor_de_la_luna() else Color(0.85, 0.9, 1.0)
	color.a = 0.35 if atras else 0.7
	var n := 90
	for i in n:
		if i % 2 == 1:
			continue
		var a := TAU * i / n
		if (sin(a) < 0.0) != atras:
			continue
		nodo.draw_line(_punto(a), _punto(a + TAU / n), color, 2.0 * k)


# ================= Escape =================

func _listo_para_escapar() -> void:
	estado = "listo"


func _iniciar_escape() -> void:
	estado = "escape"
	fuego.emitting = true
	temblor = 3.0
	lbl_titulo.text = "¡INYECCIÓN DE ESCAPE!"
	lbl_titulo.add_theme_color_override("font_color", Color("ffb37a"))
	lbl_vuelta.text = "MOTORES AL 100%"
	_texto_centro("¡MOTORES ENCENDIDOS!", Color("ffb37a"))
	decir(LINEAS_ESCAPE)


# ================= Acercamiento a la Luna =================

func _iniciar_acercamiento() -> void:
	# Viaje de 3 días en primera persona (si existe la escena)
	if ResourceLoader.exists(ESCENA_VIAJE):
		_ir_al_viaje()
		return
	estado = "acercamiento"
	escala_orbita = 1.0
	capsula_inicio = capsula.position
	capsula.z_index = 2
	capsula.modulate = Color.WHITE
	lbl_titulo.text = "RUMBO A LA LUNA"
	lbl_titulo.add_theme_color_override("font_color", Color("8fd3e8"))
	lbl_vuelta.text = String(Mision.NAVES[id_nave].nombre)
	get_tree().create_timer(2.0).timeout.connect(func(): fuego.emitting = false)
	cola.append_array(LINEAS_ACERCAMIENTO)


func _ir_al_viaje() -> void:
	estado = "al_viaje"
	await RenderingServer.frame_post_draw
	Mision.captura = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	get_tree().change_scene_to_file(ESCENA_VIAJE)


func _preparar_llegada() -> void:
	estado = "acercamiento"
	escala_orbita = 1.0
	t_acercamiento = DURACION_ACERCAMIENTO * 0.65
	capsula_inicio = Vector2(-60.0 * k, pantalla.y * 0.3)
	capsula.z_index = 2
	lbl_titulo.text = "LLEGANDO A LA LUNA"
	lbl_vuelta.text = String(Mision.NAVES[id_nave].nombre)
	_animar_acercamiento(t_acercamiento / DURACION_ACERCAMIENTO)
	decir(["¡Después de 3 días de viaje, ya estamos llegando a la Luna!"])


func _animar_acercamiento(t: float) -> void:
	t = clamp(t, 0.0, 1.0)
	var s := t * t * (3.0 - 2.0 * t)   # suave al inicio y al final
	# La Tierra se aleja y se hace chiquita
	centro_tierra = tierra_inicio.lerp(Vector2(pantalla.x * 0.07, pantalla.y * 0.72), s)
	tierra.position = centro_tierra
	tierra.scale = Vector2.ONE * lerp(TAMANO_TIERRA, 1.3, s) * k
	# La Luna se acerca y crece
	luna.position = luna_inicio.lerp(centro_luna, s)
	luna.scale = Vector2.ONE * lerp(1.6, TAMANO_LUNA, s * s) * k
	# La cápsula va hacia el lado izquierdo de la Luna
	var fin := centro_luna + Vector2(-rx_luna, 0)
	var control := Vector2(pantalla.x * 0.45, pantalla.y * 0.1)
	var p := _bezier(capsula_inicio, control, fin, s)
	var adelante := _bezier(capsula_inicio, control, fin, min(s + 0.02, 1.0))
	capsula.position = p
	if adelante.distance_to(p) > 0.5:
		capsula.rotation = lerp_angle(capsula.rotation, (adelante - p).angle() + PI * 0.5, 0.2)
	var esc := ALTO_CAPSULA * k / capsula.texture.get_size().y
	capsula.scale = Vector2(esc, esc)
	lbl_velocidad.text = TranslationServer.translate("DISTANCIA A LA LUNA: %s km") % _miles(DISTANCIA_KM * (1.0 - s))


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _llegar_a_la_luna() -> void:
	angulo = PI
	lbl_velocidad.text = "DISTANCIA A LA LUNA: 0 km"
	# Bitácora: las naves que no bajan a la superficie la desbloquean al llegar
	if id_nave != "apollo11":
		_desbloquear_luna()
	if id_nave == "artemis2":
		estado = "sobrevuelo"
		lbl_titulo.text = "SOBREVUELO LUNAR"
		_texto_centro("¡LLEGAMOS A LA LUNA!", Color("f5c542"))
		decir(LINEAS_ARTEMIS)
		return
	estado = "insercion"
	lbl_titulo.text = "INSERCIÓN EN ÓRBITA LUNAR"
	_texto_centro("¡FRENANDO!", Color("ffb37a"))
	decir(LINEAS_INSERCION, _fin_explicacion_orbita)
	# Gira la nave al revés y enciende el motor para frenar
	var t := create_tween()
	t.tween_property(capsula, "rotation", capsula.rotation + PI, 1.2)
	t.tween_callback(func(): fuego.emitting = true)
	t.tween_callback(func(): temblor = 2.0)
	t.tween_interval(2.2)
	t.tween_callback(func(): fuego.emitting = false)
	t.tween_callback(_entrar_en_orbita_lunar)


func _entrar_en_orbita_lunar() -> void:
	estado = "orbita_lunar"
	lbl_titulo.text = "ÓRBITA LUNAR"


func _fin_explicacion_orbita() -> void:
	if id_nave == "apollo11":
		decir(LINEAS_APOLLO, func(): listo_modulo = true)
	elif _toca_alunizaje():
		# Otras naves que alunizan: después de entrar en órbita, directo al minijuego
		decir(LINEAS_A_ALUNIZAR, _ir_al_alunizaje)
	else:
		decir(LINEAS_GEMINI)
		get_tree().create_timer(12.0).timeout.connect(_terminar)


# ================= Alunizaje (Apollo 11) =================

func _soltar_modulo() -> void:
	estado = "alunizaje"
	lbl_titulo.text = "DESCENSO A LA SUPERFICIE"
	modulo = Sprite2D.new()
	modulo.texture = _cargar(MODULO_LUNAR)
	modulo.scale = Vector2.ONE * (34.0 * k / modulo.texture.get_size().y)
	modulo.position = capsula.position
	modulo.z_index = 3
	raiz.add_child(modulo)
	var destino := centro_luna + Vector2(-radio_luna * 0.05, -radio_luna * 0.96) - Vector2(0, 17.0 * k)
	var t := create_tween()
	t.tween_property(modulo, "position", destino + Vector2(0, -60.0 * k), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _toca_alunizaje():
		# El módulo se separa y empieza a bajar... y el jugador toma el control
		decir(LINEAS_A_ALUNIZAR)
		t.tween_callback(_ir_al_alunizaje)
		return
	t.tween_property(modulo, "position", destino, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(_alunizar.bind(destino))


## ¿Esta nave pasa al minijuego de alunizaje?
func _toca_alunizaje() -> bool:
	if not (id_nave in NAVES_CON_ALUNIZAJE):
		print("[orbita] La nave '%s' no está en NAVES_CON_ALUNIZAJE: termina sin minijuego." % id_nave)
		return false
	if not ResourceLoader.exists(ESCENA_ALUNIZAJE):
		push_error("[orbita] No encuentro la escena del alunizaje: %s  <- revisa ESCENA_ALUNIZAJE" % ESCENA_ALUNIZAJE)
		return false
	return true


## Fundido a negro (sin detener la animación) y cambio a la escena del alunizaje
func _ir_al_alunizaje() -> void:
	if yendo_a_alunizaje:
		return
	yendo_a_alunizaje = true
	print("[orbita] Pasando al minijuego de alunizaje: ", ESCENA_ALUNIZAJE)
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.size = pantalla
	negro.modulate.a = 0.0
	negro.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(negro)
	var t := create_tween()
	t.tween_interval(1.5)   # deja ver un momento la animación
	t.tween_property(negro, "modulate:a", 1.0, 1.0)
	t.tween_callback(_cambiar_al_alunizaje)


func _cambiar_al_alunizaje() -> void:
	var error := get_tree().change_scene_to_file(ESCENA_ALUNIZAJE)
	if error != OK:
		push_error("No se pudo abrir %s (error %d)" % [ESCENA_ALUNIZAJE, error])


func _alunizar(destino: Vector2) -> void:
	var polvo := CPUParticles2D.new()
	polvo.one_shot = true
	polvo.explosiveness = 0.9
	polvo.amount = 40
	polvo.lifetime = 1.2
	polvo.direction = Vector2(0, -1)
	polvo.spread = 80.0
	polvo.gravity = Vector2(0, 40.0 * k)
	polvo.initial_velocity_min = 30.0 * k
	polvo.initial_velocity_max = 70.0 * k
	polvo.scale_amount_min = 2.0 * k
	polvo.scale_amount_max = 4.0 * k
	polvo.color = Color(0.8, 0.8, 0.8, 0.8)
	polvo.position = destino + Vector2(0, 16.0 * k)
	polvo.z_index = 4
	raiz.add_child(polvo)
	polvo.emitting = true
	temblor = 0.4
	lbl_titulo.text = "¡ALUNIZAJE!"
	_texto_centro("¡EL ÁGUILA HA ALUNIZADO!", Color("f5c542"))
	_desbloquear_luna()   # Bitácora: alunizaje del Apollo 11
	decir(LINEAS_ALUNIZAJE)
	get_tree().create_timer(12.0).timeout.connect(_terminar)


func _desbloquear_luna() -> void:
	var bitacora = get_node_or_null("/root/Bitacora")
	if bitacora:
		bitacora.desbloquear_entrada("lunar_craters")


func _terminar() -> void:
	if estado == "fin":
		return
	estado = "fin"
	_mostrar_resultado()


func _crear_fuego() -> void:
	fuego = CPUParticles2D.new()
	fuego.amount = 60
	fuego.lifetime = 0.6
	fuego.local_coords = false
	fuego.emitting = false
	fuego.direction = Vector2(0, 1)
	fuego.spread = 14.0
	fuego.gravity = Vector2.ZERO
	fuego.initial_velocity_min = 90.0 * k
	fuego.initial_velocity_max = 160.0 * k
	fuego.scale_amount_min = 2.0 * k
	fuego.scale_amount_max = 5.0 * k
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.2, 0.85), Color(0.6, 0.3, 0.6, 0)])
	fuego.color_ramp = g
	fuego.position = Vector2(0, capsula.texture.get_size().y * 0.5)
	capsula.add_child(fuego)


func _crear_hud() -> void:
	capa_hud = CanvasLayer.new()
	add_child(capa_hud)
	lbl_titulo = _etiqueta(24, Color("8fd3e8"))
	lbl_titulo.text = "ÓRBITA TERRESTRE"
	lbl_titulo.position = Vector2(18, 12) * k
	capa_hud.add_child(lbl_titulo)
	lbl_velocidad = _etiqueta(16, Color.WHITE)
	lbl_velocidad.text = "VELOCIDAD: 27,600 km/h"
	lbl_velocidad.position = Vector2(18, 46) * k
	capa_hud.add_child(lbl_velocidad)
	lbl_vuelta = _etiqueta(16, Color("f5c542"))
	lbl_vuelta.position = Vector2(18, 70) * k
	capa_hud.add_child(lbl_vuelta)
	var nave := _etiqueta(14, Color("c9d3ff"))
	nave.text = String(Mision.NAVES[id_nave].nombre)
	nave.position = Vector2(18, 94) * k
	capa_hud.add_child(nave)

	lbl_centro = _etiqueta(44, Color.WHITE)
	lbl_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_centro.size = Vector2(pantalla.x, 70 * k)
	lbl_centro.position = Vector2(0, pantalla.y * 0.06)
	lbl_centro.modulate.a = 0.0
	capa_hud.add_child(lbl_centro)


# ================= Utilidades, diálogo y resultado =================

func _cargar(ruta: String) -> Texture2D:
	var t: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	if t == null:
		push_error("No encuentro la imagen: " + ruta)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	return t


func _crear_capa(archivo: String, velocidad: float, tile: int) -> void:
	var capa := TextureRect.new()
	capa.texture = _cargar(RUTA + "fondos/" + archivo)
	capa.stretch_mode = TextureRect.STRETCH_TILE
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = -10
	add_child(capa)
	move_child(capa, capas.size())   # detrás de todo lo demás
	capa.size = pantalla + Vector2(tile, tile)
	capas.append({"nodo": capa, "vel": velocidad, "tile": tile, "d": 0.0})


func _etiqueta(tamano: float, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", int(tamano * k))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b0f24"))
	l.add_theme_constant_override("outline_size", int(6 * k))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _texto_centro(texto: String, color: Color) -> void:
	lbl_centro.text = texto
	lbl_centro.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(lbl_centro, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.0)
	t.tween_property(lbl_centro, "modulate:a", 0.0, 0.6)


func _miles(v: float) -> String:
	var s := str(int(v))
	return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3)




func _crear_dialogo() -> void:
	tex_normal = _cargar("res://assets/personajes/astronauta.png")
	tex_hablando = _cargar("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = _cargar("res://assets/personajes/astronauta_parpadeo.png")

	var caja := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.06, 0.15, 0.88)
	estilo.border_color = Color("6a76a8")
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(6 * k))
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.position = Vector2(14 * k, pantalla.y - 112 * k)
	caja.custom_minimum_size = Vector2(620 * k, 98 * k)
	capa_hud.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(8 * k))
	caja.add_child(fila)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(78 * k, 70 * k)
	hueco.clip_contents = true
	fila.add_child(hueco)
	retrato = TextureRect.new()
	retrato.texture = tex_normal
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hueco.add_child(retrato)
	retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(col)
	var nombre := _etiqueta(13, Color("f5c542"))
	nombre.text = "ALBERTSAHUR"
	col.add_child(nombre)
	lbl_dialogo = _etiqueta(15, Color("f4eefc"))
	lbl_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_dialogo.custom_minimum_size.x = 500 * k
	col.add_child(lbl_dialogo)


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
	lbl_dialogo.visible_characters = 0
	letras = 0.0
	espera = 2.0 + lbl_dialogo.text.length() * 0.03


func _actualizar_dialogo(delta: float) -> void:
	var total := lbl_dialogo.get_total_character_count()
	if lbl_dialogo.visible_characters < total:
		letras = min(letras + 45.0 * delta, total)
		lbl_dialogo.visible_characters = int(letras)
		reloj_boca += delta
		if reloj_boca >= 0.11:
			reloj_boca = 0.0
			boca_abierta = not boca_abierta
		retrato.texture = tex_hablando if boca_abierta else tex_normal
		var salto: float = round(abs(sin(tiempo * 14.0)) * 2.0 * k)
		retrato.offset_top = -salto
		retrato.offset_bottom = -salto
	else:
		retrato.offset_top = 0
		retrato.offset_bottom = 0
		parpadeo -= delta
		if parpadeo <= 0.0:
			retrato.texture = tex_parpadeo
			if parpadeo <= -0.12:
				parpadeo = randf_range(2.0, 4.5)
		else:
			retrato.texture = tex_normal
		if total > 0 and (not cola.is_empty() or al_terminar.is_valid()):
			espera -= delta
			if espera <= 0.0:
				_siguiente_linea()


func _input(event: InputEvent) -> void:
	# Clic o Espacio: adelanta el texto de Albertsahur
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and estado != "fin"):
		if lbl_dialogo.visible_characters < lbl_dialogo.get_total_character_count():
			letras = lbl_dialogo.get_total_character_count()
		else:
			espera = 0.0




func _mostrar_resultado() -> void:
	var r: Dictionary = Mision.resultado
	var fondo_panel := ColorRect.new()
	fondo_panel.color = Color(0, 0, 0, 0.55)
	fondo_panel.size = pantalla
	capa_hud.add_child(fondo_panel)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("0b1026")
	estilo.border_color = Color("f5c542")
	estilo.set_border_width_all(max(1, int(3 * k)))
	estilo.set_content_margin_all(int(18 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	capa_hud.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * k))
	panel.add_child(v)
	var titulo := _etiqueta(34, Color("f5c542"))
	titulo.text = "¡MISIÓN CUMPLIDA!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var info := _etiqueta(16, Color("f4eefc"))
	if r.is_empty():
		info.text = "Escapamos de la gravedad de la Tierra."
	else:
		info.text = TranslationServer.translate("Nave: %s\nResistencia restante: %d / %d   (+%d)\nGolpes recibidos: %d  |  Escudos recogidos: %d\nAltitud máxima: %s km\nDatos científicos: %d\nPresupuesto sin usar: %s   (+%d)") % [
			r.nave, r.vida, r.vida_max, r.bono_vida, r.golpes, r.escudos, r.altitud,
			r.datos, Mision.dinero(Mision.presupuesto_restante), r.bono_dinero]
	if not Mision.viaje.is_empty():
		info.text += TranslationServer.translate("\nViaje a la Luna: %d de %d fallas resueltas") % [int(Mision.viaje.resueltas), int(Mision.viaje.total)]
	v.add_child(info)
	if not r.is_empty():
		var puntaje := _etiqueta(28, Color("f5c542"))
		puntaje.text = TranslationServer.translate("PUNTAJE: %d") % int(r.puntaje)
		puntaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(puntaje)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", int(10 * k))
	v.add_child(botones)
	if ESCENA_SIGUIENTE != "" and ResourceLoader.exists(ESCENA_SIGUIENTE):
		botones.add_child(_boton("CONTINUAR", ESCENA_SIGUIENTE))
	botones.add_child(_boton("TALLER", ESCENA_TALLER))
	botones.add_child(_boton("CAMBIAR NAVE", ESCENA_SELECCION))
	botones.add_child(_boton("MENÚ", ESCENA_MENU))

	await get_tree().process_frame
	panel.position = (pantalla - panel.size) * 0.5


func _boton(texto: String, ruta: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_override("font", fuente)
	b.add_theme_font_size_override("font_size", int(15 * k))
	b.custom_minimum_size = Vector2(0, 36 * k)
	b.pressed.connect(_ir_a.bind(ruta))
	return b


func _ir_a(ruta: String) -> void:
	if ResourceLoader.exists(ruta):
		get_tree().change_scene_to_file(ruta)
	else:
		push_warning("No existe " + ruta)
