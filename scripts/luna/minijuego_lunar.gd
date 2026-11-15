class_name MinijuegoLunar
extends Node2D
## Base de los minijuegos de la Luna (un jugador: WASD + E).
## Se encarga de la pantalla de instrucciones, el cronómetro, el resultado
## y el regreso al mapa. Cada minijuego hereda de aquí y solo escribe:
##   _preparar()          -> arma el escenario
##   _al_empezar()        -> cuando el jugador presiona E en las instrucciones
##   _actualizar(delta)   -> lógica de cada cuadro
##   _hud()               -> texto extra del HUD (opcional)
## NO sobrescribas _ready() ni _process() en los minijuegos.

const ANCHO := 480.0
const ALTO := 270.0
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const A := "res://assets/luna/"

const C_P1 := Color("41a6f6")
const C_P2 := Color("ef7d57")
const C_TEXTO := Color("f4f4f4")
const C_DORADO := Color("ffcd75")
const C_VERDE := Color("38b764")
const C_ROJO := Color("e0505f")
const C_PANEL := Color(0.06, 0.07, 0.13, 0.94)

enum Estado { INTRO, JUGANDO, FIN }

# ---- Lo llena cada minijuego en _preparar() ----
var id_minijuego := ""
var titulo := ""
var datos: Array[String] = []      # datos curiosos / educativos de la pantalla de inicio
var objetivo := ""
var controles := ""
var tiempo_limite := 60.0

# ---- Estado ----
var estado := Estado.INTRO
var tiempo_restante := 0.0
var tiempo_juego := 0.0
var puntos := 0
var exito := false
var motivo_fin := ""

# ---- Nodos ----
var fuente: Font
var tam := 8
var mundo: Node2D
var camara: Camera2D
var ui: CanvasLayer
var hud: Control
var lbl_tiempo: Label
var lbl_hud: Label
var panel_intro: Control
var panel_fin: Control
var lbl_listo: Label


# =====================================================================
func _ready() -> void:
	LunaEstado.asegurar_controles()
	if ResourceLoader.exists(RUTA_FUENTE):
		fuente = load(RUTA_FUENTE)
	else:
		fuente = ThemeDB.fallback_font
		tam = 10
	mundo = Node2D.new()
	mundo.name = "Mundo"
	add_child(mundo)
	camara = Camera2D.new()
	camara.position = Vector2(ANCHO, ALTO) / 2.0
	add_child(camara)
	camara.make_current()
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	_preparar()
	tiempo_restante = tiempo_limite
	_crear_hud()
	_crear_intro()
	hud.visible = false
	get_viewport().size_changed.connect(_ajustar_escala)
	_ajustar_escala()


func _ajustar_escala() -> void:
	var vp := get_viewport_rect().size
	var f := minf(vp.x / ANCHO, vp.y / ALTO)
	camara.zoom = Vector2(f, f)
	ui.scale = Vector2(f, f)
	ui.offset = (vp - Vector2(ANCHO, ALTO) * f) / 2.0


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_volver_al_mapa()
		return
	match estado:
		Estado.INTRO:
			if Input.is_action_just_pressed("p1_interact"):
				_empezar()
		Estado.JUGANDO:
			tiempo_juego += delta
			tiempo_restante = maxf(tiempo_restante - delta, 0.0)
			_actualizar(delta)
			if estado == Estado.JUGANDO and tiempo_restante <= 0.0:
				terminar(false, "¡Se acabó el tiempo!")
			_refrescar_hud()
		Estado.FIN:
			if Input.is_action_just_pressed("luna_reintentar"):
				get_tree().reload_current_scene()
			elif Input.is_action_just_pressed("p1_interact"):
				_volver_al_mapa()


func _empezar() -> void:
	estado = Estado.JUGANDO
	panel_intro.queue_free()
	hud.visible = true
	_al_empezar()


## Llama a esto cuando se gana o se pierde.
func terminar(gano: bool, motivo: String = "") -> void:
	if estado != Estado.JUGANDO:
		return
	estado = Estado.FIN
	exito = gano
	motivo_fin = motivo
	_al_terminar()
	LunaEstado.registrar(id_minijuego, exito, puntos)
	_crear_panel_fin()


func _volver_al_mapa() -> void:
	set_process(false)
	if LunaEstado.escena_mapa != "" and ResourceLoader.exists(LunaEstado.escena_mapa):
		get_tree().change_scene_to_file.call_deferred(LunaEstado.escena_mapa)
	else:
		# Probando la escena sola (F6): no hay mapa al que volver.
		print("[Luna] Minijuego '%s' terminado. Éxito: %s  Puntos: %d" % [id_minijuego, exito, puntos])
		get_tree().reload_current_scene.call_deferred()


# ---- Métodos para sobrescribir ----
func _preparar() -> void:
	pass

func _al_empezar() -> void:
	pass

func _actualizar(_delta: float) -> void:
	pass

func _al_terminar() -> void:
	pass

func _hud() -> String:
	return ""


