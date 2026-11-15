extends Control
## VIAJE TIERRA-LUNA EN PRIMERA PERSONA (3 días)
## Vamos dentro de la cabina. La barra de arriba muestra el progreso del viaje.
## En ciertos momentos aparece una falla (minijuego). Cada nave tiene sus
## propias desventajas: qué fallas le tocan y qué tan difíciles son.
## Albertsahur explica todo abajo a la izquierda.
## Al terminar, se regresa a la escena de la órbita para llegar a la Luna.
##
## Eventos: entre 3 y 5 al azar (asteroides, oxígeno o eléctrico), repartidos
## en bloques de tiempo iguales y sin repetir el mismo dos veces seguidas.
## Al final del viaje SIEMPRE llega una tormenta solar (escena con Albertsahur
## y el refugio). Al pasar, se desbloquea "Solar Flares" en la bitácora.
## Los minijuegos están dentro de este mismo archivo (clases MinijuegoAsteroides
## MinijuegoOxigeno y MinijuegoElectrico, hasta abajo), así que no necesitan ningún otro script.

# ---------- Cosas que puedes cambiar fácilmente ----------
const CABINA := "res://assets/viaje/cabina.jpg"
const CABINA_ASTRONAUTA := "res://assets/viaje/cabina_astronauta.jpg"
const REFUGIO := "res://assets/viaje/refugio_limpio.jpg"        # 3 cuadros: salir del refugio (sin letreros)
const ESCONDERSE := "res://assets/viaje/esconderse_limpio.jpg"  # 3 cuadros: esconderse en el refugio (sin letreros)
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const ESCENA_SIGUIENTE := "res://scenes/orbita.tscn"
const ESCENA_TALLER := "res://scenes/taller.tscn"
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const DURACION_VIAJE := 80.0      # segundos de viaje sin contar las fallas
const PUNTOS_POR_FALLA := 300

# Eventos aleatorios: cada viaje tiene entre EVENTOS_MIN y EVENTOS_MAX.
# Se reparten en bloques de tiempo iguales (con 4 eventos salen al 20, 40, 60 y 80 %)
# y nunca sale el mismo minijuego dos veces seguidas.
const EVENTOS_DISPONIBLES := ["asteroides", "oxigeno", "electrico"]
const EVENTOS_MIN := 5
const EVENTOS_MAX := 5

# Tormenta solar fija: llega siempre poco antes de llegar a la Luna
const MOMENTO_TORMENTA := 0.93    # 93 % del viaje (después de todas las fallas)
const LINEAS_TORMENTA := [
	"¡Director, alerta del control de misión! El Sol acaba de lanzar una llamarada solar clase X, de las más fuertes que existen.",
	"Detrás viene una eyección de masa coronal: una nube gigante de partículas cargadas que va directo hacia nosotros.",
	"Esa radiación daña la electrónica y a la tripulación. ¡Todos al refugio, la zona con más blindaje de la nave! Cerrando escotillas...",
]
const LINEAS_ESCONDIDOS := [
	"Apagamos todo lo que no es indispensable y nos quedamos a oscuras, bien pegados al blindaje.",
	"Shhh... Ahora solo queda esperar a que pase la radiación.",
]
const LINEAS_ALIVIO := [
	"...Uf. Los sensores de radiación ya bajaron. La tormenta pasó.",
	"Salimos del refugio, revisamos los sistemas y todo sigue en orden. ¡Ya casi llegamos a la Luna!",
	"Lo anoté en la bitácora, director. Ábrela en el menú de pausa para saber más de las llamaradas solares.",
]

const INTRO := [
	"Ya vamos rumbo a la Luna, director. Son unos 3 días de viaje, casi todo con los motores apagados.",
	"Desde la cabina vigilamos el oxígeno, el combustible y el casco. Si algo falla, hay que arreglarlo rápido.",
]
const DESVENTAJAS := {
	"gemini4": "Ojo: la Gemini IV es pequeña y vieja. Sus válvulas fallan seguido y los propulsores responden con un poco de retraso.",
	"apollo11": "Ojo: la computadora del Apollo tiene muy poca memoria. Si recibe demasiados datos se satura... como en la famosa alarma 1202.",
	"artemis2": "Artemis es muy confiable, pero la radiación del espacio profundo altera su computadora. Y si algo llega a fallar, falla todo junto.",
}
const DIAS := {
	2: "Día 2. La Tierra ya se ve chiquita por la ventana. Seguimos en silencio rumbo a la Luna.",
	3: "Día 3. ¡La Luna se ve cada vez más grande! Ya casi llegamos.",
}
# Lo que dice Albertsahur al empezar cada falla
const AVISOS := {
	"valvulas": [
		"¡Falla en las válvulas de oxígeno! En el Apollo 13 un tanque de oxígeno explotó camino a la Luna.",
		"Elige una válvula (1, 2 o 3) y gira el regulador con A/D o arrastrando el mouse hasta que la aguja quede en verde.",
	],
	"asteroides": [
		"¡Basura espacial en la ruta! Un pedacito del tamaño de una tuerca puede atravesar el casco.",
		"La NASA hace maniobras de evasión con impulsos cortos. Muévete con las flechas, pero cada movimiento gasta combustible.",
	],
	"tormenta": [
		"¡Tormenta solar! El Sol lanzó una eyección de masa coronal: radiación que daña la electrónica y a la tripulación.",
		"Baja la palanca del escudo de plomo y mantén presionado DEPLOY para cerrar las ventanas.",
	],
	"computadora": [
		"¡Alarma 1202! En el Apollo 11 la computadora se saturó durante el descenso a la Luna.",
		"Por suerte sabía descartar lo menos importante. Elimina los procesos basura (ámbar), ¡pero no toques los vitales (verdes)!",
	],
	"oxigeno": [
		"¡Falla crítica de oxígeno! La válvula principal se atascó. En el Apollo 13 un tanque de oxígeno explotó camino a la Luna.",
		"Abre las 3 válvulas auxiliares: mantén presionada cada una hasta que su círculo se llene de verde. ¡Mientras tardes, perdemos oxígeno!",
	],
	"electrico": [
		"¡Falla en la distribución eléctrica! Si se cae la energía, se apaga el soporte de vida.",
		"Enciende todos los switches de la matriz. Mientras haya apagados se gastan las baterías... ¡y algunos se van a botar solos!",
	],
	"antena": [
		"Perdimos la señal con la Tierra. Mientras más nos alejamos, más débil llega.",
		"La NASA usa la Red del Espacio Profundo para hablar con las naves. Ajusta la onda verde con W/S y A/D hasta que quede sobre la azul.",
	],
}
const BIEN := {
	"valvulas": "¡Válvulas estables! El oxígeno vuelve a subir.",
	"asteroides": "¡Esquivamos todo! Ni un rasguño en el casco.",
	"tormenta": "¡Escudo cerrado! Nos refugiamos hasta que pase la tormenta.",
	"computadora": "¡CPU bajo control! La computadora vuelve a guiarnos.",
	"oxigeno": "¡Válvulas abiertas! El oxígeno vuelve a fluir a la cabina.",
	"electrico": "¡Energía restaurada! Todos los sistemas vuelven a estar en línea.",
	"antena": "¡Enlace restablecido! Ya estamos mandando datos a la Tierra otra vez.",
}
const MAL := {
	"asteroides": "Nos pegaron algunas rocas. El casco quedó al %d%%.",
	"tormenta": "¡La radiación nos alcanzó! Se alteraron los monitores y perdimos datos científicos.",
	"computadora": "La computadora nos desvió de la ruta. Gastamos combustible para corregir y retrasamos el viaje.",
	"oxigeno": "No abrimos todas las válvulas a tiempo y perdimos mucho oxígeno. ¡Hay que tener cuidado!",
	"electrico": "No restauramos toda la energía a tiempo. Las baterías quedaron al %d%%.",
	"antena": "No logramos alinear bien la antena. La señal llega débil: juntaremos menos datos.",
}
# ---------------------------------------------------------

var k := 1.0
var pantalla := Vector2.ZERO
var arriba := 0.0
var fuente: Font
var tiempo := 0.0
var id_nave := "apollo11"

# Recursos de la nave (los minijuegos los cambian)
var oxigeno := 100.0
var combustible := 100.0
var energia := 100.0        # baterías de la nave (no se regenera)
var casco := 100.0
var datos := 0.0
var progreso := 0.0
var mult_oxigeno := 1.0     # energía: qué tan rápido se pierde oxígeno
var dano_casco := 30.0      # cap. de masa: daño por roca
var casco_reforzado := false
var tasa_datos := 10.0      # ciencia: datos por segundo
var factor_antena := 1.0