# =====================================================================
#  UTILIDADES PARA LOS MINIJUEGOS
# =====================================================================

func etiqueta(padre: Node, texto: String, pos: Vector2, color: Color = C_TEXTO, ancho: float = 0.0, centrado := false, escala := 1) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", tam * escala)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ancho > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = ancho
		l.size.x = ancho
	if centrado:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	padre.add_child(l)
	return l


func panel(padre: Node, r: Rect2, borde: Color = C_DORADO) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = borde
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(p)
	return p


func sprite(ruta: String, pos: Vector2, padre: Node = null, cuadros := 1) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(ruta):
		s.texture = load(ruta)
	else:
		push_warning("[Luna] Falta la imagen: " + ruta)
	s.hframes = cuadros
	s.position = pos
	(padre if padre else mundo).add_child(s)
	return s


func barra(padre: Node, r: Rect2, color: Color) -> ColorRect:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.position = r.position
	fondo.size = r.size
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(fondo)
	var relleno := ColorRect.new()
	relleno.color = color
	relleno.position = Vector2(1, 1)
	relleno.size = r.size - Vector2(2, 2)
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relleno.set_meta("ancho", r.size.x - 2)
	fondo.add_child(relleno)
	return relleno


func llenar_barra(relleno: ColorRect, fraccion: float) -> void:
	relleno.size.x = float(relleno.get_meta("ancho")) * clampf(fraccion, 0.0, 1.0)


## Texto que sube y se desvanece en el mundo (ej. "+1 BASALTO").
func texto_flotante(pos: Vector2, texto: String, color: Color = C_DORADO) -> void:
	var nodo := Node2D.new()
	nodo.position = pos
	nodo.z_index = 50
	mundo.add_child(nodo)
	var l := etiqueta(nodo, texto, Vector2(-60, -8), color, 120.0, true)
	l.add_theme_font_size_override("font_size", tam)
	var tw := create_tween()
	tw.tween_property(nodo, "position:y", pos.y - 22.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(nodo, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(nodo.queue_free)


## Suelo lunar dibujado (gris con puntitos y pequeños cráteres decorativos).
func crear_suelo(rect: Rect2, semilla := 1) -> void:
	var s := SueloLunar.new()
	s.rect = rect
	s.semilla = semilla
	s.z_index = -10
	mundo.add_child(s)


## Mueve un nodo con los controles del jugador y lo mantiene dentro de un rectángulo.
func mover_con_controles(nodo: Node2D, pid: int, velocidad: float, limites: Rect2, delta: float) -> Vector2:
	var p := "p%d_" % pid
	var dir := Input.get_vector(p + "left", p + "right", p + "up", p + "down")
	nodo.position += dir * velocidad * delta
	nodo.position = nodo.position.clamp(limites.position, limites.end)
	return dir


## Paredes invisibles alrededor de un rectángulo para que nadie se salga.
func crear_paredes(r: Rect2) -> void:
	var cuerpo := StaticBody2D.new()
	mundo.add_child(cuerpo)
	var lados := [
		[r.position, Vector2(r.end.x, r.position.y)],
		[Vector2(r.end.x, r.position.y), r.end],
		[r.end, Vector2(r.position.x, r.end.y)],
		[Vector2(r.position.x, r.end.y), r.position],
	]
	for l in lados:
		var col := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = l[0]
		seg.b = l[1]
		col.shape = seg
		cuerpo.add_child(col)


## Obstáculo sólido rectangular (ej. la base de la nave).
func crear_solido(centro: Vector2, tamano: Vector2) -> StaticBody2D:
	var cuerpo := StaticBody2D.new()
	cuerpo.position = centro
	var col := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = tamano
	col.shape = forma
	cuerpo.add_child(col)
	mundo.add_child(cuerpo)
	return cuerpo


## Crea al astronauta. Usa la escena del jugador del proyecto (Player.tscn) si existe;
## si no, crea un astronauta sencillo con los mismos controles.
func crear_jugador(pos: Vector2) -> Node2D:
	var j: Node2D = null
	var escena := LunaEstado.escena_jugador(1)
	if escena:
		var inst := escena.instantiate()
		if inst is CharacterBody2D and "player_id" in inst:
			j = inst as Node2D
		else:
			inst.free()
	if j == null:
		j = AstronautaSimple.new()
	j.set("player_id", 1)
	j.position = pos
	mundo.add_child(j)
	# Por si la escena del jugador trae su propia cámara: usamos la del minijuego.
	for c in j.find_children("*", "Camera2D", true, false):
		(c as Camera2D).enabled = false
	camara.make_current()
	return j


# =====================================================================
#  INTERFAZ
# =====================================================================

func _crear_hud() -> void:
	panel(hud, Rect2(0, 0, ANCHO, 16), Color(0, 0, 0, 0))
	etiqueta(hud, titulo, Vector2(6, 2), C_DORADO)
	lbl_tiempo = etiqueta(hud, "", Vector2(ANCHO - 86, 2), C_TEXTO, 80.0)
	lbl_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_hud = etiqueta(hud, "", Vector2(6, 18), C_TEXTO, 200.0)


func _refrescar_hud() -> void:
	lbl_tiempo.text = "TIEMPO %d" % ceili(tiempo_restante)
	lbl_tiempo.add_theme_color_override("font_color", C_ROJO if tiempo_restante < 10.0 else C_TEXTO)
	lbl_hud.text = _hud()


func _crear_intro() -> void:
	panel_intro = Control.new()
	panel_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel_intro)
	var oscuro := ColorRect.new()
	oscuro.color = Color(0, 0, 0, 0.55)
	oscuro.size = Vector2(ANCHO, ALTO)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_intro.add_child(oscuro)
	panel(panel_intro, Rect2(30, 14, 420, 242))
	etiqueta(panel_intro, titulo, Vector2(30, 22), C_DORADO, 420.0, true, 2)
	var y := 48.0
	for d in datos:
		etiqueta(panel_intro, d, Vector2(44, y), C_TEXTO, 392.0)
		y += _alto_texto(d, 392.0) + 4.0
	y += 2.0
	etiqueta(panel_intro, "OBJETIVO: " + objetivo, Vector2(44, y), C_VERDE, 392.0)
	y += _alto_texto("OBJETIVO: " + objetivo, 392.0) + 8.0
	etiqueta(panel_intro, "CONTROLES", Vector2(44, y), C_P1)
	y += tam + 4.0
	etiqueta(panel_intro, controles, Vector2(44, y), C_TEXTO, 392.0)
	lbl_listo = etiqueta(panel_intro, "Presiona E para empezar", Vector2(30, 232), C_DORADO, 420.0, true)


func _alto_texto(texto: String, ancho: float) -> float:
	var s := fuente.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, ancho, tam)
	return s.y