var estado := "intro"       # intro, viajando, alerta, minijuego, pausa, escena, llegando, fallo
var eventos := []
var indice_evento := 0
var resueltas := 0
var total_fallas := 0
var dia := 1
var temblor := 0.0
var glitch := 0.0
var tormenta_hecha := false

var cabina: Control
var hud: Control
var capa_minijuegos: Control
var vineta: Control
var capa_efectos: Control
var lbl_centro: Label
var tex_tierra: Texture2D
var tex_luna: Texture2D

# Diálogo
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
	k = pantalla.x / 1024.0
	arriba = (pantalla.y - 576.0 * k) * 0.5
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font
	id_nave = Mision.nave_elegida if Mision.NAVES.has(Mision.nave_elegida) else "apollo11"

	# --- Lo que hacen las mejoras del taller en el viaje ---
	combustible = clamp(50.0 + Mision.valor(id_nave, "propulsion") * 0.5, 0.0, 100.0)
	energia = clamp(40.0 + Mision.valor(id_nave, "energia") * 0.6, 0.0, 100.0)
	mult_oxigeno = 1.3 - Mision.valor(id_nave, "energia") / 200.0
	casco_reforzado = Mision.valor(id_nave, "masa") >= 70
	dano_casco = 20.0 if casco_reforzado else 30.0
	tasa_datos = Mision.datos_por_capa(id_nave) / 40.0

	# --- Eventos aleatorios de este viaje ---
	_sortear_eventos()

	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.size = pantalla
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(negro)

	# --- Cabina (todo lo que usa coordenadas de la imagen) ---
	cabina = Control.new()
	cabina.position = Vector2(0, arriba)
	cabina.size = Vector2(1024, 576) * k
	cabina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cabina)
	var fondo := TextureRect.new()
	fondo.texture = _cargar(CABINA)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.size = cabina.size
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabina.add_child(fondo)

	tex_tierra = _cargar("res://assets/espacio/planetas/planet-terran.png")
	tex_luna = _cargar("res://assets/espacio/planetas/planet-moon.png")
	hud = Control.new()
	hud.size = cabina.size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_dibujar_hud)
	cabina.add_child(hud)

	capa_minijuegos = Control.new()
	capa_minijuegos.size = cabina.size
	capa_minijuegos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabina.add_child(capa_minijuegos)

	vineta = Control.new()
	vineta.size = cabina.size
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.draw.connect(_dibujar_vineta)
	cabina.add_child(vineta)

	capa_efectos = Control.new()
	capa_efectos.size = cabina.size
	capa_efectos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_efectos.draw.connect(_dibujar_glitch)
	cabina.add_child(capa_efectos)

	_crear_textos()
	_crear_dialogo()
	_intro()
	_transicion_de_entrada()


## Elige entre EVENTOS_MIN y EVENTOS_MAX eventos, repartidos en bloques iguales
## y sin repetir el mismo minijuego dos veces seguidas.
func _sortear_eventos() -> void:
	eventos.clear()
	var cantidad := randi_range(EVENTOS_MIN, EVENTOS_MAX)
	var anterior := ""
	for i in cantidad:
		var opciones: Array = EVENTOS_DISPONIBLES.duplicate()
		opciones.erase(anterior)
		var tipo: String = opciones.pick_random()
		var momento := float(i + 1) / float(cantidad + 1)
		eventos.append([momento, tipo])
		anterior = tipo
	print("Eventos de este viaje: ", eventos)


func _cargar(ruta: String) -> Texture2D:
	var t: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	if t == null:
		push_error("No encuentro la imagen: " + ruta)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	return t


func _transicion_de_entrada() -> void:
	if Mision.captura != null:
		var capa := CanvasLayer.new()
		capa.layer = 20
		add_child(capa)
		var foto := TextureRect.new()
		foto.texture = Mision.captura
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_SCALE
		foto.size = pantalla
		capa.add_child(foto)
		Mision.captura = null
		var t := create_tween()
		t.tween_property(foto, "modulate:a", 0.0, 1.5)
		t.tween_callback(capa.queue_free)
	else:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.0)


func sacudir(segundos: float) -> void:
	temblor = max(temblor, segundos)


# ================= Intro: el astronauta en su asiento =================

func _intro() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 8
	add_child(capa)
	var foto := TextureRect.new()
	foto.texture = _cargar(CABINA_ASTRONAUTA)
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.size = pantalla
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(foto)
	var titulo := _etiqueta(46, Color("f5c542"))
	titulo.text = "DÍA 1"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size = Vector2(pantalla.x, 60 * k)
	titulo.position = Vector2(0, pantalla.y * 0.08)
	foto.add_child(titulo)
	var sub := _etiqueta(20, Color("8fd3e8"))
	sub.text = "RUMBO A LA LUNA"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(pantalla.x, 30 * k)
	sub.position = Vector2(0, pantalla.y * 0.08 + 56 * k)
	foto.add_child(sub)
	var t := create_tween()
	t.tween_interval(5.5)
	t.tween_property(foto, "modulate:a", 0.0, 1.5)
	t.tween_callback(capa.queue_free)

	var lineas: Array = INTRO.duplicate()
	lineas.append(DESVENTAJAS.get(id_nave, ""))
	decir(lineas, _empezar_viaje)


func _empezar_viaje() -> void:
	if estado == "intro":
		estado = "viajando"


# ================= Ciclo principal =================

func _process(delta: float) -> void:
	tiempo += delta
	_actualizar_dialogo(delta)

	if estado == "viajando":
		progreso = min(progreso + delta / DURACION_VIAJE, 1.0)
		datos += tasa_datos * factor_antena * delta
		var d: int = clamp(1 + int(progreso * 3.0), 1, 3)
		if d > dia:
			dia = d
			_texto_centro(TranslationServer.translate("DÍA %d") % d, Color("f5c542"))
			decir([DIAS.get(d, "")])
		if indice_evento < eventos.size() and progreso >= float(eventos[indice_evento][0]):
			var tipo: String = eventos[indice_evento][1]
			indice_evento += 1
			_alerta(tipo)
		elif not tormenta_hecha and progreso >= MOMENTO_TORMENTA:
			_tormenta_solar()
		elif progreso >= 1.0:
			_llegar()
	elif estado == "minijuego" and _minijuego_actual() == "":
		estado = "pausa"   # por si un minijuego se cerró solo

	if temblor > 0.0:
		temblor -= delta
		cabina.position = Vector2(0, arriba) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * k
	else:
		cabina.position = Vector2(0, arriba)
	glitch = max(glitch - delta, 0.0)

	hud.queue_redraw()
	vineta.queue_redraw()
	capa_efectos.queue_redraw()


func _minijuego_actual() -> String:
	return "si" if capa_minijuegos.get_child_count() > 0 else ""


# ================= Fallas (minijuegos) =================

func _alerta(tipo: String) -> void:
	estado = "alerta"
	total_fallas += 1
	sacudir(0.5)
	_texto_centro("¡ALERTA!", Color("ff4a3d"))
	if tipo == "antena":
		factor_antena = 0.0   # sin señal no se juntan datos
	decir(AVISOS.get(tipo, []))
	get_tree().create_timer(1.8).timeout.connect(_iniciar_minijuego.bind(tipo))


func _iniciar_minijuego(tipo: String) -> void:
	if estado == "fallo":
		return
	var mj
	match tipo:
		"asteroides":
			mj = MinijuegoAsteroides.new()
		"electrico":
			mj = MinijuegoElectrico.new()
		"oxigeno":
			mj = MinijuegoOxigeno.new()
		_:
			push_warning("El minijuego '%s' todavía no está integrado" % tipo)
			estado = "viajando"
			return
	estado = "minijuego"
	mj.configurar(self, k, fuente, id_nave)
	mj.terminado.connect(_fin_minijuego.bind(tipo))
	capa_minijuegos.add_child(mj)