func _crear_panel_fin() -> void:
	panel_fin = Control.new()
	panel_fin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel_fin)
	var col := C_VERDE if exito else C_ROJO
	panel(panel_fin, Rect2(110, 70, 260, 120), col)
	etiqueta(panel_fin, "¡MISIÓN CUMPLIDA!" if exito else "MISIÓN FALLIDA", Vector2(110, 80), col, 260.0, true, 2)
	etiqueta(panel_fin, motivo_fin, Vector2(122, 108), C_TEXTO, 236.0, true)
	etiqueta(panel_fin, "PUNTOS: %d" % puntos, Vector2(110, 134), C_DORADO, 260.0, true)
	etiqueta(panel_fin, "E: volver a la base     R: reintentar", Vector2(110, 168), C_TEXTO, 260.0, true)


# =====================================================================
#  CLASES INTERNAS
# =====================================================================

## Suelo lunar procedural.
class SueloLunar extends Node2D:
	var rect := Rect2(0, 0, 480, 270)
	var semilla := 1

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var margen := rect.grow(240)
		draw_rect(margen, Color("8f939b"))
		draw_rect(rect, Color("a3a7ae"))
		for i in int(rect.size.x * rect.size.y / 90.0):
			var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)).floor()
			var c := Color("8c9098") if rng.randf() < 0.6 else Color("b9bcc2")
			draw_rect(Rect2(p, Vector2.ONE * (1 if rng.randf() < 0.8 else 2)), c)
		for i in int(rect.size.x * rect.size.y / 9000.0):
			var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)).floor()
			var r := rng.randf_range(3.0, 8.0)
			draw_circle(p, r + 1.0, Color("b9bcc2"))
			draw_circle(p + Vector2(0.5, 0.8), r, Color("888c94"))
			draw_circle(p + Vector2(1, 1.5), r * 0.6, Color("7c8088"))


## Astronauta de respaldo por si no se encuentran las escenas de jugador.
class AstronautaSimple extends CharacterBody2D:
	var player_id := 1
	var speed := 70.0

	func _ready() -> void:
		add_to_group("players")
		var col := CollisionShape2D.new()
		var forma := CircleShape2D.new()
		forma.radius = 5.0
		col.shape = forma
		col.position = Vector2(0, 4)
		add_child(col)
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	func _physics_process(_delta: float) -> void:
		var p := "p%d_" % player_id
		velocity = Input.get_vector(p + "left", p + "right", p + "up", p + "down") * speed
		move_and_slide()
		queue_redraw()

	func _draw() -> void:
		var traje := Color("41a6f6")
		draw_rect(Rect2(-5, -2, 10, 9), Color("1a1c2c"))
		draw_rect(Rect2(-4, -1, 8, 7), Color("f4f4f4"))
		draw_rect(Rect2(-4, 3, 8, 2), traje)
		draw_circle(Vector2(0, -6), 5.5, Color("1a1c2c"))
		draw_circle(Vector2(0, -6), 4.5, Color("f4f4f4"))
		draw_rect(Rect2(-3, -8, 6, 4), Color("29366f"))
		draw_rect(Rect2(-4, 7, 3, 2), Color("333c57"))
		draw_rect(Rect2(1, 7, 3, 2), Color("333c57"))