func _fin_minijuego(exito: bool, tipo: String) -> void:
	if estado == "fallo":
		return
	if exito:
		resueltas += 1
		_texto_centro("¡RESUELTO!", Color("5ee36a"))
	match tipo:
		"valvulas":
			if not exito:
				_fallar("Nos quedamos sin oxígeno.")
				return
		"asteroides":
			if casco <= 0.0:
				_fallar("El casco no aguantó los impactos.")
				return
		"tormenta":
			# Bitácora: sobrevivimos (o sufrimos) la tormenta solar
			var bitacora = get_node_or_null("/root/Bitacora")
			if bitacora:
				bitacora.desbloquear_entrada("solar_flares")
			if not exito:
				datos *= 0.7
				glitch = 2.5
				sacudir(0.6)
		"computadora":
			if not exito:
				progreso = max(progreso - 0.06, 0.0)
				combustible = max(combustible - 10.0, 0.0)
		"antena":
			factor_antena = 1.0 if exito else 0.5
		"oxigeno":
			if not exito or oxigeno <= 0.0:
				_fallar("Nos quedamos sin oxígeno.")
				return
		"electrico":
			if not exito or energia <= 0.0:
				_fallar("Nos quedamos sin energía y se apagaron todos los sistemas.")
				return

	if exito:
		decir([BIEN.get(tipo, "¡Bien hecho!")])
	elif tipo == "asteroides":
		decir([TranslationServer.translate(MAL["asteroides"]) % int(casco)])
	elif tipo == "electrico":
		decir([TranslationServer.translate(MAL["electrico"]) % int(energia)])
	else:
		decir([MAL.get(tipo, "Eso no salió bien, pero seguimos.")])

	if tipo == "tormenta" and exito:
		estado = "escena"
		get_tree().create_timer(1.5).timeout.connect(_entrar_al_refugio)
	else:
		estado = "pausa"
		get_tree().create_timer(2.0).timeout.connect(_reanudar)


func _reanudar() -> void:
	if estado == "pausa":
		estado = "viajando"


## Tormenta solar fija antes de llegar: aviso + Albertsahur + refugio + alivio
func _tormenta_solar() -> void:
	tormenta_hecha = true
	estado = "alerta"          # el marco rojo pulsa mientras explica
	sacudir(0.8)
	glitch = 2.0
	_texto_centro("¡TORMENTA SOLAR!", Color("ffb37a"))
	decir(LINEAS_TORMENTA, _entrar_al_refugio)


func _entrar_al_refugio() -> void:
	if estado == "fallo":
		return
	estado = "escena"
	glitch = 1.5
	sacudir(0.5)
	# 1) Esconderse: los 3 cuadros se van oscureciendo (se queda en negro al final)
	var capa_esconderse := _escena_paneles(ESCONDERSE, true, false)
	decir(LINEAS_ESCONDIDOS, _salir_del_refugio.bind(capa_esconderse))


## 2) Salir del refugio: los 3 cuadros de vuelta a la normalidad + alivio
func _salir_del_refugio(capa_anterior: CanvasLayer) -> void:
	if estado == "fallo":
		return
	_escena_paneles(REFUGIO, false, true)
	if is_instance_valid(capa_anterior):
		capa_anterior.queue_free()
	# Bitácora: ya vivimos una tormenta solar
	var bitacora = get_node_or_null("/root/Bitacora")
	if bitacora:
		bitacora.desbloquear_entrada("solar_flares")
	# Se sigue viajando cuando Albertsahur termina de hablar
	decir(LINEAS_ALIVIO, _reanudar_despues_de_escena)


## Muestra una imagen de 3 cuadros y los va descubriendo uno por uno.
## entrar_con_fade: aparece desde la cabina (si es false, empieza ya en negro).
## salir_con_fade: al final se desvanece y se borra (si es false, se queda en pantalla).
func _escena_paneles(ruta: String, entrar_con_fade: bool, salir_con_fade: bool) -> CanvasLayer:
	var capa := CanvasLayer.new()
	capa.layer = 8
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.size = pantalla
	capa.add_child(fondo)
	var tex := _cargar(ruta)
	var esc: float = min(pantalla.x / tex.get_size().x, pantalla.y / tex.get_size().y)
	var tam := tex.get_size() * esc
	var pos := (pantalla - tam) * 0.5
	var foto := TextureRect.new()
	foto.texture = tex
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_SCALE
	foto.position = pos
	foto.size = tam
	fondo.add_child(foto)
	# Tapas negras que se van quitando cuadro por cuadro
	var t := create_tween()
	if entrar_con_fade:
		fondo.modulate.a = 0.0
		t.tween_property(fondo, "modulate:a", 1.0, 0.6)
	for i in 3:
		var tapa := ColorRect.new()
		tapa.color = Color.BLACK
		tapa.position = pos + Vector2(tam.x * i / 3.0, 0)
		tapa.size = Vector2(tam.x / 3.0 + 2, tam.y)
		fondo.add_child(tapa)
		t.tween_property(tapa, "modulate:a", 0.0, 0.8)
		t.tween_interval(0.8)
	if salir_con_fade:
		t.tween_interval(2.0)
		t.tween_property(fondo, "modulate:a", 0.0, 0.8)
		t.tween_callback(capa.queue_free)
	return capa


func _reanudar_despues_de_escena() -> void:
	if estado == "escena":
		estado = "viajando"


# ================= Llegada y fallo =================

func _llegar() -> void:
	estado = "llegando"
	_texto_centro("¡LLEGAMOS!", Color("f5c542"))
	decir(["¡Ya vemos la Luna enorme por la ventana! Prepárate para la maniobra de llegada."])
	get_tree().create_timer(4.5).timeout.connect(_ir_a_la_luna)


func _ir_a_la_luna() -> void:
	Mision.viaje = {"datos": int(datos), "resueltas": resueltas, "total": total_fallas}
	if not Mision.resultado.is_empty():
		Mision.resultado["datos"] = int(Mision.resultado.get("datos", 0)) + int(datos)
		Mision.resultado["puntaje"] = int(Mision.resultado.get("puntaje", 0)) + int(datos) + resueltas * PUNTOS_POR_FALLA
	Mision.fase_orbita = "llegada"
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		await RenderingServer.frame_post_draw
		Mision.captura = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
	else:
		push_error("No existe " + ESCENA_SIGUIENTE)


func _fallar(razon: String) -> void:
	estado = "fallo"
	for mj in capa_minijuegos.get_children():
		mj.queue_free()
	sacudir(0.8)
	_texto_centro("MISIÓN FALLIDA", Color("ff4a3d"))
	decir([TranslationServer.translate(razon) + TranslationServer.translate(" Revisemos el diseño de la nave e intentémoslo otra vez.")])
	get_tree().create_timer(2.5).timeout.connect(_panel_fallo.bind(razon))


func _panel_fallo(razon: String) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.size = pantalla
	capa.add_child(fondo)
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("0b1026")
	estilo.border_color = Color("ff5a5a")
	estilo.set_border_width_all(max(1, int(3 * k)))
	estilo.set_content_margin_all(int(18 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	capa.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * k))
	panel.add_child(v)
	var titulo := _etiqueta(32, Color("ff5a5a"))
	titulo.text = "MISIÓN FALLIDA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var info := _etiqueta(16, Color("f4eefc"))
	info.text = TranslationServer.translate("%s\nDía %d del viaje  |  Fallas resueltas: %d de %d") % [razon, dia, resueltas, total_fallas]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", int(10 * k))
	v.add_child(botones)
	botones.add_child(_boton("REINTENTAR VIAJE", ""))
	botones.add_child(_boton("TALLER", ESCENA_TALLER))
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
	if ruta == "":
		get_tree().reload_current_scene()
	elif ResourceLoader.exists(ruta):
		get_tree().change_scene_to_file(ruta)


# ================= Dibujo del HUD de la cabina =================

func R(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * k, y * k, w * k, h * k)


func P(x: float, y: float) -> Vector2:
	return Vector2(x * k, y * k)


func _texto(nodo: CanvasItem, pos: Vector2, s: String, tam: float, color: Color, ancho: float = -1.0, alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	s = TranslationServer.translate(s)   # el texto dibujado a mano no lo traduce Godot solo
	nodo.draw_string_outline(fuente, pos, s, alineacion, ancho, int(tam * k), int(3 * k), Color(0, 0, 0, 0.85))
	nodo.draw_string(fuente, pos, s, alineacion, ancho, int(tam * k), color)


func _color_nivel(v: float) -> Color:
	if v > 50.0:
		return Color("5ee36a")
	if v > 25.0:
		return Color("ffb347")
	return Color("ff4a3d")


func _dibujar_hud() -> void:
	# --- Barra PROGRESO TIERRA-LUNA ---
	var panel := R(186, 6, 652, 42)
	hud.draw_rect(panel.grow(2 * k), Color("1c1f24"))
	hud.draw_rect(panel, Color("2b3036"))
	_texto(hud, Vector2(panel.position.x, panel.position.y + 15 * k), "PROGRESO TIERRA-LUNA", 10, Color("dfe6ee"), panel.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var barra := R(210, 24, 604, 16)
	hud.draw_rect(barra.grow(1.5 * k), Color("101317"))
	hud.draw_rect(Rect2(barra.position, Vector2(barra.size.x * progreso, barra.size.y)), Color("5ee36a"))
	hud.draw_rect(Rect2(barra.position, Vector2(barra.size.x * progreso, 4 * k)), Color("a6ffad"))
	for i in range(1, 3):
		var x := barra.position.x + barra.size.x * i / 3.0
		hud.draw_line(Vector2(x, barra.position.y - 2 * k), Vector2(x, barra.end.y + 2 * k), Color("dfe6ee"), 1.5 * k)
	hud.draw_texture_rect(tex_tierra, R(168, 10, 36, 36), false)
	hud.draw_texture_rect(tex_luna, R(820, 10, 36, 36), false)

	# --- Línea de estado ---
	var estado_r := R(232, 52, 560, 20)
	hud.draw_rect(estado_r, Color(0.05, 0.06, 0.08, 0.75))
	var linea := TranslationServer.translate("DÍA %d DE 3  |  O2 %d%%  |  FUEL %d%%  |  ENERGÍA %d%%  |  CASCO %d%%  |  DATOS %d") % [dia, int(oxigeno), int(combustible), int(energia), int(casco), int(datos)]
	_texto(hud, Vector2(estado_r.position.x, estado_r.position.y + 15 * k), linea, 10, Color("dfe6ee"), estado_r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# --- Medidores de la pared izquierda (encima de los de la imagen) ---
	var o2 := R(30, 177, 18, 75)
	hud.draw_rect(o2, Color("101317"))
	var alto_o2 := o2.size.y * oxigeno / 100.0
	hud.draw_rect(Rect2(o2.position.x, o2.end.y - alto_o2, o2.size.x, alto_o2), _color_nivel(oxigeno))
	var fu := R(74, 182, 11, 65)
	hud.draw_rect(fu, Color("101317"))
	var alto_fu := fu.size.y * combustible / 100.0
	hud.draw_rect(Rect2(fu.position.x, fu.end.y - alto_fu, fu.size.x, alto_fu), Color("ffb347") if combustible > 20.0 else Color("ff4a3d"))
	# Aguja del reloj FUEL
	var c := P(146, 182)
	hud.draw_circle(c, 21 * k, Color("0d1013"))
	for m in 7:
		var am: float = lerp(deg_to_rad(135.0), deg_to_rad(405.0), m / 6.0)
		hud.draw_line(c + Vector2.from_angle(am) * 15 * k, c + Vector2.from_angle(am) * 19 * k, Color("dfe6ee"), 1.5 * k)
	var ang: float = lerp(deg_to_rad(135.0), deg_to_rad(405.0), combustible / 100.0)
	hud.draw_line(c, c + Vector2.from_angle(ang) * 17 * k, Color("ffffff"), 2.0 * k)
	hud.draw_circle(c, 2.5 * k, Color("ff4a3d"))
	# Barrita de ENERGÍA (sobre la barra naranja debajo del reloj)
	var en := R(126, 228, 48, 11)
	hud.draw_rect(en, Color("101317"))
	hud.draw_rect(Rect2(en.position, Vector2(en.size.x * energia / 100.0, en.size.y)), _color_nivel(energia))
	_texto(hud, P(124, 252), "ENERGÍA", 7, Color("dfe6ee"))


func _dibujar_vineta() -> void:
	# Marco rojo que pulsa mientras hay una falla
	if estado == "alerta" or estado == "minijuego":
		var a := 0.25 + 0.2 * sin(tiempo * 8.0)
		var w := 10.0 * k
		var s := vineta.size
		var c := Color(1, 0.1, 0.05, a)
		vineta.draw_rect(Rect2(0, 0, s.x, w), c)
		vineta.draw_rect(Rect2(0, s.y - w, s.x, w), c)
		vineta.draw_rect(Rect2(0, 0, w, s.y), c)
		vineta.draw_rect(Rect2(s.x - w, 0, w, s.y), c)


func _dibujar_glitch() -> void:
	# "Bit-flip" por radiación: barras de colores que brincan
	if glitch <= 0.0:
		return
	var s := capa_efectos.size
	for i in 14:
		var y := randf() * s.y
		var h := randf_range(2.0, 14.0) * k
		var col := Color(randf(), randf(), randf(), 0.35 * min(glitch, 1.0))
		capa_efectos.draw_rect(Rect2(randf_range(-40, 40) * k, y, s.x, h), col)
	capa_efectos.draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0, 0.8, 0.08 * min(glitch, 1.0)))


# ================= Textos y Albertsahur =================

func _etiqueta(tamano: float, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", int(tamano * k))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b0f24"))
	l.add_theme_constant_override("outline_size", int(6 * k))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_textos() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	lbl_centro = _etiqueta(46, Color.WHITE)
	lbl_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_centro.size = Vector2(pantalla.x, 70 * k)
	lbl_centro.position = Vector2(0, arriba + 92 * k)
	lbl_centro.modulate.a = 0.0
	capa.add_child(lbl_centro)


func _texto_centro(texto: String, color: Color) -> void:
	lbl_centro.text = texto
	lbl_centro.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(lbl_centro, "modulate:a", 1.0, 0.25)
	t.tween_interval(1.4)
	t.tween_property(lbl_centro, "modulate:a", 0.0, 0.5)


func _crear_dialogo() -> void:
	tex_normal = _cargar("res://assets/personajes/astronauta.png")
	tex_hablando = _cargar("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = _cargar("res://assets/personajes/astronauta_parpadeo.png")

	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	var caja := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.06, 0.15, 0.9)
	estilo.border_color = Color("6a76a8")
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(5 * k))
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.position = Vector2(206 * k, arriba + 484 * k)
	caja.custom_minimum_size = Vector2(500 * k, 84 * k)
	caja.size = caja.custom_minimum_size
	capa.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(8 * k))
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(fila)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(70 * k, 64 * k)
	hueco.clip_contents = true
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(hueco)
	retrato = TextureRect.new()
	retrato.texture = tex_normal
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.add_child(retrato)
	retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(1 * k))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(col)
	var nombre := _etiqueta(11, Color("f5c542"))
	nombre.text = "ALBERTSAHUR"
	col.add_child(nombre)
	lbl_dialogo = _etiqueta(13, Color("f4eefc"))
	lbl_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_dialogo.custom_minimum_size.x = 400 * k
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
	espera = 2.2 + lbl_dialogo.text.length() * 0.03


func _actualizar_dialogo(delta: float) -> void:
	var total := lbl_dialogo.get_total_character_count()
	if lbl_dialogo.visible_characters < total:
		letras = min(letras + 50.0 * delta, total)
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


# =====================================================================
# MINIJUEGO: EVASIÓN DE MICROMETEORITOS Y BASURA ORBITAL
# Durante 10 a 15 segundos (al azar) caen rocas por las columnas del radar.
# Una línea punteada marca por dónde pasará cada una. Mueve la nave casilla
# por casilla (flechas, WASD o la cruceta) para esquivarlas. Cada movimiento
# gasta combustible; sin combustible ya no te puedes mover.
# Se dibuja con coordenadas de la imagen de la cabina (1024 x 576).
# =====================================================================
class MinijuegoAsteroides extends Control:
	signal terminado(exito: bool)

	const C_METAL := Color("5d636b")
	const C_METAL_CLARO := Color("8a9099")
	const C_OSCURO := Color("1c1f24")
	const C_ROJO := Color("ff4a3d")
	const C_VERDE := Color("5ee36a")
	const C_AMBAR := Color("ffb347")
	const C_TEXTO := Color("f4eefc")

	var viaje                  # la escena del viaje (oxigeno, combustible, casco, datos...)
	var k := 1.0               # escala: pantalla / 1024
	var fuente: Font
	var nave := "apollo11"
	var tiempo := 0.0
	var acabado := false


	func configurar(escena: Node, escala: float, f: Font, id: String) -> void:
		viaje = escena
		k = escala
		fuente = f
		nave = id


	func _ready() -> void:
		position = Vector2.ZERO
		size = Vector2(1024, 576) * k
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
		iniciar()


	func _process(delta: float) -> void:
		tiempo += delta
		if not acabado:
			actualizar(delta)
		queue_redraw()


	func terminar(exito: bool) -> void:
		if acabado:
			return
		acabado = true
		terminado.emit(exito)
		var t := create_tween()
		t.tween_interval(0.8)
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)


	# ---------- Ayudas para dibujar ----------

	func R(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(x * k, y * k, w * k, h * k)


	func RR(r: Rect2) -> Rect2:
		return Rect2(r.position * k, r.size * k)


	func P(x: float, y: float) -> Vector2:
		return Vector2(x * k, y * k)


	func PV(v: Vector2) -> Vector2:
		return v * k


	## Placa de metal con remaches, como los paneles de la cabina
	func placa(r: Rect2, color: Color = C_METAL) -> void:
		draw_rect(r.grow(3.0 * k), C_OSCURO)
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0 * k)), color.lightened(0.2))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3.0 * k), Vector2(r.size.x, 3.0 * k)), color.darkened(0.25))
		var m := 6.0 * k
		for p in [r.position + Vector2(m, m), r.position + Vector2(r.size.x - m, m),
				r.position + Vector2(m, r.size.y - m), r.end - Vector2(m, m)]:
			draw_circle(p, 2.2 * k, color.darkened(0.4))
			draw_circle(p - Vector2(0.6, 0.6) * k, 1.0 * k, color.lightened(0.3))


	## Pantallita oscura (tipo monitor) con borde
	func pantallita(r: Rect2, fondo: Color = Color("0a0f12")) -> void:
		draw_rect(r.grow(2.0 * k), C_OSCURO)
		draw_rect(r, fondo)


	func texto(pos: Vector2, s: String, tam: float, color: Color, ancho: float = -1.0, alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var t := int(tam * k)
		s = TranslationServer.translate(s)   # el texto dibujado a mano no lo traduce Godot solo
		draw_string_outline(fuente, pos, s, alineacion, ancho, t, int(3 * k), Color(0, 0, 0, 0.8))
		draw_string(fuente, pos, s, alineacion, ancho, t, color)


	func texto_centrado(r: Rect2, y: float, s: String, tam: float, color: Color) -> void:
		texto(Vector2(r.position.x, y), s, tam, color, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


	func marco_parpadeante(r: Rect2, color: Color) -> void:
		var a := 0.45 + 0.45 * sin(tiempo * 9.0)
		var c := color
		c.a = a
		draw_rect(r.grow(4.0 * k), c, false, 3.0 * k)


	func tecla(codigo: Key) -> bool:
		return Input.is_physical_key_pressed(codigo)


	const VENTANA := Rect2(372, 148, 288, 274)
	const REJILLA := Rect2(384, 176, 264, 168)
	const COLS := 7
	const FILAS := 5
	const DURACION_MIN := 10.0    # el minijuego dura entre 10 y 15 segundos
	const DURACION_MAX := 15.0
	const PASO := 0.42            # segundos que tarda una roca en bajar una casilla
	const COSTO_MOVIMIENTO := 2.5 # % de combustible por movimiento
	const CRUCETA := Vector2(520, 384)

	var col := 3
	var fila := 4
	var rocas := []
	var reloj_rocas := 0.5
	var cada := 0.55
	var anticipacion := 1          # casillas de aviso antes de que una roca entre al radar
	var retraso := 0.0             # segundos de retraso de los controles
	var pendientes := []           # movimientos esperando (por el retraso)
	var golpes := 0
	var restante := 10.0
	var flash := 0.0
	var aviso_combustible := 0.0
	var tex_nave: Texture2D
	var tex_rocas := []


	func iniciar() -> void:
		restante = randf_range(DURACION_MIN, DURACION_MAX)
		match nave:
			"gemini4":
				retraso = 0.2       # la Gemini responde con un pequeño retraso
				cada = 0.55
			"artemis2":
				anticipacion = 2    # el radar de Artemis predice 2 casillas antes
				cada = 0.5
			_:
				cada = 0.52
		var ruta: String = Mision.NAVES[nave].capsula_img
		tex_nave = load(ruta) if ResourceLoader.exists(ruta) else null
		for i in range(1, 9):
			var r := "res://assets/espacio/asteroides/asteroid-%d.png" % i
			if ResourceLoader.exists(r):
				tex_rocas.append(load(r))


	func actualizar(delta: float) -> void:
		restante -= delta
		flash = max(flash - delta, 0.0)
		aviso_combustible = max(aviso_combustible - delta, 0.0)

		# Movimientos con retraso (Gemini)
		for p in pendientes.duplicate():
			p[1] -= delta
			if p[1] <= 0.0:
				pendientes.erase(p)
				_aplicar(p[0])

		# Nuevas rocas
		reloj_rocas -= delta
		if reloj_rocas <= 0.0 and restante > PASO * (FILAS + anticipacion):
			reloj_rocas = cada * randf_range(0.8, 1.2)
			var roca := {"col": randi() % COLS, "fila": -float(anticipacion) - 0.5, "tex": null, "pego": false, "giro": randf() * TAU}
			if not tex_rocas.is_empty():
				roca.tex = tex_rocas.pick_random()
			rocas.append(roca)

		# Mover rocas y revisar choques
		for r in rocas.duplicate():
			r.fila += delta / PASO
			r.giro += delta
			if not r.pego and r.col == col and absf(r.fila - fila) < 0.45:
				r.pego = true
				golpes += 1
				flash = 0.35
				viaje.casco -= viaje.dano_casco
				viaje.sacudir(0.35)
				if viaje.casco <= 0.0:
					viaje.casco = 0.0
					terminar(false)
					return
			if r.fila > FILAS + 0.5:
				rocas.erase(r)

		if restante <= 0.0:
			terminar(golpes == 0)


	func _mover(direccion: Vector2i) -> void:
		if acabado:
			return
		if viaje.combustible < COSTO_MOVIMIENTO:
			aviso_combustible = 1.0
			return
		if retraso > 0.0:
			pendientes.append([direccion, retraso])
		else:
			_aplicar(direccion)


	func _aplicar(direccion: Vector2i) -> void:
		var nueva_col: int = clamp(col + direccion.x, 0, COLS - 1)
		var nueva_fila: int = clamp(fila + direccion.y, 0, FILAS - 1)
		if nueva_col == col and nueva_fila == fila:
			return
		if viaje.combustible < COSTO_MOVIMIENTO:
			aviso_combustible = 1.0
			return
		col = nueva_col
		fila = nueva_fila
		viaje.combustible -= COSTO_MOVIMIENTO


	func _input(event: InputEvent) -> void:
		if acabado or not (event is InputEventKey) or not event.pressed or event.echo:
			return
		match event.physical_keycode:
			KEY_LEFT, KEY_A:
				_mover(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				_mover(Vector2i(1, 0))
			KEY_UP, KEY_W:
				_mover(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				_mover(Vector2i(0, 1))


	func _gui_input(event: InputEvent) -> void:
		if acabado:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var dirs := {Vector2i(0, -1): Vector2(0, -22), Vector2i(0, 1): Vector2(0, 22),
				Vector2i(-1, 0): Vector2(-26, 0), Vector2i(1, 0): Vector2(26, 0)}
			for d in dirs:
				var c: Vector2 = CRUCETA + dirs[d]
				if R(c.x - 10, c.y - 9, 20, 18).has_point(event.position):
					_mover(d)
					return


	# ================= Dibujo =================

	func _celda(c: float, f: float) -> Rect2:
		var w := REJILLA.size.x / COLS
		var h := REJILLA.size.y / FILAS
		return R(REJILLA.position.x + c * w, REJILLA.position.y + f * h, w, h)


	func _draw() -> void:
		# Letrero de alerta arriba
		var banner := R(232, 4, 560, 44)
		draw_rect(banner.grow(2 * k), C_OSCURO)
		draw_rect(banner, Color("2a0d0b"))
		draw_rect(banner, Color("ff7a3d") if fmod(tiempo, 0.6) < 0.35 else Color("8a2a14"), false, 2.0 * k)
		texto_centrado(banner, 24 * k, "¡ALERTA: CAMBIO DE CURSO! - ALERT: COURSE CORRECTION NEEDED", 12, C_ROJO)
		texto_centrado(banner, 41 * k, "SELECCIONE EL VECTOR DE EVASIÓN - SELECT EVASION VECTOR", 11, C_AMBAR)

		# Ventana gris
		var v := RR(VENTANA)
		draw_rect(v.grow(3 * k), C_OSCURO)
		draw_rect(v, Color("a8adb3"))
		draw_rect(R(VENTANA.position.x, VENTANA.position.y, VENTANA.size.x, 22), Color("7c8288"))
		texto(P(380, 164), "SYSTEM: ASTEROID EVASION", 10, Color("1c1f24"))
		var x_cerrar := R(642, 152, 14, 14)
		draw_rect(x_cerrar, Color("5d636b"), false, 1.5 * k)
		texto(P(645, 164), "X", 10, Color("1c1f24"))

		# Radar
		var rej := RR(REJILLA)
		draw_rect(rej.grow(2 * k), C_OSCURO)
		draw_rect(rej, Color("0f1a24"))
		for c in range(1, COLS):
			var x := rej.position.x + rej.size.x * c / COLS
			draw_line(Vector2(x, rej.position.y), Vector2(x, rej.end.y), Color(0.3, 0.75, 0.75, 0.35), 1.0)
		for f in range(1, FILAS):
			var y := rej.position.y + rej.size.y * f / FILAS
			draw_line(Vector2(rej.position.x, y), Vector2(rej.end.x, y), Color(0.3, 0.75, 0.75, 0.35), 1.0)

		# Rocas: línea punteada de su trayectoria + la roca
		for r in rocas:
			var celda := _celda(r.col, max(r.fila, 0.0))
			var x_centro := celda.get_center().x
			var y_desde: float = max(rej.position.y, celda.get_center().y)
			var y := y_desde
			while y < rej.end.y:
				draw_line(Vector2(x_centro, y), Vector2(x_centro, min(y + 4 * k, rej.end.y)), Color(1, 0.6, 0.4, 0.35), 1.5 * k)
				y += 9 * k
			if r.fila < -0.3:
				# Todavía no entra: flechita de aviso arriba del radar
				var punta := Vector2(x_centro, rej.position.y + 9 * k)
				draw_colored_polygon(PackedVector2Array([punta, punta + Vector2(-6, -8) * k, punta + Vector2(6, -8) * k]),
					Color(1, 0.35, 0.25, 0.6 + 0.4 * sin(tiempo * 14.0)))
			else:
				var rc := _celda(r.col, r.fila)
				var tam := rc.size.y * 0.9
				var cent := rc.get_center()
				if r.tex != null:
					draw_set_transform(cent, r.giro, Vector2.ONE)
					draw_texture_rect(r.tex, Rect2(-tam * 0.5, -tam * 0.5, tam, tam), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_circle(cent, tam * 0.4, Color("7a5a3a"))

		# Nave
		var cn := _celda(col, fila)
		var cc := cn.get_center()
		if tex_nave != null:
			var tam_n := cn.size.y * 0.85
			var esc := tam_n / tex_nave.get_size().y
			var tn := tex_nave.get_size() * esc
			draw_texture_rect(tex_nave, Rect2(cc - tn * 0.5, tn), false, Color(1, 0.6, 0.6) if flash > 0.0 else Color.WHITE)
		else:
			draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -10) * k, cc + Vector2(-7, 8) * k, cc + Vector2(7, 8) * k]), Color.WHITE)
		# Esquinas verdes alrededor de la nave
		var g := Color(0.37, 0.89, 0.42)
		var l := 6.0 * k
		for esq in [cn.position, Vector2(cn.end.x, cn.position.y), Vector2(cn.position.x, cn.end.y), cn.end]:
			var sx := 1.0 if esq.x == cn.position.x else -1.0
			var sy := 1.0 if esq.y == cn.position.y else -1.0
			draw_line(esq, esq + Vector2(l * sx, 0), g, 1.5 * k)
			draw_line(esq, esq + Vector2(0, l * sy), g, 1.5 * k)

		if flash > 0.0:
			draw_rect(rej, Color(1, 0.2, 0.1, flash))

		# Abajo: joystick, cruceta, tiempo y combustible
		var joy := R(386, 356, 40, 40)
		draw_rect(joy, Color("7c8288"))
		draw_rect(joy, C_OSCURO, false, 1.5 * k)
		draw_line(P(406, 386), P(406, 368), C_OSCURO, 3 * k)
		draw_circle(P(406, 366), 5 * k, C_OSCURO)
		draw_rect(R(396, 386, 20, 6), C_OSCURO)

		var dirs := [Vector2(0, -22), Vector2(0, 22), Vector2(-26, 0), Vector2(26, 0)]
		var flechas := ["^", "v", "<", ">"]
		for i in 4:
			var c: Vector2 = CRUCETA + dirs[i]
			var b := R(c.x - 10, c.y - 9, 20, 18)
			draw_rect(b, Color("5d8a7a"))
			draw_rect(b, C_OSCURO, false, 1.5 * k)
			texto(b.position + Vector2(b.size.x * 0.32, b.size.y * 0.8), flechas[i], 10, C_TEXTO)
		draw_circle(PV(CRUCETA), 4 * k, Color("5d8a7a"))

		texto(P(572, 372), TranslationServer.translate("%.1f s") % max(restante, 0.0), 12, Color("1c1f24"))
		var comb: float = viaje.combustible
		texto(P(572, 390), TranslationServer.translate("FUEL %d%%") % int(comb), 10, C_ROJO if comb < 15.0 else Color("1c1f24"))
		if retraso > 0.0:
			texto(P(572, 406), "RETRASO 0.2s", 8, Color("8a2a14"))
		if aviso_combustible > 0.0:
			texto_centrado(rej, rej.get_center().y, "¡SIN COMBUSTIBLE RCS!", 13, C_ROJO)


# =====================================================================
# MINIJUEGO: FALLA EN LA DISTRIBUCIÓN ELÉCTRICA
# Aparece el panel de conmutadores con 12 switches. Hay que encenderlos
# TODOS (clic en cada uno). No hay límite de tiempo, pero mientras haya
# switches apagados se gastan las baterías (ENERGÍA). Si llega a 0, se pierde.
# Cada 1.5 segundos uno de los que ya estaban encendidos se bota.
# Se dibuja con coordenadas de la imagen de la cabina (1024 x 576).
# =====================================================================
class MinijuegoElectrico extends Control:
	signal terminado(exito: bool)

	const C_OSCURO := Color("1c1f24")
	const C_ROJO := Color("ff4a3d")
	const C_VERDE := Color("5ee36a")
	const C_AMBAR := Color("ffb347")
	const C_TEXTO := Color("f4eefc")

	const PANEL := Rect2(208, 128, 226, 394)
	const COLS := 4
	const FILAS := 3
	const ORIGEN := Vector2(226, 206)     # esquina del primer switch
	const PASO_X := 50.0
	const PASO_Y := 78.0
	const TAM := Vector2(34, 58)          # tamaño de cada switch
	const GASTO_POR_APAGADO := 0.5        # % de energía por segundo por cada switch apagado
	const CADA_BOTE := 1.5                # cada cuánto se bota un switch encendido
	const ENCENDIDOS_AL_INICIO := 4

	var viaje
	var k := 1.0
	var fuente: Font
	var nave := "apollo11"
	var tiempo := 0.0
	var acabado := false

	var encendidos := []       # 12 valores true/false
	var destello := []         # tiempo de destello rojo de cada switch (cuando se bota)
	var reloj_bote := CADA_BOTE


	func configurar(escena: Node, escala: float, f: Font, id: String) -> void:
		viaje = escena
		k = escala
		fuente = f
		nave = id


	func _ready() -> void:
		position = Vector2.ZERO
		size = Vector2(1024, 576) * k
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
		for i in COLS * FILAS:
			encendidos.append(false)
			destello.append(0.0)
		var lugares := range(COLS * FILAS)
		lugares.shuffle()
		for i in ENCENDIDOS_AL_INICIO:
			encendidos[lugares[i]] = true


	func _process(delta: float) -> void:
		tiempo += delta
		if not acabado:
			_actualizar(delta)
		queue_redraw()


	func _actualizar(delta: float) -> void:
		for i in destello.size():
			destello[i] = max(float(destello[i]) - delta, 0.0)

		if _todos_encendidos():
			_terminar(true)
			return

		# Mientras haya switches apagados, se gastan las baterías
		var apagados := 0
		for e in encendidos:
			if not e:
				apagados += 1
		viaje.energia = max(viaje.energia - apagados * GASTO_POR_APAGADO * delta, 0.0)
		if viaje.energia <= 0.0:
			_terminar(false)
			return

		# Cada 1.5 s se bota uno de los encendidos
		reloj_bote -= delta
		if reloj_bote <= 0.0:
			reloj_bote = CADA_BOTE
			var prendidos := []
			for i in encendidos.size():
				if encendidos[i]:
					prendidos.append(i)
			if not prendidos.is_empty():
				var i: int = prendidos.pick_random()
				encendidos[i] = false
				destello[i] = 0.5
				viaje.sacudir(0.15)


	func _todos_encendidos() -> bool:
		for e in encendidos:
			if not e:
				return false
		return true


	func _terminar(exito: bool) -> void:
		if acabado:
			return
		acabado = true
		terminado.emit(exito)
		var t := create_tween()
		t.tween_interval(0.8)
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)


	func _rect_switch(i: int) -> Rect2:
		var c := i % COLS
		var f := i / COLS
		return R(ORIGEN.x + c * PASO_X, ORIGEN.y + f * PASO_Y, TAM.x, TAM.y)


	func _gui_input(event: InputEvent) -> void:
		if acabado:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in encendidos.size():
				if _rect_switch(i).grow(4 * k).has_point(event.position):
					encendidos[i] = not encendidos[i]
					return


	# ---------- Ayudas para dibujar ----------

	func R(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(x * k, y * k, w * k, h * k)


	func RR(r: Rect2) -> Rect2:
		return Rect2(r.position * k, r.size * k)


	func P(x: float, y: float) -> Vector2:
		return Vector2(x * k, y * k)


	func texto(pos: Vector2, s: String, tam: float, color: Color, ancho: float = -1.0, alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var t := int(tam * k)
		s = TranslationServer.translate(s)   # el texto dibujado a mano no lo traduce Godot solo
		draw_string_outline(fuente, pos, s, alineacion, ancho, t, int(3 * k), Color(0, 0, 0, 0.8))
		draw_string(fuente, pos, s, alineacion, ancho, t, color)


	# ---------- Dibujo ----------

	func _draw() -> void:
		# Marco rojo sobre el panel de OXYGEN (la energía alimenta el soporte de vida)
		var ox := R(12, 112, 86, 160)
		var a := 0.5 + 0.4 * sin(tiempo * 9.0)
		draw_rect(ox, Color(1, 0.2, 0.15, a), false, 3.0 * k)

		# Placa metálica
		var panel := RR(PANEL)
		var metal := Color("6a6458")
		draw_rect(panel.grow(3.0 * k), C_OSCURO)
		draw_rect(panel, metal)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3.0 * k)), metal.lightened(0.2))
		draw_rect(Rect2(panel.position + Vector2(0, panel.size.y - 3.0 * k), Vector2(panel.size.x, 3.0 * k)), metal.darkened(0.25))
		var m := 6.0 * k
		for p in [panel.position + Vector2(m, m), panel.position + Vector2(panel.size.x - m, m),
				panel.position + Vector2(m, panel.size.y - m), panel.end - Vector2(m, m)]:
			draw_circle(p, 2.2 * k, metal.darkened(0.4))

		# Encabezado
		var cab := R(218, 138, 206, 56)
		draw_rect(cab.grow(2 * k), C_OSCURO)
		draw_rect(cab, Color("170707"))
		texto(P(224, 154), "¡FALLA DE DISTRIBUCIÓN!", 10, C_ROJO if fmod(tiempo, 0.6) < 0.35 else Color("ff8a6a"))
		texto(P(224, 169), "RECONFIGURAR MATRIZ DE", 9, C_AMBAR)
		texto(P(224, 183), "CONMUTADORES: RESTAURAR ENERGÍA", 9, C_AMBAR)

		# Línea verde de referencia detrás de los switches
		for f in FILAS:
			var y := (ORIGEN.y + f * PASO_Y + TAM.y * 0.28) * k
			draw_line(Vector2((ORIGEN.x - 8) * k, y), Vector2((ORIGEN.x + (COLS - 1) * PASO_X + TAM.x + 8) * k, y), Color(0.37, 0.89, 0.42, 0.35), 2.0 * k)

		# Switches
		for i in encendidos.size():
			_dibujar_switch(i)

		# Pie: instrucciones, tiempo y contador
		var pie := R(218, 446, 206, 66)
		draw_rect(pie.grow(2 * k), C_OSCURO)
		draw_rect(pie, Color("170707"))
		texto(P(224, 462), "ENCIENDE TODOS LOS SWITCHES", 9, C_AMBAR)
		texto(P(224, 476), "(clic en cada uno)", 8, C_TEXTO)
		var n := 0
		for e in encendidos:
			if e:
				n += 1
		texto(P(224, 500), TranslationServer.translate("%d / %d") % [n, encendidos.size()], 14, C_VERDE if n == encendidos.size() else C_TEXTO)
		var en: float = viaje.energia
		var c_energia := C_ROJO if en < 25.0 else (C_AMBAR if en < 50.0 else C_VERDE)
		texto(P(300, 500), TranslationServer.translate("ENERGÍA %d%%") % int(en), 11, c_energia)
		# Barra de energía
		var barra := R(224, 504, 194, 4)
		draw_rect(barra, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * clamp(en / 100.0, 0.0, 1.0), barra.size.y)), c_energia)


	func _dibujar_switch(i: int) -> void:
		var r := _rect_switch(i)
		var on: bool = encendidos[i]
		# Caja
		draw_rect(r.grow(2 * k), C_OSCURO)
		draw_rect(r, Color("3e3b35"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2 * k)), Color("5a564d"))
		# Foquito arriba
		var foco := r.position + Vector2(r.size.x * 0.5, 7 * k)
		var color_foco := C_VERDE if on else C_ROJO
		if not on and fmod(tiempo + i * 0.13, 0.8) > 0.5:
			color_foco = Color("7a1a14")
		draw_circle(foco, 4.2 * k, C_OSCURO)
		draw_circle(foco, 3.2 * k, color_foco)
		if on:
			draw_circle(foco, 6.0 * k, Color(0.37, 0.89, 0.42, 0.25))
		# Ranura y palanca (arriba = encendido, abajo = apagado)
		var ranura := Rect2(r.position + Vector2(r.size.x * 0.3, 16 * k), Vector2(r.size.x * 0.4, r.size.y - 22 * k))
		draw_rect(ranura, Color("15171a"))
		var alto_palanca := ranura.size.y * 0.5
		var y_palanca := ranura.position.y if on else ranura.end.y - alto_palanca
		var palanca := Rect2(Vector2(ranura.position.x - 2 * k, y_palanca), Vector2(ranura.size.x + 4 * k, alto_palanca))
		draw_rect(palanca, Color("c8ccd0") if on else Color("8a8f95"))
		draw_rect(palanca, C_OSCURO, false, 1.0 * k)
		# Destello rojo cuando se acaba de botar
		if float(destello[i]) > 0.0:
			draw_rect(r.grow(3 * k), Color(1, 0.2, 0.1, float(destello[i])), false, 3.0 * k)


# =====================================================================
# MINIJUEGO: FALLA DE OXÍGENO (VÁLVULAS)
# La válvula principal de O2 se atascó. Hay que abrir las 3 válvulas
# auxiliares: mantén presionada cada una (clic sostenido o teclas 1, 2, 3)
# 2.5 segundos, hasta que el círculo de atrás se llene de verde.
# No hay límite de tiempo, pero mientras haya válvulas cerradas se pierde
# oxígeno. Si llega a 0, se pierde la misión.
# Se dibuja con coordenadas de la imagen de la cabina (1024 x 576).
# =====================================================================
class MinijuegoOxigeno extends Control:
	signal terminado(exito: bool)

	const C_OSCURO := Color("1c1f24")
	const C_ROJO := Color("ff4a3d")
	const C_VERDE := Color("5ee36a")
	const C_AMBAR := Color("ffb347")
	const C_TEXTO := Color("f4eefc")

	const PANEL := Rect2(208, 130, 226, 312)
	const AVISO := Rect2(208, 448, 226, 80)
	const VALVULAS := [Vector2(246, 272), Vector2(320, 272), Vector2(394, 272)]
	const MEDIDORES_Y := 222.0
	const RADIO := 27.0
	const REGULADOR := Vector2(320, 388)
	const GASTO_POR_VALVULA := 1.2   # % de oxígeno por segundo por cada válvula cerrada
	const SEGUNDOS_POR_VALVULA := 2.5
	const TECLAS := [KEY_1, KEY_2, KEY_3]

	var viaje
	var k := 1.0
	var fuente: Font
	var nave := "apollo11"
	var tiempo := 0.0
	var acabado := false

	var progreso := [0.0, 0.0, 0.0]   # 0 a 1 de cada válvula
	var giro := [0.0, 0.0, 0.0]
	var giro_regulador := 0.0
	var con_mouse := -1               # válvula que se está presionando con el mouse


	func configurar(escena: Node, escala: float, f: Font, id: String) -> void:
		viaje = escena
		k = escala
		fuente = f
		nave = id


	func _ready() -> void:
		position = Vector2.ZERO
		size = Vector2(1024, 576) * k
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


	func _process(delta: float) -> void:
		tiempo += delta
		if not acabado:
			_actualizar(delta)
		queue_redraw()


	func _presionada(i: int) -> bool:
		return con_mouse == i or Input.is_physical_key_pressed(TECLAS[i])


	func _actualizar(delta: float) -> void:
		var alguna := false
		for i in 3:
			if progreso[i] < 1.0 and _presionada(i):
				progreso[i] = min(float(progreso[i]) + delta / SEGUNDOS_POR_VALVULA, 1.0)
				giro[i] = float(giro[i]) + 4.0 * delta
				alguna = true
		if alguna:
			giro_regulador += 2.5 * delta

		# El oxígeno baja mientras las válvulas sigan cerradas
		var abiertas := 0
		for p in progreso:
			if p >= 1.0:
				abiertas += 1
		viaje.oxigeno = max(viaje.oxigeno - (3 - abiertas) * GASTO_POR_VALVULA * viaje.mult_oxigeno * delta, 0.0)

		if abiertas == 3:
			_terminar(true)
		elif viaje.oxigeno <= 0.0:
			_terminar(false)


	func _terminar(exito: bool) -> void:
		if acabado:
			return
		acabado = true
		con_mouse = -1
		terminado.emit(exito)
		var t := create_tween()
		t.tween_interval(0.8)
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)


	func _gui_input(event: InputEvent) -> void:
		if acabado:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				for i in 3:
					var c: Vector2 = VALVULAS[i] * k
					if c.distance_to(event.position) < (RADIO + 8.0) * k:
						con_mouse = i
						return
			else:
				con_mouse = -1


	# ---------- Ayudas para dibujar ----------

	func R(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(x * k, y * k, w * k, h * k)


	func RR(r: Rect2) -> Rect2:
		return Rect2(r.position * k, r.size * k)


	func P(x: float, y: float) -> Vector2:
		return Vector2(x * k, y * k)


	func texto(pos: Vector2, s: String, tam: float, color: Color, ancho: float = -1.0, alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var t := int(tam * k)
		s = TranslationServer.translate(s)   # el texto dibujado a mano no lo traduce Godot solo
		draw_string_outline(fuente, pos, s, alineacion, ancho, t, int(3 * k), Color(0, 0, 0, 0.8))
		draw_string(fuente, pos, s, alineacion, ancho, t, color)


	func _rueda(c: Vector2, r: float, angulo: float, color: Color) -> void:
		draw_arc(c, r, 0, TAU, 32, color, 4.0 * k)
		for s in 3:
			var a := angulo + s * TAU / 3.0
			draw_line(c, c + Vector2.from_angle(a) * r, color, 3.0 * k)
		draw_circle(c, 4.0 * k, color.darkened(0.3))


	# ---------- Dibujo ----------

	func _draw() -> void:
		# Marco rojo sobre el panel de OXYGEN
		var a := 0.5 + 0.4 * sin(tiempo * 9.0)
		draw_rect(R(12, 112, 86, 160), Color(1, 0.2, 0.15, a), false, 3.0 * k)

		# Placa metálica
		var panel := RR(PANEL)
		var metal := Color("6a6458")
		draw_rect(panel.grow(3.0 * k), C_OSCURO)
		draw_rect(panel, metal)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3.0 * k)), metal.lightened(0.2))
		var m := 6.0 * k
		for p in [panel.position + Vector2(m, m), panel.position + Vector2(panel.size.x - m, m),
				panel.position + Vector2(m, panel.size.y - m), panel.end - Vector2(m, m)]:
			draw_circle(p, 2.2 * k, metal.darkened(0.4))

		# Encabezado
		var cab := R(218, 140, 206, 42)
		draw_rect(cab.grow(2 * k), C_OSCURO)
		draw_rect(cab, Color("0d0f12"))
		texto(P(224, 157), "¡FALLA CRÍTICA!", 10, C_ROJO if fmod(tiempo, 0.6) < 0.35 else Color("ff8a6a"))
		texto(P(224, 173), "ESTABILIZAR SISTEMAS O2", 10, C_TEXTO)

		# Tubería de las válvulas al regulador
		var tubo := Color("4d4a43")
		for c in VALVULAS:
			draw_line(P(c.x, c.y + 30), P(c.x, 345), tubo, 8.0 * k)
		draw_line(P(246, 345), P(394, 345), tubo, 8.0 * k)
		draw_line(P(320, 345), P(320, 360), tubo, 8.0 * k)

		for i in 3:
			_dibujar_valvula(i)

		# Regulador de flujo (gira cuando abres una válvula)
		texto(P(262, 356), "REGULADOR DE FLUJO", 8, C_TEXTO)
		var rc := REGULADOR * k
		draw_circle(rc, 33.0 * k, C_OSCURO)
		_rueda(rc, 28.0 * k, giro_regulador, Color("9aa0a6"))
		draw_line(rc, rc + Vector2.from_angle(giro_regulador * 0.5 - 0.8) * 24.0 * k, Color("c0392b"), 3.0 * k)

		# Luces de nivel a la derecha del regulador
		var abiertas := 0
		for p in progreso:
			if p >= 1.0:
				abiertas += 1
		for j in 3:
			var luz := R(404, 404 - j * 12, 14, 8)
			draw_rect(luz, C_VERDE if j < abiertas else Color("5a1410"))

		# Aviso rojo de abajo con tiempo
		var av := RR(AVISO)
		draw_rect(av.grow(2 * k), C_OSCURO)
		draw_rect(av, Color("140606"))
		texto(P(214, 465), "ALERTA: VÁLVULA PRINCIPAL O2", 9, C_ROJO)
		texto(P(214, 479), "ATASCADA. MANTÉN PRESIONADAS", 9, C_ROJO)
		texto(P(214, 493), "LAS VÁLVULAS (CLIC o 1-2-3)", 9, C_ROJO)
		var ox: float = viaje.oxigeno
		var c_ox := C_ROJO if ox < 25.0 else (C_AMBAR if ox < 50.0 else C_VERDE)
		texto(P(214, 516), TranslationServer.translate("OXÍGENO: %d%%") % int(ox), 12, c_ox)
		var barra := R(214, 521, 214, 4)
		draw_rect(barra, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * clamp(ox / 100.0, 0.0, 1.0), barra.size.y)), c_ox)


	func _dibujar_valvula(i: int) -> void:
		var c: Vector2 = VALVULAS[i] * k
		var r := RADIO * k
		var p: float = progreso[i]
		var lista := p >= 1.0

		# Medidor de arriba: la aguja pasa de rojo a verde con el progreso
		var mc := Vector2(c.x, MEDIDORES_Y * k)
		var mr := 18.0 * k
		draw_circle(mc, mr + 2 * k, C_OSCURO)
		draw_circle(mc, mr, Color("d9d6cc"))
		var a0 := deg_to_rad(200.0)
		var a1 := deg_to_rad(340.0)
		draw_arc(mc, mr * 0.75, a0, lerp(a0, a1, 0.6), 10, Color("e5383b"), 5.0 * k)
		draw_arc(mc, mr * 0.75, lerp(a0, a1, 0.6), a1, 10, Color("3cb44b"), 5.0 * k)
		var aguja: float = lerp(a0, a1, 0.1 + 0.85 * p) + sin(tiempo * 30.0 + i) * 0.03 * (1.0 - p)
		draw_line(mc, mc + Vector2.from_angle(aguja) * mr * 0.85, Color("8b0000"), 2.0 * k)
		draw_circle(mc, 2.5 * k, C_OSCURO)

		# Círculo de atrás: se llena de verde mientras la mantienes presionada
		draw_circle(c, r + 6 * k, Color(0.9, 0.2, 0.15, 0.35) if not lista else Color(0.37, 0.89, 0.42, 0.55))
		if p > 0.0 and not lista:
			draw_arc(c, r + 3 * k, -PI * 0.5, -PI * 0.5 + TAU * p, 40, Color(0.37, 0.89, 0.42, 0.9), 6.0 * k)
		draw_circle(c, r - 2 * k, Color("2e2c28"))
		var color_rueda := Color("c8ccd0") if _presionada(i) or lista else Color("8a8f95")
		_rueda(c, r - 6 * k, giro[i], color_rueda)
		if _presionada(i) and not lista:
			draw_arc(c, r + 10 * k, 0, TAU, 32, Color(1, 1, 1, 0.35), 1.5 * k)

		# Placa con el número
		var placa := R(VALVULAS[i].x - 13, 312, 26, 22)
		draw_rect(placa.grow(1.5 * k), C_OSCURO)
		draw_rect(placa, Color("4a4740"))
		texto(placa.position + Vector2(8, 17) * k, str(i + 1), 14, C_VERDE if lista else C_TEXTO)
